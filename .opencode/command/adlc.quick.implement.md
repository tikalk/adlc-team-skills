---
description: Session-based ad-hoc task execution with task-level commits (LOW-FRICTION
  MODE)
mode: quick
scripts:
  sh: "# Try to source common.sh from typical locations\nfor path in \"$(pwd)/.specify/scripts/bash/common.sh\"\
    \ \"$(dirname \"$(pwd)\")/scripts/bash/common.sh\"; do\n    if [[ -f \"$path\"\
    \ ]]; then\n        source \"$path\" 2>/dev/null && break\n    fi\ndone\nREPO_ROOT=$(get_repo_root\
    \ 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || pwd)\nCURRENT_BRANCH=$(git\
    \ rev-parse --abbrev-ref HEAD 2>/dev/null || echo \"main\")\necho \"REPO_ROOT='$REPO_ROOT'\"\
    \necho \"CURRENT_BRANCH='$CURRENT_BRANCH'\"\n"
  ps: '$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    $commonPath = Join-Path $scriptDir "..\..\..\scripts\powershell\common.ps1"

    if (Test-Path $commonPath) { . $commonPath }

    $repoRoot = Get-RepoRoot

    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null

    if (-not $currentBranch) { $currentBranch = "main" }

    "REPO_ROOT=''$repoRoot''"

    "CURRENT_BRANCH=''$currentBranch''"'
---


<!-- Extension: quick -->
<!-- Config: .specify/extensions/quick/ -->
## Quick: Low-Friction Session-Based Task Execution

### Design Principles

1. **Minimal stops** - Only one stop (after Mission Brief)
2. **Task-level commits** - Auto-commit after each task as checkpoints
3. **Auto-proceed** - No pauses between tasks
4. **Error commits** - Commit "WIP" on failure before asking user

---

## User Input

```text
$ARGUMENTS
```

Consider the user input before proceeding (if not empty).

---

## ⚠️ MANDATORY STOP: Mission Brief

### Collect Mission Brief

Ask the user these questions:

```markdown
## Mission Brief

**Question 1: What needs to be done?**
What is the primary task, feature, fix, or change you need?

**Question 2: What defines success?**
How will we know when this is complete? What criteria must be met?

**Question 3: Any constraints?** (if relevant)
Time constraints? Priority? Dependencies? Technical limitations?
```

Wait for user answers.

### Display Mission Brief

After collecting answers, display:

```markdown
## Mission Brief

**Goal**: {response to Question 1}

**Success Criteria**:
- {response to Question 2}

**Constraints**:
- {response to Question 3}
```

### ⚠️ STOP: Get User Confirmation

```markdown
**Proceed with this Mission Brief?** (yes/no)
```

**STOP HERE** - Wait for explicit "yes".

- If "no": Ask what needs to be adjusted, re-display, ask again.
- If "yes": Proceed to execution.

---

## Context Discovery (Auto)

After Mission Brief approved, ask briefly:

```markdown
## Context

Any specific files to examine? (optional)
```

Wait briefly for response, then proceed (can be empty/none).

---

## Task Breakdown (Auto)

Generate and display a simple task checklist:

```markdown
## Task Breakdown

- [ ] {Task 1}
- [ ] {Task 2}
- [ ] {Task 3}
- [ ] {Task 4}
```

**Do not ask for approval** - proceed directly to execution.

---

## Execution: Task-Level Commits

### For Each Task (IN ORDER):

1. **Display task**: `## Task {N}: {description}`

2. **Execute**: Read files if needed, make changes

3. **Commit after completion**:
   ```bash
   git add -A
   git commit -m "[quick] Task {N}: {task description}"
   ```

4. **Auto-proceed** to next task (no pause)

### After All Tasks Complete

Display summary:

```markdown
## Quick Implementation Complete ✅

**Tasks completed**:
- [x] Task 1: ...
- [x] Task 2: ...
- [x] Task 3: ...

**Files modified**: {count}

**Next steps**: {optional}
```

---

## Error Handling

If a task fails:

1. **Commit WIP state**:
   ```bash
   git add -A
   git commit -m "[quick] Task {N}: WIP - {brief error description}"
   ```

2. **Display error**:
   ```markdown
   ❌ **Task Failed**: {task description}

   Error: {error message}

   Committed WIP checkpoint.

   What would you like to do?
   - (1) Retry this task
   - (2) Skip to next task
   - (3) Stop execution
   ```

3. **Wait for user decision** - do not auto-retry or auto-skip

---

## Critical Constraints

1. **1 stop only** - Mission Brief confirmation is the only interactive stop
2. **Auto-commit after each task** - Provides rollback/checkpoint capability
3. **No pauses between tasks** - Auto-proceed after commit
4. **WIP commit on error** - Always commit before asking user what to do
5. **No file artifacts** - No PLAN.md, TASKS.md, or other workflow files
6. **Session-only** - All interaction in conversation
7. **Manual final commit** - User decides when to push/merge

---

## Commit Message Format

**Successful task**:
```
[quick] Task 1: Add error handling to login API
```

**Failed task (WIP)**:
```
[quick] Task 2: WIP - session validation fix failed
```

---

## Output Notes

- Task execution happens in actual codebase
- No workflow/documentation files created
- Commits provide checkpoint history
- User can `git reset` to any task if needed
- User manages final push/merge manually