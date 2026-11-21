"""RED probes for the Important grader findings (EVAL-017).

Each probe is an independently worded Tier-2 decision exercising the
canonical-fix defect. Outputs carry a `tier2-route` record; probes that
omit the record or name a wrong class, vehicle, or seed fail.
"""
import json
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_eval_seed_routing import get_assert


def rec(routes):
    return "```tier2-route\n" + json.dumps({"tier": 2, "routes": routes}) + "\n```"


def _check(decision: str, expected: bool, label: str) -> None:
    result = get_assert(decision)
    assert result["pass"] is expected, (
        f"{label}: expected {'PASS' if expected else 'FAIL'}, got "
        f"{'PASS' if result['pass'] else 'FAIL'} — {result['reason']}"
    )


# ---------------------------------------------------------------------------
# Adversarial envelope: ten review rounds' worth of paraphrase families
# cannot be expressed in the record; prose excuses are not the decision.
# ---------------------------------------------------------------------------

def test_red_comment_prose_without_record_fails():
    # Prose names a reviewer note, an authoring, and no record.
    _check(
        "A reviewer note says the agent was slow to stop at the gate. "
        "I author an eval criterion to grade it via /evals-specify, "
        "no reproduction evidence behind it.",
        False,
        "comment-prose-no-record",
    )


def test_red_negated_evidence_prose_without_record_fails():
    # "sans any failing test" is prose; there is no record.
    _check(
        "The reviewer comment says the gate was bypassed, sans any "
        "failing test, CI red, or diff. I author an eval criterion "
        "for this behavioral issue.",
        False,
        "negated-evidence-no-record",
    )


def test_red_refused_vehicle_prose_without_record_fails():
    # A refused vehicle in prose does not excuse the missing record.
    _check(
        "Tier 2 - add a lint rule for the behavioral gate bypass; an "
        "eval criterion is N/A here.",
        False,
        "refused-vehicle-no-record",
    )


def test_red_declination_prose_without_record_fails():
    # An explicit decline in prose is not the decision; the record is.
    _check(
        "I won't author a criterion; it stays a Tier-3 preference.",
        False,
        "declination-no-record",
    )


def test_red_multi_clause_prose_without_record_fails():
    # A correct-looking multi-property decision still fails without
    # the record.
    _check(
        "The missing marker is enforced by a required-marker check. "
        "Separately, the gate bypass is behavioral; route it to an eval "
        "criterion via /evals-specify.",
        False,
        "multi-clause-no-record",
    )


def test_red_homoglyph_prose_without_record_fails():
    # A Cyrillic 'о' in "cоmment" is prose, not a record.
    _check(
        "The reviewer c\u043emment says the gate was bypassed, with no "
        "failing test. I author an eval criterion for the behavioral "
        "issue.",
        False,
        "homoglyph-no-record",
    )


# ---------------------------------------------------------------------------
# Record-level defects: the wrong class, vehicle, or seed.
# ---------------------------------------------------------------------------

def test_red_record_behavioral_to_check_fails():
    _check(
        "Tier 2 — behavioral gate bypass routed to a lint rule.\n"
        + rec([{"class": "behavioral", "vehicle": "check",
                "seed": "event-stream", "evidence": ["failing test"],
                "runs": 2}]),
        False,
        "record-behavioral-check",
    )


def test_red_record_decidable_to_eval_fails():
    result = get_assert(
        "Tier 2 — decidable marker judged by a model, as an eval "
        "criterion.\n"
        + rec([{"class": "decidable", "vehicle": "eval",
                "seed": "event-stream", "evidence": ["failing test"],
                "runs": 2}])
    )
    assert result["pass"] is False
    assert "llm-judged eval" in result["reason"].lower()


def test_red_record_comment_seed_authors_fails():
    _check(
        "The verbosity comment recurs; authoring from it.\n"
        + rec([{"class": "behavioral", "vehicle": "eval",
                "seed": "comment", "evidence": [], "runs": 0}]),
        False,
        "record-comment-authors",
    )


def test_red_record_single_run_fails():
    _check(
        "Behavioral gate bypass with one failing test.\n"
        + rec([{"class": "behavioral", "vehicle": "eval",
                "seed": "event-stream", "evidence": ["failing test"],
                "runs": 1}]),
        False,
        "record-single-run",
    )


def test_red_record_non_artifact_evidence_fails():
    _check(
        "Comment-backed twice.\n"
        + rec([{"class": "behavioral", "vehicle": "eval",
                "seed": "comment",
                "evidence": ["reviewer comment", "reviewer comment"],
                "runs": 2}]),
        False,
        "record-non-artifact-evidence",
    )


def test_red_record_two_records_fails():
    one = rec([{"class": "behavioral", "vehicle": "eval",
                "seed": "event-stream",
                "evidence": ["recorded state transition"], "runs": 2}])
    _check(one + "\n" + one, False, "record-two-records")


def test_red_record_tier3_with_vehicle_fails():
    _check(
        rec([{"class": "behavioral", "vehicle": "eval", "seed": "tier-3",
              "evidence": [], "runs": 0}]),
        False,
        "record-tier3-vehicle",
    )


# ---------------------------------------------------------------------------
# Valid records under the contract.
# ---------------------------------------------------------------------------

def test_red_record_behavioral_eval_passes():
    _check(
        "Tier 2 — behavioral gate bypass, reproduced in two runs, "
        "routes to an eval criterion.\n"
        + rec([{"class": "behavioral", "vehicle": "eval",
                "seed": "event-stream",
                "evidence": ["recorded state transition"], "runs": 2}]),
        True,
        "record-behavioral-eval",
    )


def test_red_record_multi_route_passes():
    _check(
        "Two corrections: marker check plus behavioral eval.\n"
        + rec([{"class": "decidable", "vehicle": "check",
                "seed": "event-stream", "evidence": ["failing test"],
                "runs": 2},
               {"class": "behavioral", "vehicle": "eval",
                "seed": "event-stream",
                "evidence": ["recorded state transition"], "runs": 2}]),
        True,
        "record-multi-route",
    )


def test_red_record_tier3_decline_passes():
    _check(
        "Unreproduced remark; stays a Tier-3 preference.\n"
        + rec([{"class": "behavioral", "vehicle": "none",
                "seed": "tier-3", "evidence": [], "runs": 0}]),
        True,
        "record-tier3-decline",
    )
