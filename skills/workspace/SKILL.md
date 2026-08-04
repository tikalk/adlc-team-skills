---
name: workspace
description: Multi-repo workspace for shared team context. Discover child repos, link them as Git submodules, and audit workspace health. Use when coordinating multiple implementation repos that share PDRs, ADRs, and CDRs in the parent .adlc/ directory.
---

# workspace

## Overview

A multi-repo workspace coordinator for shared team context. The parent
repository holds shared decisions (PDRs, ADRs, CDRs) under `.adlc/`,
created by `product-specify`, `architect-specify`, and `levelup-specify`.
Child implementation repositories are discovered at depth 1 and optionally
linked as Git submodules so the entire workspace can be cloned with
`git clone --recursive`.

No `workspace.yml`, no registry file. Pure convention:

- Parent repo = current working directory (must be a Git repo)
- Child repos = depth-1 subdirectories containing `.git/`
- Shared context = `.adlc/` in parent root

## When to Use

- After `product-specify` or `architect-specify` has created shared PDRs/ADRs
  in the parent repo and you have multiple implementation repos alongside.
- When you've cloned new child repos into the workspace and want to register
  them as submodules.
- To audit workspace health: dirty working trees, unpushed commits, SHA drift
  between parent submodule reference and child HEAD.
- To verify child repos can see the parent `.adlc/` shared context.

## User Input

```text
$ARGUMENTS
```

## Commands

| Command | Purpose |
|---|---|
| `/workspace` | Discover child repos, show summary status |
| `/workspace --link` | Convert child repos to Git submodules (requires clean parent tree) |
| `/workspace --status` | Detailed audit: branch, dirty, unpushed, SHA drift, `.adlc` presence |
| `/workspace --dry-run` | Preview changes without executing (combine with `--link`) |
| `/workspace --force` | Convert repos already tracked by parent index (requires clean tree) |

## Execution

Run the helper script relative to this skill directory:

```bash
# Bash
"$(dirname "$0")/../scripts/bash/workspace.sh" --json $ARGUMENTS
```

Parse the JSON output and present it to the user.

## Output Contract

The script emits JSON on stdout when invoked with `--json`:

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

## Discovery Rules

| Rule | Behavior |
|---|---|
| Depth | 1 level only (direct subdirectories of parent root) |
| Detection | Directory contains `.git/` directory or `.git` file |
| Exclusions | `node_modules`, `.venv`, `venv`, `dist`, `build`, `target`, `.idea`, `.vscode`, `.git` |
| No config file | No `workspace.yml` — pure auto-discovery |

## Shared Team Context (`.adlc/`)

The parent repo's `.adlc/` directory is the single source of truth for
team context. It is created and maintained by other skills:

| Artifact | Path | Created By |
|---|---|---|
| PDRs | `.adlc/product/` | `product-specify`, `product-init` |
| ADRs | `.adlc/architecture/` | `architect-specify`, `architect-init` |
| CDRs | `.adlc/context/` | `levelup-specify`, `levelup-init` |
| Skills | `.adlc/skills/` | `team-skills` |

This skill does **not** create or modify `.adlc/` content. It only:
1. Verifies the parent has `.adlc/` (warns if missing).
2. Checks whether each child repo has its own `.adlc/` (informational).

## Safety

- **Read-only by default**: `/workspace` and `/workspace --status` make no changes.
- **`--link` requires clean parent tree**: uncommitted changes outside child repos abort the operation.
- **`--force`** removes child directories from the parent Git index (`git rm --cached`) before re-adding as submodules. Requires a clean working tree.
- **Idempotent**: already-registered submodules are skipped on re-run.
- **Child repos without a remote `origin`** are reported as errors and skipped.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I'll add `workspace.yml` for explicit repo list" | Adds config overhead; auto-discovery is simpler and sufficient | Use depth-1 discovery; exclude via `.gitignore` if needed |
| "I'll create `.adlc/` in child repos too" | Diverges from single-source-of-truth model | Keep `.adlc/` in parent only; children reference parent |
| "I'll skip the clean-tree check for `--link`" | Risks losing uncommitted parent changes | Require clean tree; tell user to commit or stash first |
| "I'll use worktrees instead of submodules" | Worktrees are for feature isolation, not multi-repo coordination | Use submodules for tracked multi-repo linking |

## Red Flags

- Running `--link` without checking parent working tree is clean.
- Running `--force` on a parent with uncommitted changes outside child repos.
- Creating `.adlc/` content in child repos (parent is the single source).
- Adding a `workspace.yml` or registry file (convention-only, no config).
- Excluding `.specify` from discovery (it may be a legitimate child repo).
- Modifying child repo contents during `--link` (only parent index changes).

## Verification

- [ ] Parent repo is a Git repository.
- [ ] Parent `.adlc/` exists (warn if missing, do not create).
- [ ] Child repos discovered at depth 1 (excluding `node_modules`, `.venv`, etc.).
- [ ] `--link` only runs when parent working tree is clean.
- [ ] Already-registered submodules are skipped (idempotent).
- [ ] Child repos without `origin` remote are reported as errors.
- [ ] `--status` reports branch, dirty state, unpushed count, SHA drift, `.adlc` presence per child.
- [ ] JSON output matches the Output Contract schema.

## Integration with Existing Skills

| Skill | Relationship |
|---|---|
| `product-specify` | Creates PDRs in parent `.adlc/product/` |
| `architect-specify` | Creates ADRs in parent `.adlc/architecture/` |
| `levelup-specify` | Creates CDRs in parent `.adlc/context/` |
| `workspace` (this skill) | Discovers child repos, links them, audits alignment |
| `team-boot` | Loads parent `.adlc` context at session start |

## 12-Factor Alignment

Factor XI (Directives as Code) — establishes a version-controlled multi-repo
workspace where shared decisions live in the parent and implementation repos
are linked as submodules.
