"""Unit test for check_universal_skill_routing.py grader.

Verifies the grader produces correct pass/fail results against goldset examples.
This follows the evals-implement Phase 2 closed-loop self-tuning pattern.

Contract (harness-native skill routing): delegation prompts name skills by
exact name and direct the subagent to resolve them through its own Skill
tool, with the commands-dir fallback for commands-based frameworks. Scanned
"Available Skills in This Workspace" inventories are the removed mechanism
and must fail.
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

PASS_OUTPUT_1 = """Step: Implement the retry logic. Use the `tdd` skill for this step —
resolve it via your own Skill tool. If the target framework is
commands-based, check the commands dir per `agent-integrations.md`;
an absent commands dir means the step executes directly.
"""

PASS_OUTPUT_2 = """Use the `evals-validate` skill — the subagent resolves it via its
Skill tool. For commands-based frameworks consult agent-integrations.md;
absent commands dir means direct execution.
"""

# Minimal but compliant — exact skill name, Skill-tool resolution, fallback
PASS_OUTPUT_3 = """Run the `tdd` skill (resolve via your Skill tool).
Commands-based framework? Check the commands dir; absent means execute directly.
"""


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

# Removed mechanism: scanned inventory (old EVAL-005 pass output)
FAIL_OUTPUT_1 = """## Available Skills in This Workspace

- **tdd** (`.claude/skills/tdd`) — Test-driven development with red-green-refactor loop
- **grill-me** (`.claude/skills/grill-me`) — Get relentlessly interviewed about a plan
- **code-review** (`.claude/skills/code-review`) — Two-axis review of the diff

The list above shows skills installed in this workspace from any source.
Review each skill's name and description. If one matches the goal of your
current task, invoke it (via the skill tool or by reading its SKILL.md inline).
If none apply, proceed with direct execution.
"""

FAIL_OUTPUT_2 = """Phase implement maps to skill tdd.
Phase converge maps to skill code-review.
Execute the mapped skill for this phase.
"""

FAIL_OUTPUT_3 = """No skill named for this step. Just implement the task directly.
"""


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_pass_case_1():
    """EVAL-005-CASE-1: exact-name delegation with Skill-tool resolution passes."""
    result = get_assert(PASS_OUTPUT_1)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_case_2():
    """Single exact-named skill with Skill-tool resolution + fallback passes."""
    result = get_assert(PASS_OUTPUT_2)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_case_3():
    """Minimal compliant output passes."""
    result = get_assert(PASS_OUTPUT_3)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_fail_case_1():
    """The removed scanned-inventory mechanism fails."""
    result = get_assert(FAIL_OUTPUT_1)
    assert result["pass"] is False
    assert result["score"] == 0.0
    reason = result["reason"].lower()
    assert "scanned" in reason or "inventory" in reason, result["reason"]


def test_fail_case_2():
    """Hard-coded phase-to-skill mapping fails."""
    result = get_assert(FAIL_OUTPUT_2)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "hard-coded" in result["reason"].lower() or "mapping" in result["reason"].lower()


def test_fail_case_3():
    """No skill named by exact name fails."""
    result = get_assert(FAIL_OUTPUT_3)
    assert result["pass"] is False
    assert result["score"] == 0.0
