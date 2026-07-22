---
name: product-roadmap
description: Track milestone progress from PDR status and feature completion. Shows completion percentages, updates PDR status to Completed when milestones are done, and optionally syncs with external project management tools. Use for weekly progress checks and milestone validation.
disable-model-invocation: true
---

# product-roadmap

## What this skill does

Tracks product milestone progress by analyzing PDR status fields. Optionally updates PDR status to **Completed** when milestones are finished.

**Key functions**:
1. **Read PDR statuses** from `.adlc/drafts/pdr/` and `.adlc/memory/pdr/`
2. **Group by milestone** (PDRs with Category = Milestone)
3. **Show completion percentages**
4. **Update PDR status** to Completed (if requested)

## When to use

- Weekly progress check
- After sprint to update PDR status
- Before release to verify milestone completion
- Quarterly roadmap review

## When NOT to use

- No PDRs exist (use `/product.specify` or `/product.init` first)
- You want to create PDRs (use `/product.specify`)

## Execution Steps

### Phase 1: Load PDRs

```bash
sh: scripts/bash/setup-product-roadmap.sh [--json]
ps: scripts/powershell/setup-product-roadmap.ps1
```

**Read PDR files** (memory first, drafts fallback):
1. `{REPO_ROOT}/.adlc/memory/pdr/PDR-*.md` (Accepted/Completed)
2. `{REPO_ROOT}/.adlc/drafts/pdr/PDR-*.md` (Proposed/Discovered)

### Phase 2: Identify Milestones

Find PDRs with `Category: Milestone`. These define the roadmap structure.

```markdown
| Milestone PDR | Target Date | Features |
|---------------|-------------|----------|
| PDR-010 | M01: Q2 User Auth | PDR-003, PDR-004, PDR-005 |
| PDR-011 | M02: Q3 Enhancements | PDR-008, PDR-009 |
```

### Phase 3: Analyze Feature PDR Completion

For each non-milestone PDR, check status:

| Status | Meaning |
|--------|---------|
| Completed | All work done |
| Accepted | Approved, in progress |
| Proposed | Not yet started |
| Discovered | Brownfield, not yet approved |

### Phase 4: Aggregate by Milestone

```markdown
## Product Roadmap Progress

### Milestone M01: Q2 User Auth (60%)

| Feature PDR | Feature | Status |
|-------------|---------|--------|
| PDR-003 | OAuth2 Login | ✅ Complete |
| PDR-004 | SSO Integration | ✅ Complete |
| PDR-005 | Password Reset | 🔄 In Progress |
| PDR-006 | Session Management | ⏳ Not Started |

**Overall**: 2/4 features complete (50%)
```

### Phase 5: Update PDR Status (Optional)

**Only if user explicitly requests update** (e.g., "update" in arguments):

For each completed milestone or feature:

| Current Status | New Status | Action |
|----------------|------------|--------|
| Proposed | Completed | Update to Completed |
| Accepted | Completed | Update to Completed |
| Discovered | Completed | Update to Completed |
| Completed | (no change) | Keep as is |

**Write updated PDR files** with new status, preserving all other content.

**Regenerate `pdr.md` index** after updates.

### Phase 6: Sync with External Tools (Optional)

When user runs `/product.roadmap --sync`:

1. **Detect available tools**:
   - MCP: `github_projects_list`, `gitlab_epics_list`, `jira_get_roadmap`, `linear_cycles_list`
   - CLI: `gh`, `glab`, `jira`, `linear`

2. **Pull milestones** and compare with PDR milestones
3. **Report discrepancies** (warning only — non-blocking)

## Key Rules

### PDR References Required
- Only track PDRs with explicit milestone linkage
- Milestone PDRs (Category = Milestone) define roadmap structure
- Feature PDRs linked via "Related PDRs" section

### Status Updates
- Only update PDR status, not PRD directly
- `/product.implement` will regenerate PRD with updated status
- Preserve all other PDR fields when updating status

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `PDR_MEMORY_DIR` — `{REPO_ROOT}/.adlc/memory/pdr`
- `PRD_FILE` — `{REPO_ROOT}/PRD.md`

## 12-Factor Alignment

- **Factor III (Mission Definition)**: Tracks mission progress against planned milestones
- **Factor IX (Traceability)**: Links progress back to decision records

## Verification

- [ ] All PDR files loaded (memory + drafts)
- [ ] Milestone PDRs identified
- [ ] Feature PDRs grouped by milestone
- [ ] Completion percentages calculated correctly
- [ ] Progress report generated
- [ ] Status updates applied only when explicitly requested
- [ ] `pdr.md` index regenerated after any updates
