---
description: "Configure .gitignore with proper rules for Spec Kit directories"
aliases: ["git.setup-ignore"]
---

## Overview

Automatically manages `.gitignore` rules for Spec Kit projects to ensure:
- Cache/backup files are excluded from version control
- Project configs and templates are properly included
- AI agent directories are not accidentally ignored

## Rules Applied

### Excluded (should NOT be committed)
These are auto-generated or local-only files:

```gitignore
# Spec Kit - Generated/Local files
.specify/extensions/.cache/
.specify/extensions/.backup/
.specify/extensions/*/*.local.yml
.specify/extensions/.registry
```

### Protected (ensure NOT ignored)
These ensure spec-kit directories aren't caught by broad ignore patterns:

```gitignore
# Ensure Spec Kit directories are tracked
!.specify/
!.specify/templates/
!.specify/scripts/
!.specify/memory/
!.opencode/
!.claude/
!.cursor/
!.windsurf/
```

## Execution Modes

### Mode 1: Check Only (`--check`)
Verify current `.gitignore` has all required rules without making changes.

```bash
/speckit.git.setup-ignore --check
```

### Mode 2: Fix/Default
Add missing rules to `.gitignore` and commit changes.

```bash
/speckit.git.setup-ignore
```

### Mode 3: Dry Run (`--dry-run`)
Preview what would be added without modifying files.

```bash
/speckit.git.setup-ignore --dry-run
```

## Outline

1. **Check prerequisites**
   - Verify we're in a git repository
   - Check if `.gitignore` exists (create if needed)

2. **Analyze current state**
   - Read existing `.gitignore` rules
   - Identify which spec-kit rules are missing

3. **Apply changes** (unless `--check` or `--dry-run`)
   - Add missing ignore rules
   - Add missing negation patterns
   - Stage and commit `.gitignore`

4. **Report results**
   - Show rules added/verified
   - Indicate if commit was made

## Example Output

### Success (rules added)

```
==========================================
Spec Kit .gitignore Setup
==========================================

Rules added (6):
  ✓ .specify/extensions/.cache/
  ✓ .specify/extensions/.backup/
  ✓ .specify/extensions/*/*.local.yml
  ✓ .specify/extensions/.registry
  ✓ !.specify/
  ✓ !.opencode/

Changes committed:
  [Spec Kit] Configure .gitignore for spec-kit directories
```

### Success (already configured)

```
==========================================
Spec Kit .gitignore Setup
==========================================

All rules already configured ✓

Verified rules (6):
  ✓ .specify/extensions/.cache/
  ✓ .specify/extensions/.backup/
  ✓ .specify/extensions/*/*.local.yml
  ✓ .specify/extensions/.registry
  ✓ !.specify/
  ✓ !.opencode/
```

### Dry Run

```
==========================================
Spec Kit .gitignore Setup (DRY RUN)
==========================================

Would add rules (4):
  → .specify/extensions/.cache/
  → .specify/extensions/.backup/
  → .specify/extensions/*/*.local.yml
  → .specify/extensions/.registry

Would add negations (2):
  → !.specify/
  → !.opencode/
```

## Key Rules

- Idempotent: Safe to run multiple times
- Non-destructive: Won't remove existing rules
- Auto-commit: Commits `.gitignore` changes with descriptive message
- Graceful: Skips if not in a git repository

## Safety

This command is safe to run multiple times. It will:
- Only add rules that don't already exist
- Not modify or remove existing rules
- Create `.gitignore` if it doesn't exist
- Skip gracefully if not in a git repository

## Integration

This command is automatically called by:
- `/speckit.git.workspace` - Before submodule setup
- `/speckit.git.workspace --ignore-only` - Before adding child repos

You can also run it manually to ensure proper configuration.