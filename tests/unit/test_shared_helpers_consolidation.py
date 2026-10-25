"""No-stale-copies + borrower-reference guards for consolidated shared helpers.

setup-architect.{sh,ps1} (+ common/ascii/mermaid companions) and pdr-lib.{sh,ps1}
are canonical in exactly one skill each; every other skill references them by
path. This pins that contract: stale copies must not reappear, borrower
references must resolve in BOTH the source tree (skills/<group>/<skill>/) and
the installed mirror tree (.agents/skills/<skill>/, flat per skill).
"""

import os
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
MIRROR = ROOT / ".agents" / "skills"

# Canonical home per helper basename.
CANONICAL = {
    "setup-architect.sh": ROOT / "skills/architect/architect-clarify/scripts/bash/setup-architect.sh",
    "setup-architect.ps1": ROOT / "skills/architect/architect-clarify/scripts/powershell/setup-architect.ps1",
    "common.sh": ROOT / "skills/architect/architect-clarify/scripts/bash/common.sh",
    "ascii-generator.sh": ROOT / "skills/architect/architect-clarify/scripts/bash/ascii-generator.sh",
    "ascii-generator.ps1": ROOT / "skills/architect/architect-clarify/scripts/powershell/ascii-generator.ps1",
    "mermaid-generator.sh": ROOT / "skills/architect/architect-clarify/scripts/bash/mermaid-generator.sh",
    "mermaid-generator.ps1": ROOT / "skills/architect/architect-clarify/scripts/powershell/mermaid-generator.ps1",
    "pdr-lib.sh": ROOT / "skills/product/product-clarify/scripts/bash/pdr-lib.sh",
    "pdr-lib.ps1": ROOT / "skills/product/product-clarify/scripts/powershell/pdr-lib.ps1",
    # Intent run helpers (ADR-431-amendment C1, adlc-workspace#26).
    "run-branch.sh": ROOT / "skills/factory/factory-mission/scripts/bash/run-branch.sh",
    "commit-step.sh": ROOT / "skills/factory/factory-mission/scripts/bash/commit-step.sh",
    "open-mr.sh": ROOT / "skills/factory/factory-mission/scripts/bash/open-mr.sh",
}

# (borrower script, expected canonical-relative snippet in its source line)
BASH_BORROWERS = {
    ROOT / "skills/product/product-implement/scripts/bash/setup-product-implement.sh": "../../../product-clarify/scripts/bash/pdr-lib.sh",
    ROOT / "skills/product/product-init/scripts/bash/setup-product-init.sh": "../../../product-clarify/scripts/bash/pdr-lib.sh",
    ROOT / "skills/product/product-specify/scripts/bash/setup-product-specify.sh": "../../../product-clarify/scripts/bash/pdr-lib.sh",
    ROOT / "skills/product/product-implement/scripts/bash/migrate-pdr-frontmatter.sh": "../../../product-clarify/scripts/bash/pdr-lib.sh",
}

# (SKILL.md, canonical mirror-absolute path it must reference)
DOC_BORROWERS = {
    ROOT / "skills/architect/architect-analyze/SKILL.md":
        "{REPO_ROOT}/.agents/skills/architect-clarify/scripts/bash/setup-architect.sh",
    ROOT / "skills/architect/architect-implement/SKILL.md":
        "{REPO_ROOT}/.agents/skills/architect-clarify/scripts/bash/setup-architect.sh",
    ROOT / "skills/architect/architect-init/SKILL.md":
        "{REPO_ROOT}/.agents/skills/architect-clarify/scripts/bash/setup-architect.sh",
    ROOT / "skills/architect/architect-specify/SKILL.md":
        "{REPO_ROOT}/.agents/skills/architect-clarify/scripts/bash/setup-architect.sh",
    ROOT / "skills/product/product-implement/SKILL.md":
        "{REPO_ROOT}/.agents/skills/product-clarify/scripts/bash/pdr-lib.sh",
}

STALE_ARCHITECT_DIRS = [
    "architect-analyze", "architect-implement", "architect-init", "architect-specify",
]
STALE_ARCHITECT_FILES = [
    "setup-architect.sh", "setup-architect.ps1", "common.sh",
    "ascii-generator.sh", "ascii-generator.ps1",
    "mermaid-generator.sh", "mermaid-generator.ps1",
]
STALE_PRODUCT_DIRS = ["product-implement", "product-init", "product-specify"]


def test_canonical_helpers_exist():
    for name, path in CANONICAL.items():
        assert path.exists(), f"canonical {name} missing at {path}"


def test_no_stale_helper_copies():
    stale = []
    for skill in STALE_ARCHITECT_DIRS:
        for fname in STALE_ARCHITECT_FILES:
            sub = "powershell" if fname.endswith(".ps1") else "bash"
            p = ROOT / "skills/architect" / skill / "scripts" / sub / fname
            if p.exists():
                stale.append(str(p.relative_to(ROOT)))
    for skill in STALE_PRODUCT_DIRS:
        for fname, sub in (("pdr-lib.sh", "bash"), ("pdr-lib.ps1", "powershell")):
            p = ROOT / "skills/product" / skill / "scripts" / sub / fname
            if p.exists():
                stale.append(str(p.relative_to(ROOT)))
    assert not stale, f"stale helper copies reappeared: {stale}"


def test_borrower_source_lines_resolve_to_canonical():
    """Each borrower source line, resolved from its own dir, hits the canonical file."""
    for borrower, snippet in BASH_BORROWERS.items():
        content = borrower.read_text(encoding="utf-8")
        assert snippet in content, f"{borrower.name}: missing canonical reference"
        resolved = os.path.normpath(os.path.join(str(borrower.parent), snippet))
        expected = str(CANONICAL["pdr-lib.sh"])
        assert resolved == expected, f"{borrower.name}: resolves to {resolved}, want {expected}"


def test_borrower_refs_resolve_in_mirror_tree():
    """Same references must resolve under the installed flat mirror tree."""
    if not MIRROR.exists():
        pytest.skip("installed mirror absent — regenerate with adlc-cli")
    for borrower, snippet in BASH_BORROWERS.items():
        rel = borrower.relative_to(ROOT / "skills")
        # source skills/<group>/<skill>/... -> mirror .agents/skills/<skill>/...
        mirror_borrower = MIRROR / rel.parts[1] / Path(*rel.parts[2:])
        assert mirror_borrower.exists(), f"mirror missing borrower {mirror_borrower}"
        assert (MIRROR / "product-clarify/scripts/bash/pdr-lib.sh").exists(), \
            "mirror missing canonical pdr-lib.sh"
        resolved = os.path.normpath(os.path.join(str(mirror_borrower.parent), snippet))
        assert resolved == str(MIRROR / "product-clarify/scripts/bash/pdr-lib.sh"), \
            f"mirror resolve mismatch: {resolved}"


def test_skill_docs_point_at_canonical():
    for doc, canon in DOC_BORROWERS.items():
        content = doc.read_text(encoding="utf-8")
        assert canon in content, f"{doc.parent.name}/SKILL.md: missing canonical path"
    # borrower docs must not keep the bare per-skill-relative token
    for doc in [ROOT / "skills/architect/architect-analyze/SKILL.md",
                ROOT / "skills/architect/architect-implement/SKILL.md",
                ROOT / "skills/architect/architect-init/SKILL.md",
                ROOT / "skills/architect/architect-specify/SKILL.md"]:
        assert "`scripts/bash/setup-architect.sh`" not in doc.read_text(encoding="utf-8"), \
            f"{doc.parent.name}/SKILL.md: stale bare path"


def test_selective_install_guards_name_recovery_command():
    """Borrowers fail fast with the exact install command when canonical is absent."""
    consumers = [
        ROOT / "skills/product/product-implement/scripts/bash/setup-product-implement.sh",
        ROOT / "skills/product/product-init/scripts/bash/setup-product-init.sh",
        ROOT / "skills/product/product-specify/scripts/bash/setup-product-specify.sh",
        ROOT / "skills/product/product-implement/scripts/bash/migrate-pdr-frontmatter.sh",
    ]
    for path in consumers:
        content = path.read_text(encoding="utf-8")
        assert "command -v generate_pdr_index" in content, f"{path.parent.parent.name}: no guard"
        assert "adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify" in content, \
            f"{path.parent.parent.name}: guard lacks recovery command"


def test_borrower_docs_name_requires_skill():
    """Every borrower SKILL.md states its canonical-home dependency explicitly."""
    docs = {
        ROOT / "skills/architect/architect-analyze/SKILL.md": "architect-clarify",
        ROOT / "skills/architect/architect-implement/SKILL.md": "architect-clarify",
        ROOT / "skills/architect/architect-init/SKILL.md": "architect-clarify",
        ROOT / "skills/architect/architect-specify/SKILL.md": "architect-clarify",
        ROOT / "skills/product/product-implement/SKILL.md": "product-clarify",
        ROOT / "skills/product/product-init/SKILL.md": "product-clarify",
        ROOT / "skills/product/product-specify/SKILL.md": "product-clarify",
    }
    for doc, home in docs.items():
        content = doc.read_text(encoding="utf-8")
        assert "Requires" in content and home in content, f"{doc.parent.name}: no Requires line"
        assert f"--skill {home}" in content, f"{doc.parent.name}: no install command"


def test_skills_deps_manifest_valid():
    """skills-deps.json: every borrower and home must be a real skill dir."""
    import json
    manifest = json.loads((ROOT / ".skills-deps.json").read_text(encoding="utf-8"))
    assert manifest["version"] == "1.0.0"
    skill_dirs = {p.parent.name for p in ROOT.glob("skills/*/*/SKILL.md")}
    assert skill_dirs, "no skills found"
    for borrower, homes in manifest["requires"].items():
        assert borrower in skill_dirs, f"unknown borrower skill: {borrower}"
        assert borrower not in homes, f"{borrower} lists itself"
        for home in homes:
            assert home in skill_dirs, f"unknown canonical home: {home} (required by {borrower})"


# Intent orchestrators borrow the run helpers from factory-mission
# (ADR-431-amendment C1): every SKILL.md names all three by mirror path, states
# the Requires line, and the deps manifest records the dependency.
INTENT_ORCHESTRATORS = [
    ROOT / "skills/factory/factory-product/SKILL.md",
    ROOT / "skills/factory/factory-architect/SKILL.md",
]
INTENT_HELPERS = ["run-branch.sh", "commit-step.sh", "open-mr.sh"]


def test_intent_orchestrators_reference_the_run_helpers():
    for doc in INTENT_ORCHESTRATORS:
        content = doc.read_text(encoding="utf-8")
        for helper in INTENT_HELPERS:
            path = f"{{REPO_ROOT}}/.agents/skills/factory-mission/scripts/bash/{helper}"
            assert path in content, f"{doc.parent.name}/SKILL.md: missing {path}"
        assert "Requires" in content and "--skill factory-mission" in content, \
            f"{doc.parent.name}/SKILL.md: no Requires line for factory-mission"


def test_deps_manifest_records_intent_orchestrators():
    import json
    manifest = json.loads((ROOT / ".skills-deps.json").read_text(encoding="utf-8"))
    for skill in ("factory-product", "factory-architect"):
        assert "factory-mission" in manifest["requires"].get(skill, []), \
            f".skills-deps.json: {skill} must require factory-mission"
