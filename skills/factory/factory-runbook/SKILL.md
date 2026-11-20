---
name: factory-runbook
description: Use when a factory run must post its changes — check out the run branch, commit a step's allowlisted paths, push only that branch, and open or reuse one draft MR/PR with milestone/assignee ownership. Also the shared home for factory run contracts (executor, tracker integration, lanes, brief and provider templates).
---

# factory-runbook


> **Scope rule**: scripts stay skill-local — never source a script from another skill. For another skill's operations, invoke that skill (e.g. `architect-clarify`, `product-clarify`, `team-boot`) via the Skill tool; for its documents, follow the `Requires` line. `scripts/` and `references/` below are relative to this skill. `{REPO_ROOT}` denotes the project root (where `.adlc/` lives).

## What this skill does

`factory-runbook` is the shared run mechanics of the software factory. It has
two halves:

1. **Publish procedure** (below) — the deterministic branch → commit → push →
   draft-MR/PR sequence every factory run ends with. Factory orchestrators
   invoke this skill for their publish step; it is also directly usable to
   post a run's changes.
2. **Run contracts** (`references/`) — the executor loop, tracker
   integration, lanes, brief/provider templates, and run-context rules that
   factory skills borrow by path instead of copying.

It never approves or merges. The engine's gate after the step is the approval.

**Direct-invocation guard:** publishing needs a run context — `ADLC_RUN_ID`
(and usually `ADLC_ISSUE_REF` plus `ADLC_STEP_OUTPUT`) from a workflow run, the
lane's `WORKFLOW_INPUTS` in a raw lane run (reviews, `autonomous` missions:
`bash scripts/bash/run-context.sh` prints `factory_run=yes` and the `run_id` /
`issue_ref` to use, and the helpers below adopt it on their own), or explicit
orchestrator-provided args (orchestrator name, step id, output type, paths).
Never invent a branch name, a step, paths to commit, or a run id, and never
set `ADLC_RUN_ID` by hand. Without a run context and without them, state what
is missing and stop.

---

## Publish procedure — read this first

**Requires:** nothing — this skill is self-contained. (Borrowers declare the
reverse: `adlc-cli skills add tikalk/adlc-team-skills --skill factory-runbook`.)

1. **Start:** `bash scripts/bash/run-branch.sh [--kind <intent|code>]`
   — on Windows, the PowerShell twin (every helper has one under
   `scripts/powershell/`). Checks out the run branch (`factory/intent/<repo>-<iid>`
   from `ADLC_ISSUE_REF` for intent runs — the default; `factory/mission/<repo>-<iid>`
   with `--kind code` for mission code runs) in the project root, reusing it
   or continuing from `origin`. A new code branch starts from origin's default
   branch, never from the checked-out intent branch, so the intent step's
   drafts stay out of the code MR. Shared by both intent lanes and with
   re-dispatches. Without a run context (`ADLC_RUN_ID`, or the lane's
   `WORKFLOW_INPUTS.run_id` adopted through `scripts/bash/run-context.sh`)
   this is a no-op.
2. Run the lifecycle steps. After **each** step that changed files:
   `bash scripts/bash/commit-step.sh --orchestrator <name> --step <id> --output-type
   <draft|decision|artifact-ref|findings> --summary "<one line, no issue text>"
   --records <IDs> -- <paths the step wrote, moved or deleted>`. Stages ONLY
   allowlisted paths; prints `sha: <sha>` or `sha: none` for the
   step's bus marker.
3. **Before returning, always:** `bash scripts/bash/open-mr.sh [--kind <intent|code>]` —
   pushes the run branch only, finds or opens one draft MR (merge commit, no
   squash; Issue milestone applied inline, Issue assignees else the
   runner's own account, per `tracker-integration.md` Operation 11; the
   deterministic resolver `scripts/bash/resolve-mr-ownership.sh`
   itself runs at caller/completion, not inside `open-mr.sh`), and the
   `agent-authored` stamp likewise lives at completion (mission Phase 6,
   orchestrator §7 hygiene — not in this helper). It writes `mr_url` to
   `ADLC_STEP_OUTPUT`. Pass
   `--kind code` for code missions (`factory/mission/*` branch). Call it
   whatever the outcome — an empty run opens nothing and the gate shows no
   link. Also write a one-line `conclusion` into the same JSON object,
   preserving existing keys.
4. **Never ask for approval** or wait for an answer here. A helper's non-zero
   exit (refused path, missing committer identity, tracker scope) stops the
   run — report it, do not work around it.

Outside a factory run the helpers do nothing unless the user opted in
(`adlc.commit_steps: true` in `.adlc/init-options.json`, or `--commit`
forwarded to `commit-step.sh`); `run-branch.sh` and `open-mr.sh` never act
without a run context (`scripts/bash/run-context.sh` prints `factory_run=no`).

Only an orchestrator-invoked runbook commits, pushes and opens the MR, and
only through these helpers; lifecycle skills never do.

**Lifecycle labels:** `bash scripts/bash/set-lifecycle.sh --issue <ref> --to
<state>` is the Set Lifecycle step of `references/tracker-integration.md`
Operation 9 as one command: it adds the target, removes every other lifecycle
label in the same call, re-reads the labels and exits 0 only when exactly the
target remains (1: another lifecycle label is still there; 2: usage or
tracker error). `--issue` defaults to the run's issue.

**Completion record:** `bash scripts/bash/post-completion.sh --outcome
<done|no-op|blocked|failed> --conclusion "<one line>" [--mr-url <url>]
[--details-file <md>]` leaves a mission run's one completion record on its
issue (`<!-- factory-mission:step=complete … run=<run id> … outcome=… -->`;
blocked/failed records also carry the `factory-run:ended` marker). The run id
comes from the run context only; a run that already has a record posts
nothing; the record is read back (exit 0 only when it is on the issue).

---

## Run contracts (`references/`)

| File | Borrowed by |
|--|--|
| `executor.md` | every Kind-A orchestrator (step schema, run state, lanes, gates, converge) |
| `tracker-integration.md` | tracker-integrated skills (comment bus, labels, lease, provider ops, MR ownership) |
| `lanes.md` | lane-based dispatch consumers |
| `mission-brief-template.md` | brief/milestone authors (queue, orchestrator) — canonical home `mission-brief/references/` |
| `issues-provider.yml` | provider resolution template (setup writes the repo copy) |
| `run-context.md` | run-mode vs local-session rules |
| `project-contract.md` | consumer projects — what their `REVIEW.md`, `AGENTS.md`, skills and workflow override may and may not change in a factory run |
| `mission-template.yml` | run policy defaults (execution, supervision, budgets) |
