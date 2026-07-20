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
- **Routine health checks**: Use `/team-repair` for KB maintenance

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
- `--type TYPE`: Filter by context type (rules, personas, examples, skills, constitution)
- `--limit N`: Limit to N clarifications per session (default: 5)

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
3. **Gap Identification** (Phase 3): List clarification needs
4. **Sequential Clarification** (Phase 4): One CDR per interaction
5. **Update CDRs** (Phase 5): Write status and clarification metadata after each decision
6. **Regenerate Index** (Phase 6): Update `cdr.md`
7. **Summary** (Phase 7): Present results

### Execution Steps

#### Phase 1: Load Pending CDRs

Run setup script:

```bash
skills/levelup/levelup-clarify/scripts/bash/setup-levelup-clarify.sh
```

Read all `{REPO_ROOT}/.adlc/drafts/cdr/CDR-*.md` files and filter:

- **Include**: Status = "Discovered" or "Proposed"
- **Skip**: Status = "Accepted", "Rejected", "Deprecated"

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

Reply with your choice (A/B/C).
```

Wait for user input before proceeding.

#### Action A: Accept

Update status to **Accepted**. Add clarification metadata:

```markdown
### Clarification

- **Date**: [YYYY-MM-DD]
- **Action**: Accepted
- **Rationale**: [summary of discussion]
```

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

Update status to **Rejected** with reason.

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

Run:

```bash
skills/team/levelup-helpers.sh --index
```

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

1. **Accepted**: Run `/levelup-implement`
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

If any CDRs were **Accepted**, handoff to `/levelup-implement`:

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
[Run /levelup-implement] → Compile accepted CDRs
```

## Next Steps

After accepting CDRs, run `/levelup-implement` to compile them into a team-ai-directives PR.

## Verification

- All reviewed CDR files updated with new status and clarification metadata.
- `cdr.md` index regenerated.
- Accepted CDRs are ready for `/levelup-implement`.
- No CDRs were auto-accepted or auto-rejected without user input.

## Context

$ARGUMENTS
