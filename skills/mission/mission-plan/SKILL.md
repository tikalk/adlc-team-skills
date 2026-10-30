---
name: mission-plan
description: Use when a measurable spec must become an ordered implementation plan — every file named with its purpose, every step leaving the tree valid, before any code is written.
---

# mission-plan

**Requires:** the `factory-runbook` skill's shared executor contract at `.agents/skills/factory-runbook/references/executor.md` (installed path); install with `adlc-cli skills add tikalk/adlc-team-skills --skill factory-runbook`.

## In a local session — you answer the gates

When `ADLC_RUN_ID` is not set, a person is in this session, and nothing else will answer a gate. The agentic-container runtime that relays gates to Slack exists only in a runner pod.

1. **A paused run is your turn, not the end of the mission.** When `adlc-cli workflow run` or `resume` exits with the run paused at a gate (`run_paused`, `status: paused` in `adlc-cli workflow state show <run_id>`), ask the person the gate's question and options. Then run `adlc-cli workflow resume <run_id> --input <verdict_input>=<answer>` and keep going. Never end your turn on a paused run that nobody was asked about.
2. **Every gate that approves MRs is followed by a step that opens them.** A `gate` whose message promises MRs/PRs is followed by a `publish` step: `run-branch.sh` and `open-mr.sh` for each repository the change touches, writing `mr_url` (`mr_urls` for more than one). Only then comes the write-back step, so the completion comment links real MRs. A gate with nothing after it to act on its answer is a plan defect; fix the plan before you start the run.
3. Before ending your turn, the run is `completed`, `failed` or aborted, or it is paused at a gate the person has been asked about.

## What this skill does

`mission-plan` owns the plan phase of the mission SDD family: it turns the settled `spec.md` into a `plan.md` that names every file the change touches and orders the work so each step stands on a valid tree. It works under the shared executor contract (`.agents/skills/factory-runbook/references/executor.md`): the `plan` step emits a draft, read from `spec.md` and the clarify decision that closed the spec. It stops at the plan — building belongs to `mission-implement`, verification and convergence to `mission-verify`, and REVIEW and SHIP belong to `factory-review` and `factory-deploy`.

## Default lane

1. Read `spec.md` and the clarify decision; treat the spec's acceptance criteria as the plan's definition of done.
2. List every file to create or modify, each with a one-line purpose.
3. Order the work so each step leaves the tree valid — no step relies on a later step to make it correct or runnable.
4. Name the exact test command that will prove the change, and put the test-first order ahead of the implementation steps.
5. Write `plan.md`: the files table, the test-first order, and the risk notes for anything that could invalidate that order.
6. On `SPEC_CORRECTION_NEEDED`, the verdict routes to the owning clarify gate — the spec's clarify phase — never straight to code; once the spec is corrected, the plan is revised. The plan absorbs the revision; it never owns the route.

## Step contract

| Step | phase_type | output_type | reads_from | artifact |
|---|---|---|---|---|
| `plan` | generate | draft | `spec.md`, `clarify` | `plan.md` |

## Gates

No gate in this phase.

## Boundaries

- No worktree: isolation belongs to the orchestrator; this skill works in the tree it is handed.
- No lease: never acquire, renew or release a run lease.
- No tracker writes: no comments, labels, status transitions, or MR/PR creation.
- No merge or approval: this skill never approves, merges or ships.
- Routes back: an ambiguous or contradictory spec routes to its owning clarify phase; an implementation discovery that invalidates the order revises the plan; a `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate (the spec's clarify phase), and the plan is revised once the spec is corrected — the plan absorbs the revision, it never owns the route.
