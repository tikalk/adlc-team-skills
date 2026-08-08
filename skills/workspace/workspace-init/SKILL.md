---
name: workspace-init
description: Initialize a multi-repo workspace for shared team context. Creates .adlc/ directory structure, configures .gitignore conventions, discovers child repos, and optionally links them as Git submodules or ignores them. Use when bootstrapping a new workspace or onboarding child repos.
disable-model-invocation: true
---

# workspace-init

## What this skill does

Initializes a **multi-repo workspace** so that a parent repository can coordinate shared team context (PDRs, ADRs, CDRs) across multiple child implementation repositories.

**Three initialization layers**:

1. **`.adlc/` structure** — Create the shared context directory tree in the parent repo
2. **`.gitignore` conventions** — Ensure workspace conventions are properly configured
3. **Child repo discovery** — Detect depth-1 child repos and optionally link or ignore them

**Output**: Initialized `.adlc/` directory structure, configured `.gitignore`, and a workspace initialization report.

**Key Difference from `/workspace`**:

- `/workspace-init` (this skill) = **Initializes** the workspace: creates `.adlc/`, configures `.gitignore`, links/ignores child repos
- `/workspace` = **Audits** the workspace: discovers, reports status, checks SHA drift (read-only)

## When to use

- **New workspace**: Parent repo needs `.adlc/` structure for shared team context
- **Child repo onboarding**: New child repos cloned into the workspace need registration
- **`.gitignore` bootstrap**: Workspace needs proper ignore rules for `.adlc/`, `.agents/`, etc.
- **Brownfield conversion**: Existing tracked child repos need conversion to submodules or ignoring

### When NOT to use

- **Workspace already initialized**: Use `/workspace --status` to audit instead
- **Only auditing child repo state**: Use `/workspace` (read-only discovery + status)
- **Linking additional child repos after init**: Use `/workspace --link` directly

## Process

### User Input

```text
$ARGUMENTS
```

Parse flags from the arguments first, then treat remaining text as context:

- `--link` — Register discovered child repos as Git submodules (delegates to `workspace.sh`)
- `--ignore-only` — Add child repos to `.gitignore` instead of creating submodules
- `--force` — Convert repos already tracked by parent index (requires clean tree)
- `--dry-run` — Preview changes without executing
- Remaining text — Workspace description (informational)

### Phase 0: Environment Setup

**Run setup script** to resolve paths, create `.adlc/` structure, and discover child repos:

```bash
sh: scripts/bash/setup-workspace-init.sh [--json]
ps: scripts/powershell/setup-workspace-init.ps1
```

**Setup output** (JSON):
```json
{
  "REPO_ROOT": "/path/to/parent",
  "ADLC_DIR": "/path/to/parent/.adlc",
  "ADLC_DIRS_CREATED": [".adlc/product", ".adlc/architecture", ".adlc/context"],
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
├── context/           # CDRs (levelup-specify, levelup-init)
├── skills/            # Team skills metadata
└── drafts/            # Draft artifacts before clarification
    ├── pdr/
    ├── adr/
    ├── cdr/
    ├── skills/
    └── evals/
```

### Phase 1: `.gitignore` Configuration

Ensure `.gitignore` has proper workspace conventions.

**Excluded (should NOT be committed)** — local-only or agent-generated:

```gitignore
# ADLC - local agent state (generated per contributor)
.adlc/
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
.mcp.json
```

**Protected (ensure NOT ignored)** — workspace source files:

```gitignore
# Ensure workspace source directories are tracked
!skills/
!docs/
!evals/
!tests/
```

**Action**: If `GITIGNORE_RULES_MISSING` is non-empty, add the missing rules to `.gitignore`. Do NOT remove existing rules. If changes were made and not in `--dry-run` mode, commit with message `[workspace] Configure .gitignore for workspace conventions`.

### Phase 2: Child Repo Discovery

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

**Discovery rules** (same as `/workspace`):

| Rule | Behavior |
|---|---|
| Depth | 1 level only (direct subdirectories of parent root) |
| Detection | Directory contains `.git/` directory or `.git` file |
| Exclusions | `node_modules`, `.venv`, `venv`, `dist`, `build`, `target`, `.idea`, `.vscode`, `.git`, `.cache` |
| No config file | No `workspace.yml` — pure auto-discovery |

If no child repos are discovered, skip to Phase 5 (output summary).

### Phase 3: Child Repo Action

Based on user flags, perform one of the following:

#### Mode A: Submodule Linking (`--link`)

Delegate to the existing workspace skill's script:

```bash
"$(dirname "$0")/../../scripts/bash/workspace.sh" --json --link $([ "$DRY_RUN" == true ] && echo "--dry-run") $([ "$FORCE" == true ] && echo "--force")
```

**Safety checks** (enforced by `workspace.sh`):
- Parent working tree must be clean (no uncommitted changes outside child repos)
- Child repos must have a remote `origin` URL configured
- Already-registered submodules are skipped (idempotent)
- Repos tracked in parent index require `--force`

#### Mode B: Ignore Only (`--ignore-only`)

Add each discovered child repo to `.gitignore` instead of creating submodules.

For each child repo:
1. If tracked in parent index: `git rm --cached <name>` (remove from index, keep on disk)
2. Add `<name>/` to `.gitignore` if not already present
3. Skip repos already in `.gitignore` (idempotent)

Commit with message `[workspace] Add child repos to .gitignore` if changes were made.

**Use when**: Child repos are truly independent projects; team members manage them separately.

#### Mode C: No Action (Default)

If neither `--link` nor `--ignore-only` is specified, report discovered repos and recommend next steps without making changes beyond `.adlc/` creation and `.gitignore` setup.

### Phase 4: Commit Changes

If any changes were made (`.adlc/` creation, `.gitignore` updates, submodule registration, or ignore rules) and not in `--dry-run` mode:

```bash
git add .adlc/ .gitignore .gitmodules 2>/dev/null || true
git commit -m "[workspace] Initialize multi-repo workspace" 2>/dev/null || true
```

### Phase 5: Output Summary

```markdown
## Workspace Init Complete ✓

### .adlc/ Structure
- Created: 8 directories under `.adlc/`
- `product/`, `architecture/`, `context/`, `skills/`, `drafts/{pdr,adr,cdr,skills,evals}/`

### .gitignore
- Rules added: 5
- Rules verified: 12

### Child Repos
- Discovered: 3
- Registered as submodules: 2
- Ignored: 0
- Skipped (already submodules): 1
- Errors: 0

### Next Steps
1. Create product decisions: `/product-specify`
2. Create architecture decisions: `/architect-specify`
3. Audit workspace health: `/workspace --status`
4. Team members can clone with: `git clone --recursive <workspace-url>`
```

## Configuration

- `REPO_ROOT` — Parent repository root (auto-detected)
- `ADLC_DIR` — `{REPO_ROOT}/.adlc` (shared context directory)
- No `workspace.yml` or registry file — pure convention

## Safety

- **`.adlc/` creation is safe**: Only creates directories; never overwrites existing content.
- **`.gitignore` is additive**: Only adds missing rules; never removes existing rules.
- **`--link` requires clean parent tree**: Uncommitted changes outside child repos abort the operation (enforced by `workspace.sh`).
- **`--force`** removes child directories from the parent Git index (`git rm --cached`) before re-adding as submodules. Requires a clean working tree.
- **Idempotent**: Already-registered submodules and already-ignored repos are skipped on re-run.
- **Child repos without a remote `origin`** are reported as errors and skipped during `--link`.
- **`--dry-run`** previews all changes without executing.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I'll create `.adlc/` manually with mkdir" | Misses the full directory tree and `.gitignore` conventions | Run the setup script for complete initialization |
| "I'll add `workspace.yml` for explicit repo list" | Adds config overhead; auto-discovery is simpler and sufficient | Use depth-1 discovery; exclude via `.gitignore` if needed |
| "I'll skip the `.gitignore` setup" | Risks committing local agent state (`.agents/`, `.opencode/`) | Let the init skill configure conventions |
| "I'll use `--ignore-only` instead of submodules for everything" | Loses workspace coordination benefits | Use `--link` for tracked repos; `--ignore-only` only for independent projects |
| "I'll create `.adlc/` in child repos too" | Diverges from single-source-of-truth model | Keep `.adlc/` in parent only; children reference parent |

## Red Flags

- Running `--link` without checking parent working tree is clean.
- Running `--force` on a parent with uncommitted changes outside child repos.
- Creating `.adlc/` content in child repos (parent is the single source).
- Adding a `workspace.yml` or registry file (convention-only, no config).
- Excluding `.specify` from discovery (it may be a legitimate child repo).
- Modifying child repo contents during `--link` (only parent index changes).
- Skipping `.gitignore` setup when local agent directories exist.

## Verification

- [ ] Setup script returns valid JSON with all paths
- [ ] `.adlc/` directory exists with all subdirectories (`product/`, `architecture/`, `context/`, `skills/`, `drafts/`)
- [ ] `.gitignore` has all required workspace rules (no missing rules)
- [ ] Child repos discovered at depth 1 (excluding `node_modules`, `.venv`, etc.)
- [ ] `--link` only runs when parent working tree is clean
- [ ] Already-registered submodules are skipped (idempotent)
- [ ] Child repos without `origin` remote are reported as errors during `--link`
- [ ] `--ignore-only` adds repos to `.gitignore` and removes from parent index
- [ ] `--dry-run` produces no file changes
- [ ] JSON output matches the setup output contract

## Integration with Existing Skills

| Skill | Relationship |
|---|---|
| `workspace` (parent skill) | Audits the workspace after init: discovery, status, SHA drift |
| `product-specify` | Creates PDRs in parent `.adlc/product/` after init |
| `architect-specify` | Creates ADRs in parent `.adlc/architecture/` after init |
| `levelup-specify` | Creates CDRs in parent `.adlc/context/` after init |
| `team-boot` | Loads parent `.adlc` context at session start |
| `team-setup` | Configures agent directories (`.agents/`, `.opencode/`) — complement to workspace init |

## 12-Factor Alignment

- **Factor XI (Directives as Code)** — establishes a version-controlled multi-repo workspace where shared decisions live in the parent and implementation repos are linked as submodules or ignored by convention.
