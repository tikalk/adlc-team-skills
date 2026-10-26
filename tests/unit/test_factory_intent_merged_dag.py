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
WORKFLOW_PRODUCT = SKILL / "workflow-product.yml"
WORKFLOW_ARCHITECTURE = SKILL / "workflow-architecture.yml"

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
            assert cmd.startswith("architect") and "product" not in cmd, (
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


# ── Lane activation: thin per-lane entry workflows ──────────────────────────

LANE_FILES = {
    "product": WORKFLOW_PRODUCT,
    "architecture": WORKFLOW_ARCHITECTURE,
}

LANE_COMMAND_PREFIX = {
    "product": "product",
    "architecture": "architect",
}


def load_lane(lane):
    path = LANE_FILES[lane]
    assert path.exists(), f"skills/factory/factory-intent/{path.name} must exist"
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_lane_entry_workflows_exist():
    """Each lane has a thin entry workflow (prompt-driven lane activation)."""
    for lane, path in LANE_FILES.items():
        assert path.exists(), (
            f"{lane} lane entry workflow missing: {path.name}"
        )


def test_lane_entry_covers_single_lane_steps():
    """Each lane entry runs specify → clarify → gate → build-and-verify for
    its own lane only (no cross-lane steps)."""
    for lane, path in LANE_FILES.items():
        doc = load_lane(lane)
        steps = steps_by_id(doc)
        ids = list(steps)
        prefix = LANE_COMMAND_PREFIX[lane]
        other = "architect" if lane == "product" else "product"
        assert any("specify" in k for k in steps), f"{lane}: specify missing in {ids}"
        assert any("clarify" in k for k in steps), f"{lane}: clarify missing in {ids}"
        assert any("gate" in k for k in steps), f"{lane}: gate missing in {ids}"
        assert any("build" in k and "verify" in k for k in steps), (
            f"{lane}: build-and-verify missing in {ids}"
        )
        for sid in steps:
            assert other not in sid, (
                f"{lane} entry must not run the other lane: {sid}"
            )


def test_lane_entry_gates_are_scope_pinned():
    """Lane-entry gates keep the scope-pinned contract: product entry reads
    the PDR drafts dir only, architecture entry reads the ADR drafts dir
    only; context holds only records/since/link."""
    for lane, path in LANE_FILES.items():
        doc = load_lane(lane)
        steps = steps_by_id(doc)
        gates = [s for s in steps.values() if s.get("type") == "gate"]
        assert gates, f"{lane} entry must have a gate"
        for g in gates:
            ctx = g.get("context", {})
            assert ctx, f"{lane} entry gate should carry a context block"
            for ck in ctx.keys():
                assert ck in ALLOWED_CONTEXT_KEYS, (
                    f"{lane} entry gate: unknown context key {ck!r}"
                )
            recs = " ".join(ctx.get("records", []))
            assert "*" in recs, f"{lane} entry gate records must be globs"
            if lane == "product":
                assert "pdr" in recs.lower(), f"product entry gate: {recs}"
                assert "adr" not in recs.lower(), f"product entry must not read adr: {recs}"
            else:
                assert "adr" in recs.lower(), f"arch entry gate: {recs}"
                assert "pdr" not in recs.lower(), f"arch entry must not read pdr: {recs}"


def test_lane_entry_inputs_are_declared():
    """Every {{ inputs.* }} a lane entry references is a declared input."""
    for lane, path in LANE_FILES.items():
        doc = load_lane(lane)
        inputs = doc.get("inputs", {}) or {}
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r"\{\{\s*inputs\.([A-Za-z0-9_]+)", text):
            assert m.group(1) in inputs, (
                f"{lane} entry references undeclared input: {m.group(1)}"
            )


def test_lane_entry_matches_twin_structure():
    """Each lane entry mirrors the removed twin's step shape: specify →
    clarify → gate-decisions → build-and-verify(implement → analyze), with
    the lane's own commands and no twin-skill invokables."""
    for lane, path in LANE_FILES.items():
        doc = load_lane(lane)
        steps = steps_by_id(doc)
        prefix = LANE_COMMAND_PREFIX[lane]
        assert "specify" in steps, f"{lane}: specify missing"
        assert "clarify" in steps, f"{lane}: clarify missing"
        assert "gate-decisions" in steps, f"{lane}: gate-decisions missing"
        assert "build-and-verify" in steps, f"{lane}: build-and-verify missing"
        assert steps["specify"].get("command") == f"{prefix}-specify"
        assert steps["clarify"].get("command") == f"{prefix}-clarify"
        joint = steps["build-and-verify"]
        nested = {s.get("id"): s for s in joint.get("steps", [])}
        assert nested.get("implement", {}).get("command") == f"{prefix}-implement"
        assert nested.get("analyze", {}).get("command") == f"{prefix}-analyze"
        text = path.read_text(encoding="utf-8")
        assert not re.search(r"command:\s*factory-product", text)
        assert not re.search(r"command:\s*factory-architect", text)


def test_lane_entry_engine_valid():
    """Each lane entry parses in the workflow engine with no validation
    errors and no headless gate errors."""
    import json
    import os
    import shutil
    import subprocess

    cli_dir = os.environ.get(
        "ADLC_CLI_DIR",
        str(ROOT.parent / "adlc-cli"),
    )
    engine = os.path.join(cli_dir, "src", "workflow", "engine.mjs")
    if shutil.which("node") is None or not os.path.isfile(engine):
        pytest.skip(
            f"execution engine not available (ADLC_CLI_DIR={cli_dir})"
        )
    for lane, path in LANE_FILES.items():
        rel = str(path.relative_to(ROOT))
        r = subprocess.run(
            ["node", "--input-type=module", "-e",
             "import('./src/workflow/engine.mjs').then(m => {"
             " const eng = new m.WorkflowEngine(process.argv[1]);"
             " const def = eng.loadWorkflow(process.argv[2]);"
             " console.log(JSON.stringify({"
             " validate: m.validateWorkflow(def, eng.registry),"
             " gateErrors: m.headlessGateErrors(def)})); });",
             "--", str(ROOT), rel],
            capture_output=True, text=True,
            cwd=cli_dir,
        )
        assert r.returncode == 0, f"{lane} entry engine probe failed: {r.stderr[-500:]}"
        report = json.loads(r.stdout.strip())
        assert report["validate"] == [], (
            f"{lane} entry engine validation: {report['validate']}"
        )
        assert report["gateErrors"] == [], (
            f"{lane} entry engine gates: {report['gateErrors']}"
        )


def test_skill_documents_lane_entries():
    """SKILL.md names the per-lane entry workflows for single-lane runs."""
    text = SKILL_MD.read_text(encoding="utf-8")
    assert "workflow-product.yml" in text, (
        "SKILL.md must name the product lane entry workflow"
    )
    assert "workflow-architecture.yml" in text, (
        "SKILL.md must name the architecture lane entry workflow"
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
