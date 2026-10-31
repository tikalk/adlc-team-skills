---
name: factory-intent
description: Use when orchestrating an intent lifecycle (product + architecture lanes, two scope-pinned gates, joint build-and-verify) to generate PRD.md and AD.md from one Mission Brief.
disable-model-invocation: true
---

# factory-intent

## In a factory run — read this first

When `ADLC_RUN_ID` is set, the workflow engine runs this step unattended and a gate follows it. Invoke the `factory-runbook` skill for the publish sequence (run branch → step commits → draft MR, plus the run-context rules); run the lifecycle steps the DAG resolves for the issue in between.

**Never ask for approval** or wait for an answer. The engine's gate after this step is the approval. **Before you return, always:** write `mr_url` and a one-line `conclusion` into `ADLC_STEP_OUTPUT`, whatever the outcome.

Only this orchestrator invokes the publish sequence, and only through the runbook; lifecycle skills never do. Details: [Run Branch, Step Commits and Draft MR](#run-branch-step-commits-and-draft-mr).

---

## What this skill does

`factory-intent` orchestrates the intent lifecycle over two lanes. It
coordinates the product lifecycle skills (`product-init`, `product-specify`,
`product-clarify`, `product-implement`, `product-analyze`) and the
architecture lifecycle skills (`architect-init`, `architect-specify`,
`architect-clarify`, `architect-implement`, `architect-analyze`) to maintain
a consistent `PRD.md` and `AD.md` from a single Mission Brief.

It operates as a **Kind-A DAG orchestrator** in alignment with the shared
executor engine contract in `factory-runbook/references/executor.md`. It
replaces the twin orchestrators with one two-lane DAG — no aliases.

---

## When to use

- You want to capture product requirements and architecture decisions
  end-to-end from one intent, each signed at its own gate.
- You want a guided, accept-gated, verified definition process with a
  resume checkpoint.

**When NOT to use**:
- For software implementation task execution (use `factory-mission` instead).
- For single-lane follow-ups already past intent (invoke the lane skill directly).

### Single-lane runs (lane activation)

When the brief needs one lane only, run that lane's entry workflow instead
of the both-lanes `workflow.yml`:

- Product only → `workflow-product.yml` (`specify` → `clarify` →
  `gate-decisions` → `build-and-verify`, product commands, PDR-scoped gate).
- Architecture only → `workflow-architecture.yml` (same shape, architecture
  commands, ADR-scoped gate).

Each entry mirrors the removed twin's step shape with the gate-context
contract (records/since/link); the adaptive executor resolves its `route`
input at dispatch the same way.

---

## Lifecycle DAG & Step Resolution

`factory-intent` implements a **fixed named-skill DAG** (`fixed` step resolution)
with one step per lane per phase:

### Greenfield Route (default on empty project)
1. **`product-specify` / `architect-specify`** (`generate`) — capture
   drafts in `.adlc/drafts/pdr/` and `.adlc/drafts/adr/`.
2. **`product-clarify` / `architect-clarify`⭐** (`clarify`) — quality
   checks; each lane marks its own drafts accepted at its own gate.
3. **`gate-product-decisions` / `gate-architecture-decisions`** — separate
   scope-pinned human gates. Neither gate can accept the other lane's
   artifacts; a lane blocked at its gate does not block the other lane's
   drafting — only the joint implement waits for both gates.
4. **`build-and-verify`** — joint implement (`product-implement`,
   `architect-implement`) then joint analyze (`product-analyze`,
   `architect-analyze`).

### Brownfield / Refresh Routes
Per-lane route inputs (`product_route`, `architecture_route`) select
greenfield / brownfield (`init`) / refresh (analyze-first) independently —
one lane may refresh while the other runs greenfield. The adaptive (LLM)
executor resolves the routes at dispatch (choosing `init` vs `specify` vs
analyze-first for each lane); the checked-in `workflow.yml` below encodes the
greenfield default (`specify` lanes) for headless execution.

---

## Boundary & Tiebreak

Product decides WHAT / WHY / FOR WHOM (problem, persona, scope, priority,
business metrics, NFR targets). Anything answering HOW (stack, pattern,
interface, NFR mechanism) is recorded as a handoff note to the architecture
lane, never as a product decision. Overlap disputes escalate to a named
human; the ruling is posted to the comment bus as a `decision` output
(human tiebreak — no auto-resolution). The adaptive executor must not run
the joint implement until the human ruling lands (the checked-in
`workflow.yml` encodes the greenfield two-gate default; the tiebreak wait is
enforced at dispatch, not by a gate in that file).

---

## Shared Executor Overrides

1. **Publish Target**: Fixed to `local` (`docs/adlc/memory/` + PRD/AD).
2. **Output Types**: `specify`/`init` → `draft`; `clarify`⭐ → `decision`;
   `implement` → `artifact-ref`; `analyze` → `findings`.
3. **Correction Loop**: per-lane HIGH/CRITICAL routes that lane back to its
   clarify, bounded by `max_corrections` (default 2); if exceeded, halt for
   human review. (Adaptive executor behavior — the checked-in `workflow.yml`
   headless loop below is a bounded re-implementation only.)
4. **Supervision Default**: `hybrid` — human gates at both clarifies and at
   final review. Merge sign-off is always human.
5. **Pre-flight Check**: Verifies both `product-*` and `architect-*`
   lifecycle skills are installed before beginning Phase 0.

---

## Run Branch, Step Commits and Draft MR

**Requires:** the `factory-runbook` skill (provides the publish procedure and run contracts): `adlc-cli skills add tikalk/adlc-team-skills --skill factory-runbook`

In a factory run (`ADLC_RUN_ID` set by the workflow engine) this orchestrator — and only it, never the lane lifecycle skills — commits, pushes the run branch and opens the draft MR. Invoke the `factory-runbook` skill for the publish sequence with:

1. **Branch:** `factory/intent/<repo>-<iid>` (from `ADLC_ISSUE_REF`) — shared by both lanes and with re-dispatches; continues from `origin`.
2. **Step commits** (`specify`/`init`, `clarify`, `implement`, `analyze` fixes): every path the step wrote, moved or deleted (a promoted draft's old path too), restricted to the lifecycle write allowlists (`.adlc/drafts/pdr/`, `docs/adlc/memory/pdr/`, `docs/adlc/product/PRD.md`, `.adlc/product/sections/`, `.adlc/product/state.json`, `.adlc/drafts/adr/`, `docs/adlc/memory/adr/`, `docs/adlc/architect/AD.md`, `docs/adlc/architect/views/`, `.adlc/architect/state.json`). Put the returned `sha` in the step's bus marker (the bus carries pointers, not content). Never stage `.adlc/workflows/**`.
3. **Draft MR + conclusion:** Call it whatever the outcome — even when nothing was committed (`sha: none`, an analyze-only pass): with no commits on the run branch it opens nothing and the gate shows there is nothing to review. In a factory run the engine's gate after this step **is** the approval: do not ask for approval yourself — finish the steps the issue needs, state the conclusion and return.

Outside a factory run the runbook helpers do nothing unless the user opted in (`adlc.commit_steps: true` in `.adlc/init-options.json`, or `--commit` passed to this skill and forwarded); a helper's non-zero exit (refused path, missing committer identity, tracker scope) stops the run — report it, do not work around it.
