---
description: Session-based ad-hoc task execution without file artifacts (ENFORCED
  WORKFLOW)
mode: quick.enforced
scripts:
  sh: 'REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

    echo "REPO_ROOT=''$REPO_ROOT''"

    echo "CURRENT_BRANCH=''$CURRENT_BRANCH''"

    '
  ps: '$repoRoot = git rev-parse --show-toplevel 2>$null | Select-Object -First 1

    if (-not $repoRoot) { $repoRoot = Get-Location }

    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null | Select-Object -First
    1

    if (-not $currentBranch) { $currentBranch = "main" }

    "REPO_ROOT=''$repoRoot''"

    "CURRENT_BRANCH=''$currentBranch''"'
---


<!-- Extension: quick -->
<!-- Config: .specify/extensions/quick/ -->
## ⚠️ ENFORCEMENT MODE: MANDATORY SEQUENTIAL WORKFLOW

### CRITICAL RULES
1. **DO NOT SKIP ANY PHASE** - Each phase must complete before proceeding
2. **MUST WAIT FOR USER CONFIRMATION** - Never auto-proceed
3. **STOP AT CHECKPOINTS** - Explicit stop markers require pause
4. **NO FILE READING WITHOUT CONTEXT** - Cannot read files until Phase 3 (Context Discovery) approved

**Failure to follow these rules violates the Quick extension contract.**

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Execute a **strictly enforced, session-based, ad-hoc task workflow** without creating any file artifacts. All interactions happen in conversation, following the 12-factors methodology:

### MANDATORY PHASES (MUST EXECUTE IN ORDER):
**Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8**

**DO NOT SKIP ANY PHASE. DO NOT READ FILES UNTIL PHASE 3.**

---

## ⚠️ ENFORCEMENT CHECKPOINT 1: Mission Brief

### STOP: DO NOT PROCEED WITHOUT USER INPUT

You **MUST FIRST** collect Mission Brief information before reading ANY files or doing ANY analysis.

---

### MANDATORY: Ask These Questions FIRST

```markdown
## Mission Brief Questions

### Question 1: What needs to be done?
What is the primary task, feature, fix, or change you need?

### Question 2: What defines success?
How will we know when this is complete? What criteria must be met?

### Question 3: Any constraints? (ask if relevant)
Time constraints? Priority? Dependencies? Technical limitations?
```

**⚠️ STOP HERE**: Wait for user to answer these questions. **DO NOT read any files yet.**

---

### CHECKPOINT 1: Display Mission Brief for APPROVAL #1

After collecting user answers, display Mission Brief in this EXACT format:

```markdown
## Mission Brief

**Goal**: {user's response to Question 1}

**Success Criteria**:
- {user's response to Question 2}
- (split into multiple bullet points if needed)

**Constraints**:
- {user's response to Question 3}
- "None" if no constraints
```

### MANDATORY: Get User Confirmation

```markdown
**Proceed with this Mission Brief?** (yes/no)
```

**⚠️ STOP**: Wait for explicit "yes" OR handle "no" response.

- If "no": Ask what needs to be adjusted. Re-display Mission Brief with changes. Ask again.
- If "yes": Proceed to Phase 3.

---

## ⚠️ ENFORCEMENT CHECKPOINT 2: Context Discovery

### STOP: MUST GET USER CONTEXT BEFORE CONTINUING

Before proceeding to any file reading or analysis, you MUST get user context.

---

### MANDATORY: Ask for Context

```markdown
## Context Discovery

Please provide any relevant context for the task:

- **Project files**: Specific files or directories to examine? (e.g., src/auth/login.ts)
- **Documentation**: Any existing specs, docs, or notes to reference?
- **Technical constraints**: Any technical limitations or preferences?
- **Examples**: Similar implementations or patterns to follow?
```

**Wait for user input.** User may provide:
- File paths to read
- General context explanations
- URLs or references
- "N/A" or "none" if not needed

### MANDATORY: Confirm Context Collected

```markdown
**Context received. Proceed?** (yes/no)
```

**⚠️ STOP**: Wait for "yes" to continue.

---

## ⚠️ ENFORCEMENT CHECKPOINT 3: Plan Generation (INTERNAL)

### DO NOT DISPLAY THIS TO USER

Based on Mission Brief + Context, generate a **mental plan** (not written down):

- Identify key components affected
- Determine technical approach
- Identify dependencies or risks
- Plan execution strategy

**This is AI internal reasoning only** - do NOT display or document the plan.

---

## ⚠️ ENFORCEMENT CHECKPOINT 4: Task Breakdown

### MANDATORY: Generate Task Checklist

Based on your mental plan, generate and display a **simple task checklist**:

```markdown
## Task Breakdown

- [ ] {Task 1 description}
- [ ] {Task 2 description}
- [ ] {Task 3 description}
- [ ] {Task 4 description}
- [ ] {Task 5 description}
```

**Guidelines**:
- Keep tasks concrete and actionable
- Each task should be completable in one conversation turn
- Organize logically (setup → core → polish)
- Aim for 3-8 tasks total (keep it compact)
- Use clear, specific descriptions

---

## ⚠️ ENFORCEMENT CHECKPOINT 5: Approval #2

### MANDATORY: Get Task List Approval

Display the task list and ask:

```markdown
## Ready to Execute

Here are the tasks I will execute:

{Your task list from above}

**Proceed with these tasks?** (yes/no)
```

**⚠️ STOP**: Wait for explicit "yes" OR handle "no" response.

- If "no": Ask what changes are needed. Regenerate task list. Ask again.
- If "yes": Proceed to Phase 7 (Execution).

---

## ⚠️ ENFORCEMENT CHECKPOINT 6: Sequential Execution

### MANDATORY: Execute Tasks ONE AT A TIME, IN ORDER

Do NOT execute multiple tasks simultaneously.

### For Each Task:

#### START: Display Task
```markdown
---
## Task {N}/{Total}: {task description}
```

#### EXECUTE: Read Files if Needed, Make Changes
- Read files if needed (use Read tool)
- Understand content first
- Make necessary changes using Write/Edit tools

#### VERIFY: Display What Was Done
```markdown
✅ **Completed**: {brief summary}

Changes made:
- {file 1}: {change summary}
- {file 2}: {change summary}
```

#### MARK PROGRESS
Display updated checklist:
```markdown
- [x] {Task 1 description}
- [ ] {Task 2 description}
```

#### PAUSE BEFORE NEXT TASK
Do NOT auto-proceed. Wait for user to confirm ready for next task:

```markdown
**Next task ready?** (yes/no)
```

**⚠️ STOP**: Wait for "yes" before starting next task.

---

### MANDATORY: Error Handling

**If a task fails:
1. **STOP IMMEDIATELY** - Do NOT continue to next task
2. Display error:

```markdown
❌ **Task Failed**: {task description}

Error: {error message}

What would you like to do?
- (1) Retry this task
- (2) Skip and continue to next task
- (3) Stop execution
```

3. **WAIT FOR USER DECISION** - Do NOT auto-retry or auto-skip
4. Act based on user choice

**Do NOT proceed automatically on error. Always ask user what to do.**

---

## ⚠️ ENFORCEMENT CHECKPOINT 7: Summary

### MANDATORY: Show Completion Status

After all tasks complete (or execution stops):

### Success Case
```markdown
## Quick Implementation Complete ✅

**All tasks completed successfully**:

- [x] {Task 1 description}
- [x] {Task 2 description}
- [x] {Task 3 description}

**Files modified**: {count files changed}

**Summary**: {what was accomplished}
**Next steps**: {optional testing, review, etc.}
```

### Partial Completion or Failure
```markdown
## Quick Implementation Summary

**Completed tasks**:
- [x] {Task 1 description}
- [x] {Task 2 description}

**Failed tasks**:
- [ ] {Task 3 description} → {error reason}

**Recommendation**: {what to do next}
```

---

## Critical Constraints (MANDATORY)

1. **NO FILE ARTIFACTS**: Do NOT create PLAN.md, TASKS.md, CONTEXT.md, MISSION_BRIEF.md, or any other workflow files
2. **SESSION-ONLY**: All interactions happen in conversation/memory
3. **NO AUTO-COMMIT**: Do NOT run git commands for commits (user decides)
4. **STOP ON ERROR**: Halt execution and ask user what to do on failure
5. **SEQUENTIAL ONLY**: Execute one task at a time, no parallel execution
6. **MARK PROGRESS**: Display checklist updates in conversation (not files)
7. **MINIMAL ARTIFACTS**: Only create/update code/project files as needed
8. **ENFORCED CHECKPOINTS**: Must stop at each ⚠️ ENFORCEMENT CHECKPOINT and wait for user

---

## Output Notes

- All file modifications done in actual codebase
- No workflow/documentation files created
- User manages git commits manually
- Execution history is conversation-based only
- **Phases MUST execute in order, no skipping**