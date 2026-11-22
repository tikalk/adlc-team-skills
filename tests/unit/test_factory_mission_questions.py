"""factory-mission asks through the question payload (adlc-workspace#151).

Skill-side half of the run-questions contract: the orchestrator (not the
lifecycle skills) asks through ADLC_STEP_QUESTION, publishes the work so
far first (pause publish), and reads ADLC_STEP_ANSWERS on start.

AC1: intent-shaped brief with a real gap writes a payload, asks nothing in prose.
AC3/AC4: no-diff pause opens no MR and says "no MR yet"; push failure writes
no payload and blocks with `blocked: pause publish failed`.
AC5/AC6: answers read-first documented for both phases; the never-ask rules
point at the new payload rule.
"""

from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
MISSION_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
EXECUTOR_MD = ROOT / "skills/factory/factory-runbook/references/executor.md"


def test_mission_documents_question_payload_rule():
    text = MISSION_MD.read_text(encoding="utf-8")
    assert "ADLC_STEP_QUESTION" in text, (
        "factory-mission must document the ADLC_STEP_QUESTION payload rule"
    )
    assert "Never ask a question or wait for an answer" not in text, (
        "the old never-ask rule must be replaced by the payload rule"
    )


def test_mission_reads_answers_first_for_both_phases():
    text = MISSION_MD.read_text(encoding="utf-8")
    assert "ADLC_STEP_ANSWERS" in text
    assert "answer_plan" in text, "plan-phase answers must be documented"
    assert "answer_execute" in text, "execute-phase answers must be documented"


def test_mission_pause_publish_names_wip_commit_and_runbook():
    text = MISSION_MD.read_text(encoding="utf-8")
    assert "wip(" in text, "pause publish must name the WIP commit shape"
    assert "commit-step.sh" in text or "--kind code" in text, (
        "pause publish must go through the factory-runbook helpers"
    )
    assert "no MR yet" in text, "the no-diff pause must say no MR yet"
    assert "blocked: pause publish failed" in text, (
        "a failed publish must block without writing a payload"
    )


def test_shared_executor_routes_questions_through_payload():
    text = EXECUTOR_MD.read_text(encoding="utf-8")
    assert "ADLC_STEP_QUESTION" in text, (
        "the shared executor must align question handling with the payload rule"
    )
