---
name: factory-intent
description: Use when orchestrating an intent lifecycle (product + architecture lanes, two scope-pinned gates, joint build-and-verify) to generate PRD.md and AD.md from one Mission Brief.
disable-model-invocation: true
---

# factory-intent

## In a factory run — read this first

When `ADLC_RUN_ID` is set, the workflow engine runs this step unattended and a gate follows it. Do exactly this:

1. **Start:** `bash {REPO_ROOT}/.agents/skills/factory-mission/scripts/bash/run-branch.sh` — on Windows, the PowerShell twin (every helper has one under `scripts/powershell/`)
2. Run the lifecycle steps the DAG resolves for the issue. After **each** step that changed files: `commit-step.sh` with every path it wrote, moved or deleted.
3. **Before you return, always:** `open-mr.sh`, then write a one-line `conclusion` into `ADLC_STEP_OUTPUT`. Do this whatever the outcome, even when nothing changed.
4. **Never ask for approval** or wait for an answer. The engine's gate after this step is the approval; a question here ends the step with nothing published.

Only this orchestrator commits, pushes and opens the MR, and only through these helpers; lifecycle skills never do. Details: [Run Branch, Step Commits and Draft MR](#run-branch-step-commits-and-draft-mr).

---

## What this skill does

`factory-intent` orchestrates the intent lifecycle over two lanes. It
coordinates the product lifecycle skills (`product-init`, `product-specify`,
`product-clarify`, `product-implement`, `product-analyze`) and the
architecture lifecycle skills (`architect-init`, `architect-specify`,
`architect-clarify`, `architect-implement`, `architect-analyze`) to maintain
a consistent `PRD.md` and `AD.md` from a single Mission Brief.

It operates as a **Kind-A DAG orchestrator** in alignment with the shared
executor engine contract in `factory-mission/references/executor.md`. It
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

---

## Lifecycle DAG & Step Resolution

`factory-intent` implements a **fixed named-skill DAG** (`fixed` step resolution)
with one step per lane per phase:

### Greenfield Route (default on empty project)
1. **`product-specify` / `architecture-specify`** (`generate`) — capture
   drafts in `.adlc/drafts/pdr/` and `.adlc/drafts/adr/`.
2. **`product-clarify` / `architecture-clarify`⭐** (`clarify`) — quality
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
one lane may refresh while the other runs greenfield.

---

## Boundary & Tiebreak

Product decides WHAT / WHY / FOR WHOM (problem, persona, scope, priority,
business metrics, NFR targets). Anything answering HOW (stack, pattern,
interface, NFR mechanism) is recorded as a handoff note to the architecture
lane, never as a product decision. Overlap disputes escalate to a named
human; the ruling is posted to the comment bus as a `decision` output
(human tiebreak — no auto-resolution). The joint implement waits until the
human ruling lands.

---

## Shared Executor Overrides

1. **Publish Target**: Fixed to `local` (`docs/adlc/memory/` + PRD/AD).
2. **Output Types**: `specify`/`init` → `draft`; `clarify`⭐ → `decision`;
   `implement` → `artifact-ref`; `analyze` → `findings`.
3. **Correction Loop**: per-lane HIGH/CRITICAL routes that lane back to its
   clarify, bounded by `max_corrections` (default 2); if exceeded, halt for
   human review.
4. **Supervision Default**: `hybrid` — human gates at both clarifies and at
   final review. Merge sign-off is always human.
5. **Pre-flight Check**: Verifies both `product-*` and `architect-*`
   lifecycle skills are installed before beginning Phase 0.

---

## Run Branch, Step Commits and Draft MR

**Requires:** the `factory-mission` skill (provides the run helpers).

In a factory run (`ADLC_RUN_ID` set) this orchestrator — and only it — commits,
pushes the run branch and opens the draft MR through `run-branch.sh`,
`commit-step.sh` (one commit per step, trailer-tagged, allowlist-staged) and
`open-mr.sh` (one draft MR per issue, `mr_url` in `ADLC_STEP_OUTPUT` for the
gates' `context.link`). Outside a factory run the helpers are no-ops unless
the user opted in. A helper's non-zero exit stops the run.
