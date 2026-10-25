# Factory Workflow Executor Engine (Shared Contract)

## Overview

This is the canonical executor contract for all Kind-A factory orchestrators (`factory-mission`, `factory-product`, `factory-architect`, `factory-learn`, `factory-init`). It defines how to compile a feature or lifecycle task into a structured step list, execute steps sequentially with state tracking, handle supervision gates, and run correction loops.

## Shared Run State (shared run state — read this first)

The executor is the **LLM interpreter** of a dual-executor architecture. It shares one program (`workflow.yml`) and one program counter (`state.json`) with the CLI engine (`adlc-cli workflow`):

1. **One program counter.** All step progress lives in `.adlc/workflows/runs/<run_id>/state.json`. The executor NEVER hand-writes that file — every mutation goes through the librarian helpers:
   ```
   adlc-cli workflow state start   --workflow <id|path> [--run-id <id>] [--input k=v]
   adlc-cli workflow state advance <run_id> --step <id> --status completed|failed \
        [--output-file <path> | --output-json <json>] [--error <msg>]
   adlc-cli workflow state pause   <run_id> --step <id>
   adlc-cli workflow state fail    <run_id> --error <msg>"
   adlc-cli workflow state show    <run_id>
   ```
2. **Step boundaries only.** State advances only at completed-step boundaries — never mid-step. This is what lets the CLI engine resume any run the executor parks, and vice versa.
3. **Strict lease.** Every state-writing session acquires the lease first (`state start/advance` fold this in). Set `ADLC_WORKFLOW_SESSION=<session-id>` once per executor session — the lease then persists across sequential helper invocations and blocks concurrent writers. `state pause`/`state fail`/terminal advance release it: the run becomes claimable by any executor (exit-and-resume handoff).
4. **Gates.** In-session, a gate is an inline human Q&A: `state pause <run_id> --step <gate_id>` → ask the human → `state advance <run_id> --step <gate_id> --status completed --output-json '{"choice":"<answer>"}'`. Headless (CI) the same gate is engine-PAUSED + `verdict_input`; the human's answer arrives as `resume --input verdict=<choice>`.
5. **Frozen vs live policy (the executor difference).** This executor re-reads `runs/<run_id>/mission.yml` live on resume — operators may adjust budgets/supervision mid-run. The CLI engine executes the frozen `workflow.yml` copy deterministically.
6. **Run context home.** Everything the run needs lives in `runs/<run_id>/`: `brief.md`, `mission.yml` (policy), `scratchpads/`, `findings/`, `decisions/`, `artifacts/`, `iterations.md`. Cross-run memory is global: `.adlc/workflows/memory.jsonl`. There is no `.adlc/workflow/` directory anymore.

The execution loop below is annotated with the helper calls at each write point.

When tracker-integrated, step terminal outputs are published to the code host's PR/MR/issue comment thread (the **comment bus**) via `factory-mission/references/tracker-integration.md` §Inter-Agent Comment Bus. The comment bus is the durable inter-agent memory — it survives session boundaries, runtime switches, and pod crashes. When not tracker-integrated, steps communicate through local files and the state file only (same-session mode).

The executor is runtime-independent: it works with any agent CLI in any session. Lanes provide optional cross-runtime dispatch — the default `agent` lane spawns a fresh session of the same CLI for maker/checker separation.

---

## Core Process

### Phase 0 — Configuration

1. Every orchestrator reads the mission policy: `mission.yml` from the run directory (`.adlc/workflows/runs/<run_id>/mission.yml`) once the run exists, or the template defaults before it starts (`mission-template.yml`, copied into the run dir by `state start`). Policy knobs — `execution`, `supervision`, budgets (`max_iterations`, `max_spec_corrections`, `circuit_breaker`, `quality_threshold`), model tiers, `tdd`, `worktree_root`, `lease_ttl`, `stall_window`, `lanes` — are unchanged from the former `workflow-config.yml`; only the home moved.
2. Supervision default is `gated` (or `hybrid` for lifecycle runs, meaning gates only at `clarify`⭐ and merge sign-off).
3. Verify target lifecycle/compliance skills are installed (check `.agents/skills/` directory). Stop if missing.
4. If `--issue <ref>` is specified: resolve tracker provider, discover MCP/CLI tools, verify the target PR/MR/issue is accessible (`tracker-integration.md` §1-2). The comment bus is active for this run.

### Phase 0.5 — Workspace Isolation & Atomic Git Ref Lock

1. Derive the run id (`<orchestrator>-<target-slug>`; append `-2`, `-3`… if taken under `.adlc/workflows/runs/`), then the worktree path: `<worktree_root>/<run_id>/` (run_id-prefixed — the registry link is mechanical, the workflow namespace). Default `worktree_root` is `.adlc/worktrees`.
2. If worktree exists (resume): reuse it. Never remove or reset it. Inspect status and commits; if it holds work, confirm before continuing.
3. If worktree doesn't exist: `git worktree add <path> -b <branch> <remote>/<base-branch>`. Branch named per project convention or `factory/<orchestrator>/<target-slug>`.
4. **Atomic Git Ref Lock**: To eliminate race conditions where two machines read the tracker concurrently, the claiming machine pushes an atomic lock ref: `git push origin HEAD:refs/heads/factory/locks/<orchestrator>-<target-slug>`. If the ref already exists, the Git server rejects the push; the runner immediately halts before making code changes or running LLM steps.
5. **Committer Identity Validation**: Confirm a committer identity resolves in the worktree (`git -C <path> var GIT_COMMITTER_IDENT`) before the first commit. If none resolves, the orchestrator must halt and report the missing capability. An unattended runner cannot invent or borrow an identity (never author commits using a reviewer's, assignee's, or pushing login's identity). Authorized identities must be applied worktree-locally, disclosed, never globally.
6. **Authorship Preservation**: Verify that any git operation preserves historical authorship. A rebase, cherry-pick, or amend over someone else's commit must keep that commit's original author; never `--reset-author` or `--amend --author="..."` across it. Pushing is restricted to the target's own head branch, and force-push requires `--force-with-lease` for the exact previously observed remote SHA.
7. Never `checkout`, `switch`, `reset`, `clean`, or `stash` in the user's main checkout. Work only in the run's worktree via absolute paths.
8. Register worktree path and validated git identity in state file and brief.

### Phase 0.7 — Lane & Context Parameter Resolution

1. If `lanes` section exists in the mission policy (`mission.yml`):
   a. Match this runtime's label against `runtimes[].match` (case-insensitive substring).
   b. For each step, resolve its lane: `inline` (this session), `agent` (fresh session of same CLI), or `cli:<runtime>` (spawn another runtime's CLI).
   c. Verify each `cli` lane's command executable exists. If missing, degrade to `agent` on this runtime and disclose lost independence.
   d. Record resolved lane per step in state file and brief.
2. If `lanes` section is absent: interactive stages run `inline`, unattended stages run `agent` (fresh session of same CLI). This is the default — backward compatible.
3. **Context Parameter Resolution**: Resolve all `{{params.<key>}}` references in the brief and step instructions by looking from most specific to least specific: `agent < workflow < repository < project < default`. A referenced key with no value and no default stops the run at preparation.
4. Disclose the resolved lane plan and context parameters to the user before execution.

### Phase 1 — Two-Tier Resume & Lock Check (`--resume`)

1. **Tier 1 (Shared-State Check — any machine, any executor)**:
   - `adlc-cli workflow state show <run_id>` — the shared program counter (`.adlc/workflows/runs/<run_id>/state.json`).
   - The strict lease (`runs/<run_id>/lease.json`, shared run state) replaces the old local state-file heartbeat: if a live lease is held by another session → HALT & REFUSE (the helper errors with the holder). Expired/absent → claim and continue.

2. **Tier 2 (Remote Distributed Check - Cross-Machine)**:
   - If tracker-integrated: execute `tracker-integration.md` §Operation 10 (`Acquire Remote Lease`).
   - If `acquired == false`:
     - **HALT & REFUSE**: "Ticket is actively locked by host `<holder>` (run `<run_id>`). Halting to prevent cross-machine collision."
   - If `mode == "takeover"`:
     - Log: "Adopting stale remote lease from host `<holder>`."
     - Read all marker comments from the PR/MR/issue via `tracker-integration.md` §5 (Read Step Outputs). Marker comments are the source of truth across machines.
     - Reconstruct completed step outputs from marker comments.
     - Fetch existing remote branch and resume in an isolated worktree.
   - If `mode == "fresh"`:
     - Free to claim; proceed to Phase 2.

3. **Read the brief**: if `runs/<run_id>/brief.md` exists, read it to restore full run context (goal, constraints, success criteria, run ID, route, supervision, target, worktree, step inputs).
4. If state is empty and no marker comments exist: start fresh.
5. If marker comments exist with incomplete steps: load outputs, skip to the first pending step (`state show` → `current_step_index`), passing the previous step's findings as input.
6. Completed runs need no archiving — the run directory **is** the archive (`status: completed` persists; git-refs `refs/factory-runs/<run_id>` is the transport, git-refs run state). Marker comments remain on the PR/MR/issue as a permanent audit trail.

### Phase 2 — Brief Construction

Before executing, compile the input into a structured Brief contract:
- **Goal**: One-sentence core objective.
- **Constraints**: Environment, tech stack, and non-goals.
- **Success Criteria**: Measurable binary verification outcomes.

Presented to the user for sign-off (in gated/hybrid modes).

**Persist the brief to `runs/<run_id>/brief.md`** as a `draft` (not published to the comment bus). The brief contains:

```markdown
# Factory Run Brief: <orchestrator>

## Goal
<one-sentence core objective>

## Constraints
<environment, tech stack, non-goals>

## Success Criteria
<measurable binary verification outcomes>

## Run Context
- **Run ID:** <run_id>
- **Orchestrator:** <factory-mission | factory-product | ...>
- **Route:** <greenfield | brownfield | refresh>
- **Supervision:** <gated | hybrid | autonomous>
- **Target:** <owner>/<repo>#<number> (if tracker-integrated)
- **Worktree:** <worktree path>
- **Lanes:** <resolved lane plan, if configured>

## Step Inputs
<list of reads_from entries — what each step should read and where>
```

A resumed run reads the brief from disk. A `cli:` lane worker reads the brief from disk. The dispatch instruction tells the subagent: "Read `.adlc/workflows/runs/<run_id>/brief.md` for full context."

**Emit the workflow definition (the plan of record).** In the same phase, compile the step list (Phase 4 schema) into a `workflow.yml` and start the shared run:

1. Write the compiled definition to `.adlc/workflows/<run_id>/workflow.yml` (generated-by-slug home, the workflow namespace) — steps as `command`/`prompt` entries carrying the step's skill + prompt, supervision gates as `gate` steps with `verdict_input`, correction loops as `do-while` with `max_iterations` from mission budgets, models from tiers.
2. Validate: `adlc-cli workflow validate <run_id>` — a failed validation is a Phase 2 defect; fix the definition, never skip the gate.
3. Create the shared run: `adlc-cli workflow state start --workflow <run_id> --run-id <run_id> --input …` (lease acquired; frozen copy + mission.yml land in the run dir).
4. The emitted file is dual-executor (shared run state): CI can run the identical loop headless later; drift between prose and program is impossible because both consume one file.

### Phase 3 — Route Classification

Classify into routes based on workspace state (or `--route` override):
- `greenfield` (specify/new)
- `brownfield` (init/exist)
- `refresh` (analyze/drift correction)

### Phase 4 — Step List Generation

Generate an ordered list of steps using the orchestrator's specific DAG. The list is *also* the compiled `workflow.yml` emitted in Phase 2 — keep the two synchronized by construction (generate once, render twice).

Step schema:

```json
{
  "id": "step_id",
  "phase_type": "generate | clarify | build | verify | analyze",
  "tier": "strong | fast",
  "skill": "exact-skill-name | routed",
  "prompt": "Instruction text",
  "status": "pending | completed",
  "lane": "inline | agent | cli:<runtime>",
  "output_type": "draft | decision | findings | artifact-ref",
  "output_path": "local path for draft/artifact-ref outputs",
  "output_marker": "factory-<orchestrator>:step=<step_id>:run=<run_id>",
  "reads_from": [
    "factory-<orchestrator>:step=<prev_step_id>:run=<run_id>",
    ".adlc/drafts/pdr/"
  ]
}
```

The lease lives in `runs/<run_id>/lease.json` (holder/heartbeat/ttl — written by the `state` helpers, renewed on every `advance`), replacing the old in-state `run_lease` block. Worktree path, git identity, route, and supervision are recorded in the brief (they are run context, not step progress).

`reads_from` entries are either:
- Marker strings → fetch from comment bus (for `decision`/`findings`/`artifact-ref` outputs)
- Local paths → read from disk (for `draft` outputs)

Mirror steps to a `todowrite` tracking list.

**Output type per orchestrator** (defaults — orchestrators may override):

| Step | factory-product | factory-mission | factory-architect | factory-learn |
|------|-----------------|-----------------|-------------------|---------------|
| specify/init | draft | draft | draft | draft |
| clarify⭐ | decision | decision | decision | decision |
| implement/build | artifact-ref | artifact-ref | artifact-ref | artifact-ref |
| analyze/verify | findings | findings | findings | findings |
| converge | — | decision | — | — |

### Phase 5 — Step Execution Loop

For each step:

1. **Read input.** Before dispatching, resolve `reads_from`:
   - For marker entries: fetch from the PR/MR/issue via `tracker-integration.md` §5 (Read Step Outputs). Include the previous step's terminal output in the subagent's instruction.
   - For local path entries: read files from disk. Include content or path reference in the subagent's instruction.
   - If `reads_from` is empty: the step starts from scratch (read `runs/<run_id>/brief.md` for Brief context).

2. **Lease renewal before dispatch**: `adlc-cli workflow state show <run_id>` (or any helper call) renews the lease heartbeat. For steps expected to exceed half the lease TTL (long builds, tests, deep analysis), the step must be executed under a process-level heartbeat wrapper (e.g., `run_lock.sh with` equivalent) that refreshes the lease on a timer for the lifetime of the child and stops when the child exits.
   - **FD Leak Prevention**: To prevent the heartbeat process from inheriting the child's or parent's open file descriptors (which holds write pipes open and causes CI/CD shells to hang indefinitely waiting for EOF), all stdout/stderr for the heartbeat process must be explicitly redirected (e.g. to `/dev/null` or log files) inside the wrapped command. Never pipe the heartbeat wrapper process itself directly into a consumer that waits for EOF.

3. **Dispatch to a subagent** using the step's resolved lane:
   - `inline`: follow the step's skill in this session (interactive stages — clarify, specify).
   - `agent`: spawn a fresh session of the same CLI (e.g., `opencode -p "<instruction>"`) with the brief path, reads_from inputs, and skill instruction. Fresh context — no memory of previous steps.
   - `cli:<runtime>`: spawn the other runtime's CLI as a child process. Write step instruction + brief + reads_from inputs to a temp file. The CLI reads it from stdin. Wait for exit. Parse output.
    - The subagent has access to **Scratchpad Tools**: `write_scratchpad`, `append_scratchpad`, `read_scratchpad`, `list_scratchpads`. Scratchpads are stored in `runs/<run_id>/scratchpads/<name>.txt` and persist across steps within the run.
    - The subagent also has access to **Workflow Memory**: `read_memory`, `write_memory`. Memories are stored in `.adlc/workflows/memory.jsonl` (workspace-global) and persist across runs of the same workflow.
   - Exactly one agent is live at a time. Never dispatch a second step while one is running.
   - A `cli:` lane that fails to launch (command missing, runtime refuses) degrades to `agent` on this runtime. Disclose the degradation and record it in state file.
   - The dispatch instruction includes: "Read `.adlc/workflows/runs/<run_id>/brief.md` for full context. The Brief is your specification — do not ask the user to repeat it. Read `.adlc/workflows/memory.jsonl` for past run lessons."

4. If `phase_type` is `verify`: prepend independent verification instructions (maker/checker separation). The reviewer/verifier must review against an **exact revision**: record the `(head SHA, base SHA, merge base)` tuple. If the revision moves during the step, discard the output and re-run against the new revision.

5. If subagent returns `NEEDS_CORRECTION` or `analyze`/`verify` reports CRITICAL/HIGH errors: route back to the preceding `clarify`⭐ step (bounded by `max_corrections`, default 2). The analyze findings (already published as `output_type: findings`) are passed to clarify via `reads_from` marker.

6. **Confidence Escalation Gate**: If subagent reports `Confidence score: LOW`, auto-escalate supervision to `gated` and halt for human confirmation.

7. **Publish step output.** On step completion, check the step's `output_type`:

   a. If `output_type` is `draft`:
   - Persist output to `output_path` on local disk.
   - Do NOT publish to the comment bus.
   - `adlc-cli workflow state advance <run_id> --step <step_id> --status completed` (records the result, advances the shared counter, renews the lease).
   - Discard full subagent response from session context.

   b. If `output_type` is `decision`:
   - Publish a comment to the PR/MR/issue with the step's `output_marker` via `tracker-integration.md` §4 (Post Step Output). Content: accepted/rejected list with one-line reasons.
   - If not tracker-integrated: persist to `runs/<run_id>/decisions/<step_id>.md` as local fallback.
   - `adlc-cli workflow state advance <run_id> --step <step_id> --status completed`.
   - Discard full subagent response from session context.

   c. If `output_type` is `findings`:
   - Publish a comment to the PR/MR/issue with the step's `output_marker` via `tracker-integration.md` §4 (Post Step Output). Content: severity-ranked actionable report.
   - If not tracker-integrated: persist to `runs/<run_id>/findings/<step_id>.md` as local fallback.
   - `adlc-cli workflow state advance <run_id> --step <step_id> --status completed`.
   - Discard full subagent response from session context.

   d. If `output_type` is `artifact-ref`:
   - Publish a comment to the PR/MR/issue with the step's `output_marker` via `tracker-integration.md` §4 (Post Step Output). Content: path/URL + one-line summary, NOT full artifact content.
   - The artifact itself lives on disk at `output_path`.
   - If not tracker-integrated: record path in the step's `--output-json '{"path": …}'`.
   - `adlc-cli workflow state advance <run_id> --step <step_id> --status completed`.
   - Discard full subagent response from session context.

8. **The full subagent response is discarded from session context.** Terminal output is now durable — on the comment bus (if tracker-integrated) or on local disk (if not). Session context is freed for the next step.

### §5.5 — Stall Detection

After dispatching a subagent, check for observable progress when nothing has advanced for `stall_window` seconds (default 1200 = 20 min).

**What counts as progress** (checked in order):
1. Did the step publish any marker comment? (comment bus — `tracker-integration.md` §5)
2. Did any local file change? (`output_path` files, `.adlc/` artifacts, `brief.md`)
3. Is the subagent process still alive? (if PID tracked in lease)
4. Any new commits/comments/checks on the target? (via `tracker-integration.md` §6)

**Decision**:
- Evidence of work → extend by one window (max 2 extensions per step)
- Alive but nothing to show across 2 consecutive windows → kill the subagent, respawn the step (counts as one abnormal end; second consecutive abnormal end halts the run)
- Subagent published a question/blocker → it is blocked on the user, not stuck. Relay the question and pause. Stop applying the window.
- Neither evidence nor process → treat as dead, respawn once

A window is not a deadline on the work. It only asks whether the work is still happening. The run has no time budget.

### §5.6 — Autonomous Decision Recording

When supervision is `autonomous` and a step would have asked the user a question (clarification, approval, authorization, blocker):

1. The orchestrator answers the question using the decision basis hierarchy (see `tracker-integration.md` §Operation 8).
2. Before the next step uses the answer, post the decision as a comment on the PR/MR/issue via `tracker-integration.md` §8 (Post Decision).
3. The answer goes into the next step's `reads_from` — both as a marker comment (durable) and in the brief (session context).
4. Decisions are numbered across the run (`k` increments).
5. If the same non-convergence condition trips again after an autonomous decision, stop the run with the state and reasoning posted. Further unattended cycles would be thrashing.

Under `gated` or `hybrid` supervision, this section does not apply — questions are relayed to the human and the run pauses.

### Correction loop

When `analyze`/`verify` reports CRITICAL/HIGH errors:
1. The findings are already published as a comment (`output_type: findings`) or on local disk.
2. Route back to `clarify`⭐ with `reads_from` set to the analyze marker (or local findings path if not tracker-integrated).
3. `clarify` reads the findings as input, addresses them, and publishes its own decision.
4. Route forward to `implement` with `reads_from` set to the clarify marker.
5. Bounded by `max_corrections` (default 2); if exceeded, halt for human review.

### Phase 6 — Completion & Publish

On successful convergence of all steps:

1. If tracker-integrated: read all marker comments from the PR/MR/issue to compile the audit trail (decisions per step, findings, artifact references, convergence history, autonomous decisions if applicable).
2. If not tracker-integrated: read from state file and local disk.
3. Route to the specified **Publish Target**:
   - `local`: Write to `.adlc/` and project root.
   - `external-repo`: Open a PR on the `team-ai-directives` repository (used by `factory-learn`).
   - `tracker`: Post a completion summary comment on the PR/MR/issue with the final audit trail.
4. **Draft MR/PR ownership (the MR-ownership decision)**: whenever the publish target opens or reuses a draft MR/PR, that MR must arrive owned and tracked — it carries the Issue's milestone and a named assignee. Apply `tracker-integration.md` §Operation 11: resolve the propagation with the resolver twins (`scripts/bash/resolve-mr-ownership.sh` / `scripts/powershell/resolve-mr-ownership.ps1`), then create or reuse the MR and set the resolved fields. Preserve-only (never overwrite a field a human set), silent skip when the Issue has no milestone, block the run with an actionable error when a read/write scope is missing. Never guess a milestone or an assignee.
5. No archiving move — the run directory (`.adlc/workflows/runs/<run_id>/`) is the durable archive; git-refs Tier-3 transports it. The final `state advance` (last step, completed) closes the run and releases the lease. Marker comments on the PR/MR/issue remain as a permanent, human-visible audit trail.
6. Print the audit trail.

### Phase 6.5 — Worktree Cleanup & Lease Release

1. Determine whether removal is safe:
   - No uncommitted or untracked changes
   - No commits absent from remote branch
   - No rebase/merge/cherry-pick/bisect in progress
2. Safe → remove worktree (`git worktree remove <path>`), keep the branch.
3. Not safe → retain worktree, report path and what it holds, mark state file `retained`.
4. **Remote Lease Release**: If tracker-integrated, post the release marker (`status=released`) via `tracker-integration.md` §Operation 10 to instantly unlock the ticket across all machines. Delete the atomic Git lock ref (`refs/heads/factory/locks/...`) from the remote repository.
5. Run on every exit path — success, failure, user stop.
