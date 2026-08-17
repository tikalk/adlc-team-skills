---
name: change-clarify
description: Review, accept, reject, or defer Change Decision Records (ChDRs) discovered by change-init. Interactive one-ChDR-at-a-time workflow that validates inferred decisions against their git/issue evidence before promotion to project memory.
disable-model-invocation: true
---

# change-clarify

## What this skill does

Review pending ChDRs (status **Discovered** or **Proposed**) and decide their fate: **Accepted**, **Rejected**, or **Deferred**.

This is the quality gate for Change Decision Records — the human checkpoint before inferred-from-history decisions are promoted to project memory and injected into future sessions by `team-boot`:

- Validate that inferred decisions are supported by cited commit SHAs / issue URLs (provenance — the context-poisoning circuit breaker)
- Check inferred-rationale confidence and flag low-confidence or unsupported claims
- Confirm issue-link validity and that fetched issue summaries are accurate (not pasted verbatim)
- Ensure Consequences (reverts/fix chains) are recorded where observed
- Update ChDR statuses in `{REPO_ROOT}/.adlc/drafts/chdr/ChDR-{NNN}.md`
- Regenerate `{REPO_ROOT}/.adlc/drafts/chdr/chdr.md` index

**This is an interactive command.** Present exactly one ChDR per interaction and wait for user input.

## When to use

- **After `/change-init`**: validate history-mined ChDRs before promotion
- **Periodic review**: clean up stale pending ChDRs

### When NOT to use

- **No pending ChDRs**: if no ChDRs have status Discovered/Proposed, there is nothing to clarify
- **Reviewing CDRs**: use `/levelup-clarify` (CDRs and ChDRs are distinct record types with separate gates)
- **Direct editing**: do not use this skill to bypass the review workflow

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"ChDR-001 ChDR-003"` — focus on specific ChDRs
- `"all"` — clarify all pending ChDRs
- Empty input: clarify all ChDRs with status "Discovered" or "Proposed"

### Flags

- `--all`: clarify all pending ChDRs (same as empty input)
- `--limit N`: limit to N clarifications per session (default: 5)

### Role & Context

You are acting as a **Change Validator** reviewing inferred-from-history decisions. Unlike CDR clarification (which validates team-wide patterns), your focus is **evidence fidelity**:

- Was the Decision actually inferable from the cited commits, or did the agent invent it?
- Is the confidence level honest (a HIGH-confidence claim with a terse commit + no issue link is suspicious)?
- Are issue summaries accurate and not leaking sensitive detail verbatim?
- Are reverts/fix chains recorded where they exist (the highest-value content)?

#### ChDR Quality Checklist

Each ChDR should have:

- [ ] `### Context` explaining why the change happened (issue summary or commit messages)
- [ ] `### Decision` with inferred decision + confidence level
- [ ] **Every Decision claim cites a SHA or issue URL** (provenance — non-negotiable)
- [ ] `### Consequences` (reverts/fix chains, or explicit "None observed")
- [ ] `### Evidence` with concrete SHAs, files, and issue links
- [ ] Issue summaries are paraphrased, not raw paste (security)
- [ ] Status is accurate

### Outline

1. **Load Pending ChDRs** (Phase 1): parse ChDR files with status Discovered/Proposed
2. **Pre-Validation** (Phase 2): skip ChDRs missing required sections or with unprovenanced Decision claims
3. **Gap Identification** (Phase 3): list clarification needs
4. **Sequential Clarification** (Phase 4): one ChDR per interaction
5. **Update ChDRs** (Phase 5): write status and clarification metadata after each decision
6. **Regenerate Index** (Phase 6): update `chdr.md`
7. **Summary** (Phase 7): present results

### Execution Steps

#### Phase 1: Load Pending ChDRs

Run setup script:

```bash
scripts/bash/setup-change-clarify.sh
```

Read all `{REPO_ROOT}/.adlc/drafts/chdr/ChDR-*.md` files and filter:

- **Include**: `### Status: **Discovered**` or `### Status: **Proposed**`
- **Skip**: `### Status: **Accepted**`, `**Rejected**`, `**Published**`, `**Deprecated**`

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`.
2. `CHDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/chdr`
3. `PENDING_COUNT` — count files with Discovered/Proposed status.

If no pending ChDRs:

```text
No pending ChDRs found.
Run /change-init to mine git history first.
```

#### Phase 2: Pre-Validation

For each pending ChDR, check required sections:

- `### Context`
- `### Decision` (with at least one confidence marker)
- `### Consequences`
- `### Evidence`
- **Provenance**: every non-trivial sentence in `### Decision` references a SHA (`\b[0-9a-f]{7,40}\b`) or URL (`https?://`)

Skip invalid ChDRs and report:

```markdown
## Skipped ChDRs

| ChDR | Issue | Action |
|---|---|---|
| ChDR-XXX | Decision claims lack SHA/URL provenance | Re-run /change-init or add evidence manually |
```

#### Phase 3: Gap Identification

Generate a gap report:

```markdown
## ChDR Clarification Report

| ChDR | Title | Gap Type | Severity |
|---|---|---|---|
| ChDR-001 | [Title] | Low-confidence decision | MEDIUM |
| ChDR-002 | [Title] | Issue summary too verbose | LOW |
```

Gap types:

- **Low-confidence decision**: Decision marked LOW confidence — consider rejecting or deferring
- **Unprovenanced claim**: a Decision sentence without SHA/URL (should have been caught in Phase 2)
- **Issue summary too verbose**: pasted verbatim instead of paraphrased (security)
- **Missing consequences**: Consequences section empty but reverts observed in window
- **Stale**: cluster's commits later reverted (the decision was reversed — mark for rejection or status reversal)

#### Phase 4: Sequential Clarification

**CRITICAL**: Present exactly ONE ChDR per interaction. Do NOT:

- Present multiple ChDRs together
- Auto-select actions
- Proceed without explicit user input
- Ask more than one question at a time

**Session limit**: Default 5 ChDRs per session. User can say "done" to exit early.

For each ChDR:

```markdown
## ChDR-{ID}: {Title}

**Status**: {status}
**Issue Links**: {links or "none"}
**Commits**: {sha list}

### Current Content

**Context**:
{context}

**Decision** (confidence: {level}):
{decision}

**Consequences**:
{consequences}

**Evidence**:
{evidence}

### Choose Action

| Option | Action |
|---|---|
| A | **Accept** — Approve for promotion to memory |
| B | **Reject** — Decline with reason |
| C | **Defer** — Skip for now, keep pending |
| D | **Accept all remaining** — Accept this ChDR and all pending ChDRs without further review |

Reply with your choice (A/B/C/D).
```

Wait for user input before proceeding.

#### Action A: Accept

Update status to `### Status: **Accepted**`. Add clarification metadata:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Accepted
- **Rationale**: [summary of review]
```

#### Action D: Accept All Remaining

Accept the current ChDR (Action A), then iterate remaining pending ChDRs marking each `### Status: **Accepted**` with bulk metadata. Skip per-ChDR presentation. Proceed to Phase 6.

#### Action B: Reject

Ask for reason:

```markdown
### Decision: Reject

| Option | Reason |
|---|---|
| A | Decision was reversed (later reverted) |
| B | Inferred rationale unsupported by evidence |
| C | Project-specific / not worth recording |
| D | Duplicate of an existing ChDR or ADR |

Reply with your choice.
```

Update status to `### Status: **Rejected**` with reason.

#### Action C: Defer

Keep status as-is. Add note:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Deferred
- **Reason**: [need more context / waiting on team / low priority]
```

#### Phase 5: Update ChDR Files

After EACH ChDR interaction, immediately update the file. Do not batch at the end.

#### Phase 6: Regenerate Index

Regenerate `{REPO_ROOT}/.adlc/drafts/chdr/chdr.md` by listing all `ChDR-*.md` files and building the markdown table from single-line fields (`### Status:`, `### Date:`, `### Issue Links:`, `### Commits:`, `### Descriptor:`).

#### Phase 7: Summary

```markdown
## Change-Clarify Summary

**ChDRs Reviewed**: N
**Accepted**: N
**Rejected**: N
**Deferred**: N

### Accepted (Ready for Promotion)

| ChDR | Title |
|---|---|
| ChDR-001 | [Title] |

### Rejected

| ChDR | Reason |
|---|---|
| ChDR-003 | Decision was reversed (later reverted) |

### Deferred

| ChDR | Title |
|---|---|
| ChDR-004 | [Title] |

### Next Steps

1. **Accepted**: Run `/change-publish` to promote to `.adlc/memory/chdr/`
2. **Deferred**: will appear in next clarify session
3. **Remaining**: run `/change-clarify` again to continue
```

### Key Rules

#### One-at-a-Time

- Present exactly ONE ChDR per response
- Ask exactly ONE question per response
- Wait for user input before proceeding

#### Immediate Writes

- Update ChDR file after each decision
- Regenerate index after session ends

#### No Auto-Approval

- Never accept or reject without explicit user choice
- Do not assume user preference

#### Provenance Is the Gate

- A Decision claim without SHA/URL provenance is a poisoning risk — reject or require evidence before accepting
- LOW-confidence decisions are acceptable to accept if evidence is solid; HIGH-confidence with no evidence is not

### Workflow Guidance & Transitions

#### After `/change-clarify`

If any ChDRs were **Accepted**, handoff to `/change-publish`:

```json
{
  "command": "clarify",
  "accepted": ["ChDR-001", "ChDR-002"],
  "rejected": ["ChDR-003"],
  "deferred": ["ChDR-004"]
}
```

#### Complete Clarify Flow

```text
[Pending ChDRs exist]
    ↓
/change-clarify
    ↓
[One ChDR at a time] → Accept / Reject / Defer
    ↓
[Run /change-publish] → Promote accepted ChDRs to .adlc/memory/chdr/
```

## Next Steps

After accepting ChDRs, run `/change-publish` to promote them to project memory and regenerate the boot-facing `chdr.md` index.

## Verification

- All reviewed ChDR files updated with new status and clarification metadata.
- `chdr.md` drafts index regenerated.
- Accepted ChDRs are ready for `/change-publish`.
- No ChDRs were auto-accepted or auto-rejected without user input.
- Accepted ChDRs all have provenance on Decision claims.

## Context

$ARGUMENTS
