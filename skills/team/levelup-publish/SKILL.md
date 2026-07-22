---
name: levelup-publish
description: Compile accepted Context Directive Records (CDRs) into team-ai-directives artifacts and create a draft PR. Builds context modules and/or skills based on CDR context types, and publishes the session trace alongside them.
disable-model-invocation: true
---

# levelup-publish

## What this skill does

Compile **accepted CDRs** into actual artifacts in the `team-ai-directives` team AI directives and create a **draft PR**.

It is the implementation phase of the CDR lifecycle:

- Validate accepted CDRs against the signal gate
- Detect cross-CDR conflicts before publishing
- Generate context module files (rules, personas, examples, constitution)
- Generate skill artifacts (`SKILL.md` + `.skills-entry.json`)
- Publish the session trace to the team AI directives
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
- `"--skip-trace"` — Don't publish the session trace
- `"--skill CDR-005"` — Build only the skill from CDR-005
- `"CDR-001 CDR-003"` — Only implement specific CDRs
- Empty input: Implement all accepted CDRs as draft PR

### Flags

- `--ready`: Create ready PR instead of draft
- `--skip-skills`: Skip skill-type CDRs
- `--context-only`: Build only context modules (skip all skills)
- `--skill <name|CDR-id>`: Build only one skill from a specific accepted skill CDR
- `--skip-trace`: Do not publish the session trace to the team AI directives

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
7. **Session Trace Publication** (Phase 6): Publish session trace to team AI directives
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

Parse JSON for `REPO_ROOT`, `TEAM_AI_DIRECTIVE`, `CDR_DRAFTS_DIR`, `ACCEPTED_CDRS`, `TD_CONFIGURED`, `TD_IS_GIT`, `TD_CLEAN`, `TRACE_FILE`, `TRACE_EXISTS`.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`, or `pwd`.
2. `TEAM_AI_DIRECTIVE` — `TEAM_AI_DIRECTIVE` env var, then `.adlc/init-options.json` → `team_ai_directive`, then `REPO_ROOT/team-ai-directives`.
3. `CDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/cdr`
4. `ACCEPTED_CDRS` — `grep -l '^### Status: \*\*Accepted\*\*' CDR_DRAFTS_DIR/CDR-*.md` and extract IDs.
5. `TD_IS_GIT` — `git -C "$TEAM_AI_DIRECTIVE" rev-parse --is-inside-work-tree` (exit 0 = true).
6. `TD_CLEAN` — `git -C "$TEAM_AI_DIRECTIVE" status --porcelain` (empty = clean).
7. `TRACE_FILE` — `REPO_ROOT/.adlc/drafts/trace.md`
8. `TRACE_EXISTS` — `[[ -f "$TRACE_FILE" ]]`

If `TD_IS_GIT` is false, Phase 10 (branch/commit/PR) cannot run. Offer to `git init` the team AI directives or write files directly without git.

#### Phase 1: Prerequisites Check

**Verify Team Directives configured**:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export TEAM_AI_DIRECTIVE=/path/to/team-ai-directives
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
cd "$TEAM_AI_DIRECTIVE"
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

#### Phase 6: Session Trace Publication

Skip if `--skip-trace` is set.

Publish the session trace alongside the context modules so the team has an evidence trail for every contribution. The trace is stored at `{TEAM_AI_DIRECTIVE}/traces/{BRANCH}.md`, following the `spec.trace` convention of branch-based naming (`specs/{BRANCH}/trace.md` in spec-kit).

**Step 1: Ensure trace exists**

Check `TRACE_EXISTS` (from Phase 0 setup output).

If `TRACE_EXISTS` is **false** (`.adlc/drafts/trace.md` does not exist):

```text
No session trace found at {TRACE_FILE}.
Generating one via /levelup-trace...
```

Invoke the `levelup-trace` skill to generate a trace from the current session. After it completes, re-check that `{TRACE_FILE}` now exists. If it still doesn't (e.g., the session had no meaningful work), skip trace publication with a warning:

```text
Warning: Session trace could not be generated. Continuing without trace.
```

**Step 2: Copy trace to team AI directives**

Create the traces directory if it doesn't exist:

```bash
mkdir -p "$TEAM_AI_DIRECTIVE/traces"
```

Copy the trace file:

```bash
cp "$TRACE_FILE" "$TEAM_AI_DIRECTIVE/traces/${BRANCH}.md"
```

**Step 3: Report**

```text
Session trace published: traces/{BRANCH}.md
Source: {existing trace | generated via /levelup-trace}
```

**Brownfield note**: The brownfield path (`/levelup-init → /levelup-clarify → /levelup-publish`) has no implementation session to trace. In that case `/levelup-trace` will trace the init/clarify/publish session itself — still useful but not an implementation trace. Use `--skip-trace` if you prefer to skip trace publication for brownfield contributions.

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

Create/update `{TEAM_AI_DIRECTIVE}/CDR.md` with accepted CDRs:

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
cd "$TEAM_AI_DIRECTIVE"
git checkout -b "levelup/$(basename "$REPO_ROOT")" main 2>/dev/null || git checkout -b "levelup/$(basename "$REPO_ROOT")"
```

2. Commit:
```bash
git add -A
git commit -m "Add context modules from $(basename "$REPO_ROOT")

CDRs implemented:
- CDR-001: ...
- CDR-002: ...

Session trace: traces/{BRANCH}.md
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
cd "$TEAM_AI_DIRECTIVE"
git init
git add -A
git commit -m "Initial team-ai-directives scaffold"
git checkout -b "levelup/$(basename "$REPO_ROOT")"
git add -A
git commit -m "Add context modules from $(basename "$REPO_ROOT")"
```
Then follow steps 3–4 above (remote check).

2. **Write files only** — skip all git operations. Files are written directly to the working tree. Report: "Files written to `{TEAM_AI_DIRECTIVE}`. Initialize git and commit when ready."

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
| Traces | N |

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
- Context module files created in `{TEAM_AI_DIRECTIVE}/context_modules/`
- Skill directories created in `{TEAM_AI_DIRECTIVE}/skills/` (unless skipped)
- Session trace published at `{TEAM_AI_DIRECTIVE}/traces/{BRANCH}.md` (unless `--skip-trace`)
- `.skills.json` updated with new skills
- `CDR.md` updated at `{TEAM_AI_DIRECTIVE}/CDR.md`
- Draft PR created with proper description
- team-ai-directives working tree is clean after commit

## Context

$ARGUMENTS
