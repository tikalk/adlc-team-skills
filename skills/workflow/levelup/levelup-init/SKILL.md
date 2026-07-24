---
name: levelup-init
description: Reverse-engineer Context Directive Records (CDRs) from an existing codebase for contribution to team-ai-directives. Use when bootstrapping team knowledge from brownfield projects.
disable-model-invocation: true
---

# levelup-init

## What this skill does

Reverse-engineer **Context Directive Records (CDRs)** from an **existing codebase** (brownfield) to document reusable patterns that could become contributions to `team-ai-directives`.

You act as a **Context Archaeologist** uncovering implicit team patterns from code:

- Scan the codebase for reusable rules, personas, examples, skill-worthy capabilities, and eval-worthy patterns
- Detect cross-sub-system patterns and inconsistencies
- For each directive CDR, also extract a paired eval CDR with pass/fail cases from code evidence
- Compare against existing team-ai-directives to avoid duplicates
- Write CDRs to `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md` with status **Discovered**
- Auto-generate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` index

**Key Difference from `/levelup-specify`**:

- `/levelup-init` (this skill) = **Discovers** what's already implemented in code
- `/levelup-specify` = **Extracts** patterns from a completed feature's spec/plan/tasks

This skill focuses on **current state analysis** — what IS reusable, not what SHOULD BE created.

## When to use

- **Brownfield projects**: Existing code without team-wide directives
- **Legacy modernization**: Extract reusable patterns before refactoring
- **Team onboarding**: Turn implicit conventions into explicit directives
- **Team AI Directives bootstrapping**: Populate a new team-ai-directives repository

### When NOT to use

- **Greenfield projects**: Use `/levelup-specify` after implementing a feature
- **CDRs already exist**: If `.adlc/drafts/cdr/` has pending CDRs, use `/levelup-clarify` to review
- **Routine team AI directives health checks**: Use `/team-repair` for re-indexing and conflict scanning

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Python FastAPI backend with PostgreSQL"` — Focus on Python patterns
- `"Focus on testing patterns"` — Narrow to testing-related CDRs
- `"--cdr-heuristic all"` — Document all patterns, not just surprising ones
- `"--focus rules"` — Only discover rule-type patterns
- `"--resume"` — Resume from previous state
- Empty input: Scan entire codebase for all context types

### Flags

- `--cdr-heuristic HEURISTIC`: CDR generation strategy
  - `surprising` (default): Only document patterns not already in team-ai-directives
  - `all`: Document all discovered patterns
  - `minimal`: Only high-value/novel patterns

- `--focus AREA`: Focus on specific context type
  - `rules`: Only scan for coding rules
  - `personas`: Only scan for role patterns
  - `examples`: Only scan for example-worthy code
  - `constitution`: Only scan for governance patterns
  - `skills`: Only scan for skill-worthy capabilities

- `--no-decompose`: Disable automatic sub-system detection

- `--resume`: Resume from previous state (if interrupted)

- `--skip-constitution`: Skip constitution generation phase

### Role & Context

You are orchestrating a **multi-agent analysis pipeline** with three specialized agents:

1. **Discovery Agent**: Scans each sub-system for raw patterns
2. **Pattern Agent**: Classifies and scores patterns for reusability
3. **Synthesis Agent**: Performs cross-sub-system analysis and generates CDRs

#### Brownfield vs Greenfield

| Scenario | Command | Input | Output |
|---|---|---|---|
| **Brownfield** (existing code) | `/levelup-init` | Codebase scan | Discovered CDRs |
| **Greenfield** (feature complete) | `/levelup-specify` | Feature artifacts | Proposed CDRs |

#### Cross-Sub-System Analysis

The Synthesis Agent detects:

| Pattern Type | Criteria | Action |
|---|---|---|
| **Cross-cutting** | Pattern in ≥50% of sub-systems | High-priority CDR |
| **Inconsistent** | Same concern, different implementations | Inconsistency CDR |
| **Project-specific** | Only in 1 sub-system, low reuse | Lower priority or skip |
| **Gap** | High value, not in team-directives | Recommended CDR |

### Outline

1. **Validate Environment** (Phase 1): Ensure team-ai-directives is configured
2. **Sub-System Detection** (Phase 2): Identify sub-systems from code structure
3. **Environment Setup** (Phase 3): Resolve paths and initialize state
4. **Load Team Directives** (Phase 4): Read existing TD for comparison
5. **Discovery Agent** (Phase 5): Scan each sub-system for patterns
6. **Pattern Agent** (Phase 6): Classify and score patterns per sub-system
7. **Synthesis Agent** (Phase 7): Cross-sub-system analysis
8. **Constitution Generation** (Phase 8): Generate/enhance constitution CDR
9. **CDR Generation** (Phase 9): Generate final CDRs as individual files
10. **Output** (Phase 10): Regenerate `cdr.md` index and present summary

### Execution Steps

#### Phase 1: Validate Environment

Run the setup script from repository root:

```bash
scripts/bash/setup-levelup-init.sh
```

Parse the JSON output for `REPO_ROOT`, `CDR_DRAFTS_DIR`, `TEAM_AI_DIRECTIVES`, `NEXT_CDR`, etc.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`, or `pwd`.
2. `TEAM_AI_DIRECTIVES` — `TEAM_AI_DIRECTIVES` env var, then `.adlc/init-options.json` → `team_ai_directives`, then `REPO_ROOT/team-ai-directives`.
3. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
4. `NEXT_CDR` — list `CDR_DRAFTS_DIR/CDR-*.md`, find highest number, increment, zero-pad to 3 digits.

If `TEAM_AI_DIRECTIVES` is not configured:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export TEAM_AI_DIRECTIVES=/path/to/team-ai-directives
```

#### Phase 2: Sub-System Detection (Brownfield)

Analyze the codebase for distinct sub-systems. Same detection rules as `/architect-init`:

| Pattern | Likely Sub-System |
|---|---|
| `src/auth/` | Authentication sub-system |
| `src/users/` | User management sub-system |
| `services/payment/` | Payment sub-system |
| `apps/api/`, `apps/web/` | Monorepo apps |

**Threshold Logic**:

| Sub-System Count | Required Action |
|---|---|
| 0 | Proceed as monolithic |
| 1-3 | Show summary, auto-approve allowed |
| 4-6 | MUST show summary and ask confirmation |
| >6 | MUST suggest grouping and ask confirmation |

#### Phase 3: Environment Setup

1. Ensure directories exist:
   - `{REPO_ROOT}/.adlc/drafts/cdr/`
   - `{REPO_ROOT}/.adlc/drafts/skills/`
   - `{REPO_ROOT}/.adlc/levelup/`

2. Initialize `{REPO_ROOT}/.adlc/levelup/state.json`:

```json
{
  "version": "1.0.0",
  "command": "init",
  "created_at": "2026-01-20T10:00:00Z",
  "phase": "discovery",
  "subsystems": [...],
  "constitution_generation": { "enabled": true, "completed": false }
}
```

#### Phase 4: Load Team Directives

Read existing `team-ai-directives` for comparison:

- `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md`
- `{TEAM_AI_DIRECTIVES}/context_modules/rules/**/*.md`
- `{TEAM_AI_DIRECTIVES}/context_modules/personas/*.md`
- `{TEAM_AI_DIRECTIVES}/context_modules/examples/**/*.md`
- `{TEAM_AI_DIRECTIVES}/skills/**/*`

#### Phase 5-7: Multi-Agent Analysis

Run Discovery, Pattern, and Synthesis agents sequentially per sub-system.

#### Phase 8: Constitution CDR Generation

Create a Constitution CDR (if not skipped) in `.adlc/drafts/cdr/CDR-CONST-NNN.md`:

- **Constitution Creation** if no constitution exists
- **Constitution Amendment** if constitution exists

**CRITICAL**: Write to `.adlc/drafts/cdr/`, NOT directly to team-ai-directives.

#### Phase 9: CDR Generation

For each high-value pattern, create an individual CDR file:

```markdown
## CDR-NNN: [Title]

### Status: **Discovered**

### Date: [YYYY-MM-DD]

### Source: Cross-sub-system analysis via /levelup-init

### Cross-System Metadata
- **Appears in**: [sub-systems]
- **Cross-system score**: [0.0-1.0]
- **Consistency**: [consistent|inconsistent]
- **Reuse score**: [0.0-1.0]

### Target Module: `context_modules/rules/[domain]/[file].md`

### Context Type: Rule | Persona | Example | Skill | Constitution Creation | Constitution Amendment | Eval

### Descriptor: One-line "when to use" summary for CDR index search.

### Context
[Problem statement and evidence]

### Decision
[What should be contributed to team-ai-directives]

### Evidence
- [file/path]: [description]
- [commit/sha]: [description]
```

**Eval CDRs from codebase patterns**: When creating a directive CDR from a discovered codebase pattern, also extract a paired eval CDR:

- **Pass cases**: code examples that demonstrate the pattern being followed (with file:line references)
- **Fail cases**: inconsistent implementations (from cross-sub-system analysis) or missing implementations
- **Adversarial cases**: edge cases identifiable from the code context

Eval CDRs use `### Context Type: Eval`, reference their paired directive CDR via `### Paired Directive CDR: CDR-NNN`, and have `### Target Module: evals/{directive-id}/goldset.md`. Cases are self-contained with inline code snippets — no external file dependency.

#### Phase 10: Output Summary

1. Regenerate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` index by listing all `CDR-*.md` files and building a markdown table from their single-line fields (`### Target Module:`, `### Context Type:`, `### Status:`, `### Date:`, `### Descriptor:`). See `/levelup-specify` Phase 5 for the full format.

2. Present summary:

```markdown
## LevelUp Init Summary

- Sub-systems analyzed: N
- Patterns discovered: N
- Cross-cutting patterns: N
- Inconsistencies flagged: N
- CDRs generated: N
- Output: `{REPO_ROOT}/.adlc/drafts/cdr/`
```

### Key Rules

#### Evidence-Based Documentation

- Only document patterns found in code
- Cite specific evidence (file paths, commits, code snippets)
- Mark confidence levels (HIGH/MEDIUM/LOW)
- Flag uncertainties explicitly

#### Non-Destructive

- Do not overwrite existing CDRs without user approval
- Preserve manually added CDR content
- Merge intelligently if a CDR already exists for the same target module

#### No Fabricated Rejection Rationale

- For brownfield CDRs, use neutral "Common Alternatives" framing
- "We don't know why X wasn't chosen" is acceptable

#### Signal Gate (Strict Mode)

Before publishing (handled later by `/levelup-publish`), CDRs must pass:

- **Team-wide**: Pattern applicable across projects
- **High Value**: Saves >30min per future use
- **Unique**: Not duplicate of existing directive
- **Evidence**: Has concrete commits/files

### Workflow Guidance & Transitions

#### After `/levelup-init`

**Required**: Run `/levelup-clarify` to validate discovered CDRs.

Handoff context to include:

```json
{
  "source": "brownfield",
  "command": "init",
  "cdrs_created": ["CDR-001", "CDR-002", "CDR-CONST-001"],
  "subsystems": ["auth", "payments", "users"],
  "inconsistencies": ["CDR-INC-001"]
}
```

#### Complete Brownfield Flow

```text
/levelup-init
    ↓
[Scan codebase] → Detect sub-systems and patterns
    ↓
[Generate CDRs] → Write to .adlc/drafts/cdr/CDR-{NNN}.md (Discovered)
    ↓
[Run /levelup-clarify] → Validate and accept/reject CDRs
    ↓
[Run /levelup-publish] → Compile accepted CDRs into team-ai-directives PR
    ↓
[Run /team-repair] → Re-index and validate team AI directives after merge
```

## Next Steps

After `init` completes, run `/levelup-clarify` to refine and validate the discovered CDRs.

## Verification

- CDRs written to `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md` with status **Discovered**.
- Auto-generated `cdr.md` index exists in `{REPO_ROOT}/.adlc/drafts/cdr/`.
- Gap analysis report identifies unclear areas and recommended clarifications.
- Sub-system decomposition confirmed (or disabled) per threshold rules.
- No existing CDRs were overwritten without explicit approval.

## Context

$ARGUMENTS
