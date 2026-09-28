---
name: workspace-init
description: Initialize and coordinate a WORKSPACE_REPO_ROOT — shared SDD metadata repo holding .adlc/, PRD.md, AD.md, specs/, and evals/ outside (or as parent of) implementation repos. Discover child repos, link as submodules, audit health.
---

# workspace-init

## Overview

A workspace metadata repository (`WORKSPACE_REPO_ROOT`) holds shared SDD
artifacts at its root — no per-project subfolders:

```
workspace-root/   ← WORKSPACE_REPO_ROOT
├── .adlc/  PRD.md  AD.md  specs/  evals/
├── .gitmodules
├── backend-api/
└── frontend/
```

Child implementation repositories are discovered at depth 1 and optionally
linked as Git submodules.

## When to Use

- To create the workspace metadata layout (`--init`).
- After product/architect skills have written shared PDRs/ADRs and you have
  multiple implementation repos alongside.
- To audit workspace health: dirty trees, unpushed commits, SHA drift.

## Commands

| Command | Purpose |
|---|---|
| `/workspace-init --init` | Create `.adlc/`, `PRD.md`, `AD.md`, `specs/`, `evals/` |
| `/workspace-init` | Discover child repos, show summary status |
| `/workspace-init --link` | Convert child repos to Git submodules |
| `/workspace-init --status` | Detailed audit |
| `/workspace-init --dry-run` | Preview (combine with `--link` or `--init`) |
| `/workspace-init --force` | Convert repos already tracked by parent index |

## Execution

```bash
"$(dirname "$0")/../scripts/bash/workspace-init.sh" --json $ARGUMENTS
```

## Shared Team Context

| Artifact | Path | Created By |
|---|---|---|
| ADLC state | `.adlc/` | `workspace-init --init`, product/architect/evals/levelup skills |
| Product requirements | `PRD.md` | `product-implement`, `workspace-init --init` |
| Architecture description | `AD.md` | `architect-implement`, `workspace-init --init` |
| Specs | `specs/` | `workspace-init --init`, specify skills |
| Evals | `evals/` | `workspace-init --init`, evals skills |
| PDRs | `.adlc/product/`, `.adlc/drafts/pdr/` | `product-specify`, `product-init` |
| ADRs | `.adlc/architecture/`, `.adlc/drafts/adr/` | `architect-specify`, `architect-init` |
| CDRs | `.adlc/context/`, `.adlc/drafts/cdr/` | `levelup-specify`, `levelup-init` |

## Resolution of WORKSPACE_REPO_ROOT

1. `WORKSPACE_REPO_ROOT` environment variable
2. `workspace_repo_root` in project-local `.adlc/init-options.json`
3. Auto-discovery: parent of `git rev-parse --show-toplevel` contains `.adlc/`
4. Project root (in-project default)

## Safety

- Read-only by default (`/` and `--status`).
- `--link` requires a clean parent tree.
- Idempotent submodule registration.
