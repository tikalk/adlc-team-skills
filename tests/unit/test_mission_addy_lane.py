"""Addy reference lane contract tests (adlc-workspace#56).

Verifies the Addy reference lane implementation in mission-brief:
- ## Addy lane section is present and structured across the DAG steps
- Each step preserves the shared executor contract (output_type, reads_from)
- Maps to addy native skills (github.com/addyosmani/agent-skills/skills/... or installed agent-skills)
- Anchors to installed paths and repository artifact grammar (CONSTRAINTS.md, tasks/, references/)
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


def test_addy_lane_section_has_step_mappings():
    """Addy lane section maps lifecycle steps preserving output_type and reads_from."""
    text = read_brief()
    body = section_body(text, "## Addy lane")

    # Step mappings required
    steps = ["specify", "clarify", "plan", "test", "code", "verify", "converge"]
    for step in steps:
        assert re.search(rf"`{step}`|\b{step}\b", body), f"missing step `{step}` in Addy lane"
        assert "output_type" in body and "reads_from" in body, "Addy lane must declare output_type and reads_from"

    # Specific contract pairs from lane-routing.yml
    assert "draft" in body  # specify, plan
    assert "decision" in body  # clarify, converge
    assert "artifact-ref" in body  # test, code
    assert "findings" in body  # verify


def test_addy_lane_anchors_and_artifacts():
    """Addy lane anchors on installed skill paths and produces native addy artifacts."""
    text = read_brief()
    body = section_body(text, "## Addy lane")

    # Installed plugin / skills anchors
    assert "github.com/addyosmani/agent-skills/skills/" in body or "agent-skills" in body, (
        "Addy lane must cite installed skill paths (github.com/addyosmani/agent-skills/skills/...) or agent-skills"
    )

    # Native addy artifact grammar (CONSTRAINTS.md, tasks/, references/)
    assert "CONSTRAINTS.md" in body, "Addy lane must reference CONSTRAINTS.md"
    assert "tasks/" in body or "tasks" in body, "Addy lane must reference tasks/ directory"
    assert "references/" in body, "Addy lane must reference references/ directory"
    assert "spec.md" in body, "Addy lane must produce or read spec.md"
    assert "plan.md" in body, "Addy lane must produce or read plan.md"


def test_addy_lane_no_bare_commands_or_record_ids():
    """Addy lane contains no bare commands (e.g. /plan) and no record IDs."""
    text = read_brief()
    body = section_body(text, "## Addy lane")

    bare_match = BARE_COMMAND_RE.search(body)
    assert bare_match is None, f"bare slash command {bare_match.group(0)!r} forbidden in Addy lane"

    record_match = RECORD_ID_RE.search(body)
    assert record_match is None, f"record ID {record_match.group(0)!r} forbidden in Addy lane"
