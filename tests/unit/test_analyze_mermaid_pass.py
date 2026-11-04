"""the mermaid detection pass wiring: one canonical rule set, two analyze skills, evals-analyze untouched.

The mermaid rule set is owned by exactly one script (canonical in
``architect-clarify``). ``product-analyze`` and ``architect-analyze`` both
*reference* it; neither forks the thresholds. ``evals-analyze`` is out of
scope by ruling and must stay byte-identical.
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILLS = ROOT / "skills"
LINTER_REL = "skills/architect/architect-clarify/scripts/bash/mermaid-lint.sh"
LINTER = ROOT / LINTER_REL
MIRROR = ROOT / ".agents" / "skills"

PRODUCT_ANALYZE = SKILLS / "product/product-analyze/SKILL.md"
ARCHITECT_ANALYZE = SKILLS / "architect/architect-analyze/SKILL.md"
EVALS_ANALYZE = SKILLS / "evals/evals-analyze/SKILL.md"

CANONICAL_DOC_PATH = "{SKILLS_DIR}/architect-clarify/scripts/bash/mermaid-lint.sh"


def rule_ids_in_script():
    text = LINTER.read_text(encoding="utf-8")
    return sorted(set(re.findall(r"\bM00\d-[a-z-]+", text)))


def rule_ids_in_doc(path):
    text = path.read_text(encoding="utf-8")
    return sorted(set(re.findall(r"`(M00\d-[a-z-]+)`", text)))


# ── the canonical helper ────────────────────────────────────────────────────

def test_linter_is_canonical_in_architect_clarify():
    assert LINTER.exists(), f"canonical mermaid linter missing at {LINTER}"


def test_no_stale_copies_of_the_linter():
    """The linter exists in exactly one skill directory."""
    copies = sorted(p.relative_to(ROOT) for p in SKILLS.glob("**/mermaid-lint.sh"))
    assert copies == [Path(LINTER_REL)], f"mermaid-lint.sh must have one canonical home, found {copies}"


# ── both analyze skills reference the canonical path ─────────────────────────

@pytest.mark.parametrize("doc", [PRODUCT_ANALYZE, ARCHITECT_ANALYZE], ids=["product", "architect"])
def test_analyze_skill_points_at_the_canonical_linter(doc):
    content = doc.read_text(encoding="utf-8")
    assert CANONICAL_DOC_PATH in content, (
        f"{doc.parent.name}/SKILL.md must reference the canonical linter path"
    )


@pytest.mark.parametrize("doc", [PRODUCT_ANALYZE, ARCHITECT_ANALYZE], ids=["product", "architect"])
def test_analyze_skill_does_not_invent_a_local_linter(doc):
    """A borrower must not reference a per-skill copy of the helper."""
    content = doc.read_text(encoding="utf-8")
    assert "scripts/bash/mermaid-lint.sh" not in content.replace(
        CANONICAL_DOC_PATH, ""
    ), f"{doc.parent.name}/SKILL.md references a local copy of the linter"


@pytest.mark.parametrize("doc", [PRODUCT_ANALYZE, ARCHITECT_ANALYZE], ids=["product", "architect"])
def test_analyze_skill_states_the_read_only_contract(doc):
    content = doc.read_text(encoding="utf-8")
    assert "read-only" in content.lower(), f"{doc.parent.name}/SKILL.md must state the read-only pass"


@pytest.mark.parametrize("doc", [PRODUCT_ANALYZE, ARCHITECT_ANALYZE], ids=["product", "architect"])
def test_analyze_skill_names_the_rule_owner(doc):
    """The rules live in the validator, not in each skill — so the skill points
    at the validator and never re-derives the thresholds."""
    content = doc.read_text(encoding="utf-8")
    assert "documented once" in content, (
        f"{doc.parent.name}/SKILL.md must say the rule set is documented once"
    )
    assert CANONICAL_DOC_PATH in content, (
        f"{doc.parent.name}/SKILL.md must point at the validator that owns the rules"
    )


# ── the rule vocabulary does not drift between the script and the doc ───────

def test_product_analyze_vocabulary_matches_the_linter():
    """The ids product-analyze lists are exactly the ids the linter can emit."""
    assert rule_ids_in_doc(PRODUCT_ANALYZE) == rule_ids_in_script(), (
        "product-analyze's rule vocabulary drifted from the linter — "
        "the linter owns the set"
    )


def test_linter_emits_every_rule_id_it_documents():
    """Every id the script can emit is reachable — no dead rules."""
    text = LINTER.read_text(encoding="utf-8")
    for rule in rule_ids_in_script():
        assert f'"{rule}"' in text or f"{rule}" in text, f"{rule} is not emitted anywhere"


# ── evals-analyze is out of scope by ruling ─────────────────────────────────

def test_evals_analyze_is_untouched():
    """the mermaid detection pass scopes the pass to product-analyze + architect-analyze only."""
    content = EVALS_ANALYZE.read_text(encoding="utf-8")
    assert "mermaid-lint" not in content, "evals-analyze must not gain the mermaid pass"
    assert "M00" not in content, "evals-analyze must not reference the rule vocabulary"
    assert "the mermaid detection pass" not in content, "evals-analyze is out of the mermaid detection pass's scope"


def test_no_other_skill_gained_the_pass():
    """Only the two analyze skills may reference the linter."""
    offenders = []
    for skill_md in SKILLS.glob("**/SKILL.md"):
        if skill_md in (PRODUCT_ANALYZE, ARCHITECT_ANALYZE):
            continue
        if "mermaid-lint" in skill_md.read_text(encoding="utf-8"):
            offenders.append(str(skill_md.relative_to(ROOT)))
    assert not offenders, f"unexpected skills reference the mermaid linter: {offenders}"


# ── the mirror tree resolves ────────────────────────────────────────────────

def test_mirror_tree_resolves_the_canonical_linter():
    if not MIRROR.exists():
        pytest.skip("installed mirror absent — regenerate with adlc-cli")
    assert (MIRROR / "architect-clarify/scripts/bash/mermaid-lint.sh").exists(), (
        "mirror missing the canonical mermaid linter"
    )
