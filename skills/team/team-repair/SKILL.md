---
name: team-repair
description: Re-index OKF v0.2 index.md/log.md files, derive CDR.md, rebuild .skills.json and AGENTS.md in team-ai-directives, migrate v0.1→v0.2 frontmatter, scan for rule conflicts, and verify directive freshness. Use when indexes are inconsistent, orphans are detected, after bulk changes, or for periodic team AI directives health validation.
disable-model-invocation: true
---

# team-repair

## Overview

Re-indexes OKF v0.2 artifacts (`index.md`, `log.md`), derives the flat `CDR.md` inject, rebuilds `.skills.json` and `AGENTS.md` in team-ai-directives to fix inconsistencies, detect orphaned files, and auto-repair issues. Migrates OKF v0.1 frontmatter to v0.2 on every run (always-on, no opt-out). Begins with a health-check phase (Phase 0) that verifies the directives framework is installed, configured, and aligned before performing any repairs.

**Input**: team-ai-directives repository

**Output**:
0. Health check report (7 checks: team AI directives configured, context modules exist, skills registry, OKF log tracking, constitution alignment, OKF v0.2 type field presence, project AGENTS.md directive)
1. Repaired AGENTS.md (if missing or corrupted)
2. Migrated all context module frontmatter from OKF v0.1 to v0.2 (always-on)
3. Rebuilt per-directory `index.md` files (OKF §8 catalog)
4. Rebuilt per-directory `log.md` files (OKF §9 audit trail)
5. Derived `CDR.md` flat table from `index.md` files (for team-boot system prompt injection)
6. Rebuilt .skills.json manifest from skills/
7. Auto-added OKF v0.2 YAML frontmatter to orphan context modules
8. Auto-generated .skills.json entries for orphan skills
9. Conflict scan across rules (creates conflict CDRs if issues found)
10. Freshness verification (updates `verified` timestamps, flags stale directives)
11. Summary report of all repairs

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
| **AGENTS.md** | `{TEAM_AI_DIRECTIVES}/AGENTS.md` | Main instruction file for AI agents |
| **index.md** | `{TEAM_AI_DIRECTIVES}/context_modules/**/index.md` | OKF §8 per-directory catalogs (progressive disclosure) |
| **log.md** | `{TEAM_AI_DIRECTIVES}/context_modules/**/log.md` | OKF §9 per-directory audit trails |
| **CDR.md** | `{TEAM_AI_DIRECTIVES}/CDR.md` | Derived flat table for team-boot system prompt injection (auto-generated from index.md files) |
| **.skills.json** | `{TEAM_AI_DIRECTIVES}/.skills.json` | Skills manifest registry |

## When to Use

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `""` - Repair all three indexes (default)
- `"--dry-run"` - Report only, don't write changes
- `"--index-only"` - Only rebuild OKF index.md + log.md + derive CDR.md
- `"--skills-only"` - Only repair .skills.json
- `"--agents-only"` - Only repair AGENTS.md
- Empty input: Repair all indexes with auto-fix (includes v0.1→v0.2 migration)

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Report only, don't write changes |
| `--health-only` | Run Phase 0 health check only, then stop. |
| `--validate` | Run conflict scan + freshness verification only (Phases 8-9) |
| `--conflicts` | Scan for rule conflicts only |
| `--freshness` | Verify directive freshness only |
| `--build-to-delete` | Run evals without directives to identify candidates for removal (Factor XII) |
| `--index-only` | Only rebuild OKF index.md + log.md + derive CDR.md |
| `--skills-only` | Only repair .skills.json |
| `--agents-only` | Only repair AGENTS.md |
| (default) | Repair all indexes + migrate v0.1→v0.2 + validate conflicts and freshness |

## Core Process

### Phase 0: Health Check

**Objective**: Run a non-destructive health check against the team directives framework before proceeding with repairs. If any check returns `[FAIL]`, present the report and stop — the framework is not healthy enough to repair safely.

Execute all seven checks below. Each check prints a status line. If any check is `[FAIL]`, abort repair.

#### Check 1: Team AI Directives Configured

1. Read `.adlc/init-options.json`
2. Verify `team_ai_directives` field exists and points to valid path
3. Check the team AI directives path exists

Output: `[OK]` or `[FAIL]` with reason

#### Check 2: Context Modules Exist

1. Read `.adlc/init-options.json` → get team AI directives path
2. Verify:
   - `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md`
   - `{TEAM_AI_DIRECTIVES}/context_modules/personas/`
   - `{TEAM_AI_DIRECTIVES}/context_modules/rules/`
   - `{TEAM_AI_DIRECTIVES}/context_modules/examples/`

Output: `[OK]` or `[FAIL]` with reason

#### Check 3: Skills Registry

- `{TEAM_AI_DIRECTIVES}/.skills.json` exists and is valid JSON

Output: `[OK]` or `[FAIL]` with reason

#### Check 4: OKF Log Tracking

- `{TEAM_AI_DIRECTIVES}/context_modules/rules/log.md` exists
- `{TEAM_AI_DIRECTIVES}/context_modules/personas/log.md` exists
- `{TEAM_AI_DIRECTIVES}/context_modules/examples/log.md` exists
- `{TEAM_AI_DIRECTIVES}/CDR.md` exists (derived artifact)

Output: `[OK]` or `[FAIL]` with reason

#### Check 5: Constitution Alignment

1. Read team constitution from `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md`
2. Locate project constitution: the project root (where `.adlc/` lives) → `{REPO_ROOT}/.adlc/memory/constitution.md`
3. If project constitution exists:
   - Check if it references team-ai-directives (e.g., "Based on team-ai-directives", "Inherits from")
   - Check if team principles are present in project constitution (compare principle titles)
   - Output:
     - `[OK]` — Project constitution exists and inherits team principles
     - `[WARN]` — Project constitution exists but missing team inheritance
4. If project constitution doesn't exist:
   - `[INFO]` — Project constitution doesn't exist yet (first-time setup)

#### Check 6: OKF v0.2 Conformance

1. Scan all `.md` files in `context_modules/` (excluding `index.md`, `log.md`)
2. Parse YAML frontmatter from each file
3. Verify `type` field is present and has a valid value:
   - Valid types: `Constitution`, `Persona`, `Rule`, `Example`, `Skill`
4. Verify OKF v0.2 fields (migrate if v0.1 detected):
   - `generated: { by, at }` present (not legacy `timestamp`)
   - `verified` is a list format (not bare string)
   - `status` present (e.g., `stable`, `draft`, `deprecated`)
   - `stale_after` present (e.g., `180d`)
5. Output:
   - `[OK]` — All concept files have valid `type` fields and v0.2 families
   - `[WARN]` — Some files missing v0.2 fields or still carry v0.1 fields (will be migrated in Phase 4)

#### Check 7: Project AGENTS.md Directive

1. Read `{REPO_ROOT}/AGENTS.md` (the project-level agent instructions file)
2. Check if it contains the `<!-- TEAM_AI_DIRECTIVES START -->` marker
3. If the marker exists, verify the managed section includes:
   - A `team-boot` invocation directive
   - A reference to team AI directives context (constitution, CDR index)
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
- **`{TEAM_AI_DIRECTIVES}/.skills.json` is missing or not valid JSON**: skill discovery is broken; agents cannot find team skills even if the files exist.
- **Project constitution exists but shows no team inheritance** (`[WARN]` on Check 5): the project was bootstrapped without the team AI directives, or the constitution was hand-edited and the inheritance markers were removed.
- **Multiple checks return `[WARN]` simultaneously**: systemic drift, usually from a moved `.adlc/` directory or a reconfigured team AI directives path. Treat as a `[FAIL]`-equivalent and re-init.

---

### Phase 1: Environment Setup

**Objective**: Resolve paths and validate infrastructure

Run `$(dirname "$0")/team-helpers.sh --json` (or the PowerShell equivalent) to resolve paths and parse JSON output:

```json
{
  "REPO_ROOT": "/path/to/project",
  "TEAM_AI_DIRECTIVES": "/path/to/team-ai-directives",
  "BRANCH": "current-branch"
}
```

`{REPO_ROOT}` is the project root (where `.adlc/` lives). Subsequent references use `{REPO_ROOT}`.

### Phase 2: Validate Environment

**Objective**: Ensure team-ai-directives is configured

Check if TEAM_AI_DIRECTIVES has a value from script output.

If empty, **STOP**:
```
Team AI directives repository not configured.
Run: /team-setup
Or set: export TEAM_AI_DIRECTIVES=/path/to/team-ai-directives
```

### Phase 3: Repair AGENTS.md

**Objective**: Ensure AGENTS.md exists with required structure

**Skip if**: `--index-only` or `--skills-only` flag provided

#### Step 1: Check AGENTS.md Exists

```bash
test -f "{TEAM_AI_DIRECTIVES}/AGENTS.md" && echo "EXISTS" || echo "MISSING"
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
grep -q "^# Agent Instructions" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
grep -q "^## Structure" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
grep -q "^## Loading Order" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
grep -q "^## Functional Categories" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
grep -q "^## Using Skills" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
grep -qiE "##.*CDR\.md" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
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
cp "templates/agents-template.md" "{TEAM_AI_DIRECTIVES}/AGENTS.md"
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
bash "$(dirname "$0")/team-helpers.sh" --inject-agents "{REPO_ROOT}"
# or: pwsh "$(Split-Path $PSCommandPath -Parent)/team-helpers.ps1" -InjectAgents "{REPO_ROOT}"
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
find "{TEAM_AI_DIRECTIVES}/context_modules/rules" -name "*.md" -type f 2>/dev/null
find "{TEAM_AI_DIRECTIVES}/context_modules/personas" -name "*.md" -type f 2>/dev/null
find "{TEAM_AI_DIRECTIVES}/context_modules/examples" -name "*.md" -type f 2>/dev/null
```

Skip `constitution.md` (not indexed in CDR.md).

#### Step 2: Extract YAML Frontmatter

For each file, parse YAML frontmatter (OKF v0.2 form after migration):

```yaml
---
type: Rule
title: Python error handling
description: Python error handling patterns and best practices
tags: [python, error-handling]
resource: ./context_modules/rules/python/error-handling.md
generated: { by: agent:legacy, at: 2026-04-15T00:00:00Z }
id: rule-python-error-handling
cdr_ref: CDR-2026-001
created: 2026-04-15
verified:
  - { by: process:team-repair, at: 2026-05-18T00:00:00Z }
status: stable
stale_after: 180d
sources:
  - id: commit-abc123
    resource: src/errors.py
    title: Error handling implementation
---
```

Extraction logic:
1. Read file content
2. Check if starts with `---`
3. Parse YAML between `---` markers
4. Extract: `id`, `cdr_ref`, `created`, `type`, `title`, `description`, `tags`, `generated.at`, `verified` (latest `at`), `status`

#### Step 2a: Build CDR Lookup from Existing CDR.md

Before generating new frontmatter, read the existing CDR.md to find pre-existing CDR references for orphan files.

Parse the CDR.md index table to build a mapping of `{relative_file_path → cdr_ref}`:

```bash
# Read existing CDR.md and extract file path -> CDR reference mappings
CDR_LOOKUP=()
if [[ -f "{TEAM_AI_DIRECTIVES}/CDR.md" ]]; then
    while IFS='|' read -r _ id module _ _ _ _ _; do
        id="${id// /}"
        module="${module// /}"
        if [[ -n "$id" && -n "$module" && "$id" =~ ^CDR- ]]; then
            CDR_LOOKUP["$module"]="$id"
        fi
    done < <(grep "| CDR-" "{TEAM_AI_DIRECTIVES}/CDR.md")
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
3. Compute the file's relative path from `TEAM_AI_DIRECTIVES` and look it up in `CDR_LOOKUP`:
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
    resource: {relative-path}
    generated: { by: agent:team-repair, at: {today}T00:00:00Z }
    id: {generated-id}
    cdr_ref: {from CDR_LOOKUP or null}
    created: {today}
    verified:
      - { by: agent:team-repair, at: {today}T00:00:00Z }
    status: stable
    stale_after: 180d
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

#### Step 3b: Migrate v0.1 Frontmatter to v0.2 (Always-On)

For every `.md` file in `context_modules/` (excluding `index.md`, `log.md`) that has existing frontmatter, detect and migrate v0.1 fields to v0.2. This runs on every `team-repair` invocation — no flag, no opt-out.

**Migration rules** (idempotent — skip if already v0.2):

| Detection | Action |
|---|---|
| `timestamp:` present, `generated:` absent | Rewrite to `generated: { by: agent:legacy, at: <timestamp value> }`, delete `timestamp` |
| `timestamp:` present, `generated:` present | Delete `timestamp` (v0.2 takes precedence) |
| `verified:` is a bare string (not a list) | Rewrite to `verified: [{ by: process:team-repair, at: <value>T00:00:00Z }]` |
| `evidence:` present with entries | Map each entry to `sources[]` entry (`id`, `resource`, `title`), delete `evidence` |
| `evidence: []` (empty list) | Delete field, omit `sources` |
| `modified:` present | Delete (redundant with `generated.at`) |
| `age_days:` present | Delete (derived at render time) |
| `status:` absent | Add `status: stable` |
| `stale_after:` absent | Add `stale_after: 180d` |
| `resource:` absent | Add from file relative path |
| `generated` already present, no v0.1 fields | Skip (already v0.2) |

Preserve custom fields (`id`, `cdr_ref`, `created`, `type`, `title`, `description`, `tags`) as-is per OKF §4.1.

If `--dry-run`:
```markdown
### v0.1 → v0.2 Migration Preview

| File | Fields Migrated | Fields Added | Fields Removed |
|------|----------------|--------------|----------------|
| rules/security/sql_injection_prevention.md | timestamp→generated, verified→list | status, stale_after, resource | modified, age_days, evidence |
```

Otherwise, rewrite frontmatter in place for each file.

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
      "generated_at": "2026-04-15T00:00:00Z",
      "verified_at": "2026-05-18T00:00:00Z",
      "status": "stable",
      "stale_after": "180d",
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

### Phase 5: Scan Skills for .skills.json Reindex

**Objective**: Find all skills and build manifest entries

**Skip if**: `--index-only` or `--agents-only` flag provided

#### Step 1: Find All Skill Directories

```bash
find "{TEAM_AI_DIRECTIVES}/skills" -mindepth 1 -maxdepth 1 -type d
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

### Phase 6: Rebuild OKF index.md + log.md + Derive CDR.md

**Objective**: Generate OKF v0.2 per-directory `index.md` (§8) and `log.md` (§9) files from scanned context modules, then derive the flat `CDR.md` table from the index.md data for team-boot system prompt injection.

**Skip if**: `--skills-only` or `--agents-only` flag provided

#### Step 1: Rebuild Per-Directory index.md (OKF §8)

For each subdirectory (`rules/`, `personas/`, `examples/`) and the `context_modules/` root, generate an `index.md` file in OKF §8 list format.

**`context_modules/index.md`** (root — carries `okf_version`):

```markdown
---
okf_version: "0.2"
---

# Context Modules

* [Rules](rules/index.md) - Team rules and workflows
* [Personas](personas/index.md) - Team personas
* [Examples](examples/index.md) - Team examples
```

**`context_modules/rules/index.md`** (per-type catalog):

```markdown
# Rules

* [Prevent SQL Injection](security/sql_injection_prevention.md) - Standards for preventing SQL injection vulnerabilities across all languages
* [Dependency Injection](architecture/dependency_injection.md) - Dependency injection patterns for maintainable code
```

Entries are derived from each module's frontmatter `title` and `description`. Sort alphabetically by title within each directory. If a module lacks `description`, derive from first body paragraph.

Personas and Examples follow the same pattern with `# Personas` and `# Examples` headings.

#### Step 2: Rebuild Per-Directory log.md (OKF §9)

For each subdirectory, generate a `log.md` file in OKF §9 date-grouped format (newest first).

**`context_modules/rules/log.md`**:

```markdown
# Rules Update Log

## 2026-05-23
* **Creation**: Added [Dependency Injection](architecture/dependency_injection.md) — Dependency injection patterns for maintainable code. CDR: CDR-2026-008.
* **Verification**: Verified [SQL Injection Prevention](security/sql_injection_prevention.md). CDR: CDR-2026-021.

## 2026-05-21
* **Creation**: Added [SQL Injection Prevention](security/sql_injection_prevention.md) — Standards for preventing SQL injection. CDR: CDR-2026-021.
```

Log entries are derived from:
1. Git history: `git log --diff-filter=A --format="%ai %s" -- <file>` for creation dates
2. Frontmatter `verified` timestamps for verification entries
3. Existing `log.md` content (preserve manual entries, append new)

**`context_modules/log.md`** (root — aggregate):

```markdown
# Context Modules Update Log

## 2026-08-12
* **Re-index**: Rebuilt all index.md and log.md files via /team-repair. Rules: {N} files, Personas: {N} files, Examples: {N} files.
```

#### Step 3: Derive CDR.md (Flat Table for team-boot)

From the per-directory `index.md` data + module frontmatter, derive a flat `CDR.md` table for team-boot system prompt injection.

**`{TEAM_AI_DIRECTIVES}/CDR.md`**:

```markdown
# Context Directive Records (Derived Index)

> ⚠️ Auto-generated by `/team-repair`. Do not edit manually.
> Source of truth: `context_modules/*/index.md` + module frontmatter.
> Decision lifecycle (Accepted/Rejected) lives in project `.adlc/drafts/cdr/`.

## CDR Index

| ID | Path | Type | Description | Generated | Verified | Age | Status |
|----|------|------|-------------|-----------|----------|-----|--------|
| CDR-2026-021 | context_modules/rules/security/sql_injection_prevention.md | Rule | Standards for preventing SQL injection... | 2026-06-14 | 2026-05-21 | 46d | stable |
| rule-frontend-routing | context_modules/rules/frontend/framework/frontend_routing.md | Rule | Client-side routing patterns... | 2026-06-15 | 2026-06-15 | 0d | stable |

**Stats**: {N} entries | Last Updated: {date}
```

**Columns**:
- `ID`: `cdr_ref` from frontmatter (or `id` if `cdr_ref` is null)
- `Path`: relative path from `TEAM_AI_DIRECTIVES`
- `Type`: `type` from frontmatter
- `Description`: `description` from frontmatter (truncated to 80 chars)
- `Generated`: `generated.at` date (YYYY-MM-DD)
- `Verified`: latest `verified[].at` date (YYYY-MM-DD)
- `Age`: days since `verified` date
- `Status`: `status` from frontmatter (or `stable` if absent)

#### Step 4: Write Files

If `--dry-run`:

```markdown
### OKF Files Preview

Would write:
- context_modules/index.md ({N} entries)
- context_modules/log.md
- context_modules/rules/index.md ({N} entries)
- context_modules/rules/log.md
- context_modules/personas/index.md ({N} entries)
- context_modules/personas/log.md
- context_modules/examples/index.md ({N} entries)
- context_modules/examples/log.md
- CDR.md ({N} derived entries)
```

Otherwise, write all 9 files.



**Objective**: Generate fresh .skills.json from scanned skills

**Skip if**: `--index-only` or `--agents-only` flag provided

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
cat > "{TEAM_AI_DIRECTIVES}/.skills.json" << 'EOF'
{generated JSON}
EOF
```

### Phase 8: Conflict Scanning

**Objective**: Scan team-ai-directives rules for contradictions and overlaps.

**Skip if**: `--skills-only`, `--agents-only`, or `--freshness` flag provided.

#### Step 1: Load Rules and Constitution

Load:
- `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md`
- `{TEAM_AI_DIRECTIVES}/context_modules/rules/**/*.md`

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
skills/levelup/levelup-helpers.sh --conflicts "$TEAM_AI_DIRECTIVES/context_modules/rules"
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
2. Append to `verified` list: `{ by: process:team-repair, at: {today}T00:00:00Z }`
3. Update `generated.at` if content changed during this repair run
4. Append verification entry to per-directory `log.md`:

```markdown
* **Verification**: Verified [{Title}](path) — no conflicts detected.
```

#### Step 3: Report Stale Directives

Flag directives whose latest `verified[].at` is older than `stale_after` (default 180d), or whose `status` is `deprecated`.

```markdown
### Stale Directives

| File | Last Verified | Age | Stale After | Status |
|---|---|---|---|---|
| rules/old-pattern.md | 2026-04-01 | 190d | 180d | stale |
```

### Phase 10: Build to Delete (Factor XII)

**Objective**: Identify directives that are no longer needed because baseline models handle them natively. This is the "Harness Decay" mechanism — run evals without directives; if the model passes independently, the directive is a candidate for removal.

**Skip if**: `--build-to-delete` flag is NOT provided.

**This phase makes LLM calls** — it runs goldenset cases against the agent to test whether directives are still needed.

#### Step 1: Load All Goldensets

Read all goldenset directories from `{TEAM_AI_DIRECTIVES}/evals/`:

```bash
ls -1 "$TEAM_AI_DIRECTIVES/evals/" 2>/dev/null
```

For each `{directive-id}` directory, read:
- `evals/{directive-id}/goldset.md` — human-readable cases
- `evals/{directive-id}/goldset.json` — machine-readable cases

If no goldensets exist, report: "No evals found — run /levelup-specify to create eval CDRs first." and skip this phase.

#### Step 2: Identify Paired Directives

For each goldenset, identify its paired directive:
- Read `paired_directive` from the goldenset frontmatter
- Read the directive file from `context_modules/` (e.g., `rules/security/sql_injection_prevention.md`)
- If the directive file doesn't exist → skip (already deleted or orphaned eval)

#### Step 3: Run Goldenset Without Directive

For each directive+eval pair:

1. **Temporarily remove the directive** from the context that would be loaded (simulate: the agent works without the rule)
2. **Run the goldenset cases** against the agent via LLM calls:
   - For each pass case: present the scenario and input context, ask the agent to produce output, check if it follows the (removed) directive
   - For each fail case: present the scenario and input context, ask the agent to produce output, check if it still makes the mistake
3. **Compute pass rate**: `cases_passed / total_cases`

#### Step 4: Classify Results

| Pass Rate | Verdict | Recommendation |
|---|---|---|
| 100% | **Delete candidate** | Model handles this natively — directive is obsolete |
| 80-99% | **Review candidate** | Model mostly handles it — consider simplifying the directive |
| < 80% | **Keep** | Model still needs the directive |

#### Step 5: Generate Harness Decay Report

```markdown
## Build to Delete Report

### Candidates for Removal (model passes 100% without directive)

| Directive | Eval | Pass Rate | Recommendation |
|---|---|---|---|
| rules/security/sql_injection.md | evals/CDR-001/ | 100% (6/6) | Delete — model handles this natively now |

### Review Candidates (80-99%)

| Directive | Eval | Pass Rate | Recommendation |
|---|---|---|---|
| rules/devops/helm_packaging.md | evals/CDR-008/ | 83% (5/6) | Simplify — model mostly handles it, 1 case failed |

### Still Needed (< 80%)

| Directive | Eval | Pass Rate | Recommendation |
|---|---|---|---|
| rules/style/python_pep8.md | evals/CDR-015/ | 40% (2/5) | Keep — model still needs guidance |
```

#### Step 6: Create Deletion CDRs

For each **Delete candidate** (100% pass rate), create a CDR in `{REPO_ROOT}/.adlc/drafts/cdr/CDR-{NNN}.md`:

```markdown
## CDR-{NNN}: Delete Directive: [Title]

### Status: **Discovered**

### Date: [YYYY-MM-DD]

### Source: Build to Delete via /team-repair --build-to-delete

### Target Module: `context_modules/rules/{domain}/{file}.md` + `evals/{directive-id}/`

### Context Type: Constitution Amendment

### Descriptor: Directive is obsolete — model handles natively without the rule.

### Context
The directive `{title}` was tested by running its goldenset cases without the directive loaded.
The model passed 100% of cases (N/N), indicating the baseline model now handles this pattern natively.
The directive is a candidate for Harness Decay removal.

### Decision
Delete both the directive file and its paired eval goldenset.

### Evidence
- Directive: context_modules/rules/{domain}/{file}.md
- Eval: evals/{directive-id}/goldset.md
- Pass rate: 100% (N/N cases passed without the directive)
- Test date: [YYYY-MM-DD]
```

Regenerate the local CDR index. Handoff: suggest `/levelup-clarify` to review deletion candidates.

### Phase 11: Summary Report

```markdown
## Team Repair Summary

**Date**: {date}
**Team Directives**: {path}
**Mode**: {DRY RUN|LIVE}

### AGENTS.md Repair

| Status | Action |
|--------|--------|
| {VALID|CREATED|OVERWRITTEN} | {No changes needed|Created from template|Re-created from template} |

### OKF index.md + log.md + CDR.md Repair

| Action | Count |
|--------|-------|
| Files scanned | {n} |
| v0.1→v0.2 migrated | {n} |
| index.md files rebuilt | {n} |
| log.md files rebuilt | {n} |
| CDR.md derived entries | {n} |
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
- **Selective repair**: Use `--index-only`, `--skills-only`, or `--agents-only` for specific targets
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
- **Proceeding past Phase 2 when `TEAM_AI_DIRECTIVES` is empty** — operating without a configured repository writes to undefined paths and corrupts the wrong workspace.
- **Skipping Phase 0 Health Check** — jumping straight into repairs without verifying the framework is installed risks writing to an absent or misconfigured workspace.
- **Skipping Step 5 (project AGENTS.md injection)** — the team AI directives' own `AGENTS.md` describes its structure, but the **project-level** `AGENTS.md` is what tells agents to invoke `team-boot` at session start. Without it, agents have no session-start instruction and the team AI directives remains invisible until manually loaded.

## Verification

- [ ] Phase 0 Health Check passes all 8 checks (no `[FAIL]`) before any repair is attempted.
- [ ] AGENTS.md exists at `{TEAM_AI_DIRECTIVES}/AGENTS.md` and contains all six required sections.
- [ ] Project-level `AGENTS.md` at `{REPO_ROOT}/AGENTS.md` contains the `<!-- TEAM_AI_DIRECTIVES START -->` managed section with the event-hook awareness note, fallback `team-boot` invocation, and the Team Context in Use output contract.
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

- `TEAM_AI_DIRECTIVES` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directives` field.
- Default fallback: `team-ai-directives/` relative to project root.
- `team-helpers.sh` / `team-helpers.ps1` — Shared scripts used for path resolution.

## 12-Factor Alignment

Factor XI (Directives as Code) — maintains integrity of version-controlled team directives.
