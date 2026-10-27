"""
test_change_specify_contract.py — Contract tests for change-specify.

change-specify captures change rationale from the current session (revert,
hotfix, fix chain, workaround, abandoned approach) as a ChDR draft with
status Proposed — the in-session counterpart of /change-init's history
mining. These tests pin its frontmatter, its capture contract, and its
routing in change-boot.
"""

from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SPECIFY = ROOT / "skills/change/change-specify/SKILL.md"
SETUP_SH = ROOT / "skills/change/change-specify/scripts/bash/setup-change-specify.sh"
SETUP_PS1 = ROOT / "skills/change/change-specify/scripts/powershell/setup-change-specify.ps1"
CHANGE_BOOT = ROOT / "skills/change/change-boot/SKILL.md"


def _content(path):
    return path.read_text(encoding="utf-8")


def _frontmatter(content):
    parts = content.split("---", 2)
    assert len(parts) >= 3, "malformed frontmatter"
    return parts[1]


def test_frontmatter_contract():
    fm = _frontmatter(_content(SPECIFY))
    assert "name: change-specify" in fm
    assert "disable-model-invocation: true" in fm
    desc = fm.split("description:", 1)[1]
    assert "use when" in desc.lower(), "description must be trigger-shaped"
    assert "/change-init" in desc, "description must route mining to /change-init"
    assert "/change-clarify" in desc, "description must route review to /change-clarify"


def test_draft_capture_contract():
    content = _content(SPECIFY)
    assert "status: proposed" in content, "drafts must carry status Proposed"
    assert "chdr-draft-template.md" in content, "must use the shared draft template"
    assert ".adlc/drafts/chdr/" in content
    assert "Provenance" in content, "Decision claims require provenance"
    assert "/change-clarify" in content, "summary must suggest /change-clarify"


def test_writes_only_drafts():
    content = _content(SPECIFY)
    lowered = content.lower()
    assert "docs/adlc/memory" in content, "must name the promotion target it never writes"
    assert "never" in lowered, "must forbid writing outside .adlc/drafts/chdr/"


def test_draft_index_regenerated():
    content = _content(SPECIFY)
    assert "chdr.md" in content, "must regenerate the drafts index"
    assert "| ChDR-" in content, "index rows must match team-boot's filter"


def test_setup_scripts_exist():
    assert SETUP_SH.exists(), "missing setup-change-specify.sh"
    assert SETUP_PS1.exists(), "missing setup-change-specify.ps1"
    for path in (SETUP_SH, SETUP_PS1):
        content = _content(path)
        assert "CHDR_DRAFTS_DIR" in content, f"{path.name}: no CHDR_DRAFTS_DIR"
        assert "NEXT_CHDR" in content, f"{path.name}: no NEXT_CHDR"


def test_change_boot_routes_in_session_capture_here():
    content = _content(CHANGE_BOOT)
    assert "/change-specify" in content, "change-boot must suggest /change-specify"
    assert "/change-init" in content, "change-boot must keep the /change-init mining pairing"
