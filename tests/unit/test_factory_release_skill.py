"""Contract tests for the factory-release skill (issue #95).

The skill tree skills/factory/factory-release/ must exist (renamed from
factory-deploy per the accepted alias-free rename decision, no alias); tests verify the contract plan
record. Grader-behavior coverage lives in
evals/promptfoo/tests/test_check_factory_release_gates.py (pure-python,
passes independently); two wiring tests at the end only pin that the
grader skeleton exists with the required shape.
"""
import pathlib
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILL_DIR = ROOT / "skills" / "factory" / "factory-release"
SKILL_MD = SKILL_DIR / "SKILL.md"
WORKFLOW = SKILL_DIR / "workflow.yml"
REFERENCES = SKILL_DIR / "references"
GRADER = ROOT / "evals" / "promptfoo" / "graders" / "check_factory_release_gates.py"
GRADER_TEST = ROOT / "evals" / "promptfoo" / "tests" / "test_check_factory_release_gates.py"

EXPECTED_STEPS = [
    "verify", "gate-merge", "merge", "stage", "gate-canary-expand", "canary",
    "gate-full-expand", "expand", "full", "publish",
    "close-milestone", "update-roadmap",
]
EXPECTED_GATES = ["gate-merge", "gate-canary-expand", "gate-full-expand"]

MAX_DESCRIPTION_CHARS = 1024
BODY_HARD_CAP_LINES = 500


def _read_skill():
    assert SKILL_MD.exists(), f"missing skill body {SKILL_MD.relative_to(ROOT)}"
    return SKILL_MD.read_text(encoding="utf-8")


def test_skill_tree_exists():
    assert SKILL_MD.exists(), f"missing {SKILL_MD.relative_to(ROOT)}"
    assert WORKFLOW.exists(), f"missing {WORKFLOW.relative_to(ROOT)}"
    assert REFERENCES.is_dir(), f"missing {REFERENCES.relative_to(ROOT)}/"


def test_skill_frontmatter_name_parity():
    text = _read_skill()
    assert text.startswith("---"), "SKILL.md must open with YAML frontmatter"
    parts = text.split("---", 2)
    assert len(parts) == 3, "SKILL.md frontmatter must close"
    meta = yaml.safe_load(parts[1])
    assert meta.get("name") == "factory-release"
    assert SKILL_DIR.name == meta.get("name")


def test_skill_description_shape():
    meta = yaml.safe_load(_read_skill().split("---", 2)[1])
    desc = meta.get("description")
    assert desc and desc.strip(), "description must be non-empty"
    assert len(desc) <= MAX_DESCRIPTION_CHARS
    assert desc.strip().lower().startswith("use ")


def test_no_alias_shim_remains():
    """The rename is alias-free — no factory-deploy skill or shim."""
    old_dir = ROOT / "skills" / "factory" / "factory-deploy"
    assert not old_dir.exists(), (
        f"alias shim remains at {old_dir.relative_to(ROOT)} — "
        "the accepted rename decision requires alias-free replacement"
    )


def test_skill_body_sections():
    text = _read_skill()
    assert len(text.splitlines()) <= BODY_HARD_CAP_LINES
    low = text.lower()
    for section in ["overview", "core process", "verification", "configuration"]:
        assert section in low, f"missing section: {section}"
    assert ("red flag" in low) or ("rationalization" in low)


def test_workflow_twelve_steps_three_named_gates():
    assert WORKFLOW.exists(), f"missing {WORKFLOW.relative_to(ROOT)}"
    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = (wf.get("workflow") or {}).get("steps") or wf.get("steps") or []
    ids = [s.get("id") for s in steps]
    assert ids == EXPECTED_STEPS, f"expected {EXPECTED_STEPS}, got {ids}"
    gates = [s.get("id") for s in steps if s.get("type") == "gate"]
    assert gates == EXPECTED_GATES, f"expected gates {EXPECTED_GATES}, got {gates}"


def test_workflow_terminal_step_ordering():
    """close-milestone then update-roadmap follow publish, terminal."""
    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = (wf.get("workflow") or {}).get("steps") or wf.get("steps") or []
    ids = [s.get("id") for s in steps]
    pub = ids.index("publish")
    assert ids.index("close-milestone") == pub + 1, (
        "close-milestone must immediately follow publish")
    assert ids.index("update-roadmap") == pub + 2, (
        "update-roadmap must follow close-milestone")
    assert ids[-1] == "update-roadmap" or ids[-1] == "handoff" or "update-roadmap" in ids[-2:], (
        "milestone/roadmap steps are terminal; monitor handoff stays last or folds into publish")


def test_close_milestone_step_semantics():
    """halt-first milestone close via issues-provider only."""
    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = (wf.get("workflow") or {}).get("steps") or wf.get("steps") or []
    step = next(s for s in steps if s.get("id") == "close-milestone")
    prompt = str(step.get("prompt", "")).lower()
    assert prompt, "close-milestone step must carry a prompt"
    assert "milestone" in prompt
    assert "halt" in prompt, "close-milestone must be halt-first on open issues"
    assert "open issue" in prompt or "open issues" in prompt
    assert "no-op" in prompt or "none" in prompt, (
        "no milestone linked must be a recorded no-op, not a halt")
    assert "issues-provider" in prompt or "issues provider" in prompt or "provider" in prompt, (
        "tracker writes go through the issues-provider only"
    )


def test_update_roadmap_step_semantics():
    """roadmap flip committed through the run's publish path."""
    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = (wf.get("workflow") or {}).get("steps") or wf.get("steps") or []
    step = next(s for s in steps if s.get("id") == "update-roadmap")
    prompt = str(step.get("prompt", "")).lower()
    assert prompt, "update-roadmap step must carry a prompt"
    assert "roadmap.md" in prompt
    assert "closed" in prompt
    assert "commit" in prompt or "publish path" in prompt, (
        "roadmap flip is committed through the run's publish path, never a local edit"
    )


def test_workflow_parses_in_execution_engine():
    """The execution engine (adlc-cli subset parser) must accept all 12 steps.

    PyYAML files the engine cannot parse (flush-left lists, folded
    single-quoted multi-line scalars silently truncate) pass a green
    PyYAML check but fail the executor at ci-integrity time, so this
    test pins engine-parseability: 12 steps, 3 gates, inputs intact.
    """
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
            f"execution engine not available (ADLC_CLI_DIR={cli_dir}); "
            "PyYAML contract test above still guards step/gate shape"
        )
    r = subprocess.run(
        ["node", "--input-type=module", "-e",
         "import('./src/workflow/engine.mjs').then(m => {"
         " const eng = new m.WorkflowEngine(process.argv[1]);"
         " const def = eng.loadWorkflow(process.argv[2]);"
         " console.log(JSON.stringify({steps: def.steps.map(s => s.id),"
         " inputs: Object.keys(def.inputs || {}),"
         " validate: m.validateWorkflow(def, eng.registry),"
         " gateErrors: m.headlessGateErrors(def)})); });",
         "--", str(ROOT), str(WORKFLOW)],
        capture_output=True, text=True,
        cwd=cli_dir,
    )
    assert r.returncode == 0, f"engine probe failed: {r.stderr[-500:]}"
    report = json.loads(r.stdout.strip())
    assert report["steps"] == EXPECTED_STEPS, (
        f"engine reads {report['steps']}, expected {EXPECTED_STEPS}")
    assert set(report["inputs"]) >= {"route", "verdict_merge", "verdict_canary", "verdict_full", "mr_url"}, (
        f"engine inputs {report['inputs']} missing declared inputs")
    assert report["validate"] == [], f"engine validation: {report['validate']}"
    assert report["gateErrors"] == [], f"engine gates: {report['gateErrors']}"


def test_skill_both_gates_green_same_sha_no_autoapprove():
    low = _read_skill().lower()
    assert "both gates green" in low
    assert "same sha" in low
    assert "exact-head" in low or "exact head" in low
    assert "auto-approve" in low, "skill must name the forbidden auto-approve tier"
    assert "no auto-approve" in low or "never auto-approve" in low or "without auto-approve" in low


def test_skill_head_moved_discards_and_reverifies():
    low = _read_skill().lower()
    assert "head-moved" in low or "head moved" in low
    assert "re-verify" in low or "reverify" in low


def test_skill_chdr_on_nonobvious_rationale_only():
    low = _read_skill().lower()
    assert "chdr" in low
    assert "non-obvious" in low or "nonobvious" in low


def test_skill_monitoring_is_factory_monitor_scope():
    low = _read_skill().lower()
    assert "continuous monitoring" in low or "continuous-monitoring" in low
    assert "factory-monitor" in low


def test_grader_skeleton_exists_with_return_shape():
    assert GRADER.exists(), f"missing {GRADER.relative_to(ROOT)}"
    assert GRADER_TEST.exists(), f"missing {GRADER_TEST.relative_to(ROOT)}"
    text = GRADER.read_text(encoding="utf-8")
    assert "def get_assert" in text
    assert "1.0" in text and "0.0" in text


def test_grader_vocabulary_matches_skill_prose():
    """D1: the grader's safety vocabulary must match the shipped prose.

    Gate names, same-SHA phrasing, and the exact-head rule are hand-repeated
    across SKILL.md, the grader regexes, and both test files. A prose reword
    that the grader silently stops matching would decouple the eval from the
    skill it claims to grade — so every grader keyword pattern must match at
    least one passage in the skill prose, failing loudly on drift.
    """
    import re
    skill = _read_skill()
    refs = ROOT / "skills" / "factory" / "factory-release" / "references"
    prose = skill + "\n" + "\n".join(
        p.read_text(encoding="utf-8") for p in sorted(refs.glob("*.md"))
    )
    low = prose.lower()
    for pattern in [
        r"merge gate",
        r"checkpoint 3",
        r"both gates green",
        r"same sha",
        r"exact.head",
        r"head.moved",
        r"human",
        r"override",
    ]:
        assert re.search(pattern, low), (
            f"grader vocabulary {pattern!r} matches no skill prose — "
            "eval decoupled from the skill it grades"
        )
