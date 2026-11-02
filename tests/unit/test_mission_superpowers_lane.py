"""Superpowers reference lane contract tests (adlc-workspace#72).

Verifies the Superpowers reference lane implementation in mission-brief:
- ## Superpowers lane section is present and structured across the DAG steps
- Each step preserves the shared executor contract (output_type, reads_from)
- Maps to superpowers native skills (github.com/obra/superpowers/skills/...)
- Anchors to installed plugin entry (.opencode/opencode.json) and docs/superpowers/ layout
- Zero bare slash commands and zero record IDs in lane prose
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
BRIEF_MD = ROOT / "skills/mission/mission-brief/SKILL.md"

BARE_COMMAND_RE = re.compile(
    r"(?<![\w./])/(?:specify|plan|implement|verify|tasks|clarify|review|ship|"
    r"mission-[a-z-]+)\b"
)

RECORD_ID_RE = re.compile(
    r"ADR-\d{3}|PDR-\d{3}|CDR-\d{4}|ChDR-\d{3}"
)


def read_brief() -> str:
    assert BRIEF_MD.exists(), "SKILL.md does not exist"
    return BRIEF_MD.read_text(encoding="utf-8")


def section_body(text: str, heading: str) -> str:
    pattern = rf"(?ms)^{re.escape(heading)}\s*$(.*?)(?=^## |\Z)"
    match = re.search(pattern, text)
    assert match, f"missing required section: {heading}"
    return match.group(1)


def test_superpowers_lane_section_has_step_mappings():
    """Superpowers lane section maps lifecycle steps preserving output_type and reads_from."""
    text = read_brief()
    body = section_body(text, "## Superpowers lane")

    # Step mappings required
    steps = ["specify", "clarify", "plan", "test", "code", "verify", "converge"]
    for step in steps:
        assert re.search(rf"`{step}`|\b{step}\b", body), f"missing step `{step}` in Superpowers lane"
        assert "output_type" in body and "reads_from" in body, "Superpowers lane must declare output_type and reads_from"

    # Specific contract pairs from lane-routing.yml
    assert "draft" in body  # specify, plan
    assert "decision" in body  # clarify, converge
    assert "artifact-ref" in body  # test, code
    assert "findings" in body  # verify


def test_superpowers_lane_anchors_and_artifacts():
    """Superpowers lane anchors on installed skill paths and produces native superpowers artifacts."""
    text = read_brief()
    body = section_body(text, "## Superpowers lane")

    # Installed plugin / skills anchors
    assert "github.com/obra/superpowers/skills/" in body, (
        "Superpowers lane must cite installed skill paths (github.com/obra/superpowers/skills/...)"
    )
    assert ".opencode/opencode.json" in body or "plugin" in body, (
        "Superpowers lane must cite plugin installation entry"
    )

    # Native superpowers artifact grammar (docs/superpowers/specs/, docs/superpowers/plans/)
    assert "docs/superpowers/" in body, "Superpowers lane must reference docs/superpowers/ directory"
    assert "docs/superpowers/specs/" in body, "Superpowers lane must reference docs/superpowers/specs/"
    assert "docs/superpowers/plans/" in body, "Superpowers lane must reference docs/superpowers/plans/"
    assert "spec.md" in body, "Superpowers lane must produce or read spec.md"
    assert "plan.md" in body, "Superpowers lane must produce or read plan.md"


def test_superpowers_lane_no_bare_commands_or_record_ids():
    """Superpowers lane contains no bare commands (e.g. /plan) and no record IDs."""
    text = read_brief()
    body = section_body(text, "## Superpowers lane")

    bare_match = BARE_COMMAND_RE.search(body)
    assert bare_match is None, f"bare slash command {bare_match.group(0)!r} forbidden in Superpowers lane"

    record_match = RECORD_ID_RE.search(body)
    assert record_match is None, f"record ID {record_match.group(0)!r} forbidden in Superpowers lane"
