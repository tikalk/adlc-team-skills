---
description: Re-index CDR.md, .skills.json, and AGENTS.md in team-ai-directives
scripts:
  sh: .specify/extensions/levelup/scripts/bash/setup-levelup.sh --json
  ps: .specify/extensions/levelup/scripts/powershell/setup-levelup.ps1 -Json
---

## User Input

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

## Goal

Re-index CDR.md, .skills.json, and AGENTS.md in team-ai-directives to fix inconsistencies, detect orphaned files, and auto-repair issues.

**Input**: team-ai-directives repository

**Output**:
1. Repaired AGENTS.md (if missing or corrupted)
2. Rebuilt CDR.md index from context_modules/
3. Rebuilt .skills.json manifest from skills/
4. Auto-added YAML frontmatter to orphan context modules
5. Auto-generated .skills.json entries for orphan skills
6. Summary report of all repairs

## Role & Context

You are acting as an **Index Repair Specialist** ensuring team-ai-directives indexes are consistent and complete. Your role involves:

- **Scanning** context_modules/ and skills/ directories
- **Detecting** orphan files (missing frontmatter/manifest entries)
- **Auto-repairing** issues by generating missing metadata
- **Rebuilding** index files to reflect actual content
- **Reporting** all changes made

### Repair Targets

| Target | Location | Purpose |
|--------|----------|---------|
| **AGENTS.md** | `{TEAM_DIRECTIVES}/AGENTS.md` | Main instruction file for AI agents |
| **CDR.md** | `{TEAM_DIRECTIVES}/CDR.md` | Index of approved context contributions |
| **.skills.json** | `{TEAM_DIRECTIVES}/.skills.json` | Skills manifest registry |

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Report only, don't write changes |
| `--cdr-only` | Only repair CDR.md |
| `--skills-only` | Only repair .skills.json |
| `--agents-only` | Only repair AGENTS.md |
| (default) | Repair all indexes with auto-fix |

## Execution Steps

### Phase 0: Environment Setup

**Objective**: Resolve paths and validate infrastructure

Run `{SCRIPT}` from repository root and parse JSON output:

```json
{
  "REPO_ROOT": "/path/to/project",
  "TEAM_DIRECTIVES": "/path/to/team-ai-directives",
  "BRANCH": "current-branch"
}
```

### Phase 1: Validate Environment

**Objective**: Ensure team-ai-directives is configured

Check if TEAM_DIRECTIVES has a value from script output.

If empty, **STOP**:
```
Team AI directives repository not configured.
Run: specify init --team-ai-directives <path-or-url>
Or set: export SPECIFY_TEAM_DIRECTIVES=/path/to/team-ai-directives
```

### Phase 2: Repair AGENTS.md

**Objective**: Ensure AGENTS.md exists with required structure

**Skip if**: `--cdr-only` or `--skills-only` flag provided

#### Step 1: Check AGENTS.md Exists

```bash
test -f "{TEAM_DIRECTIVES}/AGENTS.md" && echo "EXISTS" || echo "MISSING"
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
grep -q "^# Agent Instructions" "{TEAM_DIRECTIVES}/AGENTS.md"
grep -q "^## Structure" "{TEAM_DIRECTIVES}/AGENTS.md"
grep -q "^## Loading Order" "{TEAM_DIRECTIVES}/AGENTS.md"
grep -q "^## Functional Categories" "{TEAM_DIRECTIVES}/AGENTS.md"
grep -q "^## Using Skills" "{TEAM_DIRECTIVES}/AGENTS.md"
grep -q "^## CDR.md" "{TEAM_DIRECTIVES}/AGENTS.md"
```

#### Step 3: Auto-Repair

| Status | Action |
|--------|--------|
| **Missing** | Create from `.specify/extensions/levelup/templates/agents-template.md` |
| **Corrupted** (missing sections) | Overwrite with template |
| **Valid** | No changes |

If `--dry-run`:
```markdown
### AGENTS.md Status: {MISSING|CORRUPTED|VALID}

**Action**: {Would create|Would overwrite|No changes needed}
```

Otherwise, execute repair:
```bash
cp ".specify/extensions/levelup/templates/agents-template.md" "{TEAM_DIRECTIVES}/AGENTS.md"
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

### Phase 3: Scan Context Modules for CDR.md Reindex

**Objective**: Find all context modules and extract metadata

**Skip if**: `--skills-only` or `--agents-only` flag provided

#### Step 1: Find All Context Module Files

```bash
find "{TEAM_DIRECTIVES}/context_modules/rules" -name "*.md" -type f 2>/dev/null
find "{TEAM_DIRECTIVES}/context_modules/personas" -name "*.md" -type f 2>/dev/null
find "{TEAM_DIRECTIVES}/context_modules/examples" -name "*.md" -type f 2>/dev/null
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

#### Step 3: Detect Orphans (No Frontmatter)

Files with `.md` extension but no YAML frontmatter.

For each orphan:
1. Generate `id` from filename: `rules/python/new-pattern.md` → `rule-python-new-pattern`
2. Determine context type from path:
   - `rules/` → `Rule`
   - `personas/` → `Persona`
   - `examples/` → `Example`
3. Set default metadata:
   ```yaml
   id: {generated-id}
   cdr_ref: null
   created: {today}
   modified: {today}
   verified: {today}
   age_days: 0
   evidence: []
   ```

If `--dry-run`:
```markdown
### Orphan Files Detected

| File | Generated ID | Action |
|------|--------------|--------|
| rules/python/new-pattern.md | rule-python-new-pattern | Would add frontmatter |
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
      "age_days": 33
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

### Phase 4: Scan Skills for .skills.json Reindex

**Objective**: Find all skills and build manifest entries

**Skip if**: `--cdr-only` or `--agents-only` flag provided

#### Step 1: Find All Skill Directories

```bash
find "{TEAM_DIRECTIVES}/skills" -mindepth 1 -maxdepth 1 -type d
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

### Phase 5: Rebuild CDR.md

**Objective**: Generate fresh CDR.md from scanned context modules

**Skip if**: `--skills-only` or `--agents-only` flag provided

#### Step 1: Generate CDR Index Table

From scanned context modules, build index:

```markdown
# Context Directive Records

Context Directive Records (CDRs) track decisions about contributing context modules (rules, personas, examples, skills) to team-ai-directives.

> **Memory Engineering**: This index tracks directive freshness. Run `/levelup.validate` to update verification timestamps.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age |
|----|---------------|------|--------|---------|----------|-----|
| CDR-2026-001 | context_modules/rules/python/error-handling.md | Rule | Accepted | 2026-04-15 | 2026-05-18 | 33d |
| rule-python-new-pattern | context_modules/rules/python/new-pattern.md | Rule | Auto-generated | 2026-05-22 | 2026-05-22 | 0d |

**Stats**: {N} entries | Last Updated: {date}

---

## CDR-2026-001: {Title from context module}

### Status
**Accepted**

### Dates
- **Created**: 2026-04-15
- **Modified**: 2026-05-18
- **Verified**: 2026-05-18
- **Age**: 33 days

### Target Module
`context_modules/rules/python/error-handling.md`

### Context Type
Rule

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
cat > "{TEAM_DIRECTIVES}/CDR.md" << 'EOF'
{generated content}
EOF
```

### Phase 6: Rebuild .skills.json

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
    },
    "local:./skills/deployment": {
      "version": "1.0.0",
      "description": "Deploy applications to production with safety checks",
      "categories": ["devops", "deployment"],
      "instruction_type": "General Capability"
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
cat > "{TEAM_DIRECTIVES}/.skills.json" << 'EOF'
{generated JSON}
EOF
```

### Phase 7: Summary Report

**Objective**: Present repair results

```markdown
## LevelUp Repair Summary

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

{If orphans repaired:}
#### Orphans Repaired

| File | Generated ID |
|------|--------------|
| {file} | {id} |

### .skills.json Repair

| Action | Count |
|--------|-------|
| Skills scanned | {n} |
| Valid entries | {n} |
| Orphans repaired | {n} |
| Missing removed | {n} |

{If orphans repaired:}
#### Orphans Repaired

| Skill | Generated Entry |
|-------|-----------------|
| {skill} | Added from SKILL.md |

### Files Modified

| File | Change |
|------|--------|
| {file} | {change description} |

{If --dry-run:}
> **Note**: Dry run mode - no files were modified

### Next Steps

1. Review repaired files
2. Run `/levelup.validate` to check for conflicts
3. Commit changes if satisfied
```

## Notes

- **Auto-fix**: Always repairs issues automatically (no confirmation needed)
- **Dry run**: Use `--dry-run` to preview changes without writing
- **Selective repair**: Use `--cdr-only`, `--skills-only`, or `--agents-only` for specific targets
- **YAML frontmatter**: Auto-generated for orphan context modules
- **Skills entries**: Auto-generated from SKILL.md content
- **AGENTS.md**: Overwrites if corrupted (missing required sections)
- **Idempotent**: Re-running produces same result

## Related Commands

- `/levelup.init` - Discover CDRs from codebase
- `/levelup.implement` - Compile accepted CDRs to team-ai-directives
- `/levelup.validate` - Scan for rule conflicts and update verification timestamps
