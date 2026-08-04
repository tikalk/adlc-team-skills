from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
BOOT = (ROOT / "skills/team/team-boot/SKILL.md").read_text(encoding="utf-8")
DISCOVER = (ROOT / "skills/team/team-discover/SKILL.md").read_text(encoding="utf-8")
SETUP = (ROOT / "skills/team/team-setup/SKILL.md").read_text(encoding="utf-8")
BOOT_SH = (ROOT / "skills/team/team-boot/scripts/boot.sh").read_text(encoding="utf-8")
BOOT_PS1 = (ROOT / "skills/team/team-boot/scripts/boot.ps1").read_text(encoding="utf-8")
EVENTS = (ROOT / ".events.json").read_text(encoding="utf-8")
RADAR_SH = (ROOT / "skills/tech-radar/tech-radar-context/scripts/radar-search.sh").read_text(encoding="utf-8")
RADAR_PS1 = (ROOT / "skills/tech-radar/tech-radar-context/scripts/radar-search.ps1").read_text(encoding="utf-8")
TECH_RADAR = (ROOT / "skills/tech-radar/tech-radar-context/SKILL.md").read_text(encoding="utf-8")
# AGENTS.md is gitignored (machine-injected with local paths) — may not exist in CI.
_AGENTS_PATH = ROOT / "AGENTS.md"
AGENTS = _AGENTS_PATH.read_text(encoding="utf-8") if _AGENTS_PATH.exists() else ""


def test_team_boot_has_scripts_frontmatter():
    """team-boot must declare scripts: so the dispatcher runs the script path."""
    assert "scripts:" in BOOT
    assert "sh: scripts/boot.sh" in BOOT
    assert "ps: scripts/boot.ps1" in BOOT


def test_team_boot_script_files_exist():
    """Both boot.sh and boot.ps1 must exist."""
    assert (ROOT / "skills/team/team-boot/scripts/boot.sh").exists()
    assert (ROOT / "skills/team/team-boot/scripts/boot.ps1").exists()


def test_team_boot_sh_is_executable():
    """boot.sh must have execute permission."""
    import os
    assert os.access(ROOT / "skills/team/team-boot/scripts/boot.sh", os.X_OK)


def test_team_boot_sh_has_extremely_important_marker():
    """boot.sh must wrap output in EXTREMELY_IMPORTANT tags."""
    assert "<EXTREMELY_IMPORTANT>" in BOOT_SH
    assert "</EXTREMELY_IMPORTANT>" in BOOT_SH


def test_team_boot_ps1_has_extremely_important_marker():
    """boot.ps1 must wrap output in EXTREMELY_IMPORTANT tags."""
    assert "<EXTREMELY_IMPORTANT>" in BOOT_PS1
    assert "</EXTREMELY_IMPORTANT>" in BOOT_PS1


def test_team_boot_sh_lean_orientation():
    """boot.sh must output lean orientation, not full context."""
    assert "Constitution" in BOOT_SH
    assert "CDR Index" in BOOT_SH
    assert "Available Skills" in BOOT_SH
    assert "MCP Servers" in BOOT_SH
    assert "Every response MUST include" in BOOT_SH
    assert "Team Context in Use" in BOOT_SH
    # Should NOT cat full files
    assert "cat \"$TEAM_AI_DIRECTIVES/context_modules/constitution.md\"" not in BOOT_SH
    assert "cat \"$TEAM_AI_DIRECTIVES/.skills.json\"" not in BOOT_SH


def test_team_boot_ps1_lean_orientation():
    """boot.ps1 must output lean orientation, not full context."""
    assert "Constitution" in BOOT_PS1
    assert "CDR Index" in BOOT_PS1
    assert "Available Skills" in BOOT_PS1
    assert "Every response MUST include" in BOOT_PS1


def test_boot_sh_example_row_is_placeholder():
    """boot.sh Team Context example row must be a placeholder, not a real CDR ID.

    A real example row (e.g. CDR-2026-003) anchors the model to cargo-cult that
    specific CDR into every response instead of searching for a genuine match.
    """
    assert "CDR-2026-003 | Cloud-Native Platform Architect" not in BOOT_SH
    assert "CDR-YYYY-NNN" in BOOT_SH


def test_boot_sh_context_contract_integrity():
    """boot.sh must enforce counts-line integrity, canonical heading, and exploration guidance."""
    # J must equal row count (prevents "1 matched" copy-paste with a 2-row table)
    assert "J MUST equal the number of rows" in BOOT_SH
    # Canonical heading standardizes the section across models
    assert "## Team Context in Use" in BOOT_SH
    # Exploration efficiency guidance
    assert "targeted file searches" in BOOT_SH


def test_boot_ps1_example_row_is_placeholder():
    """boot.ps1 Team Context example row must be a placeholder, not a real CDR ID."""
    assert "CDR-2026-003 | Cloud-Native Platform Architect" not in BOOT_PS1
    assert "CDR-YYYY-NNN" in BOOT_PS1


def test_boot_ps1_context_contract_integrity():
    """boot.ps1 must enforce counts-line integrity, canonical heading, and exploration guidance."""
    assert "J MUST equal the number of rows" in BOOT_PS1
    assert "## Team Context in Use" in BOOT_PS1
    assert "targeted file searches" in BOOT_PS1


def test_team_boot_sh_unconfigured_warns_user():
    """boot.sh unconfigured output must warn the user, not instruct the LLM."""
    assert "not configured" in BOOT_SH
    assert "/team-setup" in BOOT_SH
    assert "Invoke the team-setup skill" not in BOOT_SH
    assert "MANDATORY" not in BOOT_SH
    assert "Do NOT rationalize" not in BOOT_SH
    assert "Do not proceed" not in BOOT_SH


def test_team_boot_ps1_unconfigured_warns_user():
    """boot.ps1 unconfigured output must warn the user, not instruct the LLM."""
    assert "not configured" in BOOT_PS1
    assert "/team-setup" in BOOT_PS1
    assert "Invoke the team-setup skill" not in BOOT_PS1
    assert "MANDATORY" not in BOOT_PS1
    assert "Do NOT rationalize" not in BOOT_PS1


def test_team_boot_sh_extracts_init_options():
    """boot.sh must read .adlc/init-options.json and extract team_ai_directives."""
    assert ".adlc/init-options.json" in BOOT_SH
    assert "team_ai_directives" in BOOT_SH
    assert "grep" in BOOT_SH


def test_team_boot_sh_handles_unconfigured():
    """boot.sh must output guidance when init-options.json is missing."""
    assert "Team AI directives not configured" in BOOT_SH
    assert "team-setup" in BOOT_SH


def test_team_boot_sh_handles_null_optout():
    """boot.sh must silently exit on null marker (user opted out)."""
    assert "null" in BOOT_SH


def test_team_boot_sh_assembles_context():
    """boot.sh must assemble constitution, CDR index, skills, and MCP."""
    assert "constitution" in BOOT_SH
    assert "CDR" in BOOT_SH
    assert "skills.json" in BOOT_SH
    assert "mcp.json" in BOOT_SH


def test_team_boot_ps1_assembles_context():
    """boot.ps1 must assemble constitution, CDR index, skills, and MCP."""
    assert "constitution" in BOOT_PS1
    assert "CDR" in BOOT_PS1
    assert "skills.json" in BOOT_PS1 or "skillsPath" in BOOT_PS1
    assert "mcp.json" in BOOT_PS1 or "mcpPath" in BOOT_PS1


def test_team_boot_sh_extracts_cdr_index_only():
    """boot.sh must extract only CDR index entries (not body documentation)."""
    assert "awk" in BOOT_SH
    assert "CDR" in BOOT_SH


def test_team_boot_ps1_uses_convertfrom_json():
    """boot.ps1 must use native PowerShell JSON parsing."""
    assert "ConvertFrom-Json" in BOOT_PS1
    assert "node" not in BOOT_PS1


def test_team_boot_body_mentions_team_setup():
    """team-boot body must mention team-setup for unconfigured projects."""
    assert "team-setup" in BOOT


def test_team_boot_body_mentions_cdr_index():
    """team-boot body must mention CDR index."""
    assert "CDR index" in BOOT


def test_team_boot_body_no_anti_rationalization():
    """Anti-rationalization table is obsolete with event hook — must be removed."""
    assert "Common Rationalizations" not in BOOT
    assert "Red Flags" not in BOOT
    assert "MANDATORY in build mode" not in BOOT
    assert "Do NOT second-guess" not in BOOT


def test_team_boot_body_no_per_prompt_discovery():
    """Per-prompt discovery directive must be removed."""
    assert "every prompt" not in BOOT.lower()
    assert "no continuation exemption" not in BOOT.lower()
    assert "Step 4" not in BOOT


def test_team_discover_is_manual_only():
    """team-discover must be described as manual re-scan, not auto-invoked."""
    assert "manually" in DISCOVER.lower() or "manual" in DISCOVER.lower()
    assert "/team-discover" in DISCOVER


def test_team_discover_no_persistence_logic():
    """team-discover must not have persistence/delta/modes logic."""
    assert "team-context.md" not in DISCOVER
    assert "Persist" not in DISCOVER
    assert "delta" not in DISCOVER.lower()
    assert "no-write" not in DISCOVER


def test_team_discover_no_scripts_frontmatter():
    """team-discover must not have scripts: — it's body-path only."""
    assert "scripts:" not in DISCOVER


def test_team_setup_is_model_invocable():
    """team-setup must not disable model invocation so team-boot can self-install."""
    assert "disable-model-invocation: true" not in SETUP
    assert "Model-invoked by `team-boot`" in SETUP or "model-invoked by `team-boot`" in SETUP


def test_team_setup_decline_handling_documented():
    """team-setup must handle user decline with a session-scoped skip and a persistent opt-out marker."""
    assert "Decline Handling" in SETUP
    assert "team_ai_directives: null" in SETUP
    assert "session-scoped" in SETUP


def test_no_stale_parent_walk_remnants():
    """v0.16.3 removed the parent-directory walk-up; only the explicit 'Do NOT walk up' prohibition may remain."""
    assert "Do NOT walk up parent directories" in BOOT
    assert "up to 4" not in BOOT
    assert "Default fallback" not in BOOT


def test_events_json_no_user_prompt_submit():
    """events.json must not have user_prompt_submit — only session_start."""
    assert "session_start" in EVENTS
    assert "user_prompt_submit" not in EVENTS


def test_events_json_only_team_boot():
    """events.json must only have team-boot on session_start."""
    assert "team-boot" in EVENTS
    assert "team-discover" not in EVENTS


def test_agents_md_simplified():
    """AGENTS.md must not have anti-rationalization table or per-prompt discovery."""
    if not AGENTS:
        return  # AGENTS.md is gitignored — skip in CI
    assert "team-boot" in AGENTS
    assert "CDR" in AGENTS
    assert "Team Context in Use" in AGENTS
    assert "Every response MUST include" in AGENTS
    assert "_Searched" in AGENTS
    assert "Common Rationalizations" not in AGENTS
    assert "Anti-pattern" not in AGENTS
    assert "every message" not in AGENTS
    assert "First-Tool-Call Gate" not in AGENTS
    assert "CDR-2026-003 | Cloud-Native Platform Architect" not in AGENTS
    assert "CDR-YYYY-NNN" in AGENTS
    assert "## Team Context in Use" in AGENTS
    assert "J MUST equal the number of rows" in AGENTS


def test_radar_search_sh_uses_jq():
    """radar-search.sh must use jq for JSON parsing, no Python."""
    assert "jq" in RADAR_SH
    assert "python3" not in RADAR_SH
    assert "python" not in RADAR_SH


def test_radar_search_ps1_uses_convertfrom_json():
    """radar-search.ps1 must use native PowerShell JSON parsing."""
    assert "ConvertFrom-Json" in RADAR_PS1


def test_radar_search_py_deleted():
    """radar-search.py must not exist (replaced by .sh/.ps1)."""
    assert not (ROOT / "skills/tech-radar/tech-radar-context/scripts/radar-search.py").exists()


def test_tech_radar_skill_references_sh_and_ps1():
    """tech-radar SKILL.md must reference .sh and .ps1, not .py."""
    assert "radar-search.sh" in TECH_RADAR
    assert "radar-search.ps1" in TECH_RADAR
    assert "radar-search.py" not in TECH_RADAR


def test_team_setup_no_python():
    """team-setup must not reference python3."""
    assert "python3" not in SETUP
