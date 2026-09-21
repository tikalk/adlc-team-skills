"""
test_team_class_boots.py — Contract tests for the class-boot decomposition.

team-boot injects the always-relevant layer (constitution, CDR index, skills)
plus a Class Boots catalog; the five class boots load their record-class
index on demand and pair it with decision capture. These tests pin that
contract across the skill files, the boot scripts, and the helper templates.
"""

from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

CLASS_BOOTS = {
    "architect-boot": {
        "dir": ROOT / "skills" / "architect" / "architect-boot",
        "index": ".adlc/memory/adr/",
        "capture": "/architect-specify",
    },
    "product-boot": {
        "dir": ROOT / "skills" / "product" / "product-boot",
        "index": ".adlc/memory/pdr/",
        "capture": "/product-specify",
    },
    "change-boot": {
        "dir": ROOT / "skills" / "change" / "change-boot",
        "index": ".adlc/memory/chdr.md",
        "capture": "/change-init",
    },
    "team-learn": {
        "dir": ROOT / "skills" / "team" / "team-learn",
        "index": "context_modules",
        "capture": "/team-learn",
    },
    "tech-radar-boot": {
        "dir": ROOT / "skills" / "tech-radar" / "tech-radar-boot",
        "index": "https://tikalk.com/radar.json",
        "capture": "/architect-specify",
    },
}

BOOT = (ROOT / "skills/team/team-boot/SKILL.md").read_text(encoding="utf-8")
BOOT_SH = (ROOT / "skills/team/team-boot/scripts/boot.sh").read_text(encoding="utf-8")
BOOT_PS1 = (ROOT / "skills/team/team-boot/scripts/boot.ps1").read_text(encoding="utf-8")

HELPER_TEMPLATES = {
    "team-repair sh": ROOT / "skills/team/team-repair/team-helpers.sh",
    "team-repair ps1": ROOT / "skills/team/team-repair/team-helpers.ps1",
    "team-setup sh": ROOT / "skills/team/team-setup/team-helpers.sh",
    "team-setup ps1": ROOT / "skills/team/team-setup/team-helpers.ps1",
    "team-skills sh": ROOT / "skills/team/team-skills/team-helpers.sh",
    "team-skills ps1": ROOT / "skills/team/team-skills/team-helpers.ps1",
}


def test_class_boot_skills_exist():
    """All five class boots must exist in the canonical skills/ tree."""
    for name, spec in CLASS_BOOTS.items():
        skill_md = spec["dir"] / "SKILL.md"
        assert skill_md.exists(), f"missing {skill_md}"


def test_class_boot_frontmatter_names():
    """Each class boot's frontmatter name must match its directory."""
    for name, spec in CLASS_BOOTS.items():
        content = (spec["dir"] / "SKILL.md").read_text(encoding="utf-8")
        assert f"name: {name}" in content, f"{name}: frontmatter name mismatch"


def test_class_boot_descriptions_pair_capture():
    """Each class boot description must state its index source AND its
    decision-capture pairing (the -specify/-init skill for its class)."""
    for name, spec in CLASS_BOOTS.items():
        content = (spec["dir"] / "SKILL.md").read_text(encoding="utf-8")
        desc = content.split("description:", 1)[1].split("\n---", 1)[0]
        assert spec["capture"] in desc, f"{name}: description lacks capture skill {spec['capture']}"
        assert "team-boot" in desc, f"{name}: description must reference team-boot's catalog"


def test_class_boot_index_sources():
    """Each class boot body must name its index source path."""
    for name, spec in CLASS_BOOTS.items():
        content = (spec["dir"] / "SKILL.md").read_text(encoding="utf-8")
        assert spec["index"] in content, f"{name}: body lacks index source {spec['index']}"


def test_class_boot_searched_line_contract():
    """Each class boot must emit its own searched line (_Searched N <class>
    records, K matched._) — the per-class counterpart of team-boot's line."""
    expected = {
        "architect-boot": "Searched N ADRs, K matched.",
        "product-boot": "Searched N PDRs, K matched.",
        "change-boot": "Searched N ChDRs, K matched.",
        "team-learn": "Searched N CDRs, K matched.",
    }
    for name, line in expected.items():
        content = (CLASS_BOOTS[name]["dir"] / "SKILL.md").read_text(encoding="utf-8")
        assert line in content, f"{name}: lacks searched-line contract '{line}'"


def test_class_boot_ledger_integration():
    """Each class boot must integrate with the Session Decision Ledger."""
    for name in CLASS_BOOTS:
        content = (CLASS_BOOTS[name]["dir"] / "SKILL.md").read_text(encoding="utf-8")
        assert "Session Decision Ledger" in content, f"{name}: no ledger integration"


def test_class_boot_never_fabricate():
    """Each class boot must forbid fabricating rows and handle empty indexes."""
    for name in CLASS_BOOTS:
        content = (CLASS_BOOTS[name]["dir"] / "SKILL.md").read_text(encoding="utf-8")
        lowered = content.lower()
        assert "never fabricate" in lowered or "do not fabricate" in lowered, (
            f"{name}: no anti-fabrication rule"
        )


def test_architect_boot_references_tech_radar():
    """architect-boot must route tech-selection ADRs through tech-radar-boot."""
    content = (CLASS_BOOTS["architect-boot"]["dir"] / "SKILL.md").read_text(encoding="utf-8")
    assert "tech-radar-boot" in content


def test_tech_radar_boot_keeps_machinery():
    """tech-radar-boot must keep the absorbed radar machinery (live-fetch scripts)."""
    spec = CLASS_BOOTS["tech-radar-boot"]
    assert (spec["dir"] / "scripts" / "radar-search.sh").exists()
    assert (spec["dir"] / "scripts" / "radar-search.ps1").exists()
    # Live-fetch contract (merged from main): no bundled snapshot.
    assert not (spec["dir"] / "resources" / "radar.json").exists()
    body = (spec["dir"] / "SKILL.md").read_text(encoding="utf-8")
    assert "https://tikalk.com/radar.json" in body
    content = (spec["dir"] / "SKILL.md").read_text(encoding="utf-8")
    assert "radar-search.sh" in content
    assert "radar-search.ps1" in content
    # Deprecated alias must be documented for continuity
    assert "tech-radar-context" in content


def test_tech_radar_boot_capture_pairing():
    """tech-radar-boot must pair tech selection with ADR capture."""
    content = (CLASS_BOOTS["tech-radar-boot"]["dir"] / "SKILL.md").read_text(encoding="utf-8")
    assert "architect-specify" in content
    assert "Session Decision Ledger" in content
    assert "Capture the Selection" in content


def test_team_boot_skill_documents_catalog():
    """team-boot SKILL.md must document the Class Boots catalog + Decision Capture."""
    assert "## Class Boots" in BOOT
    for name in CLASS_BOOTS:
        assert name in BOOT, f"team-boot SKILL.md missing {name}"
    assert "## Decision Capture" in BOOT
    assert "Session Decision Ledger" in BOOT


def test_boot_scripts_catalog_rows():
    """boot.sh and boot.ps1 must carry all five catalog rows (parity)."""
    for source in (BOOT_SH, BOOT_PS1):
        assert "## Class Boots" in source
        for name in CLASS_BOOTS:
            assert name in source, f"boot script missing {name} row"


def test_helper_templates_carry_catalog():
    """All six team-helpers templates must embed the Class Boots catalog and
    compact Decision Capture in the AGENTS.md managed section."""
    for label, path in HELPER_TEMPLATES.items():
        content = path.read_text(encoding="utf-8")
        assert "## Class Boots" in content, f"{label}: no Class Boots catalog"
        for name in CLASS_BOOTS:
            assert name in content, f"{label}: missing {name} row"
        assert "## Decision Capture" in content, f"{label}: no Decision Capture"
        assert "Session Decision Ledger" in content, f"{label}: no ledger contract"
