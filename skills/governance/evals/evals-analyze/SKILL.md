---
name: evals-analyze
description: Analyze evaluation results and close the loop. Specification failures create local CDRs to fix agent rules; generalization failures go to evaluator backlog.
disable-model-invocation: true
---

# evals-analyze

## What this skill does

Provides **cross-functional team elevation** and **closed-loop feedback** following **EDD Principle VIII** (Close the Production Loop) by deep-analyzing trajectory failure traces and routing them to correct resolution pathways.

**Output**:
1. **Trajectory Analysis** - Full multi-turn trace analysis with tool calls and context preservation (EDD Principle V)
2. **Failure Routing**:
   - **Specification Failures** (agent logic missing/ambiguous) → Automatically triggers a local call to `levelup-specify` to propose new context rules in `.adlc/drafts/cdr/` to fix agent behavior.
   - **Generalization Failures** (grader flawed or lacks edge-case coverage) → Appends evaluator backlog items to the project backlog for ongoing monitoring.
3. **Cross-Functional PR** - Creates a team-ai-directives PR with insights and rule updates (EDD Principle X)

**Key EDD Principles Applied**:
- **Principle VIII**: Close Production Loop - Spec failures → fix directives; Gen failures → evaluator backlog
- **Principle V**: Trajectory Observability - Full multi-turn traces, not just outputs
- **Principle X**: Cross-Functional Observability - PMs, domain experts, and AI engineers collaborate

## When to use

- **After `/evals-validate`**: Analyze failures and resolve them
- **Closing a development loop**: Translate evaluation failure insights into rule or evaluator fixes
- **Reporting to stakeholders**: Generate readable summaries for PMs and domain experts

## When NOT to use

- **Evals not yet executed**: Run `/evals-validate` first to generate results in `evals/results/`
- **Trivial tasks**: Closed-loop analysis is overhead for simple features

## Process

### User Input
```text
$ARGUMENTS
```
- `--focus AREA` — Focus analysis on specific areas (e.g., security, quality, performance)
- `--dry-run` — Analyze results and print report, but skip PR creation and local skill triggers

### Execution Steps

#### Phase 1: Load Evaluation Results
- Reads results JSON from `evals/results/`.
- Extracts failure cases and full multi-turn conversation traces (including tool calls).

#### Phase 2: Failure Classification
Categorizes each failure trace:
- **Specification Failure**: The agent was correct relative to its context, but the rule/directive was missing, ambiguous, or incorrect.
- **Generalization Failure**: The rule was correct, but the agent made a mistake anyway (hallucinated, missed a constraint, or grader lacked edge-case coverage).

#### Phase 3: Action Routing (Close the Loop)
- **For Specification Failures**: Automatically triggers local skill `/levelup-specify` with the failure trace as input. This creates new rule/persona/example CDRs in `.adlc/drafts/cdr/` to fix the agent's behavior.
- **For Generalization Failures**: Appends an evaluator backlog item to `evals/results/evaluator_backlog.md` detailing the needed grader edge-case updates.

#### Phase 4: Cross-Functional Insights & PR
- Generates a stakeholder-specific report in `evals/results/team_insights.md` (tailored for PMs, domain experts, and AI engineers).
- If git remote and gh CLI are available, commits rule/eval changes in `team-ai-directives` and opens a draft PR (uses `levelup-publish` logic under the hood).

## Verification
- Trajectory failure traces analyzed and classified
- Specification failures successfully routed to `/levelup-specify` (proposes CDRs in `.adlc/drafts/cdr/`)
- Generalization failures written to `evals/results/evaluator_backlog.md`
- Stakeholder report `evals/results/team_insights.md` generated
- Draft PR created in team-ai-directives (if applicable)
- Final report summary presented with PR link and backlog details