"""Unit test for check_correction_ladder.py grader.

Verifies the grader produces correct pass/fail results for the
correction-elimination ladder primary-route check (EVAL-016).

Scope: EVAL-016 evaluates recurring MECHANICALLY CHECKABLE mistakes —
whether the primary correction is a concrete elimination vehicle.
Genuine Tier 3 judgment-only cases are outside its scope and fail here
by design. Adversarial strings are independently worded (never copied
from goldset.json) so the tests cannot pass by memorising gold phrasing.

Follows the evals-implement Phase 2 closed-loop self-tuning pattern.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_correction_ladder import get_assert


def _assert_fail(decision: str) -> None:
    result = get_assert(decision)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "failed" in result["reason"]


def _assert_pass(decision: str, tier: str) -> None:
    result = get_assert(decision)
    assert result["pass"] is True
    assert result["score"] == 1.0
    assert tier in result["reason"]
    assert "concrete" in result["reason"]


# ---------------------------------------------------------------------------
# Pass cases — independently worded, never goldset copies
# ---------------------------------------------------------------------------

def test_pass_tier1_structural_operation():
    """A concrete structural operation + attached route passes (Tier 1)."""
    decision = """Replace the optional status flag with an exhaustive
union type covering every legal state, and capture this change
through /architect-specify and an ADR so the bad state is
unrepresentable."""
    _assert_pass(decision, "Tier 1")


def test_pass_tier2_mechanical_vehicle():
    """A concrete mechanical vehicle governed by an action verb passes."""
    decision = """Introduce a CI check that rejects direct imports of the
billing internals package, wired into the merge pipeline before review."""
    _assert_pass(decision, "Tier 2")


def test_pass_thin_pointer_beside_check():
    """A thin CDR pointer beside the enforcing vehicle still passes."""
    decision = """Enforce the boundary with a lint rule that blocks the
import at commit time; note the rule path in a thin pointer CDR for
discoverability. The rule, not the prose, is the correction."""
    _assert_pass(decision, "Tier 2")


def test_pass_case2_semicolon_construction():
    """A valid semicolon-joined operation + route passes (gold shape)."""
    decision = """Eliminate the nullable config field by migrating it to an
enum of the three valid modes; record the change in an ADR via
/architect-specify."""
    _assert_pass(decision, "Tier 1")


def test_pass_vehicle_fails_statement():
    """A vehicle described as failing/blocking the build passes."""
    decision = """Ship a pre-commit hook scanning staged diffs for embedded
credentials, blocking the commit whenever a match is found."""
    _assert_pass(decision, "Tier 2")


# ---------------------------------------------------------------------------
# Fail cases — prose-primary even with a vehicle mentioned
# ---------------------------------------------------------------------------

def test_fail_prose_primary_with_vehicle_mentioned():
    """A prose CDR declared primary fails even naming a unit test."""
    decision = """The primary correction is a prose CDR reminding reviewers
to look for leaked tokens; a unit test may be added as supporting
evidence when time allows."""
    _assert_fail(decision)


def test_fail_prose_primary_remains_mechanism():
    """'Prose CDR remains the primary mechanism' fails despite a CI job."""
    decision = """Land a CI job that scans for the pattern as supporting
context. The prose CDR remains the primary mechanism through which
agents learn the rule."""
    _assert_fail(decision)


def test_fail_prose_primary_instead_of_check():
    """'Prose instead of a check' phrasing fails despite a named vehicle."""
    decision = """Write a context rule the team must read instead of adding
a lint rule, since reviewers should internalise the pattern first."""
    _assert_fail(decision)


# ---------------------------------------------------------------------------
# Fail cases — bare route, unrelated route, vague, hedged
# ---------------------------------------------------------------------------

def test_fail_bare_route_without_operation():
    """Naming /architect-specify + ADR with no structural operation fails."""
    decision = """Send this recurrence to /architect-specify and record the
outcome in an ADR so the decision is documented."""
    _assert_fail(decision)


def test_fail_type_name_without_operation():
    """A type term with no operating verb fails even with a route."""
    decision = """This is fundamentally a union type concern. Capture the
analysis in an ADR via /architect-specify."""
    _assert_fail(decision)


def test_fail_unrelated_route_separate_sentence():
    """A route attached to another issue in a later sentence fails."""
    decision = """Migrate the nullable retry counter into an enum of valid
attempt counts. The ADR for an unrelated rollout is already open."""
    _assert_fail(decision)


def test_fail_unrelated_route_after_semicolon():
    """A distanced route after a semicolon fails."""
    decision = """Restrict the free-form role string to a union type of
known roles; separately mention /architect-specify as a possible route
for another issue."""
    _assert_fail(decision)


def test_fail_vague_vehicle():
    """A vague recommendation naming no concrete vehicle fails."""
    decision = """Tighten enforcement around this pattern so future
occurrences are caught earlier in the workflow."""
    _assert_fail(decision)


def test_fail_vehicle_as_mere_possibility():
    """A vehicle mentioned only as a possibility fails."""
    decision = """A pre-commit hook could potentially flag this pattern if
someone later finds time to prototype one."""
    _assert_fail(decision)
