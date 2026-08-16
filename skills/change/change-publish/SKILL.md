---
name: change-publish
description: Promote accepted Change Decision Records (ChDRs) from drafts to project memory at .adlc/memory/chdr/, write OKF-style frontmatter, and regenerate the boot-facing .adlc/memory/chdr.md index that team-boot injects at session start. Use after /change-clarify has accepted ChDRs.
disable-model-invocation: true
---

# change-publish

## What this skill does

Compile **accepted ChDRs** into the project's memory layer at `{REPO_ROOT}/.adlc/memory/chdr/`:

- Validate accepted ChDRs (status + provenance on Decision claims)
- Write each promoted ChDR to `.adlc/memory/chdr/ChDR-{NNN}.md` with OKF-style frontmatter
- Regenerate `{REPO_ROOT}/.adlc/memory/chdr.md` — the **boot-facing index** that `team-boot` injects into the session-start context (same convention as `pdr.md`/`adr.md`)
- Mark source drafts `### Status: **Published**`

Unlike `/levelup-publish` (which opens a PR against team-ai-directives), `change-publish` writes **project-local memory** — ChDRs describe this repo's evolution and fail the team-wide signal gate. No PR is created; the user commits via their normal flow.

**This skill does not run until ChDRs have been accepted via `/change-clarify`.**

## When to use

- **After `/change-clarify`**: accepted ChDRs need promotion to memory
- **After re-running `/change-init`**: new accepted ChDRs to add to the memory index

### When NOT to use

- **No accepted ChDRs**: run `/change-clarify` first
- **Discovering ChDRs**: use `/change-init`
- **Reviewing ChDRs**: use `/change-clarify`

## Process

### User Input

```text
$ARGUMENTS
```

**Examples**:

- `"ChDR-001 ChDR-003"` — promote only specific ChDRs
- Empty input: promote all accepted ChDRs

### Role & Context

You are acting as a **Memory Publisher** — moving accepted ChDRs from local drafts to durable project memory. Your role:

- Validate provenance one more time (the poisoning circuit breaker — a promoted unprovenanced decision poisons every future session via team-boot)
- Write promoted records with frontmatter that `team-boot` can index
- Regenerate the `chdr.md` index so the next session start sees the new decisions

### Outline

1. **Environment Setup** (Phase 0): resolve paths, list accepted ChDRs
2. **Prerequisites Check** (Phase 1): ensure accepted ChDRs exist
3. **Provenance Validation** (Phase 2): re-verify every Decision claim has SHA/URL
4. **Duplicate Check** (Phase 3): skip ChDRs already in memory with same issue key
5. **Memory Record Generation** (Phase 4): write `.adlc/memory/chdr/ChDR-{NNN}.md`
6. **Index Regeneration** (Phase 5): rebuild `.adlc/memory/chdr.md` (boot-facing)
7. **Draft Status Update** (Phase 6): mark promoted drafts `Published`
8. **Summary** (Phase 7): report results

### Execution Steps

#### Phase 0: Environment Setup

Run:

```bash
scripts/bash/setup-change-publish.sh
```

Parse JSON for `REPO_ROOT`, `CHDR_DRAFTS_DIR`, `MEMORY_DIR`, `MEMORY_INDEX`, `ACCEPTED_CHDRS`.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up to `.adlc/`, or `git rev-parse --show-toplevel`.
2. `CHDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/chdr`
3. `MEMORY_DIR` — `REPO_ROOT/.adlc/memory/chdr`
4. `MEMORY_INDEX` — `REPO_ROOT/.adlc/memory/chdr.md` (same level as `pdr.md`/`adr.md`)
5. `ACCEPTED_CHDRS` — `grep -l '^### Status: \*\*Accepted\*\*' CHDR_DRAFTS_DIR/ChDR-*.md`

#### Phase 1: Prerequisites Check

If `ACCEPTED_CHDRS` is empty:

```text
No accepted ChDRs found.
Run /change-clarify to accept ChDRs first.
```

#### Phase 2: Provenance Validation

For each accepted ChDR, re-verify: every non-trivial sentence in `### Decision` references a SHA (`\b[0-9a-f]{7,40}\b`) or URL (`https?://`). Skip ChDRs that fail provenance — they cannot be promoted (poisoning risk):

```markdown
## Provenance Validation

**Passing**: N | **Skipped**: M

### Skipped ChDRs

| ChDR | Reason |
|---|---|
| ChDR-XXX | Decision claim lacks SHA/URL provenance |
```

Skipped ChDRs remain `Accepted` in drafts for the user to fix.

#### Phase 3: Duplicate Check

For each passing ChDR, check if a memory record already exists with the same `### Issue Links` key. If so, skip (or offer to merge) — do not create duplicates.

#### Phase 4: Memory Record Generation

For each accepted ChDR, write `{MEMORY_DIR}/ChDR-{NNN}.md`:

```markdown
---
type: ChDR
title: {title from heading}
description: {descriptor from draft}
resource: ./.adlc/memory/chdr/ChDR-{NNN}.md
tags: [chdr]
generated:
  by: agent:change-publish
  at: {today}T00:00:00Z
id: ChDR-{NNN}
created: {date from draft}
verified:
  - by: agent:change-publish
    at: {today}T00:00:00Z
status: stable
stale_after: 365d
sources:
  - id: {sha}
    resource: git:{sha}
    title: {commit subject}
  - id: {issue-key}
    resource: {issue-url}
    title: {issue title}
---

# {Title}

{Content from draft — Context, Decision, Consequences, Evidence verbatim}

## Source

Promoted from: .adlc/drafts/chdr/ChDR-{NNN}.md
```

#### Phase 5: Index Regeneration (boot-facing)

**This is the integration point with `team-boot`.** Regenerate `{MEMORY_INDEX}` (`{REPO_ROOT}/.adlc/memory/chdr.md`) by listing all `ChDR-*.md` files in `{MEMORY_DIR}` and building a markdown table whose rows start with `| ChDR-` (the awk filter `team-boot` uses):

```markdown
# Change Decision Records (Memory)

## ChDR Index

| ID | Title | Status | Date | Issues | Commits | Descriptor |
|----|-------|--------|------|--------|---------|------------|
| ChDR-001 | Why payments retries are capped at 3 | stable | 2026-08-16 | PROJ-123 | abc1234 | Consult before changing retry config |

**Stats**: N entries | Last Updated: YYYY-MM-DD
```

`team-boot`'s `boot.sh`/`boot.ps1` reads this file and emits a `## ChDR Index` section + `CHDR_COUNT` into the session-start context, alongside the PDR/ADR indexes.

#### Phase 6: Draft Status Update

For each promoted ChDR, update the draft file's status to `### Status: **Published**` and add:

```markdown
### Promotion

- **Date**: [YYYY-MM-DD]
- **Memory path**: .adlc/memory/chdr/ChDR-{NNN}.md
```

#### Phase 7: Summary

```markdown
## Change-Publish Summary

**ChDRs Promoted**: N
**ChDRs Skipped (provenance)**: M
**ChDRs Skipped (duplicate)**: K

### Artifacts

| Type | Count |
|---|---|
| Memory records (.adlc/memory/chdr/) | N |
| Boot index (.adlc/memory/chdr.md) | 1 (regenerated) |

### Next Steps

The next session start (`team-boot`) will inject the ChDR index into context.
Commit `.adlc/memory/chdr/` and `.adlc/memory/chdr.md` via your normal flow.
```

### Key Rules

#### Provenance Before Promotion

- A promoted unprovenanced Decision poisons every future session (team-boot injects it)
- Re-validate provenance at publish time, not just at clarify

#### Project-Local, Not Team-Wide

- ChDRs publish to `.adlc/memory/`, not team-ai-directives
- No PR created — user commits via normal flow
- ChDRs fail the levelup "team-wide applicability" signal gate by design

#### Index Format Must Match team-boot

- Rows MUST start with `| ChDR-` (the awk/regex filter in boot.sh/boot.ps1)
- File MUST be at `.adlc/memory/chdr.md` (same level as `pdr.md`/`adr.md`)

### Workflow Guidance & Transitions

#### After `/change-publish`

```text
/change-init → /change-clarify → /change-publish
    ↓
[team-boot] → injects .adlc/memory/chdr.md index at next session start
    ↓
[Agent consults ChDRs on demand when touching affected code]
```

Re-run `/change-init` periodically to mine new history; new accepted ChDRs are added to memory and the index is regenerated.

## Next Steps

Commit the memory directory. The next session automatically sees the ChDR index via `team-boot`.

## Verification

- All accepted ChDRs with provenance promoted to `.adlc/memory/chdr/ChDR-*.md`.
- `.adlc/memory/chdr.md` index regenerated with rows starting `| ChDR-`.
- Promoted drafts marked `### Status: **Published**`.
- No unprovenanced ChDRs were promoted.
- No duplicate issue keys in memory.

## Context

$ARGUMENTS
