---
description: Session-based ad-hoc task execution with per-task extension hooks (LOW-FRICTION MODE)
mode: quick
scripts:
  sh: |
    # Try to source common.sh from typical locations
    for path in "$(pwd)/.specify/scripts/bash/common.sh" "$(dirname "$(pwd)")/scripts/bash/common.sh"; do
        if [[ -f "$path" ]]; then
            source "$path" 2>/dev/null && break
        fi
    done
    REPO_ROOT=$(get_repo_root 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || pwd)
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    echo "REPO_ROOT='$REPO_ROOT'"
    echo "CURRENT_BRANCH='$CURRENT_BRANCH'"
  ps: |
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $commonPath = Join-Path $scriptDir "..\..\..\scripts\powershell\common.ps1"
    if (Test-Path $commonPath) { . $commonPath }
    $repoRoot = Get-RepoRoot
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $currentBranch) { $currentBranch = "main" }
    "REPO_ROOT='$repoRoot'"
    "CURRENT_BRANCH='$currentBranch'"
---

## Quick: Low-Friction Session-Based Task Execution

### Design Principles

1. **Minimal stops** - Only one stop (after Mission Brief)
2. **Per-task hooks** - Extension hooks fire before/after each task (e.g., auto-commit via git extension)
3. **Auto-proceed** - No pauses between tasks
4. **Error hooks** - Extension hooks fire on failure before asking user

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

## ⚠️ CRITICAL: Pre-Execution Checks

**MUST complete these checks before proceeding to execution:**

### Step 1: Extension Hooks (before implementation)

**🔴 MANDATORY - DO NOT SKIP THIS STEP**

Execute the following steps in order:

1. **Read** `{REPO_ROOT}/.specify/extensions.yml`
2. **Locate** the `hooks.before_implement` section in the YAML
3. **Filter** the hooks:
   - Remove any hooks where `enabled` is explicitly `false`
   - Keep hooks where `enabled` is `true` or not specified
4. **For each remaining hook**, execute based on its `optional` flag:
   - **If `optional: false` (MANDATORY)**:
     - Read the command file for the hook from the installed extension commands directory
     - **Execute the instructions in that command file IMMEDIATELY**
     - Wait for the hook to complete before proceeding
     - If the command file is not found, log a warning and continue
   - **If `optional: true` (OPTIONAL)**:
     - Display the hook details to the user:
       ```
       ## Extension Hooks

       **Optional Pre-Hook**: {extension}
       Command: `/{command}`
       Description: {description}

       Prompt: {prompt}
       To execute: `/{command}`
       ```
     - Allow the user to decide whether to execute
5. **If** `{REPO_ROOT}/.specify/extensions.yml` does not exist or has no `hooks.before_implement` entries, **continue silently** - this is normal

**⚠️ WARNING: Skipping mandatory hooks violates the quick.implement contract.**

---

## Execution: Per-Task Hook Dispatch

### For Each Task (IN ORDER):

1. **Display task**: `## Task {N}: {description}`

2. **Dispatch `before_task_execute` hooks**:
   - Read `{REPO_ROOT}/.specify/extensions.yml`
   - Locate the `hooks.before_task_execute` section
   - Filter out hooks where `enabled` is explicitly `false`
   - For each remaining hook, execute based on its `optional` flag:
     - **Mandatory** (`optional: false`): Read and execute the command file immediately
     - **Optional** (`optional: true`): Skip silently (do not prompt -- maintain low-friction flow)
   - If no hooks registered or file does not exist, continue silently

3. **Execute**: Read files if needed, make changes

4. **Dispatch `after_task_execute` hooks**:
   - Read `{REPO_ROOT}/.specify/extensions.yml`
   - Locate the `hooks.after_task_execute` section
   - Filter out hooks where `enabled` is explicitly `false`
   - For each remaining hook, execute based on its `optional` flag:
     - **Mandatory** (`optional: false`): Read and execute the command file immediately
     - **Optional** (`optional: true`): Skip silently (do not prompt -- maintain low-friction flow)
   - If no hooks registered or file does not exist, continue silently

5. **Auto-proceed** to next task (no pause)

### After All Tasks Complete

Display summary:

```markdown
## Quick Implementation Complete

**Tasks completed**:
- [x] Task 1: ...
- [x] Task 2: ...
- [x] Task 3: ...

**Files modified**: {count}

**Next steps**: {optional}
```

---

## Post-Execution Checks

### Step 2: Extension Hooks (after implementation)

**Execute after all tasks are complete:**

1. **Read** `{REPO_ROOT}/.specify/extensions.yml`
2. **Locate** the `hooks.after_implement` section in the YAML
3. **Filter** the hooks:
   - Remove any hooks where `enabled` is explicitly `false`
   - Keep hooks where `enabled` is `true` or not specified
4. **For each remaining hook**, execute based on its `optional` flag:
   - **If `optional: false` (MANDATORY)**:
     - Read the command file for the hook from the installed extension commands directory
     - **Execute the instructions in that command file IMMEDIATELY**
     - Wait for the hook to complete before proceeding
     - If the command file is not found or execution fails, log a warning and continue
   - **If `optional: true` (OPTIONAL)**:
     - Display the hook details to the user:
       ```
       ## Extension Hooks

       **Optional Hook**: {extension}
       Command: `/{command}`
       Description: {description}

       Prompt: {prompt}
       To execute: `/{command}`
       ```
     - Allow the user to decide whether to execute
5. **If** `{REPO_ROOT}/.specify/extensions.yml` does not exist or has no `hooks.after_implement` entries, **continue silently**

---

## Error Handling

If a task fails:

1. **Dispatch `after_task_execute` hooks** (allows WIP checkpoint if git extension is configured):
   - Same dispatch logic as step 4 above
   - Hooks that auto-commit will capture the WIP state

2. **Display error**:
   ```markdown
   **Task Failed**: {task description}

   Error: {error message}

   What would you like to do?
   - (1) Retry this task
   - (2) Skip to next task
   - (3) Stop execution
   ```

3. **Wait for user decision** - do not auto-retry or auto-skip

---

## Critical Constraints

1. **1 stop only** - Mission Brief confirmation is the only interactive stop
2. **Per-task hooks** - `before_task_execute` / `after_task_execute` hooks dispatch around each task (configurable via extensions)
3. **No pauses between tasks** - Auto-proceed after hooks complete
4. **Hooks on error** - `after_task_execute` hooks fire on failure before asking user what to do
5. **No file artifacts** - No PLAN.md, TASKS.md, or other workflow files
6. **Session-only** - All interaction in conversation
7. **Manual final commit** - User decides when to push/merge

---

## Per-Task Commit Messages (when git extension is enabled)

When the git extension is installed with `after_task_execute.enabled: true` in `.specify/extensions/git/git-config.yml`, the commit message is controlled by the `auto_commit.after_task_execute.message` setting. For example, users can configure:

```yaml
auto_commit:
  after_task_execute:
    enabled: true
    message: "[quick] Task checkpoint"
```

Which produces commits like:
```
[quick] Task 1: Add error handling to login API
```

---

## Output Notes

- Task execution happens in actual codebase
- No workflow/documentation files created
- Per-task commits provide checkpoint history (when git extension is configured)
- User can `git reset` to any task if needed (when commits are enabled)
- User manages final push/merge manually
