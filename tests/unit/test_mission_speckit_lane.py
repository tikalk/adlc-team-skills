"""Speckit reference lane RED gate (adlc-workspace!55).

RED-gate suite for the speckit reference lane: each mission-* discipline
skill (mission-specify, mission-plan, mission-implement, mission-verify)
gains a prose-only ``## Speckit lane`` section placed directly after its
``## Default lane`` section, carrying the same step contract the skill's
unchanged ``## Step contract`` table declares once, anchored on
installed paths (never bare slash names). Suite FAILS on the pre-lane
tree because no skill carries a ``## Speckit lane`` section yet.
carries no record IDs; contracts prose, tables globs.
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = ROOT / "skills/mission"

SKILL_NAMES = [
    "mission-specify",
    "mission-plan",
    "mission-implement",
    "mission-verify",
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
        f"missing skills/mission/{name}/SKILL.md — speckit lane "
        "not implemented yet"
    )
    return path.read_text(encoding="utf-8")


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
        assert len(cells) == 5, f"step contract row needs 5 cells: {line!r}"
        rows.append({
            "id": cells[0],
            "phase_type": cells[1],
            "output_type": cells[2],
            "reads_from": parse_reads_from(cells[3]),
            "artifact": cells[4],
        })
    return rows


def lane_body(text: str, name: str) -> str:
    assert "## Speckit lane" in text, (
        f"{name}: missing ## Speckit lane section — speckit reference lane "
        "not implemented yet"
    )
    return section_body(text, "## Speckit lane")


def test_speckit_lane_section_present_after_default_lane():
    """Each skill carries `## Speckit lane` placed after `## Default lane`."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        assert "## Speckit lane" in text, (
            f"{name}: missing ## Speckit lane section — speckit reference "
            "lane not implemented yet"
        )
        assert text.index("## Default lane") < text.index("## Speckit lane"), (
            f"{name}: ## Speckit lane must sit directly after ## Default lane"
        )


def test_lane_steps_keep_shared_contract():
    """Lane prose names every owned step with its table contract pair."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        body = lane_body(text, name)
        rows = parse_contract_rows(text)
        expected = {
            (row["id"], row["output_type"], tuple(row["reads_from"]))
            for row in rows
            if row["id"] in EXPECTED_STEPS[name]
        }
        assert sorted(step for step, _, _ in expected) == sorted(EXPECTED_STEPS[name]), (
            f"{name}: step contract rows must be {EXPECTED_STEPS[name]}, "
            f"got {sorted(step for step, _, _ in expected)}"
        )
        actual = set()
        for step, output_type, reads_from in expected:
            assert re.search(rf"`{re.escape(step)}`|\b{re.escape(step)}\b", body), (
                f"{name}: ## Speckit lane body must name owned step `{step}`"
            )
            assert "output_type" in body and "reads_from" in body, (
                f"{name}: ## Speckit lane body must name step `{step}` "
                "alongside the literal tokens `output_type` and `reads_from`"
            )
            assert output_type in body, (
                f"{name}: ## Speckit lane body must carry output_type "
                f"{output_type!r} for step `{step}` per the ## Step contract table"
            )
            for source in reads_from:
                assert source in body, (
                    f"{name}: ## Speckit lane body must carry reads_from "
                    f"{source!r} for step `{step}` per the ## Step contract table"
                )
            actual.add((step, output_type, tuple(reads_from)))
        assert actual == expected, (
            f"{name}: lane prose (output_type, reads_from) pairs must equal "
            f"the ## Step contract rows: got {sorted(actual)}, want {sorted(expected)}"
        )


def test_lane_anchors_use_installed_paths():
    """Each lane body cites at least one installed-path anchor."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        body = lane_body(text, name)
        anchored = (
            ".agents/skills/" in body
            or "github.com/tikalk/adlc-spec-kit-bundle/" in body
            or "specify bundle" in body
            or ".specify/" in body
        )
        assert anchored, (
            f"{name}: ## Speckit lane body must cite an installed-path anchor "
            "(`.agents/skills/` path, `github.com/tikalk/adlc-spec-kit-bundle/` "
            "path, `specify bundle` invocation, or `.specify/` path) — "
            "bare `/plan`-style names never satisfy the rule"
        )


def test_lane_sections_have_no_bare_commands_or_record_ids():
    """Lane bodies carry no bare slash commands and no record IDs."""
    for name in SKILL_NAMES:
        text = read_skill(name)
        assert "## Speckit lane" in text, (
            f"{name}: missing ## Speckit lane section — speckit reference "
            "lane not implemented yet"
        )
        body = section_body(text, "## Speckit lane")
        match = BARE_COMMAND_RE.search(body)
        assert match is None, (
            f"{name}: bare slash command {match.group(0).strip()!r} is "
            "forbidden in the ## Speckit lane body — cite installed paths"
        )
        record = RECORD_ID_RE.search(body)
        assert record is None, (
            f"{name}: record ID {record.group(0)!r} is forbidden "
            "in the ## Speckit lane body"
        )
