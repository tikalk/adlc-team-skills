---
name: product-clarify
description: Refine and validate Product Decision Records through targeted clarification questions. Review PDR completeness, detect conflicts, approve decisions, and update status to Accepted. Use before /product.implement.
disable-model-invocation: true
---

# product-clarify

## What this skill does

Reviews existing PDRs for quality gaps, asks targeted clarification questions, and promotes approved PDRs to **Accepted** status. This is the quality gate before PRD generation.

**Input**: Individual `PDR-*.md` files in `.adlc/drafts/pdr/` (status Proposed or Discovered)

**Output**: Updated `PDR-*.md` files (status Accepted where approved), regenerated `pdr.md` index

## When to use

- After `/product.specify` or `/product.init` to refine initial PDRs
- Before `/product.implement` to approve PDRs (required — implement skips non-Accepted)
- Periodic PDR review before milestones
- Resolving inconsistency flags from cross-feature-area analysis

## When NOT to use

- No PDRs exist (use `/product.specify` or `/product.init` first)

## Execution Steps

### Phase 1: Load PDRs

1. **Run setup script**:
```bash
sh: scripts/bash/setup-product-clarify.sh [--json]
ps: scripts/powershell/setup-product-clarify.ps1
```

2. **Read all PDR files** from `{REPO_ROOT}/.adlc/drafts/pdr/PDR-*.md`
3. **Read constitution** from `{REPO_ROOT}/.adlc/memory/constitution.md` if exists
4. **Build inventory**:
```markdown
| PDR | Title | Status | Category |
|-----|-------|--------|----------|
| PDR-001 | Target Market | Proposed | Problem |
| PDR-002 | Primary Persona | Proposed | Persona |
```

### Phase 2: PDR Quality Analysis

Check each PDR against standards:

| Dimension | Check | Severity if Missing |
|-----------|-------|---------------------|
| Context | Problem clearly stated | MEDIUM |
| Decision | Actionable, testable | HIGH |
| Consequences | Positive AND negative | HIGH |
| Success Metrics | Defined with targets | HIGH |
| Alternatives | At least 2 with neutral trade-offs | HIGH |
| Constitution | Aligns with vision | CRITICAL |

**Quality checklist**:
- [ ] Clear context explaining the problem/opportunity
- [ ] Explicit, actionable decision statement
- [ ] Positive AND negative consequences documented
- [ ] At least 2 alternatives with neutral trade-offs (not "rejected because")
- [ ] Success metrics defined
- [ ] Risks identified with mitigation strategies
- [ ] Valid status value
- [ ] No conflicts with other PDRs
- [ ] Alignment with constitution/vision principles

### Phase 3: Cross-PDR Consistency

1. **Conflicting Decisions**: Same concept, different decisions across PDRs
2. **Missing Dependencies**: PDRs that should reference each other
3. **Terminology Drift**: Same concept named differently
4. **Priority Conflicts**: One PDR says B2B, another assumes B2C

### Phase 4: Gap Identification

Generate gap report:
```markdown
## PDR Clarification Report

| PDR | Title | Gap Type | Severity |
|-----|-------|----------|----------|
| PDR-001 | [Title] | Missing alternatives | HIGH |
| PDR-002 | [Title] | Incomplete consequences | MEDIUM |
```

**Severity**:
- **CRITICAL**: Constitution violations, missing decision statement, no success metrics
- **HIGH**: No alternatives, missing consequences
- **MEDIUM**: Incomplete risks, unclear context
- **LOW**: Minor phrasing

### Phase 5: Interactive Refinement

For each gap, present one clarification at a time:

```markdown
## Clarification [N]: PDR-XXX — [Gap Type]

**Current State**:
[Quote current PDR content]

**Gap Identified**:
[Explain what's missing]

**Question**:
[Specific question]

**Suggested Options**:
| Option | Description |
|--------|-------------|
| A | [Option A] |
| B | [Option B] |
| C | [Custom response] |
```

**Rules**:
- Present **one clarification at a time**
- **Prioritize by severity** — CRITICAL/HIGH first
- **Limit to 5 clarifications** per session
- Allow user to **skip** non-critical clarifications
- **Summarize changes** after each answer

### Phase 6: Constitution Violations (if any)

**For Duplicates**:
```markdown
## Constitution Duplication Detected

**PDR**: PDR-XXX — [Title]
**Constitution Principle**: §[Section] — [Principle]

**Options**:
| Option | Action |
|--------|--------|
| A | Remove PDR |
| B | Convert to Reference |
| C | Add Context |
| D | Extend |
```

**For Violations** (⭐ RECOMMENDED: Amend Constitution):
```markdown
## Constitution Violation Detected ⭐

**⭐ RECOMMENDED: A. Amend Constitution**
Update constitution §[Section] to accommodate this decision.

**Alternatives**:
B. Override in PDR — Document justification
C. Revise PDR — Change decision to comply
D. Remove PDR — Delete and follow constitution
```

### Phase 7: Update PDR Files

1. **Apply clarifications** per-file
2. **Update status** where applicable
3. **Update "Last Updated"** timestamps
4. **Regenerate `pdr.md` index**

### Phase 8: PDR Approval ⭐

**Critical**: `/product.implement` only processes PDRs with **Accepted** status.

```markdown
## PDR Approval ⭐

**Total PDRs**: [N]
**Status Distribution**:
- Accepted: [N]
- Proposed: [N]
- Discovered: [N]

**Options**:
| Option | Action |
|--------|--------|
| A | Accept All — Change Proposed/Discovered → Accepted |
| B | Review Specific — Select individual PDRs |
| C | Defer — Keep current status |
```

**Bulk approval** (Option A):
```markdown
## Confirm Bulk Approval

Change [N] PDRs to Accepted?

| PDR | Current | New |
|-----|---------|-----|
| PDR-001 | Proposed | Accepted |
| PDR-002 | Discovered | Accepted |
```

**Post-approval**:
```markdown
## PDRs Approved

**Ready for Implementation**:
- Accepted PDRs: [N]
- Pending: [N]

Run `/product.implement` to generate PRD.md.
```

## Key Rules

### Non-Destructive Refinement
- **Never delete** existing PDRs without explicit user approval
- **Preserve original intent** when updating wording
- **Add, don't replace** consequences and alternatives
- **Mark changes** with updated timestamps

### Focused Clarification
- Ask **one question at a time**
- Make questions **specific and answerable**
- Provide **suggested options** when possible
- Respect user's time

### Constitution Authority
- Constitution violations are **always flagged**
- PDRs cannot override MUST principles without justification
- Suggest constitution updates if conflict is systemic

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `PDR_INDEX` — `{REPO_ROOT}/.adlc/drafts/pdr/pdr.md`
- `CONSTITUTION` — `{REPO_ROOT}/.adlc/memory/constitution.md`

## 12-Factor Alignment

- **Factor III (Mission Definition)**: Ensures product mission is well-defined before execution
- **Factor VII (Quality Gates)**: Applies human judgment before automated generation

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The PDRs look fine — let's skip clarify." | Implement will skip non-Accepted PDRs, silently dropping decisions from the PRD. |
| "I'll just accept all at once." | Bulk accept without review risks embedding bad decisions into the PRD. |
| "A warning on constitution is basically okay." | Constitution violations are CRITICAL because they undermine product coherence. |

## Red Flags

- **Skipping the approval step** — without Accepted status, implement ignores the PDR.
- **Accepting without reading** — defeats the purpose of the quality gate.
- **Not flagging cross-PDR conflicts** — inconsistent PDRs produce an incoherent PRD.

## Verification

- [ ] All PDR files read and inventoried
- [ ] Quality checklist applied to each PDR
- [ ] Cross-PDR consistency verified
- [ ] Constitution alignment checked
- [ ] Gaps identified and prioritized
- [ ] Clarifications applied per-file
- [ ] `pdr.md` index regenerated
- [ ] Approval phase completed (Accept/Review/Defer)
- [ ] Accepted PDRs have status "Accepted" in their files
- [ ] No duplicate or missing PDR IDs
