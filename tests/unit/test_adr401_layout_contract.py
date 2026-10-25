"""the shared layout layout contract tests (RED gate).

Asserts the docs/adlc layout contract outcomes:
- shared path constants defined in paths.sh / paths.ps1
- gitignore allowlist replaces the wholesale ".adlc/" ignore
- no dead .adlc subdirs (architecture/context/skills)
- boot.sh dual-reads docs/adlc/memory and legacy .adlc/memory for counts
- PRD/AD/roadmap/ChDR outputs repointed under docs/adlc
- architect-boot primary ADR index under docs/adlc/memory (legacy fallback)
- AD-template links memory via relative memory/ paths

These tests MUST fail until the shared layout layout contract is implemented.
"""
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

PATHS_SH = ROOT / "skills/team/workspace/scripts/bash/paths.sh"
PATHS_PS1 = ROOT / "skills/team/workspace/scripts/powershell/paths.ps1"
SETUP_WORKSPACE_SH = ROOT / "skills/team/workspace/scripts/bash/setup-workspace.sh"
BOOT_SH = ROOT / "skills/team/team-boot/scripts/bash/boot.sh"
SETUP_PRODUCT_SH = ROOT / "skills/product/product-implement/scripts/bash/setup-product-implement.sh"
SETUP_ARCHITECT_SH = ROOT / "skills/architect/architect-clarify/scripts/bash/setup-architect.sh"
FACTORY_QUEUE_SKILL = ROOT / "skills/factory/factory-queue/SKILL.md"
SETUP_CHANGE_PUBLISH_SH = ROOT / "skills/change/change-publish/scripts/bash/setup-change-publish.sh"
ARCHITECT_BOOT_SKILL = ROOT / "skills/architect/architect-boot/SKILL.md"
AD_TEMPLATE = ROOT / "skills/architect/templates/AD-template.md"


def _read(path):
    """Return file text, or None when the file does not exist (RED for missing files)."""
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def test_paths_sh_defines_constants():
    """paths.sh/paths.ps1 must define the shared layout shared layout constants and gitignore allowlist."""
    bash = _read(PATHS_SH)
    assert bash is not None, f"missing shared path constants script: {PATHS_SH.relative_to(ROOT)}"
    expected = {
        "ADLC_DIR": ".adlc",
        "DOCS_ADLC_DIR": "docs/adlc",
        "DOCS_ADLC_MEMORY": "docs/adlc/memory",
        "DOCS_ADLC_PRODUCT": "docs/adlc/product",
        "DOCS_ADLC_ARCHITECT": "docs/adlc/architect",
        "ADLC_DRAFTS": ".adlc/drafts",
    }
    for name, value in expected.items():
        pattern = (
            rf'^(?:export\s+|readonly\s+)*{re.escape(name)}='
            rf'[\'"][^\'"]*{re.escape(value)}[^\'"]*[\'"]'
        )
        assert re.search(pattern, bash, re.MULTILINE), (
            f"paths.sh must define {name} with value containing '{value}'"
        )
    assert "GITIGNORE_RULES_ALLOWLIST" in bash, "paths.sh must define GITIGNORE_RULES_ALLOWLIST"
    assert "!.adlc/init-options.json" in bash, (
        "paths.sh GITIGNORE_RULES_ALLOWLIST must un-ignore .adlc/init-options.json"
    )

    ps1 = _read(PATHS_PS1)
    assert ps1 is not None, f"missing shared path constants script: {PATHS_PS1.relative_to(ROOT)}"
    for name, value in expected.items():
        assert name in ps1, f"paths.ps1 must define ${name}"
        assert value in ps1, f"paths.ps1 {name} must reference '{value}'"
    assert "GITIGNORE_RULES_ALLOWLIST" in ps1, "paths.ps1 must define GITIGNORE_RULES_ALLOWLIST"
    assert "!.adlc/init-options.json" in ps1, (
        "paths.ps1 GITIGNORE_RULES_ALLOWLIST must un-ignore .adlc/init-options.json"
    )


def test_setup_workspace_gitignore_allowlist():
    """setup-workspace.sh must drop the wholesale .adlc/ ignore in favor of the allowlist."""
    content = _read(SETUP_WORKSPACE_SH)
    assert content is not None
    assert '".adlc/"' not in content, (
        'setup-workspace.sh must not keep ".adlc/" as a GITIGNORE_RULES entry (wholesale ignore)'
    )
    assert ("paths.sh" in content) or ("!.adlc/drafts/" in content), (
        "setup-workspace.sh must source/reference paths.sh or inline the !.adlc/drafts/ allowlist"
    )


def test_setup_workspace_no_dead_dirs():
    """ADLC_SUBDIRS must not create dead dirs; product and drafts must remain."""
    content = _read(SETUP_WORKSPACE_SH)
    assert content is not None
    match = re.search(r"ADLC_SUBDIRS=\((.*?)\)", content, re.S)
    assert match, "setup-workspace.sh must define the ADLC_SUBDIRS array"
    items = re.findall(r'"([^"]+)"', match.group(1))
    for dead in ("architecture", "context", "skills"):
        assert dead not in items, f"ADLC_SUBDIRS must not create dead dir '{dead}'"
    for kept in ("product", "drafts"):
        assert kept in items, f"ADLC_SUBDIRS must still create '{kept}'"


def test_boot_sh_dual_read_counts():
    """boot.sh memory counting must read docs/adlc/memory with legacy .adlc/memory fallback."""
    content = _read(BOOT_SH)
    assert content is not None
    start = content.find("ADR_COUNT")
    assert start != -1, "boot.sh must count ADR records (ADR_COUNT)"
    end = content.find("EVAL_COUNT", start)
    assert end != -1, "boot.sh must count eval records (EVAL_COUNT)"
    section = content[start:end]
    assert "docs/adlc/memory" in section, (
        "counting section must read memory counts from docs/adlc/memory"
    )
    assert ".adlc/memory" in section, (
        "counting section must fall back to legacy .adlc/memory"
    )


def test_prd_output_target_repointed():
    """PRD output must land at docs/adlc/product/PRD.md, not bare repo-root PRD.md."""
    content = _read(SETUP_PRODUCT_SH)
    assert content is not None
    assert re.search(r"PRD_FILE=[^\n]*docs/adlc/product/PRD\.md", content), (
        "PRD_FILE must point at docs/adlc/product/PRD.md"
    )
    assert not re.search(r"PRD_FILE=[^\n]*REPO_ROOT/PRD\.md", content), (
        "PRD_FILE must not point at the bare repo-root PRD.md"
    )


def test_ad_output_target_repointed():
    """AD output must land at docs/adlc/architect/AD.md with views under docs/adlc/architect/views."""
    content = _read(SETUP_ARCHITECT_SH)
    assert content is not None
    assert re.search(r"AD_FILE=[^\n]*docs/adlc/architect/AD\.md", content), (
        "AD_FILE must point at docs/adlc/architect/AD.md"
    )
    assert "docs/adlc/architect/views" in content, (
        "view outputs must live under docs/adlc/architect/views"
    )


def test_roadmap_output_target_repointed():
    """factory-queue roadmap must be docs/adlc/product/roadmap.md, not .adlc/roadmap.md."""
    content = _read(FACTORY_QUEUE_SKILL)
    assert content is not None
    assert "docs/adlc/product/roadmap.md" in content, (
        "factory-queue must write the roadmap to docs/adlc/product/roadmap.md"
    )
    assert ".adlc/roadmap.md" not in content, (
        "factory-queue must not reference the legacy .adlc/roadmap.md path"
    )


def test_change_publish_memory_repointed():
    """change-publish memory must live under docs/adlc/memory (chdr dir + chdr.md index)."""
    content = _read(SETUP_CHANGE_PUBLISH_SH)
    assert content is not None
    assert re.search(r"MEMORY_DIR=[^\n]*docs/adlc/memory/chdr(?!\.md)", content), (
        "MEMORY_DIR must point at docs/adlc/memory/chdr"
    )
    assert re.search(r"MEMORY_INDEX=[^\n]*docs/adlc/memory/chdr\.md", content), (
        "MEMORY_INDEX must point at docs/adlc/memory/chdr.md"
    )


def test_architect_boot_dual_read_index():
    """architect-boot primary ADR index is docs/adlc/memory/adr/adr.md; legacy path is fallback."""
    content = _read(ARCHITECT_BOOT_SKILL)
    assert content is not None
    lines = content.splitlines()
    primary_lines = [ln for ln in lines if "Primary" in ln]
    fallback_lines = [ln for ln in lines if "Fallback" in ln]
    assert primary_lines and any(
        "docs/adlc/memory/adr/adr.md" in ln for ln in primary_lines
    ), "primary ADR index must be docs/adlc/memory/adr/adr.md"
    assert fallback_lines and any(
        ".adlc/memory/adr/adr.md" in ln for ln in fallback_lines
    ), "legacy .adlc/memory/adr/adr.md must remain as fallback"


def test_ad_template_links_relative():
    """AD-template must link memory via relative memory/ paths, never .adlc link syntax."""
    content = _read(AD_TEMPLATE)
    assert content is not None
    assert re.search(r"\]\((?:\.\./)*memory/(?:adr/adr\.md|constitution\.md)", content), (
        "AD-template must reference memory via relative memory/... links"
    )
    assert "](.adlc/memory" not in content, (
        "AD-template must not use .adlc/memory in link syntax"
    )
