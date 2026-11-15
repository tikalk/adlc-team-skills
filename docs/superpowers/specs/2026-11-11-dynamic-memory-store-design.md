# Design: Dynamic per-working-directory decision-record store

Date: 2026-11-11
Status: draft (awaiting human approval)
Scope repo: `adlc-team-skills` (skill sources; installed into consumers via `.agents/skills/`)

## Intent and why

ADR-412 centralized all decision records (ADR/PDR/ChDR) in the workspace
repo's `docs/adlc/memory/`. That works while every repo is worked on inside
the workspace, but a repo that gets cloned and worked on standalone leaves
its records behind: the standalone session can neither read nor write the
repo's decision history.

The goal: let a repo carry its own decision-record store, with the working
directory alone deciding which store a session uses. No config keys, no
merge machinery — presence of the store is the opt-in.

## Current state (verified 2026-11-11)

- Every family's `setup-*.sh` resolves `PROJECT_ROOT`/`REPO_ROOT` as the
  **nearest ancestor of `pwd` containing `.adlc/`**, and hangs both drafts
  (`$PROJECT_ROOT/.adlc/drafts/<family>`) and published records
  (`$PROJECT_ROOT/docs/adlc/memory/<family>`) off it.
  (`skills/change/change-specify/scripts/bash/setup-change-specify.sh`,
  `skills/change/change-clarify/scripts/bash/setup-change-clarify.sh`,
  `skills/architect/architect-clarify/scripts/bash/setup-architect.sh`, …)
- Boot prose (`architect-boot`, `product-boot`, `change-boot`, `team-boot`)
  reads differently: CWD's memory index first, then — when inside a
  workspace (`.gitmodules` ancestor) — the **workspace root** index as
  fallback, with an explicit "do NOT walk up parent directories" red flag.
- Net effect today is split-brain for a repo that has `.adlc/` but no
  memory store: `adlc-argo-wf` has `.adlc/` (`init-options.json`,
  `workflows/factory/workflow.yml`), so scripts would already write its
  records repo-local, while boots read from the workspace. Repos without
  `.adlc/` read+write the workspace (the ADR-412 default).
- Evidence of past centralization: argo-wf's old ADR-438/439 were migrated
  into the workspace store as ADR-502/503.

## Goals

1. One explicit store-resolution rule shared by read paths (boots, analyze,
   governance loads) and write paths (specify → drafts, clarify/implement/
   publish → records), driven only by the current working directory.
2. Repo-local store opt-in by **presence of decision-record family
   directories** — `adr/`, `pdr/`, or `chdr/` (or their index files)
   under `docs/adlc/memory/` or legacy `.adlc/memory/`. A memory dir
   containing only non-decision content (e.g. `adlc-cli`'s
   `.adlc/memory/evals/`) is **not** a marker and does not flip the repo.
   `.adlc/` alone is also not the signal (it carries
   `init-options.json` / `workflows/`; `adlc-argo-wf` is the
   counterexample), and there is no config key.
3. Standalone clones self-bootstrap: the first accepted record creates the
   store in the repo, with a loud notice.
4. Zero behavior change for markerless repos inside the workspace
   (ADR-412 default preserved).

## Non-goals

- No merge/federation of stores. Per working directory = exactly one store
  is read and written. Workspace-root sessions do not see a repo-mode
  repo's new records (accepted trade-off; cross-repo rollups stay manual).
- No migration of records already in the workspace store. They stay as
  history; init prints candidates so a human can move them by hand.
- No `init-options.json` schema change (the original idea; superseded by
  presence-based resolution).
- Evals family and team-levelup (CDRs live in the team-directives repo)
  are untouched.

## Anti-goals

- Silent store creation as a side effect of an unrelated task.
- A shared sourced helper script — violates the existing scope rule
  ("scripts stay skill-local"). The same resolution function is copied
  into each skill's setup script, as today.
- Breaking the honest-empty contract: absent store ≠ "no decisions exist".

## Constraints

- Boots never block on an absent store; reads are side-effect-free.
- Legacy `.adlc/memory/` remains read-compatible (dual-read).
- Store creation is loud: the skill must say what it created and that the
  directory should be committed (it is the opt-in marker and travels with
  clones).
- Bounded walk-up: resolution never climbs past the workspace root (when
  inside a workspace) or the git toplevel (when standalone).

## The design (decided)

### `resolve_memory_root()` — one algorithm, copied per setup script

1. Walk up from `pwd`: the first directory whose `docs/adlc/memory/` or
   `.adlc/memory/` contains a decision-record family (`adr/`, `pdr/`,
   `chdr/`, or their index files) is the store root.
2. Else, if a workspace root exists (nearest ancestor with `.gitmodules`
   or `.adlc/workspace.yml`): the workspace root is the store root.
3. Else (standalone): the git toplevel is the store root.

### Behavior per quadrant

| CWD repo has store marker | Workspace store exists | Store used | On first write |
|---|---|---|---|
| yes | (irrelevant) | repo | — |
| no | yes | workspace (ADR-412 default) | — |
| no | no, but inside a workspace | workspace root | create loudly at workspace root |
| no | standalone, no workspace | repo (git toplevel) | create loudly in repo → auto repo mode |

### Read paths

Boots, analyze skills, and constitution/index loads follow
`resolve_memory_root()`. If the resolved root has no store directory, they
report honestly (`_Searched 0 ADRs, 0 matched (no store found)._`) and
continue. The boot red flag "do NOT walk up parent directories" is
replaced by the bounded walk above; the workspace-fallback prose is
subsumed by step 2.

### Write paths

- Drafts: unchanged — `$PROJECT_ROOT/.adlc/drafts/<family>` where
  `PROJECT_ROOT` is the nearest `.adlc/` ancestor (working state,
  per-repo is fine).
- Record promotion (clarify/implement/publish): resolve
  `resolve_memory_root()`; if the store directory is missing, create it
  (`mkdir -p` the family subdir + index skeleton) and emit a loud notice:
  "No decision-record store found — initialized `<path>`; commit it to
  opt `<name>` into repo-scoped memory" (workspace wording when the root
  is the workspace).
- IDs are per-store sequences. A repo store numbers its own ADR-001…;
  cross-store references, when needed, name the repo explicitly.

### Init skills

`architect-init` / `product-init` / `change-init` gain (or document) the
deliberate enable step: create `docs/adlc/memory/<family>/` + index in the
current repo and say to commit it. When enabling a repo that has records
in the workspace store, print the candidate list for optional manual
moves; never move automatically.

## Scope of readers (decided)

All read paths that touch `docs/adlc/memory/` adopt `resolve_memory_root()`
in this change — not only the three families' boots/analyze/governance
loads, but also the factory skills that run inside child repos
(`factory-init`, `factory-mission`, `factory-review`, `factory-learn`) and
the team skills (`team-repair`, `team-discover`, the constitution load).
Phasing was considered and rejected: half-migrated readers would silently
miss repo-mode records exactly where repo mode is used.

## Builder calls (settled by the designer, marked for review)

- **Numbering across roots**: record ID allocation takes the max across the
  drafts root (`$PROJECT_ROOT/.adlc/drafts/<family>`) **and both** store
  roots (`docs/adlc/memory/<family>` and legacy `.adlc/memory/<family>`).
  Today's `next_*` functions skip the legacy root and would collide under
  dual-read; `tests/unit/test_ledger_slot_numbering.py` (which pins the
  current shape) is updated accordingly.
- **`team-boot/boot.sh`**: implements the same bounded walk for the
  injected ADR/PDR/ChDR/Eval scope counts (today it counts strictly
  CWD-relative, so the scope line would lie in repo-mode or subdirectory
  sessions). Pending-draft counts adopt the setup scripts' existing rule —
  nearest `.adlc/` ancestor — so counts match where specify actually
  writes drafts.

## Left to the builder

- Exact per-skill edit list across `skills/{architect,product,change}/`,
  the read-path edits in `skills/factory/{factory-init,factory-mission,factory-review,factory-learn}/`
  and `skills/team/{team-boot,team-repair,team-discover}/` (which setup
  scripts, which SKILL.md prose blocks), the three `*-boot` SKILL.mds, and
  the `AGENTS.md` template dual-read paragraph.
- Exact wording of the loud notice per skill.
- Draft/store mismatch edge: clarify scans drafts at `PROJECT_ROOT` but
  promotes into the resolved memory root — confirm the two are reported
  together so a draft is never silently promoted into a different store
  than the user expects (the loud notice covers this).
- Test additions under `adlc-team-skills/tests/` (or
  `scripts/acceptance-test.sh`) covering the four quadrants.
