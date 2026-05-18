---
description: Discover child repositories and register them as Git submodules for multi-repo
  workspace coordination.
aliases:
- git.workspace
---


<!-- Extension: git -->
<!-- Config: .specify/extensions/git/ -->
## User Input

```text
$ARGUMENTS
```

## Overview

This command sets up a multi-repo workspace by discovering child git repositories at depth 1 from the project root and registering them as Git submodules.

**When to use:**
- After `specify init` when you have multiple implementation repos alongside your coordination workspace
- When you've cloned new child repos into the workspace and want to register them as submodules
- To convert an existing multi-repo setup to use submodules for better git isolation

## How It Works

1. **Discover child repos**: Scan depth 1 for directories containing `.git/`
2. **Check existing submodules**: Skip directories already registered in `.gitmodules`
3. **Read remote URLs**: Get `origin` URL from each child repo's git config
4. **Register as submodules**: Run `git submodule add <url> <path>` for each
5. **Commit changes**: Create a commit with the updated `.gitmodules` file

## Safety First

⚠️ **WARNING**: Before running this command:
- Parent repository should have a clean working tree (no uncommitted changes outside child repos)
- All child repositories must have a remote `origin` URL configured

**Brownfield Workspaces (Existing Repos)**:
If your child repos are already tracked by the parent, use `--force` to convert them. The script will:
- Allow "dirty" child repo directories (they'll be converted to submodules)
- Still block if there are uncommitted changes outside child repos (for safety)

If the parent has uncommitted changes outside child repos, the command will abort with an error showing which files need attention.

## Execution Modes

### Mode 1: Submodule Conversion (Default)

Converts child repos to Git submodules for full workspace integration.

**Features:**
- Creates `.gitmodules` file with all child repo URLs
- Registers each child as a proper Git submodule
- Child repos remain editable and independently committable
- Team members can clone entire workspace with `git clone --recursive`

**For brownfield workspaces** (repos already exist and are tracked):

If child repos are already tracked by the parent git index, you'll see an error:
```
⚠ dms-addin: tracked in parent index (use --force)
```

Use `--force` to convert them:
```bash
/git.workspace --force
```

⚠️ **WARNING with --force:**
- Requires clean working tree (no uncommitted changes)
- Removes child directories from parent index with `git rm --cached`
- Converts to submodule references
- Cannot be undone without manual git operations

### Mode 2: Ignore Only (`--ignore-only`)

Simple isolation without submodule complexity.

**Features:**
- Adds each child repo to `.gitignore`
- Removes from parent index if already tracked (`git rm --cached`)
- Child repos remain completely independent
- Parent won't track any child files

**Use when:**
- You want quick isolation without submodule overhead
- Children are truly independent projects
- Team members manage child repos separately

```bash
/git.workspace --ignore-only
```

## Options

- `--force` - Convert directories already tracked by parent (requires clean working tree)
- `--ignore-only` - Add to .gitignore instead of creating submodules
- `--dry-run` - Preview changes without executing

## Outline

1. **Setup .gitignore**: Automatically configure `.gitignore` with proper Spec Kit rules (cache/backup exclusions, directory protections)
2. **Validate safety**: Check parent working tree is clean
3. **Run discovery script**:
   - **Bash**: `.specify/extensions/git/scripts/bash/workspace-submodules.sh --json $ARGUMENTS`
   - **PowerShell**: `.specify/extensions/git/scripts/powershell/workspace-submodules.ps1 -Json $ARGUMENTS`
4. **Parse JSON output**: Extract `DISCOVERED_COUNT`, `REGISTERED_COUNT`, `SKIPPED_COUNT`, `ERROR_COUNT`, `IGNORED_COUNT`, `REGISTERED_REPOS`, `SKIPPED_REPOS`, `ERROR_REPOS`, `IGNORED_REPOS`, `MODE`
5. **Report results**: Display which repos were registered/ignored vs skipped
6. **Handle errors**: Display any repos that couldn't be processed

## Automatic .gitignore Setup

This command automatically ensures `.gitignore` is properly configured for Spec Kit projects before processing submodules:

**Excluded (not committed):**
- `.specify/extensions/.cache/` - Catalog cache
- `.specify/extensions/.backup/` - Config backups
- `.specify/extensions/*/*.local.yml` - Local overrides
- `.specify/extensions/.registry` - Installation state

**Protected (ensure not accidentally ignored):**
- `!.specify/` - Spec Kit directory
- `!.specify/templates/` - Project templates
- `!.specify/scripts/` - Project scripts
- `!.opencode/` - AI agent commands
- etc.

To manually configure .gitignore without running workspace setup:
```bash
/git.setup-ignore
```

## Example Output

### Submodule Mode (Default)

```
==========================================
Workspace Submodule Setup
==========================================

Registered (3):
  ✓ frontend → git@github.com:org/frontend.git
  ✓ backend-api → git@github.com:org/backend-api.git
  ✓ shared-libs → git@github.com:org/shared-libs.git

Skipped (1):
  - local-only-repo (no remote URL configured)

Next steps:
  - Team members can clone with: git clone --recursive <workspace-url>
  - Or initialize submodules: git submodule update --init
```

### Ignore-Only Mode

```
==========================================
Workspace Ignore Setup
==========================================

Added to .gitignore (5):
  ✓ dms-addin
  ✓ dms-be
  ✓ dms-client
  ✓ dms-fe
  ✓ shared-libs

Next steps:
  - Child repos are now ignored by the parent
  - Each child remains an independent git repository
```

### Brownfield Conversion with --force

```
==========================================
Workspace Submodule Setup
==========================================

Registered (5):
  ✓ dms-addin → git@github.com:org/dms-addin.git
  ✓ dms-be → git@github.com:org/dms-be.git
  ✓ dms-client → git@github.com:org/dms-client.git
  ✓ dms-fe → git@github.com:org/dms-fe.git
  ✓ shared-libs → git@github.com:org/shared-libs.git

Next steps:
  - Team members can clone with: git clone --recursive <workspace-url>
  - Or initialize submodules: git submodule update --init
```

## Key Rules

- Child repos must have a remote `origin` URL configured
- Already-registered submodules are skipped (idempotent)
- Already-ignored repos are skipped (idempotent)
- Requires git to be initialized in the workspace root
- Parent working tree must be clean (no uncommitted changes)
- Only discovers repos at depth 1 (direct subdirectories)
- Directories named `.specify`, `node_modules`, `.venv`, etc. are ignored

## Safety

This command is safe to run multiple times. It will:
- Not modify child repo contents
- Not unregister existing submodules
- Skip repos without remote URLs (with a warning)
- Skip common development directories (node_modules, etc.)
- Abort if parent has uncommitted changes