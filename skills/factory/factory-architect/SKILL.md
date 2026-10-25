---
name: factory-architect
description: Use when orchestrating an architecture lifecycle (specify/init → clarify → implement → analyze) to generate or maintain AD.md.
disable-model-invocation: true
---

# factory-architect

## In a factory run — read this first

When `ADLC_RUN_ID` is set, the workflow engine runs this step unattended and a gate follows it. Do exactly this:

1. **Start:** `bash {REPO_ROOT}/.agents/skills/factory-mission/scripts/bash/run-branch.sh` — on Windows, `pwsh {REPO_ROOT}/.agents/skills/factory-mission/scripts/powershell/run-branch.ps1` (every helper has a PowerShell twin under `scripts/powershell/`; use it instead of the bash one on Windows)
2. Run the lifecycle steps the DAG resolves for the issue. After **each** step that changed files: `commit-step.sh` with every path it wrote, moved or deleted.
3. **Before you return, always:** `open-mr.sh`, then write a one-line `conclusion` into `ADLC_STEP_OUTPUT`. Do this whatever the outcome, even when nothing changed.
4. **Never ask for approval** or wait for an answer. The engine's gate after this step is the approval; a question here ends the step with nothing published.

Only this orchestrator commits, pushes and opens the MR, and only through these helpers; `architect-*` skills never do. Details: [Run Branch, Step Commits and Draft MR](#run-branch-step-commits-and-draft-mr).

---

## What this skill does

`factory-architect` orchestrates the architecture-decisions lifecycle. It coordinates individual architecture-related skills (`architect-init`, `architect-specify`, `architect-clarify`, `architect-implement`, `architect-analyze`) to maintain a consistent `AD.md` at the project root.

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
3. **`implement`** (`build` phase) -> Invoke `architect-implement` to compile accepted ADRs into `AD.md` (by sub-systems) and promote them to `docs/adlc/memory/adr/`.
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

1. **Publish Target**: Fixed to `local`. Outputs are written to `docs/adlc/memory/adr/` and `docs/adlc/architect/AD.md`. If tracker-integrated, a `tracker` completion summary comment is also posted.
2. **Output Types**: Steps use the following `output_type` assignments:
   - `specify`/`init` → `draft` (ADR drafts stay in `.adlc/drafts/adr/`, not published to comment bus)
   - `clarify`⭐ → `decision` (accepted/rejected ADR list published to comment bus)
   - `implement` → `artifact-ref` (AD.md path reference published, content stays on disk)
   - `analyze` → `findings` (severity-ranked consistency report published to comment bus)
3. **Correction Loop**: If `analyze` returns `CRITICAL` or `HIGH` consistency errors, the executor routes back to `clarify` with the analyze marker in `reads_from`. `clarify` reads the findings from the PR/MR/issue comment bus (or local fallback). This loop is bounded by `max_corrections` (default 2); if exceeded, the orchestrator halts for human review.
4. **Supervision Default**: `hybrid`. A human gate is hard-enforced at `clarify`⭐ (for ADR approvals) and at final `AD.md` review.
5. **Pre-flight Check**: Verifies that the `architect-*` lifecycle skills are installed in the workspace before beginning Phase 0.

---

## Run Branch, Step Commits and Draft MR

**Requires:** the `factory-mission` skill (provides the run helpers): `adlc-cli skills add tikalk/adlc-team-skills --skill factory-mission`

In a factory run (`ADLC_RUN_ID` set by the workflow engine) this orchestrator — and only it, never the `architect-*` lifecycle skills — commits, pushes the run branch and opens the draft MR, always through these three helpers:

1. **Before the first step:** `bash {REPO_ROOT}/.agents/skills/factory-mission/scripts/bash/run-branch.sh` — checks out `factory/intent/<repo>-<iid>` (from `ADLC_ISSUE_REF`) in the project root, reusing it or continuing from `origin`. Shared with the other intent lane and with re-dispatches.
2. **After each step** (`specify`/`init`, `clarify`, `implement`, `analyze` fixes):
   `bash {REPO_ROOT}/.agents/skills/factory-mission/scripts/bash/commit-step.sh --orchestrator factory-architect --step <step> --output-type <draft|decision|artifact-ref|findings> --summary "<one line, no issue text>" --records <IDs> -- <paths the step wrote>`
   Pass every path the step wrote, moved or deleted (a promoted draft's old path too; the helper also commits deletions inside the allowlist), and only paths inside the lifecycle write allowlist (`.adlc/drafts/adr/`, `docs/adlc/memory/adr/`, `docs/adlc/architect/AD.md`, `docs/adlc/architect/views/`). It prints `sha: <sha>` or `sha: none`; put that `sha` in the step's bus marker (the bus carries pointers, not content). Never stage `.adlc/workflows/**`.
3. **Before you return, always:** `bash {REPO_ROOT}/.agents/skills/factory-mission/scripts/bash/open-mr.sh` — pushes the run branch only, finds or opens one draft MR (merge commit, no squash; milestone/assignee per the MR-ownership decision) and writes `mr_url` to `ADLC_STEP_OUTPUT`, which the engine's gate links (`context.link`). Call it whatever the outcome — even when nothing was committed (`sha: none`, an analyze-only pass): with no commits on the run branch it opens nothing and the gate shows there is nothing to review. Also write a one-line `conclusion` into the same JSON object (the gate's intent-conclusion rule).
   In a factory run the engine's gate after this step **is** the approval: do not ask for approval yourself (no "approve `implement`?" question) — finish the steps the issue needs, run `open-mr.sh`, state the conclusion and return.

Outside a factory run the helpers do nothing unless the user opted in (`adlc.commit_steps: true` in `.adlc/init-options.json`, or `--commit` passed to this skill, which you forward to `commit-step.sh`); `run-branch.sh` and `open-mr.sh` never act without `ADLC_RUN_ID`. A helper's non-zero exit (refused path, missing committer identity, tracker scope) stops the run — report it, do not work around it.
