---
name: workspace-publish
description: Publish WORKSPACE_REPO_ROOT metadata (.adlc/, PRD.md, AD.md, specs/, evals/) to a git remote via draft PR. Triggered explicitly by the user; no other skill invokes it automatically.
disable-model-invocation: true
---

# workspace-publish

## What this skill does

Publishes workspace SDD metadata from an external `WORKSPACE_REPO_ROOT` to a
git remote by creating a branch, committing the metadata pathspec, and opening
a draft PR.

This skill does nothing when workspace metadata is stored in-project (the
default). It is the only skill that performs git operations against
`WORKSPACE_REPO_ROOT`.

## When to use

- After product/architect/evals/mission skills have written SDD artifacts to
  an external workspace and you want to push them to a shared remote.

### When NOT to use

- `WORKSPACE_REPO_ROOT` is not configured — artifacts are in-project.
- The workspace working tree has uncommitted changes you do not want yet.

## Process

### User Input

```text
$ARGUMENTS
```

**Flags**: `--ready` — create a ready PR instead of a draft.

### Execution

The dedicated publish script owns the full workflow (helper loading, validation,
git readiness, branch/commit/push/PR, structured JSON). SKILL.md only handles
user interaction and reporting.

```bash
scripts/bash/workspace-publish.sh --json $ARGUMENTS
```

```powershell
scripts/powershell/workspace-publish.ps1 -Json
```

Parse JSON for `PUBLISH_OUTCOME`, `PR_URL`, `WORKSPACE_REPO_ROOT`,
`WORKSPACE_CONFIGURED`.

### Outcomes

| PUBLISH_OUTCOME | Meaning |
|---|---|
| `not_configured` | In-project default; nothing to publish |
| `git_init_offered` | Target is not a git repo |
| `draft_pr` / `ready_pr` | PR created; include `PR_URL` |
| `push_only` | Pushed; open PR manually |
| `local_only` | Local branch only |

## Key Rules

- Publishing is never automatic from implement/mission skills.
- The script uses explicit pathspec `.adlc PRD.md AD.md specs evals` for
  status, staging, and commit — never `git add -A`.
- Helpers are not used for publishing; only `team-paths` for resolution.

## Context

$ARGUMENTS
