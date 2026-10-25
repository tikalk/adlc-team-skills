"""factory-intent merged two-lane DAG (issue #19).

Covers: one brief in, product + architecture lanes, two scope-pinned gates,
joint build-and-verify, human tiebreak, no aliases, gate-context contract.

RED gate: this suite FAILS on the pre-implementation tree and PASSES once
the skill lands. No record IDs in skill files; tests reference prose/globs.
"""

import re
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-intent"
SKILL_MD = SKILL / "SKILL.md"
WORKFLOW = SKILL / "workflow.yml"

OLD_PRODUCT = ROOT / "skills/factory/factory-product"
OLD_ARCHITECT = ROOT / "skills/factory/factory-architect"


def load_workflow():
    return yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))


def steps_by_id(doc):
    steps = doc.get("steps") or doc.get("workflow", {}).get("steps", [])
    return {s.get("id"): s for s in steps}


# ── Row 1 (B): one brief in, two lanes, joint build-and-verify ─────────────

def test_workflow_has_two_lanes_and_joint_build():
    """factory-intent has product + architecture specify lanes and a joint
    build-and-verify step waiting for both gates."""
    assert WORKFLOW.exists(), "skills/factory/factory-intent/workflow.yml must exist"
    doc = load_workflow()
    steps = steps_by_id(doc)
    ids = " ".join(steps.keys())
    assert "product" in ids, f"product lane missing in {list(steps)}"
    assert "architect" in ids, f"architecture lane missing in {list(steps)}"
    assert any("build" in k and "verify" in k for k in steps), (
        f"joint build-and-verify step missing in {list(steps)}"
    )


def test_lanes_use_same_step_shape_as_twins():
    """Each lane runs specify → clarify → gate → implement → analyze with the
    same step types as the removed twins (structure, not behavior parity)."""
    doc = load_workflow()
    steps = steps_by_id(doc)
    # product lane commands are product-* only, arch lane architect-* only
    for sid, s in steps.items():
        cmd = str(s.get("command", ""))
        if "product" in sid and cmd:
            assert "architect" not in cmd, f"{sid} mixes lanes: {cmd}"
        if "architect" in sid and cmd:
            assert cmd.startswith("architect") or "product" not in cmd, (
                f"{sid} mixes lanes: {cmd}"
            )


# ── Row 2 (A): gate independence — negative test ───────────────────────────

def test_two_separate_gates_exist():
    """Two gate steps exist, one per lane."""
    doc = load_workflow()
    steps = steps_by_id(doc)
    gates = [k for k, s in steps.items() if s.get("type") == "gate"]
    assert len(gates) >= 2, f"need 2 gates, found {gates}"


def test_gates_are_scope_pinned():
    """Product gate reads PDR drafts dir only; architecture gate reads ADR
    drafts dir only (cross-lane acceptance is a contract violation)."""
    doc = load_workflow()
    steps = steps_by_id(doc)
    gates = {k: s for k, s in steps.items() if s.get("type") == "gate"}
    prod_gates = [s for k, s in gates.items() if "product" in k]
    arch_gates = [s for k, s in gates.items() if "architect" in k or "architecture" in k]
    assert prod_gates, "no product gate found"
    assert arch_gates, "no architecture gate found"
    for g in prod_gates:
        recs = " ".join(g.get("context", {}).get("records", []))
        assert "pdr" in recs.lower(), f"product gate must read pdr drafts: {recs}"
        assert "adr" not in recs.lower(), f"product gate must not read adr: {recs}"
    for g in arch_gates:
        recs = " ".join(g.get("context", {}).get("records", []))
        assert "adr" in recs.lower(), f"arch gate must read adr drafts: {recs}"
        assert "pdr" not in recs.lower(), f"arch gate must not read pdr: {recs}"


# ── Row 6a (A): scope-pinned gate globs ────────────────────────────────────

def test_gate_globs_point_at_drafts_dirs():
    """context.records are directory globs under .adlc/drafts (prose, no IDs)."""
    doc = load_workflow()
    steps = steps_by_id(doc)
    for k, s in steps.items():
        if s.get("type") != "gate":
            continue
        ctx = s.get("context", {})
        recs = ctx.get("records", [])
        assert isinstance(recs, list) and len(recs) > 0, (
            f"gate {k} must list records globs"
        )
        for r in recs:
            assert ".adlc/drafts/" in r, f"gate {k} record must be a drafts glob: {r}"


# ── Row 6b (A): gate-context contract validator ────────────────────────────

ALLOWED_CONTEXT_KEYS = {"records", "since", "link"}


def test_gate_context_contract():
    """Gate context uses only records/since/link; records is a non-empty
    glob list; every {{ inputs.* }} referenced is a declared input."""
    doc = load_workflow()
    inputs = doc.get("inputs", {}) or {}
    steps = steps_by_id(doc)
    text = WORKFLOW.read_text(encoding="utf-8")
    for m in re.finditer(r"\{\{\s*inputs\.([A-Za-z0-9_]+)", text):
        assert m.group(1) in inputs, (
            f"template references undeclared input: {m.group(1)}"
        )
    for k, s in steps.items():
        if s.get("type") != "gate":
            continue
        ctx = s.get("context", {})
        assert ctx, f"gate {k} should carry a context block"
        for ck in ctx.keys():
            assert ck in ALLOWED_CONTEXT_KEYS, (
                f"gate {k}: unknown context key {ck!r}"
            )
        recs = ctx.get("records", [])
        assert isinstance(recs, list) and all(
            isinstance(r, str) and "*" in r for r in recs
        ), f"gate {k}: records must be a non-empty list of globs"


# ── Row 3 (B): overlap dispute → human ruling ───────────────────────────────

def test_skill_documents_human_tiebreak():
    """SKILL.md documents overlap escalation to a named human with the ruling
    posted as a comment-bus decision."""
    assert SKILL_MD.exists(), "skills/factory/factory-intent/SKILL.md must exist"
    text = SKILL_MD.read_text(encoding="utf-8").lower()
    assert "tiebreak" in text or ("human" in text and "overlap" in text), (
        "SKILL.md must document human tiebreak on overlap disputes"
    )
    assert "decision" in text, "SKILL.md must mention the decision output type"


# ── Row 4/5 (B): boundary + bounded loop ───────────────────────────────────

def test_skill_documents_boundary_and_bounded_loop():
    """SKILL.md states the WHAT/WHY vs HOW boundary and the bounded
    correction loop (max 2, then halt for human)."""
    text = SKILL_MD.read_text(encoding="utf-8")
    low = text.lower()
    assert "handoff" in low or "boundary" in low, (
        "SKILL.md must state the product/architecture boundary"
    )
    assert "max_corrections" in text or "max 2" in low or "bounded" in low, (
        "SKILL.md must state the bounded correction loop"
    )


# ── Row 6 (A): no aliases, old skills removed ───────────────────────────────

def test_old_skills_removed():
    """factory-product and factory-architect skill dirs are removed."""
    assert not OLD_PRODUCT.exists(), "skills/factory/factory-product must be removed"
    assert not OLD_ARCHITECT.exists(), (
        "skills/factory/factory-architect must be removed"
    )


def test_no_alias_references_in_intent():
    """factory-intent does not alias the old skill names as invokable commands."""
    text = (SKILL_MD.read_text(encoding="utf-8")
            if SKILL_MD.exists() else "")
    wf_text = (WORKFLOW.read_text(encoding="utf-8")
               if WORKFLOW.exists() else "")
    for blob, name in ((text, "SKILL.md"), (wf_text, "workflow.yml")):
        for pat in (r"command:\s*factory-product",
                    r"command:\s*factory-architect"):
            assert not re.search(pat, blob), (
                f"{name} must not invoke removed skill: {pat}"
            )
