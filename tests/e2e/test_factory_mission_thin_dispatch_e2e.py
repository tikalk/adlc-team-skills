"""E2E: factory-mission acts as thin spec-harness orchestrator after the rewrite (E2/adlc-workspace!54).

Pins the thin boundary from the consumer's side: `skills/factory/factory-mission/SKILL.md`
carries no lifecycle discipline text itself (no RED/GREEN gates, no Test/Implement Agent
prose, no embedded converge-loop returns, no "route to Phase 6"), and instead dispatches
every lifecycle step through the `## Lifecycle DAG & Step Resolution` table to exactly
one of the four `mission-*` family skills — each step named in a contract table of the
skill that owns it. Carries correction route G4: SPEC_CORRECTION_NEEDED routes to the
owning clarify gate (`mission-specify`), never to code, never to Phase 6 write-back.
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILL_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
MISSION_DIR = ROOT / "skills/mission"

ALLOWED_MISSION_SKILLS = {
    "mission-specify",
    "mission-plan",
    "mission-implement",
    "mission-verify",
}

# Lifecycle discipline that now lives in the mission-* family, not in factory-mission.
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

# Correction routes that belong to the old embedded loop.
FORBIDDEN_ROUTES = [
    "routes to code",
    "back to the `code` step",
    "route to Phase 6",
]

BARE_COMMAND_RE = re.compile(
    r"(?<![\w/`'\[\(\"‘“])/(?:mission-[a-z-]+)\b"
)

RECORD_ID_RE = re.compile(
    r"\b(?:ADR|PDR)-\d{3,4}(?:-[a-z0-9-]+)?\b"
    r"|\b(?:CDR|ChDR)-\d{3,4}(?:-[a-z0-9-]+)?\b"
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
    assert match, f"missing {heading}"
    return match.group(1)


def test_factory_mission_carries_no_lifecycle_discipline():
    """Thin orchestrator: RED/GREEN mechanics must not live in factory-mission."""
    text = read_skill_md()
    for phrase in DISCIPLINE_PHRASES:
        assert phrase not in text, (
            f"factory-mission must not carry embedded discipline text {phrase!r} — "
            "mechanics belong to the mission-* family"
        )
    for route in FORBIDDEN_ROUTES:
        assert route not in text, (
            f"factory-mission must not route {route!r} — "
            "correction routes to the owning clarify gate"
        )


def test_factory_mission_dispatches_only_to_mission_skills():
    """Lifecycle DAG dispatches to exactly the four mission-* discipline skills."""
    text = read_skill_md()
    assert "## Lifecycle DAG & Step Resolution" in text, (
        "missing ## Lifecycle DAG & Step Resolution — "
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
    # Prose hygiene on the table's home file.
    match = BARE_COMMAND_RE.search(text)
    assert match is None, (
        f"bare slash command {match.group(0).strip()!r} is forbidden in "
        "factory-mission — skills dispatch by name through the DAG table"
    )
    record = RECORD_ID_RE.search(text)
    assert record is None, (
        f"record ID {record.group(0)!r} is forbidden in factory-mission prose — "
        "name the decision in words"
    )


def test_factory_mission_dispatched_steps_are_owned():
    """Every step the DAG names must exist in the owning mission-* step contract."""
    text = read_skill_md()
    body = section_body(text, "## Lifecycle DAG & Step Resolution")
    rows = [
        line.strip() for line in body.splitlines() if line.strip().startswith("|")
    ]
    dispatched = [
        [c.replace("`", "").strip() for c in r.strip("|").split("|")][0]
        for r in rows[2:]
    ]
    assert set(dispatched) == {
        "specify", "clarify", "plan", "test", "code", "verify", "converge",
    }, f"DAG must dispatch exactly the 7 lifecycle steps, got {sorted(dispatched)}"
    owned_steps: set[str] = set()
    for skill in sorted(ALLOWED_MISSION_SKILLS):
        skill_file = MISSION_DIR / skill / "SKILL.md"
        assert skill_file.exists(), f"skills/mission/{skill}/SKILL.md must exist"
        skill_text = skill_file.read_text(encoding="utf-8")
        contract = section_body(skill_text, "## Step contract")
        for line in contract.splitlines():
            line = line.strip()
            if not line.startswith("|") or "Step" in line.split("|")[1]:
                continue
            cells = [c.replace("`", "").strip() for c in line.strip("|").split("|")]
            if all(re.fullmatch(r":?-{3,}:?", c) for c in cells):
                continue
            if cells:
                owned_steps.add(cells[0])
    missing = set(dispatched) - owned_steps
    assert not missing, (
        f"DAG steps with no owning mission-* step contract: {sorted(missing)}"
    )


def test_spec_correction_routes_to_clarify_gate():
    """G4: SPEC_CORRECTION_NEEDED routes to mission-specify clarify gate, never code/Phase 6."""
    text = read_skill_md()
    canonical = (
        "A `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate "
        "(`mission-specify`), never to code."
    )
    assert canonical in text, (
        "factory-mission must carry the canonical G4 correction sentence: "
        f"{canonical!r}"
    )
    for route in FORBIDDEN_ROUTES:
        assert route not in text, (
            f"factory-mission must not route {route!r}"
        )
