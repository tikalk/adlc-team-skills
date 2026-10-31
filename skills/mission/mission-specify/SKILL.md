---
name: mission-specify
description: Use when a mission brief must become a measurable spec — restates every success criterion as a binary outcome and resolves what cannot be measured before any plan exists.
---

# mission-specify

**Requires:** the `factory-runbook` skill's shared executor contract at `.agents/skills/factory-runbook/references/executor.md` (installed path); install with `adlc-cli skills add tikalk/adlc-team-skills --skill factory-runbook`.

## In a local session — you answer the gates

When `ADLC_RUN_ID` is not set, a person is in this session, and nothing else will answer a gate. The agentic-container runtime that relays gates to Slack exists only in a runner pod.

1. **A paused run is your turn, not the end of the mission.** When `adlc-cli workflow run` or `resume` exits with the run paused at a gate (`run_paused`, `status: paused` in `adlc-cli workflow state show <run_id>`), ask the person the gate's question and options. Then run `adlc-cli workflow resume <run_id> --input <verdict_input>=<answer>` and keep going. Never end your turn on a paused run that nobody was asked about.
2. **Every gate that approves MRs is followed by a step that opens them.** A `gate` whose message promises MRs/PRs is followed by a `publish` step: `run-branch.sh` and `open-mr.sh` for each repository the change touches, writing `mr_url` (`mr_urls` for more than one). Only then comes the write-back step, so the completion comment links real MRs. A gate with nothing after it to act on its answer is a plan defect; fix the plan before you start the run.
3. Before ending your turn, the run is `completed`, `failed` or aborted, or it is paused at a gate the person has been asked about.

## What this skill does

`mission-specify` owns the specify phase of the mission SDD family: it turns the mission's `brief.md` into a `spec.md` whose acceptance criteria can each be judged yes or no, and it records the decisions taken to get there. It works under the shared executor contract (`.agents/skills/factory-runbook/references/executor.md`): the `specify` step reads `brief.md` and emits a draft, and the `clarify` step reads `spec.md` and emits a decision, with `reads_from` resolved by the orchestrator. It stops at the spec — planning belongs to `mission-plan`, building to `mission-implement`, verification and convergence to `mission-verify`, and REVIEW and SHIP belong to `factory-review` and `factory-deploy`.

## Default lane

1. Read `brief.md`; treat its goal, constraints, non-goals and success criteria as the input, not as wording to preserve.
2. Restate every success criterion as a binary, measurable outcome — each one answers a yes/no question through a command that exits, an artifact that exists, or a diff that shows the change.
3. Write `spec.md`: outcome, constraints, non-goals, acceptance criteria, and out of scope. Each acceptance criterion stays traceable to the success criterion it restates.
4. Surface any criterion that cannot be measured and any constraint that conflicts with another; do not paper over either in prose.
5. Resolve each surfaced item at the clarify phase — ask the person in a gated run, or in autonomous mode record the decision with its basis. The resulting decision is the `clarify` output.
6. Never select technologies and never plan files; those are later phases.

## Step contract

| Step | phase_type | output_type | reads_from | artifact |
|---|---|---|---|---|
| `specify` | generate | draft | `brief.md` | `spec.md` |
| `clarify` | clarify | decision | `spec.md` | — |

## Gates

No gate in this phase.

## Boundaries

- No worktree: isolation belongs to the orchestrator; this skill works in the tree it is handed.
- No lease: never acquire, renew or release a run lease.
- No tracker writes: no comments, labels, status transitions, or MR/PR creation.
- No merge or approval: this skill never approves, merges or ships.
- Routes back: an unmeasurable criterion or a conflicting constraint stays at clarify until resolved; a spec later proven wrong is corrected through the owning clarify phase, never by quietly editing acceptance criteria downstream.
