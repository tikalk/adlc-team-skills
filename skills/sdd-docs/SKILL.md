---
name: sdd-docs-publish
description: Publish externally-stored SDD docs (PDRs, PRDs, ADRs, ADs, eval artifacts, CDRs, mission state) to a git remote via draft PR. Triggered explicitly by the user; no other skill invokes it automatically.
disable-model-invocation: true
---

# sdd-docs-publish

## What this skill does

Publishes SDD docs from an external `sdd_docs_location` to a git remote by creating a branch, committing the current project's subfolder, and opening a draft PR.

This skill does nothing when SDD docs are stored in-project (the default). It is the only skill that performs git operations against `sdd_docs_location`.

## When to use

- After `product-implement`, `architect-implement`, `evals-implement`, or `mission-brief` has written SDD artifacts to an external location and you want to push them to a shared remote.

### When NOT to use

- `sdd_docs_location` is not configured — SDD artifacts are stored in-project and are already part of the project's own git workflow.
- The external location's working tree has uncommitted changes you do not want to publish yet.

## Process

### User Input

```text
$ARGUMENTS
```

**Examples of User Input**:

- `"--ready"` — Create a ready PR instead of a draft PR.
- Empty input — Create a draft PR (default).

### Flags

- `--ready`: Create a ready PR instead of a draft PR.

### Outline

1. **Environment Setup** (Phase 0): Resolve paths and determine whether `sdd_docs_location` is configured.
2. **Git Readiness Check** (Phase 1): Verify the external location is a git repo and the working tree is clean.
3. **Publish** (Phase 2): Invoke the shared `git_publish_workflow()` against the current project's subfolder.
4. **Summary** (Phase 3): Report the outcome (draft PR, ready PR, push-only, local-only, or git-init offer).

### Execution Steps

#### Phase 0: Environment Setup

Run:

```bash
scripts/bash/setup-sdd-docs-publish.sh --json
```

Parse JSON for `REPO_ROOT`, `SDD_DOCS_LOCATION`, `SDD_ROOT`, `PROJECT_SUBFOLDER`, `SDD_CONFIGURED`, `SDD_IS_GIT`, `SDD_CLEAN`.

PowerShell equivalent:

```powershell
scripts/powershell/Setup-SddDocsPublish.ps1 --json
```

If `SDD_CONFIGURED` is `false` (i.e. `SDD_DOCS_LOCATION` is empty), print verbatim:

```text
sdd_docs_location is not configured. Nothing to publish — SDD artifacts are
stored in-project. Set sdd_docs_location in .adlc/init-options.json to enable
external storage and publishing.
```

and exit 0.

#### Phase 1: Git Readiness Check

If `SDD_IS_GIT` is `false`, proceed to Phase 3 with outcome `git_init_offered`.

If `SDD_CLEAN` is `false`, report:

```text
sdd_docs_location has uncommitted changes.
Please commit or stash changes before running /sdd-docs-publish.
```

#### Phase 2: Invoke `git_publish_workflow()`

Source shared helpers and call the reusable publish workflow, scoping the commit to the current project's subfolder:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAM_HELPERS=""
for candidate in \
  "${SCRIPT_DIR}/../../team/team-helpers.sh" \
  "${SCRIPT_DIR}/../team-helpers.sh" \
  "${SCRIPT_DIR}/team-helpers.sh"; do
  [[ -f "$candidate" ]] && { TEAM_HELPERS="$candidate"; break; }
done
[[ -n "$TEAM_HELPERS" ]] && source "$TEAM_HELPERS"

READY_FLAG=""  # set to "--ready" if user passed --ready
COMMIT_MSG="Publish SDD docs from ${PROJECT_SUBFOLDER}

$(git -C "$SDD_DOCS_LOCATION" status --porcelain -- "$PROJECT_SUBFOLDER")
"

git_publish_workflow "$SDD_DOCS_LOCATION" "sdd-docs" "$COMMIT_MSG" "$READY_FLAG"
```

PowerShell equivalent:

```powershell
$ReadyFlag = $false  # set to $true if user passed --ready
$Status = git -C "$env:SDD_DOCS_LOCATION" status --porcelain -- "$env:PROJECT_SUBFOLDER"
$CommitMsg = "Publish SDD docs from ${env:PROJECT_SUBFOLDER}`n`n$Status"
Invoke-GitPublishWorkflow -TargetDir "$env:SDD_DOCS_LOCATION" -BranchPrefix "sdd-docs" -CommitMsg $CommitMsg -Ready:$ReadyFlag
```

#### Phase 3: Report outcome

Echo the `PUBLISH_OUTCOME` returned by `git_publish_workflow()`:

- `draft_pr` — Draft PR created; include `PR_URL`.
- `ready_pr` — Ready PR created; include `PR_URL`.
- `push_only` — Pushed to remote but `gh` CLI is unavailable; prompt user to open PR manually.
- `local_only` — Committed to a local branch; prompt user to add a remote and push.
- `git_init_offered` — `sdd_docs_location` is not a git repo; offer `git init` + commit or write-only/no-op.

## Key Rules

- Publishing is not automatic — `product-implement`, `architect-implement`, `evals-implement`, and `mission-brief` never invoke git operations against `sdd_docs_location`.
- The commit is scoped to the current project's subfolder so a multi-project external location does not produce a misleading "everything changed" message.
- If `sdd_docs_location` is not configured, this skill exits cleanly without doing anything.

## Verification

- With `sdd_docs_location` unset, the setup script emits `"SDD_CONFIGURED": false` and the skill exits with the "not configured" message.
- With `sdd_docs_location` set to a scratch external directory, the setup script emits `"SDD_CONFIGURED": true` and a correct `SDD_ROOT`/`PROJECT_SUBFOLDER`.
- Running from two `git worktree add` checkouts of the same repo produces the same `PROJECT_SUBFOLDER`.

## Context

$ARGUMENTS
