"""Contract test for the factory-review self-heal cost gate (Task 2).

Small changes skip the three-sub-agent converge loop and get a single
inline review instead. The triage preamble in `review-loop.md` defines
"small"; `SKILL.md` section 3 names it at the loop entry. This test pins
the triage contract: the small-change definition, the `review-depth:`
disclosure line, and the override disclosure rules.
"""

from pathlib import Path

REPO = Path(__file__).parent.parent.parent
LOOP = REPO / "skills" / "factory" / "factory-review" / "references" / "review-loop.md"
SKILL = REPO / "skills" / "factory" / "factory-review" / "SKILL.md"

# Minimal inline sensitive-path list. Task 3 replaces this with the
# REVIEW.md policy field; until then this stands in for the concept.
SENSITIVE_PATHS = ("auth", "billing", "migrations")


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_triage_preamble_exists():
    """review-loop.md opens the loop spec with a small-change triage preamble."""
    text = _read(LOOP).lower()
    assert "triage" in text, "review-loop.md has no triage preamble"
    assert "review-depth" in text, "triage preamble must publish a review-depth disclosure"


def test_small_change_is_docs_or_config_only():
    """Small includes docs-only / config-only changes."""
    text = _read(LOOP).lower()
    assert "docs-only" in text or "docs only" in text
    assert "config-only" in text or "config only" in text


def test_small_change_file_threshold_n3():
    """Small means at most 3 files (threshold N=3)."""
    text = _read(LOOP)
    assert "≤3 files" in text or "<=3 files" in text or "3 files" in text, (
        "triage preamble must state the N=3 file threshold"
    )


def test_small_change_excludes_sensitive_paths():
    """Small excludes sensitive paths (auth, billing, migrations until Task 3)."""
    text = _read(LOOP).lower()
    for path in SENSITIVE_PATHS:
        assert path in text, f"triage preamble must exclude sensitive path '{path}'"


def test_small_maps_to_single_review_depth():
    """Small changes get `review-depth: single (small change)`; else the full loop."""
    text = _read(LOOP)
    assert "review-depth: single" in text, "triage must map small changes to review-depth: single"
    assert "review-depth: full" in text or "full loop" in text.lower(), (
        "triage must map everything else to the full loop"
    )


def test_overrides_disclosed():
    """`--self-heal=full` and `--depth=single` overrides are named and disclosed."""
    text = _read(LOOP)
    assert "--self-heal=full" in text, "triage must name the --self-heal=full override"
    assert "--depth=single" in text, "triage must name the --depth=single override"
    assert "disclos" in text.lower(), "overrides must be disclosed"


def test_skill_section3_names_triage():
    """SKILL.md section 3 entry names the small-change triage before the loop."""
    text = _read(SKILL)
    section3 = text.split("### 3.", 1)[1].split("### 4.", 1)[0]
    assert "triage" in section3.lower(), "SKILL.md section 3 must name the triage"
    assert "review-depth" in section3, "SKILL.md section 3 must name the review-depth disclosure"


def test_no_marker_change():
    """The cost gate discloses via review-depth, never by touching the verdict marker."""
    text = _read(LOOP).lower()
    assert "review-depth" in text
    # review-depth is a status disclosure line, not a marker field: the marker
    # grammar (single HTML comment, head= 40-char SHA, outcome=) is unchanged.
    assert text.count("factory-review:step=review run=") <= 1
