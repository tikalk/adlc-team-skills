"""factory-runbook shared home: one canonical home for factory run mechanics.

Nine factory skills borrow run behavior that used to live inside
factory-mission: the publish scripts and the run contracts. The runbook owns
both — scripts are canonical here, contracts are canonical here. Publish
users invoke it; contract borrowers reference it by installed path.
"""

import json
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-runbook"

BASH_SCRIPTS = ["run-branch.sh", "commit-step.sh", "open-mr.sh", "resolve-mr-ownership.sh"]
PS_SCRIPTS = ["run-branch.ps1", "commit-step.ps1", "open-mr.ps1", "resolve-mr-ownership.ps1"]
REFERENCES = [
    "executor.md",
    "tracker-integration.md",
    "lanes.md",
    "mission-brief-template.md",
    "issues-provider.yml",
    "run-context.md",
]

# Orchestrators that post changes delegate publish to the runbook.
PUBLISH_USERS = [
    ROOT / "skills/factory/factory-intent/SKILL.md",
    ROOT / "skills/factory/factory-mission/SKILL.md",
]
# Skills that borrow run contracts by installed path.
REF_BORROWERS = [
    ROOT / "skills/factory/factory-init/SKILL.md",
    ROOT / "skills/factory/factory-learn/SKILL.md",
    ROOT / "skills/factory/factory-orchestrator/SKILL.md",
    ROOT / "skills/factory/factory-queue/SKILL.md",
    ROOT / "skills/factory/factory-review/SKILL.md",
    ROOT / "skills/factory/factory-setup/SKILL.md",
    ROOT / "skills/factory/factory-tickets/SKILL.md",
    ROOT / "skills/factory/factory-review/references/review-loop.md",
]

INVOKE_NEEDLE = "Invoke the `factory-runbook` skill"


def _frontmatter(skill_file: Path) -> dict:
    parts = skill_file.read_text(encoding="utf-8").split("---", 2)
    assert len(parts) >= 3, f"Malformed frontmatter in {skill_file}"
    return yaml.safe_load(parts[1]) or {}


def test_runbook_skill_is_present_and_invocable():
    meta = _frontmatter(SKILL / "SKILL.md")
    assert meta.get("name") == "factory-runbook", "skill name must match its directory"
    description = meta.get("description")
    assert isinstance(description, str) and description.strip(), "runbook needs a trigger description"
    assert not meta.get("disable-model-invocation"), (
        "the runbook is invoked by orchestrators — it must stay model-invocable"
    )


def test_canonical_publish_scripts_exist():
    missing = [n for n in BASH_SCRIPTS if not (SKILL / "scripts/bash" / n).exists()]
    missing += [n for n in PS_SCRIPTS if not (SKILL / "scripts/powershell" / n).exists()]
    assert not missing, f"runbook missing publish scripts: {missing}"


def test_no_stale_publish_scripts_in_mission():
    stale = [n for n in BASH_SCRIPTS + PS_SCRIPTS
             if list((ROOT / "skills/factory/factory-mission/scripts").rglob(n))]
    assert not stale, f"stale publish scripts reappeared under factory-mission: {stale}"


def test_canonical_contract_refs_exist():
    missing = [n for n in REFERENCES if not (SKILL / "references" / n).exists()]
    assert not missing, f"runbook missing contract references: {missing}"
    assert (SKILL / "mission-template.yml").exists(), "runbook missing mission-template.yml"


def test_no_stale_contract_refs_in_mission():
    mission = ROOT / "skills/factory/factory-mission"
    stale = [n for n in REFERENCES + ["mission-template.yml"]
             if list(mission.rglob(n))]
    assert not stale, f"stale contract refs reappeared under factory-mission: {stale}"
    assert (mission / "references/agent-integrations.md").exists(), (
        "agent-integrations.md is mission-local and must stay"
    )


def test_publish_users_invoke_the_runbook():
    for doc in PUBLISH_USERS:
        content = doc.read_text(encoding="utf-8")
        assert INVOKE_NEEDLE in content, f"{doc.parent.name}: must delegate publish ({INVOKE_NEEDLE})"
        assert "factory-mission/scripts/" not in content, (
            f"{doc.parent.name}: raw helper path bypasses the runbook"
        )


def test_contract_borrowers_name_the_runbook():
    for doc in REF_BORROWERS:
        content = doc.read_text(encoding="utf-8")
        assert "factory-runbook" in content, f"{doc}: must reference the runbook home"
        assert "Requires" in content, f"{doc}: must carry a Requires line for selective installs"


def test_no_legacy_home_pointers_anywhere_in_skills():
    hits = []
    for path in sorted((ROOT / "skills").rglob("*.md")):
        content = path.read_text(encoding="utf-8")
        for token in ("factory-mission/scripts", "factory-mission/references",
                      "factory-mission/mission-template"):
            if token in content:
                hits.append(f"{path.relative_to(ROOT)}: {token}")
    assert not hits, f"legacy factory-mission home pointers survive:\n" + "\n".join(hits)


def test_deps_manifest_closure_points_at_runbook():
    manifest = json.loads((ROOT / ".skills-deps.json").read_text(encoding="utf-8"))
    requires = manifest["requires"]
    for skill in ("factory-intent", "factory-mission", "factory-init", "factory-learn",
                  "factory-orchestrator", "factory-queue", "factory-review",
                  "factory-setup", "factory-tickets"):
        assert "factory-runbook" in requires.get(skill, []), (
            f".skills-deps.json: {skill} must require factory-runbook"
        )
    for skill in ("factory-intent", "factory-mission"):
        assert "factory-mission" not in requires.get(skill, []), (
            f".skills-deps.json: {skill} must not borrow from the sibling orchestrator"
        )


def test_no_raw_mr_create_calls_in_factory_skills():
    """MRs are opened only through the runbook helpers, never by inlined
    tracker calls. Verdict/review calls (gh pr review, glab mr approve)
    are unaffected — only create verbs are banned."""
    hits = []
    for path in sorted((ROOT / "skills/factory").glob("*/SKILL.md")):
        content = path.read_text(encoding="utf-8")
        for token in (" pr create", " mr create"):
            if token in content:
                hits.append(f"{path.relative_to(ROOT)}: {token.strip()}")
    assert not hits, f"inlined MR creation bypasses the runbook:\n" + "\n".join(hits)


MOVED_CONTRACTS = [
    "executor.md",
    "tracker-integration.md",
    "lanes.md",
    "mission-brief-template.md",
    "issues-provider.yml",
]


def test_mission_home_holds_no_moved_contracts():
    """factory-mission/references/ keeps only its local file; anything else
    is a stale copy the moves left behind."""
    mission_refs = ROOT / "skills/factory/factory-mission/references"
    assert sorted(p.name for p in mission_refs.iterdir() if p.is_file()) == [
        "agent-integrations.md",
    ]


def test_no_bare_relative_pointers_at_moved_contracts():
    """Bare `references/<file>` pointers inside factory-mission used to
    resolve locally; after the move they dangle. They must name the runbook
    home like every other borrower."""
    text = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text(encoding="utf-8")
    hits = [n for n in MOVED_CONTRACTS if f"`references/{n}`" in text]
    assert not hits, f"dangling bare-relative pointers in factory-mission: {hits}"
