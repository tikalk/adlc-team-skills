"""Contract tests for the factory-deploy skill (issue #17).

The skill tree at skills/factory/factory-deploy/ exists; these tests
verify its contract against the plan of record.
Grader-behavior coverage lives in
evals/promptfoo/tests/test_check_factory_deploy_gates.py (pure-python,
passes independently); the two wiring tests at the end of this file only
pin that the grader skeleton exists with the required return shape.
"""
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILL_DIR = ROOT / "skills" / "factory" / "factory-deploy"
SKILL_MD = SKILL_DIR / "SKILL.md"
WORKFLOW = SKILL_DIR / "workflow.yml"
REFERENCES = SKILL_DIR / "references"
GRADER = ROOT / "evals" / "promptfoo" / "graders" / "check_factory_deploy_gates.py"
GRADER_TEST = ROOT / "evals" / "promptfoo" / "tests" / "test_check_factory_deploy_gates.py"

EXPECTED_STEPS = [
    "verify", "gate-merge", "merge", "stage", "gate-canary-expand", "canary",
    "gate-full-expand", "expand", "full", "publish",
]
EXPECTED_GATES = ["gate-merge", "gate-canary-expand", "gate-full-expand"]

MAX_DESCRIPTION_CHARS = 1024
BODY_HARD_CAP_LINES = 500


def _read_skill():
    assert SKILL_MD.exists(), f"missing skill body at {SKILL_MD.relative_to(ROOT)}"
    return SKILL_MD.read_text(encoding="utf-8")


def _frontmatter(text):
    assert text.startswith("---"), "SKILL.md must start with YAML frontmatter"
    parts = text.split("---", 2)
    assert len(parts) >= 3, "malformed frontmatter"
    return yaml.safe_load(parts[1]) or {}


def test_skill_tree_exists():
    assert SKILL_MD.exists(), f"missing {SKILL_MD.relative_to(ROOT)}"
    assert WORKFLOW.exists(), f"missing {WORKFLOW.relative_to(ROOT)}"
    assert REFERENCES.is_dir(), f"missing {REFERENCES.relative_to(ROOT)}/"


def test_skill_frontmatter_name_parity():
    meta = _frontmatter(_read_skill())
    assert meta.get("name") == "factory-deploy"
    assert SKILL_DIR.name == meta.get("name")


def test_skill_description_trigger_and_length():
    meta = _frontmatter(_read_skill())
    desc = meta.get("description") or ""
    assert desc.strip(), "description must be non-empty"
    assert len(desc) <= MAX_DESCRIPTION_CHARS
    assert desc.strip().lower().startswith("use when")


def test_skill_model_invoked():
    meta = _frontmatter(_read_skill())
    assert meta.get("disable-model-invocation") is not True


def test_skill_exactly_two_levels_deep():
    rel = SKILL_MD.relative_to(ROOT / "skills")
    assert len(rel.parts) - 1 == 2, f"must live at skills/<domain>/<skill>/, got {rel}"


def test_skill_body_lean_with_required_sections():
    text = _read_skill()
    assert text.count("\n") < BODY_HARD_CAP_LINES
    low = text.lower()
    for section in ["overview", "core process", "verification", "configuration"]:
        assert section in low, f"missing section: {section}"
    assert ("red flag" in low) or ("rationalization" in low)


def test_workflow_ten_steps_three_named_gates():
    assert WORKFLOW.exists(), f"missing {WORKFLOW.relative_to(ROOT)}"
    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = (wf.get("workflow") or {}).get("steps") or wf.get("steps") or []
    ids = [s.get("id") for s in steps]
    assert ids == EXPECTED_STEPS, f"expected {EXPECTED_STEPS}, got {ids}"
    gates = [s.get("id") for s in steps if s.get("type") == "gate"]
    assert gates == EXPECTED_GATES, f"expected gates {EXPECTED_GATES}, got {gates}"


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
    assert "pdr-128" in low or "non-obvious" in low or "nonobvious" in low


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
