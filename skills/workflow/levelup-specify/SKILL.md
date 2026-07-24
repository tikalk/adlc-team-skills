---
name: levelup-specify
description: Extract Context Directive Records (CDRs) from the current session after completing work. Identifies reusable patterns (rules, personas, examples, evals) and captures directive compliance cases for team-ai-directives.
disable-model-invocation: true
---

# levelup-specify

## What this skill does

Extract **Context Directive Records (CDRs)** from the **current session** after completing work.

This is the primary command for capturing learnings from completed work:

- Review the current session directly (the agent remembers what it did)
- Identify reusable patterns: rules, personas, examples, skills, and constitution amendments
- For each directive CDR, also extract a paired **eval CDR** with pass/fail cases from the session
- Link CDRs to concrete implementation evidence (files, commits, tests)
- Write CDRs to `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md` with status **Proposed**
- Auto-generate `{REPO_ROOT}/.adlc/drafts/cdr/cdr.md` index

**Key Difference from `/levelup-init`**:

- `/levelup-init` = **Discovers** patterns from existing codebase (brownfield)
- `/levelup-specify` (this skill) = **Extracts** patterns from the current session (greenfield)

This skill focuses on **session-level learnings** — what reusable knowledge emerged from the work just completed.

## When to use

- **After completing work**: Capture reusable patterns from the session
- **Contributing back to team AI directives**: Turn session work into reusable directives
- **Before closing a branch**: Extract team-wide learnings

### When NOT to use

- **Brownfield projects**: Use `/levelup-init` to scan existing code
- **Before work is done**: Run this after completing the implementation
- **Routine team AI directives validation**: Use `/team-repair` for health checks

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Focus on error handling patterns"` — Extract CDRs related to error handling
- `"Document the testing approach"` — Focus on testing patterns
- `"CDR-001"` — Enrich an existing CDR with more session evidence
- `"--focus skills"` — Only propose skill-type CDRs
- Empty input: Extract all patterns from the session trace

### Flags

- `--focus AREA`: Focus on specific context type
  - `rules`: Only propose rule CDRs
  - `personas`: Only propose persona CDRs
  - `examples`: Only propose example CDRs
  - `constitution`: Only propose constitution amendment CDRs
  - `skills`: Only propose skill CDRs
- `--cdr-id ID`: Enrich an existing CDR with session evidence instead of creating new ones

### Role & Context

You are acting as a **Context Extractor** — identifying reusable patterns from the current session. Your role involves:

- Reading the current session (the agent directly observes what happened)
- Identifying patterns that would benefit other projects
- Creating CDRs for rules, personas, examples, constitution amendments, or **skills**
- For each directive CDR, extracting a paired **eval CDR** with pass/fail cases from the session
- Linking CDRs to implementation evidence (code, commits, tests)

#### Brownfield vs Greenfield

| Scenario | Command | Input | Output |
|---|---|---|---|
| **Brownfield** (existing code) | `/levelup-init` | Codebase scan | Discovered CDRs |
| **Greenfield** (session complete) | `/levelup-specify` | Current session | Proposed CDRs |

### Outline

1. **Environment Setup** (Phase 0): Resolve paths
2. **Review Session** (Phase 1): Review the current session for patterns and evidence
3. **Load Existing CDRs** (Phase 2): Read pending CDRs for enrichment
4. **Extract Patterns** (Phase 3): Identify reusable patterns by context type + extract paired eval CDRs
5. **Create/Enrich CDRs** (Phase 4): Write CDR files with session evidence
6. **Regenerate Index** (Phase 5): Update `cdr.md`
7. **Summary** (Phase 6): Present extraction results

### Execution Steps

#### Phase 0: Environment Setup

Run the setup script from the skill's base directory:

```bash
scripts/bash/setup-levelup-specify.sh
```

Parse JSON output for paths and next CDR number.

**If the setup script is unavailable or fails**, resolve paths manually:

1. `REPO_ROOT` — walk up from cwd to find a directory containing `.adlc/`, or use `git rev-parse --show-toplevel`, or use `pwd`.
2. `TEAM_AI_DIRECTIVES` — check `TEAM_AI_DIRECTIVES` env var, then `REPO_ROOT/.adlc/init-options.json` → `team_ai_directives` field, then fallback to `REPO_ROOT/team-ai-directives`.
3. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
4. `NEXT_CDR` — list `CDR_DRAFTS_DIR/CDR-*.md`, find the highest number, increment by 1, zero-pad to 3 digits (e.g., `001`).

If `TEAM_AI_DIRECTIVES` is not configured:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export TEAM_AI_DIRECTIVES=/path/to/team-ai-directives
```

#### Phase 1: Review Session

Review the current session to identify what happened. The agent directly observes the session — no trace file is needed.

1. What did the user ask for?
2. What did the agent do? (file changes, key decisions, approach)
3. What was the outcome?
4. What files were created/modified? (`git diff --stat`, `git log --oneline -10`)
5. What reusable patterns emerged?

Also collect implementation evidence:

```bash
# Files changed
git diff --stat 2>/dev/null

# Recent commits
git log --oneline -10 2>/dev/null

# New/untracked files
git status --short 2>/dev/null
```

#### Phase 2: Load Existing CDRs

Read `{REPO_ROOT}/.adlc/drafts/cdr/CDR-*.md`:

- If user provided `--cdr-id`: load that specific CDR for enrichment
- Otherwise: load all pending CDRs (status Discovered/Proposed) to avoid duplicates

#### Phase 3: Extract Patterns

For each context type, look for reusable patterns from the session and evidence:

**Rules**: Coding conventions, error handling, testing patterns, security practices
**Personas**: Roles that emerged during implementation (e.g., "API consumer", "DevOps operator")
**Examples**: Code patterns worth reusing
**Skills**: Capabilities that could be packaged as agent skills (especially reusable workflows)
**Constitution Amendments**: Cross-cutting principles discovered during the session

**Skill-Type CDRs**: Yes, `/levelup-specify` can propose skill-type CDRs. The actual `SKILL.md` is built later by `/levelup-publish --skill <name>`.

**Eval CDRs**: For each directive CDR extracted (rule, persona, example, constitution), also extract a paired **eval CDR** with binary pass/fail cases from the session:

- **Pass cases**: moments where the agent correctly followed the (implicit) pattern
- **Fail cases**: moments where the agent violated the pattern (often the trigger for the directive's creation)
- **Adversarial cases**: edge cases from the session context that the directive should handle

Each case is **self-contained** — it includes the scenario, input context, agent output, and why it passes/fails. The case does not depend on an external trace file; the evidence is inline.

Eval CDRs use `### Context Type: Eval` and reference their paired directive CDR via `### Paired Directive CDR: CDR-NNN`.

#### Phase 4: Create/Enrich CDRs

For each extracted pattern, create or enrich a CDR:

```markdown
## CDR-NNN: [Title]

### Status: **Proposed**

### Date: [YYYY-MM-DD]

### Source: Session evidence via /levelup-specify

### Target Module: `context_modules/rules/[domain]/[file].md` or `skills/[skill-name]/`

### Context Type: Rule | Persona | Example | Skill | Constitution Amendment

### Descriptor: One-line "when to use" summary.

### Context
[What reusable pattern was identified]

### Evidence

**Session**: [brief session description]
**Branch**: [branch-name]

**Implementation Evidence**:
- [file/path]: [description]
- `{commit-sha}`: [commit message]

### Decision
[What should be contributed to team-ai-directives]
```

**Eval CDR format** (paired with a directive CDR):

```markdown
## CDR-NNN: [Eval Title]

### Status: **Proposed**

### Date: [YYYY-MM-DD]

### Source: Session evidence via /levelup-specify

### Target Module: `evals/{directive-id}/goldset.md`

### Context Type: Eval

### Paired Directive CDR: CDR-NNN

### Descriptor: One-line "what directive this eval tests"

### Context
[What behavior is being tested and why]

### Pass Cases
1. **Source**: session "[brief description]"
   **Scenario**: [what was asked]
   **Input context**: [what context was loaded]
   **Agent output**: [what the agent did]
   **Why it passes**: [why this follows the directive]

### Fail Cases
1. **Source**: session "[brief description]"
   **Scenario**: [what was asked]
   **Input context**: [what context was loaded]
   **Agent output**: [what the agent did — the violation]
   **Why it fails**: [why this violates the directive]
   **Correction**: [what should have been done]

### Adversarial Cases
1. **Scenario**: [edge case]
   **Expected**: [correct behavior]

### Evidence
**Session**: [brief session description]
**Paired Directive**: CDR-NNN
```

When enriching an existing CDR, append to the `### Evidence` section and update the enrichment timestamp.

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

**Session**: [brief description]
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
| Evals | N |

### Handover

**Next**: Run `/levelup-clarify` to review the N proposed CDRs.

CDRs are in `Proposed` status and cannot be published until accepted.

Handoff context:

```json
{
  "source": "session",
  "command": "specify",
  "cdrs_created": ["CDR-001", "CDR-002"],
  "cdrs_enriched": [],
  "next": "clarify"
}
```
```

### Next Steps

1. Run `/levelup-clarify` to review proposed CDRs
2. For low-evidence CDRs, add implementation evidence first
3. Run `/levelup-publish` for accepted CDRs
```

### Key Rules

#### Link Evidence, Don't Fabricate

- Every CDR must link to concrete session evidence
- Cite specific file paths, commit SHAs, or test cases
- Do not invent evidence

#### Avoid Duplicates

- Check existing CDRs before creating new ones
- If a similar pattern exists, enrich it instead of duplicating

#### Skill CDRs Are Records, Not Skills

- `/levelup-specify` creates CDRs with `Context Type: Skill`
- It does **not** create `SKILL.md` files directly
- Skill artifacts are built by `/levelup-publish --skill <name>`

#### Signal Gate Applies Later

- Create CDRs generously from session evidence
- The signal gate (team-wide, high-value, unique, evidence) is applied at `/levelup-publish`

### Workflow Guidance & Transitions

#### After `/levelup-specify`

**Required**: Run `/levelup-clarify` to review proposed CDRs.

#### Complete CDR Lifecycle

```text
[Agent session — work completed]
    ↓
/levelup-specify
    ↓
[Extract patterns + paired evals] → Write CDRs to .adlc/drafts/cdr/CDR-{NNN}.md (Proposed)
    ↓
[Run /levelup-clarify] → Review and accept/reject CDRs (evals gate runs existing goldensets)
    ↓
[Run /levelup-publish] → Compile accepted CDRs into team-ai-directives PR
    ↓
[Run /team-repair] → Re-index and validate team AI directives after merge
```

## Next Steps

After `/levelup-specify` completes, run `/levelup-clarify` to review the proposed CDRs.

## Verification

- CDRs written to `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md` with status **Proposed**.
- Auto-generated `cdr.md` index exists in `{REPO_ROOT}/.adlc/drafts/cdr/`.
- Each CDR includes session implementation evidence.
- Eval CDRs are paired with their directive CDRs and contain self-contained pass/fail cases.
- Existing CDRs were enriched rather than duplicated when applicable.

## Configuration

- `TEAM_AI_DIRECTIVES` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directives` field.
- Default fallback: `team-ai-directives/` relative to project root.

## 12-Factor Alignment

Factor IX (Traceability) — extracts reusable patterns from session evidence for team-wide contribution.

## Context

$ARGUMENTS
