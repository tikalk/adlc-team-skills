---
name: levelup-publish
description: Compile accepted Context Directive Records (CDRs) into team-ai-directives artifacts and create a draft PR. Builds context modules, evals goldensets, and/or skills based on CDR context types.
disable-model-invocation: true
---

# levelup-publish

## What this skill does

Compile **accepted CDRs** into actual artifacts in the `team-ai-directives` team AI directives and create a **draft PR**.

It is the implementation phase of the CDR lifecycle:

- Validate accepted CDRs against the signal gate
- Detect cross-CDR conflicts before publishing
- Generate context module files (rules, personas, examples, constitution)
- Generate eval goldenset files (`goldset.md` + `goldset.json`) for eval-type CDRs
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
7. **Eval Goldenset Generation** (Phase 6): Build goldset.md + goldset.json for eval CDRs
8. **Skill Generation** (Phase 7): Build SKILL.md + .skills-entry.json
9. **CDR.md Update** (Phase 8): Update team AI directives root CDR.md index
10. **AGENTS.md Check** (Phase 9): Create if missing
11. **Commit and PR** (Phase 10): Publish changes
12. **Summary** (Phase 11): Report results

### Execution Steps

#### Phase 0: Environment Setup

Run:

```bash
scripts/bash/setup-levelup-publish.sh
```

Parse JSON for `REPO_ROOT`, `TEAM_AI_DIRECTIVES`, `CDR_DRAFTS_DIR`, `ACCEPTED_CDRS`, `TD_CONFIGURED`, `TD_IS_GIT`, `TD_CLEAN`.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`, or use `pwd`.
2. `TEAM_AI_DIRECTIVES` — `TEAM_AI_DIRECTIVES` env var, then `.adlc/init-options.json` → `team_ai_directives`, then `REPO_ROOT/team-ai-directives`.
3. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
4. `ACCEPTED_CDRS` — `grep -l '^### Status: \*\*Accepted\*\*' CDR_DRAFTS_DIR/CDR-*.md` and extract IDs.
5. `TD_IS_GIT` — `git -C "$TEAM_AI_DIRECTIVES" rev-parse --is-inside-work-tree` (exit 0 = true).
6. `TD_CLEAN` — `git -C "$TEAM_AI_DIRECTIVES" status --porcelain` (empty = clean).

If `TD_IS_GIT` is false, Phase 10 (branch/commit/PR) cannot run. Offer to `git init` the team AI directives or write files directly without git.

#### Phase 1: Prerequisites Check

**Verify Team Directives configured**:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export TEAM_AI_DIRECTIVES=/path/to/team-ai-directives
```

**Check Working Tree**:

If `TD_CLEAN` is false:

```text
team-ai-directives has uncommitted changes.
Please commit or stash changes before running /levelup-publish.
```

**Check Accepted CDRs**:

If `ACCEPTED_CDRS` is empty:

```text
No accepted CDRs found.
Run /levelup-clarify to accept CDRs first.
```

#### Phase 2: Signal Gate Validation

For each accepted CDR, evaluate it against these four criteria:

1. **Team-wide applicability**: Does this pattern apply to multiple projects/teams, or is it specific to one project? If the CDR's context or evidence only references a single project's internals with no generalizable lesson → SKIP (reason: "project-specific").

2. **Evidence quality**: Does the CDR reference concrete file paths, commit SHAs, or test cases? If the evidence section is empty or vague ("various files", "general practice") → SKIP (reason: "no evidence").

3. **Uniqueness**: Does this duplicate an existing directive in team-ai-directives? Check `context_modules/rules/`, `context_modules/examples/`, and `CDR.md` for overlapping content. If it overlaps → SKIP (reason: "duplicate").

4. **High value**: Is this a genuinely useful pattern, or a nice-to-have minor convenience? If the CDR explicitly states "low value" or "minor convenience", or the pattern is trivial (e.g., "use semicolons") → SKIP (reason: "low value").

Skip CDRs that fail any criterion. Skipped CDRs remain in local drafts.

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

Create branch in team-ai-directives (skip if `TD_IS_GIT=false` — git operations are handled in Phase 10):

```bash
cd "$TEAM_AI_DIRECTIVES"
git checkout -b "levelup/$(basename "$REPO_ROOT")" main 2>/dev/null || git checkout -b "levelup/$(basename "$REPO_ROOT")"
```

#### Phase 5: Context Module Generation

For each accepted non-skill CDR, create/update the target file.

**Extracting fields from CDRs**: CDRs use single-line field format (`### Field: value`). Extract values by parsing the line after the `###` prefix:
- `title` — from the `## CDR-NNN: ` heading
- `description` — from `### Descriptor:` line
- `id` — from `## CDR-NNN` heading (e.g., `CDR-001`)
- `cdr_ref` — same as `id`
- `domain` — from `### Domain:` line (default: `general`)
- `context-type` — from `### Context Type:` line (lowercased; default: `rule`)
- `created` / `modified` / `verified` — from `### Date:` line (use today's date for modified/verified if not present)
- `evidence` — from `### Feature Implementation Evidence` or `### Evidence` section body
- `{Content from CDR}` — from `### Context` section body
- OKF fields (`resource`, `tags`, `timestamp`) are derived: `resource` = relative path from context type/domain/file, `tags` = context type, `timestamp` = ISO 8601 datetime

**Rules**:

```markdown
---
type: Rule
title: {title}
description: {description}
resource: ./context_modules/rules/{domain}/{file}.md
tags: [{context-type}]
timestamp: {today}T00:00:00Z
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

#### Phase 6: Eval Goldenset Generation

For each accepted eval-type CDR, generate goldenset files in `team-ai-directives/evals/`.

**Extracting fields from eval CDRs**: Parse the CDR's single-line fields:
- `directive_id` — from `### Paired Directive CDR:` line (e.g., `CDR-001`)
- `descriptor` — from `### Descriptor:` line
- `pass_cases` — from `### Pass Cases` section body
- `fail_cases` — from `### Fail Cases` section body
- `adversarial_cases` — from `### Adversarial Cases` section body

**Step 1: Create evals directory**

```bash
mkdir -p "$TEAM_AI_DIRECTIVES/evals/{directive_id}"
```

**Step 2: Write goldset.md**

Write `{TEAM_AI_DIRECTIVES}/evals/{directive_id}/goldset.md`:

```markdown
---
type: Eval
title: {title from CDR}
description: {descriptor from CDR}
resource: ./evals/{directive_id}/goldset.md
tags: [eval]
timestamp: {today}T00:00:00Z
id: {eval CDR id}
cdr_ref: {eval CDR id}
paired_directive: {directive_id}
created: {date from CDR}
modified: {today}
verified: {today}
age_days: 0
---

# Goldset: {Title}

## Directive Under Test

- **CDR**: {directive_id}
- **Path**: {target module of paired directive CDR}

## Pass Cases

{pass cases from CDR — each with scenario, input, output, why-it-passes}

## Fail Cases

{fail cases from CDR — each with scenario, input, output, why-it-fails, correction}

## Adversarial Cases

{adversarial cases from CDR — each with scenario, expected}
```

**Step 3: Write goldset.json**

Write `{TEAM_AI_DIRECTIVES}/evals/{directive_id}/goldset.json` — machine-readable version for grader consumption:

```json
{
  "id": "{eval CDR id}",
  "paired_directive": "{directive_id}",
  "title": "{title}",
  "description": "{descriptor}",
  "cases": [
    {
      "id": "PASS-001",
      "type": "pass",
      "scenario": "...",
      "input_context": "...",
      "expected_output": "...",
      "actual_output": "...",
      "reason": "..."
    },
    {
      "id": "FAIL-001",
      "type": "fail",
      "scenario": "...",
      "input_context": "...",
      "expected_output": "...",
      "actual_output": "...",
      "reason": "...",
      "correction": "..."
    }
  ]
}
```

**Step 4: Report**

```text
Eval goldenset published: evals/{directive_id}/goldset.md
Eval goldenset JSON: evals/{directive_id}/goldset.json
```

#### Phase 7: Skill Generation

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

#### Phase 8: CDR.md Update

Create/update `{TEAM_AI_DIRECTIVES}/CDR.md` with accepted CDRs:

```markdown
# Context Directive Records

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|---|---|---|---|---|---|---|---|
| CDR-001 | context_modules/rules/... | Rule | Accepted | ... | ... | 0 | ... |
```

#### Phase 9: AGENTS.md Check

If `AGENTS.md` is missing, create it from a template.

#### Phase 10: Commit and PR

Verify files created, then follow the git decision tree:

**Case A: team-ai-directives IS a git repo (`TD_IS_GIT=true`)**

1. Create branch (use `main` if it exists, otherwise `HEAD`):
```bash
cd "$TEAM_AI_DIRECTIVES"
git checkout -b "levelup/$(basename "$REPO_ROOT")" main 2>/dev/null || git checkout -b "levelup/$(basename "$REPO_ROOT")"
```

2. Commit:
```bash
git add -A
git commit -m "Add context modules from $(basename "$REPO_ROOT")

CDRs implemented:
- CDR-001: ...
- CDR-002: ...
"
```

3. Check for a remote:
```bash
git remote get-url origin 2>/dev/null
```

4a. **If remote "origin" exists AND `gh` CLI is available** — push and create draft PR:
```bash
git push -u origin "levelup/$(basename "$REPO_ROOT")"
gh pr create --draft --title "Add context modules from $(basename "$REPO_ROOT")" --body "..."
```

4b. **If remote "origin" exists but `gh` is NOT available** — push only, tell user to open PR manually:
```bash
git push -u origin "levelup/$(basename "$REPO_ROOT")"
```
Report: "Pushed to `origin/levelup/{project-name}`. Open a PR manually at your Git host."

4c. **If no remote exists** — commit locally only. Report: "Committed to local branch `levelup/{project-name}`. Add a remote (`git remote add origin <url>`) and push when ready."

**Case B: team-ai-directives is NOT a git repo (`TD_IS_GIT=false`)**

Offer the user two options:

1. **`git init` + commit** — initialize git, create an initial commit with the scaffold, then commit the new context modules:
```bash
cd "$TEAM_AI_DIRECTIVES"
git init
git add -A
git commit -m "Initial team-ai-directives scaffold"
git checkout -b "levelup/$(basename "$REPO_ROOT")"
git add -A
git commit -m "Add context modules from $(basename "$REPO_ROOT")"
```
Then follow steps 3–4 above (remote check).

2. **Write files only** — skip all git operations. Files are written directly to the working tree. Report: "Files written to `{TEAM_AI_DIRECTIVES}`. Initialize git and commit when ready."

#### Phase 11: Summary

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
| Evals | N |

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

#### After `/levelup-publish`

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
/levelup-publish
    ↓
PR merged
    ↓
/team-repair --validate
```

## Next Steps

After implementation, monitor the PR for review. Once merged, run `/team-repair` to validate the updated team AI directives.

## Verification

- All accepted CDRs passed signal gate or were explicitly skipped
- Context module files created in `{TEAM_AI_DIRECTIVES}/context_modules/`
- Eval goldenset files created in `{TEAM_AI_DIRECTIVES}/evals/` (for eval-type CDRs)
- Skill directories created in `{TEAM_AI_DIRECTIVES}/skills/` (unless skipped)
- `.skills.json` updated with new skills
- `CDR.md` updated at `{TEAM_AI_DIRECTIVES}/CDR.md`
- Draft PR created with proper description
- team-ai-directives working tree is clean after commit

## Context

$ARGUMENTS
