---
name: factory-learn
description: Learning Loop Orchestrator. Extracts CDRs/ChDRs, reviews them via gates/regression, publishes to team-ai-directives via PR, and prunes/verifies rules via build-to-delete.
disable-model-invocation: true
---

# factory-learn

## What this skill does

`factory-learn` orchestrates the continuous improvement learning loop of the software factory (deck slide 18). It coordinates individual learning-related skills (`levelup-init`, `levelup-specify`, `levelup-clarify`, `levelup-publish`, `change-init`, `change-clarify`, `change-publish`, `team-repair`, `evals-analyze`) to transition draft directives into verified, published, and minimal team context assets.

It operates as a **Kind-A DAG orchestrator** in alignment with the shared executor engine contract in `factory-mission/references/executor.md`.

---

## When to use

- You want to extract and compile hard-won session learnings into your team's centralized `team-ai-directives` repository.
- You want to mine git commit history to capture the rationale (ChDRs) behind past reverts and hotfixes.
- You want to run "Build to Delete" (Harness Decay checks) to prune redundant rules.

**When NOT to use**:
- For product-level specification or development (use `factory-product` or `factory-mission` instead).
- If the team directives repository is completely unconfigured (run `/team-setup` first).

---

## Lifecycle DAG & Step Resolution

`factory-learn` implements a **fixed named-skill DAG** (`fixed` step resolution):

### Session Learnings Route (default on session-end)
1. **`specify`** (`generate` phase) -> Invoke `levelup-specify` to extract candidate Context Directive Records (CDRs) and compliances from the active session.
2. **`clarify`⭐** (`clarify` phase) -> Invoke `levelup-clarify` to review pending CDRs. Enforces the **evals-regression gate** (running the compliance goldset as the `verify` sub-phase to ensure no quality degradation).
3. **`publish`** (`build` phase) -> Invoke `levelup-publish` to package accepted CDRs, index them, and compile a draft PR targeting the `team-ai-directives` repository.
4. **`prune`** (`analyze` phase) -> Runs the PDR-021 cleanup bot over the directive store to detect and propose deprecations of superseded, contradictory, or stale rules. Deprecations feed back to `levelup-clarify`.

### Historical Mining Route (brownfield)
1. **`init`** (`generate` phase) -> Invoke `change-init` to mine git history and issue trackers for Change Decision Records (ChDRs).
2. **`clarify`⭐** (`clarify` phase) -> Invoke `change-clarify` to run interactive provenance reviews on mined claims.
3. **`publish`** (`build` phase) -> Invoke `change-publish` to promote accepted ChDRs into `.adlc/memory/chdr/` and regenerate indices.

### Maintenance & Build-to-Delete Route (periodic)
1. **`verify`** (`verify` phase) -> Run `team-repair --build-to-delete`. Re-runs goldset evals with rules temporarily disabled. If the model passes without a rule, the rule is flagged as redundant.
2. **`clarify`⭐** -> Proposes the redundant rule's deprecation to `levelup-clarify` for human review.

---

## Shared Executor Overrides

`factory-learn` overrides the shared executor engine primitives as follows:

1. **Publish Target**: Fixed to `external-repo`. Opens or updates a draft pull request on the configured `team-ai-directives` repository.
2. **Feedback Loop Ingestion**: Automatically consumes the output of `evals-analyze` (when an application test fails due to specification issues, `evals-analyze` automatically routes to `levelup-specify`, which triggers this orchestrator).
3. **Supervision Default**: `hybrid`. Human gates are hard-enforced at `clarify`⭐ (approval of CDR/ChDR entries) and at final PR creation.
4. **Pre-flight Check**: Verifies that `levelup-*`, `change-*`, and `team-*` skills are installed, and that the directives repo path is set in `.adlc/init-options.json`.
