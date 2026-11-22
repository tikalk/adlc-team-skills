"""Merge-risk content contract (Task 1 of the merge-risk-gated-merge plan).

Pins the canonical Holmes-five shape the SKILL.md merge-risk sub-step
requires: five rows (Verification | Alignment | Impact | Rollback cost |
Error detection), each carrying an evidence pointer or the word
`unverified`, plus exactly one grep-able `**Merge risk: <band>**` line —
and the informs-never-overrides rule (risk never changes `outcome=`).

TDD RED step: the `**Merge risk:**` band line is not yet required anywhere
(not in verdict-schema lint, not in SKILL.md body schema), so the
band-line assertions below FAIL until the contract lands.
"""
import re
from pathlib import Path

REVIEW = Path(__file__).parent.parent.parent / "skills/factory/factory-review"
SKILL = REVIEW / "SKILL.md"

HEAD = "63e2525b7eca8577e5984e84d269b308f197bb9d"

ROWS = ["Verification", "Alignment", "Impact", "Rollback cost", "Error detection"]


def body_with_risk(marker, risk_line, rows_block):
    return (f"{marker}\n\n## Verdict\n**Outcome:** merge-ready\n\n"
            f"{risk_line}\n\n{rows_block}\n\n"
            f"## Important findings\nNone.\n\n## Nits\nNone.\n")


def marker_line():
    return ("<!-- factory-review:step=review run=interactive iter=0 status=completed "
            f"outcome=merge-ready findings=0 important=0 nits=0 head={HEAD} -->")


def good_rows():
    return "\n".join(f"| {r} | good | src/x.py:1 |" for r in ROWS)


def test_band_line_is_required_by_the_skill_contract():
    """The skill's body schema names the grep-able band line exactly once."""
    text = SKILL.read_text(encoding="utf-8")
    assert "**Merge risk:" in text, "risk: SKILL.md never names the band line"


def test_five_rows_are_named_in_the_skill():
    """All five Holmes rows are pinned by name in the merge-risk sub-step."""
    text = SKILL.read_text(encoding="utf-8")
    for row in ROWS:
        assert row in text, f"risk: missing row {row}"


def test_informs_never_overrides_is_stated():
    """Risk informs, never overrides: only an Important finding flips outcome."""
    text = SKILL.read_text(encoding="utf-8")
    assert "never changes `outcome=`" in text or "never overrides" in text, \
        "risk: informs-never-overrides rule missing"


def test_risk_table_shape_is_complete():
    """The lint fixture shape (band line + five rows) is the contract shape.

    The real pin is the schema: SKILL.md names the band line (§2) and
    verdict-schema.sh lint rejects any body missing it. This test guards the
    shared fixture builder against drift (row or band-line loss), not the
    contract itself.
    """
    text = body_with_risk(marker_line(), "**Merge risk: low**", good_rows())
    assert text.count("## Verdict") == 1 and text.count("**Merge risk:") == 1, \
        "fixture builder lost the band line or Verdict section"
    for row in ROWS:
        assert re.search(rf"(?m)^\| {re.escape(row)} \|", text), \
            f"fixture builder lost row {row}"
    # And the contract itself: the skill names the band line the lint enforces.
    assert "**Merge risk:" in SKILL.read_text(encoding="utf-8")
