"""mission-brief fold (adlc-workspace!69, implementing the lane-core fold).

RED-gate suite for the fold: mission-brief is restored as the single
lane-carrying core DAG (brief -> steps -> converge - Default lane plus four
framework lane pointers; lane prose lands in !55/!56/!57 plus the new
superpowers issue), and the four mission-* step-skills are retired
(deleted, not shimmed). factory-mission becomes harness-only and delegates
lifecycle to mission-brief's DAG with the resolved lane.

Detection is session-LLM-only: the brief step instructs the session model
to inspect well-known install paths and disclose
`Framework lane: <lane> (<evidence>)`. There is NO deterministic fallback
table and NO lane logic in adlc-cli; the headless path keeps today's
behavior. Parity therefore covers the step contract only
(output_type/reads_from/markers), never lane resolution.

Carries no record IDs; contracts are prose, tables and globs.
"""

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).parent.parent.parent
MISSION_DIR = ROOT / "skills/mission"
BRIEF_DIR = MISSION_DIR / "mission-brief"
BRIEF_MD = BRIEF_DIR / "SKILL.md"
ROUTING_YML = BRIEF_DIR / "references" / "lane-routing.yml"
TEMPLATE_NEW = BRIEF_DIR / "references" / "mission-brief-template.md"
TEMPLATE_OLD = ROOT / "skills/factory/factory-mission/references/mission-brief-template.md"
FACTORY_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
GOLDEN = ROOT / "tests/fixtures/mission-sdd/golden-run.json"
DEPS = ROOT / ".skills-deps.json"

RETIRED_SKILLS = [
    "mission-specify",
    "mission-plan",
    "mission-implement",
    "mission-verify",
]
EXPECTED_STEPS = [
    "specify",
    "clarify",
    "plan",
    "test",
    "code",
    "verify",
    "converge",
]
EXPECTED_LANES = {"embedded", "speckit", "superpowers", "matt", "addy"}

STEP_CONTRACT_HEADER = "| Step | phase_type | output_type | reads_from | artifact |"

CANONICAL_G4 = (
    "A `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate "
    "(`mission-brief` clarify), never to code."
)

# Old brief-construction ownership: factory-mission Phase 4 built the brief.
# After the fold the brief step lives in mission-brief; factory-mission only
# validates intake and hands off.
OLD_BRIEF_CONSTRUCTION = "Structure the Mission Brief"

RECORD_ID_RE = re.compile(
    r"ADR-\d{3}|PDR-\d{3}|CDR-\d{4}|ChDR-\d{3}"
)

FROZEN_PRECEDENCE_RE = re.compile(
    r"override\s*→|git-dated usage evidence|installed packs → embedded"
)


def read_brief() -> str:
    assert BRIEF_MD.exists(), (
        "skills/mission/mission-brief/SKILL.md must exist - "
        "mission-brief restoration not implemented yet"
    )
    return BRIEF_MD.read_text(encoding="utf-8")


def parse_frontmatter(text: str) -> dict:
    assert text.startswith("---\n"), "SKILL.md must open with YAML frontmatter"
    end = text.find("\n---", 4)
    assert end != -1, "SKILL.md frontmatter has no closing delimiter"
    data = yaml.safe_load(text[4:end])
    assert isinstance(data, dict), "SKILL.md frontmatter must be a YAML mapping"
    return data


def section_body(text: str, heading: str) -> str:
    pattern = rf"(?ms)^{re.escape(heading)}\s*$(.*?)(?=^## |\Z)"
    match = re.search(pattern, text)
    assert match, f"missing required section: {heading}"
    return match.group(1)


def clean_cell(cell: str) -> str:
    return cell.replace("`", "").strip()


def parse_reads_from(cell: str) -> list:
    value = clean_cell(cell)
    if not value or value == "—":
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def parse_contract_rows(text: str) -> list:
    """Parse the `## Step contract` markdown table into row dicts."""
    body = section_body(text, "## Step contract")
    lines = [line.strip() for line in body.splitlines() if line.strip().startswith("|")]
    assert lines, "## Step contract must contain a markdown table"
    assert lines[0] == STEP_CONTRACT_HEADER, (
        f"step contract header must be {STEP_CONTRACT_HEADER!r}, got {lines[0]!r}"
    )
    rows = []
    for line in lines[1:]:
        cells = [clean_cell(cell) for cell in line.strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        assert len(cells) == 5, f"step contract row must have 5 cells: {line!r}"
        rows.append({
            "id": cells[0],
            "phase_type": cells[1],
            "output_type": cells[2],
            "reads_from": parse_reads_from(cells[3]),
            "artifact": cells[4],
        })
    return rows


def load_routing() -> dict:
    assert ROUTING_YML.exists(), (
        "skills/mission/mission-brief/references/lane-routing.yml must exist - "
        "shared lane-routing reference not implemented yet"
    )
    data = yaml.safe_load(ROUTING_YML.read_text(encoding="utf-8"))
    assert isinstance(data, dict), "lane-routing.yml must be a YAML mapping"
    return data


# -- core presence + full step contract -------------------------------------

# Canonical 7-step contract shared by the skill table and lane-routing.yml.
# mission-brief's own table carries one extra leading row (the brief step
# itself, `reads_from: intake`); the golden trace covers the 7 lifecycle
# steps the DAG shares with the pre-fold harness.
GOLDEN_STEPS = [
    "specify",
    "clarify",
    "plan",
    "test",
    "code",
    "verify",
    "converge",
]

def test_mission_brief_skill_exists_with_frontmatter():
    text = read_brief()
    meta = parse_frontmatter(text)
    assert meta.get("name") == "mission-brief", (
        f"frontmatter name must be 'mission-brief', got {meta.get('name')!r}"
    )
    assert str(meta.get("description") or "").strip(), (
        "mission-brief: frontmatter description must be non-empty"
    )


def test_mission_brief_carries_full_step_contract():
    """The single core DAG replays the golden 7-step lifecycle trace
    (plus its own leading brief step)."""
    text = read_brief()
    rows = parse_contract_rows(text)
    assert [row["id"] for row in rows] == ["brief"] + GOLDEN_STEPS, (
        f"mission-brief must own the brief step plus all 7 lifecycle steps, "
        f"got {[row['id'] for row in rows]}"
    )
    golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
    actual = [
        {
            "id": row["id"],
            "phase_type": row["phase_type"],
            "output_type": row["output_type"],
            "reads_from": row["reads_from"],
        }
        for row in rows
        if row["id"] in GOLDEN_STEPS
    ]
    assert [row["id"] for row in rows if row["id"] in GOLDEN_STEPS] == EXPECTED_STEPS
    assert actual == golden["steps"], (
        "mission-brief step contract must replay the golden run trace"
    )
    gate_after = [gate["after"] for gate in golden["gates"]]
    assert gate_after == ["test", "code"], "golden gates must sit after test and code"


def test_mission_brief_keeps_mechanical_gates_and_converge_verdict():
    """RED/GREEN gates and the converge verdict move with the DAG."""
    text = read_brief()
    low = text.lower()
    assert "RED gate" in text, "mission-brief must name the RED gate"
    assert "GREEN gate" in text, "mission-brief must name the GREEN gate"
    assert "at least one test fails" in low, (
        "mission-brief must define RED as 'at least one test fails'"
    )
    assert "full suite passes" in low, (
        "mission-brief must define GREEN as 'full suite passes'"
    )
    for verdict in ("DONE", "CONTINUE", "SPEC_CORRECTION_NEEDED"):
        assert verdict in text, f"mission-brief must name the {verdict} verdict"
    assert "clarify gate" in text, (
        "SPEC_CORRECTION_NEEDED must route to the owning clarify gate"
    )


def test_mission_brief_carries_brief_format_and_comment_bus():
    """Brief step enforces Goal/Constraints/Non-Goals/Success Criteria;
    every step publishes comment-bus markers."""
    text = read_brief()
    for token in ("Non-Goals", "Success Criteria", "Constraints"):
        assert token in text, f"mission-brief must carry the brief format ({token})"
    low = text.lower()
    assert "comment bus" in low, "mission-brief steps must publish to the comment bus"
    assert "marker" in low, "mission-brief must name the comment-bus markers"


# -- shared lane-routing reference --------------------------------------------

def test_lane_routing_yml_is_the_single_lane_table():
    """One lane table: exactly the five resolvable lanes, all 7 steps."""
    routing = load_routing()
    assert set(routing.get("lanes", {})) == EXPECTED_LANES, (
        f"lane-routing.yml lanes must be {sorted(EXPECTED_LANES)}, "
        f"got {sorted(routing.get('lanes', {}))}"
    )
    assert set(routing.get("steps", {})) == set(EXPECTED_STEPS), (
        "lane-routing.yml steps must cover all 7 lifecycle steps"
    )
    for lane, entry in routing["lanes"].items():
        assert isinstance(entry, dict) and entry.get("section"), (
            f"lane {lane}: must name its mission-brief section"
        )
        assert entry.get("home"), (
            f"lane {lane}: must name its prose home (pointer target)"
        )


def test_no_orphan_lane_every_resolvable_lane_has_a_section():
    """Every lane the routing table can resolve has a section in mission-brief,
    and each lane section points at its prose home (pointer-only, no prose)."""
    text = read_brief()
    routing = load_routing()
    for lane, entry in routing["lanes"].items():
        heading = f"## {entry['section']}"
        assert heading in text, (
            f"lane {lane}: no section {heading!r} in mission-brief "
            "(orphan lane - resolution without a section)"
        )
        body = section_body(text, heading)
        assert entry["home"] in body, (
            f"lane {lane}: section must point at its prose home {entry['home']!r}"
        )
        lines = [line for line in body.splitlines() if line.strip()]
        if lane == "embedded":
            # Default lane prose lives here inline; the pointer-only cap
            # applies to the four framework lanes below.
            continue
        assert len(lines) <= 14, (
            f"lane {lane}: section must stay a pointer "
            f"(got {len(lines)} lines - lane prose belongs in its lane issue)"
        )
        assert re.search(r"!\d+|prose|pointer|canonical", body, re.IGNORECASE), (
            f"lane {lane}: section must reference its prose home explicitly"
        )


def test_step_contract_parity_skill_yml_dispatch():
    """Skill table, routing yml, and factory-mission dispatch resolve the
    same step contract per step (output_type/reads_from - never lane
    resolution)."""
    text = read_brief()
    skill_rows = {
        row["id"]: (row["output_type"], row["reads_from"])
        for row in parse_contract_rows(text)
        if row["id"] in EXPECTED_STEPS
    }
    routing = load_routing()
    for step in EXPECTED_STEPS:
        entry = routing["steps"][step]
        assert entry["output_type"] == skill_rows[step][0], (
            f"step {step}: yml output_type must match the skill table"
        )
        assert list(entry["reads_from"]) == skill_rows[step][1], (
            f"step {step}: yml reads_from must match the skill table"
        )
    factory = FACTORY_MD.read_text(encoding="utf-8")
    dispatch = section_body(factory, "## Lifecycle DAG & Step Resolution")
    retired = re.compile(r"mission-(specify|plan|implement|verify)")
    assert retired.search(dispatch) is None, (
        "dispatch table must not resolve to retired mission-* skills"
    )
    for step in EXPECTED_STEPS:
        assert re.search(rf"(?m)^\|\s*`?{step}`?\s*\|", dispatch), (
            f"factory-mission dispatch table must resolve step {step}"
        )
        assert "mission-brief" in dispatch, (
            "factory-mission dispatch table must resolve through mission-brief"
        )


# -- session-LLM-only detection (no deterministic fallback) --------------------

def test_detection_is_session_llm_instruction_not_a_fallback_table():
    """Phase 0 instructs the session model to inspect well-known install
    paths and disclose the lane - no deterministic fallback table, no
    shell detector, no lane logic."""
    text = read_brief()
    assert re.search(
        r"Framework lane:\s*<lane>\s*\(<evidence>\)", text
    ), "mission-brief must require the `Framework lane: <lane> (<evidence>)` disclosure"
    assert ".agents/skills" in text, (
        "Phase 0 must instruct inspection of installed skill packs"
    )
    assert "plugin" in text.lower(), (
        "Phase 0 must instruct inspection of plugin entries"
    )
    assert "`specify`" in text, (
        "Phase 0 must instruct inspection of the `specify` CLI"
    )
    assert "detect-framework" not in text, (
        "mission-brief must not reference the shell detector - "
        "detection is a session-LLM instruction, not a script call"
    )
    assert "CONSTRAINTS.md" not in text, (
        "mission-brief must not embed artifact fingerprints - "
        "no deterministic fallback table"
    )
    assert FROZEN_PRECEDENCE_RE.search(text) is None, (
        "mission-brief must not carry the frozen precedence chain - "
        "the session model inspects install paths, it does not run a table"
    )


# -- canonical template move ----------------------------------------------------

def test_canonical_template_moved_to_mission_brief():
    TEMPLATE_NEW_exists = TEMPLATE_NEW.exists()
    assert TEMPLATE_NEW_exists, (
        "mission-brief-template.md must live at "
        "skills/mission/mission-brief/references/"
    )
    assert not TEMPLATE_OLD.exists(), (
        "old factory-mission/references/mission-brief-template.md must be gone"
    )
    template = TEMPLATE_NEW.read_text(encoding="utf-8")
    assert "Framework lane" in template, (
        "canonical template must carry the Framework lane line"
    )
    assert FROZEN_PRECEDENCE_RE.search(template) is None, (
        "canonical template must not carry the frozen precedence chain"
    )


def test_no_stale_template_path_in_skills():
    """Every template reference points at the new home (one wave)."""
    stale = "factory-mission/references/mission-brief-template"
    hits = [
        str(p.relative_to(ROOT))
        for p in (ROOT / "skills").rglob("*.md")
        if stale in p.read_text(encoding="utf-8")
    ]
    assert not hits, f"stale template path in skills/: {hits}"
    for consumer in (
        ROOT / "skills/factory/factory-queue/SKILL.md",
        ROOT / "skills/factory/factory-orchestrator/SKILL.md",
    ):
        content = consumer.read_text(encoding="utf-8")
        assert "mission-brief/references/mission-brief-template.md" in content, (
            f"{consumer.parent.parent.name}: must reference the new template home"
        )


# -- mission-* retirement ---------------------------------------------------------

def test_mission_star_skills_deleted_not_shimmed():
    for name in RETIRED_SKILLS:
        assert not (MISSION_DIR / name).exists(), (
            f"skills/mission/{name}/ must be deleted (retired, not shimmed)"
        )
    pattern = re.compile(r"mission-(specify|plan|implement|verify)")
    hits = [
        str(p.relative_to(ROOT))
        for p in (ROOT / "skills").rglob("*.md")
        if pattern.search(p.read_text(encoding="utf-8"))
    ]
    assert not hits, f"retired mission-* references survive in skills/: {hits}"


def test_skills_deps_manifest_drops_retired_borrowers():
    manifest = json.loads(DEPS.read_text(encoding="utf-8"))
    for name in RETIRED_SKILLS:
        assert name not in manifest.get("requires", {}), (
            f".skills-deps.json: retired borrower {name} must be removed"
        )
    assert manifest["requires"].get("mission-brief") == ["factory-mission"], (
        ".skills-deps.json: mission-brief must require factory-mission"
    )
    skill_dirs = {p.parent.name for p in ROOT.glob("skills/*/*/SKILL.md")}
    for borrower, homes in manifest["requires"].items():
        assert borrower in skill_dirs, f"unknown borrower skill: {borrower}"
        for home in homes:
            assert home in skill_dirs, (
                f"unknown canonical home: {home} (required by {borrower})"
            )


# -- factory-mission harness thinning -----------------------------------------------

def test_factory_mission_delegates_lifecycle_to_mission_brief():
    """factory-mission is harness-only: dispatch resolves every step to
    mission-brief; brief construction moved out of Phase 2."""
    text = FACTORY_MD.read_text(encoding="utf-8")
    dispatch = section_body(text, "## Lifecycle DAG & Step Resolution")
    assert "mission-brief" in dispatch, (
        "dispatch table must resolve lifecycle through mission-brief"
    )
    retired = re.compile(r"mission-(specify|plan|implement|verify)")
    assert retired.search(dispatch) is None, (
        "dispatch table must not resolve to retired mission-* skills"
    )
    assert CANONICAL_G4 in text, (
        "factory-mission must keep the canonical correction route: "
        f"{CANONICAL_G4!r}"
    )
    assert OLD_BRIEF_CONSTRUCTION not in text, (
        "factory-mission must not construct the brief - "
        "Phase 2 is intake validation + handoff only"
    )


# -- prose hygiene ---------------------------------------------------------------------

def test_no_bare_command_names_in_mission_brief():
    bare = re.compile(
        r"(?<![\w./])/(?:specify|plan|implement|verify|tasks|clarify|review|ship|"
        r"mission-[a-z-]+)\b"
    )
    match = bare.search(read_brief())
    assert match is None, (
        f"bare slash command {match.group(0).strip()!r} is not allowed"
    )


def test_no_record_ids_in_mission_brief():
    match = RECORD_ID_RE.search(read_brief())
    assert match is None, (
        f"record ID {match.group(0)!r} must not appear in a skill"
    )
