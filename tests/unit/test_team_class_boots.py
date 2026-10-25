"""
test_team_class_boots.py — Contract tests for the class-boot decomposition.

team-boot injects the always-relevant layer (constitution, CDR index, skills)
plus a Class Boots catalog; the five class boots load their record-class
index on demand and pair it with decision capture. These tests pin that
contract across the skill files, the boot scripts, and the helper templates.
"""

from pathlib import Path
import json
import os
import subprocess

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
    "team-levelup": {
        "dir": ROOT / "skills" / "team" / "team-levelup",
        "index": "context_modules",
        "capture": "/team-levelup",
    },
    "tech-radar-boot": {
        "dir": ROOT / "skills" / "tech-radar" / "tech-radar-boot",
        "index": "https://tikalk.com/radar.json",
        "capture": "/architect-specify",
    },
}

BOOT = (ROOT / "skills/team/team-boot/SKILL.md").read_text(encoding="utf-8")
BOOT_SH = (ROOT / "skills/team/team-boot/scripts/bash/boot.sh").read_text(encoding="utf-8")
BOOT_PS1 = (ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1").read_text(encoding="utf-8")

HELPER_TEMPLATES = {
    "team-setup sh": ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh",
    "team-setup ps1": ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1",
}

BORROWER_SKILLS = {
    "team-repair": ROOT / "skills/team/team-repair/SKILL.md",
    "team-skills": ROOT / "skills/team/team-skills/SKILL.md",
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


def test_change_boot_git_command_trigger():
    """change-boot must fire on in-session git commands with human-authored
    messages (plus authored PRs and CHANGELOG edits) — the trigger belongs in
    its description and in the Invoke When cell on all four catalog surfaces.
    The description must also name the /change-clarify clarify gate alongside
    the pinned /change-init mining pairing."""
    change_desc = (CLASS_BOOTS["change-boot"]["dir"] / "SKILL.md").read_text(
        encoding="utf-8"
    ).split("description:", 1)[1].split("\n---", 1)[0]
    assert "human-authored messages" in change_desc
    assert "/change-clarify" in change_desc
    catalog_sources = {
        "boot.sh": BOOT_SH,
        "boot.ps1": BOOT_PS1,
        "team-helpers.sh": HELPER_TEMPLATES["team-setup sh"].read_text(encoding="utf-8"),
        "team-helpers.ps1": HELPER_TEMPLATES["team-setup ps1"].read_text(encoding="utf-8"),
    }
    for name, source in catalog_sources.items():
        assert "human-authored messages" in source, (
            f"{name}: change-boot catalog cell lacks git-command trigger"
        )


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
        "team-levelup": "Searched N CDRs, K matched.",
    }
    for name, line in expected.items():
        content = (CLASS_BOOTS[name]["dir"] / "SKILL.md").read_text(encoding="utf-8")
        assert line in content, f"{name}: lacks searched-line contract '{line}'"


def test_class_boot_ledger_integration():
    """Each class boot must integrate with the merged Team Context & Decisions table."""
    for name in CLASS_BOOTS:
        content = (CLASS_BOOTS[name]["dir"] / "SKILL.md").read_text(encoding="utf-8")
        assert "Team Context & Decisions" in content, f"{name}: no merged-table integration"
        assert "Session Decision Ledger" not in content, f"{name}: stale standalone ledger"


# ── Single-table merge (issue #56) ──────────────────────────────────────────
# Team Context in Use + Session Decision Ledger merge into one
# "Team Context & Decisions" section (shared 6-col grammar). Status carries
# the accepted-vs-pending distinction; no draft row may carry `in use`.

MERGED_SECTION_HEADING = "## Team Context & Decisions"


def _emission_surfaces():
    return {
        "boot.sh": ROOT / "skills/team/team-boot/scripts/bash/boot.sh",
        "boot.ps1": ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1",
        "team-helpers.sh": ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh",
        "team-helpers.ps1": ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1",
        "team-boot/SKILL.md": ROOT / "skills/team/team-boot/SKILL.md",
    }


def test_single_response_table_contract():
    """One merged section per emission surface; stale two-table specs gone."""
    for label, path in _emission_surfaces().items():
        content = path.read_text(encoding="utf-8")
        assert MERGED_SECTION_HEADING in content, f"{label}: missing merged heading"
        assert "## Team Context in Use" not in content, f"{label}: stale context heading"
        assert "### Session Decision Ledger" not in content, f"{label}: stale ledger heading"
        merged_lines = [
            ln for ln in content.splitlines()
            if "rows shown" in ln and "Unrecorded:" in ln
        ]
        assert merged_lines, f"{label}: missing merged counts line (scope + ledger)"


def test_status_semantics_rule():
    """Status alone distinguishes context rows from decision rows."""
    for label, path in _emission_surfaces().items():
        lowered = path.read_text(encoding="utf-8").lower()
        assert "no draft row may carry" in lowered, f"{label}: missing status rule"


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
    assert (spec["dir"] / "scripts" / "bash" / "radar-search.sh").exists()
    assert (spec["dir"] / "scripts" / "powershell" / "radar-search.ps1").exists()
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
    assert "Team Context & Decisions" in content
    assert "Capture the Selection" in content


def test_team_boot_skill_documents_catalog():
    """team-boot SKILL.md must document the Class Boots catalog + Decision Capture."""
    assert "## Class Boots" in BOOT
    for name in CLASS_BOOTS:
        assert name in BOOT, f"team-boot SKILL.md missing {name}"
    assert "## Decision Capture" in BOOT
    assert "Team Context & Decisions" in BOOT


def test_boot_scripts_catalog_rows():
    """boot.sh and boot.ps1 must carry all five catalog rows (parity)."""
    for source in (BOOT_SH, BOOT_PS1):
        assert "## Class Boots" in source
        for name in CLASS_BOOTS:
            assert name in source, f"boot script missing {name} row"


def test_helper_templates_carry_catalog():
    """Both canonical team-helpers templates must embed the Class Boots catalog and
    compact Decision Capture in the AGENTS.md managed section."""
    for label, path in HELPER_TEMPLATES.items():
        content = path.read_text(encoding="utf-8")
        assert "## Class Boots" in content, f"{label}: no Class Boots catalog"
        for name in CLASS_BOOTS:
            assert name in content, f"{label}: missing {name} row"
        assert "## Decision Capture" in content, f"{label}: no Decision Capture"
        assert "Team Context & Decisions" in content, f"{label}: no merged-table contract"


def test_helper_borrowers_reference_canonical():
    """team-repair and team-skills must reference the canonical team-setup
    helpers (no local copies)."""
    for name, path in BORROWER_SKILLS.items():
        assert not (path.parent / "team-helpers.sh").exists(), f"{name}: stale local team-helpers.sh"
        assert not (path.parent / "team-helpers.ps1").exists(), f"{name}: stale local team-helpers.ps1"
        content = path.read_text(encoding="utf-8")
        assert "../team-setup/scripts/bash/team-helpers.sh" in content, f"{name}: no canonical sh reference"
        assert "../team-setup/scripts/powershell/team-helpers.ps1" in content, f"{name}: no canonical ps1 reference"


# ── team-boot file_edited payload mode ──────────────────────────────────────
# The dispatcher sets ADLC_EVENT=file_edited and forwards the event payload on
# stdin. A draft landing in .adlc/drafts/{type}/ must nudge the matching
# EXISTING clarify skill; everything else stays silent. Default (session-start)
# mode is untouched.

DRAFT_NUDGES = {
    "adr": "/architect-clarify",
    "pdr": "/product-clarify",
    "chdr": "/change-clarify",
    "cdr": "/team-levelup",
    "evals": "/evals-clarify",
}

BOOT_SH_PATH = ROOT / "skills/team/team-boot/scripts/bash/boot.sh"


def _run_boot_sh(env_event, payload):
    env = {**os.environ}
    if env_event is None:
        env.pop("ADLC_EVENT", None)
    else:
        env["ADLC_EVENT"] = env_event
    return subprocess.run(
        ["bash", str(BOOT_SH_PATH)],
        input=payload, capture_output=True, text=True, env=env, timeout=30,
    )


def test_boot_file_edited_nudges_matching_clarify_skill():
    """Each draft type nudges its matching existing clarify skill."""
    for draft_type, skill in DRAFT_NUDGES.items():
        payload = json.dumps({"type": "file.edited", "file": f".adlc/drafts/{draft_type}/x.md"})
        result = _run_boot_sh("file_edited", payload)
        assert result.returncode == 0
        assert "[pending-drafts]" in result.stdout, f"{draft_type}: no nudge emitted"
        assert skill in result.stdout, f"{draft_type} draft must nudge {skill}"


def test_boot_file_edited_silent_for_non_drafts():
    """Code-file edits produce no output (no counter, no noise)."""
    result = _run_boot_sh("file_edited", json.dumps({"type": "file.edited", "file": "src/main.py"}))
    assert result.returncode == 0
    assert result.stdout.strip() == ""


def test_boot_file_edited_handles_agent_payload_shapes():
    """opencode flat, nested properties, and claude-code tool_input shapes all resolve."""
    flat = _run_boot_sh("file_edited", json.dumps({"type": "file.edited", "file": ".adlc/drafts/adr/a.md"}))
    nested = _run_boot_sh("file_edited", json.dumps({"type": "file.edited", "properties": {"file": "/abs/repo/.adlc/drafts/pdr/b.md"}}))
    tool_input = _run_boot_sh("file_edited", json.dumps({"tool_input": {"file_path": ".adlc/drafts/evals/c.yml"}}))
    assert "[pending-drafts]" in flat.stdout and "/architect-clarify" in flat.stdout
    assert "[pending-drafts]" in nested.stdout and "/product-clarify" in nested.stdout
    assert "[pending-drafts]" in tool_input.stdout and "/evals-clarify" in tool_input.stdout


def test_boot_file_edited_silent_on_garbage_payload():
    """Malformed payload: fail-open silence, exit 0."""
    result = _run_boot_sh("file_edited", "not-json")
    assert result.returncode == 0
    assert result.stdout.strip() == ""


def test_boot_default_mode_untouched():
    """Without ADLC_EVENT the script keeps its session-start contract."""
    result = _run_boot_sh(None, "{}")
    assert result.returncode == 0
    assert "<EXTREMELY_IMPORTANT>" in result.stdout


def test_boot_ps1_file_edited_mode_parity():
    """boot.ps1 carries the same mode: env guard, marker, and all five nudges."""
    for marker in ("ADLC_EVENT", "file_edited", "pending-drafts"):
        assert marker in BOOT_PS1, f"boot.ps1 missing {marker}"
    for skill in DRAFT_NUDGES.values():
        assert skill in BOOT_PS1, f"boot.ps1 missing nudge for {skill}"


# ── Unified 6-col tables + consolidated pending table ───────────────────────
# Locked format: | ID | Name | Type | Rel | Status | Clarify | for BOTH tables.
# Team Context = accepted records only; Pending Decisions = one table with a
# mandatory clarify-skill column (no per-class sections, no divergent 4-col).

UNIFIED_HEADER = "| ID | Name | Type | Rel | Status | Clarify |"
BOOT_SH_PATH = ROOT / "skills/team/team-boot/scripts/bash/boot.sh"


def test_unified_header_at_every_emission_site():
    """One 6-col response table + the Pending Decisions table share one header.

    boot.sh/boot.ps1 carry two tables (merged Team Context & Decisions +
    session-start Pending Decisions); the team-helpers templates carry only
    the merged response table.
    """
    expected_counts = {
        "boot.sh": (ROOT / "skills/team/team-boot/scripts/bash/boot.sh", 2),
        "boot.ps1": (ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1", 2),
        "team-helpers.sh": (ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh", 1),
        "team-helpers.ps1": (ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1", 1),
    }
    for label, (path, expected) in expected_counts.items():
        content = path.read_text(encoding="utf-8")
        assert content.count(UNIFIED_HEADER) == expected, (
            f"{label}: expected {expected} unified tables, found {content.count(UNIFIED_HEADER)}"
        )
    for stale in ("| Decision | Type | Captured? | Skill |",
                  "| Decision | Type | Captured? | Draft ID | Clarify |"):
        for label, path in {
            "boot.sh": ROOT / "skills/team/team-boot/scripts/bash/boot.sh",
            "boot.ps1": ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1",
            "team-helpers.sh": ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh",
            "team-helpers.ps1": ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1",
        }.items():
            assert stale not in path.read_text(encoding="utf-8"), f"{label}: stale ledger format"


def test_boot_pending_decisions_consolidated_table(tmp_path, monkeypatch):
    """Fixture project: one 6-col Pending Decisions table, per-draft statuses.

    - lowercase/odd filenames count (glob is *.md, status grep filters)
    - bold `- **Status:** Proposed` shape counts (tolerant pattern)
    - files without a status line stay silent
    - scope line reflects fixture memory globs
    """
    (tmp_path / ".adlc/drafts/adr").mkdir(parents=True)
    (tmp_path / ".adlc/drafts/adr/ADR-x.md").write_text("---\nstatus: proposed\n---\n", encoding="utf-8")
    (tmp_path / ".adlc/drafts/chdr").mkdir(parents=True)
    (tmp_path / ".adlc/drafts/chdr/lower.md").write_text("- **Status:** Proposed\n", encoding="utf-8")
    (tmp_path / ".adlc/drafts/pdr").mkdir(parents=True)
    (tmp_path / ".adlc/drafts/pdr/nothing.md").write_text("no status here\n", encoding="utf-8")
    (tmp_path / ".adlc/memory/adr").mkdir(parents=True)
    (tmp_path / ".adlc/memory/adr/ADR-9.md").write_text("# x\n", encoding="utf-8")
    td = tmp_path / "td"
    td.mkdir()
    (td / ".skills.json").write_text('{"default": [], "external": {}}', encoding="utf-8")
    (tmp_path / ".adlc/init-options.json").write_text(
        json.dumps({"team_ai_directives": str(td)}), encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    result = subprocess.run(["bash", str(BOOT_SH_PATH)],
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    out = result.stdout
    assert out.count("## Pending Decisions") == 1
    assert "| — | 1 ADR draft(s) | ADR | .adlc/drafts/adr/ | pending | /architect-clarify |" in out
    assert "| — | 1 ChDR draft(s) | ChDR | .adlc/drafts/chdr/ | pending | /change-clarify |" in out
    assert "_Pending total: 2 across 2 classes." in out
    for old in ("## Pending ADRs", "## Pending PDRs", "## Pending ChDRs",
                "## Pending CDRs", "## Pending EVALs"):
        assert old not in out, f"stale per-class block: {old}"
    assert "_Scope: 0 CDRs · 1 ADRs · 0 PDRs · 0 ChDRs · 0 evals · 0 skills — J rows shown · Unrecorded: N pending · Unclarified: M captured drafts._" in out
    assert UNIFIED_HEADER in out


# ── Class-boot contract v2 — workspace-centralized decision memory/413 (issue #50 + workspace-fallback scope) ─
# Early-fire: class boots invoke at the START of matching work (before todo
# planning/implementation), never deferred to session end.
# 0-rows rendering: heading + counts/searched line only — NO table (a 0-row table
# header collapses into unrendered single-line markdown).
# Workspace fallback: boots in a memory-less submodule CWD fall back to the
# workspace root memory (detected via .gitmodules marker).

EARLY_FIRE_MARKERS = (
    "before planning the todo list",
    "never defer to session end",
)

TEAM_BOOT_CATALOG_SURFACES = {
    "boot.sh": ROOT / "skills/team/team-boot/scripts/bash/boot.sh",
    "boot.ps1": ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1",
    "team-helpers.sh": ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh",
    "team-helpers.ps1": ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1",
    "team-boot/SKILL.md": ROOT / "skills/team/team-boot/SKILL.md",
    "manual-fallback.md": ROOT / "skills/team/team-boot/references/manual-fallback.md",
}


def _boot_skill_text(name):
    return (CLASS_BOOTS[name]["dir"] / "SKILL.md").read_text(encoding="utf-8")


def test_class_boot_early_fire_contract():
    """All five class boots must carry the early-fire rule."""
    for name in CLASS_BOOTS:
        lowered = _boot_skill_text(name).lower()
        for marker in EARLY_FIRE_MARKERS:
            assert marker in lowered, f"{name}: missing early-fire marker '{marker}'"


def test_catalog_surfaces_early_fire_contract():
    """All four catalog surfaces + team-boot SKILL.md + manual-fallback carry early-fire."""
    for label, path in TEAM_BOOT_CATALOG_SURFACES.items():
        lowered = path.read_text(encoding="utf-8").lower()
        for marker in EARLY_FIRE_MARKERS:
            assert marker in lowered, f"{label}: missing early-fire marker '{marker}'"


def test_zero_rows_drop_table_contract():
    """0-rows rendering = heading + counts line only — no table anywhere.

    The stale 'empty table' contract is the source of collapsed single-line
    markdown; it must not appear on any contract surface.
    """
    for label, path in {
        "boot.sh": ROOT / "skills/team/team-boot/scripts/bash/boot.sh",
        "boot.ps1": ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1",
        "team-helpers.sh": ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh",
        "team-helpers.ps1": ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1",
    }.items():
        content = path.read_text(encoding="utf-8")
        lowered = content.lower()
        assert "empty table" not in lowered, f"{label}: stale 'empty table' contract"
        assert "no table" in lowered, f"{label}: missing drop-table rule"
        assert "0 rows matched" in content, f"{label}: missing 0-rows contract"
    for name in CLASS_BOOTS:
        lowered = _boot_skill_text(name).lower()
        assert "empty table" not in lowered, f"{name}: stale 'empty table' contract"
        assert "no table" in lowered, f"{name}: missing drop-table rule"


def test_workspace_fallback_contract():
    """Class boots + catalog surfaces document the workspace-root fallback."""
    for name in CLASS_BOOTS:
        lowered = _boot_skill_text(name).lower()
        assert ".gitmodules" in lowered, f"{name}: missing workspace-fallback marker"
        assert "workspace root" in lowered, f"{name}: missing workspace-root rule"
    for label, path in TEAM_BOOT_CATALOG_SURFACES.items():
        lowered = path.read_text(encoding="utf-8").lower()
        assert ".gitmodules" in lowered, f"{label}: missing workspace-fallback marker"


def test_tech_radar_boot_reemit_contract():
    """tech-radar-boot must mandate visible re-emission of tool-channel findings."""
    lowered = _boot_skill_text("tech-radar-boot").lower()
    for marker in ("tool channel", "re-emit", "visible response"):
        assert marker in lowered, f"tech-radar-boot: missing re-emit marker '{marker}'"
