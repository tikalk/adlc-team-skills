"""factory-setup skill contract tests (ADR-428, RED gate).

Asserts the first-run creation contract for the factory tracker config:
- factory-setup skill ships with trigger-only description and mode references
- skill promises never-credentials / never-overwrite semantics
- tracker-integration.md halt names /factory-setup as the fix path
- team-boot suggests factory-setup when no provider config resolves

These tests MUST fail until the ADR-428 contract is implemented.
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

SKILL_DIR = ROOT / "skills/factory/factory-setup"
SKILL_MD = SKILL_DIR / "SKILL.md"
TEMPLATE = ROOT / "skills/factory/factory-mission/references/issues-provider.yml"
TRACKER_INTEGRATION = ROOT / "skills/factory/factory-mission/references/tracker-integration.md"
TEAM_BOOT_MD = ROOT / "skills/team/team-boot/SKILL.md"


def _read(path):
    """Return file text, or None when the file does not exist (RED for missing files)."""
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def test_skill_ships_with_trigger_description():
    """factory-setup must ship with a trigger-only frontmatter description."""
    content = _read(SKILL_MD)
    assert content is not None, f"missing skill: {SKILL_MD.relative_to(ROOT)}"
    assert "name: factory-setup" in content, "frontmatter must declare name: factory-setup"
    for line in content.splitlines():
        if line.startswith("description:"):
            assert "Use when" in line, "description must lead with trigger-only 'Use when'"
            break
    else:
        raise AssertionError("frontmatter must declare a description")


def test_skill_has_mode_references():
    """The skill must route detect/pick/configured modes through references."""
    content = _read(SKILL_MD)
    assert content is not None
    for mode in ("mode-detect", "mode-pick", "mode-configured"):
        assert mode in content, f"SKILL.md must reference '{mode}'"
        assert (SKILL_DIR / "references" / f"{mode}.md").exists(), (
            f"missing mode reference: skills/factory/factory-setup/references/{mode}.md"
        )


def test_skill_promises_safe_writes():
    """The skill must promise never-credentials and never-overwrite semantics."""
    content = _read(SKILL_MD)
    assert content is not None
    lowered = content.lower()
    assert "never" in lowered and "credential" in lowered, (
        "skill must state it never writes credentials"
    )
    assert "never overwrite" in lowered, "skill must state it never overwrites an existing file"
    assert ".adlc/issues-provider.yml" in content, "skill must target the canonical repo path"


def test_halt_names_factory_setup():
    """The tracker-integration halt must name /factory-setup as the fix path."""
    content = _read(TRACKER_INTEGRATION)
    assert content is not None
    assert "factory-setup" in content, (
        "tracker-integration.md must point unresolved-provider halts at /factory-setup"
    )


def test_team_boot_suggests_factory_setup():
    """team-boot must suggest factory-setup when no provider config resolves."""
    content = _read(TEAM_BOOT_MD)
    assert content is not None
    assert "factory-setup" in content, (
        "team-boot must suggest /factory-setup when no provider config resolves"
    )


def test_template_documents_label_vocabulary():
    """The template must document the factory label vocabulary for verify-only checks."""
    content = _read(TEMPLATE)
    assert content is not None
    assert "factory-stage:" in content, "template must list the lifecycle label vocabulary"
    assert "agent-can-execute" in content, "template must list the gating label vocabulary"


def test_mode_configured_verifies_labels():
    """Mode 3 must verify label presence against effective (mapped) names."""
    content = _read(SKILL_DIR / "references" / "mode-configured.md")
    assert content is not None, "missing mode-configured.md"
    lowered = content.lower()
    assert "label" in lowered, "Mode 3 must cover label vocabulary verification"
    assert "effective" in lowered or "mapping" in lowered, (
        "Mode 3 must resolve effective names through the labels: mapping"
    )


def test_template_documents_labels_mapping():
    """The template must document the optional labels: override mapping."""
    content = _read(TEMPLATE)
    assert content is not None
    assert "labels:" in content, "template must document the optional labels: mapping"
    assert "factory-stage:executing" in content, "mapping must show a lifecycle override example"


def test_mode_configured_offers_provisioning():
    """Mode 3 must offer confirm-gated creation, never headless."""
    content = _read(SKILL_DIR / "references" / "mode-configured.md")
    assert content is not None, "missing mode-configured.md"
    lowered = content.lower()
    assert "create" in lowered and "confirm" in lowered, (
        "Mode 3 must offer creation behind explicit confirmation"
    )
    assert "headless" in lowered, "Mode 3 must exclude provisioning from headless runs"
