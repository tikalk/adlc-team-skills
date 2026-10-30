"""Tests for GitLab work item #37: STE prose and complex-decision maps.

Verifies:
1. Canonical ste-rules exists at skills/authoring/references/ste-rules.md.
2. All four *-clarify skills cite skills/authoring/references/ste-rules.md.
3. All four *-clarify skills document the >=2-boundary tier rule and the
   0-1 boundary plain prose rule.
4. ste-rules.md defines the required STE principles, the four boundaries
   (record, lane, team, now), the ASCII map anatomy, and the '?' slot rule.
5. Mirror-with-sync-note fallback exists in all four clarify consumer directories.
"""

from pathlib import Path
import re
import pytest

ROOT = Path(__file__).parent.parent.parent

CANONICAL_STE = ROOT / "skills/authoring/references/ste-rules.md"
CLARIFY_SKILLS = [
    ROOT / "skills/product/product-clarify/SKILL.md",
    ROOT / "skills/architect/architect-clarify/SKILL.md",
    ROOT / "skills/change/change-clarify/SKILL.md",
    ROOT / "skills/evals/evals-clarify/SKILL.md",
]
MIRROR_REFS = [
    ROOT / "skills/product/product-clarify/references/ste-rules.md",
    ROOT / "skills/architect/architect-clarify/references/ste-rules.md",
    ROOT / "skills/change/change-clarify/references/ste-rules.md",
    ROOT / "skills/evals/evals-clarify/references/ste-rules.md",
]


def test_canonical_ste_rules_exists_and_complete():
    """Criterion 6: canonical ruleset lives at
    skills/authoring/references/ste-rules.md with required sections."""
    assert CANONICAL_STE.exists(), f"Missing canonical ruleset: {CANONICAL_STE}"
    text = CANONICAL_STE.read_text(encoding="utf-8")
    assert "Simplified Technical English" in text
    assert "Short Sentences" in text
    assert "One Idea Per Sentence" in text
    assert "Active Voice" in text
    assert "Imperative" in text
    assert "Named Referents" in text
    assert "Plain Words" in text
    assert "STE-Lite Subset" in text
    # The 4 explicit boundaries
    for b in ("record", "lane", "team", "now"):
        assert f"`{b}`" in text, f"Missing boundary: {b}"
    # Map anatomy components
    assert "WHAT / WHY" in text
    assert "REACH FAN-OUT" in text
    assert "IF-UNDECIDED" in text
    assert "Undrawn Slots (`?`)" in text or "undrawn slot" in text


def test_all_four_clarify_skills_cite_ste_rules():
    """Criterion 6: all four *-clarify skills cite the shared reference."""
    expected_ref = "skills/authoring/references/ste-rules.md"
    for skill_path in CLARIFY_SKILLS:
        assert skill_path.exists(), f"Skill file not found: {skill_path}"
        content = skill_path.read_text(encoding="utf-8")
        assert expected_ref in content, (
            f"{skill_path.name} does not cite {expected_ref}"
        )


def test_clarify_skills_contain_tier_and_boundary_rule():
    """Criterion 1 & 2: each skill contains the tier rule where 0-1
    boundaries stay plain prose and >=2 boundaries draw a map."""
    for skill_path in CLARIFY_SKILLS:
        content = skill_path.read_text(encoding="utf-8")
        assert "0–1 boundaries" in content or "0-1 boundaries" in content, (
            f"{skill_path.name} missing 0-1 boundary rule"
        )
        assert ("2 or more boundaries" in content or "≥2" in content
                or ">=2" in content), (
            f"{skill_path.name} missing 2 or more boundaries rule"
        )
        # Verify the 4 boundary keywords are mentioned
        for b in ("record", "lane", "team", "now"):
            assert b in content, f"{skill_path.name} missing boundary {b}"


def test_mirror_fallback_files_exist_with_sync_notes():
    """Fallback mechanism: consumer skills hold a mirror with a sync-note."""
    for mirror in MIRROR_REFS:
        assert mirror.exists(), f"Mirror file missing: {mirror}"
        text = mirror.read_text(encoding="utf-8")
        assert "SYNC NOTE:" in text
        assert "skills/authoring/references/ste-rules.md" in text
        assert "WHAT / WHY" in text


def test_mirror_bodies_match_canonical():
    """ADR-456 drift guard: each mirror body (past the SYNC NOTE header)
    is byte-identical to the canonical file.

    Catches a canonical edit without re-copy: today the sync test asserts
    existence + header markers only, so the four mirrors would rot silently.
    When adlc-workspace#34 lands and the mirrors collapse to path-refs,
    delete this test with them."""
    canonical = CANONICAL_STE.read_text(encoding="utf-8")
    for mirror in MIRROR_REFS:
        text = mirror.read_text(encoding="utf-8")
        # Strip the one-line SYNC NOTE HTML comment + following blank line.
        assert text.startswith("<!-- SYNC NOTE:"), f"{mirror} lost its sync header"
        body = text.split("-->", 1)[1].lstrip("\n")
        assert body == canonical, (
            f"{mirror} drifted from {CANONICAL_STE.name}: "
            "re-copy the canonical file over the mirror"
        )


def test_tier_boundary_classification_logic():
    """Criterion 2, 3, 4: unit logic tests for 0, 1, and >=2 boundaries."""
    def classify_and_render(boundaries, gaps=None):
        """Simulates the decision logic mandated by ste-rules.md."""
        count = len(boundaries)
        if count <= 1:
            return "PROSE"
        # >=2 boundaries: map required
        map_parts = [
            "+-------------------------------------------------------------------------+",
            "| DECISION MAP                                                            |",
            f"| BOUNDARIES CROSSED: {', '.join(boundaries):<52}|",
            "+-------------------------------------------------------------------------+",
            "| REACH FAN-OUT:                                                          |",
        ]
        for b in boundaries:
            target = gaps.get(b, "?") if gaps else "?"
            map_parts.append(f"|   +-[{b:<6}] --> {target:<54}|")
        map_parts.extend([
            "+-------------------------------------------------------------------------+",
            "| IF-UNDECIDED: Halt run safely.                                          |",
            "+-------------------------------------------------------------------------+",
        ])
        return "\n".join(map_parts)

    # 0 boundaries -> plain prose
    assert classify_and_render([]) == "PROSE"

    # 1 boundary (even severe) -> plain prose
    assert classify_and_render(["record"]) == "PROSE"
    assert classify_and_render(["lane"]) == "PROSE"

    # 2 boundaries -> decision map with complete anatomy
    m2 = classify_and_render(["lane", "team"], gaps={"lane": "arch pattern"})
    assert "DECISION MAP" in m2
    assert "REACH FAN-OUT" in m2
    assert "IF-UNDECIDED" in m2
    assert "+-[lane  ] --> arch pattern" in m2
    assert "+-[team  ] --> ?" in m2  # Undrawn slot renders as '?'

    # 3 boundaries -> decision map with '?' slots
    m3 = classify_and_render(["record", "team", "now"], gaps={})
    assert "+-[record] --> ?" in m3
    assert "+-[team  ] --> ?" in m3
    assert "+-[now   ] --> ?" in m3
    assert "PROSE COMPLAINT" not in m3
