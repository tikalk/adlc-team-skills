---
name: factory-mission
description: Spec Harness & Execution Engine that runs the inner loop (specify → plan → implement ↔ converge) with optional tracker integration and structural TDD.
---

# factory-mission

## What this skill does

`factory-mission` is the execution-harness orchestrator of the software factory (deck slide 12). It takes a feature description, structures it into a **Mission Brief** (goal, constraints, non-goals, success criteria), generates an ordered **step list**, and executes those steps via sequential subagent runs. 

It implements the following key factory platform capabilities:
1. **Universal Skill Routing**: Decoupled step dispatching. It scans installed skills and hands the inventory to subagents (the model picks which tool fits the step).
2. **Tracker-Agnostic Integration** (`references/tracker-integration.md`): When invoked with `--issue <ref>`, it pulls ticket context, respects automation/dispatch labels (`autonomous`/`supervised`), and writes back status comments + iteration logs.
3. **Decoupled Test/Code Separation (PDR-049)**: In `autonomous` or `supervised` modes, it splits `implement` into sequential `test` (Test Agent writes tests under read-only `src/`) and `code` (Implement Agent writes code under read-only `tests/`) runs.

---

## When to use

- "Build this feature end to end" inside a factory-enabled team.
- You want an execution loop with a circuit breaker, score-regression checking, and a robust resume mechanism (`factory-mission --resume`).
- You want to run autonomously against a ticket queue.

**When NOT to use**:
- For non-factory standalone projects (use generic `mission-brief` instead).
- Trivial 1-line changes (do them directly).

---

## Process

`factory-mission` executes in alignment with the shared executor contract (`references/executor.md`) and the tracker-agnostic layer (`references/tracker-integration.md`).

### Phase 0 to 4: Setup & Compilation
1. Read `.adlc/workflow/workflow-config.yml`. Resolve execution and supervision.
2. If `--issue <ref>` is specified:
   - Discover credentials and MCP tracker tools (`references/tracker-integration.md`).
   - Pull the issue content as the primary Brief description.
   - Read the labels. If dispatch is `interactive` or gating is `human-required` -> **HALT execution** (hand back to interactive session).
3. If no issue: read spec description from arguments.
4. Structure the Mission Brief (Goal, Constraints, Non-Goals, Success Criteria).
5. Generate the step list based on route classification (`spec`, `change`, `quick`).

### Phase 5: Executing the Converge Loop
Execute steps sequentially. When reaching `implement` / `converge`:

#### Decoupled Test/Code Execution (PDR-049)
In `autonomous` and `supervised` modes, the `implement` step is split into two sequential subagent dispatches:
1. **The Test Agent (`test` step)**:
   - Instruction: Write a failing test suite based on `spec.md` in `tests/`.
   - Enforcement: Mount `src/` as hard **read-only**; only `tests/` is writeable.
2. **The Implement Agent (`code` step)**:
   - Instruction: Write minimum implementation code in `src/` to pass the tests.
   - Enforcement: Mount `tests/`, `spec.md`, and `plan.md` as hard **read-only**; only `src/` is writeable.

*Note: Skip the split in `interactive` mode or if no TDD capability is configured.*

#### Converge Loop (Implement ↔ Converge)
1. Execute implement step (or `test` + `code` steps).
2. Execute `converge` step (independent judge mode; checks against Brief and Non-Goals).
3. If `converge` returns:
   - `DONE` (and quality is above `quality_threshold`): Loop exits.
   - `CONTINUE`: Increment `consecutive_tasks_appended`. Check circuit breaker (default 3) and score-regression counter. Repeat.
   - `SPEC_CORRECTION_NEEDED`: Stop and route to Phase 6.

### Phase 6: Completion & Write-Back
1. Archive state to `.adlc/workflow/runs/<slug>/mission-log.json`.
2. Write per-implement logs to `iterations.md`.
3. If tracker-integrated:
   - Post completion summary and iteration metrics as a ticket comment.
   - Transition lifecycle label from `executing` to `validation` (or `done` if merged).
   - Stamp `agent-authored` on opened PRs.
   - Defer PR merge to code-owner approval (never auto-merge without approval).
4. Output the complete audit summary.
