"""factory-queue never stamps gating/dispatch labels at creation (adlc-workspace#100–#103).

Plan mode created four `intent` issues with `supervised` already on them.
A dispatch label on a newly opened issue is a lane trigger, so all four
started missions before anyone ran the Intent Gate. The skill must create
plan-mode issues at `intent` (plus grouping labels) and stamp gating and
dispatch labels only on approval.

Criterion class B (skill prose). Positive witness: the shipped SKILL.md.
Breakage witness: the pre-fix "Push to Q" wording, which the check rejects.
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-queue/SKILL.md"

PRE_FIX_PUSH = (
    "6. **Push to Q**: Push epics and milestone issues to the tracker via MCP. "
    "Stamp appropriate automation-gating and dispatch labels on each generated "
    "issue based on AI triage."
)


def push_step(text):
    m = re.search(r"^\d+\. \*\*Push to Q\*\*:.*$", text, re.M)
    assert m, "plan mode has a Push to Q step"
    return m.group(0)


def creation_is_label_safe(step):
    """True when the step creates at `intent` and forbids gating/dispatch labels."""
    return ("`intent`" in step
            and re.search(r"never stamp automation-gating or dispatch labels", step, re.I) is not None)


def test_plan_mode_creates_issues_at_intent_without_dispatch_labels():
    assert creation_is_label_safe(push_step(SKILL.read_text()))


def test_pre_fix_wording_is_rejected():
    assert not creation_is_label_safe(push_step(PRE_FIX_PUSH))


def test_invariant_dispatch_labels_only_on_approval():
    text = SKILL.read_text()
    invariants = text[text.index("## Invariants & Safety Constraints"):]
    assert "Dispatch Labels Only on Approval" in invariants
