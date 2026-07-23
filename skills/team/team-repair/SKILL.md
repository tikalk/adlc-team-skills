---
name: team-repair
description: Re-index CDR.md, .skills.json, and AGENTS.md in team-ai-directives, scan for rule conflicts, and verify directive freshness. Use when indexes are inconsistent, orphans are detected, after bulk changes, or for periodic team AI directives health validation.
disable-model-invocation: true
---

# team-repair

## Overview

Re-index CDR.md, .skills.json, and AGENTS.md in team-ai-directives to fix inconsistencies, detect orphaned files, and auto-repair issues. Begins with a health-check phase (Phase 0) that verifies the directives framework is installed, configured, and aligned before performing any repairs.

**Input**: team-ai-directives repository

**Output**:
0. Health check report (8 checks: extension installed, team AI directives configured, context modules exist, skills registry, CDR tracking, constitution alignment, type field presence, project AGENTS.md directive)
1. Repaired AGENTS.md (if missing or corrupted)
2. Rebuilt CDR.md index from context_modules/
3. Rebuilt .skills.json manifest from skills/
4. Auto-added YAML frontmatter to orphan context modules (including OKF fields: `resource`, `tags`, `timestamp`)
5. Auto-generated .skills.json entries for orphan skills
6. Generated OKF-compliant `index.md` (progressive disclosure) per context module directory
7. Generated OKF-compliant `log.md` (chronological change history) per context module directory
8. Conflict scan across rules (creates conflict CDRs if issues found)
9. Freshness verification (updates `verified` timestamps, flags stale directives)
10. Summary report of all repairs

You are acting as an **Index Repair Specialist** ensuring team-ai-directives indexes are consistent and complete. Your role involves:

- **Verifying** health checks before repair (Phase 0)
- **Scanning** context_modules/ and skills/ directories
- **Detecting** orphan files (missing frontmatter/manifest entries)
- **Auto-repairing** issues by generating missing metadata
- **Rebuilding** index files to reflect actual content
- **Reporting** all changes made

### Repair Targets

| Target | Location | Purpose |
|--------|----------|---------|
| **AGENTS.md** | `{TEAM_AI_DIRECTIVE}/AGENTS.md` | Main instruction file for AI agents |
| **CDR.md** | `{TEAM_AI_DIRECTIVE}/CDR.md` | Index of approved context contributions |
| **.skills.json** | `{TEAM_AI_DIRECTIVE}/.skills.json` | Skills manifest registry |
| **OKF index.md** | `{TEAM_AI_DIRECTIVE}/context_modules/{type}/index.md` | Progressive disclosure per concept directory |
| **OKF log.md** | `{TEAM_AI_DIRECTIVE}/context_modules/{type}/log.md` | Chronological change log per concept directory |

## When to Use

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `""` - Repair all three indexes (default)
- `"--dry-run"` - Report only, don't write changes
- `"--cdr-only"` - Only repair CDR.md
- `"--skills-only"` - Only repair .skills.json
- `"--agents-only"` - Only repair AGENTS.md
- Empty input: Repair all indexes with auto-fix

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Report only, don't write changes |
| `--health-only` | Run Phase 0 health check only, then stop. |
| `--validate` | Run conflict scan + freshness verification only (Phases 8-9) |
| `--conflicts` | Scan for rule conflicts only |
| `--freshness` | Verify directive freshness only |
| `--cdr-only` | Only repair CDR.md |
| `--skills-only` | Only repair .skills.json |
| `--agents-only` | Only repair AGENTS.md |
| (default) | Repair all indexes + validate conflicts and freshness |

## Core Process

### Phase 0: Health Check

**Objective**: Run a non-destructive health check against the team directives framework before proceeding with repairs. If any check returns `[FAIL]`, present the report and stop — the framework is not healthy enough to repair safely.

Execute all eight checks below. Each check prints a status line. If any check is `[FAIL]`, abort repair.

#### Check 1: Extension Installed

1. Check `.adlc/extensions/.registry` for `team-ai-directives` entry
2. Verify `.adlc/extensions/team-ai-directives/extension.yml` exists
3. Extract version from `extension.yml`

Output: `[OK]` or `[FAIL]` with reason

#### Check 2: Team AI Directives Configured

1. Read `.adlc/init-options.json`
2. Verify `team_ai_directive` field exists and points to valid path
3. Check the team AI directives path exists

Output: `[OK]` or `[FAIL]` with reason

#### Check 3: Context Modules Exist

1. Read `.adlc/init-options.json` → get team AI directives path
2. Verify:
   - `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md`
   - `{TEAM_AI_DIRECTIVE}/context_modules/personas/`
   - `{TEAM_AI_DIRECTIVE}/context_modules/rules/`
   - `{TEAM_AI_DIRECTIVE}/context_modules/examples/`

Output: `[OK]` or `[FAIL]` with reason

#### Check 4: Skills Registry

- `{TEAM_AI_DIRECTIVE}/.skills.json` exists and is valid JSON

Output: `[OK]` or `[FAIL]` with reason

#### Check 5: CDR Tracking

- `{TEAM_AI_DIRECTIVE}/CDR.md` exists

Output: `[OK]` or `[FAIL]` with reason

#### Check 6: Constitution Alignment

1. Read team constitution from `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md`
2. Locate project constitution: the project root (where `.adlc/` lives) → `{REPO_ROOT}/.adlc/memory/constitution.md`
3. If project constitution exists:
   - Check if it references team-ai-directives (e.g., "Based on team-ai-directives", "Inherits from")
   - Check if team principles are present in project constitution (compare principle titles)
   - Output:
     - `[OK]` — Project constitution exists and inherits team principles
     - `[WARN]` — Project constitution exists but missing team inheritance
4. If project constitution doesn't exist:
   - `[INFO]` — Project constitution doesn't exist yet (first-time setup)

#### Check 7: OKF Type Field Presence

1. Scan all `.md` files in `context_modules/` (excluding `index.md`, `log.md`)
2. Parse YAML frontmatter from each file
3. Verify `type` field is present and has a valid value:
   - Valid types: `Constitution`, `Persona`, `Rule`, `Example`, `Skill`
4. Output:
   - `[OK]` — All concept files have valid `type` fields
   - `[WARN]` — Some files missing `type` field (list files)

#### Check 8: Project AGENTS.md Directive

1. Read `{REPO_ROOT}/AGENTS.md` (the project-level agent instructions file)
2. Check if it contains the `<!-- TEAM_AI_DIRECTIVES START -->` marker
3. If the marker exists, verify the managed section includes:
   - The `team-boot` strict-compliance directive ("MUST invoke the `team-boot` skill")
   - A reference to `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md`
4. Output:
   - `[OK]` — Project AGENTS.md contains a valid team AI directives managed section
   - `[WARN]` — Project AGENTS.md exists but is missing the managed section (agents won't auto-invoke `team-boot`)
   - `[INFO]` — Project AGENTS.md doesn't exist yet (first-time setup)

#### Health Check Output

Print verification status for each check:
- `[OK]` — Check passed
- `[FAIL]` — Check failed with reason (abort repair)
- `[WARN]` — Check passed with warnings (non-blocking)
- `[INFO]` — Informational only

If any check is `[FAIL]`, print the report, set exit code 1, and **STOP**. Do not proceed to Phase 1.

#### Health Check Red Flags

- **`[FAIL]` on Check 1 or Check 2**: the directives framework is effectively absent — agents have nothing to inherit from. Stop and reinstall before repairing.
- **Team AI Directives path resolves outside the repo** or to a temp/scratch location: the project is pointing at a transient or shared team AI directives that may vanish or diverge.
- **`{TEAM_AI_DIRECTIVE}/.skills.json` is missing or not valid JSON**: skill discovery is broken; agents cannot find team skills even if the files exist.
- **Project constitution exists but shows no team inheritance** (`[WARN]` on Check 6): the project was bootstrapped without the directives extension, or the constitution was hand-edited and the inheritance markers were removed.
- **Multiple checks return `[WARN]` simultaneously**: systemic drift, usually from an extension upgrade or a moved `.adlc/` directory. Treat as a `[FAIL]`-equivalent and re-init.

---

### Phase 1: Environment Setup

**Objective**: Resolve paths and validate infrastructure

Run `team-helpers.sh --json` from repository root and parse JSON output:

```json
{
  "REPO_ROOT": "/path/to/project",
  "TEAM_AI_DIRECTIVE": "/path/to/team-ai-directives",
  "BRANCH": "current-branch"
}
```

`{REPO_ROOT}` is the project root (where `.adlc/` lives). Subsequent references use `{REPO_ROOT}`.

### Phase 2: Validate Environment

**Objective**: Ensure team-ai-directives is configured

Check if TEAM_AI_DIRECTIVE has a value from script output.

If empty, **STOP**:
```
Team AI directives repository not configured.
Run: /team-setup
Or set: export TEAM_AI_DIRECTIVE=/path/to/team-ai-directives
```

### Phase 3: Repair AGENTS.md

**Objective**: Ensure AGENTS.md exists with required structure

**Skip if**: `--cdr-only` or `--skills-only` flag provided

#### Step 1: Check AGENTS.md Exists

```bash
test -f "{TEAM_AI_DIRECTIVE}/AGENTS.md" && echo "EXISTS" || echo "MISSING"
```

#### Step 2: Validate Structure (if exists)

Required sections:
- `# Agent Instructions` (title)
- `## Structure`
- `## Loading Order`
- `## Functional Categories (Rules)`
- `## Using Skills`
- `## CDR.md`

Check for each required section:
```bash
grep -q "^# Agent Instructions" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
grep -q "^## Structure" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
grep -q "^## Loading Order" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
grep -q "^## Functional Categories" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
grep -q "^## Using Skills" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
grep -qiE "##.*CDR\.md" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
```

#### Step 3: Auto-Repair

| Status | Action |
|--------|--------|
| **Missing** | Create from `templates/agents-template.md` |
| **Corrupted** (missing sections) | Overwrite with template |
| **Valid** | No changes |

If `--dry-run`:
```markdown
### AGENTS.md Status: {MISSING|CORRUPTED|VALID}

**Action**: {Would create|Would overwrite|No changes needed}
```

Otherwise, execute repair:
```bash
cp "templates/agents-template.md" "{TEAM_AI_DIRECTIVE}/AGENTS.md"
```

#### Step 4: Track Results

Store for summary:
```json
{
  "agents_md": {
    "status": "VALID|CREATED|OVERWRITTEN",
    "action": "No changes|Created from template|Re-created from template"
  }
}
```

#### Step 5: Inject Project-Level AGENTS.md Directive

After repairing the team AI directives' own `AGENTS.md`, also ensure the **project-level** `AGENTS.md` (at `{REPO_ROOT}/AGENTS.md`) contains the team-boot strict-compliance directive. This is what tells agents to invoke `team-boot` at session start.

If Check 8 returned `[WARN]` or `[INFO]`, run the injection:

```bash
bash "team-helpers.sh" --inject-agents "{REPO_ROOT}"
# or: pwsh team-helpers.ps1 -InjectAgents "{REPO_ROOT}"
```

If `--dry-run`:
```markdown
### Project AGENTS.md Status: {WARN|INFO}

**Action**: Would inject team AI directives managed section into {REPO_ROOT}/AGENTS.md
```

Otherwise, execute the injection. The function is idempotent — if the managed section already exists (between `<!-- TEAM_AI_DIRECTIVES START -->` and `<!-- TEAM_AI_DIRECTIVES END -->` markers), it replaces the section in place rather than duplicating.

Store for summary:
```json
{
  "project_agents_md": {
    "status": "VALID|INJECTED|UPDATED",
    "action": "No changes|Created with managed section|Updated managed section"
  }
}
```

### Phase 4: Scan Context Modules for CDR.md Reindex

**Objective**: Find all context modules and extract metadata

**Skip if**: `--skills-only` or `--agents-only` flag provided

#### Step 1: Find All Context Module Files

```bash
find "{TEAM_AI_DIRECTIVE}/context_modules/rules" -name "*.md" -type f 2>/dev/null
find "{TEAM_AI_DIRECTIVE}/context_modules/personas" -name "*.md" -type f 2>/dev/null
find "{TEAM_AI_DIRECTIVE}/context_modules/examples" -name "*.md" -type f 2>/dev/null
```

Skip `constitution.md` (not indexed in CDR.md).

#### Step 2: Extract YAML Frontmatter

For each file, parse YAML frontmatter:

```yaml
---
id: rule-python-error-handling
cdr_ref: CDR-2026-001
created: 2026-04-15
modified: 2026-05-18
verified: 2026-05-18
age_days: 33
evidence:
  - commit: abc123
  - file: src/errors.py
---
```

Extraction logic:
1. Read file content
2. Check if starts with `---`
3. Parse YAML between `---` markers
4. Extract: `id`, `cdr_ref`, `created`, `modified`, `verified`, `age_days`

#### Step 2a: Build CDR Lookup from Existing CDR.md

Before generating new frontmatter, read the existing CDR.md to find pre-existing CDR references for orphan files.

Parse the CDR.md index table to build a mapping of `{relative_file_path → cdr_ref}`:

```bash
# Read existing CDR.md and extract file path -> CDR reference mappings
CDR_LOOKUP=()
if [[ -f "{TEAM_AI_DIRECTIVE}/CDR.md" ]]; then
    while IFS='|' read -r _ id module _ _ _ _ _; do
        id="${id// /}"
        module="${module// /}"
        if [[ -n "$id" && -n "$module" && "$id" =~ ^CDR- ]]; then
            CDR_LOOKUP["$module"]="$id"
        fi
    done < <(grep "| CDR-" "{TEAM_AI_DIRECTIVE}/CDR.md")
fi
```

This creates an associative array:
```
context_modules/rules/style-guides/java/google_style_guide.md → CDR-2026-023
```

#### Step 3: Detect Orphans (No Frontmatter)

Files with `.md` extension but no YAML frontmatter.

For each orphan:
1. Generate `id` from filename:
   - Strip the context type directory prefix (`rules/`, `personas/`, `examples/`)
   - Remove `.md` extension, replace `/` with `-`, prepend type prefix
   - Example: `rules/python/new-pattern.md` → strip `rules/` → `python/new-pattern.md` → `rule-python-new-pattern`
   - Example: `personas/architect.md` → strip `personas/` → `architect.md` → `persona-architect`
2. Determine context type from path:
   - `rules/` → `Rule`
   - `personas/` → `Persona`
   - `examples/` → `Example`
3. Compute the file's relative path from `TEAM_AI_DIRECTIVE` and look it up in `CDR_LOOKUP`:
   - If found, use the existing `cdr_ref`
   - If not found, set `cdr_ref: null`
4. Generate `title` from filename (humanize the basename)
5. Generate `description` from first paragraph or filename
6. Generate `tags` from path segments (e.g., `rules/python/` → `[python]`)
7. Set default metadata:
    ```yaml
    type: {context-type}
    title: {generated-title}
    description: {generated-description}
    tags: {generated-tags}
    timestamp: {today}T00:00:00Z
    id: {generated-id}
    cdr_ref: {from CDR_LOOKUP or null}
    created: {today}
    modified: {today}
    verified: {today}
    age_days: 0
    evidence: []
    ```

If `--dry-run`:
```markdown
### Orphan Files Detected

| File | Generated ID | Existing CDR Ref | Action |
|------|--------------|-----------------|--------|
| rules/python/new-pattern.md | rule-python-new-pattern | CDR-2026-023 | Would add frontmatter (preserving CDR ref) |
| personas/architect.md | persona-architect | null | Would add frontmatter |
```

Otherwise, auto-fix:
1. Read file content
2. Prepend generated YAML frontmatter
3. Write back to file

#### Step 4: Build Context Module Index

Create index structure:

```json
{
  "context_modules": [
    {
      "file": "context_modules/rules/python/error-handling.md",
      "id": "rule-python-error-handling",
      "cdr_ref": "CDR-2026-001",
      "type": "Rule",
      "created": "2026-04-15",
      "verified": "2026-05-18",
      "age_days": 33,
      "descriptor": "Python error handling patterns and best practices"
    }
  ],
  "orphans": [
    {
      "file": "context_modules/rules/python/new-pattern.md",
      "id": "rule-python-new-pattern",
      "repaired": true
    }
  ]
}
```

#### Step 5: Generate index.md and log.md Per Directory

Generate OKF-compliant `index.md` (progressive disclosure) and `log.md` (chronological history) for each context module directory that has entries.

**index.md** — lists all files in the directory with type/title/description:

```markdown
# Rules

| File | Type | Description | Tags |
|------|------|-------------|------|
| [python/error-handling.md](python/error-handling.md) | Rule | Python error handling patterns and best practices | python |
| [frontend/version-modal.md](frontend/version-modal.md) | Rule | Version modal display rules | frontend |
```

Generate `{TEAM_AI_DIRECTIVE}/context_modules/rules/index.md`, `context_modules/personas/index.md`, `context_modules/examples/index.md`, and `context_modules/index.md` (toplevel index linking all sub-indexes).

**log.md** — chronological log of additions and changes:

```markdown
# Rules Log

| Date | Action | File | CDR |
|------|--------|------|-----|
| 2026-07-21 | Added | python/error-handling.md | CDR-2026-001 |
| 2026-07-21 | Verified | frontend/version-modal.md | CDR-2026-002 |
```

Generate `{TEAM_AI_DIRECTIVE}/context_modules/rules/log.md`, `context_modules/personas/log.md`, `context_modules/examples/log.md`.

If `--dry-run`:
```markdown
### index.md / log.md Preview

| Directory | index.md | log.md |
|-----------|----------|--------|
| rules/ | Would generate ({N} entries) | Would generate ({N} entries) |
| personas/ | Would generate ({N} entries) | Would generate ({N} entries) |
| examples/ | Would generate ({N} entries) | Would generate ({N} entries) |
```

Otherwise, write each file.

### Phase 5: Scan Skills for .skills.json Reindex

**Objective**: Find all skills and build manifest entries

**Skip if**: `--cdr-only` or `--agents-only` flag provided

#### Step 1: Find All Skill Directories

```bash
find "{TEAM_AI_DIRECTIVE}/skills" -mindepth 1 -maxdepth 1 -type d
```

#### Step 2: Check Each Skill

For each skill directory:

1. Check `SKILL.md` exists (required)
2. Check `.skills-entry.json` exists (optional)
3. Parse SKILL.md for metadata

#### Step 3: Extract Skill Metadata

From `SKILL.md`:
- **Description**: First paragraph after title
- **Categories**: Look for `## Categories` or `## Trigger Keywords` section
- **Instruction Type**: Look for `**Instruction Type**:` line

#### Step 4: Generate .skills.json Entry

```json
{
  "local:./skills/{skill-name}": {
    "version": "1.0.0",
    "description": "{extracted from SKILL.md first paragraph}",
    "categories": ["{from SKILL.md}"],
    "instruction_type": "{from SKILL.md}"
  }
}
```

#### Step 5: Detect Orphans

Skills with `SKILL.md` but no entry in `.skills.json`.

If `--dry-run`:
```markdown
### Orphan Skills Detected

| Skill | Action |
|-------|--------|
| code-review | Would add to .skills.json |
| deployment | Would add to .skills.json |
```

Otherwise, auto-generate entry.

#### Step 6: Detect Missing Files

Entries in `.skills.json` where skill directory doesn't exist.

Auto-remove invalid entries.

#### Step 7: Build Skills Index

```json
{
  "skills": [
    {
      "name": "code-review",
      "path": "skills/code-review/",
      "has_skill_md": true,
      "has_entry": false,
      "repaired": true
    }
  ],
  "missing_removed": 1
}
```

### Phase 6: Rebuild CDR.md

**Objective**: Generate fresh CDR.md from scanned context modules

**Skip if**: `--skills-only` or `--agents-only` flag provided

#### Step 1: Generate CDR Index Table

From scanned context modules, build index:

```markdown
# Context Directive Records

Context Directive Records (CDRs) track decisions about contributing context modules (rules, personas, examples, skills) to team-ai-directives.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|
| CDR-2026-001 | context_modules/rules/python/error-handling.md | Rule | Accepted | 2026-04-15 | 2026-05-18 | 33d | Python error handling patterns and best practices |
| rule-python-new-pattern | context_modules/rules/python/new-pattern.md | Rule | Auto-generated | 2026-05-22 | 2026-05-22 | 0d | (auto-generated — edit descriptor at first publish) |

**Stats**: {N} entries | Last Updated: {date}

---

## CDR-2026-001: {Title from context module}

### Status
**Accepted**

### Target Module
`context_modules/rules/python/error-handling.md`

### Descriptor
{One-line "when to use" summary derived from file content or frontmatter description. This becomes the search surface for the `team-discover` command.}

### Evidence
{From YAML frontmatter}

---

{Repeat for each entry}
```

#### Step 2: Write CDR.md

If `--dry-run`:
```markdown
### CDR.md Preview

Would write {N} entries to CDR.md
```

Otherwise:
```bash
cat > "{TEAM_AI_DIRECTIVE}/CDR.md" << 'EOF'
{generated content}
EOF
```

### Phase 7: Rebuild .skills.json

**Objective**: Generate fresh .skills.json from scanned skills

**Skip if**: `--cdr-only` or `--agents-only` flag provided

#### Step 1: Generate Skills Manifest

```json
{
  "skills": {
    "local:./skills/code-review": {
      "version": "1.0.0",
      "description": "Review code following team standards and best practices",
      "categories": ["review", "quality"],
      "instruction_type": "Review"
    }
  }
}
```

#### Step 2: Write .skills.json

If `--dry-run`:
```markdown
### .skills.json Preview

Would write {N} skill entries
```

Otherwise:
```bash
cat > "{TEAM_AI_DIRECTIVE}/.skills.json" << 'EOF'
{generated JSON}
EOF
```

### Phase 8: Conflict Scanning

**Objective**: Scan team-ai-directives rules for contradictions and overlaps.

**Skip if**: `--skills-only`, `--agents-only`, or `--freshness` flag provided.

#### Step 1: Load Rules and Constitution

Load:
- `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md`
- `{TEAM_AI_DIRECTIVE}/context_modules/rules/**/*.md`

#### Step 2: Detect Conflicts

Conflict levels:

| Level | Pattern | Severity |
|---|---|---|
| Direct Contradiction | `must X` vs `never X` | CRITICAL |
| Implicit Contradiction | Numeric/logical impossibility | ERROR |
| Exception Conflict | Base rule vs exception | WARNING |
| Scope Overlap | Overlapping rules | INFO |
| Constitution Conflict | Rule vs principle | CRITICAL |

Use `levelup-helpers.sh` conflict detection or implement inline:

```bash
skills/team/levelup-helpers.sh --conflicts "$TEAM_AI_DIRECTIVE/context_modules/rules"
```

#### Step 3: Create Conflict CDRs

For each conflict, create a CDR in `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md`:

```markdown
## CDR-{NNN}: Resolve Rule Conflict: {title}

### Status
**Discovered**

### Date
{today}

### Source
Rule conflict detection via /team-repair --validate

### Target Module
`context_modules/rules/{domain}/`

### Context Type
Rule

### Context
**Conflict Details**:
- Rule A: {path} — "{statement}"
- Rule B: {path} — "{statement}"
- Type: {critical|error|warning|info}

### Decision
**Proposed Resolution**:
1. Add exception
2. Edit rule to avoid conflict
3. Mark intentional
4. Deprecate one rule
```

Regenerate the local CDR index.

Handoff: if conflict CDRs created, suggest `/levelup-clarify`.

### Phase 9: Freshness Verification

**Objective**: Update `verified` timestamps for valid directives and flag stale ones.

**Skip if**: `--skills-only`, `--agents-only`, or `--conflicts` flag provided.

#### Step 1: Identify Valid Directives

For each context module file (rules, personas, examples, constitution) and skill SKILL.md:
- If no conflicts detected for this file → eligible for verification update
- If conflicts detected → skip (will be resolved via conflict CDRs)

#### Step 2: Update Verification Metadata

For each eligible directive:

1. Parse YAML frontmatter
2. Update `verified` to today's date
3. Update `timestamp` to current ISO 8601 datetime
4. Reset `age_days` to 0
5. Append to verification log table:

```markdown
| Date | Verified By | Notes |
|---|---|---|
| {today} | /team-repair --validate | Validation passed, no conflicts |
```

#### Step 3: Report Stale Directives

Flag directives with `age_days` > 30 or whose `verified` date is older than 30 days.

```markdown
### Stale Directives

| File | Age | Last Verified |
|---|---|---|
| rules/old-pattern.md | 45d | 2026-04-01 |
```

### Phase 10: Summary Report

```markdown
## Team Repair Summary

**Date**: {date}
**Team Directives**: {path}
**Mode**: {DRY RUN|LIVE}

### AGENTS.md Repair

| Status | Action |
|--------|--------|
| {VALID|CREATED|OVERWRITTEN} | {No changes needed|Created from template|Re-created from template} |

### CDR.md Repair

| Action | Count |
|--------|-------|
| Files scanned | {n} |
| Valid entries | {n} |
| Orphans repaired | {n} |
| Missing removed | {n} |

### .skills.json Repair

| Action | Count |
|--------|-------|
| Skills scanned | {n} |
| Valid entries | {n} |
| Orphans repaired | {n} |
| Missing removed | {n} |

### Conflict Scanning

| Metric | Count |
|---|---|
| Conflicts detected | {n} |
| Conflict CDRs created | {n} |
| Critical | {n} |
| Error | {n} |
| Warning | {n} |
| Info | {n} |

### Freshness Verification

| Metric | Count |
|---|---|---|
| Directives updated | {n} |
| Stale directives (>30d) | {n} |
| Skipped (has conflicts) | {n} |

### OKF index.md / log.md

| Directory | index.md | log.md |
|-----------|----------|--------|
| context_modules/ | {written|skipped} | {written|skipped} |
| rules/ | {written|skipped} ({n} entries) | {written|skipped} ({n} entries) |
| personas/ | {written|skipped} ({n} entries) | {written|skipped} ({n} entries) |
| examples/ | {written|skipped} ({n} entries) | {written|skipped} ({n} entries) |

### Files Modified

| File | Change |
|------|--------|
| {file} | {change description} |

{If --dry-run:}
> **Note**: Dry run mode - no files were modified

### Next Steps

1. Review repaired files
2. If conflict CDRs were created, run `/levelup-clarify` to resolve them
3. Commit changes if satisfied
```

### Notes

- **Auto-fix**: Always repairs issues automatically (no confirmation needed)
- **Dry run**: Use `--dry-run` to preview changes without writing
- **Selective repair**: Use `--cdr-only`, `--skills-only`, or `--agents-only` for specific targets
- **Validation modes**: `--validate` runs conflict scan + freshness; `--conflicts` and `--freshness` run each separately
- **YAML frontmatter**: Auto-generated for orphan context modules
- **Skills entries**: Auto-generated from SKILL.md content
- **AGENTS.md**: Overwrites if corrupted (missing required sections)
- **Idempotent**: Re-running produces same result

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The indexes look fine — no need to reindex." | Orphaned files and missing frontmatter are invisible without a full directory scan. |
| "I'll just hand-edit CDR.md to add the missing row." | Manual edits drift from actual content; a rebuild guarantees the index matches the filesystem. |
| "Dry run is unnecessary — just write the changes." | A dry run surfaces unexpected orphans and null CDR refs before any file is mutated. |
| "AGENTS.md looks valid, so I'll skip Phase 2." | Missing sections can be subtle (e.g., a renamed heading). Validation is cheap and idempotent. |
| "Skipping Step 5 — the project AGENTS.md is not my job." | The team AI directives' own AGENTS.md describes structure; the project-level AGENTS.md is what tells agents to invoke `team-boot` at session start. Without it, the directives remain invisible. |
| "I can skip the CDR_LOOKUP step for orphans." | Without the lookup, existing CDR refs are lost and orphaned entries get `cdr_ref: null`, breaking traceability. |
| "I'll just jump to the repair — no need for a health check first." | Phase 0 exists precisely because an unhealthy framework makes repairs dangerous or meaningless. Run it. |
| "A `[WARN]` on Phase 0 is basically an `[OK]`." | Warnings are non-blocking for exit code but often signal drift that becomes a `[FAIL]` later. Track warnings across runs. |

## Red Flags

- **Overwriting AGENTS.md without validating structure first** — a "corrupted" verdict should require evidence of missing sections, not a hunch; otherwise custom content is destroyed.
- **Generating `cdr_ref: null` when an existing CDR_LOOKUP entry exists** — this silently severs the audit trail between a context module and its accepted CDR record.
- **Skipping the dry run when the orphan count is high** — bulk auto-fix without review leads to fabricated IDs and metadata propagating into version control.
- **Writing `.skills.json` entries without parsing the actual `SKILL.md`** — fabricated descriptions and categories make skills unsearchable and misrepresent capabilities.
- **Proceeding past Phase 2 when `TEAM_AI_DIRECTIVE` is empty** — operating without a configured repository writes to undefined paths and corrupts the wrong workspace.
- **Skipping Phase 0 Health Check** — jumping straight into repairs without verifying the framework is installed risks writing to an absent or misconfigured workspace.
- **Skipping Step 5 (project AGENTS.md injection)** — the team AI directives' own `AGENTS.md` describes its structure, but the **project-level** `AGENTS.md` is what tells agents to invoke `team-boot` at session start. Without it, agents have no session-start instruction and the team AI directives remains invisible until manually loaded.

## Verification

- [ ] Phase 0 Health Check passes all 8 checks (no `[FAIL]`) before any repair is attempted.
- [ ] AGENTS.md exists at `{TEAM_AI_DIRECTIVE}/AGENTS.md` and contains all six required sections.
- [ ] Project-level `AGENTS.md` at `{REPO_ROOT}/AGENTS.md` contains the `<!-- TEAM_AI_DIRECTIVES START -->` managed section with the `team-boot` strict-compliance directive.
- [ ] CDR.md entry count equals the number of scanned context module `.md` files (excluding `constitution.md`).
- [ ] Every context module file under `context_modules/{rules,personas,examples}/` has YAML frontmatter with a non-empty `id` field.
- [ ] Every `cdr_ref` in orphan frontmatter matches the pre-existing CDR lookup (no regression to `null` where a prior ref existed).
- [ ] Every skill directory containing a `SKILL.md` has a corresponding entry in `.skills.json`.
- [ ] No `.skills.json` entry references a skill directory that does not exist on disk.
- [ ] The summary report lists non-zero counts for "Files scanned" / "Skills scanned" and shows consistent totals.
- [ ] Re-running the skill with no flags produces zero "Files Modified" entries (idempotency check).
- [ ] Conflict scan completed (if not skipped) and conflict CDRs created for any findings.
- [ ] Freshness verification completed (if not skipped) and stale directives reported.
- [ ] No rule contradictions remain unreported after `--validate`.

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `team-ai-directives/` relative to project root.
- `team-helpers.sh` / `team-helpers.ps1` — Shared scripts used for path resolution.

## 12-Factor Alignment

Factor XI (Directives as Code) — maintains integrity of version-controlled team directives.
