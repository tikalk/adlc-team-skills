"""
test_boot_suggest_only.py — Class boots suggest capture; they never write.

The class boots and team-boot's Decision Capture contract detect decisions
and suggest the class capture skill (/architect-specify, /product-specify,
/change-specify, /team-levelup, /evals-specify). Writing the draft is the
capture skill's job, invoked by the user. These tests pin that no-write
contract across every decision-capture surface, so no surface can quietly
regress to auto-writing drafts again.
"""

from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

CAPTURE_SURFACES = {
    "architect-boot": ROOT / "skills/architect/architect-boot/SKILL.md",
    "product-boot": ROOT / "skills/product/product-boot/SKILL.md",
    "change-boot": ROOT / "skills/change/change-boot/SKILL.md",
    "tech-radar-boot": ROOT / "skills/tech-radar/tech-radar-boot/SKILL.md",
    "team-boot/SKILL.md": ROOT / "skills/team/team-boot/SKILL.md",
    "team-boot/decision-capture.md": ROOT / "skills/team/team-boot/references/decision-capture.md",
    "boot.sh": ROOT / "skills/team/team-boot/scripts/bash/boot.sh",
    "boot.ps1": ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1",
    "team-helpers.sh": ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh",
    "team-helpers.ps1": ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1",
    "post-setup-agents.md": ROOT / "skills/team/team-setup/references/post-setup-agents.md",
    "team-levelup": ROOT / "skills/team/team-levelup/SKILL.md",
}

FORBIDDEN_PHRASES = (
    "direct write to",
    "write a lightweight draft",
    "writes lightweight",
    "write the draft to",
    "draft written to",
    "no specify skill invocation needed",
)

BOOT_CAPTURE_SKILLS = {
    "architect-boot": "/architect-specify",
    "product-boot": "/product-specify",
    "change-boot": "/change-specify",
    "tech-radar-boot": "/architect-specify",
}


def _text(path):
    return path.read_text(encoding="utf-8")


def test_no_surface_instructs_writing_drafts():
    """No decision-capture surface may instruct the agent to write drafts."""
    for label, path in CAPTURE_SURFACES.items():
        lowered = _text(path).lower()
        for phrase in FORBIDDEN_PHRASES:
            assert phrase not in lowered, (
                f"{label}: still instructs draft writing ('{phrase}')"
            )


def test_class_boots_suggest_their_capture_skill():
    """Each class boot names its capture skill as a suggestion, never a write."""
    for name, skill in BOOT_CAPTURE_SKILLS.items():
        content = _text(CAPTURE_SURFACES[name])
        assert "suggest" in content.lower(), f"{name}: no suggestion wording"
        assert skill in content, f"{name}: capture skill {skill} not named"
        assert "_Suggested capture" in content, (
            f"{name}: missing the _Suggested capture_ output contract"
        )


def test_change_boot_splits_capture_and_mining():
    """change-boot routes in-session rationale to /change-specify and mined
    history to /change-init — both named, neither written by the boot."""
    content = _text(CAPTURE_SURFACES["change-boot"])
    assert "/change-specify" in content
    assert "/change-init" in content
    assert "Never write" in content, "change-boot: missing explicit no-write rule"


def test_team_boot_suggest_bullet_and_trigger_table():
    """team-boot's Decision Capture is suggestion-shaped on every surface.

    team-boot SKILL.md + the boot scripts carry the full contract (**Suggest**
    bullet + the Capture via trigger column); the team-helpers templates carry
    the compact AGENTS.md variant (suggestion wording + capture-skill routing).
    """
    full = ("team-boot/SKILL.md", "boot.sh", "boot.ps1")
    compact = ("team-helpers.sh", "team-helpers.ps1")
    for label in full + compact:
        content = _text(CAPTURE_SURFACES[label])
        assert "suggest" in content.lower(), f"{label}: no suggestion wording"
        for skill in ("/architect-specify", "/product-specify",
                      "/change-specify", "/team-levelup", "/evals-specify"):
            assert skill in content, f"{label}: capture skill {skill} not named"
    for label in full:
        content = _text(CAPTURE_SURFACES[label])
        assert "**Suggest**" in content, f"{label}: missing **Suggest** bullet"
        assert "Capture via" in content, f"{label}: trigger table lacks Capture via column"
    for label in compact:
        content = _text(CAPTURE_SURFACES[label])
        assert "never write drafts" in content.lower(), (
            f"{label}: compact block must still forbid writing drafts"
        )
