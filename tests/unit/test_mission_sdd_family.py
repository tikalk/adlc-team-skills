"""mission-* SDD family extraction (adlc-workspace!53).

RED-gate suite for the mission-* extraction: factory-mission's lifecycle is
split into four discipline skills — mission-specify, mission-plan,
mission-implement, mission-verify — while factory-mission keeps orchestration.
The suite is captured against the pre-extraction lifecycle at 953c333 and
FAILS on the pre-implementation tree because none of the four skill files
exist yet. It carries no record IDs; contracts are prose, tables and globs.
"""

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = ROOT / "skills/mission"
FIXTURES = ROOT / "tests/fixtures/mission-sdd"

SKILL_NAMES = [
    "mission-specify",
    "mission-plan",
    "mission-implement",
    "mission-verify",
]

# Lifecycle order of the four discipline skills (specify → plan → implement → verify).
LIFECYCLE_ORDER = [
    "mission-specify",
    "mission-plan",
    "mission-implement",
    "mission-verify",
]

REQUIRED_SECTIONS = [
    "## What this skill does",
    "## Default lane",
    "## Step contract",
    "## Gates",
    "## Boundaries",
]

STEP_CONTRACT_HEADER = "| Step | phase_type | output_type | reads_from | artifact |"

EXPECTED_STEPS = {
    "mission-specify": ["specify", "clarify"],
    "mission-plan": ["plan"],
    "mission-implement": ["test", "code"],
    "mission-verify": ["verify", "converge"],
}

BARE_COMMAND_RE = re.compile(
    r"(?<![\w./])/(?:specify|plan|implement|verify|tasks|clarify|review|ship|"
    r"mission-[a-z-]+)\b"
)

RECORD_ID_RE = re.compile(
    r"ADR-\d{3}|PDR-\d{3}|CDR-\d{4}|ChDR-\d{3}"
)


def skill_path(name: str) -> Path:
    return SKILLS_DIR / name / "SKILL.md"


def read_skill(name: str) -> str:
    """Read a mission skill, failing with the missing path that gates RED."""
    path = skill_path(name)
    assert path.exists(), (
        f"missing skills/mission/{name}/SKILL.md — mission-* extraction "
        "not implemented yet"
    )
    return path.read_text(encoding="utf-8")


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


# ── Presence + frontmatter ──────────────────────────────────────────────────

def test_four_skills_exist_with_frontmatter():
    """Each mission-* skill exists with name == directory and a description."""
    for name in SKILL_NAMES:
        path = skill_path(name)
        assert path.exists(), (
            f"missing skills/mission/{name}/SKILL.md — mission-* extraction "
            "not implemented yet"
        )
        meta = parse_frontmatter(path.read_text(encoding="utf-8"))
        assert meta.get("name") == name, (
            f"{name}: frontmatter name must be {name!r}, got {meta.get('name')!r}"
        )
        assert str(meta.get("description") or "").strip(), (
            f"{name}: frontmatter description must be non-empty"
        )


# ── Section contract ────────────────────────────────────────────────────────

def test_each_skill_has_default_lane_and_step_contract():
    """Every skill carries the five required sections and its step table."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        for heading in REQUIRED_SECTIONS:
            assert re.search(rf"(?m)^{re.escape(heading)}\s*$", text), (
                f"{name}: missing required section {heading!r}"
            )
        rows = parse_contract_rows(text)
        assert [row["id"] for row in rows] == EXPECTED_STEPS[name], (
            f"{name}: step contract rows must be {EXPECTED_STEPS[name]}, "
            f"got {[row['id'] for row in rows]}"
        )


# ── Golden run parity ───────────────────────────────────────────────────────

def test_golden_run_trace_matches_pre_extraction():
    """The four tables replay the pre-extraction lifecycle trace byte-for-byte."""
    golden = json.loads((FIXTURES / "golden-run.json").read_text(encoding="utf-8"))
    actual = []
    for name in LIFECYCLE_ORDER:
        for row in parse_contract_rows(read_skill(name)):
            actual.append({
                "id": row["id"],
                "phase_type": row["phase_type"],
                "output_type": row["output_type"],
                "reads_from": row["reads_from"],
            })
    assert actual == golden["steps"], (
        "step contract must replay the captured pre-extraction golden run"
    )
    gate_after = [gate["after"] for gate in golden["gates"]]
    assert gate_after == ["test", "code"], "golden gates must sit after test and code"


# ── Mechanical RED/GREEN gates ──────────────────────────────────────────────

def test_red_green_gates_are_mechanical():
    """mission-implement owns the mechanical gates; the others mention none."""
    implement = read_skill("mission-implement")
    assert "RED gate" in implement, "mission-implement must name the RED gate"
    assert "GREEN gate" in implement, "mission-implement must name the GREEN gate"
    low = implement.lower()
    assert "at least one test fails" in low, (
        "mission-implement must define RED as 'at least one test fails'"
    )
    assert "full suite passes" in low, (
        "mission-implement must define GREEN as 'full suite passes'"
    )
    for name in SKILL_NAMES:
        if name == "mission-implement":
            continue
        text = read_skill(name)
        assert "RED gate" not in text, f"{name}: gates belong to mission-implement only"
        assert "GREEN gate" not in text, f"{name}: gates belong to mission-implement only"


def test_verify_owns_the_converge_verdict():
    """mission-verify carries the converge verdict gate, with all three outcomes."""
    verify = read_skill("mission-verify")
    for verdict in ("DONE", "CONTINUE", "SPEC_CORRECTION_NEEDED"):
        assert verdict in verify, f"mission-verify must name the {verdict} verdict"
    assert "converge verdict" in verify.lower(), (
        "mission-verify must declare the converge verdict as its gate"
    )
    assert "No gate in this phase" not in verify, (
        "mission-verify's verdict is a gate; it must not claim none"
    )


def test_spec_correction_has_one_owner():
    """SPEC_CORRECTION_NEEDED routes to the owning clarify gate — the plan
    absorbs the revision afterwards, it never owns the route."""
    plan = read_skill("mission-plan")
    verify = read_skill("mission-verify")
    for name, text in (("mission-plan", plan), ("mission-verify", verify)):
        assert "clarify gate" in text, (
            f"{name}: SPEC_CORRECTION_NEEDED must route to the owning clarify gate"
        )
    assert "only place the correction is absorbed" not in plan, (
        "mission-plan must not claim sole ownership of spec corrections"
    )


def test_source_fidelity_rules_are_preserved():
    """Rules the extraction must not drop: retry cap, failing-count log,
    no-test-surface skip, and the installed-path dependency reference."""
    implement = read_skill("mission-implement")
    low = implement.lower()
    assert "retry cap" in low, "mission-implement must bound the code loop"
    assert "failing count" in low, "mission-implement must log the RED failing count"
    assert "no test surface" in low, (
        "mission-implement must state when the split is skipped"
    )
    for name in SKILL_NAMES:
        text = read_skill(name)
        assert ".agents/skills/factory-mission/references/executor.md" in text, (
            f"{name}: dependency must be cited by installed path"
        )


# ── Prose hygiene ───────────────────────────────────────────────────────────

def test_no_bare_command_names():
    """Skills never dispatch a bare slash command; skills are invoked by name."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        match = BARE_COMMAND_RE.search(text)
        assert match is None, (
            f"{name}: bare slash command {match.group(0).strip()!r} is not allowed"
        )


def test_no_record_ids_in_skill_files():
    """Skills describe contracts in prose; they never cite record IDs."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        match = RECORD_ID_RE.search(text)
        assert match is None, (
            f"{name}: record ID {match.group(0)!r} must not appear in a skill"
        )


# ── PR107 local-gate section is inherited verbatim ──────────────────────────

def test_pr107_gate_section_preserved_verbatim():
    """All four skills keep the local-session gate section byte-for-byte."""
    block = (FIXTURES / "pr107-gate-section.md").read_text(encoding="utf-8").strip()
    assert block.startswith("## In a local session"), (
        "fixture must start at the local-session gate heading"
    )
    assert "completed" in block and "failed" in block, (
        "fixture must end at the run-outcome sentence"
    )
    for name in SKILL_NAMES:
        text = read_skill(name)
        assert block in text, (
            f"{name}: the local-session gate section must be preserved verbatim"
        )


# ── Parity matrix ───────────────────────────────────────────────────────────

def test_parity_matrix_is_complete_and_single_valued():
    """Parity keeps 14 discipline + 13 orchestration duties, each with text,
    a source, and exactly one destination that actually owns a golden step."""
    parity = json.loads((FIXTURES / "parity.json").read_text(encoding="utf-8"))
    discipline = parity["discipline"]
    orchestration = parity["orchestration"]
    assert len(discipline) == 14, f"need 14 discipline duties, got {len(discipline)}"
    assert len(orchestration) == 13, (
        f"need 13 orchestration duties, got {len(orchestration)}"
    )
    assert set(discipline).isdisjoint(orchestration), (
        "discipline and orchestration duty IDs must be disjoint"
    )

    destinations = {row["destination"] for row in discipline.values()}
    assert destinations == set(SKILL_NAMES), (
        f"discipline duties must map onto the four mission skills, "
        f"got {sorted(destinations)}"
    )
    assert {row["destination"] for row in orchestration.values()} == {
        "factory-mission"
    }, "orchestration duties must stay with factory-mission"

    # An obligation without text or a source cannot be audited.
    for duty_id, row in {**discipline, **orchestration}.items():
        assert row["text"].strip(), f"{duty_id}: obligation text is empty"
        assert row["source"].strip(), f"{duty_id}: obligation source is empty"

    # A destination must own at least one golden step, or the duty is homeless.
    golden = json.loads((FIXTURES / "golden-run.json").read_text(encoding="utf-8"))
    step_ids = {step["id"] for step in golden["steps"]}
    owned = {
        "mission-specify": {"specify", "clarify"},
        "mission-plan": {"plan"},
        "mission-implement": {"test", "code"},
        "mission-verify": {"verify", "converge"},
    }
    for name, steps in owned.items():
        assert steps <= step_ids, (
            f"{name} maps to {sorted(steps - step_ids)} which the golden trace lacks"
        )
        assert skill_path(name).exists(), (
            f"parity destination {name} has no skills/mission/{name}/SKILL.md"
        )
