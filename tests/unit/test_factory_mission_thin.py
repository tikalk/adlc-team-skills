"""factory-mission thin rewrite RED gate (adlc-workspace!54).

RED-gate suite for the factory-mission thin rewrite: factory-mission keeps
orchestration only while the mission-* discipline skills own the lifecycle.
This suite FAILS on the pre-rewrite tree because
skills/factory/factory-mission/SKILL.md still contains its embedded
lifecycle (discipline text, no dispatch table, Phase 6 correction route).
It carries no record IDs; contracts are prose, tables and globs.
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILL_MD = ROOT / "skills/factory/factory-mission/SKILL.md"

CANONICAL_G4 = (
    "A `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate "
    "(`mission-specify`), never to code."
)

DISCIPLINE_PHRASES = [
    "RED gate",
    "GREEN gate",
    "Test Agent",
    "Implement Agent",
    "at least one test fails",
    "full suite passes",
    "converge returns",
    "Loop exits",
    "mounted read-only",
    "retry cap",
    "failing count",
    "no test surface",
]

FORBIDDEN_ROUTES = [
    "routes to code",
    "back to the `code` step",
    "route to Phase 6",
]

ALLOWED_MISSION_SKILLS = {
    "mission-specify",
    "mission-plan",
    "mission-implement",
    "mission-verify",
}

BARE_COMMAND_RE = re.compile(
    r"(?<![\w./])/(?:specify|plan|implement|verify|tasks|clarify|review|ship|"
    r"mission-[a-z-]+)\b"
)

RECORD_ID_RE = re.compile(
    r"ADR-\d{3}|PDR-\d{3}|CDR-\d{4}|ChDR-\d{3}"
)

MISSION_SKILL_RE = re.compile(r"mission-[a-z-]+")
FACTORY_SKILL_RE = re.compile(r"factory-[a-z-]+")


def read_skill_md() -> str:
    assert SKILL_MD.exists(), (
        "skills/factory/factory-mission/SKILL.md must exist"
    )
    return SKILL_MD.read_text(encoding="utf-8")


def section_body(text: str, heading: str) -> str:
    pattern = rf"(?ms)^{re.escape(heading)}\s*$(.*?)(?=^## |\Z)"
    match = re.search(pattern, text)
    assert match, f"missing required section: {heading}"
    return match.group(1)


def test_no_discipline_text_in_factory_mission():
    """factory-mission carries no embedded discipline text (RED/GREEN gates,
    Test/Implement agents, converge loop mechanics all live in mission-*)."""
    text = read_skill_md()
    if CANONICAL_G4 in text:
        text = text.replace(CANONICAL_G4, "", 1)
    violations = [phrase for phrase in DISCIPLINE_PHRASES if phrase in text]
    assert not violations, (
        "factory-mission must not contain embedded discipline text; "
        f"found phrase(s): {violations}"
    )


def test_lifecycle_dispatches_only_to_mission_skills():
    """factory-mission dispatches lifecycle steps only to the four mission-*
    discipline skills via a Lifecycle DAG table; no bare slash commands or
    record IDs."""
    text = read_skill_md()
    assert "## Lifecycle DAG & Step Resolution" in text, (
        "missing required section: ## Lifecycle DAG & Step Resolution — "
        "factory-mission must dispatch lifecycle steps to mission-* skills"
    )
    body = section_body(text, "## Lifecycle DAG & Step Resolution")
    table_lines = [
        line.strip() for line in body.splitlines() if line.strip().startswith("|")
    ]
    assert table_lines, (
        "## Lifecycle DAG & Step Resolution must contain a markdown table"
    )
    table_text = "\n".join(table_lines)
    mission_skills = set(MISSION_SKILL_RE.findall(table_text))
    assert mission_skills, (
        "lifecycle table must name at least one mission-* skill"
    )
    unexpected = mission_skills - ALLOWED_MISSION_SKILLS
    assert not unexpected, (
        "lifecycle table must name only mission-specify, mission-plan, "
        f"mission-implement, mission-verify; found extra: {sorted(unexpected)}"
    )
    for skill in sorted(ALLOWED_MISSION_SKILLS):
        assert skill in table_text, (
            f"lifecycle table must dispatch to {skill}"
        )
    factory_skills = set(FACTORY_SKILL_RE.findall(table_text))
    assert not factory_skills, (
        "lifecycle table must not dispatch to factory-* skills; "
        f"found: {sorted(factory_skills)}"
    )
    match = BARE_COMMAND_RE.search(text)
    assert match is None, (
        f"bare slash command {match.group(0).strip()!r} is not allowed; "
        "skills are invoked by name"
    )
    record = RECORD_ID_RE.search(text)
    assert record is None, (
        f"record ID {record.group(0)!r} must not appear in a skill"
    )


def test_correction_routes_to_clarify_gate():
    """SPEC_CORRECTION_NEEDED routes to the owning clarify gate
    (mission-specify), never to code or a Phase 6 write-back."""
    text = read_skill_md()
    assert CANONICAL_G4 in text, (
        "factory-mission must state the canonical correction route: "
        f"{CANONICAL_G4!r}"
    )
    violations = [route for route in FORBIDDEN_ROUTES if route in text]
    assert not violations, (
        "correction must route to the owning clarify gate, never to code; "
        f"found forbidden route(s): {violations}"
    )
