"""Unit test for check_diagnosing_evidence_first.py grader.

Verifies the grader produces correct pass/fail results for the
diagnosing-team-skills evidence-first criterion (EVAL-013).
"""
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_diagnosing_evidence_first import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_CHAIN = """Diagnosis plan, evidence first:
1. cat .adlc/init-options.json — confirm team_ai_directives points at a real dir
2. command -v jq — the skills registry section needs it
3. bash .agents/skills/team-boot/scripts/boot.sh from the project root —
   expect the index on stdout; capture the output
If all green but the session lacks context, the injection side failed —
file in adlc-cli with these outputs attached."""


def test_pass_full_chain():
    """Concrete chain checks before any conclusion passes."""
    result = get_assert(PASS_CHAIN)
    assert result["pass"] is True
    assert result["score"] == 1.0


PASS_ACCEPTANCE = """Run scripts/acceptance-test.sh first — it scratch-installs
and asserts the whole chain. If it passes, check jq and init-options.json
manually for the live project's config."""


def test_pass_acceptance_script():
    """Naming the acceptance script + checks passes."""
    result = get_assert(PASS_ACCEPTANCE)
    assert result["pass"] is True


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_GENERIC = """Looks like a bad install. Reinstall the skills, restart
your agent, and try again — that usually fixes it."""


def test_fail_generic_advice():
    """Generic reinstall advice with no chain checks fails."""
    result = get_assert(FAIL_GENERIC)
    assert result["pass"] is False
    assert "fewer than 2 concrete chain checks" in result["reason"]


FAIL_REINSTALL_FIRST = """Try reinstalling first: npx adlc-cli skill add ...
If that doesn't help, run boot.sh and check init-options.json."""


def test_fail_remediation_before_evidence():
    """Remediation offered before any evidence fails."""
    result = get_assert(FAIL_REINSTALL_FIRST)
    assert result["pass"] is False
    assert "before any concrete check" in result["reason"] or "evidence must come first" in result["reason"]


def test_fail_empty_output():
    """Empty output fails."""
    result = get_assert("")
    assert result["pass"] is False


def test_pass_negated_remediation_is_compliant():
    """"Don't restart yet — first check…" orders evidence first and must not
    be flagged as generic remediation (review finding #7)."""
    result = get_assert(
        "Don't restart yet — first check init-options.json exists, then run "
        "boot.sh and capture the output."
    )
    assert result["pass"] is True, result["reason"]
