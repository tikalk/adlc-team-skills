# Decision Memory — Where ADRs/PDRs Live

This repository keeps **no ADR/PDR memory of its own**. Decision records for
this project live exclusively in the parent workspace:

- **Workspace memory**: `docs/adlc/memory/` in `adlc-workspace`
  (`adr/` for architecture decisions, `pdr/` for product decisions)

Policy: **workspace-centralized decision memory**. Rationale: per-submodule
memories produced colliding ID sequences (this repo's legacy `.adlc/memory/`
records duplicated different decisions than the workspace's same-numbered
records) and format drift. `.adlc/` is gitignored here — any records created
under it exist only on local disk and will not be reviewed or merged.

## Why this repo cites no record IDs

A shipped skill that names a record id points at a file it does not own, at an
id that can move under it (a workspace record was renumbered while a branch
here was open), and at a decision whose id a reader cannot resolve in this
repository. So the shipped skills name the **decision** in prose and never by
id; `tests/unit/test_no_record_id_citations.py` pins that rule, with the
local-example namespace (the ids the skills use for records they create
themselves) as the only exception.

The same rule applies to this file: the record IDs of the pre-centralization
migration are gone, and the migration outcome is recorded below in words.

## The pre-centralization migration (outcome)

The 18 ADRs + 14 PDRs formerly kept under `.adlc/memory/` were migrated to
the workspace. All duplicates were verified semantically (decision-statement
spot-check) before removal.

| Former records | Outcome |
|--|--|
| stateless queue, label gate, comment bus, worker brief, worktree isolation, lease TTL, stall detection, exact-head review, lanes, runtime independence | Relocated to the workspace catalogue — same decisions, different numbers |
| authorship preservation and 7 sibling execution-harness decisions | Same decisions, same numbers |
| planning mode, cleanup bot | Duplicates — the workspace already carried them |
| 9 product decisions (triage and siblings) | Duplicates of the workspace's records |
| findings→directives | Subsumed (twice-mistake class) |
| agent-authored stamp | Unique — imported into the workspace under a new id |
| deck↔code terminology | Unique — imported into the workspace under a new id |

## Working with decisions

- **Reading**: class boots resolve memory from the current working directory and
  fall back to the workspace root (detected via `.gitmodules`) when no local
  memory exists.
- **Writing**: class boots only suggest the capture skill; running it drafts
  the decision to the **workspace root** `.adlc/drafts/` and promotes to
  workspace `docs/adlc/memory/` — never under this repo's
  `.adlc/`.
