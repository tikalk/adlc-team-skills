"""Atomic lifecycle transitions contract (adlc-workspace#81, G2).

Every factory actor moves an issue's lifecycle label through one shared
"Set Lifecycle" step in tracker-integration Operation 9:

- one call adds the target state and removes *any* other lifecycle label,
  not only the expected previous one
- the step re-reads the labels and reports a coexisting pair instead of
  passing silently
- the `resume` trigger label is never touched by the step
- every actor skill that moves a lifecycle label names the step
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

FACTORY_DIR = ROOT / "skills/factory"
TRACKER_INTEGRATION = FACTORY_DIR / "factory-runbook/references/tracker-integration.md"

ACTORS = {
    "factory-queue": FACTORY_DIR / "factory-queue/SKILL.md",
    "factory-mission": FACTORY_DIR / "factory-mission/SKILL.md",
    "factory-review": FACTORY_DIR / "factory-review/SKILL.md",
    "factory-orchestrator": FACTORY_DIR / "factory-orchestrator/SKILL.md",
}

STEP = "Set Lifecycle"


def _op9():
    text = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    start = text.index("### Operation 9")
    end = text.index("### Operation 10", start)
    return text[start:end]


def _set_lifecycle():
    op9 = _op9()
    assert f"**{STEP}**" in op9, f"Operation 9 must define the shared **{STEP}** step"
    start = op9.index(f"**{STEP}**")
    return op9[start:]


def test_step_removes_any_other_lifecycle_label():
    step = _set_lifecycle().lower()
    assert "any other lifecycle label" in step, (
        "the step must remove any other lifecycle label, not only the expected previous one"
    )
    assert "same call" in step, "add and remove must happen in the same call"


def test_step_ships_issue_commands_that_add_and_remove_in_one_call():
    step = _set_lifecycle()
    assert 'glab issue update <iid> --label "<target>" --unlabel "<others>"' in step
    assert 'gh issue edit <number> --add-label "<target>" --remove-label "<others>"' in step


def test_op9_no_longer_moves_lifecycle_labels_on_merge_requests():
    op9 = _op9()
    assert "gh pr edit --add-label" not in op9, "lifecycle labels live on issues, not PRs"
    assert "glab mr update --label" not in op9, "lifecycle labels live on issues, not MRs"


def test_step_verifies_exactly_one_lifecycle_label():
    step = _set_lifecycle().lower()
    assert "re-read" in step and "exactly one lifecycle label" in step, (
        "the step must re-read the labels and verify exactly one lifecycle label"
    )


def test_step_leaves_the_resume_trigger_alone():
    step = _set_lifecycle()
    assert "`resume`" in step and "never" in step.lower(), (
        "the step must say it never adds or removes the `resume` trigger"
    )


def test_step_resolves_names_through_the_mapping():
    step = _set_lifecycle().lower()
    assert "labels:" in step and "mapping" in step


def test_every_actor_calls_the_shared_step():
    for name, path in ACTORS.items():
        text = path.read_text(encoding="utf-8")
        assert STEP in text, f"{name} must move lifecycle labels through the {STEP} step"


def test_lease_acquire_and_dependency_revert_use_the_step():
    text = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    acquire = next(line for line in text.splitlines() if "**ACQUIRE**" in line)
    assert STEP in acquire, "lease ACQUIRE must move the label to `executing` through the step"
    mission = ACTORS["factory-mission"].read_text(encoding="utf-8")
    gate = next(line for line in mission.splitlines() if "Dependency hard gate" in line)
    assert STEP in gate, "the dependency-gate revert to `spec-gated` must use the step"
