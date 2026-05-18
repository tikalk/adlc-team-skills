# Quick Extension - Session-Based Ad-Hoc Task Execution

A streamlined, session-based workflow for ad-hoc task execution without file artifacts. Quick compresses the full spec-driven workflow into a single command with minimal interaction.

## Overview

Quick follows the 12-factors methodology in a compact, single-command session:

```
Mission Brief → Context Discovery → Task Breakdown → Execution (with per-task hooks)
```

**No file artifacts are created** - everything happens in the conversation with your AI agent.

### Low-Friction Design

Quick uses **per-task extension hooks** for checkpoint behavior:
- **1 stop**: After Mission Brief (for approval)
- **Per-task hooks**: `before_task_execute` / `after_task_execute` hooks fire around each task (e.g., auto-commit via git extension)
- **Auto-proceed**: No pauses between tasks
- **Error hooks**: Hooks fire on failure before asking user

When the git extension is installed with `after_task_execute.enabled: true`, this provides rollback capability via task-level commits while keeping interaction minimal.

## Quick Start

```bash
/quick.implement "fix authentication bug in login flow"
```

## How It Works

### Phase 1: Mission Brief (⚠️ Stop)
Quick asks 2-3 questions to understand what you're doing:
- What needs to be done?
- What defines success?
- Any constraints?

**Approval #1**: You see the Mission Brief and confirm before proceeding.
- **⚠️ Mandatory stop**: AI waits for "yes" confirmation

### Phase 2: Context Discovery (Auto)
You provide any relevant context:
- Project files to examine
- Documentation to reference
- Technical constraints

Quick proceeds automatically after brief input.

### Phase 3: Task Breakdown (Auto)
Quick generates a concrete task checklist:
```markdown
- [ ] Add error handling to login API
- [ ] Update session token validation
- [ ] Add unit tests for auth flow
```

**No stop** - proceeds directly to execution.

### Phase 4: Extension Hooks (Optional)

If extensions are installed (e.g., TDD), Quick checks for hooks before execution:

**Before execution**: `before_implement` hooks fire (e.g., TDD's RED→GREEN→REFACTOR)

**After execution**: `after_implement` hooks fire (e.g., TDD test validation)

Hooks execute seamlessly without interrupting the quick flow. See [Hook Support](#hook-support) for details.

### Phase 5: Execution with Per-Task Hooks
Quick executes tasks one at a time:
- Dispatches `before_task_execute` hooks
- Displays task being executed
- Makes necessary code changes
- Dispatches `after_task_execute` hooks (e.g., auto-commit via git extension)
- Proceeds to next task automatically

When the git extension is configured with `after_task_execute.enabled: true`:
```bash
git commit -m "[quick] Task 1: Add error handling to login API"
```

**Error handling**: If a task fails, `after_task_execute` hooks fire (allowing WIP checkpoint commits), then Quick asks what to do next.

### Phase 5: Summary
Quick shows completion status:
- All tasks completed ✅
- Files modified
- Next steps (testing, review, etc.)

## When to Use Quick

### Perfect For:
- Ad-hoc bug fixes
- Small features
- Refactoring tasks
- Documentation updates
- Quick experiments

### Not For:
- Large-scale features (use full spec-driven workflow)
- Architecture changes (use `/architect` extension)
- Complex multi-phase projects (use `/spec.specify`, `/spec.plan`, `/spec.tasks`, `/spec.implement`)
- Projects requiring extensive documentation (use full workflow)

## Commands

| Command | Purpose |
|---------|---------|
| `/quick.implement` | Session-based ad-hoc task execution |

## Key Differences from Full Workflow

| Aspect | Quick | Full Workflow |
|--------|-------|---------------|
| File Artifacts | None (session-only) | spec.md, plan.md, tasks.md, etc. |
| Commands | 1 (`/quick.implement`) | 4+ commands |
| Interactive Stops | 1 (Mission Brief) | Review at each stage |
| Checkpoints | Task-level commits | Review phases + commits |
| Task Complexity | Simple checklist | Detailed task breakdown with phases |
| Use Case | Ad-hoc, small tasks | Full-featured spec-driven development |

## Execution Flow

```text
/quick.implement "your task description"
  ↓
⚠️ CHECKPOINT 1: Mission Brief (2-3 questions)
  ↓
⚠️ STOP: Approval #1: "Proceed with this brief?"
  ↓
Context Discovery (brief input)
  ↓
Task Breakdown (auto-display)
  ↓
[before_implement hooks] → Optional: TDD, etc.
  ↓
Execution (auto-proceed with per-task hooks):
  Task 1 → [before_task_execute] → make changes → [after_task_execute]
  Task 2 → [before_task_execute] → make changes → [after_task_execute]
  Task 3 → [before_task_execute] → make changes → [after_task_execute]
  ↓
[after_implement hooks] → Optional: TDD validation, etc.
  ↓
Summary
```

## Checkpoint Strategy

Quick uses **per-task extension hooks** for checkpoint behavior:

| Checkpoint Type | Trigger | Purpose |
|-----------------|---------|---------|
| Mission Brief | User confirmation | Ensure understanding of goal |
| Per-task hooks | `before_task_execute` / `after_task_execute` | Extensible per-task behavior (commits, tests, lint, etc.) |
| Error hooks | `after_task_execute` on failure | Save WIP state before asking |

**Benefits** (when git extension `after_task_execute` is enabled):
- User can `git reset` to any task checkpoint
- Commit history shows progress
- No need to wait for user confirmation between tasks
- Error hooks save state before asking what to do
- Commits are **opt-in** -- disable by setting `after_task_execute.enabled: false` in git config

## Commit Format (when git extension is enabled)

**Successful task**:
```
[quick] Task 1: Add error handling to login API
```

**Failed task (WIP)**:
```
[quick] Task 2: WIP - session validation fix failed
```

The `[quick]` prefix and message are configurable via `.specify/extensions/git/git-config.yml`.

## Error Handling

If a task fails during execution:

```markdown
Task Failed: Add error handling to login API

Error: TypeError: Cannot read property 'token' of undefined

What would you like to do?
- Retry this task
- Skip and continue to next task
- Stop execution
```

Quick dispatches `after_task_execute` hooks on failure. When the git extension is configured, this creates a WIP checkpoint commit so you can always rollback.

## Examples

### Example 1: Bug Fix

```bash
/quick.implement "fix login page not redirecting after authentication"
```

**Mission Brief**:
- Goal: Fix login redirect issue
- Success: Login redirects to dashboard after successful auth
- Constraints: Must work with existing session token

**Task Breakdown**:
- [ ] Investigate login component redirect logic
- [ ] Fix redirect condition bug
- [ ] Test redirect flow
- [ ] Verify integration

### Example 2: Small Feature

```bash
/quick.implement "add dark mode toggle to settings page"
```

**Mission Brief**:
- Goal: Add dark mode toggle
- Success: Button toggles theme, persists preference
- Constraints: Use existing theme system

**Task Breakdown**:
- [ ] Add toggle UI component
- [ ] Implement theme switch logic
- [ ] Persist theme preference
- [ ] Test theme switching

## Installation

Quick is **bundled by default** in new projects:

```bash
specify init my-project
# Quick extension is automatically included
```

For manual installation:

```bash
specify extension add quick
```

## Configuration

Quick requires **no configuration** for basic operation. Per-task behavior is controlled via extension hooks:

### Enabling Per-Task Auto-Commits

Install the git extension and enable `after_task_execute` in `.specify/extensions/git/git-config.yml`:

```yaml
auto_commit:
  after_task_execute:
    enabled: true
    message: "[quick] Task checkpoint"  # customize the prefix/message as desired
```

This restores the classic Quick behavior of committing after each task.

## Limitations

1. **No file artifacts** - Quick doesn't save workflow state to files
2. **Session-only** - History is lost after conversation ends (but commits persist)
3. **Auto-proceed** - No pause between tasks (relies on commits for checkpoints)
4. **Simple task structure** - No complex phases, dependencies, or sync/async modes
5. **Manual push** - User decides when to push/merge commits

## Comparison to Full Spec-Driven Workflow

### Full Workflow (spec.md, plan.md, tasks.md, implement.md)
- Comprehensive documentation
- Multiple review checkpoints
- Complex task breakdown with phases
- Sync/async execution modes
- Atomic commits (configurable)
- File-based state management

### Quick (/quick.implement)
- No documentation files
- 1 interactive stop only
- Simple task checklist
- Sequential execution with per-task extension hooks
- Configurable task-level commits via git extension
- Session-only workflow (commits for history when enabled)

## Hook Support

Quick now supports extension hooks, enabling seamless integration with other Spec Kit extensions:

| Hook Point | When | Example Extension |
|------------|------|-------------------|
| `before_implement` | After Task Breakdown, before first task | TDD (RED→GREEN→REFACTOR) |
| `before_task_execute` | Before each individual task | Git (save progress) |
| `after_task_execute` | After each individual task | Git (task checkpoint commit) |
| `after_implement` | After all tasks complete | TDD (test validation) |

### TDD Integration Example

When the TDD extension is installed:

```bash
/quick.implement "add JWT authentication"
  ↓
Mission Brief → Context → Task Breakdown
  ↓
[before_implement] → TDD runs RED→GREEN→REFACTOR (in-session, no files)
  ↓
Execution with commits
  ↓
[after_implement] → TDD validation offered
  ↓
Summary
```

TDD runs entirely in-session when triggered from Quick:
- Condensed planning (3 questions instead of 5)
- Language auto-detection
- Test increment generation
- RED→GREEN→REFACTOR cycles

**No file artifacts** - TDD state is tracked in the conversation, preserving Quick's philosophy.

## Related Extensions

- **architect** - Architecture decision records and documentation
- **levelup** - Context module discovery and contribution
- **tdd** - Test-Driven Development workflow (RED→GREEN→REFACTOR)

## License

MIT

## Author

Agentic SDLC Team

## Repository

https://github.com/tikalk/agentic-sdlc-spec-kit/tree/main/extensions/quick
