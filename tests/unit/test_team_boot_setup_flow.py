from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
BOOT = (ROOT / "skills/team/team-boot/SKILL.md").read_text(encoding="utf-8")
DISCOVER = (ROOT / "skills/team/team-discover/SKILL.md").read_text(encoding="utf-8")
SETUP = (ROOT / "skills/team/team-setup/SKILL.md").read_text(encoding="utf-8")


def test_team_boot_unconfigured_self_installs_team_setup():
    """Step 1 must invoke the team-setup skill when unconfigured (self-install)."""
    assert "team-setup" in BOOT
    assert "Self-install" in BOOT
    assert "invoke the `team-setup` skill" in BOOT
    assert "Team AI directives not configured." in BOOT


def test_team_boot_plan_mode_defers_with_guidance():
    """In plan/read-only mode, team-boot must defer setup and print guidance, not invoke team-setup."""
    assert "plan/read-only mode" in BOOT
    assert "do NOT invoke `team-setup`" in BOOT
    assert "Run /team-setup to:" in BOOT


def test_team_boot_declined_optout_marker():
    """A team_ai_directives: null marker must skip setup silently on every prompt."""
    assert "team_ai_directives` is `null`" in BOOT
    assert "team_setup`: `declined`" in BOOT or '"team_setup": "declined"' in BOOT
    assert "Skip setup silently on every prompt" in BOOT


def test_team_boot_step4_guard_on_configuration():
    """Step 4 (Run Discovery) must be guarded on a resolved team_ai_directives."""
    assert "**Guard**" in BOOT
    assert "only when Step 1 resolved a valid `team_ai_directives`" in BOOT
    assert "do NOT invoke `team-discover`" in BOOT


def test_team_boot_failure_handling_invokes_setup_not_discover():
    """Failure handling must invoke team-setup (build) or defer (plan) and stop before discovery."""
    failure_section = BOOT.split("### Failure Handling")[1]
    failure_section = failure_section.split("## Common Rationalizations")[0]
    assert "invoke the `team-setup` skill" in failure_section
    assert "do NOT invoke `team-discover`" in failure_section
    assert "Team AI directives not configured" in failure_section


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
    for skill in (BOOT, DISCOVER):
        assert "Do NOT walk up parent directories" in skill
        assert "up to 4" not in skill
        assert "Default fallback" not in skill


def test_team_discover_unconfigured_handover():
    """team-discover must hand over to /team-setup when unconfigured, but may still load project indexes."""
    assert "/team-setup" in DISCOVER
    failure_section = DISCOVER.split("### Failure Handling")[1]
    failure_section = failure_section.split("## Common Rationalizations")[0]
    assert "/team-setup" in failure_section
    assert "0 CDR entries searched" in failure_section
    assert "PDR/ADR indexes" in failure_section


def test_team_boot_anti_second_guessing_rationalizations():
    """team-boot must explicitly forbid second-guessing team-setup self-install on questions or meta repos."""
    assert "MANDATORY in build mode" in BOOT
    assert "Do NOT second-guess this invocation" in BOOT
    assert "meta repo" in BOOT
    assert "intrusive" in BOOT
