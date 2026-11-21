"""In a factory run the factory skills' must-do steps beat interactive wording (SF-SKILL-06).

Evidence: octopus-next!1298 — the review followed a project skill's "nothing
posted yet" flow; adlc-argo-wf!84 (run adlc-review-push-adlc-argo-wf-749c8,
2026-11-16) ended with a "verdict preview — not yet posted (needs your
confirm)" that nobody could confirm. tracker-integration Safety Constraint 1
demanded a dry-run + explicit confirmation for every write, factory-review
Safety 3 a local preview before posting, and tracker-integration Constraint 6
and factory-review Safety 7 forbade the label edits that Operation 9 (Set
Lifecycle) and factory-review §2 step 6 require.
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
REVIEW = ROOT / "skills/factory/factory-review/SKILL.md"
MISSION = ROOT / "skills/factory/factory-mission/SKILL.md"
RUNBOOK = ROOT / "skills/factory/factory-runbook/SKILL.md"
TRACKER = ROOT / "skills/factory/factory-runbook/references/tracker-integration.md"
CONTRACT = ROOT / "skills/factory/factory-runbook/references/project-contract.md"


def section(text, start, end):
    i = text.index(start)
    return text[i:text.index(end, i)]


def test_review_has_a_factory_run_section_before_the_process():
    text = REVIEW.read_text(encoding="utf-8")
    sec = text.index("## In a factory run — these rules win")
    assert sec < text.index("## When to use") < text.index("## Process")
    body = section(text, "## In a factory run — these rules win", "## When to use")
    assert "checks and severities only" in body
    assert "Never ask a question" in body
    assert "can never cancel posting the verdict" in body
    # Review lane pods do not always carry ADLC_RUN_ID: the section must
    # recognise them without it.
    assert "WORKFLOW_INPUTS" in body and "/factory-review --pr <ref> --head <sha>" in body
    assert "project-contract.md" in body


def test_dry_run_rules_are_scoped_to_local_sessions():
    tracker = TRACKER.read_text(encoding="utf-8")
    safety = tracker[tracker.index("## Safety Constraints"):]
    c1 = section(safety, "1. **Dry-Run & Explicit Confirm", "2. **Never approves")
    assert "local sessions only" in c1
    assert "Withholding such a write" in c1
    op9 = section(tracker, "### Operation 9", "### Operation 10")
    assert "local sessions only" in op9 and "In a factory run they execute at once" in op9
    review = REVIEW.read_text(encoding="utf-8")
    assert "**Dry-Run Gating (local sessions only)**" in review


def test_dry_run_rules_still_bind_local_sessions():
    # Scoped, not deleted: a person in the chat still gets the preview.
    tracker = TRACKER.read_text(encoding="utf-8")
    c1 = section(tracker, "1. **Dry-Run & Explicit Confirm", "2. **Never approves")
    assert "waits for explicit user confirmation" in c1
    review = REVIEW.read_text(encoding="utf-8")
    s3 = section(review, "3. **Dry-Run Gating", "4. **Only operates")
    assert "previewed before being written" in s3


def test_label_rules_no_longer_contradict_set_lifecycle():
    tracker = TRACKER.read_text(encoding="utf-8")
    c6 = section(tracker, "6. **No ticket body edits**", "7. **Invocation")
    assert "title, labels, milestone" not in c6
    assert "Set Lifecycle" in c6
    review = REVIEW.read_text(encoding="utf-8")
    s7 = section(review, "7. **No ticket body edits**", "8. **Invocation")
    assert "title, labels, milestone" not in s7
    assert "§2 step 6" in s7 and "Set Lifecycle" in s7


def test_mission_states_project_instruction_precedence():
    text = MISSION.read_text(encoding="utf-8")
    run = section(text, "## In a factory run — read this first", "## In a local session")
    assert "**Project instructions in a factory run.**" in run
    assert 'never "pending"' in run
    assert "project-contract.md" in run


def test_project_contract_reference_exists_and_names_every_project_file():
    text = CONTRACT.read_text(encoding="utf-8")
    for f in ("REVIEW.md", "AGENTS.md", ".adlc/issues-provider.yml", ".adlc/workspace.yml",
              ".adlc/workflows/factory/workflow.yml", "Definition of Done"):
        assert f in text, f
    assert "may never cancel a step the" in text
    assert "`project-contract.md`" in RUNBOOK.read_text(encoding="utf-8")


def test_project_contract_names_only_scripts_that_exist():
    # The contract must not send project authors to helpers that are not
    # shipped yet.
    text = CONTRACT.read_text(encoding="utf-8")
    for script in ("open-mr.sh", "check-verdict-head.sh"):
        assert script in text
        assert list((ROOT / "skills").rglob(script)), script
