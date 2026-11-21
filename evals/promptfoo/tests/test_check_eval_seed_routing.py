"""Unit test for check_eval_seed_routing.py grader.

EVAL-017 grades a typed `tier2-route` decision record, not prose. The
record is the decision; surrounding prose is rationale and is not
graded. Free-form text without a record fails closed.

Scope: EVAL-017 evaluates class-to-vehicle consistency — a decidable
property routes to a deterministic check, a behavioral property routes
to an eval criterion — and rejects unreproduced comment-derived seeds.
"""
import json
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_eval_seed_routing import get_assert


def rec(routes):
    """One tier2-route record block around a routes list."""
    return "```tier2-route\n" + json.dumps({"tier": 2, "routes": routes}) + "\n```"


def route(cls, vehicle, seed, evidence=None, runs=0):
    return {
        "class": cls,
        "vehicle": vehicle,
        "seed": seed,
        "evidence": evidence or [],
        "runs": runs,
    }


def _assert_fail(decision: str, *reason_fragments: str, context=None) -> None:
    result = get_assert(decision, context)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "failed" in result["reason"].lower()
    for fragment in reason_fragments:
        assert fragment.lower() in result["reason"].lower(), (
            f"reason missing {fragment!r}: {result['reason']}"
        )


def _assert_pass(decision: str, context=None) -> None:
    result = get_assert(decision, context)
    assert result["pass"] is True
    assert result["score"] == 1.0


# ---------------------------------------------------------------------------
# Pass cases — a valid record is the decision; prose is rationale
# ---------------------------------------------------------------------------

def test_pass_decidable_routes_to_check():
    _assert_pass(
        "Tier 2 — the missing release marker is decidable from the artifact: "
        "every verdict must carry head=<sha>.\n"
        + rec([route("decidable", "check", "event-stream",
                       ["failing test", "ci red"], 2)])
    )


def test_pass_behavioral_routes_to_eval():
    _assert_pass(
        "Tier 2 — behavioral: whether the agent asks before acting at the "
        "escalation gate is a distribution over model behavior. Route to an "
        "eval criterion via /evals-specify with a binary grader; the seed "
        "is reproduced across two runs.\n"
        + rec([route("behavioral", "eval", "event-stream",
                       ["recorded state transition"], 2)])
    )


def test_pass_comment_seed_reproduced_by_artifact():
    # A comment-derived seed is admissible when the failure it describes
    # was reproduced by artifact — the taxonomy's reproduction rule.
    _assert_pass(
        "A reviewer comment said the gate was bypassed. The failure it "
        "describes reproduced in two runs (recorded state transitions), so "
        "route the behavioral bypass to an eval criterion.\n"
        + rec([route("behavioral", "eval", "comment",
                       ["recorded state transition"], 2)])
    )


def test_pass_multi_route_consistent():
    _assert_pass(
        "Two corrections. The missing marker is enforced by a "
        "required-marker check; the gate bypass is behavioral and routes "
        "to an eval criterion.\n"
        + rec([
            route("decidable", "check", "event-stream", ["failing test"], 2),
            route("behavioral", "eval", "event-stream",
                  ["recorded state transition"], 2),
        ])
    )


def test_pass_tier3_declination():
    # Declining to author a criterion from an inadmissible seed is the
    # right answer, not a missing vehicle. With no scenario context the
    # decline stands on the record alone; with a reproduced recurrence
    # in the scenario it must fail (tier-3 is not an excuse for a
    # reproduced seed).
    _assert_pass(
        "The verbosity remark recurs with nothing behind it; it stays a "
        "Tier-3 preference.\n"
        + rec([route("behavioral", "none", "tier-3")])
    )


def test_pass_tier3_declination_with_unreproduced_scenario():
    _assert_pass(
        "The verbosity remark recurs with nothing behind it; it stays a "
        "Tier-3 preference.\n"
        + rec([route("behavioral", "none", "tier-3")]),
        context={"vars": {
            "scenario": "unreproduced comment",
            "input_context": "A reviewer comment says 'the model feels "
            "too verbose lately'; no test backs it.",
        }},
    )


# ---------------------------------------------------------------------------
# Fail cases — wrong mapping, inadmissible seed, malformed record
# ---------------------------------------------------------------------------

def test_fail_no_record_free_form_routing():
    # Even a correctly worded routing fails without the record: prose
    # alone is not a decision.
    _assert_fail(
        "Tier 2 — decidable from the artifact: the verdict must carry "
        "head=<sha> on every change. Route to a deterministic check: "
        "extend check-verdict-head.sh coverage plus a unit test asserting "
        "the marker; seed is reproduced (two failing runs in state.json).",
        "routing record",
    )


def test_fail_no_record_behavioral_lint_prose():
    _assert_fail(
        "Tier 2 — add a lint rule that fails when the agent did not stop "
        "at the gate.",
        "routing record",
    )


def test_fail_behavioral_routed_to_check():
    _assert_fail(
        "Tier 2 — the gate bypass recurs; add a unit test.\n"
        + rec([route("behavioral", "check", "event-stream",
                       ["failing test"], 2)]),
        "behavioral",
        "deterministic check",
    )


def test_fail_decidable_routed_to_eval():
    # The canonical Eval-for-decidable mistake keeps its historic reason.
    _assert_fail(
        "Tier 2 — the marker is decidable but let a model judge it.\n"
        + rec([route("decidable", "eval", "event-stream",
                       ["failing test"], 2)]),
        "decidable",
        "llm-judged eval",
    )


def test_fail_multi_route_one_wrong():
    _assert_fail(
        "Two corrections, one misrouted.\n"
        + rec([
            route("decidable", "check", "event-stream", ["failing test"], 2),
            route("behavioral", "check", "event-stream", ["failing test"], 2),
        ]),
        "behavioral",
    )


def test_fail_comment_only_seed_authors_criterion():
    _assert_fail(
        "Noted — the verbosity comment recurs, so I'll author an eval "
        "criterion with a length grader for the goldset.\n"
        + rec([route("behavioral", "eval", "comment")]),
        "admissibility",
    )


def test_fail_reproduced_seed_without_evidence():
    _assert_fail(
        "Behavioral gate bypass, reproduced somewhere, trust me.\n"
        + rec([route("behavioral", "eval", "event-stream", [], 2)]),
        "admissibility",
    )


def test_fail_reproduced_seed_single_run():
    _assert_fail(
        "Behavioral gate bypass with one failing test.\n"
        + rec([route("behavioral", "eval", "event-stream",
                       ["failing test"], 1)]),
        "2 reproduced occurrences",
    )


def test_fail_non_artifact_evidence():
    _assert_fail(
        "The reviewer comment backs it, twice.\n"
        + rec([route("behavioral", "eval", "comment",
                       ["reviewer comment", "reviewer comment"], 2)]),
        "not reproduction evidence",
    )


def test_fail_unknown_class():
    _assert_fail(
        rec([route("structural", "check", "event-stream",
                     ["failing test"], 2)]),
        "unknown class",
    )


def test_fail_unknown_vehicle():
    _assert_fail(
        rec([route("behavioral", "dashboard", "event-stream",
                     ["recorded state transition"], 2)]),
        "unknown vehicle",
    )


def test_fail_unknown_seed():
    _assert_fail(
        rec([route("behavioral", "eval", "vibes",
                     ["recorded state transition"], 2)]),
        "unknown seed",
    )


def test_fail_route_missing_key():
    bad = route("behavioral", "eval", "event-stream",
                ["recorded state transition"], 2)
    del bad["runs"]
    _assert_fail(rec([bad]), "exactly class/vehicle/seed/evidence/runs")


def test_fail_route_unknown_key():
    bad = route("behavioral", "eval", "event-stream",
                ["recorded state transition"], 2)
    bad["confidence"] = "high"
    _assert_fail(rec([bad]), "exactly class/vehicle/seed/evidence/runs")


def test_fail_record_duplicate_key():
    _assert_fail(
        "```tier2-route\n"
        '{"tier": 2, "tier": 2, "routes": []}\n'
        "```",
        "duplicate key",
    )


def test_fail_record_homoglyph_key():
    # Cyrillic 'а' in "clаss" — not the ASCII contract key.
    _assert_fail(
        "```tier2-route\n"
        + json.dumps({"tier": 2, "routes": [{
            "cl\u0430ss": "behavioral", "vehicle": "eval",
            "seed": "event-stream",
            "evidence": ["recorded state transition"], "runs": 2,
        }]}) + "\n```",
        "exactly class/vehicle/seed/evidence/runs",
    )


def test_fail_record_malformed_json():
    _assert_fail(
        "```tier2-route\n{not json\n```",
        "not valid JSON",
    )


def test_fail_two_records():
    _assert_fail(
        rec([route("behavioral", "eval", "event-stream",
                     ["recorded state transition"], 2)])
        + "\n"
        + rec([route("decidable", "check", "event-stream",
                       ["failing test"], 2)]),
        "exactly one",
    )


def test_fail_empty_routes():
    _assert_fail(
        "```tier2-route\n" + json.dumps({"tier": 2, "routes": []}) + "\n```",
        "at least one route",
    )


def test_fail_wrong_tier():
    _assert_fail(
        "```tier2-route\n"
        + json.dumps({"tier": 3, "routes": [
            route("behavioral", "none", "tier-3")]}) + "\n```",
        "tier 2",
    )


def test_fail_tier3_with_vehicle():
    _assert_fail(
        rec([{"class": "behavioral", "vehicle": "eval", "seed": "tier-3",
              "evidence": [], "runs": 0}]),
        "must not name a vehicle",
    )


def test_fail_tier3_decline_with_evidence():
    _assert_fail(
        rec([{"class": "behavioral", "vehicle": "none", "seed": "tier-3",
              "evidence": ["failing test"], "runs": 0}]),
        "carries no reproduction evidence",
    )


def test_fail_tier3_decline_with_runs():
    _assert_fail(
        rec([{"class": "behavioral", "vehicle": "none", "seed": "tier-3",
              "evidence": [], "runs": 2}]),
        "carries no reproduction evidence",
    )


def test_fail_tier3_decline_of_reproduced_recurrence():
    # The universal-decline bypass: a reproduced gate-bypass recurrence
    # must route to its check/eval vehicle, not to Tier-3.
    _assert_fail(
        "Two corrections.\n"
        + rec([route("behavioral", "none", "tier-3")]),
        "reproduced recurrence",
        context={"vars": {
            "scenario": "tier2-split: behavioral recurrence routes to eval",
            "input_context": "Across two runs the agent proceeded without "
            "asking at the escalation gate; no artifact difference exists "
            "— the mistake is in behavior.",
        }},
    )


def test_fail_authored_route_without_vehicle():
    _assert_fail(
        rec([route("behavioral", "none", "event-stream",
                     ["recorded state transition"], 2)]),
        "must name a vehicle",
    )


def test_fail_decidable_goldset_case5_verbatim_reason():
    # Goldset EVAL-017-CASE-5 fails via the class-to-vehicle reason, not
    # the no-record guard.
    import json as _json

    with open(Path(__file__).parent.parent / "goldset.json") as fh:
        goldset = _json.load(fh)
    cases = goldset["cases"] if isinstance(goldset, dict) else goldset
    case5 = next(c for c in cases if c.get("id") == "EVAL-017-CASE-5")
    result = get_assert(case5["expected_output"])
    assert result["pass"] is False
    assert "llm-judged eval" in result["reason"].lower(), (
        "CASE-5 must fail via the class-to-vehicle reason, got: "
        + result["reason"]
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
