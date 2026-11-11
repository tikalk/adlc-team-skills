"""Skill-local script boundary guards.

The scope rule: scripts stay skill-local. A skill never sources another
skill's script — cross-skill capabilities are reached by invoking the owning
skill through the agent's native Skill tool, and any helper a script needs is
vendored into that script's own skill.

This pins the invariants that make the rule hold in BOTH layouts:

* source tree — ``skills/<group>/<skill>/``
* installed flat mirror — ``<skills-dir>/<skill>/``

A relative path that escapes its own skill directory resolves in the source
tree but dangles after a flat install, so the tests below forbid it outright.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILLS = ROOT / "skills"

# Canonical home per helper basename (each skill owns its own copy or helper).
CANONICAL = {
    "setup-architect.sh": SKILLS / "architect/architect-clarify/scripts/bash/setup-architect.sh",
    "setup-architect.ps1": SKILLS / "architect/architect-clarify/scripts/powershell/setup-architect.ps1",
    "common.sh": SKILLS / "architect/architect-clarify/scripts/bash/common.sh",
    "ascii-generator.sh": SKILLS / "architect/architect-clarify/scripts/bash/ascii-generator.sh",
    "ascii-generator.ps1": SKILLS / "architect/architect-clarify/scripts/powershell/ascii-generator.ps1",
    "mermaid-generator.sh": SKILLS / "architect/architect-clarify/scripts/bash/mermaid-generator.sh",
    "mermaid-generator.ps1": SKILLS / "architect/architect-clarify/scripts/powershell/mermaid-generator.ps1",
    "pdr-lib.sh": SKILLS / "product/product-clarify/scripts/bash/pdr-lib.sh",
    "pdr-lib.ps1": SKILLS / "product/product-clarify/scripts/powershell/pdr-lib.ps1",
    # Intent run helpers (ADR-431-amendment C1, adlc-workspace#26).
    "run-branch.sh": SKILLS / "factory/factory-runbook/scripts/bash/run-branch.sh",
    "commit-step.sh": SKILLS / "factory/factory-runbook/scripts/bash/commit-step.sh",
    "open-mr.sh": SKILLS / "factory/factory-runbook/scripts/bash/open-mr.sh",
}

# Borrower scripts that used to reach into product-clarify's pdr-lib.sh.
# Under the scope rule each vendors the few functions it needs.
VENDORED_PDR_BORROWERS = [
    SKILLS / "product/product-implement/scripts/bash/setup-product-implement.sh",
    SKILLS / "product/product-init/scripts/bash/setup-product-init.sh",
    SKILLS / "product/product-specify/scripts/bash/setup-product-specify.sh",
]
# (borrower, marker proving the needed helper lives in the file itself)
VENDORED_PDR_BORROWERS_PS = {
    SKILLS / "product/product-implement/scripts/powershell/setup-product-implement.ps1": "$acceptedCount",
    SKILLS / "product/product-init/scripts/powershell/setup-product-init.ps1": "function Get-NextRecordNumber",
    SKILLS / "product/product-specify/scripts/powershell/setup-product-specify.ps1": "function Get-NextRecordNumber",
}

# A reference to another skill's private scripts, in either layout.
CROSS_SKILL_SCRIPT_PATTERNS = [
    r"\{SKILLS_DIR\}",
    r"\.\./\.\./\.\./\.\./team/workspace/scripts/",
    r"\.\./\.\./\.\./workspace/scripts/",
    r"\.\./\.\./\.\./(?:product-clarify|architect-clarify|change-clarify|team-levelup|team-setup|team-boot)/scripts/",
    r"\.\./\.\./(?:product-clarify|architect-clarify|change-clarify|team-levelup|team-setup|team-boot)/scripts/",
    r"\.\./[a-z0-9-]+/scripts/",
]

# Source directives whose target must stay inside the sourcing skill's own dir.
SOURCE_DIRECTIVE = re.compile(r"^\s*(?:source|\.)\s+(.+)$", re.MULTILINE)

STALE_ARCHITECT_DIRS = [
    "architect-analyze", "architect-implement", "architect-init", "architect-specify",
]
STALE_ARCHITECT_FILES = [
    "setup-architect.sh", "setup-architect.ps1", "common.sh",
    "ascii-generator.sh", "ascii-generator.ps1",
    "mermaid-generator.sh", "mermaid-generator.ps1",
]
STALE_PRODUCT_DIRS = ["product-implement", "product-init", "product-specify"]


def _skill_root(path: Path) -> Path:
    """skills/<group>/<skill>/ for any file below the skill's own scripts/."""
    rel = path.relative_to(SKILLS)
    return SKILLS / rel.parts[0] / rel.parts[1]


def _skill_files(suffix: str):
    return sorted(p for p in SKILLS.rglob(f"*{suffix}") if p.is_file())


def test_canonical_helpers_exist():
    for name, path in CANONICAL.items():
        assert path.exists(), f"canonical {name} missing at {path}"


def test_no_stale_helper_copies():
    """Removed duplicate helpers must not reappear in borrower skills."""
    stale = []
    for skill in STALE_ARCHITECT_DIRS:
        for fname in STALE_ARCHITECT_FILES:
            sub = "powershell" if fname.endswith(".ps1") else "bash"
            p = SKILLS / "architect" / skill / "scripts" / sub / fname
            if p.exists():
                stale.append(str(p.relative_to(ROOT)))
    for skill in STALE_PRODUCT_DIRS:
        for fname, sub in (("pdr-lib.sh", "bash"), ("pdr-lib.ps1", "powershell")):
            p = SKILLS / "product" / skill / "scripts" / sub / fname
            if p.exists():
                stale.append(str(p.relative_to(ROOT)))
    assert not stale, f"stale helper copies reappeared: {stale}"


def test_no_cross_skill_script_references():
    """No skill content may name another skill's private scripts directory."""
    hits = []
    for path in list(_skill_files(".sh")) + list(_skill_files(".ps1")) + \
            list(_skill_files(".md")) + list(_skill_files(".yml")):
        content = path.read_text(encoding="utf-8")
        for pattern in CROSS_SKILL_SCRIPT_PATTERNS:
            if re.search(pattern, content):
                hits.append(f"{path.relative_to(ROOT)}: {pattern}")
    assert not hits, (
        "cross-skill script reference (invoke the owning skill instead):\n"
        + "\n".join(hits)
    )


def test_skills_dir_placeholder_is_gone():
    """The layout-dependent placeholder must not appear in shipped content."""
    hits = [
        str(path.relative_to(ROOT))
        for path in SKILLS.rglob("*")
        if path.is_file() and path.suffix in {".md", ".sh", ".ps1", ".yml", ".yaml"}
        and "{SKILLS_DIR}" in path.read_text(encoding="utf-8")
    ]
    assert not hits, f"{{SKILLS_DIR}} survives in: {hits}"


def test_sourced_scripts_stay_inside_their_skill():
    """Every relative source target resolves inside the sourcing skill's dir.

    Variables are skipped — the check targets the literal relative hops that
    break under a flat install.
    """
    escapes = []
    for path in _skill_files(".sh"):
        own_root = _skill_root(path)
        for match in SOURCE_DIRECTIVE.finditer(path.read_text(encoding="utf-8")):
            target = match.group(1).strip().strip('"').strip("'")
            if "$" in target or not target:
                continue
            resolved = (path.parent / target).resolve()
            if own_root.resolve() not in resolved.parents and resolved != own_root.resolve():
                escapes.append(f"{path.relative_to(ROOT)} -> {target}")
    assert not escapes, (
        "source directive escapes its own skill (breaks flat install):\n"
        + "\n".join(escapes)
    )


def test_pdr_ledger_helpers_are_vendored():
    """PDR borrowers define the ledger helpers they use, locally."""
    for path in VENDORED_PDR_BORROWERS:
        content = path.read_text(encoding="utf-8")
        assert not re.search(r"(?:source|\.)\s+.*product-clarify/scripts", content), (
            f"{path.parent.parent.name}: still sources product-clarify scripts"
        )
        assert "next_record_number()" in content or "_get_project_root()" in content, (
            f"{path.parent.parent.name}: expected a vendored ledger helper"
        )
        assert "adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify" not in content, (
            f"{path.parent.parent.name}: stale selective-install guard for a script it no longer borrows"
        )

    for path, marker in VENDORED_PDR_BORROWERS_PS.items():
        content = path.read_text(encoding="utf-8")
        assert not re.search(r"(?:\.|Import-Module)\s+.*product-clarify", content), (
            f"{path.parent.parent.name}: still dot-sources product-clarify scripts"
        )
        assert marker in content, (
            f"{path.parent.parent.name}: expected vendored helper marker {marker!r}"
        )


def test_one_time_repair_script_is_retired():
    """migrate-pdr-frontmatter.sh was a one-time instance repair, not skill tooling."""
    assert not list((SKILLS / "product").rglob("migrate-pdr-frontmatter.sh")), (
        "the one-time PDR migration repair was re-added as a shipped script"
    )


def test_borrower_docs_name_requires_skill():
    """Every skill that invokes another skill states its dependency explicitly."""
    docs = {
        SKILLS / "architect/architect-analyze/SKILL.md": "architect-clarify",
        SKILLS / "architect/architect-implement/SKILL.md": "architect-clarify",
        SKILLS / "architect/architect-init/SKILL.md": "architect-clarify",
        SKILLS / "architect/architect-specify/SKILL.md": "architect-clarify",
        SKILLS / "product/product-implement/SKILL.md": "product-clarify",
        SKILLS / "product/product-init/SKILL.md": "product-clarify",
        SKILLS / "product/product-specify/SKILL.md": "product-clarify",
        SKILLS / "team/team-repair/SKILL.md": "team-setup",
    }
    for doc, home in docs.items():
        content = doc.read_text(encoding="utf-8")
        assert "Requires" in content and home in content, f"{doc.parent.name}: no Requires line"
        assert f"--skill {home}" in content, f"{doc.parent.name}: no install command"


def test_skills_deps_manifest_valid():
    """skills-deps.json: every borrower and home must be a real skill dir."""
    manifest = json.loads((ROOT / ".skills-deps.json").read_text(encoding="utf-8"))
    assert manifest["version"] == "1.0.0"
    skill_dirs = {p.parent.name for p in SKILLS.glob("*/*/SKILL.md")}
    assert skill_dirs, "no skills found"
    for borrower, homes in manifest["requires"].items():
        assert borrower in skill_dirs, f"unknown borrower skill: {borrower}"
        assert borrower not in homes, f"{borrower} lists itself"
        for home in homes:
            assert home in skill_dirs, f"unknown canonical home: {home} (required by {borrower})"


# The publish procedure lives in factory-runbook: its SKILL.md names every
# helper by a skill-local relative path; orchestrators invoke the runbook
# instead of the raw paths (ADR-431-amendment §4, as amended).
INTENT_ORCHESTRATORS = [
    SKILLS / "factory/factory-intent/SKILL.md",
    SKILLS / "factory/factory-mission/SKILL.md",
]
INTENT_HELPERS = ["run-branch.sh", "commit-step.sh", "open-mr.sh"]


def test_runbook_names_the_helpers_by_skill_local_path():
    content = (SKILLS / "factory/factory-runbook/SKILL.md").read_text(encoding="utf-8")
    for helper in INTENT_HELPERS + ["resolve-mr-ownership.sh"]:
        rel = f"scripts/bash/{helper}"
        assert rel in content, f"factory-runbook/SKILL.md: missing {rel}"
        assert (SKILLS / "factory/factory-runbook" / rel).exists(), (
            f"factory-runbook/SKILL.md names {rel}, but the file is absent"
        )


def test_intent_orchestrators_invoke_the_runbook():
    for doc in INTENT_ORCHESTRATORS:
        content = doc.read_text(encoding="utf-8")
        assert "Invoke the `factory-runbook` skill" in content, (
            f"{doc.parent.name}/SKILL.md: must delegate publish to the runbook"
        )
        assert "Requires" in content and "--skill factory-runbook" in content, (
            f"{doc.parent.name}/SKILL.md: no Requires line for factory-runbook"
        )


def test_deps_manifest_records_intent_orchestrators():
    manifest = json.loads((ROOT / ".skills-deps.json").read_text(encoding="utf-8"))
    for skill in ("factory-intent", "factory-mission"):
        assert "factory-runbook" in manifest["requires"].get(skill, []), (
            f".skills-deps.json: {skill} must require factory-runbook"
        )
