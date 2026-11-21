"""The factory skills must not contradict themselves or overstate a check (SF-FIX-11).

A second review of the eight merged SF-SKILL fixes found sentences on `main`
that give the agent two instructions for one step, define "factory run" in
three ways, or call a check "enforcement" that nothing enforces. An agent
follows text literally, so each of these is a behaviour bug:

- factory-review §2 step 5 said "submit … `create_pull_request_review` (MCP)
  or `gh pr review`" and, two paragraphs on, "post with `post-verdict.sh`":
  doing both posts two verdicts (different `run=`, so nothing de-duplicates);
- it told the agent to "end the run as failed", which a raw agent run cannot do;
- it called the head rule "enforced mechanically" by `check-verdict-head.sh`,
  a script that reads GitHub only and whose CI job is not a required check
  (the eight fix PRs all merged with it red);
- its "factory run" test had a third condition (the arguments alone) that a
  person can type in a local session; factory-intent knew only `ADLC_RUN_ID`;
- factory-mission said "scripts/ is relative to this skill, never another
  skill's" and then named four factory-runbook scripts by a relative path;
- check-proof-of-work exit 2 ("no Definition of Done section") had no
  instruction, and nothing said the command checks a ledger, not the work;
- tracker-integration Operation 5 taught a one-page read for the
  idempotency check.
"""
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
FACTORY = ROOT / "skills/factory"
REVIEW = (FACTORY / "factory-review/SKILL.md").read_text(encoding="utf-8")
MISSION = (FACTORY / "factory-mission/SKILL.md").read_text(encoding="utf-8")
INTENT = (FACTORY / "factory-intent/SKILL.md").read_text(encoding="utf-8")
RUNBOOK = (FACTORY / "factory-runbook/SKILL.md").read_text(encoding="utf-8")
TRACKER = (FACTORY / "factory-runbook/references/tracker-integration.md").read_text(encoding="utf-8")


def between(text, start, end):
    i = text.index(start)
    return text[i:text.index(end, i)]


def review_step5():
    return between(REVIEW, "5. Once all passes are complete", "6. Set the PR label")


# ── factory-review: one way to post ─────────────────────────────────────────

def test_review_step5_has_one_posting_instruction():
    first = review_step5().split("\n", 1)[0]
    assert "and only that" in first and "post-verdict.sh" in first
    # The hand-made submission forms are a fallback, never a second instruction.
    assert "Submit the verdict as a native Review-type COMMENT submission" not in REVIEW
    assert "only for an install without the script" in first
    assert "never in addition to it" in first
    assert "a second verdict" in first


def test_review_does_not_tell_the_agent_to_fail_the_run():
    step5 = review_step5()
    assert "end the run as failed" not in REVIEW
    assert "You cannot fail the run yourself" in step5
    assert "only the lane can turn an unposted verdict into a failed run" in step5
    assert "post-verdict.sh --check-only" in step5


def test_review_does_not_call_an_advisory_check_enforcement():
    assert not re.search(r"enforced mechanically", REVIEW, re.IGNORECASE)
    step8 = between(REVIEW, "8. **Re-review after any fix push", "### 3. Self-Heal")
    assert "**Checked, not enforced:**" in step8
    assert "reads GitHub only" in step8 and "required status check" in step8
    # GitLab has its own check, named where the head rule is explained.
    assert "which reads GitHub only" in review_step5()
    assert "--check-only" in review_step5()


def test_review_sub_headings_inside_a_finding_are_named():
    assert "a heading inside a finding uses `#### `" in review_step5()


# ── one definition of "factory run" ─────────────────────────────────────────

def test_review_factory_run_test_is_not_the_arguments_alone():
    sec = between(REVIEW, "## In a factory run — these rules win", "## When to use")
    assert "factory-runbook/references/run-context.md" in sec and "factory_run=yes" in sec
    assert "do **not** make a factory run" in sec
    assert "started by the review lane. Then:" not in sec


def test_intent_points_to_the_shared_definition():
    head = between(INTENT, "## In a factory run — read this first", "## Worktree Isolation")
    assert "factory_run=yes" in head and "factory-runbook/references/run-context.md" in head
    assert INTENT.count("factory-runbook/references/run-context.md") >= 3
    assert "(`ADLC_RUN_ID` set by the workflow engine) this orchestrator" not in INTENT


# ── factory-mission ─────────────────────────────────────────────────────────

def test_mission_says_where_another_skills_scripts_live():
    scope = between(MISSION, "> **Scope rule**", "## In a factory run")
    assert "**Running** another skill's command is not sourcing it" in scope
    assert "factory-runbook/scripts/bash/<name>.sh" in scope
    assert "/workspace/.agents/skills/factory-runbook/scripts/bash/<name>.sh" in scope


def test_mission_step5_covers_exit_2_and_does_not_overstate_the_check():
    run = between(MISSION, "## In a factory run", "## In a local session")
    step5 = between(run, "5. **Prove the Definition of Done", "6. **Always leave one completion record")
    assert "exit 2 with `the issue has no \\`## Definition of Done\\` section`" in step5
    assert "skip the check and say so in the completion record" in step5
    assert "**accounted for**" in step5 and "it does not check the work itself" in step5
    # The message the skill quotes is the one the command prints.
    for twin in ("bash/check-proof-of-work.sh", "powershell/check-proof-of-work.ps1"):
        script = (FACTORY / "factory-runbook/scripts" / twin).read_text(encoding="utf-8")
        assert "the issue has no `## Definition of Done` section" in script, twin


def test_mission_step6_matches_post_completion():
    run = between(MISSION, "## In a factory run", "## In a local session")
    assert "never posts the same outcome twice for a run" in run
    assert "never posts twice for a run" not in run


def test_runbook_proof_of_work_paragraph_is_honest():
    para = between(RUNBOOK, "**Proof of work:**", "\n---")
    assert "accounted for" in para and "not the work" in para
    assert "no\n`## Definition of Done` section" in para


# ── tracker-integration ─────────────────────────────────────────────────────

def test_operation_5_glab_api_read_is_paginated():
    op5 = between(TRACKER, "### Operation 5", "### Operation 6")
    row = next(l for l in op5.splitlines() if l.startswith("| CLI (glab api) |"))
    assert "--paginate" in row and "Safety Constraint 8" in row
