---
name: mission-implement
description: Use when a plan must become working code under a mechanical test-first contract — a failing suite first, the minimum implementation second, and both closed by gates.
---

# mission-implement

**Requires:** the `factory-mission` skill's shared executor contract at `.agents/skills/factory-mission/references/executor.md` (installed path); install with `adlc-cli skills add tikalk/adlc-team-skills --skill factory-mission`.

## In a local session — you answer the gates

When `ADLC_RUN_ID` is not set, a person is in this session, and nothing else will answer a gate. The agentic-container runtime that relays gates to Slack exists only in a runner pod.

1. **A paused run is your turn, not the end of the mission.** When `adlc-cli workflow run` or `resume` exits with the run paused at a gate (`run_paused`, `status: paused` in `adlc-cli workflow state show <run_id>`), ask the person the gate's question and options. Then run `adlc-cli workflow resume <run_id> --input <verdict_input>=<answer>` and keep going. Never end your turn on a paused run that nobody was asked about.
2. **Every gate that approves MRs is followed by a step that opens them.** A `gate` whose message promises MRs/PRs is followed by a `publish` step: `run-branch.sh` and `open-mr.sh` for each repository the change touches, writing `mr_url` (`mr_urls` for more than one). Only then comes the write-back step, so the completion comment links real MRs. A gate with nothing after it to act on its answer is a plan defect; fix the plan before you start the run.
3. Before ending your turn, the run is `completed`, `failed` or aborted, or it is paused at a gate the person has been asked about.

## What this skill does

`mission-implement` owns the build phase of the mission SDD family: it splits implementation into a `test` step that writes the failing suite and a `code` step that writes the minimum source to satisfy it, each closed by a mechanical gate. It works under the shared executor contract (`.agents/skills/factory-mission/references/executor.md`): the `test` step reads `spec.md` and emits an `artifact-ref`; the `code` step reads that `test` artifact plus `spec.md` and `plan.md`. It stops at a green suite — verification and convergence belong to `mission-verify`, and REVIEW and SHIP belong to `factory-review` and `factory-deploy`.

## Default lane

1. Write the failing suite first, based on `spec.md`, with `tests/` as the only writable surface and source mounted read-only.
2. Run it — the **RED gate** requires that **at least one test fails** before any implementation exists. A suite that passes immediately means the behavior exists or the assertions are empty: stop and route to the owning clarify gate for spec correction. Record the failing count in the run log.
3. Write the minimum code with source as the only writable surface and `tests/`, `spec.md` and `plan.md` mounted read-only.
4. Run the suite — the **GREEN gate** requires the **full suite passes** before converge. A failure loops back to the code step with the failure list attached; the loop is bounded by the mission's code-step retry cap and does not consume the converge circuit breaker.
5. Skip the split only when the run declares no test surface: `tdd: false`, docs/config-only work, or interactive mode. A code-bearing step in autonomous or supervised mode never skips it.

## Speckit lane

This section is a reference translation only; the framework keeps its own loop internals and the step contract below stays authoritative.
- The `test` step maps to the TDD tasks command at `github.com/tikalk/adlc-spec-kit-bundle/extensions/adlc-tdd/commands/tasks.md`, which detects the language and generates hybrid risk-plus-increment tests.
  It reads the `specs/` grammar intake to stage the failing suite; RED discipline is owned here.
  Its shared contract markers are `output_type` `artifact-ref` with `reads_from` `spec.md`.
- The `code` step maps to the spec implementation preset at `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.implement.md`, executed through the RED-GREEN-REFACTOR cycle of `github.com/tikalk/adlc-spec-kit-bundle/extensions/adlc-tdd/commands/implement.md`.
  Its shared contract markers are `output_type` `artifact-ref` with `reads_from` `test` and `spec.md` and `plan.md`.

## Step contract

| Step | phase_type | output_type | reads_from | artifact |
|---|---|---|---|---|
| `test` | build | artifact-ref | `spec.md` | `tests/` |
| `code` | build | artifact-ref | `test`, `spec.md`, `plan.md` | `src/` |

## Gates

Both gates are mechanical and bind the two build steps of this skill.

- **RED gate — after `test`.** The suite is run before any implementation exists, with source mounted read-only. RED passes only when **at least one test fails**, and the failing count is recorded in the run log. A suite that passes immediately means the behavior already exists or the assertions are empty: the gate fails and the run routes to the owning clarify gate for spec correction instead of advancing to `code`.
- **GREEN gate — after `code`.** The suite is run again with `tests/`, `spec.md` and `plan.md` mounted read-only. GREEN passes only when the **full suite passes**. Any failure returns the failure list to the `code` step, bounded by the mission's code-step retry cap, and that loop-back does not consume the converge circuit breaker — only broken iterations do.
- `converge` is never reached with a red suite: GREEN is the last mechanical check before verification, and a red run stops at the gate.
- The split is skipped only when the run declares no test surface: `tdd: false`, docs/config-only work, or interactive mode.

## Boundaries

- No worktree: isolation belongs to the orchestrator; this skill works in the tree it is handed.
- No lease: never acquire, renew or release a run lease.
- No tracker writes: no comments, labels, status transitions, or MR/PR creation.
- No merge or approval: this skill never approves, merges or ships.
- Routes back: a suite that passes before implementation, or a spec or plan that cannot be implemented as written, routes to the owning clarify gate for spec correction; a GREEN failure loops back to `code` with the failure list attached, bounded by the mission's code-step retry cap, and never weakens the tests to pass.
