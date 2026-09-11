---
name: factory-mission
description: Spec Harness & Execution Engine that runs the inner loop (specify → plan → implement ↔ converge) with optional tracker integration and structural TDD.
---

# factory-mission

## What this skill does

`factory-mission` is the execution-harness orchestrator of the software factory (deck slide 12). It takes a feature description, structures it into a **Mission Brief** (goal, constraints, non-goals, success criteria), generates an ordered **step list**, and executes those steps via sequential subagent runs. 

It implements the following key factory platform capabilities:
1. **Universal Skill Routing**: Decoupled step dispatching. It scans installed skills and hands the inventory to subagents (the model picks which tool fits the step).
2. **Tracker-Agnostic Integration** (`references/tracker-integration.md`, ADR-317): When invoked with `--issue <ref>`, it pulls ticket context, respects automation/dispatch labels (`autonomous`/`supervised`, ADR-318), and writes back status comments + iteration logs.
3. **Inter-Agent Comment Bus** (ADR-330, `references/tracker-integration.md` §Inter-Agent Comment Bus): When tracker-integrated, each step's terminal output (decisions, findings, artifact references — never drafts, PDR-050) is published as a structured comment on the PR/MR/issue. The next step reads previous markers before starting. This is the durable inter-agent memory that survives session boundaries, runtime switches, and pod crashes. Drafts stay on local disk.
4. **Self-Contained Worker Brief** (ADR-331): The Mission Brief is persisted to `.adlc/workflow/brief.md` as a draft. Resumed runs and cross-runtime workers read it from disk — no session-context dependency.
5. **Worktree Isolation** (ADR-332): Each run gets its own git worktree. Never touches the user's main checkout. Cleaned up on exit (retained if unsaved work).
6. **Lease-Based Liveness** (ADR-333): The state file carries a renewable lease with heartbeat + TTL. Resume can distinguish live, stale, and completed runs.
7. **Stall Detection** (ADR-334): After dispatching a subagent, observable progress is checked at a configurable window (default 20 min). A hung agent that passes the circuit breaker is detected and killed.
8. **Lane-Based Dispatch** (ADR-336, `references/lanes.md`): Steps can run on different lanes — `inline` (this session), `agent` (fresh session of same CLI for maker/checker separation), or `cli:<runtime>` (optional cross-vendor). The `agent` lane is the default for unattended stages.
9. **Scratchpad Tools** (PDR-055): Subagents share named, run-private scratchpads (`.adlc/workflow/scratchpads/<name>.txt`) to compile notes, drafts, and reviews incrementally before publishing.
10. **Workflow Memory & Self-Improvement** (PDR-054): Persistent JSONL database (`.adlc/workflow/memory.jsonl`) stores learnings across runs. `factory-learn` periodically runs retrospectives to prune/weight memories.
11. **Hierarchical Context Parameters** (ADR-343): Workflows and agents reference parameters as `{{params.<key>}}`, resolved from most specific to least specific: `agent < workflow < repository < project < default`.
12. **Decoupled Test/Code Separation (PDR-049)**: In `autonomous` or `supervised` modes, it splits `implement` into sequential `test` (Test Agent writes tests under read-only `src/`) and `code` (Implement Agent writes code under read-only `tests/`) runs.

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
   - Discover credentials and MCP/CLI tools (`references/tracker-integration.md`).
   - Pull the issue content as the primary Brief description.
   - Read the labels. If dispatch is `interactive` or gating is `human-required` -> **HALT execution** (hand back to interactive session).
   - The comment bus is active for this run — step outputs will be published as marker comments on the PR/MR/issue.
3. If no issue: read spec description from arguments. The comment bus is inactive — steps communicate through local files only.
4. Structure the Mission Brief (Goal, Constraints, Non-Goals, Success Criteria). The Brief is a `draft` — not published to the comment bus.
5. Resolve hierarchical Context Parameters (ADR-343) from `agent < workflow < repository < project < default` and embed the frozen value map in the brief.
6. Generate the step list based on route classification (`spec`, `change`, `quick`). Each step declares `output_type` (`draft`/`decision`/`findings`/`artifact-ref`) and `reads_from` (markers or local paths) per the executor contract.

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
1. If tracker-integrated: read all marker comments from the PR/MR/issue to compile the audit trail (converge decisions, test findings, implement artifact references, convergence history).
2. Archive state to `.adlc/workflow/runs/<slug>/mission-log.json`.
3. Write per-implement logs to `iterations.md`.
4. If tracker-integrated:
   - Post completion summary as a ticket comment (marker: `factory-mission:status=completed:run=<run_id>`).
   - Transition lifecycle label from `executing` to `validation` (or `done` if merged).
   - Stamp `agent-authored` on opened PRs.
   - Defer PR merge to code-owner approval (never auto-merge without approval).
5. Output the complete audit summary.
