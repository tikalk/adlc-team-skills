"""Unit test for check_eval_seed_routing.py grader.

Verifies the grader produces correct pass/fail results for the Tier-2
split and eval-seed admissibility check (EVAL-017).

Scope: EVAL-017 evaluates class-to-vehicle consistency — a decidable
property routes to a deterministic check, a behavioral property routes to
an eval criterion — and rejects unreproduced comment-derived seeds.
Adversarial strings are independently worded (never copied from
goldset.json) so the tests cannot pass by memorising gold phrasing.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_eval_seed_routing import get_assert


def _assert_fail(decision: str) -> None:
    result = get_assert(decision)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "failed" in result["reason"].lower()


def _assert_pass(decision: str) -> None:
    result = get_assert(decision)
    assert result["pass"] is True
    assert result["score"] == 1.0


# ---------------------------------------------------------------------------
# Pass cases — independently worded, never goldset copies
# ---------------------------------------------------------------------------

def test_pass_decidable_routes_to_check():
    _assert_pass(
        "Tier 2 — the missing release marker is decidable from the artifact: "
        "every verdict must carry head=<sha>. Add a deterministic check — "
        "extend the CI job plus a unit test asserting the marker exists. "
        "Seed reproduced: failing runs recorded in two distinct run states."
    )

def test_pass_behavioral_routes_to_eval():
    _assert_pass(
        "Tier 2 — behavioral: whether the agent asks before acting at the "
        "escalation gate is a distribution over model behavior. Route to an "
        "eval criterion via /evals-specify with a binary behavioral grader; "
        "the seed is reproduced (recorded state transitions in two runs)."
    )

def test_pass_decidable_schema_check():
    _assert_pass(
        "Decidable property: the config schema must validate on every "
        "change. Enforcement: schema validation in a pre-commit hook. "
        "Reproduction: CI red twice, in two separate runs."
    )

# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

def test_fail_behavioral_proposed_as_lint():
    _assert_fail(
        "Tier 2 — add a lint rule that fails when the agent did not stop "
        "at the gate."
    )

def test_fail_decidable_proposed_as_llm_eval():
    _assert_fail(
        "Tier 2 — ask a model to judge whether secrets appear in the diff, "
        "as an eval criterion with an LLM grader."
    )

def test_fail_unreproduced_comment_becomes_criterion():
    _assert_fail(
        "Noted — the verbosity comment recurs, so I'll author an eval "
        "criterion with a length grader for the goldset."
    )

def test_fail_no_vehicle_named():
    _assert_fail(
        "This is a recurring mistake; we should handle it better going "
        "forward."
    )

def test_fail_check_grading_behavior_with_reproduction_stated():
    # Reproduction evidence alone does not save a wrong class-to-vehicle map.
    _assert_fail(
        "The gate-bypass behavior reproduced in two runs (recorded state "
        "transitions). Tier 2 — add a unit test that fails when the agent "
        "proceeded without asking at the gate."
    )
