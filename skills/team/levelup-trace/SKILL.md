---
name: levelup-trace
description: Generate a session execution trace from the current agent session. Captures what the agent did, decisions made, files changed, and reusable patterns. Use after completing work to create a trace for levelup-specify to consume.
---

# levelup-trace

## Overview

`levelup-trace` generates a session execution trace from the **current agent session** — what the agent actually did in this conversation, not from spec-kit artifacts. The trace captures the user's request, the agent's approach, key decisions, file changes, and reusable patterns.

**Purpose**:
- Document what happened during the session for reuse and learning
- Capture decision-making patterns and problem-solving approaches
- Provide evidence trail (commits, files changed, tool usage)
- Create a trace that `levelup-specify` can consume for CDR extraction

**Output**: `.adlc/drafts/trace.md`

**Key Difference from spec-kit's `spec.trace`**:
- `spec.trace` = Reads spec-kit artifacts (spec.md, plan.md, tasks_meta.json) to generate a trace
- `levelup-trace` (this skill) = Reads the **current session** to generate a trace. No spec-kit dependency.

## When to Use

- **After completing work**: Capture what the agent did for reuse
- **Before `/levelup-specify`**: Generate a trace for CDR extraction
- **Session documentation**: Keep a record of agent sessions for learning
- **Pattern capture**: Identify reusable patterns from the work just done

### When NOT to Use

- **Before work is done**: Run this after completing the implementation
- **Brownfield discovery**: Use `/levelup-init` to scan existing code
- **CDR extraction**: Use `/levelup-specify` after running this skill
- **CDR review**: Use `/levelup-clarify` to review proposed CDRs

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"focus on error handling"` — Emphasize error handling patterns in the trace
- `"document the testing approach"` — Focus on testing decisions
- Empty input: Generate a comprehensive trace from the entire session

### Role & Context

You are acting as a **Session Recorder** — documenting what happened during the current agent session. Your role involves:

- Reviewing the current conversation to identify key actions and decisions
- Collecting concrete evidence (file changes, commits, tool usage)
- Generating a structured trace document
- Identifying reusable patterns for future sessions

### Outline

1. **Environment Setup** (Phase 0): Resolve paths
2. **Session Review** (Phase 1): Reflect on what happened in the conversation
3. **Evidence Collection** (Phase 2): Gather concrete file/commit evidence
4. **Generate Trace** (Phase 3): Write the trace with all sections
5. **Validate Trace** (Phase 4): Check completeness
6. **Summary** (Phase 5): Present results and handoff to `/levelup-specify`

### Execution Steps

#### Phase 0: Environment Setup

Run the setup script from the skill's base directory:

```bash
scripts/bash/setup-levelup-trace.sh
```

Parse JSON output for paths.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find a directory containing `.adlc/`, or use `git rev-parse --show-toplevel`, or use `pwd`.
2. `TEAM_AI_DIRECTIVE` — check `TEAM_AI_DIRECTIVE` env var, then `REPO_ROOT/.adlc/init-options.json` → `team_ai_directive` field, then fallback to `REPO_ROOT/team-ai-directives`.
3. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
4. `TRACE_FILE` — `REPO_ROOT/.adlc/drafts/trace.md`

No prerequisites — any session can be traced.

#### Phase 1: Session Review

Review the current conversation to identify:

**What the user asked for**:
- The original request or task description
- Any clarification or refinement during the session
- Key constraints or requirements stated

**What the agent did**:
- Major actions taken (file creation, code changes, tool usage)
- Approach or strategy used
- Key decisions made and why
- Challenges encountered and how they were resolved

**What the outcome was**:
- What was implemented or changed
- Whether tests pass, builds succeed, etc.
- Any verification performed

#### Phase 2: Evidence Collection

Gather concrete evidence from the repository:

```bash
# Files changed (if git repo)
git diff --stat 2>/dev/null

# Recent commits
git log --oneline -10 2>/dev/null

# Untracked files (new files created)
git status --short 2>/dev/null

# Specific file contents that show key implementation decisions
# (read the most important changed files)
```

If not a git repo, manually list files created/modified during the session.

For each piece of evidence, note:
- File path
- What was created/changed
- Why it matters (what decision or pattern does it represent)

#### Phase 3: Generate Trace

Write the trace to `{TRACE_FILE}` (`.adlc/drafts/trace.md`) with this structure:

```markdown
# Session Trace

Generated: [YYYY-MM-DD]
Branch: [branch-name or "N/A"]

---

## Summary

### Problem

[1-2 sentence description of what the user asked for, extracted from the session]

### Key Decisions

1. [Decision 1 — what was chosen and why]
2. [Decision 2 — what was chosen and why]
3. [Decision N — what was chosen and why]

### Final Solution

[Brief description of what was implemented, with key metrics: files changed, tests passed, etc.]

---

## 1. Session Overview

[Summary of the agent's approach: what it did step by step, major tool calls, strategy]

## 2. Decision Patterns

[Technology choices, process decisions, architecture decisions, and the reasoning behind each]

## 3. Implementation Evidence

[Concrete file changes with descriptions:]

- `[file/path]`: [what was created/modified and why]
- `[file/path]`: [what was created/modified and why]

## 4. Reusable Patterns

[Patterns that emerged during this session that would benefit future work:]

- [Pattern 1]: [description and when to apply]
- [Pattern 2]: [description and when to apply]

## 5. Evidence Links

- Commits: [commit SHAs with messages]
- Files created: [list of new files]
- Files modified: [list of changed files]
- Key file paths: [most important files for review]
```

If the user provided input (e.g., "focus on error handling"), emphasize that aspect throughout the trace sections.

#### Phase 4: Validate Trace

Check the trace for completeness:

| Criterion | Requirement |
|-----------|-------------|
| Summary section | All 3 parts present (Problem, Key Decisions, Final Solution) |
| Section 1-5 | Each section exists with ≥3 lines of content |
| Evidence links | At least 1 commit or file path referenced |
| Reusable patterns | At least 1 pattern identified |

Report:

```markdown
## Trace Validation

**Coverage**: N/5 sections (N%)
**Evidence links**: N commits, N files
**Reusable patterns**: N identified
**Warnings**: [any missing sections or low-coverage areas]
```

#### Phase 5: Summary

```markdown
## LevelUp Trace Summary

**Session**: [brief description]
**Trace**: `.adlc/drafts/trace.md`
**Coverage**: N/5 sections (N%)
**Files changed**: N
**Reusable patterns**: N

### Handover

**Next**: Run `/levelup-specify` to extract CDRs from the session trace.

Handoff context:

```json
{
  "source": "session",
  "command": "trace",
  "trace_file": ".adlc/drafts/trace.md",
  "next": "specify"
}
```
```

### Key Rules

#### Capture What Actually Happened

- The trace documents the **current session**, not what a spec said should happen
- Base everything on concrete evidence: file changes, commits, conversation
- Do not invent or speculate about what wasn't done

#### Evidence Over Claims

- Every decision should reference a specific file, commit, or conversation point
- "Seems like a good pattern" is not sufficient — cite the evidence

#### Session-First, Not Artifact-First

- The trace is generated from the session, not from spec-kit artifacts
- No dependency on spec.md, plan.md, tasks.md, or tasks_meta.json
- Works with any agent, any project, any workflow

#### Trace Is Input, Not Output

- The trace is consumed by `/levelup-specify` for CDR extraction
- The trace itself is not a CDR — it's raw material
- CDRs are extracted by `/levelup-specify`, reviewed by `/levelup-clarify`, published by `/levelup-publish`

### Workflow Guidance & Transitions

#### After `/levelup-trace`

**Required**: Run `/levelup-specify` to extract CDRs from the trace.

#### Complete CDR Lifecycle

```text
[Agent session — work completed]
    ↓
/levelup-trace
    ↓
[Generate trace] → Write to .adlc/drafts/trace.md
    ↓
[Run /levelup-specify] → Extract CDRs from trace + session evidence
    ↓
[Run /levelup-clarify] → Review and accept/reject CDRs
    ↓
[Run /levelup-publish] → Compile accepted CDRs into team-ai-directives PR
    ↓
[Run /team-repair] → Re-index and validate team AI directives after merge
```

## Verification

- Trace written to `.adlc/drafts/trace.md`.
- All 5 sections present with content.
- Evidence links reference concrete files/commits.
- At least 1 reusable pattern identified.
- Trace is ready for `/levelup-specify` consumption.

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `team-ai-directives/` relative to project root.

## 12-Factor Alignment

Factor IX (Traceability) — captures session execution for reuse and learning.

## Context

$ARGUMENTS
