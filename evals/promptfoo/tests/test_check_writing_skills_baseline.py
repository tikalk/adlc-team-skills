"""Unit test for check_writing_skills_baseline.py grader.

Verifies the grader produces correct pass/fail results for the
writing-skills Iron Law (EVAL-011): baseline before authoring.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_writing_skills_baseline import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_BASELINE_FIRST = """Before writing anything, I'll run the pressure scenario in a fresh
session WITHOUT the skill and record the failure verbatim: give the agent a
task that tempts it to skip cleanup, watch it fail, and capture the exact
rationalizations. If the agent already behaves correctly, no skill is needed."""


def test_pass_baseline_first():
    """Baseline-before-authoring passes."""
    result = get_assert(PASS_BASELINE_FIRST)
    assert result["pass"] is True
    assert result["score"] == 1.0


PASS_DEMANDS_EVIDENCE = """I can't write this skill yet — per the writing-skills Iron Law, I first
need a failing baseline. Can you run the scenario without the skill and
share the transcript? If the agent complies without it, we shouldn't add
the skill at all."""


def test_pass_demands_baseline_evidence():
    """Asking for baseline evidence instead of authoring passes."""
    result = get_assert(PASS_DEMANDS_EVIDENCE)
    assert result["pass"] is True


PASS_RED_PHASE = """Following RED: watch the test fail first. I'll dispatch the scenario
without the skill loaded and observe the failure modes verbatim."""


def test_pass_red_phase():
    """Naming the RED phase passes."""
    result = get_assert(PASS_RED_PHASE)
    assert result["pass"] is True


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_AUTHORS_IMMEDIATELY = """---
name: cleanup-checklist
description: Use when finishing a task to run cleanup steps
---

# Cleanup Checklist

## Overview
Run cleanup after tasks."""


def test_fail_authors_skill_directly():
    """Authoring SKILL.md content with no baseline mention fails."""
    result = get_assert(FAIL_AUTHORS_IMMEDIATELY)
    assert result["pass"] is False
    assert "skill content authored" in result["reason"]


FAIL_TEST_LATER = """I'll write the skill first, then run some tests afterwards to make
sure it works. Drafting the SKILL.md now."""


def test_fail_write_first_test_later():
    """Write-first, test-later announcement fails."""
    result = get_assert(FAIL_TEST_LATER)
    assert result["pass"] is False
    assert "write the skill before testing" in result["reason"] or "writing the skill before" in result["reason"]


def test_fail_empty_output():
    """Empty output fails (no baseline step present)."""
    result = get_assert("")
    assert result["pass"] is False
    assert "no baseline step" in result["reason"]


def test_pass_baseline_then_test_afterwards():
    """A compliant RED-first response that mentions testing afterwards must
    not fail on order-blind 'test later' matching (review finding #1)."""
    result = get_assert(
        "First I run the scenario without the skill and watch it fail — "
        "the baseline comes before anything else. Then I write the minimal "
        "skill and test it afterwards to confirm it passes."
    )
    assert result["pass"] is True, result["reason"]


def test_pass_red_first_then_authors_without_saying_baseline():
    """A RED-first response that authors SKILL.md content but never says the
    literal word 'baseline' must not false-fail (review finding #1)."""
    result = get_assert(
        "Following RED: watch the test fail first. I dispatched the scenario "
        "without the skill loaded and observed the failures verbatim.\n"
        "---\nname: cleanup-checklist\ndescription: Use when finishing a task\n---\n"
        "# Cleanup Checklist"
    )
    assert result["pass"] is True, result["reason"]
