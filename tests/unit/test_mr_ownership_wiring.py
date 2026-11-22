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

TRACKER = SKILLS / "factory/factory-runbook/references/tracker-integration.md"
EXECUTOR = SKILLS / "factory/factory-runbook/references/executor.md"
PROVIDER_YML = SKILLS / "factory/factory-runbook/references/issues-provider.yml"
RESOLVERS_REL = [
    "skills/factory/factory-runbook/scripts/bash/resolve-mr-ownership.sh",
    "skills/factory/factory-runbook/scripts/powershell/resolve-mr-ownership.ps1",
]


OPEN_MR_BASH = SKILLS / "factory/factory-runbook/scripts/bash/open-mr.sh"
OPEN_MR_PWSH = SKILLS / "factory/factory-runbook/scripts/powershell/open-mr.ps1"


def test_connector_documents_the_operation():
    content = TRACKER.read_text(encoding="utf-8")
    assert "Operation 11" in content, "the connector must document the MR-ownership operation"
    assert "Create MR/PR with Milestone + Assignee + Gate-Label Propagation" in content, (
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
    match = re.search(r"(scripts/bash/resolve-mr-ownership\.sh)", content)
    assert match, "the connector must reference the resolver by its skill-local path"
    assert "{SKILLS_DIR}" not in content, (
        "the connector must not depend on a layout-dependent skills directory"
    )
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
    assert "Never guess a milestone, an assignee, or a gate label" in content


# ── gate-label wiring (ADR-547: AC7/AC8/AC10) ──────────────────────────────

GATE_FIXTURES = ("supervised", "autonomous")


def test_connector_documents_the_gate_label():
    content = TRACKER.read_text(encoding="utf-8")
    assert "gate_label" in content, "the connector must name the resolver's gate-label field"
    assert "ADR-547" in content, "the connector must cite the governing record"
    assert "supervised" in content and "autonomous" in content


def test_executor_hooks_the_gate_label():
    content = EXECUTOR.read_text(encoding="utf-8")
    assert "gate label" in content, "the executor hook must name the gate label"
    assert "ADR-547" in content


@pytest.mark.parametrize("gate", GATE_FIXTURES)
def test_open_mr_carries_the_gate_label_on_create(gate):
    for script in (OPEN_MR_BASH, OPEN_MR_PWSH):
        content = script.read_text(encoding="utf-8")
        assert "gate_label" in content, f"{script.name} must consume the resolver's gate label"


def test_open_mr_gitlab_create_body_names_labels():
    content = OPEN_MR_BASH.read_text(encoding="utf-8")
    assert "b.labels = o.gate_label" in content, "GitLab create body must carry the gate label in `labels`"


def test_open_mr_gitlab_reuse_adds_without_replacing():
    content = OPEN_MR_BASH.read_text(encoding="utf-8")
    assert "add_labels=" in content, "GitLab reuse must add (never replace) the gate label"


def test_open_mr_github_labels_in_the_same_step():
    content = OPEN_MR_BASH.read_text(encoding="utf-8")
    assert "issues/$number/labels" in content or "issues/\"$number\"/labels" in content or "/labels" in content, (
        "GitHub must apply the gate label through the additive labels endpoint in the same step"
    )


def test_open_mr_preserves_human_labels_on_reuse():
    for script in (OPEN_MR_BASH, OPEN_MR_PWSH):
        content = " ".join(script.read_text(encoding="utf-8").split())
        assert "only a missing gate label is added" in content.lower(), (
            f"{script.name} must state the preserve-only reuse rule"
        )


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
    assert (MIRROR / "factory-runbook/scripts/bash/resolve-mr-ownership.sh").exists(), (
        "mirror missing the ownership resolver twin"
    )
    assert (MIRROR / "factory-runbook/scripts/powershell/resolve-mr-ownership.ps1").exists(), (
        "mirror missing the ownership resolver PowerShell twin"
    )
