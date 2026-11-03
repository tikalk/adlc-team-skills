---
name: factory-runbook
description: Use when a factory run must post its changes — check out the run branch, commit a step's allowlisted paths, push only that branch, and open or reuse one draft MR/PR with milestone/assignee ownership. Also the shared home for factory run contracts (executor, tracker integration, lanes, brief and provider templates).
---

# factory-runbook

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
(and usually `ADLC_ISSUE_REF` plus `ADLC_STEP_OUTPUT`) from a factory run, or
explicit orchestrator-provided args (orchestrator name, step id, output type,
paths). Never invent a branch name, a step, or paths to commit. Without a run
context and without them, state what is missing and stop.

---

## Publish procedure — read this first

**Requires:** nothing — this skill is self-contained. (Borrowers declare the
reverse: `adlc-cli skills add tikalk/adlc-team-skills --skill factory-runbook`.)

1. **Start:** `bash {REPO_ROOT}/.agents/skills/factory-runbook/scripts/bash/run-branch.sh [--kind <intent|code>]`
   — on Windows, the PowerShell twin (every helper has one under
   `scripts/powershell/`). Checks out the run branch (`factory/intent/<repo>-<iid>`
   from `ADLC_ISSUE_REF` for intent runs — the default; `factory/mission/<repo>-<iid>`
   with `--kind code` for mission code runs) in the project root, reusing it
   or continuing from `origin`. Shared by both intent lanes and with
   re-dispatches. Without `ADLC_RUN_ID` this is a no-op.
2. Run the lifecycle steps. After **each** step that changed files:
   `bash {REPO_ROOT}/.agents/skills/factory-runbook/scripts/bash/commit-step.sh --orchestrator <name> --step <id> --output-type
   <draft|decision|artifact-ref|findings> --summary "<one line, no issue text>"
   --records <IDs> -- <paths the step wrote, moved or deleted>`. Stages ONLY
   allowlisted paths; prints `sha: <sha>` or `sha: none` for the
   step's bus marker.
3. **Before returning, always:** `bash {REPO_ROOT}/.agents/skills/factory-runbook/scripts/bash/open-mr.sh [--kind <intent|code>]` —
   pushes the run branch only, finds or opens one draft MR (merge commit, no
   squash; Issue milestone applied inline, Issue assignees else the
   runner's own account, per `tracker-integration.md` Operation 11; the
   deterministic resolver `{REPO_ROOT}/.agents/skills/factory-runbook/scripts/bash/resolve-mr-ownership.sh`
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
without `ADLC_RUN_ID`.

Only an orchestrator-invoked runbook commits, pushes and opens the MR, and
only through these helpers; lifecycle skills never do.

---

## The factory workflow (`workflow.yml`)

This skill ships the factory outer loop: `workflow.yml` (`id: factory`),
intent → `gate-product` → `gate-architecture` → `execute` →
`gate-completion` → `sweep`. It lives here, next to the helpers its shell
steps call, so a helper move or a renamed orchestrator changes the workflow
in the same change.

- **Run it by path, from where the skill is installed:**
  `adlc-cli workflow run <skills dir>/factory-runbook/workflow.yml --input issue_ref=<ref> --input dispatch=<mode>`.
  The skills dir depends on the agent (`.agents/skills` for opencode,
  `.claude/skills` for Claude Code, and so on). An agent runner sets
  `WORKFLOW_SOURCE` to that path. `workflow run factory` still resolves to
  the CLI's bundled copy, so until shipped workflows are installed into
  `.adlc/workflows/<id>/`, this file runs only when given by path.
- **Needs adlc-cli newer than 2.7.0** (gate `context.since: run_start`,
  tikalk/adlc-cli#69): `gate-architecture` follows the one `factory-intent`
  step, which writes the ADRs before `gate-product` is approved.
- **Shell steps** find the helpers through `ADLC_WORKFLOW_DIR`, which the
  engine sets to this file's directory and keeps on resume, so they work in
  any install layout. `scripts/bash/run-helpers.sh <label> <helper.sh>…`
  (PowerShell twin `run-helpers.ps1`) runs them; a missing helper **fails**
  the step, never "skipped": a run that pushed nothing must not report
  success. **Copying this file** (e.g. an installer placing it under
  `.adlc/workflows/factory/`) must copy the whole skill directory with it,
  or point at it, or the shell steps cannot find `scripts/`.
- `run-branch-architecture` checks out the run branch again after
  `gate-product`: a parked run can resume in a fresh clone on the base
  branch, and `gate-architecture` diffs the working tree.
- `tests/unit/test_factory_workflow_contract.py` checks every shipped
  workflow: each `command:` is a skill in this repo, each helper a shell step
  names exists, the factory layout, and that the factory's intent gates
  match `factory-intent`'s own.

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
| `mission-template.yml` | run policy defaults (execution, supervision, budgets) |
