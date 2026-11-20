"""Should-we-build intake checks in factory-queue triage mode.

Before presenting the Intent Gate, triage must evaluate requestor provenance,
measurable success metric + explicit stop condition, and active WIP against a
cap (default 5 executing+validation issues, recommending `deferred: wip-limit`
when at or above cap).
"""

from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILL = (ROOT / "skills/factory/factory-queue/SKILL.md").read_text(encoding="utf-8")


def _triage_before_intent_gate() -> str:
    start = SKILL.index("### 1. Ingestion & Triage Mode")
    gate = SKILL.index("**Intent Gate Presentation**", start)
    return SKILL[start:gate]


def test_triage_checks_requestor_before_intent_gate():
    section = _triage_before_intent_gate()
    assert "Requestor" in section
    assert "`none`" in section


def test_triage_checks_success_metric_and_stop_condition_before_intent_gate():
    section = _triage_before_intent_gate()
    lowered = section.lower()
    assert "success metric" in lowered
    assert "stop condition" in lowered


def test_triage_checks_wip_limit_before_intent_gate():
    section = _triage_before_intent_gate()
    assert "executing" in section and "validation" in section
    assert "5" in section
    assert "deferred: wip-limit" in section
