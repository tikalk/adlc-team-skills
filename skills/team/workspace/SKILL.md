---
name: workspace
description: Use when coordinating a multi-repo workspace — init the .adlc/ structure, discover and link child repos as submodules, or audit workspace health (branch, dirty, unpushed, SHA drift).
---

# workspace

## Overview

A multi-repo workspace coordinator for shared team context. The parent
repository holds shared decisions (PDRs, ADRs, CDRs) under `.adlc/`,
created by `product-specify`, `architect-specify`, and `team-levelup`.
Child implementation repositories are discovered at depth 1 and optionally
linked as Git submodules so the entire workspace can be cloned with
`git clone --recursive`.

No `workspace.yml`, no registry file. Pure convention:

- Parent repo = current working directory (must be a Git repo)
- Child repos = depth-1 subdirectories containing `.git/`
- Shared context = `.adlc/` in parent root

## When to Use

- **First-time setup** (`--init`): Create `.adlc/` directory structure, configure `.gitignore` conventions, and optionally link child repos.
- **After `product-specify` or `architect-specify`** has created shared PDRs/ADRs in the parent repo and you have multiple implementation repos alongside.
- **When you've cloned new child repos** into the workspace and want to register them as submodules (`--link`) or ignore them (`--ignore-only`).
- **To audit workspace health**: dirty working trees, unpushed commits, SHA drift between parent submodule reference and child HEAD.
- **To verify child repos** can see the parent `.adlc/` shared context.

### When NOT to Use `--init`

- **Workspace already initialized**: Use `/workspace --status` to audit instead.
- **Only auditing child repo state**: Use `/workspace` (read-only discovery + status).
- **Linking additional child repos after init**: Use `/workspace --link` directly.

## User Input

```text
$ARGUMENTS
```

## Commands

| Command | Purpose |
|---|---|
| `/workspace --init` | Initialize: create `.adlc/` structure, configure `.gitignore`, discover child repos |
| `/workspace` | Discover child repos, show summary status (read-only) |
| `/workspace --link` | Convert child repos to Git submodules (requires clean parent tree) |
| `/workspace --status` | Detailed audit: branch, dirty, unpushed, SHA drift, `.adlc` presence |
| `/workspace --ignore-only` | Add child repos to `.gitignore` instead of creating submodules |
| `/workspace --init --link` | Initialize + link child repos in one step |
| `/workspace --init --ignore-only` | Initialize + add child repos to `.gitignore` |
| `/workspace --dry-run` | Preview changes without executing (combine with `--init`, `--link`, `--ignore-only`) |
| `/workspace --force` | Convert repos already tracked by parent index (requires clean tree) |

## Execution

### Init Mode (`--init`)

Run the init setup script to create `.adlc/` structure, check `.gitignore` conventions, and discover child repos:

```bash
# Bash
scripts/bash/setup-workspace.sh --json

# PowerShell
scripts/powershell/setup-workspace.ps1
```

**Init setup output** (JSON):

```json
{
  "REPO_ROOT": "/path/to/parent",
  "ADLC_DIR": "/path/to/parent/.adlc",
  "ADLC_DIRS_CREATED": [".adlc/product", ".adlc/drafts", ".adlc/drafts/pdr"],
  "GITIGNORE_EXISTS": true,
  "GITIGNORE_RULES_MISSING": [".adlc/"],
  "CHILD_REPOS": [
    {"name": "backend-api", "path": "/path/to/parent/backend-api", "remote": "git@github.com:org/backend-api.git", "is_submodule": false, "is_tracked": false}
  ],
  "CHILD_COUNT": 1,
  "BRANCH": "main"
}
```

**Directories created**:

```
.adlc/
├── product/           # PDRs (product-specify, product-init)
├── architecture/      # ADRs (architect-specify, architect-init)
├── context/           # CDRs (team-levelup, team-init)
├── skills/            # Team skills metadata
└── drafts/            # Draft artifacts before clarification
    ├── pdr/
    ├── adr/
    ├── cdr/
    ├── skills/
    └── evals/
```

After init setup, if `--link` or `--ignore-only` is also specified, proceed to the corresponding action mode below.

### Audit/Link Mode (default, `--link`, `--status`, `--ignore-only`)

Run the workspace coordinator script:

```bash
# Bash
"$(dirname "$0")/../scripts/bash/workspace.sh" --json [--link] [--status] [--dry-run] [--force] $ARGUMENTS
```

Parse the JSON output and present it to the user.

## Output Contract

### Init Mode Output

Emitted by `setup-workspace.sh --json` (see above).

### Audit/Link Mode Output

Emitted by `workspace.sh --json`:

```json
{
  "PARENT_REPO": "/abs/path/to/parent",
  "PARENT_BRANCH": "main",
  "PARENT_HAS_ADLC": true,
  "MODE": "discover|link|status",
  "DRY_RUN": false,
  "DISCOVERED_COUNT": 3,
  "REGISTERED_COUNT": 2,
  "SKIPPED_COUNT": 1,
  "ERROR_COUNT": 0,
  "REPOS": [
    {
      "name": "backend-api",
      "path": "/abs/path/to/parent/backend-api",
      "remote": "git@github.com:org/backend-api.git",
      "branch": "main",
      "dirty": false,
      "unpushed": 0,
      "is_submodule": true,
      "parent_sha": "abc1234",
      "child_sha": "abc1234",
      "sha_drift": false,
      "has_adlc": false
    }
  ],
  "ERRORS": []
}
```

## Init Phases

### Phase 1: `.adlc/` Structure Creation

The setup script creates the `.adlc/` directory tree if it doesn't exist (`product/`, `drafts/`, and the per-family draft subdirectories — the shared layout scopes `.adlc/` to machine pipeline state). This is the shared context directory where other skills write drafts and pipeline state; published decision records and compiled deliverables live under `docs/adlc/`.

**Idempotent**: already-existing directories are not recreated.

### Phase 2: `.gitignore` Configuration

The setup script checks `.gitignore` for workspace conventions and reports missing rules.

**Allowlist model** — `.adlc/` is no longer ignored wholesale. Machine pipeline state is ignored via `.adlc/*` with tracked exceptions re-included; published content under `docs/adlc/` is always tracked:

```gitignore
# agent-install surface (regenerated)
.agents/
.opencode/
.claude/
.cursor/
.codex/
.gemini/
.qwen/
.devin/
.tabnine/
skills-lock.json
.skills.json
# .mcp.json is deliberately ABSENT: it is committed project source
# (human-edited, never generated), not a derived artifact.
.events.json
.pytest_cache/
.ruff_cache/

# machine pipeline + runtime state (tracked exceptions follow)
.adlc/*
!.adlc/init-options.json
!.adlc/workspace.yml
!.adlc/drafts/
!.adlc/evals/
.adlc/evals/results/
!.adlc/memory/
.adlc/memory/*
!.adlc/memory/evals/
!.adlc/memory/evals/holdout.json

# generated reports (legacy name kept during transition)
.adlc/team-learn-report.md
.adlc/team-levelup-report.md

# knowledge graph (generated)
graphify-out/
```

The allowlist has a single definition in `scripts/bash/paths.sh` (`GITIGNORE_RULES_ALLOWLIST`, mirrored in `scripts/powershell/paths.ps1`); the setup scripts source it and report any missing rules. Tracked legacy files keep working — gitignore gates only untracked files.

**Action**: If `GITIGNORE_RULES_MISSING` is non-empty, add the missing rules to `.gitignore`. Do NOT remove existing rules. If changes were made and not in `--dry-run` mode, commit with message `[workspace] Configure .gitignore for workspace conventions`.

### Phase 3: Child Repo Discovery

Review discovered child repos from setup output.

**Present discovered repos**:

```markdown
## Discovered Child Repos

| # | Repo | Remote | Submodule? | Tracked? |
|---|------|--------|------------|----------|
| 1 | **backend-api** | git@github.com:org/backend-api.git | No | No |
| 2 | **frontend** | git@github.com:org/frontend.git | Yes | N/A |

Reply: Y to proceed with --link/--ignore-only, or adjust.
```

### Phase 4: Child Repo Action (optional)

If `--link` or `--ignore-only` is combined with `--init`, execute the corresponding action after init setup.

#### `--link` (Submodule Registration)

Delegates to `workspace.sh --link`. Safety checks enforced:
- Parent working tree must be clean (no uncommitted changes outside child repos)
- Child repos must have a remote `origin` URL configured
- Remote URLs must use an allowed scheme (`https://`, `git@`, `ssh://`) —
  anything else (e.g. `http://`, `file://`) is reported as an error and skipped
- Already-registered submodules are skipped (idempotent)
- Repos tracked in parent index require `--force`
- Preview with `--dry-run` first and confirm with the user before linking

#### `--ignore-only` (Ignore Instead of Submodule)

Add each discovered child repo to `.gitignore` instead of creating submodules.

For each child repo:
1. If tracked in parent index: `git rm --cached <name>` (remove from index, keep on disk)
2. Add `<name>/` to `.gitignore` if not already present
3. Skip repos already in `.gitignore` (idempotent)

Commit with message `[workspace] Add child repos to .gitignore` if changes were made.

**Use when**: Child repos are truly independent projects; team members manage them separately.

### Phase 5: Output Summary

```markdown
## Workspace Init Complete

### .adlc/ Structure
- Created: 7 directories under `.adlc/` (`product/`, `drafts/`, `drafts/{pdr,adr,cdr,skills,evals}/`)

### .gitignore
- Rules added: 5
- Rules verified: 12

### Child Repos
- Discovered: 3
- Registered as submodules: 2
- Ignored: 0
- Skipped (already submodules): 1

### Next Steps
1. Create product decisions: `/product-specify`
2. Create architecture decisions: `/architect-specify`
3. Audit workspace health: `/workspace --status`
```

## Discovery Rules

| Rule | Behavior |
|---|---|
| Depth | 1 level only (direct subdirectories of parent root) |
| Detection | Directory contains `.git/` directory or `.git` file |
| Exclusions | `node_modules`, `.venv`, `venv`, `dist`, `build`, `target`, `.idea`, `.vscode`, `.git`, `.cache`, `.specify` |
| No config file | No `workspace.yml` — pure auto-discovery |

## Shared Team Context (`.adlc/`)

The parent repo's `.adlc/` directory is the single source of truth for
team context. It is created by `--init` and maintained by other skills:

| Artifact | Path | Created By |
|---|---|---|
| PDR drafts | `.adlc/drafts/pdr/` (accepted → `docs/adlc/memory/pdr/`) | `product-specify`, `product-init` |
| ADR drafts | `.adlc/drafts/adr/` (accepted → `docs/adlc/memory/adr/`) | `architect-specify`, `architect-init` |
| CDRs | team-ai-directives `adlc` branch (local drafts in `.adlc/drafts/cdr/`) | `team-levelup`, `team-init` |
| Skills | agent skills dir (`.agents/skills/` mirror) | `team-skills` |
| Directory structure | `.adlc/` tree | `workspace --init` (this skill) |

In audit mode (default), this skill does **not** create or modify `.adlc/` content. It only:
1. Verifies the parent has `.adlc/` (warns if missing).
2. Checks whether each child repo has its own `.adlc/` (informational).

## Safety

- **`--init` is safe**: Only creates directories and reports missing `.gitignore` rules; never overwrites existing content.
- **`.gitignore` changes are additive**: Only adds missing rules; never removes existing rules.
- **Read-only by default**: `/workspace` and `/workspace --status` make no changes.
- **`--link` requires clean parent tree**: uncommitted changes outside child repos abort the operation.
- **`--force`** removes child directories from the parent Git index (`git rm --cached`) before re-adding as submodules. Requires a clean working tree.
- **Idempotent**: already-registered submodules, already-ignored repos, and already-created directories are skipped on re-run.
- **Child repos without a remote `origin`** are reported as errors and skipped during `--link`.
- **`--dry-run`** previews all changes without executing.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I'll create `.adlc/` manually with mkdir" | Misses the full directory tree and `.gitignore` conventions | Run `--init` for complete initialization |
| "I'll add `workspace.yml` for explicit repo list" | Adds config overhead; auto-discovery is simpler and sufficient | Use depth-1 discovery; exclude via `.gitignore` if needed |
| "I'll skip the `.gitignore` setup" | Risks committing local agent state (`.agents/`, `.opencode/`) | Let `--init` configure conventions |
| "I'll create `.adlc/` in child repos too" | Diverges from single-source-of-truth model | Keep `.adlc/` in parent only; children reference parent |
| "I'll skip the clean-tree check for `--link`" | Risks losing uncommitted parent changes | Require clean tree; tell user to commit or stash first |
| "I'll use worktrees instead of submodules" | Worktrees are for feature isolation, not multi-repo coordination | Use submodules for tracked multi-repo linking |
| "I'll use `--ignore-only` instead of submodules for everything" | Loses workspace coordination benefits | Use `--link` for tracked repos; `--ignore-only` only for independent projects |

## Red Flags

- Running `--link` without checking parent working tree is clean.
- Running `--force` on a parent with uncommitted changes outside child repos.
- Creating `.adlc/` content in child repos (parent is the single source).
- Adding a `workspace.yml` or registry file (convention-only, no config).
- Re-including `.specify` in discovery — the scripts hard-exclude it (see Discovery Rules), and that exclusion is intentional.
- Modifying child repo contents during `--link` (only parent index changes).
- Skipping `.gitignore` setup when local agent directories exist.

## Verification

- [ ] Parent repo is a Git repository.
- [ ] `--init` creates `.adlc/` with its subdirectories (`product/`, `drafts/`, `drafts/{pdr,adr,cdr,skills,evals}/`).
- [ ] `--init` reports missing `.gitignore` rules (additive, never removes).
- [ ] `--init` is idempotent (second run reports 0 dirs created).
- [ ] Parent `.adlc/` exists (warn if missing in audit mode).
- [ ] Child repos discovered at depth 1 (excluding `node_modules`, `.venv`, etc.).
- [ ] `--link` only runs when parent working tree is clean.
- [ ] Already-registered submodules are skipped (idempotent).
- [ ] Child repos without `origin` remote are reported as errors.
- [ ] `--status` reports branch, dirty state, unpushed count, SHA drift, `.adlc` presence per child.
- [ ] `--ignore-only` adds repos to `.gitignore` and removes from parent index.
- [ ] `--dry-run` produces no file changes.
- [ ] JSON output matches the Output Contract schema for both init and audit modes.

## Integration with Existing Skills

| Skill | Relationship |
|---|---|
| `product-specify` | Creates PDR drafts in parent `.adlc/drafts/pdr/` after `--init` |
| `architect-specify` | Creates ADR drafts in parent `.adlc/drafts/adr/` after `--init` |
| `team-levelup` | Creates CDR drafts (published to the team-ai-directives `adlc` branch) after `--init` |
| `team-boot` | Loads parent `.adlc` context at session start |
| `team-setup` | Configures agent directories (`.agents/`, `.opencode/`) — complement to `--init` |

## 12-Factor Alignment

Factor XI (Directives as Code) — establishes a version-controlled multi-repo
workspace where shared decisions live in the parent and implementation repos
are linked as submodules or ignored by convention.
