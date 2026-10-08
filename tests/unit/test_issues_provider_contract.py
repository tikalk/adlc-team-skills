"""issues-provider.yml release contract tests (ADR-427, RED gate).

Asserts the factory-owned tracker provider config contract:
- canonical template ships in the factory release next to tracker-integration.md
- template keeps the never-tokens rule and covers all factory readers
- tracker-integration.md resolves params > .adlc/issues-provider.yml > loud
  halt (no silent github default, no spec-kit path read)

These tests MUST fail until the ADR-427 contract is implemented.
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

TEMPLATE = ROOT / "skills/factory/factory-mission/references/issues-provider.yml"
TRACKER_INTEGRATION = ROOT / "skills/factory/factory-mission/references/tracker-integration.md"

NEW_PATH = ".adlc/issues-provider.yml"


def _read(path):
    """Return file text, or None when the file does not exist (RED for missing files)."""
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def test_release_ships_canonical_template():
    """The factory release must ship the canonical issues-provider.yml template."""
    content = _read(TEMPLATE)
    assert content is not None, f"missing canonical provider template: {TEMPLATE.relative_to(ROOT)}"
    assert "provider:" in content, "template must document the provider key"
    assert "Never put API tokens" in content, "template must retain the never-tokens rule"


def test_template_names_factory_readers():
    """The template header must name the factory skills that consume it."""
    content = _read(TEMPLATE)
    assert content is not None
    for reader in ("factory-mission", "factory-queue", "factory-review"):
        assert reader in content, f"template header must name consumer '{reader}'"


def test_provider_resolution_order():
    """§1 must resolve params > new path > loud halt."""
    content = _read(TRACKER_INTEGRATION)
    assert content is not None
    section_start = content.find("### 1. Provider Resolution")
    assert section_start != -1, "tracker-integration.md must keep a '### 1. Provider Resolution' section"
    next_section = content.find("### 2.", section_start)
    section = content[section_start:next_section if next_section != -1 else len(content)]
    assert "tracker_provider" in section, "resolution must honor the {{params.tracker_provider}} run override"
    assert NEW_PATH in section, f"resolution must read the canonical '{NEW_PATH}'"
    assert "halt" in section.lower(), "unresolved provider must halt loudly, never guess"


def test_no_silent_github_default():
    """The silent github fallback must be gone from provider resolution."""
    content = _read(TRACKER_INTEGRATION)
    assert content is not None
    assert "fall back to `github` if absent" not in content, (
        "tracker-integration.md must not silently default to github when no config resolves"
    )


def test_no_specify_path_references():
    """No shipped factory file may reference the legacy spec-kit provider path."""
    for path in (TRACKER_INTEGRATION, TEMPLATE):
        content = _read(path)
        assert content is not None
        assert ".specify" not in content, (
            f"{path.relative_to(ROOT)} must not reference the spec-kit path"
        )
