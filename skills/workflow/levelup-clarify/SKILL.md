---
name: levelup-clarify
description: Review, accept, reject, or defer Context Directive Records (CDRs) discovered by levelup-init or proposed by levelup-specify. Interactive one-CDR-at-a-time workflow.
disable-model-invocation: true
---

# levelup-clarify

## What this skill does

Review pending CDRs (status **Discovered** or **Proposed**) and decide their fate: **Accepted**, **Rejected**, or **Deferred**.

This is the quality gate for all contributions to `team-ai-directives`:

- Validate that patterns are team-wide (not project-specific)
- Check for duplicates against existing team-ai-directives
- Ensure CDRs have clear context, decision, and evidence
- Update CDR statuses in `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md`
- Regenerate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` index

**This is an interactive command.** Present exactly one CDR per interaction and wait for user input.

## When to use

- **After `/levelup-init`**: Validate brownfield discoveries
- **After `/levelup-specify`**: Review proposed feature learnings
- **After `/team-repair` found conflicts**: Resolve conflict CDRs created by repair
- **Periodic review**: Clean up stale pending CDRs

### When NOT to use

- **No pending CDRs**: If no CDRs have status Discovered/Proposed, there is nothing to clarify
- **Direct editing**: Do not use this skill to bypass the review workflow
- **Routine health checks**: Use `/team-repair` for team AI directives maintenance

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"CDR-001 CDR-003"` — Focus on specific CDRs
- `"rules"` — Clarify only rule-type CDRs
- `"all"` — Clarify all pending CDRs
- Empty input: Clarify all CDRs with status "Discovered" or "Proposed"

### Flags

- `--all`: Clarify all pending CDRs (same as empty input)
- `--type TYPE`: Filter by context type (rules, personas, examples, skills, constitution, evals)
- `--limit N`: Limit to N clarifications per session (default: 5)
- `--no-evals-gate`: Disable the evals regression gate (default: gate is ON)

### Role & Context

You are acting as a **Context Validator** reviewing discovered patterns. Your role involves:

- Validating that patterns are still relevant
- Clarifying scope (team-wide vs project-specific)
- Checking against existing team-ai-directives for overlap
- Refining CDR content through targeted questions

#### CDR Quality Checklist

Each CDR should have:

- [ ] Clear context explaining the pattern
- [ ] Explicit decision statement
- [ ] Evidence from codebase or feature
- [ ] Target module path well-formed
- [ ] Status is accurate
- [ ] No conflicts with existing directives
- [ ] Team-wide applicability

### Outline

1. **Load Pending CDRs** (Phase 1): Parse CDR files with status Discovered/Proposed
2. **Pre-Validation** (Phase 2): Skip CDRs missing required sections
3. **Evals Regression Gate** (Phase 2a): Run existing goldensets before accepting (default ON)
4. **Gap Identification** (Phase 3): List clarification needs
5. **Sequential Clarification** (Phase 4): One CDR per interaction
6. **Update CDRs** (Phase 5): Write status and clarification metadata after each decision
7. **Regenerate Index** (Phase 6): Update `cdr.md`
8. **Summary** (Phase 7): Present results

### Execution Steps

#### Phase 1: Load Pending CDRs

Run setup script:

```bash
scripts/bash/setup-levelup-clarify.sh
```

Read all `{REPO_ROOT}/.adlc/drafts/cdr/CDR-*.md` files and filter:

- **Include**: `### Status: **Discovered**` or `### Status: **Proposed**`
- **Skip**: `### Status: **Accepted**`, `**Rejected**`, `**Deprecated**`

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`.
2. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
3. `PENDING_COUNT` — `grep -l '^### Status: \*\*(Discovered|Proposed)\*\*' CDR_DRAFTS_DIR/CDR-*.md | wc -l`

If user specified specific CDR IDs or types, filter accordingly.

If no pending CDRs:

```text
No pending CDRs found.
Run /levelup-init or /levelup-specify to create CDRs first.
```

#### Phase 2: Pre-Validation

For each pending CDR, check required sections:

- `### Context`
- `### Decision`
- `### Evidence`
- `### Target Module`

Skip invalid CDRs and report:

```markdown
## Skipped CDRs

| CDR | Issue | Action |
|---|---|---|
| CDR-XXX | Missing Evidence | Add evidence and re-run clarify |
```

#### Phase 2a: Evals Regression Gate

**Default: ON.** Use `--no-evals-gate` to disable.

When reviewing an eval CDR or a directive CDR that has a paired eval, run the existing goldensets in `team-ai-directives/evals/` to check if accepting this CDR would break existing directive compliance tests.

**For eval CDRs**: Validate eval quality:
- Every case has a concrete evidence reference (session description or code file:line)
- Pass/fail is binary (no ambiguous cases)
- Eval CDR references its paired directive CDR
- Fail cases have a correction (what should have been done)

**For directive CDRs with paired evals**: Run regression check:
1. Read existing goldensets from `{TEAM_AI_DIRECTIVES}/evals/`
2. If no existing goldensets → skip gate (no regression possible)
3. If goldensets exist for the same directive area:
   - Run the existing goldenset cases against the agent via LLM calls
   - If accepting this CDR would modify the directive, check if existing eval cases would still pass
   - If existing evals would fail with the new directive → mark CDR as `Blocked (Evals)`

**Blocked CDRs** remain in pending status with a note:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Blocked (Evals)
- **Reason**: Accepting this CDR would break N existing goldenset cases in evals/{directive-id}/
```

Report:

```markdown
## Evals Regression Gate

| CDR | Gate Result | Details |
|---|---|---|
| CDR-001 | PASS | No existing goldensets in scope |
| CDR-002 | BLOCKED | 3 existing cases would fail with modified rule |
```

#### Phase 3: Gap Identification

Generate a gap report:

```markdown
## CDR Clarification Report

| CDR | Title | Gap Type | Severity |
|---|---|---|---|
| CDR-001 | [Title] | Missing scope | HIGH |
| CDR-002 | [Title] | Duplicate check | MEDIUM |
```

Gap types:

- **Missing scope**: Team-wide vs project-specific unclear
- **Unclear validity**: Pattern status unknown
- **Duplicate check needed**: May overlap existing directives
- **Content incomplete**: Missing context/decision/evidence
- **Target module unclear**: Module path needs clarification

#### Phase 4: Sequential Clarification

**CRITICAL**: Present exactly ONE CDR per interaction. Do NOT:

- Present multiple CDRs together
- Auto-select actions
- Proceed without explicit user input
- Ask more than one question at a time

**Session limit**: Default 5 CDRs per session. User can say "done" to exit early.

For each CDR:

```markdown
## CDR-{ID}: {Title}

**Context Type**: {type}
**Target Module**: {target}
**Current Status**: {status}

### Current Content

**Context**:
{context}

**Decision**:
{decision}

**Evidence**:
{evidence}

### Choose Action

| Option | Action |
|---|---|
| A | **Accept** — Approve for implementation |
| B | **Reject** — Decline with reason |
| C | **Defer** — Skip for now, keep pending |
| D | **Accept all remaining** — Accept this CDR and all pending CDRs without further review |

Reply with your choice (A/B/C/D).
```

Wait for user input before proceeding.

#### Action A: Accept

Update the CDR's status line from `### Status: **Proposed**` (or `**Discovered**`) to `### Status: **Accepted**`. Add clarification metadata:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Accepted
- **Rationale**: [summary of discussion]
```

#### Action D: Accept All Remaining

Update the current CDR as Accepted (same as Action A). Then iterate through all remaining pending CDRs, mark each as `### Status: **Accepted**`, and add clarification metadata:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Accepted (bulk)
- **Rationale**: Bulk-accepted with user approval during clarify session
```

Skip the per-CDR presentation for remaining CDRs. Proceed directly to Phase 6 (Regenerate Index) and Phase 7 (Summary).

#### Action B: Reject

Ask for reason:

```markdown
### Decision: Reject

| Option | Reason |
|---|---|
| A | Project-specific |
| B | Duplicate of existing directive |
| C | Deprecated/outdated pattern |
| D | Low value |

Reply with your choice.
```

Update the CDR's status line to `### Status: **Rejected**` with reason.

#### Action C: Defer

Keep status as-is. Add note:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Deferred
- **Reason**: [need more context / waiting on team / low priority]
```

#### Phase 5: Update CDR Files

After EACH CDR interaction, immediately update the file. Do not batch at the end.

#### Phase 6: Regenerate Index

Regenerate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` by listing all `CDR-*.md` files and building a markdown table. For each CDR, extract the single-line fields (`### Target Module:`, `### Context Type:`, `### Status:`, `### Date:`, `### Descriptor:`) and build the index table. See `/levelup-specify` Phase 5 for the full format.

#### Phase 7: Summary

```markdown
## LevelUp Clarify Summary

**CDRs Reviewed**: N
**Accepted**: N
**Rejected**: N
**Deferred**: N

### Accepted (Ready for Implementation)

| CDR | Target Module | Type |
|---|---|---|
| CDR-001 | rules/python/error-handling | Rule |

### Rejected

| CDR | Reason |
|---|---|
| CDR-003 | Project-specific |

### Deferred

| CDR | Title |
|---|---|
| CDR-004 | [Title] |

### Next Steps

1. **Accepted**: Run `/levelup-publish`
2. **Deferred**: Will appear in next clarify session
3. **Remaining**: Run `/levelup-clarify` again to continue
```

### Key Rules

#### One-at-a-Time

- Present exactly ONE CDR per response
- Ask exactly ONE question per response
- Wait for user input before proceeding

#### Immediate Writes

- Update CDR file after each decision
- Regenerate index after session ends

#### No Auto-Approval

- Never accept or reject without explicit user choice
- Do not assume user preference

#### Session Limits

- Default limit: 5 CDRs per session
- Honor `--limit N` if provided
- User can say "done" to exit early

### Workflow Guidance & Transitions

#### After `/levelup-clarify`

If any CDRs were **Accepted**, handoff to `/levelup-publish`:

```json
{
  "command": "clarify",
  "accepted": ["CDR-001", "CDR-002"],
  "rejected": ["CDR-003"],
  "deferred": ["CDR-004"]
}
```

#### Complete Clarify Flow

```text
[Pending CDRs exist]
    ↓
/levelup-clarify
    ↓
[One CDR at a time] → Accept / Reject / Defer
    ↓
[Run /levelup-publish] → Compile accepted CDRs
```

## Next Steps

After accepting CDRs, run `/levelup-publish` to compile them into a team-ai-directives PR.

## Verification

- All reviewed CDR files updated with new status and clarification metadata.
- `cdr.md` index regenerated.
- Accepted CDRs are ready for `/levelup-publish`.
- No CDRs were auto-accepted or auto-rejected without user input.

## Context

$ARGUMENTS
