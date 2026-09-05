# Factory Workflow Executor Engine (Shared Contract)

## Overview

This is the canonical executor contract for all Kind-A factory orchestrators (`factory-mission`, `factory-product`, `factory-architect`, `factory-learn`). It defines how to compile a feature or lifecycle task into a structured step list, execute steps sequentially with state tracking, handle supervision gates, and run correction loops.

---

## Core Process

### Phase 0 — Configuration
1. Every orchestrator reads `.adlc/workflow/workflow-config.yml` (copied from `config-template.yml` if absent).
2. Supervision default is `gated` (or `hybrid` for lifecycle runs, meaning gates only at `clarify`⭐ and merge sign-off).
3. Verify target lifecycle/compliance skills are installed (check `.agents/skills/` directory). Stop if missing.

### Phase 1 — Resume Check (`--resume`)
1. Read the state file: `.adlc/workflow/.factory-<orchestrator>-state.json`.
2. If state is empty: start fresh.
3. If state exists with incomplete steps: load steps and skip to the first pending step.
4. Completed runs archive to `.adlc/workflow/runs/<slug>/`.

### Phase 2 — Brief Construction
Before executing, compile the input into a structured Brief contract:
- **Goal**: One-sentence core objective.
- **Constraints**: Environment, tech stack, and non-goals.
- **Success Criteria**: Measurable binary verification outcomes.
Presented to the user for sign-off (in gated/hybrid modes).

### Phase 3 — Route Classification
Classify into routes based on workspace state (or `--route` override):
- `greenfield` (specify/new)
- `brownfield` (init/exist)
- `refresh` (analyze/drift correction)

### Phase 4 — Step List Generation
Generate an ordered list of steps using the orchestrator's specific DAG.
Step schema:
```json
{
  "id": "step_id",
  "phase_type": "generate | clarify | build | verify | analyze",
  "tier": "strong | fast",
  "skill": "exact-skill-name | routed",
  "prompt": "Instruction text",
  "status": "pending | completed"
}
```
Mirror steps to a `todowrite` tracking list.

### Phase 5 — Step Execution Loop
For each step:
1. Dispatch to a subagent with the instruction, Brief context, and either the exact skill to invoke (`fixed` resolution) or the universal skill routing metadata (`routed` resolution).
2. If `phase_type` is `verify`: prepend independent verification instructions (maker/checker separation).
3. If subagent returns `NEEDS_CORRECTION` or `analyze`/`verify` reports CRITICAL/HIGH errors: route back to the preceding `clarify`⭐ step (bounded by `max_corrections`, default 2).
4. **Confidence Escalation Gate**: If subagent reports `Confidence score: LOW`, auto-escalate supervision to `gated` and halt for human confirmation.
5. Persist state to the json file after *every* step completion. Discard full subagent responses to manage context.

### Phase 6 — Completion & Publish
On successful convergence of all steps:
1. Route to the specified **Publish Target**:
   - `local`: Write to `.adlc/` and project root.
   - `external-repo`: Open a PR on the `team-ai-directives` repository (used by `factory-learn`).
2. Move state to the run archive directory. Print the audit trail.
