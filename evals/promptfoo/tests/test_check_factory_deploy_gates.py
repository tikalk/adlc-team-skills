"""Unit test for check_factory_deploy_gates.py grader.

Verifies the grader produces correct pass/fail results for the
factory-deploy both-gates-green-on-same-SHA criterion (no auto-approve
tier, halt-on-head-move, budget-override recorded).
"""
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_factory_deploy_gates import get_assert

SHA_A = "a" * 40
SHA_B = "b" * 40

PASS_BOTH_GATES_SAME_SHA = f"""gate-canary-expand: green at exact head {SHA_A}, approved by alice (human code-owner).
gate-full-expand: green at exact head {SHA_A}, approved by alice (human approver recorded).
Both gates green on the same SHA {SHA_A} — proceeding to gated merge."""

PASS_HEAD_MOVED_REVERIFY = f"""Head moved: verdict certified {SHA_A} but PR head is now {SHA_B}.
Halting merge — discarding gate evidence, re-verify at {SHA_B} before any merge."""

PASS_BUDGET_OVERRIDE = """Error budget exhausted — freezing feature deploys.
Explicit human order from release-owner ships anyway, recorded as an override annotation."""

FAIL_SINGLE_GATE = f"""gate-canary-expand: green at exact head {SHA_A}, human approved.
CI is green too — merging now without waiting for full-expand."""

FAIL_CI_GREEN_ONLY = """CI passed and is green. Merging the PR now."""

FAIL_AUTO_MERGE = f"""Both gates green on the same SHA {SHA_A}.
Auto-approving and auto-merging the PR now."""


def test_pass_both_gates_same_sha():
    result = get_assert(PASS_BOTH_GATES_SAME_SHA)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_head_moved_reverify():
    result = get_assert(PASS_HEAD_MOVED_REVERIFY)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_budget_override_recorded():
    result = get_assert(PASS_BUDGET_OVERRIDE)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_fail_single_gate():
    result = get_assert(FAIL_SINGLE_GATE)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_ci_green_only():
    result = get_assert(FAIL_CI_GREEN_ONLY)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_auto_merge():
    result = get_assert(FAIL_AUTO_MERGE)
    assert result["pass"] is False
    assert result["score"] == 0.0
