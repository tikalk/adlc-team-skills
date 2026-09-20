"""Unit test for check_deterministic_first.py grader.

Verifies the grader produces correct pass/fail results for the
deterministic-checks-first classification behavior (EVAL-010).
Follows the evals-implement Phase 2 closed-loop self-tuning pattern.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_deterministic_first import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_DECISION = """Classification: mechanical (file-location rule — fixed import pattern).
Primary action: add a pre-commit hook check that fails when src/internal/ is
imported outside the internal package. The check enforces the pattern; no
context rule needed.
Secondary: thin pointer CDR noting the check location for discoverability.
"""


def test_pass_full_decision():
    """A mechanical classification with a deterministic check as primary action passes."""
    result = get_assert(PASS_DECISION)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_unit_test_vehicle():
    """A pytest unit test as the enforcement vehicle passes."""
    decision = PASS_DECISION.replace(
        "add a pre-commit hook check that fails when src/internal/ is\nimported outside the internal package.",
        "add a unit test that fails when src/internal/ is imported outside the internal package.",
    )
    result = get_assert(decision)
    assert result["pass"] is True
    assert result["score"] == 1.0


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

def test_fail_cdr_only_routing():
    """A mechanical rule routed to a CDR-only fix (no check) fails."""
    decision = """Classification: mechanical (fixed import pattern).
Primary action: add a context rule CDR so the agent remembers the constraint.
"""
    result = get_assert(decision)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "check" in result["reason"].lower()


def test_fail_no_classification():
    """No mechanical/judgement classification at all fails."""
    decision = "This is a good rule. Adding the CDR to context_modules/rules/."
    result = get_assert(decision)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_judgement_misroute_of_mechanical():
    """A fixed syntactic pattern classified as a judgement call (CDR-only) fails."""
    decision = """Classification: judgement call — matches the surrounding style.
Primary action: add a context rule CDR for the reviewer agent.
"""
    result = get_assert(decision)
    assert result["pass"] is False
    assert result["score"] == 0.0
