---
name: architect-boot
description: Use when architecture work starts or a tech-stack or pattern decision emerges — injects the project ADR index (docs/adlc/memory/adr/, legacy .adlc/memory/adr/ fallback) as session context and pairs the decision with capture via /architect-specify; invoked from team-boot's Class Boots catalog.
---

# architect-boot

## Overview

One of the five **class boots** surfaced by `team-boot`'s Class Boots
catalog. `team-boot` injects the always-relevant team context (constitution,
CDR index, skills registry) at session start; this skill loads the
**architecture decision layer** on demand — the Accepted ADR index from
project memory — and pairs it with decision capture so new architecture
choices are recorded (`/architect-specify`) rather than evaporating.

Reading decisions and recording decisions are one loop: existing ADRs
inform the work; decisions made during the work flow back into the same
record system.

## When to Use

Invoke at the START of a matching task — before planning the todo list and
before implementation — so the ADR context informs planning.
Never defer to session end.

Invoke when:

- Starting architecture work (system design, `AD.md` generation,
  cross-subsystem refactoring, dependency changes).
- The session turns architectural mid-flight: a tech-stack choice, pattern
  selection, or "we chose X over Y" moment emerges.
- Reviewing or validating an architecture and you need the decision
  backdrop.

For **technology selection**, also invoke `tech-radar-boot` — radar context
should inform the ADR.

## Core Process

### Step 1: Locate the ADR Index

From the current working directory (do NOT walk up parent directories):

1. Primary: `docs/adlc/memory/adr/adr.md` (generated `/architect-implement`;
   rows start `| ADR`)
2. Fallback: `.adlc/memory/adr/adr.md` (legacy layout, pre-ADR-401)

If neither exists but `docs/adlc/memory/adr/ADR-*.md` or legacy
`.adlc/memory/adr/ADR-*.md` files do, synthesize a
lean table from each file (ID from filename; Sub-System/Decision/Status
from frontmatter or first heading). If the directory is empty or absent,
report `0 ADRs` — never fabricate rows.

When no local memory index exists in the current working directory and the
directory sits inside a workspace (detected via a `.gitmodules` marker in an
ancestor), read the workspace root's `docs/adlc/memory/` index instead
(ADR-401 dual-read order applies: `docs/adlc/memory` first, legacy
`.adlc/memory` fallback).

### Step 1b: Read the ADR Drafts Index

Check `.adlc/drafts/adr/` for `ADR-*.md` files with `status: proposed` in
frontmatter. These are draft ADRs pending clarification. Collect ID /
Title / Type / Status / Date from each file. If the directory is empty or
absent, report `0 pending drafts`.

## Absent Context

If `team-boot` injected no team context this session (no Team Context & Decisions section in the first user message — unconfigured project or hook failure): say so in one line, emit the section heading with a `0 ADRs matched (no team context injected — run /team-setup)` source line, and continue the task on the directly-read ADR index. Never treat a missing injection as an empty record set. Recovery: run `/team-diagnose`.

### Step 2: Inject ADR Context (Output Contract)

Emit before the task answer:

```markdown
## ADR Context

| ID | Sub-System | Decision | Status |
|--|--|--|--|
| ADR-325 | lanes | Workflow lanes over flat queue | Accepted |

_Searched N ADRs, K matched._

## Drafts Pending Review

| ID | Title | Type | Status | Date |
|----|-------|------|--------|------|
| (from .adlc/drafts/adr/) |

_N pending drafts — run /architect-clarify to review._
```

- Render ID / Sub-System / Decision / Status from the index (the full index
  also carries Date, Decision Makers, File — read the individual `ADR-*.md`
  when a task matches a row).
- `N` = total index rows; `K` = rows relevant to the current task. **K MUST
  equal the table rows shown.** 0 rows matched → emit the section heading +
  the `_Searched N ADRs, K matched._` line only — no table. A 0-row table
  header collapses into unrendered single-line markdown; never emit one.
  Emit the section as markdown blocks — heading, table rows, and counts line
  each on their own lines.

### Step 3: Capture Architecture Decisions

| Trigger | Action |
|---------|--------|
| Tech stack choice, "we chose X over Y" | ADR → direct write to `.adlc/drafts/adr/` (pull `tech-radar-boot` context first) |
| Pattern selection, structural refactor | ADR → direct write to `.adlc/drafts/adr/` |
| ADR-class decision already in the ledger | verify capture happened; if not, re-surface |

Add/refresh rows in **Team Context & Decisions** (ID | Name | Type | Rel |
Status | Clarify) for every ADR-class decision detected this session —
including ones from before this boot was invoked. Mirror each decision as a
task-list todo (draft → `/architect-clarify` at session end); after
code-modifying tasks, add a trailing todo to sweep Team Context & Decisions until
_Unrecorded: 0 pending · Unclarified: 0 drafts_ (a draft leaves Unclarified
only via its clarify skill or an explicit user handoff to a named clarify or execute skill). At session end,
deliver the clarify prompt naming each captured ADR draft in
`.adlc/drafts/adr/` (ID + skill); if the user defers clarify, mark those
rows handed off.

## Failure Handling

- Missing index + missing records → emit the section heading +
  `_Searched 0 ADRs, 0 matched._` only — no table — and continue the user's
  task; never block.
- Unparseable index rows → skip malformed rows, note the skip count.

## Red Flags

- Fabricating ADR rows or inflating K beyond the table shown.
- Injecting the index but ignoring capture — the pairing is the point.
- Walking up parent directories to find `.adlc/`.
- Tech-selection ADRs recorded without radar context when the radar is
  available.

## Verification

- [ ] ADR Context table emitted with `_Searched N ADRs, K matched._`
      (K = table rows).
- [ ] Detected ADR-class decisions added as Team Context & Decisions rows.
- [ ] Tech-selection decisions routed through `tech-radar-boot` →
      `/architect-specify`.
