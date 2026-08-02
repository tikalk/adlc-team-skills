from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
BOOT = (ROOT / "skills/team/team-boot/SKILL.md").read_text(encoding="utf-8")
DISCOVER = (ROOT / "skills/team/team-discover/SKILL.md").read_text(encoding="utf-8")


def test_team_boot_unconfigured_exits_early_with_handover():
    """Step 1 must output /team-setup guidance and exit early when unconfigured."""
    assert "/team-setup" in BOOT
    assert "exit the bootstrap early" in BOOT
    assert "do NOT invoke `team-discover`" in BOOT
    assert "Team AI directives not configured." in BOOT


def test_team_boot_step4_guard_on_configuration():
    """Step 4 (Run Discovery) must be guarded on a resolved team_ai_directives."""
    assert "**Guard**" in BOOT
    assert "only when Step 1 resolved a valid `team_ai_directives`" in BOOT
    assert "do NOT invoke `team-discover`" in BOOT


def test_team_boot_failure_handling_hands_over_not_discover():
    """Failure handling must hand over to /team-setup and stop before discovery."""
    failure_section = BOOT.split("### Failure Handling")[1]
    failure_section = failure_section.split("## Common Rationalizations")[0]
    assert "/team-setup" in failure_section
    assert "do NOT invoke `team-discover`" in failure_section


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
