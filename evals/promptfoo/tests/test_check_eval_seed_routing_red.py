"""RED probes for the Important grader findings (EVAL-017).

Each probe is an independently worded Tier-2 decision exercising the
canonical-fix defect. Expected outcomes follow goldset.md EVAL-017
pass/fail conditions (branch numbers refer to get_assert).
"""
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_eval_seed_routing import get_assert


def _check(decision: str, expected: bool, label: str) -> None:
    result = get_assert(decision)
    assert result["pass"] is expected, (
        f"{label}: expected {'PASS' if expected else 'FAIL'}, got "
        f"{'PASS' if result['pass'] else 'FAIL'} — {result['reason']}"
    )


# ---------------------------------------------------------------------------
# grader-seed-gate-negation-and-provenance: negated evidence must not admit
# a comment seed; asserted event-stream provenance must not false-fail.
# ---------------------------------------------------------------------------

def test_red_seed_negated_list_denied():
    # "no failing test, CI red, diff ... backing it" denies every term —
    # the comment stays inadmissible (branch 1 fails).
    _check(
        "The reviewer's comment says the model is too verbose lately; "
        "there is no failing test, CI red, diff, or screenshot backing it "
        "- it is behavioral, so I'll author an eval criterion with a "
        "length grader.",
        False,
        "seed-negated-list",
    )


def test_red_seed_negated_short_list():
    # Same denial, terse form.
    _check(
        "The reviewer comment says the model is too verbose; no diff, "
        "failing test or revert evidence exists. Author an eval criterion "
        "with a length grader - the mistake is behavioral.",
        False,
        "seed-negated-short",
    )


def test_red_seed_asserted_event_stream_admits():
    # "Not a comment seed" denies comment provenance; the asserted run
    # window reproduces the failure — admissible (pass).
    _check(
        "Not a comment seed: state.json records the gate bypass across "
        "two distinct runs. Author an eval criterion with a binary "
        "behavioral grader.",
        True,
        "seed-asserted-event-stream",
    )


# ---------------------------------------------------------------------------
# grader-wrong-route-guards-negation-and-document-wide: refused vehicles
# never count; a misroute in one clause is not cleared by an unrelated
# vehicle in another.
# ---------------------------------------------------------------------------

def test_red_wrong_route_refused_eval_still_fails():
    # Refused eval is not an eval vehicle; behavioral->lint fails (branch 2).
    _check(
        "Tier 2 - add a lint rule that fails when the agent did not stop "
        "at the gate; an eval criterion is not warranted.",
        False,
        "wrong-route-refused-eval",
    )


def test_red_wrong_route_refused_check_still_fails():
    # Refused check is not a check vehicle; decidable->LLM fails (branch 3).
    _check(
        "Tier 2 - ask a model to judge whether the missing marker is "
        "present, with an LLM grader; a lint rule is not needed.",
        False,
        "wrong-route-refused-check",
    )


def test_red_wrong_route_mixed_clauses_still_fails():
    # Unrelated marker+CI in a second clause does not clear the
    # behavioral->lint misroute (branch 2, wrong-route guard).
    _check(
        "Tier 2 - the agent did not stop at the gate; add a lint rule for "
        "that. Separately, the verdict must carry the head marker, so "
        "extend the CI job.",
        False,
        "wrong-route-mixed-clauses",
    )


# ---------------------------------------------------------------------------
# grader-declination-both-directions: bare preference language fails;
# explicit authoring declinations pass.
# ---------------------------------------------------------------------------

def test_red_declination_bare_stays_a_problem_fails():
    _check(
        "This recurring mistake stays a problem; we should keep watching it.",
        False,
        "declination-bare-stays-a",
    )


def test_red_declination_bare_preference_fails():
    _check(
        "Tier 2 - behavioral, reproduced in two runs. My preference is to "
        "leave it as it is.",
        False,
        "declination-bare-preference",
    )


def test_red_declination_explicit_passes():
    _check(
        "Explicitly declining to author a criterion from an inadmissible "
        "seed - it stays a Tier-3 preference.",
        True,
        "declination-explicit",
    )


def test_red_declination_wont_author_passes():
    _check(
        "No failing test or CI red backs the reviewer note. I will not "
        "author a criterion; it stays a Tier-3 preference.",
        True,
        "declination-wont-author",
    )


# ---------------------------------------------------------------------------
# grader-documented-vocabulary-unmatched: goldset.md pass condition +
# ladder vocabulary must route.
# ---------------------------------------------------------------------------

def test_red_vocab_required_marker_check():
    _check(
        "Tier 2 - decidable: the required marker must be present on every "
        "change. Vehicle: required-marker check. Reproduced twice in "
        "separate runs.",
        True,
        "vocab-required-marker-check",
    )


def test_red_vocab_review_md_pass():
    _check(
        "Decidable from the artifact: the verdict must carry the marker. "
        "Route to a REVIEW.md pass that enforces the marker; seed "
        "reproduced in two failing runs.",
        True,
        "vocab-review-md-pass",
    )


def test_red_vocab_plural_units():
    _check(
        "Tier 2 - decidable: missing sections fail. Add unit tests and "
        "extend the CI jobs asserting the marker. Seed reproduced in two "
        "failing runs.",
        True,
        "vocab-plural-units",
    )


def test_red_vocab_asked_before_acting():
    _check(
        "Tier 2 - behavioral: whether the agent asked before acting at the "
        "gate is a distribution over model behavior. Route to an eval "
        "criterion via /evals-specify with a binary grader; seed "
        "reproduced (two recorded state transitions).",
        True,
        "vocab-asked-before-acting",
    )


# ---------------------------------------------------------------------------
# grader-branch3-missing-yield (solo; validating here): a correct
# behavioral eval that contrasts decidable vocabulary must pass.
# ---------------------------------------------------------------------------

def test_red_branch3_contrast_eval_passes():
    _check(
        "Tier 2 - this mistake is behavioral, not a marker or schema "
        "property; route it to an eval criterion via /evals-specify, and "
        "let the LLM grader judge whether the agent stopped at the gate.",
        True,
        "branch3-contrast-eval",
    )


# ---------------------------------------------------------------------------
# iter1 wrong-route + provenance + declination guards (EVAL-017 fix
# iteration): document-wide co-occurrence never excuses; same-clause
# mere co-mention never excuses; declined-then-authored never passes;
# log/testimony and tool-warning phrasing never seed; bare declin*
# never passes; filenames/abbreviations never split clauses.
# ---------------------------------------------------------------------------

def test_red_wrong_route_docwide_eval_no_excuse():
    # behavioral->lint misroute + unrelated eval vehicle elsewhere fails.
    _check(
        "Tier 2 - add a lint rule that fails when the agent did not stop "
        "at the gate. An eval criterion might also help.",
        False,
        "wrong-route-docwide-eval",
    )


def test_red_wrong_route_docwide_eval_lane_no_excuse():
    # Same, with an explicit lane-routing eval vehicle in clause two.
    _check(
        "Tier 2 - the agent did not stop at the gate; add a lint rule "
        "for that. Separately, add an eval criterion via /evals-specify "
        "for lane behavior.",
        False,
        "wrong-route-docwide-eval-lane",
    )


def test_red_wrong_route_docwide_check_no_excuse():
    # decidable->LLM misroute + unrelated check vehicle elsewhere fails
    # via branch 3 (LLM-judged eval), not branch 5.
    result = get_assert(
        "Tier 2 - the decidable marker must be present, so ask a model "
        "to judge it with an LLM grader as an eval criterion. "
        "Separately, extend the CI job that enforces the marker."
    )
    assert result["pass"] is False
    assert "llm-judged eval" in result["reason"].lower()


def test_red_same_clause_comention_no_excuse():
    # Mere co-mention (behavioral + marker/schema, no negation) with a
    # lint vehicle for the behavior still fails branch 2.
    _check(
        "Tier 2 - behavioral gate bypass, not a marker or schema "
        "property; add a lint rule for the behavior",
        False,
        "same-clause-comention-misroute",
    )


def test_red_branch0_laundered_authoring_fails():
    # Declined authoring in one clause never clears un-declined
    # authoring in another — branch 1 fails the comment-seeded tail.
    _check(
        "I won't author a criterion. Separately, the reviewer comment "
        "says it is verbose, with no failing test backing it, so I'll "
        "author an eval criterion with a length grader.",
        False,
        "branch0-laundered-authoring",
    )


def test_red_branch0_no_undeclined_authors_fails():
    # No clause binds authoring to a target — nothing authored.
    _check(
        "No clause in this decision binds an authoring verb to a target.",
        False,
        "branch0-no-undeclined-authors",
    )


def test_red_case5_in_diff_variant_fails_branch3():
    # "secrets appear in the diff" is decidable diff-scan vocabulary.
    result = get_assert(
        "Tier 2 - ask a model to judge whether secrets appear in the "
        "diff, as an eval criterion with an LLM grader."
    )
    assert result["pass"] is False
    assert "llm-judged eval" in result["reason"].lower()


def test_red_stopped_gate_variant_passes():
    # "stopped gate" without "at the" is behavioral; reproduced seed.
    _check(
        "Tier 2 - behavioral: the agent stopped gate twice without "
        "asking; route to an eval criterion via /evals-specify. Seed "
        "reproduced across two distinct runs.",
        True,
        "stopped-gate-variant",
    )


def test_red_declination_bare_declining_fails():
    _check("declining", False, "declination-bare-declining")


def test_red_declination_readings_declining_fails():
    _check("readings declining", False, "declination-readings-declining")


def test_red_provenance_log_said_no_seed():
    # Log observation ("the log said ...") is not reviewer testimony.
    _check(
        "The log said the gate check was flaky across two runs; route "
        "the behavioral gate bypass to a lint criterion.",
        False,
        "provenance-log-said",
    )


def test_red_provenance_tool_issue_no_seed():
    # Tool warning ("will issue") is not reviewer testimony — and on its
    # own it is not a reproduced seed either, so a criterion authored
    # from it alone with no reproduction evidence fails (branch 1 needs
    # comment + authorship; here the no-class/no-repro guard fails it).
    _check(
        "The tool will issue a warning, so I'll author an eval "
        "criterion with no reproduction evidence behind it.",
        False,
        "provenance-tool-issue",
    )


def test_red_clause_filenames_no_split():
    # e.g./state.json/REVIEW.md/check-verdict-head.sh never split.
    _check(
        "Tier 2 - behavioral gate bypass mistake e.g. extend "
        "check-verdict-head.sh; add an eval criterion via /evals-specify "
        "with a binary grader for gate bypass; seed reproduced across "
        "two distinct runs.",
        True,
        "clause-filenames-no-split",
    )


def test_red_double_negation_admits_evidence():
    # "not an unreproduced comment without failing test" asserts the
    # failure was reproduced — the evidence counts.
    _check(
        "This is not an unreproduced comment without failing test "
        "evidence; route to an eval criterion via /evals-specify as "
        "the mistake is behavioral.",
        True,
        "double-negation-evidence",
    )


def test_red_eval_plural_vehicles_pass():
    # Plural eval vehicles route the behavioral class.
    _check(
        "Tier 2 - behavioral: the gate bypass recurs. Route to eval "
        "criteria with binary graders; seed reproduced across two "
        "distinct runs.",
        True,
        "eval-plural-vehicles",
    )
