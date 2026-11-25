"""Unit tests for the CDR routing recall eval (EVAL-018, adlc-workspace#36).

Covers the grader (check_cdr_recall.py), the CI gate (summarize.py) and the
live index render (render_index.sh), so a green eval run means the model
routed well, not that the harness silently scored nothing.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

RECALL = Path(__file__).parent.parent / "cdr-recall"
sys.path.insert(0, str(RECALL))

from check_cdr_recall import get_assert, parse_picks  # noqa: E402
import summarize  # noqa: E402

CASES = json.loads((RECALL / "cases.json").read_text())
ALIASES = json.loads((RECALL / "cdr-aliases.json").read_text())


def _grade(output: str, **case) -> dict:
    case.setdefault("always_allow", CASES["always_allow"])
    return get_assert(output, {"vars": {"case_json": json.dumps(case)}})


# --- grader ---------------------------------------------------------------

def test_module_names_and_paths_resolve():
    picks = parse_picks("helm_template_helpers\ncontext_modules/rules/devops/argocd_applications.md")
    assert picks == {"helm_template_helpers", "argocd_applications"}


def test_cdr_ids_resolve_through_aliases():
    cdr_id, module = next((k, v) for k, v in ALIASES.items() if k.startswith("CDR-"))
    assert parse_picks(f"- {cdr_id}") == {module}


def test_unknown_words_are_not_picks():
    assert parse_picks("I would open the helm stuff and NONE else") == set()


def test_full_recall_passes():
    r = _grade("helm_template_helpers", expect=["helm_template_helpers"], allow=[])
    assert r["pass"] and r["score"] == 1.0


def test_miss_fails_with_partial_score():
    r = _grade("spring_boot_patterns", expect=["spring_boot_patterns", "dependency_injection"], allow=[])
    assert not r["pass"] and r["score"] == 0.5 and "dependency_injection" in r["reason"]


def test_any_of_needs_one_hit():
    case = dict(expect=["sql_injection_prevention", "prevent_sql_injection"], any_of=True, allow=[])
    assert _grade("prevent_sql_injection", **case)["pass"]
    assert not _grade("frontend_security", **case)["pass"]


def test_false_positive_reported_but_not_failing():
    r = _grade("github_actions\ncrossplane_compositions", expect=["github_actions"], allow=[])
    assert r["pass"] and "false positives ['crossplane_compositions']" in r["reason"]


def test_allow_and_always_allow_are_not_false_positives():
    r = _grade("gke_workload_identity\nsecrets_management\nconstitution",
               expect=["gke_workload_identity"], allow=["secrets_management"])
    assert r["pass"] and "false positives" not in r["reason"]


def test_expect_none_passes_only_on_none():
    assert _grade("NONE", expect=[], allow=[])["pass"]
    assert not _grade("github_actions", expect=[], allow=[])["pass"]


# --- cases stay in sync with the fixture ----------------------------------

def test_every_case_module_exists_in_fixture():
    cdr = (RECALL / "fixture/directives/CDR.md").read_text()
    modules = set(re.findall(r"/([A-Za-z0-9_\-]+)\.md \|", cdr))
    named = set(CASES["always_allow"])
    for c in CASES["cases"]:
        named |= set(c["expect"]) | set(c.get("allow", []))
    assert not named - modules, f"cases name modules absent from fixture CDR.md: {sorted(named - modules)}"


def test_case_ids_unique():
    ids = [c["id"] for c in CASES["cases"]]
    assert len(ids) == len(set(ids))


# --- live render ----------------------------------------------------------

def test_render_index_emits_boot_cdr_index():
    out = subprocess.run(["bash", str(RECALL / "render_index.sh")],
                         capture_output=True, text=True, timeout=30, check=True).stdout
    assert out.startswith("## CDR Index\n")
    assert "_Total: 67 CDRs available._" in out
    assert "helm_template_helpers" in out
    assert "## " not in out.split("\n", 1)[1], "render leaked past the CDR Index block"


def test_render_index_fails_loudly_without_index(tmp_path):
    (tmp_path / "context_modules").mkdir()
    r = subprocess.run(["bash", str(RECALL / "render_index.sh"), str(tmp_path)],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode != 0


# --- CI gate --------------------------------------------------------------

def _results(tmp_path, rows):
    p = tmp_path / "r.json"
    p.write_text(json.dumps({"results": {"results": [
        {"prompt": {"label": shape}, "testCase": {"description": f"c{i}"},
         "gradingResult": {"score": s, "reason": reason}}
        for i, (shape, s, reason) in enumerate(rows)]}}))
    return str(p)


def _run(path, *flags):
    return summarize.main(["summarize.py", path, *flags])


def test_baseline_mode_passes_and_reports(tmp_path, capsys):
    p = _results(tmp_path, [("shipped", 0.0, "recall 0.00")])
    assert _run(p) == 0
    assert "BASELINE" in capsys.readouterr().out


def test_floor_fails_below_min_recall(tmp_path):
    p = _results(tmp_path, [("shipped", 1.0, ""), ("shipped", 0.0, "recall 0.00")])
    assert _run(p, "--min-recall", "0.9") == 1
    assert _run(p, "--min-recall", "0.5") == 0


def test_floor_counts_false_positives(tmp_path):
    p = _results(tmp_path, [("shipped", 1.0, "recall 1.00; false positives ['a', 'b']"),
                            ("shipped", 1.0, "recall 1.00; false positives ['c']")])
    assert _run(p, "--max-false-pos", "2") == 1
    assert _run(p, "--max-false-pos", "3") == 0


def test_floor_on_missing_shape_fails(tmp_path):
    p = _results(tmp_path, [("triggers", 1.0, "")])
    assert _run(p, "--min-recall", "0.5") == 1


def test_empty_results_fail(tmp_path):
    assert _run(_results(tmp_path, []), "--min-recall", "0.5") == 1


def test_errored_row_scores_zero(tmp_path):
    p = tmp_path / "r.json"
    p.write_text(json.dumps({"results": {"results": [
        {"prompt": {"label": "shipped"}, "error": "rate limited",
         "gradingResult": {"score": 1.0, "reason": ""}}]}}))
    assert _run(str(p), "--min-recall", "0.5") == 1


@pytest.mark.parametrize("trig,table,rc", [(1.0, 0.9, 0), (0.8, 0.9, 1)])
def test_gate_triggers_vs_full_table(tmp_path, trig, table, rc):
    p = _results(tmp_path, [("triggers", trig, ""), ("full-table", table, "")])
    assert _run(p, "--gate") == rc


def test_gate_without_both_shapes_fails(tmp_path):
    assert _run(_results(tmp_path, [("shipped", 1.0, "")]), "--gate") == 1
