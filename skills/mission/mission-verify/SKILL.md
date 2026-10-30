---
name: mission-verify
description: Use when implemented work must be judged against its brief — severity-ranked findings plus one converge verdict of DONE, CONTINUE or SPEC_CORRECTION_NEEDED.
---

# mission-verify

**Requires:** the `factory-mission` skill's shared executor contract at `.agents/skills/factory-mission/references/executor.md` (installed path); install with `adlc-cli skills add tikalk/adlc-team-skills --skill factory-mission`.

## In a local session — you answer the gates

When `ADLC_RUN_ID` is not set, a person is in this session, and nothing else will answer a gate. The agentic-container runtime that relays gates to Slack exists only in a runner pod.

1. **A paused run is your turn, not the end of the mission.** When `adlc-cli workflow run` or `resume` exits with the run paused at a gate (`run_paused`, `status: paused` in `adlc-cli workflow state show <run_id>`), ask the person the gate's question and options. Then run `adlc-cli workflow resume <run_id> --input <verdict_input>=<answer>` and keep going. Never end your turn on a paused run that nobody was asked about.
2. **Every gate that approves MRs is followed by a step that opens them.** A `gate` whose message promises MRs/PRs is followed by a `publish` step: `run-branch.sh` and `open-mr.sh` for each repository the change touches, writing `mr_url` (`mr_urls` for more than one). Only then comes the write-back step, so the completion comment links real MRs. A gate with nothing after it to act on its answer is a plan defect; fix the plan before you start the run.
3. Before ending your turn, the run is `completed`, `failed` or aborted, or it is paused at a gate the person has been asked about.

## What this skill does

`mission-verify` owns the verify phase of the mission SDD family: it judges the built work against the brief rather than the implementer's claims, emits severity-ranked findings, and returns one converge verdict. It works under the shared executor contract (`.agents/skills/factory-mission/references/executor.md`): the `verify` step reads the `test` and `code` artifacts and emits `findings`, and the `converge` step reads `brief.md` and emits a `decision` — the judge is independent, so it checks the brief and non-goals rather than the verifier's own findings. It stops at the verdict — REVIEW and SHIP belong to `factory-review` and `factory-deploy`, which this skill never pre-empts.

## Default lane

1. Read the artifact refs produced by the `test` and `code` steps.
2. Judge against `brief.md`, not the implementer's claims — re-run the suite, inspect the diff, and confirm the non-goals are untouched. The converge judge works from the brief and non-goals, never from the verifier's own findings.
3. Emit severity-ranked findings as Critical, Important or Minor, each tied to evidence in the diff, the suite output or an untouched non-goal.
4. Return one converge verdict: `DONE` when the criteria are met and the quality threshold is reached, `CONTINUE` when in-scope gaps remain, `SPEC_CORRECTION_NEEDED` when a criterion is unmeasurable or the scope conflicts.
5. Route `SPEC_CORRECTION_NEEDED` to the owning clarify gate, never to code; return `CONTINUE` to the implementation phase with the findings attached.
6. Never approve or merge; approval and merge stay with the human and the deploy phase.

## Step contract

| Step | phase_type | output_type | reads_from | artifact |
|---|---|---|---|---|
| `verify` | verify | findings | `test`, `code` | — |
| `converge` | verify | decision | `brief.md` | — |

## Gates

This phase's gate is the **converge verdict** — a decision gate, not a mechanical red/green gate (the mechanical gates bind the build steps in `mission-implement`).

- **`DONE`** — the acceptance criteria are met and the quality threshold is reached.
- **`CONTINUE`** — in-scope gaps remain; the findings return to implementation and the circuit breaker applies.
- **`SPEC_CORRECTION_NEEDED`** — a criterion is unmeasurable or the scope conflicts; the verdict routes to the owning clarify gate, never to code.

## Boundaries

- No worktree: isolation belongs to the orchestrator; this skill works in the tree it is handed.
- No lease: never acquire, renew or release a run lease.
- No tracker writes: no comments, labels, status transitions, or MR/PR creation.
- No merge or approval: this skill never approves, merges or ships.
- Routes back: findings route to the phase that owns the gap; `CONTINUE` returns to implementation; `SPEC_CORRECTION_NEEDED` routes to the owning clarify gate, never to code.
