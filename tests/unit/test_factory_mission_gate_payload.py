"""Supervised Phase 1 (`--plan`) writes the spec gate's payload.

On the first prod run of the one-lane workflow the spec gate showed only its
static question: `plan` committed nothing, so no MR existed, and nothing else
carried the plan to the approver. The engine (adlc-cli) renders an
agent-composed gate payload from `$ADLC_GATE_PAYLOADS/<gate_id>.json`; this
pins the skill side of that contract:

1. In a factory run, `--plan` writes `$ADLC_GATE_PAYLOADS/gate-spec.json`
   whenever `ADLC_UPCOMING_GATES` names `gate-spec`, with or without an MR.
2. The payload carries `summary` (required) plus the plan as `sections` and
   the draft MR, when one was opened, as an `artifacts` entry.
3. The example in the skill is a valid payload for the engine's schema.
4. Only the orchestrator writes it; it never replaces `ADLC_STEP_OUTPUT`.

Carries no record IDs; contracts are prose tokens and headings.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
FACTORY_MD = ROOT / "skills/factory/factory-mission/SKILL.md"


def _text():
    return FACTORY_MD.read_text(encoding="utf-8")


def _payload_block(text):
    start = text.index("**Spec gate payload (`--plan`).**")
    end = text.index("\n\n", text.index("```", text.index("```json", start) + 7))
    return text[start:end]


def test_plan_writes_the_gate_spec_payload():
    block = _payload_block(_text())
    for token in ("ADLC_GATE_PAYLOADS", "ADLC_UPCOMING_GATES", "gate-spec.json", "`gate-spec`"):
        assert token in block, f"--plan payload contract must name {token}"
    assert "with or without an MR" in block, "the payload is written even when no MR was opened"


def test_payload_carries_summary_plan_and_mr():
    block = _payload_block(_text())
    for token in ("`summary`", "`sections`", "`artifacts`", "acceptance criteria", "files"):
        assert token in block, f"payload contract must cover {token}"
    assert "only when an MR/PR was opened or reused" in block


def test_example_matches_the_engine_schema():
    block = _payload_block(_text())
    raw = re.search(r"```json\n(.*?)\n\s*```", block, re.S).group(1)
    payload = json.loads(raw)
    assert isinstance(payload["summary"], str) and payload["summary"].strip()
    for s in payload["sections"]:
        assert set(s) == {"heading", "body"} and all(isinstance(v, str) for v in s.values())
    for a in payload.get("artifacts", []):
        assert set(a) == {"label", "url"} and re.match(r"^https?://\S+$", a["url"])
    assert len(payload["sections"]) <= 8 and len(payload.get("artifacts", [])) <= 8


def test_payload_is_the_orchestrators_and_separate_from_step_output():
    block = _payload_block(_text())
    assert "never instead of" in block and "ADLC_STEP_OUTPUT" in block
    assert "lifecycle skills never write it" in block
