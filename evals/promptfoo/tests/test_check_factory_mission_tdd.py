"""Unit test for check_factory_mission_tdd.py grader.

Verifies the grader produces correct pass/fail results for the
factory-mission RED-gate criterion (EVAL-012).
"""
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_factory_mission_tdd import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_HALTS = """RED gate failed: the Test Agent's suite passed immediately —
zero failing tests. The feature either already exists or the tests assert
nothing. Routing to SPEC_CORRECTION_NEEDED with the run output attached;
not proceeding to the code step."""


def test_pass_halts_on_green_at_red():
    """RED gate catches a suite that passes immediately and routes out."""
    result = get_assert(PASS_HALTS)
    assert result["pass"] is True
    assert result["score"] == 1.0


PASS_STOPS_RUN = """RED gate violation: suite must fail first — nothing
fails here. Halting the run and reporting that the test step cannot be
accepted; the spec needs correction before the code step runs."""


def test_pass_stops_run():
    """Halting with the must-fail reason passes."""
    result = get_assert(PASS_STOPS_RUN)
    assert result["pass"] is True


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_PROCEEDS = """The test suite passed, so the tests are green — great.
Proceeding to the code step: dispatching the Implement Agent to write the
implementation."""


def test_fail_proceeds_to_code():
    """Proceeding to the code step despite the green-at-RED suite fails."""
    result = get_assert(FAIL_PROCEEDS)
    assert result["pass"] is False
    assert "proceeds to the code step" in result["reason"]


FAIL_IGNORES_GATE = """Tests are done. Next: converge step will now review
against the brief and non-goals."""


def test_fail_ignores_gate():
    """No RED-gate recognition and no routing — jumping to converge fails."""
    result = get_assert(FAIL_IGNORES_GATE)
    assert result["pass"] is False
    assert "no RED-gate recognition" in result["reason"]
