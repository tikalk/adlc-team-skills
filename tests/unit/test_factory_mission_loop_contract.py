"""factory-mission converge-loop control contract.

The loop CONTROL (counters, thresholds, stop conditions) is harness-owned
and lives in factory-mission; the VERDICTS stay in mission-brief's DAG.
Restored from the pre-rewrite Phase 5 + the pre-removal mission-brief
safety mechanisms, adapted to the shared run state
(`runs/<run_id>/state.json`, policy in `mission.yml`).

Carries no record IDs; contracts are prose tokens and headings.
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
FACTORY_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
MISSION_TEMPLATE = ROOT / "skills/factory/factory-runbook/mission-template.yml"


def section_body(text: str, heading: str) -> str:
    pattern = rf"(?ms)^{re.escape(heading)}\s*$(.*?)(?=^## |^### |\Z)"
    match = re.search(pattern, text)
    assert match, f"missing required section: {heading}"
    return match.group(1)


def test_factory_mission_owns_loop_control():
    text = FACTORY_MD.read_text()
    body = section_body(text, "### Phase 5: Converge Loop Control")
    for token in (
        "consecutive_tasks_appended",
        "consecutive_score_regressions",
        "circuit_breaker",
        "max_spec_corrections",
        "quality_threshold",
    ):
        assert token in body, f"loop-control token missing: {token}"
    assert "default 3" in body
    assert "treated as `CONTINUE`" in body
    assert "mission-brief" in body  # verdict ownership stated, not duplicated


def test_canonical_spec_correction_sentence_intact():
    """The fold suite's canonical routing sentence must survive the Phase 5
    insertion untouched."""
    text = FACTORY_MD.read_text()
    assert (
        "A `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate "
        "(`mission-brief` clarify), never to code." in text
    )


def test_loop_policy_defaults_exist_in_template():
    template = MISSION_TEMPLATE.read_text()
    assert "circuit_breaker: 3" in template
    assert "max_spec_corrections: 2" in template


def test_phase_numbering_is_continuous():
    """Phase headings run 0-4, 5, 6 with no gaps; steps inside the setup
    section are uniquely numbered (a duplicate '6.' once lived here)."""
    text = FACTORY_MD.read_text()
    headings = re.findall(r"(?m)^### Phase (\d+)", text)
    nums = [int(n) for n in headings]
    assert nums == sorted(nums), f"phase headings out of order: {nums}"
    assert 5 in nums and 6 in nums, f"missing Phase 5/6: {nums}"
    setup = section_body(text, "### Phase 0 to 4: Setup & Compilation")
    step_nums = [int(n) for n in re.findall(r"(?m)^(\d+)\.\s", setup)]
    assert step_nums == sorted(set(step_nums)), (
        f"duplicate step numbers in setup section: {step_nums}"
    )
