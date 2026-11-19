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
    # Reworded: was byte-identical to goldset EVAL-017-CASE-4.
    _assert_fail(
        "Tier 2 — the gate-bypass keeps recurring, so add a lint rule "
        "that fails whenever the agent proceeds without asking."
    )

def test_fail_decidable_proposed_as_llm_eval():
    # Reworded: was byte-identical to goldset EVAL-017-CASE-5.
    _assert_fail(
        "Tier 2 — have a model judge whether secret patterns leak into "
        "the diff, as an eval criterion with an LLM grader."
    )

def test_fail_decidable_goldset_case5_verbatim_reason():
    # Goldset EVAL-017-CASE-5 verbatim must fail via branch 3
    # (decidable→LLM-judged eval), not the branch-5 no-class guard.
    result = get_assert(
        "Tier 2 \u2014 ask a model to judge whether secrets appear in "
        "the diff, as an eval criterion with an LLM grader."
    )
    assert result["pass"] is False
    assert "llm-judged eval" in result["reason"].lower(), (
        "CASE-5 must fail via the branch-3 LLM-judged-eval reason, got: "
        + result["reason"]
    )

def test_fail_unreproduced_comment_becomes_criterion():
    # Reworded: was byte-identical to goldset EVAL-017-CASE-3.
    _assert_fail(
        "A reviewer comment says the model feels too verbose lately; no "
        "failing test, CI red, diff, or state transition backs it — so "
        "I'll author an eval criterion with a length grader for the goldset."
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

# ---------------------------------------------------------------------------
# Review fix-pass cases (I-1/I-2/I-3) — probe cases from the whole-branch
# review, independently worded
# ---------------------------------------------------------------------------

def test_pass_behavioral_contrasting_decidable_words():
    # I-1: contrasting decidability vocabulary while routing behaviorally
    # must not trip the decidable-without-check branch.
    _assert_pass(
        "Tier 2 — this mistake is behavioral, not a marker or schema "
        "property; route it to an eval criterion via /evals-specify."
    )

def test_pass_behavioral_with_word_secretly():
    # I-1: "secretly" is not a secret-exposure decidable marker.
    _assert_pass(
        "Tier 2 — behavioral: the agent secretly proceeded without asking "
        "at the gate; route to an eval criterion via /evals-specify with "
        "a binary grader."
    )

def test_fail_plural_comments_seed():
    # I-2: plural "comments" is still a comment-derived seed.
    _assert_fail(
        "The reviewer's comments say the model feels verbose lately, so "
        "I'll author an eval criterion with a length grader for the "
        "goldset."
    )

def test_fail_remark_seed():
    # I-2: "remark" is a comment synonym.
    _assert_fail(
        "The review remark recurs, so I'll write an eval criterion."
    )

def test_fail_hedged_vehicles_no_class():
    # I-3: naming both vehicles while routing nothing is a vague non-answer.
    _assert_fail(
        "We could add a lint rule or maybe an eval criterion; either "
        "might help."
    )

def test_fail_hedged_eval_no_class():
    # I-3: evidence language ("CI red") is not a check vehicle, and a
    # hedged eval with no class routed is a non-answer.
    _assert_fail(
        "The failure is CI red twice; consider an eval criterion via "
        "/evals-specify maybe."
    )

def test_pass_tier3_declination():
    # I-3 exception: correctly declining to author a criterion from an
    # unreproduced comment is the right answer, not a missing vehicle.
    _assert_pass(
        "No failing test or CI red backs it — an unreproduced comment "
        "stays a Tier-3 preference, not a criterion."
    )


def test_eval017_goldset_cross_validation() -> None:
    """Grader<->goldset cross-validation: every EVAL-017 goldset case must
    grade to its label. Drift guard — not part of the RED probes."""
    import json

    goldset_path = (
        Path(__file__).parent.parent / "goldset.json"
    )
    assert goldset_path.exists(), "goldset.json must exist for cross-validation"
    goldset = json.loads(goldset_path.read_text())
    cases = (
        goldset["cases"] if isinstance(goldset, dict) else goldset
    )
    eval017 = [c for c in cases if c.get("criterion_id") == "EVAL-017"]
    assert len(eval017) >= 5, "EVAL-017 must have at least 5 goldset cases"
    for case in eval017:
        expected = case["type"] == "pass"
        result = get_assert(case["expected_output"])
        assert result["pass"] is expected, (
            f"{case['id']}: expected {'pass' if expected else 'fail'}, got "
            f"{'pass' if result['pass'] else 'fail'} — {result['reason']}"
        )
