---
name: factory-architect
description: Architecture Lifecycle Orchestrator. Walks Greenfield (specify) / Brownfield (init) → clarify⭐ → implement → analyze to maintain AD.md and enforce constraints.
disable-model-invocation: true
---

# factory-architect

## What this skill does

`factory-architect` orchestrates the architecture-decisions lifecycle (deck slide 12 Intent Harness stage). It coordinates individual architecture-related skills (`architect-init`, `architect-specify`, `architect-clarify`, `architect-implement`, `architect-analyze`) to maintain a consistent `AD.md` at the project root.

It operates as a **Kind-A DAG orchestrator** in alignment with the shared executor engine contract in `factory-mission/references/executor.md`.

---

## When to use

- You want to bootstrap, refine, or analyze a project's system-level design and decisions (ADRs) end-to-end.
- You want to verify that architectural viewpoints conform to the Rozanski & Woods methodology.

**When NOT to use**:
- For product-requirements definition (use `factory-product` instead).
- For feature-level software execution (use `factory-mission` instead).

---

## Lifecycle DAG & Step Resolution

`factory-architect` implements a **fixed named-skill DAG** (`fixed` step resolution):

### Greenfield Route (default on empty project)
1. **`specify`** (`generate` phase) -> Invoke `architect-specify` to collaboratively capture ADR drafts in `.adlc/drafts/adr/`.
2. **`clarify`⭐** (`clarify` phase) -> Invoke `architect-clarify` to run interactive quality checks and mark ADRs Accepted (human sign-off gate).
3. **`implement`** (`build` phase) -> Invoke `architect-implement` to compile accepted ADRs into `AD.md` (by sub-systems) and promote them to `.adlc/memory/adr/`.
4. **`analyze`** (`analyze` phase) -> Invoke `architect-analyze` to verify AD/ADR consistency and output a severity-ranked report.

### Brownfield Route (default if code exists but no ADRs)
1. **`init`** (`generate` phase) -> Invoke `architect-init` to reverse-engineer draft ADRs from the existing architecture.
2. **`clarify`⭐** → **`implement`** → **`analyze`** (same as Greenfield).

### Refresh Route (default if AD.md and memory ADRs already exist)
1. **`analyze`** (`analyze` phase) -> Run architect-analyze first to detect drift.
2. **`clarify`⭐** → **`implement`** → **`analyze`** (drift-correction cycle).

---

## Shared Executor Overrides

`factory-architect` overrides the shared executor engine primitives as follows:

1. **Publish Target**: Fixed to `local`. Outputs are written to `.adlc/memory/adr/` and `AD.md`.
2. **Correction Loop**: If `analyze` returns `CRITICAL` or `HIGH` consistency errors, the executor routes back to `clarify` with the report as input. This loop is bounded by `max_corrections` (default 2); if exceeded, the orchestrator halts for human review.
3. **Supervision Default**: `hybrid`. A human gate is hard-enforced at `clarify`⭐ (for ADR approvals) and at final `AD.md` review.
4. **Pre-flight Check**: Verifies that the `architect-*` lifecycle skills are installed in the workspace before beginning Phase 0.
