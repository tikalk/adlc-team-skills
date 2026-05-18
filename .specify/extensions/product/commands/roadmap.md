---
description: Track milestone progress by analyzing feature spec completion status and updating PDR records
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "roadmap {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "roadmap {ARGS}"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"progress"` - Show completion progress without updating PDRs
- `"update"` - Analyze specs and update PDR status to Completed
- `"M01"` - Show progress for specific milestone only
- Empty input: Show progress and prompt for update

## Goal

Analyze feature specifications to determine milestone completion based on task completion, and optionally update PDR status.

**Key Functions**:

1. **Find all feature specs** with PDR references
2. **Analyze task completion** for each spec (read tasks.md)
3. **Aggregate by Milestone** to show completion %
4. **Update PDR status** to "Completed" when all tasks are done

## Role & Context

You are acting as a **Product Roadmap Analyst** tracking feature development progress. Your role involves:

- **Scanning** feature branches for specs with PDR references
- **Analyzing** task completion status in tasks.md
- **Computing** milestone completion percentages
- **Updating** PDR records when features are complete

### PDR Location Priority

| Priority | Location | Condition |
|----------|----------|-----------|
| 1st | `{REPO_ROOT}/.specify/memory/pdr.md` | Primary |
| 2nd | `{REPO_ROOT}/.specify/drafts/pdr.md` | Fallback |

## Outline

### Phase 1: Locate PDR File

1. **Determine PDR file location**:
   - First: `{REPO_ROOT}/.specify/memory/pdr.md`
   - Fallback: `{REPO_ROOT}/.specify/drafts/pdr.md`

2. **Verify file exists**:
   - If neither exists: Output "No PDR file found. Run product.implement first."
   - If exists: Proceed to Phase 2

### Phase 2: Find Feature Specs with PDR References

1. **Find all feature directories**:
   - Look for directories matching pattern `specs/*/` or `features/*/`
   - Or look for directories with `spec.md` file
   - Exclude directories that don't have spec.md

2. **For each feature directory**:
   - Read `spec.md` header
   - Look for:
     - `**Milestone Reference**:` field
     - `**Feature PDR Reference**:` field
   - If both fields exist and are not empty: record the spec
   - If either field is empty or missing: skip (no PDR linkage)

3. **Build spec inventory**:

   ```markdown
   | Spec Path | Milestone | Feature PDR |
   |-----------|-----------|--------------|
   | specs/auth/spec.md | M01: Q2 User Auth | PDR-003 |
   | specs/sso/spec.md | M01: Q2 User Auth | PDR-004 |
   ```

### Phase 3: Analyze Task Completion

1. **For each spec with PDR reference**:
   - Look for `tasks.md` in the same directory
   - If tasks.md exists:
     - Count total tasks (lines starting with `- [ ]` or `- [X]`)
     - Count completed tasks (lines with `[X]`)
     - Calculate completion percentage
   - If tasks.md doesn't exist:
     - Mark as "No tasks yet"
   - Determine if complete: (all tasks have [X])

2. **Task completion result**:

   ```markdown
   | Spec | Feature PDR | Tasks | Complete |
   |------|--------------|-------|----------|
   | specs/auth/spec.md | PDR-003 | 5/5 | Yes |
   | specs/sso/spec.md | PDR-004 | 3/6 | No |
   ```

### Phase 4: Aggregate by Milestone

1. **Group specs by Milestone**:
   - For each unique Milestone Reference
   - Count total specs assigned
   - Count completed specs

2. **Calculate milestone completion**:

   ```text
   Milestone M01: Q2 User Auth - 3/5 features (60%)
   - PDR-003: OAuth2 Login - Complete
   - PDR-004: SSO Integration - Complete  
   - PDR-005: Password Reset - 3/6 tasks (50%)
   - PDR-006: Session Management - Not started
   - PDR-007: Token Refresh - Not started
   ```

### Phase 5: Update PDR Status (If requested)

**Only execute if user explicitly requests update** (e.g., "update" in arguments):

1. **For each completed spec**:
   - Read the Feature PDR ID from spec
   - Read the PDR file
   - Find the PDR with matching ID
   - Change status from current to "Completed"

2. **Handle PDR Status**:

   ```text
   | Current Status | New Status | Action |
   |----------------|------------|--------|
   | Proposed | Completed | Update to Completed |
   | Accepted | Completed | Update to Completed |
   | Discovered | Completed | Update to Completed |
   | Completed | (no change) | Keep as is |
   | Deprecated | (no change) | Keep as is |
   ```

3. **Write updated PDR file**:
   - Update the PDR file with new statuses
   - Preserve all other PDR content

### Phase 6: Output Report

**Always output progress report** (even if not updating):

```markdown
## Product Roadmap Progress

### Milestone M01: Q2 User Auth (60%)

| Feature PDR | Feature | Tasks | Status |
|-------------|---------|-------|--------|
| PDR-003 | OAuth2 Login | 5/5 | ✅ Complete |
| PDR-004 | SSO Integration | 4/4 | ✅ Complete |
| PDR-005 | Password Reset | 3/6 | 🔄 In Progress |
| PDR-006 | Session Management | 0/8 | ⏳ Not Started |
| PDR-007 | Token Refresh | 0/5 | ⏳ Not Started |

**Overall**: 2/5 features complete (40%)

### Milestone M02: Q3 Enhancements (0%)

| Feature PDR | Feature | Tasks | Status |
|-------------|---------|-------|--------|
| PDR-008 | Analytics Dashboard | 0/10 | ⏳ Not Started |
| PDR-009 | Export Features | 0/6 | ⏳ Not Started |

**Overall**: 0/2 features complete (0%)

---

**To update PDR status**: Run `/product.roadmap update`
**To regenerate PRD**: Run `/product.implement`
```

## Key Rules

### PDR References Required

- Only analyze specs that have both `Milestone Reference` and `Feature PDR Reference` in header
- Specs without PDR linkage are excluded from roadmap tracking

### Task Completion Logic

- A spec is "complete" only when ALL tasks in tasks.md are marked [X]
- Partial completion is "in progress" - not complete

### Status Updates

- Only update PDR status, not PRD directly
- product.implement will regenerate PRD with updated status
- Preserve all other PDR fields when updating status

## Workflow Guidance

### When to Use This Command

- **Weekly check**: See current roadmap progress
- **After sprint**: Update PDR status for completed features
- **Before release**: Verify milestone completion

### After /product.roadmap

1. **If updated PDRs**: Run `/product.implement` to regenerate PRD with completion status
2. **If not ready to update**: Continue development, run again later

### Relationship to Other Commands

| Command | Purpose |
|---------|---------|
| `product.implement` | Generates PRD from PDRs |
| `product.roadmap` | Tracks progress, updates PDR status |
| `product.analyze` | Validates PDR-PRD consistency |

## Context

{ARGS}
