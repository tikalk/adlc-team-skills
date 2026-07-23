---
name: mission-brief
description: >-
  Mission-driven SDD orchestrator: take a feature description, structure it
  into a Mission Brief (goal, constraints, success criteria), generate an
  ordered step list with prompts that trigger installed SDD skills via model
  invocation or command-file discovery, and walk those steps to converged
  implementation. Use when you want an end-to-end
  specify → plan → implement ↔ converge loop with gates, a circuit breaker,
  resume, and an audit trail — without YAML files or per-framework profiles.
---

# mission-brief

## What this skill does

`mission-brief` takes a feature description, structures it into a **Mission
Brief** (goal, constraints, success criteria), generates an ordered **step
list** with prompts, and executes those steps — each step dispatched to a
subagent whose prompt triggers the installed SDD skills. No YAML workflow
files, no per-framework profiles, no profile detection. The step prompts use
canonical SDD terminology (specify, plan, implement, converge) that works with
**any** SDD skill set — model-invoked skills auto-trigger, command-based
frameworks match by filename, and if neither exists the subagent executes
directly.

## When to use

- "Build this feature end to end": you give a description, mission-brief
  composes the pipeline and runs specify → plan → implement ↔ converge.
- You want a converge loop with a circuit breaker and an audit trail.
- You want to resume an interrupted mission across sessions
  (`mission-brief --resume`).
- You want to run unattended across sessions (`mission-brief --async`).

## When NOT to use

- A single small edit — just do it; a mission is overhead.
- You already have a spec and tasks and only want to implement one task —
  invoke the implement skill directly.

## Mission Brief template

Before generating steps, the description is structured into:

```markdown
## Mission Brief

**Goal**: <what to build — one sentence>
**Constraints**: <tech stack, limitations, dependencies, requirements>
**Success Criteria**:
- <measurable outcome 1>
- <measurable outcome 2>
- <measurable outcome 3>
```

The brief serves two purposes:
1. **Forces explicit done-criteria upfront** — feeds the converge step's
   independence check (the checker verifies against these criteria).
2. **Carries mission context** into every step's delegation prompt so each
   subagent has full context without re-reading prior steps.

## Inputs

```text
$ARGUMENTS
```

The text in the `$ARGUMENTS` block above **IS** your mission description —
proceed with it immediately. Do not ask the user what they want to build.

Parse flags from the arguments first, then treat the remaining text as
`spec_description`:

- `--async` / `--sync` — execution mode flag (overrides config default).
- `--resume` — explicit resume from state.
- Everything else — the mission description (`spec_description`).

If no description and not `--resume`: derive a best-effort description from the
feature name (git branch, or the last state's feature). If `--resume` and no
state: report "No interrupted mission found" and stop.

**Feature name derivation**: slugify the description to lowercase-hyphenated,
drop stop words (a, an, the, new, to, with, for, add, fix, update). Example:
"add a new react dashboard with telemetry" → `react-dashboard-telemetry`.
If `.adlc/workflow/runs/` already contains a dir with that name, append `-2`,
`-3`, etc.

## Flow

> **All paths are relative to the current working directory** (the project
> root where the agent operates). Do not look in subdirectories for config or
> state unless explicitly stated.

### Phase 0 — Configuration

1. `mkdir -p .adlc/workflow` (and `.adlc/workflow/tmp`, `.adlc/workflow/runs`).
2. If `.adlc/workflow/workflow-config.yml` does not exist, copy it from the
   skill's `config-template.yml` (located alongside this SKILL.md).
3. Read `.adlc/workflow/workflow-config.yml`. Defaults if fields are absent:

```yaml
workflow:
  execution: sync            # sync | async
  supervision: gated         # gated | hybrid | autonomous
  max_iterations: 5
  max_spec_corrections: 2
  circuit_breaker: 3
  spec_correction_signal: null
  # models: { strong: "...", fast: "..." }   # optional
```

Resolve the effective execution mode: `--async`/`--sync` flag > config
`execution` > `sync`. If `--async` and `supervision` is `gated`/`hybrid`: warn
("async forces ungated; running autonomous") and treat as `autonomous` for
this run.

### Phase 1 — Resume check (`--resume` only)

> `<FEATURE_DIR>` = `.adlc/workflow/runs/<feature>/` (defined in Phase 4, but
> referenced here for the completed-mission check).

If `--resume` was passed:

1. Read `.adlc/workflow/.mission-state.json`.
2. If `<FEATURE_DIR>/mission-log.json` exists → report "Mission already
   completed for feature X. Audit trail: …" → stop.
3. If state exists with non-empty `completed_steps` → resume: load the step
   list from `state.steps`, skip to Phase 5 (Execute) at the first incomplete
   step.
4. If no state → report "No interrupted mission found. Run
   `mission-brief \"<desc>\"` to start one." → stop.

If `--resume` was NOT passed and a state file with non-empty `completed_steps`
exists: **ask** — "An interrupted mission for feature X exists (N/M steps
done). Run `mission-brief --resume` to continue, or confirm to start fresh
(this discards the state)." Do not silently clobber.

### Phase 2 — Mission Brief

Structure `spec_description` into the Mission Brief template:

1. **Goal**: extract the core objective in one sentence.
2. **Constraints**: infer tech stack, limitations, and requirements from the
   description and the project context (check `package.json`, `go.mod`,
   language files, existing specs). If unclear, leave a placeholder and mark
   it for the user to fill.
3. **Success Criteria**: derive 2-5 measurable outcomes. If the description is
   vague, generate reasonable defaults based on the feature type and mark them
   as "suggested — edit if needed".

**Present the brief** to the user:
- sync + gated/hybrid → show the brief and ask for confirmation or edits
  before proceeding.
- sync + autonomous → if Success Criteria are "TBD" or empty, **STOP**: 
  "Autonomous mode requires checkable done-criteria." Otherwise proceed
  without confirmation.
- `--async` → proceed without confirmation (autonomous, ungated).

Store the brief in `.mission-state.json.brief`.

### Phase 3 — Route classification & optional phases

Classify into `spec` / `change` / `quick`:

| Route | When | Steps |
|---|---|---|
| `spec` | New feature, greenfield, "add/create/build" | brainstorm? → specify → clarify? → plan → tasks → analyze? → implement↺converge → trace? |
| `change` | Modification, brownfield, "fix/update/refactor" | specify → implement↺converge |
| `quick` | Small task, trivial, "just/quick/simple" | implement only (full brief as input) |

For `spec` route only, assess optional-phase **candidates** (hands-off,
recorded in state; the user approves each at a runtime gate if supervision is
gated/hybrid):

| Phase | Candidate when |
|---|---|
| `brainstorm` | prompt is architectural/ambiguous ("design", "approach", "compare", "how should we", multiple viable solutions) |
| `clarify` | success criteria are vague / constraints missing |
| `analyze` | route is `spec` (symmetric) |
| `trace` | prompt mentions persistence, audit, traceability, compliance |

### Phase 4 — Command discovery & generate step list

#### 4a. Command/skills discovery

Read `references/agent-integrations.md` (alongside this SKILL.md). For each
agent directory listed in the table, check if it exists in the project root.
Record discovered directories in state:

```json
"discovered": {
  "skills_dirs": [".claude/skills"],
  "commands_dirs": [{"dir": ".opencode/commands", "ext": ".md"}]
}
```

This discovery is done once at generation time and reused on `--resume`. See
the reference file for the full algorithm.

#### 4b. Generate the step list

Generate an ordered list of steps based on the route and optional-phase
candidates. Each step is a structured object stored in `state.steps`:

```json
{
  "id": "specify",
  "phase": "specify",
  "tier": "strong",
  "prompt": "Write a feature specification for the goal below. ...",
  "status": "pending"
}
```

The step list is the **reviewable artifact** — present it to the user in
gated/hybrid mode before execution:

```
## Mission Steps

1. [specify]  (strong) Write a feature specification for: react dashboard with telemetry
2. [plan]     (strong) Break down the specification into an implementation plan
3. [tasks]    (fast)   Generate the detailed task list from the plan
4. [implement](strong) Implement the next pending task from the plan
5. [converge] (fast)   Review the implementation against the spec and success criteria
   ↺ loop 4–5 until converged (max 5 iterations, circuit breaker 3)
```

For `quick` route: single `implement` step with the full brief as input.

For `change` route: `specify` + `implement↺converge` loop (no optional phases).

For `spec` route: full pipeline with optional phases inserted as gated
candidates.

#### Step prompt construction

Each step's `prompt` is built from three parts:

**1. Phase instruction** — canonical SDD terminology per phase:

| Phase | Tier | Instruction |
|---|---|---|
| brainstorm | strong | "Explore approaches and tradeoffs for the goal below. Consider multiple viable solutions and present a recommended design." |
| specify | strong | "Write a feature specification for the goal below. Include requirements, constraints, and measurable success criteria." |
| clarify | fast | "Review the specification and interview the team to resolve any vague success criteria or missing constraints." |
| plan | strong | "Break down the specification into an implementation plan with ordered, verifiable tasks." |
| tasks | fast | "Generate the detailed task list from the plan — each task must have exact file paths and verification steps." |
| analyze | fast | "Adversarially review the plan before implementation. Challenge every non-trivial decision." |
| implement | strong | "Implement the next pending task from the plan. Follow test-driven practices." |
| converge | fast | "Review the implementation against the specification and success criteria. Verify independently — you are the checker, not the maker." |
| trace | fast | "Document the decisions made during this feature as ADRs or a handoff document." |

**2. Mission Brief context** — the goal, constraints, and success criteria
from Phase 2 are appended to every prompt.

**3. Delegation wrapper** — added by the executor at dispatch time (Phase 5).

### Phase 5 — Execute the step list

Create a `todowrite` list mirroring `state.steps`. Mark steps in
`completed_steps` as completed. Update after every step.

#### Step dispatch

For each step with `status: pending`:

1. Emit:
   ```markdown
   ## Workflow Step: <id>

   **Phase**: <phase> (<tier>)
   ```
2. If the step is a **converge** step (phase is `converge`), prepend the
   independence hint to the delegation prompt:
   > You are grading work that another agent produced. Do NOT assume the
   > implementation is correct — verify against the spec independently. Try
   > to make each requirement fail at the primary source (run the test, check
   > the file, grep for the reference). You are the checker, not the maker.
3. Delegate to a subagent with this prompt **verbatim**:

   ```markdown
   You are being invoked by the `mission-brief` executor.

   ## Task

   <step.prompt>

   ## Mission Brief

   **Goal**: <goal>
   **Constraints**: <constraints>
   **Success Criteria**: <success criteria>

   ## How to execute

   Try these in order:

   1. **Skill match**: If an installed skill's description matches this task,
      invoke it (via skill tool or by reading its SKILL.md inline).

   2. **Command match**: If a command file for this phase exists, read and
      execute it. <DISCOVERED_PATHS>
      Look for a file whose name matches the phase (e.g., `*specify*`,
      `*implement*`, `*converge*`).

   3. **Direct execution**: If neither exists, execute the task directly using
      your available tools.

   If you found a skill or command, note its name in your summary.

   Do NOT follow handoffs to other skills or commands — return your results to
   the executor when you finish.

   Return:
   1. A 1-2 sentence summary (mention which skill/command you used, if any).
   2. Files changed (if any).
   3. Test results (if any).
   4. Outcome signal: DONE or CONTINUE. Report DONE if the work is complete /
      verified; report CONTINUE if more work is needed (e.g., tasks remain,
      review found issues).
   ```

   `<DISCOVERED_PATHS>` is replaced with the discovered directories from
   `state.discovered`:
   - If `commands_dirs` is non-empty: "Check these locations:
     `.opencode/commands/` (.md), `.claude/commands/` (.md), ..."
   - If `skills_dirs` is non-empty: "Installed skills are in:
     `.claude/skills/`, ..."
   - If both empty: "Check your harness's commands/skills directories, or
     consult `references/agent-integrations.md` for known locations."

4. Wait for the subagent.
5. **Update `.mission-state.json` now** — before the next step. Store a 1-2
   sentence summary as `step_results.<id>.output`; append `<id>` to
   `completed_steps`; mark `state.steps[N].status` = `completed`; write the
   file. Discard the full subagent response.
6. If the step was `implement`, append to `<FEATURE_DIR>/iterations.md`:
   ```markdown
   ## Iteration <N> - <date>
   - Files changed: <list>
   - Summary: <1-2 sentences>
   - Tests: <pass/fail>
   ```
7. If `spec_correction_signal` is set (config), check for that file in the
   feature directory. If it exists → **stop and return**
   `spec_correction_needed` to Phase 6. Do not continue.

#### Gate steps (sync, gated/hybrid only)

When supervision is `gated` or `hybrid`, the executor inserts gates inline
(not as separate steps — as executor behavior):

- **After specify** (gated + hybrid): ask "Spec created. Review before
  implementation?" → proceed / revise (re-run specify) / abort.
- **After each implement** (gated only): ask "Implementation complete. Run
  convergence?" → proceed / revise (re-run implement) / abort.
- **Final sign-off** (gated + hybrid): after converge, ask "Convergence
  passed. Review and approve completion?" → approve / reject (pause).

For `--async` or `autonomous`: no gates, no sign-off.

Store gate choices in `step_results.<id>_gate.output.choice`.

#### Converge loop (implement ↔ converge)

The implement and converge steps form a do-while loop:

1. Execute `implement` step (iteration N).
2. Execute `converge` step.
3. Check the converge subagent's outcome signal:
   - **DONE** → loop exits, proceed to Phase 6.
   - **CONTINUE** → increment `consecutive_tasks_appended`, check circuit
     breaker (below), repeat from 1 if under `max_iterations`.

Use **iteration-prefixed IDs** for tracking: `loop_0_implement`,
`loop_1_implement`, etc. The step `id` stays as-is; only the
`completed_steps` entry is prefixed.

**Circuit breaker.** Track `consecutive_tasks_appended` in state. After each
converge step, if the signal is CONTINUE, increment; if DONE, reset to 0. If
the counter reaches `circuit_breaker` (default 3) → stop the loop and return
`failed`: "Circuit breaker: N consecutive iterations did not converge. Human
review needed — the loop is not converging." This counter persists across
resume.

#### Context budget awareness

After every step, summarize and discard the full subagent response. After 5+
steps, proactively suggest: "Session is getting long — you can continue, or
start a fresh chat and run `mission-brief --resume`." If responses get
repetitive, suggest a fresh chat.

### Phase 6 — Completion routing

When all steps complete (or a signal forces a return), act on the signal:

**`spec_correction_needed`** (only if `spec_correction_signal` is set):

1. Read state. If `spec_corrections >= max_spec_corrections` → **STOP**:
   "Spec repeatedly fails evaluation (N/M). Human review of the spec
   required." Keep the signal file and state for inspection.
2. Otherwise: consume the signal file, increment `spec_corrections`, reset
   all step statuses to `pending` (fresh pipeline run), re-execute (Phase 5),
   repeat Phase 6.

**`converged` or `tasks_appended`** (loop finished):

- sync + gated/hybrid → **require human sign-off**: display the audit trail
  from `iterations.md`; ask "Convergence passed. Review and approve
  completion?" → approve proceeds; reject pauses ("Mission paused for review.
  Run `mission-brief --resume` after addressing issues.").
- sync + autonomous, or `--async` → skip sign-off.
- Move `.mission-state.json` → `.adlc/workflow/runs/<feature>/mission-log.json`
  (audit trail — not deleted).
- Report:
  ```
  ## Mission Complete
  - Feature: <feature>
  - Route: <route>
  - Execution: <sync|async>
  - Supervision: <mode>
  - Signal: <converged|tasks_appended>
  - Spec corrections: <n>/<max>
  - Audit trail: .adlc/workflow/runs/<feature>/mission-log.json
  ```

**`failed`**: report the error; keep state for inspection. User can re-run
`mission-brief --resume`.

## Safety mechanisms

- **Supervision modes**: gated (default) gates inline; autonomous runs freely
  but requires checkable done-criteria (refuse "TBD"); hybrid gates only at
  spec review + final sign-off.
- **Async forces ungated**: `--async` + gated/hybrid config → warn + autonomous.
- **Inner loop cap**: `max_iterations` (default 5).
- **Circuit breaker**: stops after N consecutive non-converging iterations
  (default 3) — prevents infinite spinning; persists across resume.
- **Outer loop cap**: `max_spec_corrections` (default 2).
- **Converge independence hint**: converge subagent verifies independently.
- **Audit trail**: `iterations.md` + `mission-log.json` — not deleted.
- **State persistence**: `.mission-state.json` survives compaction/restarts.
- **Resume is explicit**: `mission-brief --resume`; fresh `mission-brief` asks
  before clobbering an interrupted state.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is a small task, I'll skip the converge loop" | Small tasks use the `quick` route (implement only). If you classified spec/change, the loop is the point. |
| "I'll run gates later" | Gates exist to catch drift early. Skipping the spec gate means implementing against an unreviewed spec. |
| "Async can keep the gates, I'll answer them" | No one is watching an async run. Async forces ungated; if you want gates, use sync. |
| "The state file is just clutter, I'll delete it" | It's the resume + audit mechanism. Deleting it loses checkpoint/resume and the audit trail. |
| "I'll just re-run mission-brief to resume" | Without `--resume` you'll be asked and may clobber the state. Use `mission-brief --resume`. |
| "I don't need the Mission Brief, just start coding" | The brief forces explicit success criteria. Without them, the converge step has nothing to verify against. |

## Red Flags

- Executing steps without writing `.mission-state.json` after each one.
- Inserting gates in an `--async` run.
- Skipping the Mission Brief in autonomous mode when Success Criteria are
  "TBD".
- Reading the full subagent response into working memory instead of
  summarizing + discarding.
- Clobbering an interrupted state without asking (fresh `mission-brief`
  without `--resume`).
- Deleting `.mission-state.json` on completion instead of moving it to
  `mission-log.json`.
- Hardcoding a specific agent's commands directory instead of using the
  discovered paths from `state.discovered`.

## Verification

- `.adlc/workflow/workflow-config.yml` exists (copied from template if
  absent).
- `.mission-state.json` contains: `brief` (goal/constraints/success criteria),
  `steps` (ordered list with phase/tier/prompt/status), `discovered`
  (skills_dirs + commands_dirs), `completed_steps` (grows monotonically).
- `iterations.md` gains an entry per implement step.
- On completion, `mission-log.json` exists under
  `.adlc/workflow/runs/<feature>/`.
- A `--resume` with no state reports "No interrupted mission found" and stops.
- A `--resume` with `mission-log.json` present reports "already completed".
- The delegation prompt includes discovered paths (not a hardcoded list).
- Gate steps appear only in sync + gated/hybrid runs, never in `--async`.

## Configuration

- `.adlc/workflow/workflow-config.yml` — execution, supervision, budgets,
  spec-correction signal, optional models map. See `config-template.yml`.
- `references/agent-integrations.md` — full agent→directory mapping table.
  Update when new agents are added or conventions change. The executor reads
  it at generation time for command/skills discovery.

## Example session

```
# Start a sync gated mission
mission-brief "add a new react dashboard with telemetry"

# Run unattended across sessions
mission-brief --async "refactor the auth module to use JWT"

# Resume after a session restart or a paused gate
mission-brief --resume
```
