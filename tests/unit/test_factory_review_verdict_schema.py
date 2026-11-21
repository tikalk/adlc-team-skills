"""One verdict schema, a generated marker, a lint before posting (SF-SKILL-02).

Live drift on octopus-next review verdicts (2026-11-09…19): the model typed
the marker and invented run ids although the lane passes the real one in
WORKFLOW_INPUTS — run=factory-review-1332 (!1332), run=mr-1335 (!1335),
run=local (!1301), run=mission-1517-manual (!1322); !1321 said findings=0
with nits=1; markers sat on line 5/23/62; headings changed per run;
"not yet posted (needs your confirm)" leaked into adlc-argo-wf!84.

verdict-schema.sh (and its PowerShell twin) prints the marker from the counts
and the run context, and lints a whole body; post-verdict refuses a body that
fails the lint. These tests pin the marker, every lint rule, the twin parity,
compatibility with check-verdict-head.sh, and the skill text.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
REVIEW = ROOT / "skills/factory/factory-review"
SCRIPT = REVIEW / "scripts/bash/verdict-schema.sh"
PS_SCRIPT = REVIEW / "scripts/powershell/verdict-schema.ps1"
CHECKER = REVIEW / "scripts/bash/check-verdict-head.sh"
SKILL = REVIEW / "SKILL.md"

HEAD = "63e2525b7eca8577e5984e84d269b308f197bb9d"
RUN = "4335f623-f024-4f9c-87d1-9e7dd935f157"
LANE = json.dumps({"issue_ref": "tikalk/engineering/octopus-next!1335", "run_id": RUN, "dispatch": "autonomous"})

needs_node = pytest.mark.skipif(shutil.which("bash") is None or shutil.which("node") is None,
                                reason="needs bash and node")
needs_pwsh = pytest.mark.skipif(shutil.which("pwsh") is None or shutil.which("node") is None,
                                reason="needs pwsh and node (CI runs it)")
INTERPRETERS = [
    pytest.param("bash", marks=[pytest.mark.requires_bash, needs_node]),
    pytest.param("pwsh", marks=needs_pwsh),
]


def env_for(context):
    env = {k: v for k, v in os.environ.items() if k not in ("ADLC_RUN_ID", "WORKFLOW_INPUTS")}
    env.update(context)
    return env


def vs(*args, interpreter="bash", context=None):
    context = {"WORKFLOW_INPUTS": LANE} if context is None else context
    cmd = ["bash", str(SCRIPT)] if interpreter == "bash" else ["pwsh", "-NoProfile", "-File", str(PS_SCRIPT)]
    return subprocess.run([*cmd, *args], capture_output=True, text=True, env=env_for(context))


def marker(imp, nits, iter_="0", **kw):
    r = vs("marker", "--iter", iter_, "--important", str(imp), "--nits", str(nits), "--head", HEAD, **kw)
    assert r.returncode == 0, r.stderr
    return r.stdout.strip()


def body(m, imp_items, nit_items, before="", between="", status="completed"):
    imp = "\n".join(f"### I{i} — x\nwhy\n" for i in range(imp_items)) or "None."
    nit = "\n".join(f"### N{i} — y\nwhy\n" for i in range(nit_items)) or "None."
    oc = "merge-ready" if imp_items == 0 and status == "completed" else "not-merge-ready"
    return (f"{m}\n\n{before}## Verdict\n**Outcome:** {oc}\n\nTwo-line summary.\n\n{between}"
            f"## Important findings\n{imp}\n\n## Nits\n{nit}\n")


def lint(tmp_path, text, interpreter="bash", context=None):
    f = tmp_path / "v.md"
    f.write_text(text, encoding="utf-8")
    return vs("lint", str(f), interpreter=interpreter, context=context)


# ── the marker is generated ─────────────────────────────────────────────────

@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_marker_is_generated_from_counts_and_the_lane_run_id(interpreter):
    kw = {"interpreter": interpreter}
    assert marker(2, 1, **kw) == (f"<!-- factory-review:step=review run={RUN} iter=0 status=completed "
                                  f"outcome=not-merge-ready findings=3 important=2 nits=1 head={HEAD} -->")
    assert "outcome=merge-ready findings=1 important=0 nits=1" in marker(0, 1, **kw)


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("context, run", [
    ({"ADLC_RUN_ID": "7c1446ae", "WORKFLOW_INPUTS": LANE}, "7c1446ae"),  # a workflow run: the engine id wins
    ({"WORKFLOW_INPUTS": LANE}, RUN),                                    # a raw lane run (reviews)
    ({"WORKFLOW_INPUTS": json.dumps({"run_id": "pending"})}, "interactive"),  # the chart placeholder
    ({"ADLC_RUN_ID": "a b"}, "interactive"),                             # not a safe id
    ({}, "interactive"),                                                 # a local session
], ids=["adlc", "lane", "pending", "unsafe", "local"])
def test_run_id_resolution(interpreter, context, run):
    r = vs("run-id", interpreter=interpreter, context=context)
    assert r.returncode == 0 and r.stdout.strip() == run, r.stderr


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_failed_review_is_never_merge_ready(interpreter):
    r = vs("marker", "--iter", "0", "--important", "0", "--nits", "0", "--head", HEAD, "--status", "failed",
           interpreter=interpreter)
    assert r.returncode == 0 and "status=failed outcome=not-merge-ready" in r.stdout


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("args, why", [
    (["marker", "--iter", "0", "--important", "-1", "--nits", "0", "--head", HEAD], "non-negative integers"),
    (["marker", "--iter", "0", "--important", "0", "--nits", "0", "--head", HEAD[:7]], "40-character"),
    (["marker", "--iter", "0", "--important", "0", "--nits", "0", "--head", HEAD, "--run", "x"], "unknown argument"),
    (["marker", "--iter", "0", "--important", "0", "--nits", "0", "--head", HEAD, "--status", "done"], "completed or failed"),
    (["lint"], "usage"),
    (["--help"], "usage"),
], ids=["negative", "short-head", "no-run-override", "bad-status", "lint-no-file", "unknown-command"])
def test_usage_errors_exit_2(interpreter, args, why):
    r = vs(*args, interpreter=interpreter)
    assert r.returncode == 2 and why in r.stderr, r.stdout + r.stderr


# ── the lint ────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_schema_body_passes(tmp_path, interpreter):
    r = lint(tmp_path, body(marker(1, 2), 1, 2), interpreter=interpreter)
    assert r.returncode == 0 and r.stdout.strip() == "verdict-schema: OK", r.stdout


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_project_sections_may_sit_around_the_schema_sections(tmp_path, interpreter):
    # octopus-next's review skill opens with "How the Software Factory handled this MR".
    text = body(marker(0, 1), 0, 1, before="## How the Software Factory handled this MR\n- ran clean\n\n",
                between="## Runtime test\n```\n### not a finding (inside a fence)\n```\n\n")
    r = lint(tmp_path, text + "\n## Screenshots\nnone\n", interpreter=interpreter)
    assert r.returncode == 0, r.stdout


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_local_session_verdict_carries_run_interactive(tmp_path, interpreter):
    m = marker(0, 1, interpreter=interpreter, context={})
    assert " run=interactive " in m
    assert lint(tmp_path, body(m, 0, 1), interpreter=interpreter, context={}).returncode == 0
    # ...and cannot be posted from a lane run, where the run id is known.
    r = lint(tmp_path, body(m, 0, 1), interpreter=interpreter)
    assert r.returncode == 1 and f"run=interactive but this run is {RUN}" in r.stdout


DRIFT = [
    # invented run ids seen on octopus-next review verdicts
    (lambda b: b.replace(f"run={RUN}", "run=mr-1335"), "run=mr-1335 but this run is"),
    (lambda b: b.replace(f"run={RUN}", "run=factory-review-1332"), "run=factory-review-1332 but this run is"),
    (lambda b: b.replace(f"run={RUN}", "run=local"), "run=local but this run is"),
    # !1321: findings=0 with nits=1
    (lambda b: b.replace("findings=1", "findings=0"), "findings=0 but important+nits=1"),
    (lambda b: b.replace("outcome=merge-ready", "outcome=not-merge-ready"), "contradicts status=completed important=0"),
    (lambda b: b.replace("**Outcome:** merge-ready", "**Outcome:** not-merge-ready"), "differs from the marker"),
    (lambda b: b.replace("### N0 — y\n", ""), "0 \"### \" finding(s) under \"## Nits\" but nits=1"),
    (lambda b: b.replace("None.", "nothing"), "must say \"None.\""),
    # !1334 notes 87534/87543: the marker on line 5
    (lambda b: "## Review of !1334\n\nsome text\n\n" + b, "first non-blank line must be the marker"),
    (lambda b: b.replace("## Verdict", "## Summary"), "expected exactly one \"## Verdict\", found 0"),
    (lambda b: b + "\n## Nits\nagain\n", "expected exactly one \"## Nits\", found 2"),
    (lambda b: b.replace("## Important findings", "## Tmp").replace("## Nits", "## Important findings")
              .replace("## Tmp", "## Nits"), "in that order"),
    # adlc-argo-wf!84 and the octopus interactive layout
    (lambda b: b + "\nVerdict preview — not yet posted (needs your confirm)\n", "interactive hand-off"),
    (lambda b: b + "\n## Proposed comments (nothing posted yet)\n", "interactive hand-off"),
    (lambda b: b.replace(" iter=0", ""), "tokens must be exactly"),
    (lambda b: b.replace(HEAD, HEAD.upper()), "lowercase 40-character"),
    (lambda b: b + "\n" + b.splitlines()[0] + "\n", "found 2"),
]


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("mutate, why", DRIFT, ids=[
    "run-mr-1335", "run-factory-review-1332", "run-local", "findings-mismatch", "outcome-contradiction",
    "outcome-line-differs", "nit-count", "empty-section", "marker-on-line-5", "no-verdict-heading",
    "duplicate-heading", "order", "preview-wording", "proposed-comments", "missing-token", "uppercase-head",
    "two-markers"])
def test_drifted_bodies_fail_the_lint(tmp_path, interpreter, mutate, why):
    r = lint(tmp_path, mutate(body(marker(0, 1), 0, 1)), interpreter=interpreter)
    assert r.returncode == 1 and why in r.stdout, r.stdout + r.stderr


# ── quoted text is not hand-off wording (SF-FIX-11) ─────────────────────────

# A review of a skill or doc file quotes its lines. octopus-next's own review
# skill has a step that is literally "**Proposed comments**", so any MR that
# touches it was refused with: phrasing: interactive hand-off text "Proposed comments".
QUOTED = [
    ("fenced", "The skill says:\n\n```markdown\n6. **Proposed comments** — nothing posted yet\n```\n"),
    ("tilde-fence", "~~~\nVerdict preview — not yet posted (needs your confirm)\n~~~\n"),
    ("block-quote", "> 6. **Proposed comments**: post all critical comments when asked\n"),
    ("nested-block-quote", "- the file says:\n  > not yet posted\n"),
    ("code-span", "Step 6 is titled `Proposed comments`; rename it, and drop ``nothing posted yet``.\n"),
]


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("quote", [q[1] for q in QUOTED], ids=[q[0] for q in QUOTED])
def test_quoted_hand_off_text_passes_the_lint(tmp_path, interpreter, quote):
    text = body(marker(0, 1), 0, 1).replace("### N0 — y\nwhy\n", "### N0 — y\n" + quote)
    r = lint(tmp_path, text, interpreter=interpreter)
    assert r.returncode == 0, r.stdout + r.stderr


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("own_words", [
    "## Proposed comments\n",                                   # the interactive layout as a heading
    "Verdict preview — not yet posted (needs your confirm)\n",  # plain prose
    "```\ncode\n```\n\nNothing posted yet.\n",                # prose after a closed fence
    "A quote `x` and then: post all comments?\n",               # prose next to a code span
])
def test_hand_off_text_in_the_reviewers_own_words_still_fails(tmp_path, interpreter, own_words):
    r = lint(tmp_path, body(marker(0, 1), 0, 1) + "\n" + own_words, interpreter=interpreter)
    assert r.returncode == 1 and "interactive hand-off" in r.stdout, r.stdout + r.stderr
    # The refusal says how to cite such a line without tripping the check.
    assert "code span" in r.stdout


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_sub_heading_inside_a_finding_names_the_fix(tmp_path, interpreter):
    """`### Evidence` inside a finding counts as a second finding; the lint
    line now says to use `####` there, so the reviewer can repair the body."""
    text = body(marker(0, 1), 0, 1).replace("### N0 — y\nwhy\n", "### N0 — y\nwhy\n\n### Evidence\nlog line\n")
    r = lint(tmp_path, text, interpreter=interpreter)
    assert r.returncode == 1 and '2 "### " finding(s) under "## Nits" but nits=1' in r.stdout
    assert '"#### "' in r.stdout
    assert lint(tmp_path, text.replace("### Evidence", "#### Evidence"), interpreter=interpreter).returncode == 0


# ── twins and compatibility ─────────────────────────────────────────────────

def _embedded_js(path, opener, closer):
    return path.read_text(encoding="utf-8").split(opener, 1)[1].split(closer, 1)[0]


def test_both_twins_embed_the_same_checks():
    assert _embedded_js(SCRIPT, "VERDICT_JS='\n", "\n'\n") == _embedded_js(PS_SCRIPT, "$verdictJs = @'\n", "\n'@")


@needs_pwsh
@pytest.mark.requires_bash
@pytest.mark.parametrize("mutate", [lambda b: b] + [d[0] for d in DRIFT])
def test_powershell_twin_lints_like_bash(tmp_path, mutate):
    text = mutate(body(marker(0, 1), 0, 1))
    a, b = lint(tmp_path, text, "bash"), lint(tmp_path, text, "pwsh")
    assert (a.returncode, a.stdout) == (b.returncode, b.stdout)


@pytest.mark.requires_bash
@needs_node
@pytest.mark.skipif(shutil.which("jq") is None, reason="check-verdict-head.sh needs jq")
@pytest.mark.parametrize("imp, rc", [(0, 0), (1, 1)])
def test_generated_verdicts_satisfy_check_verdict_head(tmp_path, imp, rc):
    f = tmp_path / "verdicts.txt"
    f.write_text(body(marker(imp, 1), imp, 1), encoding="utf-8")
    r = subprocess.run(["bash", str(CHECKER), "--verdicts", str(f), "--pr-head", HEAD, "--require-outcome"],
                       capture_output=True, text=True)
    assert r.returncode == rc, r.stdout + r.stderr


def test_skill_tells_the_reviewer_to_generate_the_marker():
    text = SKILL.read_text(encoding="utf-8")
    step5 = text[text.index("5. Once all passes are complete"):text.index("6. Set the PR label")]
    assert "verdict-schema.sh marker" in step5 and "never type the marker" in step5
    assert "verdict-schema.sh lint" in step5 and "run=mr-<iid>" in step5
    assert "printed by `scripts/bash/verdict-schema.sh marker` (never typed)" in text
