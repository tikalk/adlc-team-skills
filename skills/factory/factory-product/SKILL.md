---
name: factory-product
description: Product Lifecycle Orchestrator. Walks Greenfield (specify) / Brownfield (init) → clarify⭐ → implement → analyze to maintain PRD.md.
disable-model-invocation: true
---

# factory-product

## What this skill does

`factory-product` orchestrates the product-decisions lifecycle (deck slide 12 Intent Harness stage). It coordinates individual product-related skills (`product-init`, `product-specify`, `product-clarify`, `product-implement`, `product-analyze`) to maintain a consistent `PRD.md` at the project root.

It operates as a **Kind-A DAG orchestrator** in alignment with the shared executor engine contract in `factory-mission/references/executor.md`.

---

## When to use

- You want to bootstrap, refine, or analyze a product's requirements and decisions (PDRs) end-to-end.
- You want a guided, accept-gated, and verified product definition process with a resume checkpoint.

**When NOT to use**:
- For software implementation task execution (use `factory-mission` instead).
- For architecture decision records (use `factory-architect` instead).

---

## Lifecycle DAG & Step Resolution

`factory-product` implements a **fixed named-skill DAG** (`fixed` step resolution):

### Greenfield Route (default on empty project)
1. **`specify`** (`generate` phase) -> Invoke `product-specify` to collaboratively capture PDR drafts in `.adlc/drafts/pdr/`.
2. **`clarify`⭐** (`clarify` phase) -> Invoke `product-clarify` to run interactive quality checks and mark PDRs Accepted (human sign-off gate).
3. **`implement`** (`build` phase) -> Invoke `product-implement` to compile accepted PDRs into `PRD.md` and promote them to `.adlc/memory/pdr/`.
4. **`analyze`** (`analyze` phase) -> Invoke `product-analyze` to verify PRD/PDR consistency and output a severity-ranked report.

### Brownfield Route (default if code exists but no PDRs)
1. **`init`** (`generate` phase) -> Invoke `product-init` to reverse-engineer draft PDRs from the existing codebase.
2. **`clarify`⭐** → **`implement`** → **`analyze`** (same as Greenfield).

### Refresh Route (default if PRD.md and memory PDRs already exist)
1. **`analyze`** (`analyze` phase) -> Run product-analyze first to detect drift.
2. **`clarify`⭐** → **`implement`** → **`analyze`** (drift-correction cycle).

---

## Shared Executor Overrides

`factory-product` overrides the shared executor engine primitives as follows:

1. **Publish Target**: Fixed to `local`. Outputs are written to `.adlc/memory/pdr/` and `PRD.md`.
2. **Correction Loop**: If `analyze` returns `CRITICAL` or `HIGH` consistency errors, the executor routes back to `clarify` with the report as input. This loop is bounded by `max_corrections` (default 2); if exceeded, the orchestrator halts for human review.
3. **Supervision Default**: `hybrid`. A human gate is hard-enforced at `clarify`⭐ (for PDR approvals) and at final `PRD.md` review.
4. **Pre-flight Check**: Verifies that the `product-*` lifecycle skills are installed in the workspace before beginning Phase 0.
