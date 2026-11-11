"""Unit test for check_change_specify.py grader.

Verifies the grader produces correct pass/fail results for change-specify
capture responses: provenanced Proposed drafts pass, unprovenanced or
self-published records fail.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_change_specify import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_DRAFT = """## Change-Specify Summary

**ChDRs drafted**: 1

---
status: proposed
type: incident
evidence: confirmed
---

# ChDR-007: Retry cap reverted after 5xx spike

## Context
The retry cap shipped in abc1234 caused 5xx spikes under load.

## Decision
Reverted the retry cap in def5678 (PROJ-123) because unbounded retries
cascaded into the payment service.

## Rejected Alternatives
* Raise the cap to 10 — still cascades under partition.

## Revisit When
After the backpressure work lands.

### Next Steps
Run /change-clarify to review and accept the draft."""


def test_pass_provenanced_proposed_draft():
    """A Proposed draft with SHA provenance routed to /change-clarify passes."""
    result = get_assert(PASS_DRAFT)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_url_provenance():
    """An issue-URL anchor satisfies provenance too."""
    out = """# ChDR-008: Workaround for flaky scheduler
status: proposed
## Decision
Pinned the scheduler image (https://gitlab.example.com/proj/issues/42) until
upstream fixes the race.
Run /change-clarify next."""
    assert get_assert(out)["pass"] is True


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_NO_PROVENANCE = """# ChDR-009: Reverted the thing
status: proposed
## Decision
We reverted it because it felt risky.
Run /change-clarify next."""


def test_fail_unprovenanced_decision():
    """A Decision claim with no SHA/URL fails — the poisoning circuit breaker."""
    result = get_assert(FAIL_NO_PROVENANCE)
    assert result["pass"] is False
    assert result["score"] == 0.0


FAIL_PROMOTED = """# ChDR-010: Capped retries at 3
status: proposed
## Decision
Capped retries at 3 (abc1234) after the incident.
Promoted it to docs/adlc/memory/chdr/ right away.
Run /change-clarify next."""


def test_fail_promotes_from_here():
    """Claiming promotion to docs/adlc/memory fails — that is change-publish."""
    result = get_assert(FAIL_PROMOTED)
    assert result["pass"] is False


FAIL_NO_CLARIFY = """# ChDR-011: Abandoned the simplification
status: proposed
## Decision
Kept the duplicate mapper (abc1234) because the shared one loses types."""


def test_fail_no_clarify_routing():
    """A draft that never routes to /change-clarify fails."""
    result = get_assert(FAIL_NO_CLARIFY)
    assert result["pass"] is False
