"""factory-mission asks through the question payload, never in prose.

In a factory run nobody reads a prose question: the run pauses only when the
step leaves `$ADLC_STEP_QUESTION`, and the engine relays it to the Slack run
thread. This pins the skill side of that contract:

1. The old "never ask" rule is gone; step 8 asks through the payload.
2. On every start, both phases read `ADLC_STEP_ANSWERS` first.
3. Before asking, the work so far is published (a `wip(<run_id>)` commit,
   the runbook publish procedure with `--kind code`); no diff means no MR and
   "no MR yet"; a failed publish writes no payload and blocks.
4. The example in the skill is a valid payload for the engine's schema
   (`summary`, 1-3 questions with string `id` and `text`, optional `mr_url`).
5. Only the orchestrator writes it; the shared executor says the same.

Carries no record IDs; contracts are prose tokens and headings.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
MISSION_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
EXECUTOR_MD = ROOT / "skills/factory/factory-runbook/references/executor.md"

RULE_HEAD = "8. **Never ask in prose."


def _text():
    return MISSION_MD.read_text(encoding="utf-8")


def _rule8(text):
    start = text.index(RULE_HEAD)
    end = text.index("\n\n**Project instructions in a factory run.**", start)
    return text[start:end]


def test_old_never_ask_rule_is_replaced():
    text = _text()
    assert "Never ask a question or wait for an answer" not in text
    assert "unattended runs never ask a question." not in text
    assert RULE_HEAD in text


def test_answers_are_read_first_in_both_phases():
    rule = _rule8(_text())
    for token in ("ADLC_STEP_ANSWERS", "answer_plan", "answer_execute", "--plan", "execute"):
        assert token in rule, f"step 8 must name {token}"
    assert "never ask again" in rule


def test_work_is_published_before_asking():
    rule = _rule8(_text())
    assert "wip(<run_id>): paused at <step> for a question" in rule
    assert "factory-runbook` publish procedure" in rule and "--kind code" in rule
    assert "no MR yet" in rule, "a pause with no diff must say no MR yet"
    assert "blocked: pause publish failed (<reason>)" in rule
    assert "write no payload" in rule, "a failed publish must not ask"
    assert "stays `executing`" in rule


def test_example_payload_matches_the_engine_schema():
    rule = _rule8(_text())
    m = re.search(r"```json\n(.*?)\n\s*```", rule, re.S)
    assert m, "step 8 must carry a JSON example"
    data = json.loads(m.group(1))
    assert isinstance(data.get("summary"), str) and data["summary"].strip()
    qs = data.get("questions")
    assert isinstance(qs, list) and 1 <= len(qs) <= 3
    for q in qs:
        assert isinstance(q.get("id"), str) and q["id"]
        assert isinstance(q.get("text"), str) and q["text"]
    assert re.match(r"^https?://[^\s<>|]{1,2040}$", data.get("mr_url", "https://x"), re.I)
    assert "An invalid file does not pause the run" in rule


def test_only_the_orchestrator_writes_the_payload():
    rule = _rule8(_text())
    assert "Only this orchestrator writes the payload." in rule
    assert "Lifecycle skills" in rule and "never write it" in rule


def test_raw_lane_without_payload_path_blocks():
    assert "blocked: needs an answer: <question>" in _rule8(_text())


def test_supervision_override_points_at_the_payload():
    text = _text()
    assert "unattended runs never ask in prose" in text
    assert "pause through the question payload" in text


def test_shared_executor_routes_questions_through_the_payload():
    text = EXECUTOR_MD.read_text(encoding="utf-8")
    assert "Relay the question and pause." not in text
    assert "questions are relayed to the human and the run pauses." not in text
    assert text.count("ADLC_STEP_QUESTION") >= 2
    assert "ADLC_STEP_ANSWERS" in text
