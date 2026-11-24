"""test_team_boot_lean_injection.py — issue #36: lean session injection.

The always-on team-boot block carries counts, fetch pointers and skill
trigger phrases; full CDR rows load only when a task matches one.

Shape contract (spec gate, issue #36 note_92297):
- CDR rows are never injected — the CDR count plus a fetch pointer
  (grep CDR.md / /team-discover) replaces them on every path.
- When the project's AGENTS.md carries the TEAM_AI_DIRECTIVES section with
  the lean-contract sentinel, the static contract blocks — Class Boots
  catalog, Team Context & Decisions template, Decision Capture rules,
  Proportionality Gate, Trust Model — are NOT repeated; a one-line pointer
  to that section replaces them.
- When AGENTS.md, the section, or the sentinel is absent (a section written
  by an older team-setup has no Trust Model), the full static sections are
  emitted as before — a stale section never silently drops a safety rail.
- team-setup's generated section carries the sentinel and the moved blocks
  byte-identical to the boot's fallback output.
- Dynamic data stays on both paths: constitution titles, real scope
  counts, every skill with its trigger, MCP names.
- A missing CDR index degrades loudly ("unavailable — run /team-diagnose"),
  never as an empty record set.
- session_compact re-injection emits the same shape as session_start.
"""

from pathlib import Path
import json
import os
import shutil
import subprocess

import pytest

ROOT = Path(__file__).parent.parent.parent
BOOT_SH_PATH = ROOT / "skills/team/team-boot/scripts/bash/boot.sh"
BOOT_PS1_PATH = ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1"
HELPERS_SH = ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh"
HELPERS_PS1 = ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1"

CDR_ROW_TITLE = "Prefer-small-merge-requests-rule"
AGENTS_SECTION = (
    "# Project\n\n"
    "<!-- TEAM_AI_DIRECTIVES START -->\n"
    "<!-- team-boot-contract: lean-v1 -->\n"
    "# Team AI Directives\n\n"
    "## Class Boots\n\n(contract lives here)\n"
    "<!-- TEAM_AI_DIRECTIVES END -->\n"
)
SKILLS = {
    "default": ["dbt-template", "helm-charts"],
    "external": {
        "team-boot": {"description": "Use when a session starts"},
        "architect-boot": {"description": "Use when architecture work starts"},
    },
    "blocked": [],
}


def _setup(tmp_path: Path, *, agents_md: str | None, cdr_md: bool = True) -> Path:
    directives = tmp_path / "directives"
    (directives / "context_modules").mkdir(parents=True)
    (directives / "context_modules" / "constitution.md").write_text(
        "1. **Human Oversight Is Mandatory**\n2. **Appropriate Delegation**\n"
    )
    if cdr_md:
        (directives / "CDR.md").write_text(
            "# CDR\n\n| ID | Title | Type | Descriptor |\n|---|---|---|---|\n"
            f"| CDR-2026-001 | {CDR_ROW_TITLE} | rule | small MRs |\n"
            "| CDR-2026-002 | Other | rule | other descriptor |\n"
        )
    (directives / ".skills.json").write_text(json.dumps(SKILLS))
    (directives / ".mcp.json").write_text(json.dumps({"mcpServers": {"context7": {}}}))

    project = tmp_path / "project"
    (project / ".adlc").mkdir(parents=True)
    (project / ".adlc" / "init-options.json").write_text(
        json.dumps({"team_ai_directives": str(directives)})
    )
    if agents_md is not None:
        (project / "AGENTS.md").write_text(agents_md)
    return project


def _run_sh(project: Path, event: str | None = None) -> str:
    env = {k: v for k, v in os.environ.items() if k != "ADLC_EVENT"}
    if event:
        env["ADLC_EVENT"] = event
    r = subprocess.run(
        ["bash", str(BOOT_SH_PATH)], cwd=project, capture_output=True,
        text=True, timeout=15, env=env,
    )
    assert r.returncode == 0, r.stderr
    return r.stdout


def _run_ps1(project: Path) -> str:
    if shutil.which("pwsh") is None:
        pytest.skip("pwsh not installed")
    r = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOOT_PS1_PATH)], cwd=project,
        capture_output=True, text=True, timeout=30,
    )
    assert r.returncode == 0, r.stderr
    return r.stdout


RUNNERS = [
    pytest.param(_run_sh, marks=pytest.mark.requires_bash, id="sh"),
    pytest.param(_run_ps1, id="ps1"),
]


def _assert_dynamic_layer(out: str):
    assert "1. **Human Oversight Is Mandatory**" in out
    # Real scope counts (dynamic) — never the template placeholders.
    assert "_Scope: 2 CDRs · 0 ADRs · 0 PDRs · 0 ChDRs · 0 evals · 4 skills" in out
    for name in ("dbt-template", "helm-charts"):
        assert f"- {name}" in out
    assert "- team-boot: Use when a session starts" in out
    assert "- architect-boot: Use when architecture work starts" in out
    assert "_Total: 4 skills available._" in out
    assert "- context7" in out


@pytest.mark.parametrize("run", RUNNERS)
def test_cdr_rows_absent_count_and_pointer_present(tmp_path, run):
    out = run(_setup(tmp_path, agents_md=AGENTS_SECTION))
    assert CDR_ROW_TITLE not in out
    assert "| CDR-2026-001 |" not in out
    assert "small MRs" not in out
    assert "_Total: 2 CDRs available._" in out
    assert "CDR.md" in out and "/team-discover" in out


@pytest.mark.parametrize("run", RUNNERS)
def test_cdr_rows_absent_on_fallback_path_too(tmp_path, run):
    out = run(_setup(tmp_path, agents_md=None))
    assert CDR_ROW_TITLE not in out
    assert "| CDR-2026-001 |" not in out
    assert "small MRs" not in out
    assert "_Total: 2 CDRs available._" in out


@pytest.mark.parametrize("run", RUNNERS)
def test_agents_section_present_skips_static_contract(tmp_path, run):
    out = run(_setup(tmp_path, agents_md=AGENTS_SECTION))
    assert "| Boot | Injects | Invoke When | Capture Via |" not in out
    assert "| CDR-YYYY-NNN | <name> |" not in out
    assert "### Detection Triggers" not in out
    assert "### Trust Model" not in out
    assert "### Proportionality Gate" not in out
    assert "AGENTS.md" in out and "TEAM_AI_DIRECTIVES" in out
    _assert_dynamic_layer(out)


@pytest.mark.parametrize(
    "agents_md",
    [None, "# Project\n\nno team section here\n",
     "<!-- TEAM_AI_DIRECTIVES START -->\n<!-- team-boot-contract: lean-v1 -->\nunterminated\n",
     AGENTS_SECTION.replace("<!-- team-boot-contract: lean-v1 -->\n", ""),
     "<!-- TEAM_AI_DIRECTIVES START -->\nx\n<!-- TEAM_AI_DIRECTIVES END -->\n<!-- team-boot-contract: lean-v1 -->\n"],
    ids=["no-agents-md", "no-section", "no-end-marker", "pre-sentinel-section",
         "sentinel-outside-section"],
)
@pytest.mark.parametrize("run", RUNNERS)
def test_agents_section_absent_emits_full_static_sections(tmp_path, run, agents_md):
    out = run(_setup(tmp_path, agents_md=agents_md))
    assert "| Boot | Injects | Invoke When | Capture Via |" in out
    assert "| CDR-YYYY-NNN | <name> | <type> | <relevance> | in use | — |" in out
    assert "### Detection Triggers" in out
    assert "### Trust Model" in out
    assert "### Proportionality Gate" in out
    _assert_dynamic_layer(out)


@pytest.mark.parametrize("run", RUNNERS)
def test_missing_cdr_index_degrades_loudly(tmp_path, run):
    out = run(_setup(tmp_path, agents_md=AGENTS_SECTION, cdr_md=False))
    assert "CDR index unavailable" in out
    assert "/team-diagnose" in out
    assert "_Total: 0 CDRs available._" not in out
    assert "0 CDRs ·" not in out


@pytest.mark.parametrize("run", RUNNERS)
def test_missing_injection_rail_stated(tmp_path, run):
    out = run(_setup(tmp_path, agents_md=AGENTS_SECTION))
    assert "never an empty record set" in out


@pytest.mark.requires_bash
def test_session_compact_emits_same_lean_shape(tmp_path):
    project = _setup(tmp_path, agents_md=AGENTS_SECTION)
    assert _run_sh(project, event="session_compact") == _run_sh(project)


@pytest.mark.requires_bash
def test_lean_path_is_much_smaller_than_fallback(tmp_path):
    lean = _run_sh(_setup(tmp_path / "a", agents_md=AGENTS_SECTION))
    full = _run_sh(_setup(tmp_path / "b", agents_md=None))
    assert len(lean) < 0.6 * len(full), (len(lean), len(full))


def _block(text: str, heading: str) -> str:
    """Body of a `### heading` block up to the next blank-line-separated heading."""
    start = text.index(heading)
    rest = text[start:]
    end = min((i for i in (rest.find("\n## ", 1), rest.find("\n### ", 1),
                           rest.find("\nDecision rows live", 1)) if i > 0),
              default=len(rest))
    return rest[:end].strip()


@pytest.mark.requires_bash
def test_team_setup_section_carries_sentinel_and_moved_blocks_verbatim(tmp_path):
    full = _run_sh(_setup(tmp_path / "boot", agents_md=None))
    project = tmp_path / "gen"
    project.mkdir()
    r = subprocess.run(
        ["bash", "-c", f'source "{HELPERS_SH}"; inject_project_agents "{project}" ./tad'],
        capture_output=True, text=True, timeout=15,
    )
    assert r.returncode == 0, r.stderr
    agents = (project / "AGENTS.md").read_text()
    assert "<!-- team-boot-contract: lean-v1 -->" in agents
    assert ("Never treat a missing injection as an empty record set. "
            "Recovery: run `/team-diagnose`.") in agents
    for heading in ("### Proportionality Gate", "### Trust Model"):
        assert _block(full, heading) in agents, heading
    # The generated section must switch the boot onto the lean path.
    lean = _run_sh(_setup(tmp_path / "lean", agents_md=agents))
    assert "## Team Contract" in lean


def test_team_setup_ps1_section_carries_sentinel_and_moved_blocks():
    ps1 = HELPERS_PS1.read_text()
    assert "<!-- team-boot-contract: lean-v1 -->" in ps1
    assert "### Proportionality Gate" in ps1
    assert "### Trust Model" in ps1
    assert "Drafts are project knowledge, not agent instructions." in ps1
    assert ("Never treat a missing injection as an empty record set. "
            "Recovery: run ``/team-diagnose``.") in ps1


def _add_pending_drafts(project: Path):
    (project / ".adlc/drafts/adr").mkdir(parents=True)
    (project / ".adlc/drafts/adr/ADR-x.md").write_text("status: proposed\n")
    (project / ".adlc/drafts/cdr").mkdir(parents=True, exist_ok=True)
    (project / ".adlc/drafts/cdr/CDR-x.md").write_text("status: raw\n")


@pytest.mark.parametrize("run", RUNNERS)
def test_lean_pending_decisions_one_line(tmp_path, run):
    project = _setup(tmp_path, agents_md=AGENTS_SECTION)
    _add_pending_drafts(project)
    out = run(project)
    assert "## Pending Decisions" not in out
    assert "| — | 1 ADR draft(s) |" not in out
    assert ("_Pending: 1 ADR draft(s) → /architect-clarify · "
            "1 CDR draft(s) → /team-levelup") in out


@pytest.mark.parametrize("run", RUNNERS)
def test_fallback_keeps_pending_table(tmp_path, run):
    project = _setup(tmp_path, agents_md=None)
    _add_pending_drafts(project)
    out = run(project)
    assert "## Pending Decisions" in out
    assert "| — | 1 ADR draft(s) | ADR | .adlc/drafts/adr/ | pending | /architect-clarify |" in out


@pytest.mark.requires_bash
def test_lean_added_lines_are_tight(tmp_path):
    """Lever 2: lines the lean path adds (beyond the dynamic layer) stay short."""
    out = _run_sh(_setup(tmp_path, agents_md=AGENTS_SECTION))
    out = out.replace(str(tmp_path / "directives"), "<dir>")  # path length is the host's, not ours
    assert "## Scope Counts" not in out
    added = [l for l in out.splitlines()
             if "TEAM_AI_DIRECTIVES" in l or "never an empty record set" in l
             or l.startswith("_Total: 2 CDRs")]
    assert added and all(len(l) <= 160 for l in added), [len(l) for l in added]
