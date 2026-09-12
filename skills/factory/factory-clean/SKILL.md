---
name: factory-clean
description: "Inventory what this project and its agent skills cost the machine — worktrees, containers, dependencies, and processes — then reclaim only what the user approves item by item. Read-only by default. Use when the user asks to reclaim project disk space or clean up leftovers."
---

# factory-clean

## What this skill does

`factory-clean` is the resource-reclamation engine of the software factory (deck slide 18 Maintenance stage). It answers two questions and acts on the second: **what is this project costing this machine right now**, and **what can be reclaimed without destroying work or interrupting an agent that is still running?**

It operates as a **Kind-B control-plane skill** that reads the run registry, identifies active worktrees, and cleans up discarded/stale artifacts.

---

## When to use

- After multiple parallel runs, to see which worktrees are safely removable and reclaim disk space.
- To clean up abandoned or stale locks and leases.
- To verify that no uncommitted or unpushed work is accidentally lost.

**When NOT to use**:
- For routine code development or PR review (use `factory-mission` or `factory-review`).
- To force-delete unpushed git commits or uncommitted files (this skill **never** deletes unsafe work, PDR-053).

---

## Operating Process

### 1. Project Ingestion
Determine the project in scope (defaulting to the current repository). Identify its state root, run registry, and worktree root (`.adlc/worktrees/`).

### 2. Live-Work Classification (PDR-053)
Before displaying any candidate for deletion, read the local state file and the comment bus (if tracker-integrated, ADR-330/ADR-333). Classify every resource into one of these five liveness states:

- **`in use`** — owned by a run whose lease is live (`heartbeat_ts + ttl_seconds > now`), or a path held open by an active process. **Protected.** Never offer for deletion.
- **`holds work`** — a worktree with uncommitted changes or commits not on its remote, or a registry entry marked `retained`. **Protected.** Show exactly what it holds. Never delete.
- **`stale`** — registered, lease is past its TTL, nothing is unsaved, **and** no running process holds its path or has it as a working directory. **Candidate for deletion.**
- **`orphan`** — no registry entry exists, but canonical containment plus deterministic project, skill, and run ownership labels prove this skill family created it. **Candidate for deletion.**
- **`unknown`** — ownership or liveness cannot be determined. **Protected.** Display to the user but do not offer for deletion.

*Note: Liveness classification is read from this skill family's own registry. Disclose in the report that other local processes or IDE checkouts are invisible and protected as `unknown`.*

### 3. Inventory Scope
Scan and measure the sizes/counts of:
1. **Skill Worktrees & Clones**: worktrees under `.adlc/worktrees/`, managed clones under `.adlc/clones/`.
2. **Git Artifacts**: stale worktree registrations, loose-object and pack sizes. (Local user branches and global git caches are ignored and protected).
3. **Project Dependency & Build Output**: dependency directories (`node_modules`, `.venv`), build and distribution output, coverage and test artifacts.
4. **Skill State, Scratch, & Logs**: per-run temporary directories, snapshots, and log files. (Saved identity mappings, project conventions, schemas, and configurations are always protected).
5. **Processes & Ports**: dev servers, port-forwards, and background workers holding this project's ports or files.

### 4. Report and Approval
1. Present the inventory grouped, each group sorted by reclaimable size, with a per-group and overall total. State clearly what is protected and why.
2. Ask the user to select exact candidate identifiers within each group. Default to selecting nothing.
3. Show the exact commands that will run.
4. **Re-verify liveness immediately before each deletion**: if a run started or gained unsaved work since the inventory, skip it and report the conflict.
5. Delete one item at a time, stopping at the first error rather than continuing through a broken assumption.
6. Report what was reclaimed, what was skipped, and the actual space recovered (measured again, not assumed).
