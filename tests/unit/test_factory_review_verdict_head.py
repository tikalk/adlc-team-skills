"""The factory-review verdict must name the head it certifies — and be checkable.

A verdict certifies exactly one head SHA. A fix push moves the head and
invalidates the verdict, so the review has to run again before
merge-readiness is claimed. The rule is stated in the skill; these tests pin
both halves of it:

  * the marker the skill tells the reviewer to post actually carries
    ``head=<sha>`` — without it the verdict certifies nothing, and
  * the checker that enforces it exists, behaves correctly, and is wired
    into CI.
"""

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review"
SKILL_MD = SKILL / "SKILL.md"
LOOP_MD = SKILL / "references/review-loop.md"
CHECKER = SKILL / "scripts/check-verdict-head.sh"
WORKFLOW = ROOT / ".github/workflows/verdict-head.yml"

MARKER = "factory-review:step=review"


def run_checker(tmp_path, bodies, pr_head):
    """Run the checker over a fixture of comment bodies; return (rc, output)."""
    fixture = tmp_path / "verdicts.txt"
    fixture.write_text(bodies, encoding="utf-8")
    proc = subprocess.run(
        ["bash", str(CHECKER), "--verdicts", str(fixture), "--pr-head", pr_head],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return proc.returncode, proc.stdout + proc.stderr


def verdict(head, extra=""):
    return (
        f"<!-- {MARKER} run=r1 iter=0 status=completed findings=1 "
        f"important=0 nits=1 {extra}head={head} -->\nA review comment.\n"
    )


def review_marker_templates(text):
    """Every review marker template in the text, joined across wrapped lines.

    The skill's diagram wraps the marker over two lines to fit the box, so
    the template has to be re-joined before it can be read as a marker.
    """
    joined = re.sub(r"\s*\n\s*", " ", text)
    return [m for m in re.findall(r"<!--.*?-->", joined) if MARKER in m]


# ── the marker the skill tells the reviewer to post ────────────────────────

def test_skill_marker_template_carries_the_head():
    content = SKILL_MD.read_text(encoding="utf-8")
    templates = review_marker_templates(content)
    assert templates, "the skill must show the review marker template"
    for template in templates:
        assert "head=" in template, (
            "the review marker template must carry the head it certifies: "
            f"{template.strip()}"
        )


def test_review_loop_marker_template_carries_the_head():
    content = LOOP_MD.read_text(encoding="utf-8")
    templates = review_marker_templates(content)
    assert templates, "the review-loop reference must show the review marker"
    for template in templates:
        assert "head=" in template, (
            f"the review marker must carry the head it certifies: {template.strip()}"
        )


def test_skill_states_the_rule_and_names_the_checker():
    content = SKILL_MD.read_text(encoding="utf-8")
    assert "Re-review after any fix push" in content, (
        "the skill must state the re-review-after-fix rule"
    )
    assert "head=<sha>" in content, "the skill must require the head in the marker"
    assert "check-verdict-head.sh" in content, (
        "the skill must name the checker that enforces the rule"
    )


# ── the checker ───────────────────────────────────────────────────────────

def test_checker_exists_and_is_executable():
    assert CHECKER.exists(), f"the verdict checker is missing at {CHECKER}"
    assert os.access(CHECKER, os.X_OK), "the checker must be executable"


def test_verdict_naming_the_current_head_passes(tmp_path):
    rc, out = run_checker(tmp_path, verdict("a" * 40), "a" * 40)
    assert rc == 0, out
    assert "OK" in out


def test_verdict_on_a_moved_head_fails(tmp_path):
    rc, out = run_checker(tmp_path, verdict("a" * 40), "b" * 40)
    assert rc == 1, out
    assert "FAIL" in out
    assert "a" * 40 in out and "b" * 40 in out, "the failure must name both heads"


def test_no_verdict_is_not_a_failure(tmp_path):
    rc, out = run_checker(tmp_path, "A human comment with no marker.\n", "a" * 40)
    assert rc == 0, out
    assert "nothing to verify" in out


def test_verdict_without_a_head_fails(tmp_path):
    """A verdict that names no head certifies nothing — it must not pass."""
    body = f"<!-- {MARKER} run=r1 iter=0 status=completed findings=0 important=0 nits=0 -->\n"
    rc, out = run_checker(tmp_path, body, "a" * 40)
    assert rc == 1, out
    assert "names no head" in out


def test_the_newest_verdict_wins(tmp_path):
    """An older verdict must not mask a newer one."""
    bodies = (
        verdict("a" * 40)
        + "%%%\n"
        + verdict("b" * 40)
    )
    rc, out = run_checker(tmp_path, bodies, "a" * 40)
    assert rc == 1, out
    assert "b" * 40 in out, "the newest verdict is the one that counts"

    rc, out = run_checker(tmp_path, bodies, "b" * 40)
    assert rc == 0, out


def test_non_verdict_markers_are_ignored(tmp_path):
    """A fix or converge marker is not a verdict — it must not be read as one."""
    bodies = (
        "<!-- factory-review:step=fix run=r1 iter=0 status=completed fixed=1 "
        "new_head_sha=" + "c" * 40 + " ci_status=pass -->\nA fix.\n"
        + "%%%\n"
        + verdict("a" * 40)
    )
    rc, out = run_checker(tmp_path, bodies, "a" * 40)
    assert rc == 0, out


def test_a_stale_fix_marker_does_not_satisfy_the_check(tmp_path):
    """Only the review verdict certifies; a fix marker never does."""
    bodies = (
        "<!-- factory-review:step=fix run=r1 iter=0 status=completed fixed=1 "
        "new_head_sha=" + "b" * 40 + " ci_status=pass -->\nA fix.\n"
    )
    rc, out = run_checker(tmp_path, bodies, "b" * 40)
    assert rc == 0, out
    assert "nothing to verify" in out


def test_missing_pr_head_is_a_usage_error(tmp_path):
    proc = subprocess.run(
        ["bash", str(CHECKER), "--verdicts", str(tmp_path / "nope.txt")],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 2, proc.stdout + proc.stderr


# ── CI wiring ─────────────────────────────────────────────────────────────

def test_ci_workflow_runs_the_checker():
    assert WORKFLOW.exists(), f"the CI workflow is missing at {WORKFLOW}"
    content = WORKFLOW.read_text(encoding="utf-8")
    assert "check-verdict-head.sh" in content, "the workflow must run the checker"
    assert "pull_request" in content, "the workflow must run on pull requests"
    assert "synchronize" in content, (
        "the workflow must re-run when the head moves — that is the whole point"
    )
    assert "pull-requests: read" in content, "the workflow must stay read-only"
