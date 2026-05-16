---
description: Refine and validate Product Decision Records through targeted clarification
  questions
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "clarify {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "clarify {ARGS}"
---


<!-- Extension: product -->
<!-- Config: .specify/extensions/product/ -->
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Focus on monetization decisions - we're reconsidering pricing"`
- `"Persona PDRs need more detail for roadmap planning"`
- `"PDR-003 consequences seem incomplete"`
- Empty input: Review all PDRs for completeness

## Goal

Identify underspecified areas in existing PDRs and refine them through targeted clarification questions. Ensure PDRs are complete, consistent, and ready for PRD generation.

## Role & Context

You are acting as a **Product Reviewer** ensuring PDR quality. Your role involves:

- **Validating** PDR completeness against standards
- **Identifying** gaps in consequences or alternatives
- **Detecting** conflicts between PDRs or with constitution
- **Refining** decisions through targeted clarification

### PDR Quality Checklist

Each PDR should have:

- [ ] Clear context explaining the problem/opportunity
- [ ] Explicit decision statement
- [ ] Positive AND negative consequences
- [ ] **Alternatives Considered** documented (neutral trade-offs, not "Rejected because")
- [ ] Risks identified with mitigation strategies
- [ ] Success metrics defined
- [ ] Status is accurate (Proposed/Accepted/Deprecated/Superseded/**Discovered**)
- [ ] No conflicts with other PDRs
- [ ] Alignment with constitution/vision principles
- [ ] **No fabricated rejection rationale** for reverse-engineered PDRs

## Outline

1. **Load Current State**: Parse `{REPO_ROOT}/.specify/drafts/pdr.md` and `{REPO_ROOT}/.specify/memory/constitution.md`
2. **Analyze PDRs**: Check each PDR against quality checklist
3. **Identify Gaps**: List areas needing clarification
4. **Interactive Refinement**: Ask targeted questions to fill gaps
5. **Update PDRs**: Write refined PDRs back to file

## Execution Steps

### Phase 1: Context Loading

**Objective**: Establish current PDR state

1. **Run Prerequisites Script**:
   - Execute `.specify/extensions/product/scripts/bash/setup-product.sh "clarify $ARGUMENTS"` from repo root
   - Parse JSON for paths to memory files
   - Handle errors gracefully if files don't exist

2. **Load PDR File**:
   - Read `{REPO_ROOT}/.specify/drafts/pdr.md`

3. **Load Constitution**:
   - Read `{REPO_ROOT}/.specify/memory/constitution.md` if it exists
   - Extract product vision and strategy principles
   - Note governance constraints

4. **User Focus**:
   - If user specified specific PDRs or areas, narrow scope
   - Otherwise, review all PDRs

### Phase 2: PDR Analysis

**Objective**: Identify quality gaps in each PDR

#### Quality Dimensions to Check

1. **Context Completeness**:
   - Is the problem clearly stated?
   - Are the market forces documented?
   - Is the decision scope clear?

2. **Decision Clarity**:
   - Is the decision actionable?
   - Are implementation implications clear?
   - Can this decision be validated/tested?

3. **Consequence Coverage**:
   - Are positive outcomes documented?
   - Are negative trade-offs acknowledged?
   - Are risks identified with mitigations?

4. **Success Metrics**:
   - Are metrics defined?
   - Are targets measurable?
   - Is measurement method specified?

5. **Alternatives Documentation**:
   - Are at least 2 alternatives listed?
   - Is trade-off reasoning clear for each?
   - Were reasonable options considered?

6. **Cross-PDR Consistency**:
   - Do decisions conflict with other PDRs?
   - Are dependencies between PDRs documented?
   - Is terminology consistent?

7. **Constitution Alignment**:
    - Does decision comply with vision principles?
    - Are strategy guidelines addressed?
    - Are violations explicitly justified?

### Phase 2.5: Risks & Gaps Analysis (Cross-Cutting)

**Objective**: Identify operational gaps, market risks, and product debt NOT documented across all sections

**Analysis Dimensions**:

| Dimension | Sections to Check | What to Look For |
|-----------|------------------|------------------|
| **Market Gaps** | Problem, Scope | Missing target segments, undefined competitive position |
| **Metric Gaps** | Success Metrics | No KPIs defined, no measurement approach |
| **Risk Gaps** | Consequences | Undocumented market risks, adoption risks |
| **Trade-off Gaps** | Consequences | Missing negative consequences, overly optimistic |

**Gap Identification Process**:

1. **Scan Each PDR**: Check completeness, identify missing critical sections
2. **Cross-PDR Analysis**: Find inconsistencies (e.g., "enterprise focus" in one PDR, "consumer" in another)
3. **Risk Severity**: CRITICAL (market failure/revenue loss), HIGH (adoption barrier), MEDIUM (debt), LOW (documentation)

**Gap ID Format**: Category-based (e.g., `metric-1` = Metric gap #1)

### Phase 2.6: Constitution Cross-Reference

**Objective**: Check PDRs against constitution for duplication and compliance

**Analysis**:

1. **Duplication Check**: Does PDR restate a constitutional principle? Is decision already mandated?
2. **Compliance Check**: Does decision violate vision MUST principles? Ignore strategy without justification?
3. **Override Classification**: Is this an intentional deviation? Justified sufficiently?

**Constitution Cross-Reference Table**:

| Issue Type | PDR | Constitution Principle | Action Required |
|------------|-----|----------------------|-----------------|
| Duplicate | PDR-002 | §Vision mandates B2B | Remove or convert to reference |
| Violation | PDR-003 | §Strategy requires freemium | Add override justification or change |
| Unclear | PDR-004 | Silent on pricing | Clarify relationship |

### Phase 3: Gap Identification

**Objective**: Prioritize clarification needs

Generate a gap report:

```markdown
## PDR Clarification Report

### Summary
- Total PDRs: [N]
- Complete: [N]
- Needs Clarification: [N]

### Gaps by PDR

| PDR | Title | Gap Type | Severity | Priority |
|-----|-------|----------|----------|----------|
| PDR-001 | [Title] | Missing alternatives | HIGH | 1 |
| PDR-002 | [Title] | Incomplete consequences | MEDIUM | 2 |
| PDR-003 | [Title] | No success metrics | HIGH | 3 |

### Cross-PDR Issues

| Issue | PDRs Affected | Description |
|-------|---------------|-------------|
| [Conflict] | PDR-001, PDR-003 | [Description of conflict] |
```

#### Gap Prioritization

- **CRITICAL**: Constitution violations, missing decision statement, no success metrics
- **HIGH**: No alternatives documented, missing consequences
- **MEDIUM**: Incomplete risks, unclear context
- **LOW**: Minor phrasing improvements, optional details

### Phase 4: Interactive Refinement

**Objective**: Fill gaps through targeted questions

#### Question Format

For each gap requiring clarification:

```markdown
## Clarification [N]: [PDR-XXX] - [Gap Type]

**Current State**: 
[Quote current PDR content]

**Gap Identified**: 
[Explain what's missing or unclear]

**Question**:
[Specific question to address the gap]

**Suggested Options** (if applicable):

| Option | Description |
|--------|-------------|
| A | [Option A] |
| B | [Option B] |
| C | [Custom response] |

Reply with your choice or provide additional context.
```

#### Constitution Cross-Reference Questions

When constitution issues are detected:

**For Duplicates**:

```markdown
## Clarification [N]: Constitution Duplication Detected

**PDR**: PDR-XXX - [Title]
**Constitution Principle**: §[Section] - [Principle Name]
**Issue**: This PDR documents a decision already mandated by constitution

**Options**:
| Option | Action | Result |
|--------|--------|--------|
| A | Remove PDR | Decision covered by constitution only |
| B | Convert to Reference | Keep PDR as "See Constitution §X" |
| C | Add Context | Keep PDR with "Aligns with Constitution §X" |
| D | Extend | Keep PDR as "Extends Constitution §X" |

Reply with your choice (A/B/C/D).
```

**For Violations (Option A PRIMARY - Amend Constitution)**:

```markdown
## Clarification [N]: Constitution Violation Detected ⭐

**PDR**: PDR-XXX - [Title]
**Decision**: [What the PDR decides]
**Constitution Principle**: §[Section] - [Principle]
**Conflict**: [How they conflict]

**The constitution should evolve with the product's needs.**

**⭐ RECOMMENDED: A. Amend Constitution**
Update constitution §[Section] to accommodate this decision. This establishes a new principle for future decisions.

**Alternative Options**:
B. Override in PDR - Document justification for deviation
C. Revise PDR - Change decision to comply with constitution
D. Remove PDR - Delete and follow existing constitution

**Consider Amendment If**:
- [ ] This decision will guide future product choices
- [ ] Product strategy has evolved since constitution was written
- [ ] Existing principle is too restrictive for current market

**Amendment Text**: [If choosing A, provide the specific constitutional amendment]

Reply with: "A [amendment text]" or "B/C/D [reasoning]"
```

#### Clarification Rules

- Present **one clarification at a time**
- **Prioritize by severity** - address CRITICAL/HIGH gaps first
- **For constitution violations, Option A (Amend) is PRIMARY**
- **Limit to 5 clarifications** per session (increased to 10 if PRD present)
- Allow user to **skip** non-critical clarifications
- **Summarize changes** after each answer
- User can say "done" to end clarification early

### Phase 5: PDR Updates

**Objective**: Write refined PDRs back to file

1. **Apply Clarifications**:
   - Update PDR sections with new content
   - Preserve structure and formatting
   - Update "Last Updated" timestamps

2. **Resolve Conflicts**:
   - If cross-PDR conflicts were found, propose resolution
   - Document decision to favor one PDR over another
   - Add cross-references between related PDRs

3. **Update Index**:
   - Refresh PDR index table if titles changed
   - Update status if applicable

4. **Write File**:
   - Atomic write to `{REPO_ROOT}/.specify/drafts/pdr.md`
   - Preserve any PDRs that weren't modified

### Phase 5.5: PDR Approval ⭐

**Objective**: Get user confirmation to approve PDRs before product requirements generation

This step is **critical** because `implement` only processes PDRs with "Accepted" status. PDRs with "Discovered" or "Proposed" status will be skipped.

#### Approval Request

```markdown
## PDR Approval ⭐

**Total PDRs**: [N]
**Status Distribution**:
- Accepted: [N]
- Proposed: [N]
- Discovered: [N]

**⚠️ Important**: Only "Accepted" PDRs will be processed by `/product.implement`

### Options

| Option | Action |
|--------|--------|
| A | Accept All - Change Proposed/Discovered → Accepted |
| B | Review Specific - Select individual PDRs to accept |
| C | Defer - Keep current status, decide later |

**Note**: You can also run `/product.clarify` again later to approve additional PDRs.

Reply with A, B, or C (or "done" to skip).
```

#### Bulk Approval (Option A)

If user chooses Option A:

```markdown
## Confirm Bulk Approval

Change [N] PDRs from Proposed/Discovered → Accepted?

| PDR | Current Status | New Status |
|-----|----------------|-------------|
| PDR-001 | Proposed | Accepted |
| PDR-002 | Discovered | Accepted |

Reply with "yes" to confirm or "no" to cancel.
```

#### Selective Approval (Option B)

If user chooses Option B, present PDRs one-by-one:

```markdown
## PDR Approval: PDR-XXX

**Title**: [Title]
**Current Status**: [Proposed/Discovered]
**Context**: [Brief summary]

**Options**:
| Option | Action |
|--------|--------|
| A | Accept - Change to "Accepted" |
| B | Keep - Keep current status |
| C | Skip - Move to next PDR |

Reply with A, B, or C for PDR-XXX.
```

#### Post-Approval

After approval (or if user chooses C to defer):

```markdown
## PDRs Approved

**Status Changes Applied**:
- PDR-001: Proposed → Accepted
- PDR-002: Discovered → Accepted
- PDR-007: Kept as Proposed

**Ready for Implementation**:
- Accepted PDRs: [N]
- Pending Approval: [N]

Run `/product.implement` to generate PRD.md from accepted PDRs.
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
- Respect user's time - limit to **5 clarifications**

### Constitution Authority

- Constitution violations are **always flagged**
- PDRs cannot override MUST principles without explicit justification
- Suggest constitution updates if conflict is systemic

### Quality Over Quantity

- Focus on **material gaps** that affect product decisions
- Skip **cosmetic improvements** unless user requests
- **Defer minor issues** if major gaps remain

## Completion Report

After clarification ends (all gaps addressed or user signals "done"):

```markdown
## PDR Clarification Complete

**Changes Made**:
- PDR-001: Updated consequences section
- PDR-002: Added Success Metrics
- PDR-003: Resolved conflict with PDR-001
- Constitution: Amended §Product Vision to allow market expansion

**Risks & Gaps Status**:
- Critical gaps identified: [N] → [N resolved]
- High priority gaps: [N] → [N resolved]
- Cross-PDR inconsistencies: [N] → [N resolved]

**Remaining Gaps** (deferred):
- metric-2: Secondary metrics (LOW)

**Cross-PDR Consistency**: ✅ Verified

**Constitution Alignment**:
- Duplicates resolved: [N]
- Violations addressed: [N]
- Constitution amended: [N] (if applicable)
- References added: [N]

**Recommended Next Steps**:
1. Review updated PDRs in `{REPO_ROOT}/.specify/drafts/pdr.md`
2. Run `/product.implement` to generate PRD
3. Or run `/spec.specify` to start feature development
```

## Workflow Guidance & Transitions

### After `/product.clarify`

**⚠️ Required**: You MUST run `/product.clarify` before `/product.implement` to approve PDRs.

**Status Workflow**:

- init → "Discovered" (brownfield)
- specify → "Proposed" (greenfield)
- **clarify → ask to approve → "Accepted"** ⭐
- implement → only reads "Accepted", skips Discovered/Proposed

Recommended next steps:

1. **Review Changes**: Verify PDR updates are accurate
2. **Approve PDRs**: Use Phase 5.5 to change status to "Accepted"
3. **Run `/product.implement`**: Generate full PRD from Accepted PDRs ⭐
4. **Start Features**: Use `/spec.specify` to create feature specs

### When to Use This Command

- **After `/product.specify`**: Refine initial PDRs before PRD generation
- **PDR Review**: Validate PDRs before major milestones
- **New Team Member**: Ensure PDRs make sense to fresh eyes
- **Conflict Resolution**: Resolve identified inconsistencies

### When NOT to Use This Command

- **No PDRs exist**: Use `/product.specify` first to create PDRs
- **Brownfield products**: Use `/product.init` to reverse-engineer PDRs
- **Feature-level**: Feature PDRs are refined via `/spec.clarify`

## Context

$ARGUMENTS