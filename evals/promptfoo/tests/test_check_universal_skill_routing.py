"""Unit test for check_universal_skill_routing.py grader.

Verifies the grader produces correct pass/fail results against goldset examples.
This follows the evals-implement Phase 2 closed-loop self-tuning pattern.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_universal_skill_routing import get_assert


# ---------------------------------------------------------------------------
# Pass cases (from goldset EVAL-005-CASE-1)
# ---------------------------------------------------------------------------

PASS_OUTPUT_1 = """## Available Skills in This Workspace

- **tdd** (`.claude/skills/tdd`) — Test-driven development with red-green-refactor loop
- **grill-me** (`.claude/skills/grill-me`) — Get relentlessly interviewed about a plan
- **code-review** (`.claude/skills/code-review`) — Two-axis review of the diff

The list above shows skills installed in this workspace from any source.
Review each skill's name and description. If one matches the goal of your
current task, invoke it (via the skill tool or by reading its SKILL.md inline).
If none apply, proceed with direct execution.
"""

PASS_OUTPUT_2 = """## Available Skills in This Workspace

- **evals-validate** (`.agents/skills/evals-validate`) — Run evaluation pyramid and compute metrics

Review each skill. If one matches, use it. If none apply, proceed directly.
"""

# Minimal but compliant — has available skills section + invoke instruction
PASS_OUTPUT_3 = """Available Skills: tdd, grill-me, code-review
If a skill matches your task, call the skill. Otherwise, direct execution.
"""


# ---------------------------------------------------------------------------
# Fail cases (from goldset EVAL-005-CASE-2)
# ---------------------------------------------------------------------------

FAIL_OUTPUT_1 = """Phase implement maps to skill tdd.
Phase converge maps to skill code-review.
Execute the mapped skill for this phase.
"""

FAIL_OUTPUT_2 = """No skills section here. Just implement the task directly.
"""

FAIL_OUTPUT_3 = """Here are some skills but no instruction to invoke them:
- tdd: test-driven development
- grill-me: interview about a plan
"""


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_pass_case_1():
    """EVAL-005-CASE-1: full delegation prompt with 3 skills passes."""
    result = get_assert(PASS_OUTPUT_1)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_case_2():
    """Single skill with invoke instruction + fallback passes."""
    result = get_assert(PASS_OUTPUT_2)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_case_3():
    """Minimal compliant output passes."""
    result = get_assert(PASS_OUTPUT_3)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_fail_case_1():
    """Hard-coded phase-to-skill mapping fails."""
    result = get_assert(FAIL_OUTPUT_1)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "hard-coded" in result["reason"].lower() or "mapping" in result["reason"].lower()


def test_fail_case_2():
    """Missing available skills section fails."""
    result = get_assert(FAIL_OUTPUT_2)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_case_3():
    """Skills listed but no invoke instruction fails."""
    result = get_assert(FAIL_OUTPUT_3)
    assert result["pass"] is False
    assert result["score"] == 0.0
