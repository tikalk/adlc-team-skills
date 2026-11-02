"""Speckit reference lane contract tests (adlc-workspace#55).

Verifies the Speckit reference lane implementation in mission-brief:
- ## Speckit lane section is present and structured across the DAG steps
- Each step preserves the shared executor contract (output_type, reads_from)
- Maps to speckit native artifacts and grammar (specs/, .specify/)
- Anchors to installed paths (github.com/tikalk/adlc-spec-kit-bundle/..., .specify/)
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


def test_speckit_lane_section_has_step_mappings():
    """Speckit lane section maps lifecycle steps preserving output_type and reads_from."""
    text = read_brief()
    body = section_body(text, "## Speckit lane")

    # Step mappings required
    steps = ["specify", "clarify", "plan", "test", "code", "verify", "converge"]
    for step in steps:
        assert re.search(rf"`{step}`|\b{step}\b", body), f"missing step `{step}` in Speckit lane"
        assert "output_type" in body and "reads_from" in body, "Speckit lane must declare output_type and reads_from"

    # Specific contract pairs from lane-routing.yml
    assert "draft" in body  # specify, plan
    assert "decision" in body  # clarify, converge
    assert "artifact-ref" in body  # test, code
    assert "findings" in body  # verify


def test_speckit_lane_anchors_and_artifacts():
    """Speckit lane anchors on installed bundle paths and produces native speckit artifacts."""
    text = read_brief()
    body = section_body(text, "## Speckit lane")

    # Installed bundle anchors
    assert "github.com/tikalk/adlc-spec-kit-bundle/" in body or ".specify/" in body, (
        "Speckit lane must cite installed paths or .specify/ presets"
    )

    # Native speckit artifact grammar (specs/, .specify/)
    assert "specs/" in body, "Speckit lane must reference specs/ artifact layout"
    assert ".specify/" in body, "Speckit lane must reference .specify/ grammar"
    assert "spec.md" in body, "Speckit lane must produce spec.md"
    assert "plan.md" in body, "Speckit lane must produce plan.md"
    assert "tasks.md" in body, "Speckit lane must produce tasks.md"


def test_speckit_lane_no_bare_commands_or_record_ids():
    """Speckit lane contains no bare commands (e.g. /plan) and no record IDs."""
    text = read_brief()
    body = section_body(text, "## Speckit lane")

    bare_match = BARE_COMMAND_RE.search(body)
    assert bare_match is None, f"bare slash command {bare_match.group(0)!r} forbidden in Speckit lane"

    record_match = RECORD_ID_RE.search(body)
    assert record_match is None, f"record ID {record_match.group(0)!r} forbidden in Speckit lane"
