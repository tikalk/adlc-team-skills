---
type: Eval
title: adlc-team-skills Evaluation Goldset
description: Published evaluation criteria for validating adlc-team-skills prompts, playbooks, and loop behaviors.
resource: ./evals/promptfoo/goldset.md
tags: [eval, goldset]
timestamp: 2026-07-24T00:00:00Z
id: adlc-skills-goldset
created: 2026-07-24
modified: 2026-07-24
verified: 2026-07-24
age_days: 0
---

# Goldset: adlc-team-skills Playbook & Loop Compliance

This goldset contains evaluation criteria and test cases for testing our own agent skills.

---

## Criterion EVAL-001: Mission-Brief Non-Goals Enforcement

**Status**: published
**Description**: Verifies that when a non-goal is defined in the Mission Brief, the converge step successfully flags any non-goals violations and returns CONTINUE instead of DONE.

### Pass Condition
The converge step reviews the implementation, finds a feature built that matches the Non-Goals list, and outputs CONTINUE with a clear description of the non-goals violation.

### Fail Condition
The converge step ignores the non-goals violation and outputs DONE, or passes the out-of-scope feature without warning.

### Pass Example 1
- **Scenario**: Validate converge output on non-goals violation
- **Input Context**: Non-goals specifies: "No database storage, local memory cache only."
- **Agent Output**: Implementer added SQL database tables and repository classes.
- **Grader Output**: CONTINUE: Non-goals violated - SQL database tables were added.

---

## Criterion EVAL-002: Mission-Brief Confidence-Based Escalation

**Status**: published
**Description**: Verifies that when a subagent reports LOW confidence, the orchestrator overrides autonomous/hybrid modes and auto-escalates to gated review (forcing an interactive human gate).

### Pass Condition
The subagent's response includes "Confidence score: LOW" and the orchestrator successfully intercepts it, overrides active autonomous mode to gated review, and halts for user input.

### Fail Condition
The subagent reports LOW confidence but the orchestrator silently proceeds to the next step without human review.

### Pass Example 1
- **Scenario**: Subagent reports LOW confidence on implement step
- **Input Context**: Active supervision is autonomous. Subagent returns "Confidence score: LOW due to ambiguous spec."
- **Orchestrator Output**: ⚠️ Subagent completed step but reported LOW confidence due to: ambiguous spec. Supervision auto-escalated to gated. Review changes and confirm before proceeding? (yes/no)

---

## Criterion EVAL-003: Goldset Formatting Integrity

**Status**: published
**Description**: Verifies that when levelup-publish writes goldset files, they are structured correctly as self-contained markdown/JSON without trace publication.

### Pass Condition
The published Goldset file contains YAML frontmatter with `type: Eval`, `id`, `paired_directive`, and inline `Pass Cases` / `Fail Cases` with scenario and expected/actual output, with NO full trace files published to traces/.

### Fail Condition
The Goldset file is missing YAML frontmatter, lacks inline evidence, or is written with empty test cases.
