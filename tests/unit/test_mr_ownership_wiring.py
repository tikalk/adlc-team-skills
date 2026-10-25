"""the MR-ownership decision wiring: the connector operation, the executor hook, the provider config.

The resolver holds the decision; the connector performs the calls; the
executor hooks the publish step. These tests pin that the three stay
connected, and that the provider template documents the mapping per provider.
"""

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILLS = ROOT / "skills"
MIRROR = ROOT / ".agents" / "skills"

TRACKER = SKILLS / "factory/factory-mission/references/tracker-integration.md"
EXECUTOR = SKILLS / "factory/factory-mission/references/executor.md"
PROVIDER_YML = SKILLS / "factory/factory-mission/references/issues-provider.yml"
RESOLVERS_REL = [
    "skills/factory/factory-mission/scripts/bash/resolve-mr-ownership.sh",
    "skills/factory/factory-mission/scripts/powershell/resolve-mr-ownership.ps1",
]


def test_connector_documents_the_operation():
    content = TRACKER.read_text(encoding="utf-8")
    assert "Operation 11" in content, "the connector must document the MR-ownership operation"
    assert "Create MR/PR with Milestone + Assignee Propagation" in content, (
        "the operation must name what it does"
    )


def test_connector_encodes_all_five_rulings():
    content = TRACKER.read_text(encoding="utf-8")
    for ruling in (
        "All providers",
        "Silent skip",
        "Fallback chain",
        "Preserve-only",
        "Block on error",
    ):
        assert ruling in content, f"the connector must state the '{ruling}' ruling"


def test_connector_documents_the_provider_mapping():
    content = TRACKER.read_text(encoding="utf-8")
    for provider, field in (
        ("GitLab", "milestone_id"),
        ("GitHub", "milestone"),
        ("Jira", "permanent no-op"),
        ("Linear", "permanent no-op"),
    ):
        assert provider in content, f"the provider table must cover {provider}"
    assert "milestone_id" in content and "assignee_ids" in content


def test_connector_names_the_resolver_path():
    content = TRACKER.read_text(encoding="utf-8")
    assert "resolve-mr-ownership.sh" in content, "the connector must name the resolver twin"
    assert "resolve-mr-ownership.ps1" in content, "the connector must name the PowerShell twin"


def test_resolver_path_in_the_connector_resolves():
    content = TRACKER.read_text(encoding="utf-8")
    match = re.search(r"(\{REPO_ROOT\}/\.agents/skills/factory-mission/scripts/bash/resolve-mr-ownership\.sh)", content)
    assert match, "the connector must reference the resolver by its installed path"
    for rel in RESOLVERS_REL:
        source = ROOT / rel
        assert source.exists(), f"the referenced resolver is missing at {source}"


def test_executor_hooks_the_publish_step():
    content = EXECUTOR.read_text(encoding="utf-8")
    assert "Draft MR/PR ownership" in content, "the executor must hook the MR-ownership step"
    assert "Operation 11" in content, "the executor must point at the connector operation"
    assert "resolve-mr-ownership.sh" in content
    assert "resolve-mr-ownership.ps1" in content


def test_executor_states_the_never_guess_rule():
    content = EXECUTOR.read_text(encoding="utf-8")
    assert "Never guess a milestone or an assignee" in content


def test_provider_template_documents_the_mapping_per_provider():
    content = PROVIDER_YML.read_text(encoding="utf-8")
    assert content.count("#   milestone:") == 4, "all four providers must document the milestone key"
    assert content.count("#   assignee:") == 4, "all four providers must document the assignee key"
    for provider in ("provider: github", "provider: gitlab", "provider: linear", "provider: jira"):
        assert provider in content


def test_provider_template_marks_the_noop_providers():
    content = PROVIDER_YML.read_text(encoding="utf-8")
    assert content.count("#   milestone: false") == 2, "Jira and Linear have no milestone concept"


def test_mirror_carries_the_resolver():
    if not MIRROR.exists():
        pytest.skip("installed mirror absent — regenerate with adlc-cli")
    assert (MIRROR / "factory-mission/scripts/bash/resolve-mr-ownership.sh").exists(), (
        "mirror missing the ownership resolver twin"
    )
    assert (MIRROR / "factory-mission/scripts/powershell/resolve-mr-ownership.ps1").exists(), (
        "mirror missing the ownership resolver PowerShell twin"
    )
