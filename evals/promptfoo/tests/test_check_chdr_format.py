"""Unit test for check_chdr_format.py grader.

Verifies the grader produces correct pass/fail results for ChDR drafts.
Follows the evals-implement Phase 2 closed-loop self-tuning pattern.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_chdr_format import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_CHDR = """## ChDR-001: Why payments retries are capped at 3

### Status: **Discovered**
### Date: 2026-08-16
### Source: Git history via /change-init
### Issue Links: PROJ-123
### Commits: abc1234
### Descriptor: Consult before changing retry config.

### Context
Issue PROJ-123 reported retries running forever under network partitions.
Commit abc1234 introduced the cap.

### Decision (confidence: HIGH)
The retry count is capped at 3 (abc1234) because unbounded retries caused
cascade failures during the 2026-03 incident.

### Consequences
None observed — no later revert or fix chain touches this path.

### Evidence
- abc1234: cap payments retries at 3
- src/payments/retry.ts: MAX_RETRIES = 3
- https://gitlab.example.com/proj/issues/123: Payments retry loop never terminates
"""


def test_pass_full_chdr():
    """A complete ChDR with all sections, SHA, issue link, and Decision provenance passes."""
    result = get_assert(PASS_CHDR)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_no_linked_issue_marker():
    """A ChDR with the explicit 'no linked issue' marker passes (issue link not required)."""
    chdr = PASS_CHDR.replace(
        "### Issue Links: PROJ-123", "### Issue Links: none detected"
    ).replace("https://gitlab.example.com/proj/issues/123: Payments retry loop never terminates",
              "no issue link — commit message only")
    result = get_assert(chdr)
    assert result["pass"] is True
    assert result["score"] == 1.0


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

def test_fail_missing_section():
    """Missing the Consequences section fails."""
    chdr = PASS_CHDR.replace("### Consequences\nNone observed — no later revert or fix chain touches this path.\n", "")
    result = get_assert(chdr)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "Consequences" in result["reason"]


def test_fail_no_sha():
    """No commit SHA anywhere fails (provenance anchor missing)."""
    chdr = PASS_CHDR.replace("abc1234", "fix-branch").replace("[0-9a-f]", "x")
    # Remove the SHA entirely; keep an issue link so only the SHA check fails
    result = get_assert(chdr)
    assert result["pass"] is False
    assert "SHA" in result["reason"]


def test_fail_no_issue_link_and_no_marker():
    """Neither an issue link nor a 'no linked issue' marker fails."""
    # Remove every issue-link reference (Issue Links line, Context mention, Evidence URL)
    chdr = PASS_CHDR.replace("### Issue Links: PROJ-123", "### Issue Links: ")
    chdr = chdr.replace("Issue PROJ-123 reported retries running forever under network partitions.",
                        "Retries ran forever under network partitions.")
    chdr = chdr.replace("https://gitlab.example.com/proj/issues/123: Payments retry loop never terminates",
                        "issue not tracked")
    result = get_assert(chdr)
    assert result["pass"] is False
    assert "issue link" in result["reason"].lower()


def test_fail_decision_without_provenance():
    """Decision section with no SHA/URL provenance fails (poisoning risk)."""
    chdr = PASS_CHDR.replace(
        "### Decision (confidence: HIGH)\nThe retry count is capped at 3 (abc1234) because unbounded retries caused\ncascade failures during the 2026-03 incident.\n",
        "### Decision (confidence: HIGH)\nThe retry count is capped at 3 because unbounded retries caused cascade failures.\n",
    )
    result = get_assert(chdr)
    assert result["pass"] is False
    assert "provenance" in result["reason"].lower()
