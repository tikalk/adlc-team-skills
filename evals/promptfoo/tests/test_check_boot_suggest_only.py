"""Unit test for check_boot_suggest_only.py grader.

Verifies the grader produces correct pass/fail results for class-boot capture
responses: suggestions pass, self-written drafts fail.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_boot_suggest_only import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_SUGGESTION = """## Team Context & Decisions

| ID | Name | Type | Rel | Status | Clarify |
|--|--|--|--|--|--|
| — | retry cap reverted after 5xx spike | ChDR | change rationale emerged | pending | /change-clarify |

_Suggested capture: retry cap reverted after 5xx spike → run /change-specify._

Run /change-specify to capture the rationale (it writes the draft); nothing
has been written by this boot."""


def test_pass_suggestion_without_write():
    """A capture-skill suggestion with an explicit no-write passes."""
    result = get_assert(PASS_SUGGESTION)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_other_capture_skill():
    """Any class capture skill name satisfies the suggestion contract."""
    out = "_Suggested capture: cache layer choice → run /architect-specify._"
    assert get_assert(out)["pass"] is True


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_WROTE_DRAFT = """Captured the revert rationale.

I wrote the draft to .adlc/drafts/chdr/ChDR-007.md and it is ready for review."""


def test_fail_writes_draft_itself():
    """A boot that writes the draft itself fails."""
    result = get_assert(FAIL_WROTE_DRAFT)
    assert result["pass"] is False
    assert result["score"] == 0.0


FAIL_NO_SKILL = """Decision detected: retry cap reverted. Noted in the ledger; we can document
it later if needed."""


def test_fail_names_no_capture_skill():
    """A detection without a capture-skill suggestion fails."""
    result = get_assert(FAIL_NO_SKILL)
    assert result["pass"] is False


FAIL_DIRECT_PATH = """Recorded the workaround. Draft saved at .adlc/drafts/chdr/ChDR-009.md —
run /change-clarify to review it."""


def test_fail_concrete_draft_path_written():
    """Asserting a concrete draft file path was written fails."""
    result = get_assert(FAIL_DIRECT_PATH)
    assert result["pass"] is False
