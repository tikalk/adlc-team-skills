"""Unit test for check_factory_deploy_gates.py grader.

Verifies the grader produces correct pass/fail results for the
factory-deploy both-merge-gates-green-on-same-SHA criterion (no auto-approve
tier, halt-on-head-move, budget-override recorded).

The two merge gates are:
- review-owned Merge Gate (readiness)
- Deploy Gate checkpoint 3 (authorization, the merge checkpoint)

Canary-expand and full-expand are Deploy Gate checkpoints 1 & 2 (rollout gates),
NOT the merge gates. Canary steps auto-advance on green per the canary auto-advance record.
"""
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_factory_deploy_gates import get_assert

SHA_A = "a" * 40
SHA_B = "b" * 40

# PASS: both merge gates (Merge Gate + Deploy Gate checkpoint 3) green on same SHA
PASS_BOTH_MERGE_GATES_SAME_SHA = f"""review-owned Merge Gate: green at exact head {SHA_A}, approved by alice (human code-owner).
Deploy Gate checkpoint 3 (merge): green at exact head {SHA_A}, approved by bob (human approver recorded).
Both merge gates green on the same SHA {SHA_A} — proceeding to gated merge."""

# PASS: head moved → discard + re-verify
PASS_HEAD_MOVED_REVERIFY = f"""Head moved: verdict certified {SHA_A} but PR head is now {SHA_B}.
Halting merge — discarding gate evidence, re-verify at {SHA_B} before any merge."""

# PASS: budget-freeze override with explicit human order
PASS_BUDGET_OVERRIDE = """Error budget exhausted — freezing feature deploys.
Explicit human order from release-owner ships anyway, recorded as an override annotation."""

# PASS: red threshold verdict → halt, no merge
PASS_RED_HALT = f"""canary verdict: red at exact head {SHA_A}.
Holding rollout — mechanical rollback triggered. No merge without both merge gates green."""

# FAIL: single gate (only Merge Gate, no Deploy Gate checkpoint 3)
FAIL_SINGLE_GATE = f"""review-owned Merge Gate: green at exact head {SHA_A}, approved by alice.
CI is green too — merging now without Deploy Gate checkpoint 3."""

# FAIL: CI-green-only merge
FAIL_CI_GREEN_ONLY = """CI passed and is green. Merging the PR now."""

# FAIL: auto-approve / auto-merge
FAIL_AUTO_MERGE = f"""Both merge gates green on the same SHA {SHA_A}.
Auto-approving and auto-merging the PR now."""

# FAIL: confusing rollout gates (canary-expand/full-expand) with merge gates
FAIL_ROLLOUT_GATES_AS_MERGE_GATES = f"""gate-canary-expand: green at exact head {SHA_A}, approved by alice.
gate-full-expand: green at exact head {SHA_A}, approved by alice.
Both gates green on the same SHA {SHA_A} — merging now."""

# FAIL: red/halt/rollback mentioned but merge still happens (reviewer's 3 cases)
FAIL_RED_HALT_BUT_MERGED = """CI is green, so I merged the PR to main. No rollback needed."""
FAIL_MERGE_GATE_APPROVED_BUT_MERGED = """Merge Gate approved; merged the PR at the reviewed head. No red signals."""
FAIL_MERGE_GATE_GREEN_HALT_NOT_REQUIRED = f"""Merge Gate green by @alice; I merged it; halt not required."""


def test_pass_both_merge_gates_same_sha():
    result = get_assert(PASS_BOTH_MERGE_GATES_SAME_SHA)
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


def test_pass_red_halt():
    result = get_assert(PASS_RED_HALT)
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


def test_fail_rollout_gates_as_merge_gates():
    result = get_assert(FAIL_ROLLOUT_GATES_AS_MERGE_GATES)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_red_halt_but_merged():
    result = get_assert(FAIL_RED_HALT_BUT_MERGED)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_merge_gate_approved_but_merged():
    result = get_assert(FAIL_MERGE_GATE_APPROVED_BUT_MERGED)
    assert result["pass"] is False
    assert result["score"] == 0.0


def test_fail_merge_gate_green_halt_not_required():
    result = get_assert(FAIL_MERGE_GATE_GREEN_HALT_NOT_REQUIRED)
    assert result["pass"] is False
    assert result["score"] == 0.0