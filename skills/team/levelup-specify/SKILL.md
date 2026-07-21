---
name: levelup-specify
description: Extract Context Directive Records (CDRs) from a completed feature's specification, plan, tasks, and trace for contribution to team-ai-directives. Use after implementing a feature to capture reusable learnings.
disable-model-invocation: true
---

# levelup-specify

## What this skill does

Extract **Context Directive Records (CDRs)** from the **current feature implementation context** after completing a feature.

This is the primary command for capturing learnings from a completed feature:

- Analyze feature spec, plan, tasks, and trace artifacts
- Identify reusable patterns, rules, examples, personas, and skill-worthy capabilities
- Link CDRs to concrete implementation evidence (files, commits, tests)
- Write CDRs to `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md` with status **Proposed**
- Auto-generate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` index

**Key Difference from `/levelup-init`**:

- `/levelup-init` = **Discovers** patterns from existing codebase (brownfield)
- `/levelup-specify` (this skill) = **Extracts** patterns from a completed feature (greenfield)

This skill focuses on **feature-level learnings** — what reusable knowledge emerged from this specific implementation.

## When to use

- **After feature implementation**: Capture reusable patterns from the work just completed
- **Before closing a feature branch**: Extract team-wide learnings
- **Contributing back to team KB**: Turn feature work into reusable directives
- **After `/spec.implement` or equivalent**: When spec/plan/tasks artifacts exist

### When NOT to use

- **Brownfield projects**: Use `/levelup-init` to scan existing code
- **No feature artifacts**: Run this only after spec/plan/tasks exist
- **Routine KB validation**: Use `/team-repair` for health checks

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Focus on error handling patterns"` — Extract CDRs related to error handling
- `"Document the testing approach"` — Focus on testing patterns
- `"CDR-001"` — Enrich an existing CDR with more feature context
- `"--feature 001-user-auth"` — Explicitly select feature directory
- `"--focus skills"` — Only propose skill-type CDRs
- Empty input: Extract all patterns from current feature artifacts

### Flags

- `--feature NAME`: Explicitly select feature directory (e.g., `001-user-auth`)
- `--focus AREA`: Focus on specific context type
  - `rules`: Only propose rule CDRs
  - `personas`: Only propose persona CDRs
  - `examples`: Only propose example CDRs
  - `constitution`: Only propose constitution amendment CDRs
  - `skills`: Only propose skill CDRs
- `--cdr-id ID`: Enrich an existing CDR with feature evidence instead of creating new ones

### Role & Context

You are acting as a **Context Extractor** — identifying reusable patterns from completed features. Your role involves:

- Analyzing feature artifacts (spec, plan, tasks, trace)
- Identifying patterns that would benefit other projects
- Creating CDRs for rules, personas, examples, constitution amendments, or **skills**
- Linking CDRs to implementation evidence (code, commits, tests)

#### Brownfield vs Greenfield

| Scenario | Command | Input | Output |
|---|---|---|---|
| **Brownfield** (existing code) | `/levelup-init` | Codebase scan | Discovered CDRs |
| **Greenfield** (feature complete) | `/levelup-specify` | Feature artifacts | Proposed CDRs |

### Outline

1. **Environment Setup** (Phase 0): Resolve paths and detect feature
2. **Load Feature Context** (Phase 1): Read spec/plan/tasks/trace
3. **Load Existing CDRs** (Phase 2): Read pending CDRs for enrichment
4. **Extract Patterns** (Phase 3): Identify reusable patterns by context type
5. **Create/Enrich CDRs** (Phase 4): Write CDR files with feature evidence
6. **Regenerate Index** (Phase 5): Update `cdr.md`
7. **Summary** (Phase 6): Present extraction results

### Execution Steps

#### Phase 0: Environment Setup

Run the setup script from repository root:

```bash
scripts/bash/setup-levelup-specify.sh
```

Parse JSON output for paths, detected features, and next CDR number.

**If the setup script is unavailable or fails**, resolve paths manually:

1. `REPO_ROOT` — walk up from cwd to find a directory containing `.adlc/`, or use `git rev-parse --show-toplevel`, or use `pwd`.
2. `TEAM_AI_DIRECTIVE` — check `TEAM_AI_DIRECTIVE` env var, then `REPO_ROOT/.adlc/init-options.json` → `team_ai_directive` field, then fallback to `REPO_ROOT/team-ai-directives`.
3. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
4. `NEXT_CDR` — list `CDR_DRAFTS_DIR/CDR-*.md`, find the highest number, increment by 1, zero-pad to 3 digits (e.g., `001`).

If `TEAM_AI_DIRECTIVE` is not configured:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export TEAM_AI_DIRECTIVE=/path/to/team-ai-directives
```

#### Phase 1: Load Feature Context

Detect feature directory in this order:

1. `--feature NAME` argument
2. Current git branch name (e.g., `feature/001-user-auth`)
3. `ADLC_FEATURE` environment variable
4. Most recently modified feature directory under `specs/` — search both `{REPO_ROOT}/specs/` and immediate subdirectories (e.g., `{REPO_ROOT}/{subproject}/specs/`), plus `.adlc/drafts/`

Load available artifacts:

| Artifact | Path | Purpose |
|---|---|---|
| Spec | `specs/{feature}/spec.md` or `.adlc/drafts/spec.md` | Feature intent |
| Plan | `specs/{feature}/plan.md` or `.adlc/drafts/plan.md` | Implementation approach |
| Tasks | `specs/{feature}/tasks.md` or `.adlc/drafts/tasks.md` | Completed task log |
| Trace | `specs/{feature}/trace.md` or `.adlc/drafts/trace.md` | Session trace |

When searching for `specs/`, check these locations in order:
1. `{REPO_ROOT}/specs/`
2. `{REPO_ROOT}/*/specs/` (immediate subdirectories — handles monorepo layouts where specs live under a subproject)
3. `{REPO_ROOT}/.adlc/drafts/` (fallback for draft specs)

If artifacts are missing, note which are unavailable and proceed with available ones.

#### Phase 2: Load Existing CDRs

Read `{REPO_ROOT}/.adlc/drafts/cdr/CDR-*.md`:

- If user provided `--cdr-id`: load that specific CDR for enrichment
- Otherwise: load all pending CDRs (status Discovered/Proposed) to avoid duplicates

#### Phase 3: Extract Patterns

For each context type, look for reusable patterns:

**Rules**: Coding conventions, error handling, testing patterns, security practices
**Personas**: Roles that emerged during implementation (e.g., "API consumer", "DevOps operator")
**Examples**: Code patterns worth reusing
**Skills**: Capabilities that could be packaged as agent skills (especially reusable workflows)
**Constitution Amendments**: Cross-cutting principles discovered during the feature

**Skill-Type CDRs**: Yes, `/levelup-specify` can propose skill-type CDRs. The actual `SKILL.md` is built later by `/levelup-implement --skill <name>`.

#### Phase 4: Create/Enrich CDRs

For each extracted pattern, create or enrich a CDR:

```markdown
## CDR-NNN: [Title]

### Status: **Proposed**

### Date: [YYYY-MM-DD]

### Source: Feature implementation evidence via /levelup-specify

### Target Module: `context_modules/rules/[domain]/[file].md` or `skills/[skill-name]/`

### Context Type: Rule | Persona | Example | Skill | Constitution Amendment

### Descriptor: One-line "when to use" summary.

### Context
[What reusable pattern was identified]

### Feature Implementation Evidence

**Feature**: [feature-name]
**Branch**: [branch-name]

**Spec References**:
- [Quote from spec]

**Implementation Evidence**:
- [file/path]: [description]
- `{commit-sha}`: [commit message]

**Task References**:
- Task N: [description]

### Decision
[What should be contributed to team-ai-directives]
```

When enriching an existing CDR, append a `### Feature Implementation Evidence` section and update the enrichment timestamp.

#### Phase 5: Regenerate Index

Regenerate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` by listing all `CDR-*.md` files and building a markdown table. For each CDR, extract these single-line fields:

- `ID` — from filename (e.g., `CDR-001`)
- `Target Module` — from `### Target Module:` line
- `Type` — from `### Context Type:` line
- `Status` — from `### Status:` line
- `Created` — from `### Date:` line
- `Descriptor` — from `### Descriptor:` line

Format:

```markdown
# Context Directive Records (Drafts)

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|
| CDR-001 | context_modules/rules/... | Rule | Proposed | 2026-07-21 | - | - | One-line summary |

**Stats**: N entries | Last Updated: YYYY-MM-DD
```

#### Phase 6: Summary

```markdown
## LevelUp Specify Summary

**Feature**: [feature-name]
**Date**: [date]
**CDRs Created**: N
**CDRs Enriched**: N

### CDRs by Type

| Type | Count |
|---|---|
| Rules | N |
| Examples | N |
| Skills | N |
| Personas | N |
| Constitution Amendments | N |

### Handover

**Next**: Run `/levelup-clarify` to review the N proposed CDRs.

CDRs are in `Proposed` status and cannot be implemented until accepted.

Handoff context:

```json
{
  "source": "feature",
  "command": "specify",
  "feature": "[feature-name]",
  "cdrs_created": ["CDR-001", "CDR-002"],
  "cdrs_enriched": [],
  "next": "clarify"
}
```

### Next Steps

1. Run `/levelup-clarify` to review proposed CDRs
2. For low-evidence CDRs, add implementation evidence first
3. Run `/levelup-implement` for accepted CDRs
```

### Key Rules

#### Link Evidence, Don't Fabricate

- Every CDR must link to concrete feature artifacts
- Cite specific file paths, commit SHAs, or test cases
- Do not invent evidence

#### Avoid Duplicates

- Check existing CDRs before creating new ones
- If a similar pattern exists, enrich it instead of duplicating

#### Skill CDRs Are Records, Not Skills

- `/levelup-specify` creates CDRs with `Context Type: Skill`
- It does **not** create `SKILL.md` files directly
- Skill artifacts are built by `/levelup-implement --skill <name>`

#### Signal Gate Applies Later

- Create CDRs generously from feature context
- The signal gate (team-wide, high-value, unique, evidence) is applied at `/levelup-implement`

### Workflow Guidance & Transitions

#### After `/levelup-specify`

**Required**: Run `/levelup-clarify` to review proposed CDRs.

Handoff context:

```json
{
  "source": "feature",
  "command": "specify",
  "feature": "001-user-auth",
  "cdrs_created": ["CDR-001", "CDR-002"],
  "cdrs_enriched": ["CDR-003"]
}
```

#### Complete Greenfield Flow

```text
[Feature implementation complete]
    ↓
/levelup-specify
    ↓
[Extract patterns] → Write CDRs to .adlc/drafts/cdr/CDR-{NNN}.md (Proposed)
    ↓
[Run /levelup-clarify] → Review and accept/reject CDRs
    ↓
[Run /levelup-implement] → Compile accepted CDRs into team-ai-directives PR
    ↓
[Run /team-repair] → Re-index and validate KB after merge
```

## Next Steps

After `specify` completes, run `/levelup-clarify` to review the proposed CDRs.

## Verification

- CDRs written to `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md` with status **Proposed**.
- Auto-generated `cdr.md` index exists in `{REPO_ROOT}/.adlc/drafts/cdr/`.
- Each CDR includes feature implementation evidence.
- Existing CDRs were enriched rather than duplicated when applicable.

## Context

$ARGUMENTS
