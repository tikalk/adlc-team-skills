---
name: levelup-implement
description: Compile accepted Context Directive Records (CDRs) into team-ai-directives artifacts and create a draft PR. Builds context modules and/or skills based on CDR context types.
disable-model-invocation: true
---

# levelup-implement

## What this skill does

Compile **accepted CDRs** into actual artifacts in the `team-ai-directives` knowledge base and create a **draft PR**.

It is the implementation phase of the CDR lifecycle:

- Validate accepted CDRs against the signal gate
- Detect cross-CDR conflicts before publishing
- Generate context module files (rules, personas, examples, constitution)
- Generate skill artifacts (`SKILL.md` + `.skills-entry.json`)
- Update `.skills.json` manifest
- Update `CDR.md` index in team-ai-directives
- Create a branch, commit, and open a draft PR

**This skill does not run until CDRs have been accepted via `/levelup-clarify`.**

## When to use

- **After `/levelup-clarify`**: Accepted CDRs need to be published
- **Single skill build**: Use `--skill <name|CDR-id>` to build one skill
- **Context modules only**: Use `--context-only` to skip skill generation

### When NOT to use

- **No accepted CDRs**: Run `/levelup-clarify` first
- **Uncommitted changes in team-ai-directives**: Clean working tree first
- **Discovering patterns**: Use `/levelup-init` or `/levelup-specify`
- **Reviewing CDRs**: Use `/levelup-clarify`

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"--ready"` — Create ready PR instead of draft
- `"--skip-skills"` — Don't include skill CDRs
- `"--context-only"` — Only build context modules
- `"--skill CDR-005"` — Build only the skill from CDR-005
- `"CDR-001 CDR-003"` — Only implement specific CDRs
- Empty input: Implement all accepted CDRs as draft PR

### Flags

- `--ready`: Create ready PR instead of draft
- `--skip-skills`: Skip skill-type CDRs
- `--context-only`: Build only context modules (skip all skills)
- `--skill <name|CDR-id>`: Build only one skill from a specific accepted skill CDR

### Role & Context

You are acting as a **Context Publisher** — moving accepted CDRs from local drafts to team-ai-directives.

Your role involves:

- Validating that CDRs are accepted and ready
- Creating context module files from CDR content
- Creating skill artifacts from skill-type CDRs
- Managing Git operations (branch, commit, push, PR)

### Outline

1. **Environment Setup** (Phase 0): Resolve paths and list accepted CDRs
2. **Prerequisites Check** (Phase 1): Ensure team-ai-directives is configured and clean
3. **Signal Gate Validation** (Phase 2): Filter CDRs without concrete evidence
4. **Cross-CDR Conflict Check** (Phase 3): Detect duplicate targets and rule conflicts
5. **Branch Preparation** (Phase 4): Create branch in team-ai-directives
6. **Context Module Generation** (Phase 5): Build rules/personas/examples/constitution
7. **Skill Generation** (Phase 6): Build SKILL.md + .skills-entry.json
8. **CDR.md Update** (Phase 7): Update KB root CDR.md index
9. **AGENTS.md Check** (Phase 8): Create if missing
10. **Commit and PR** (Phase 9): Publish changes
11. **Summary** (Phase 10): Report results

### Execution Steps

#### Phase 0: Environment Setup

Run:

```bash
skills/levelup/levelup-implement/scripts/bash/setup-levelup-implement.sh
```

Parse JSON for `REPO_ROOT`, `TEAM_DIRECTIVES`, `CDR_DRAFTS_DIR`, `ACCEPTED_CDRS`, `TD_CONFIGURED`, `TD_CLEAN`.

#### Phase 1: Prerequisites Check

**Verify Team Directives configured**:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export ADLC_TEAM_AI_DIRECTIVES=/path/to/team-ai-directives
```

**Check Working Tree**:

If `TD_CLEAN` is false:

```text
team-ai-directives has uncommitted changes.
Please commit or stash changes before running /levelup-implement.
```

**Check Accepted CDRs**:

If `ACCEPTED_CDRS` is empty:

```text
No accepted CDRs found.
Run /levelup-clarify to accept CDRs first.
```

#### Phase 2: Signal Gate Validation

For each accepted CDR, run:

```bash
skills/team/levelup-helpers.sh --signal-gate .adlc/drafts/cdr/CDR-NNN.md
```

Skip CDRs that fail. Skipped CDRs remain in local drafts.

Report:

```markdown
## Signal Gate Validation

**Passing**: N | **Skipped**: M

### Skipped CDRs

| CDR | Reason |
|---|---|
| CDR-003 | No evidence |
| CDR-005 | Project-specific |
```

#### Phase 3: Cross-CDR Conflict Check

Check for:

1. **Duplicate Targets**: Multiple CDRs targeting the same module path
2. **Rule Conflicts**: Same concern, different implementations
3. **Unresolved Inconsistencies**: CDRs with type "Inconsistency" not marked Resolved

If conflicts found:

```text
Cross-CDR conflicts detected. Resolve via /levelup-clarify before implementing.
```

#### Phase 4: Branch Preparation

Create branch in team-ai-directives:

```bash
cd "$TEAM_DIRECTIVES"
git checkout -b "levelup/$(basename "$REPO_ROOT")" main
```

#### Phase 5: Context Module Generation

For each accepted non-skill CDR, create/update the target file:

**Rules**:

```markdown
---
type: Rule
title: {title}
description: {description}
tags: {tags}
id: {id}
cdr_ref: {cdr_ref}
created: {created}
modified: {modified}
verified: {verified}
age_days: 0
evidence:
{evidence}
---

> ⚠️ **Memory Verification**
> This directive is 0 days old. Before applying:
> - [ ] Pattern still exists in current codebase
> - [ ] Rule is actively followed by team
> - [ ] No conflicting rules introduced

# {Title}

{Content from CDR}

## Source

Contributed from: {project-name}
CDR: {cdr_ref}
```

**Personas** and **Examples** follow similar templates with appropriate `type`.

**Constitution**:

- For Constitution Creation CDRs: create `context_modules/constitution.md`
- For Constitution Amendment CDRs: append to existing constitution

#### Phase 6: Skill Generation

Skip if `--skip-skills` or if all skill CDRs excluded.

For skill-type CDRs (or when `--skill <name|CDR-id>` is specified):

1. Generate `skills/{name}/SKILL.md`:

```markdown
---
name: {name}
description: {description from CDR}
disable-model-invocation: true
---

# {name}

## What this skill does

{Summary}

## When to use

- {Trigger 1}
- {Trigger 2}

## Steps

1. {Step 1}
2. {Step 2}

## Example

{Minimal example}

## Verification

{How to verify}

## Related

- CDRs: {cdr_ref}
```

2. Generate `skills/{name}/.skills-entry.json`:

```json
{
  "name": "{name}",
  "description": "{description}",
  "version": "1.0.0",
  "cdr_ref": "{cdr_ref}"
}
```

3. Register in `.skills.json`:

```json
{
  "local:./skills/{name}": {
    "version": "1.0.0",
    "description": "{description}",
    "categories": ["..."]
  }
}
```

4. Update `AGENTS.md` Skills section with the new skill.

#### Phase 7: CDR.md Update

Create/update `{TEAM_DIRECTIVES}/CDR.md` with accepted CDRs:

```markdown
# Context Directive Records

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|---|---|---|---|---|---|---|---|
| CDR-001 | context_modules/rules/... | Rule | Accepted | ... | ... | 0 | ... |
```

#### Phase 8: AGENTS.md Check

If `AGENTS.md` is missing, create it from a template.

#### Phase 9: Commit and PR

Verify files created, then commit:

```bash
cd "$TEAM_DIRECTIVES"
git add -A
git commit -m "Add context modules from $(basename "$REPO_ROOT")

CDRs implemented:
- CDR-001: ...
- CDR-002: ...
"
```

Push and create draft PR:

```bash
git push -u origin "levelup/$(basename "$REPO_ROOT")"
gh pr create --draft --title "Add context modules from $(basename "$REPO_ROOT")" --body "..."
```

#### Phase 10: Summary

```markdown
## LevelUp Implement Summary

**Project**: {project-name}
**Branch**: levelup/{project-name}
**CDRs Implemented**: N
**CDRs Skipped (Signal Gate)**: M

### Artifacts Created

| Type | Count |
|---|---|
| Rules | N |
| Personas | N |
| Examples | N |
| Skills | N |
| Constitution Changes | N |

### PR Details

**URL**: {PR-URL}
**Status**: Draft

### Next Steps

1. Review PR
2. Merge when approved
3. Run `/team-repair` after merge to re-index and validate
```

### Key Rules

#### Implement Only Accepted CDRs

- Status must be **Accepted**
- Discovered/Proposed/Rejected CDRs are skipped

#### Signal Gate

- Strict mode: skip CDRs without concrete evidence
- Skipped CDRs remain in local drafts for refinement

#### Cross-CDR Validation

- Stop on unresolved conflicts
- Require `/levelup-clarify` to resolve

#### Memory Engineering

- Published files include YAML frontmatter with `created`, `modified`, `verified`, `age_days`
- CDR.md index tracks freshness

#### Context Modules Before CDR.md

- **CRITICAL**: Create ALL context module and skill files before updating `CDR.md`
- Do not create `CDR.md` first and skip the actual modules

### Workflow Guidance & Transitions

#### After `/levelup-implement`

After PR is merged in team-ai-directives, run `/team-repair` to:

- Re-index `CDR.md`, `.skills.json`, and `AGENTS.md`
- Run conflict scanning
- Refresh verification timestamps

#### Complete CDR Lifecycle

```text
/levelup-init or /levelup-specify
    ↓
/levelup-clarify
    ↓
/levelup-implement
    ↓
PR merged
    ↓
/team-repair --validate
```

## Next Steps

After implementation, monitor the PR for review. Once merged, run `/team-repair` to validate the updated KB.

## Verification

- All accepted CDRs passed signal gate or were explicitly skipped
- Context module files created in `{TEAM_DIRECTIVES}/context_modules/`
- Skill directories created in `{TEAM_DIRECTIVES}/skills/` (unless skipped)
- `.skills.json` updated with new skills
- `CDR.md` updated at `{TEAM_DIRECTIVES}/CDR.md`
- Draft PR created with proper description
- team-ai-directives working tree is clean after commit

## Context

$ARGUMENTS
