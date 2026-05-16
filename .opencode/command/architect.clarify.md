---
description: Refine and validate system-level ADRs through targeted clarification
  questions
scripts:
  sh: .specify/extensions/architect/scripts/bash/setup-architect.sh "clarify {ARGS}"
  ps: .specify/extensions/architect/scripts/powershell/setup-architect.ps1 "clarify
    {ARGS}"
---


<!-- Extension: architect -->
<!-- Config: .specify/extensions/architect/ -->
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Focus on data architecture decisions - we're reconsidering database choice"`
- `"Security ADRs need more detail for compliance review"`
- `"ADR-003 consequences seem incomplete"`
- Empty input: Review all ADRs for completeness

## Goal

Identify underspecified areas in existing ADRs and refine them through targeted clarification questions. Ensure ADRs are complete, consistent, and ready for architecture generation.

## Role & Context

You are acting as an **Architecture Reviewer** ensuring ADR quality. Your role involves:

- **Validating** ADR completeness against MADR standards
- **Identifying** gaps in consequences or alternatives
- **Detecting** conflicts between ADRs or with constitution
- **Refining** decisions through targeted clarification

### ADR Quality Checklist

Each ADR should have:

- [ ] Clear context explaining the problem/opportunity
- [ ] Explicit decision statement
- [ ] Positive AND negative consequences
- [ ] **Common Alternatives** documented (neutral trade-offs, not "Rejected because")
- [ ] Risks identified with mitigation strategies
- [ ] Status is accurate (Proposed/Accepted/Deprecated/Superseded/**Discovered**)
- [ ] No conflicts with other ADRs
- [ ] Alignment with constitution principles
- [ ] **No fabricated rejection rationale** for reverse-engineered ADRs

## Outline

1. **Load Current State**: Parse `{REPO_ROOT}/.specify/drafts/adr.md` and `{REPO_ROOT}/.specify/memory/constitution.md`

**IMPORTANT - Path Resolution**:

- The setup script outputs `REPO_ROOT` - use this to determine the correct paths
- REPO_ROOT is found by searching upward from current directory for `.specify` directory
- NEVER use relative paths like `.specify/drafts/adr.md` - always use `{REPO_ROOT}/.specify/drafts/adr.md`
- When running from a subdirectory (e.g., `hermes-project/`), `.specify` may be in the parent directory

2. **Analyze ADRs**: Check each ADR against quality checklist
3. **Identify Gaps**: List areas needing clarification
4. **Interactive Refinement**: Ask targeted questions to fill gaps
5. **Update ADRs**: Write refined ADRs back to file

## Execution Steps

### Phase 1: Context Loading

**Objective**: Establish current ADR state

1. **Run Prerequisites Script**:
   - Execute `.specify/extensions/architect/scripts/bash/setup-architect.sh "clarify $ARGUMENTS"` from repo root
   - Parse JSON for paths to memory files
   - Handle errors gracefully if files don't exist

2. **Load ADR File**:
   - Read `{REPO_ROOT}/.specify/drafts/adr.md`
   - Parse ADR index and individual ADR sections
   - Count total ADRs and identify status distribution

3. **Load Constitution**:
   - Read `{REPO_ROOT}/.specify/memory/constitution.md` if it exists
   - Extract principles for alignment checking
   - Note governance constraints

4. **User Focus**:
   - If user specified specific ADRs or areas, narrow scope
   - Otherwise, review all ADRs

### Phase 2: ADR Analysis

**Objective**: Identify quality gaps in each ADR

#### Quality Dimensions to Check

1. **Context Completeness**:
   - Is the problem clearly stated?
   - Are the forces/drivers documented?
   - Is the decision scope clear?

2. **Decision Clarity**:
   - Is the decision actionable?
   - Are implementation implications clear?
   - Can this decision be validated/tested?

3. **Consequence Coverage**:
   - Are positive outcomes documented?
   - Are negative trade-offs acknowledged?
   - Are risks identified with mitigations?

4. **Alternatives Documentation**:
   - Are at least 2 alternatives listed?
   - Is rejection reasoning clear for each?
   - Were reasonable options considered?

5. **Cross-ADR Consistency**:
   - Do decisions conflict with other ADRs?
   - Are dependencies between ADRs documented?
   - Is terminology consistent?

6. **Constitution Alignment**:
    - Does decision comply with MUST principles?
    - Are SHOULD principles addressed?
    - Are violations explicitly justified?

### Phase 2.5: Risks & Gaps Analysis (Cross-Cutting)

**Objective**: Identify operational gaps, technical debt, SPOFs, and security concerns NOT documented across all views

**Analysis Dimensions**:

| Dimension | Views to Check | What to Look For |
|-----------|---------------|------------------|
| **Operational Gaps** | Operational (3.7), Deployment (3.6) | Missing monitoring, undefined on-call, no runbooks, unclear rollback |
| **Technical Debt** | Development (3.5), Information (3.3) | Deprecated dependencies, no tests, legacy code, schema debt |
| **Single Points of Failure** | Deployment (3.6), Concurrency (3.4) | Single DB instance, no redundancy, critical path bottlenecks |
| **Security Concerns** | All views | Unencrypted data, no auth, exposed secrets, missing audit trails |

**Gap Identification Process**:

1. **Scan Each View**: Check if view exists, identify missing critical sections, flag [TODO]/[TBD] areas
2. **Cross-View Analysis**: Find inconsistencies (e.g., "high availability" stated but single instance shown)
3. **Risk Severity**: CRITICAL (outage/breach/loss), HIGH (operational burden), MEDIUM (debt), LOW (documentation)

**Gap ID Format**: Section-based (e.g., `3.6.1` = Deployment View, gap #1)

### Phase 2.6: Constitution Cross-Reference

**Objective**: Check ADRs against constitution for duplication and compliance

**Analysis**:

1. **Duplication Check**: Does ADR restate a constitutional principle? Is decision already mandated?
2. **Compliance Check**: Does decision violate MUST principles? Ignore SHOULD without justification?
3. **Override Classification**: Is this an intentional deviation? Justified sufficiently?

**Constitution Cross-Reference Table**:

| Issue Type | ADR | Constitution Principle | Action Required |
|------------|-----|----------------------|-----------------|
| Duplicate | ADR-002 | §DataStorage mandates PostgreSQL | Remove or convert to reference |
| Violation | ADR-003 | §Security requires JWT | Add override justification or change |
| Unclear | ADR-004 | Silent on caching | Clarify relationship |

### Phase 3: Gap Identification

**Objective**: Prioritize clarification needs

Generate a gap report:

```markdown
## ADR Clarification Report

### Summary
- Total ADRs: [N]
- Complete: [N]
- Needs Clarification: [N]

### Gaps by ADR

| ADR | Title | Gap Type | Severity | Priority |
|-----|-------|----------|----------|----------|
| ADR-001 | [Title] | Missing alternatives | HIGH | 1 |
| ADR-002 | [Title] | Incomplete consequences | MEDIUM | 2 |

### Cross-ADR Issues

| Issue | ADRs Affected | Description |
|-------|---------------|-------------|
| [Conflict] | ADR-001, ADR-003 | [Description of conflict] |
```

#### Gap Prioritization

- **CRITICAL**: Constitution violations, missing decision statement
- **HIGH**: No alternatives documented, missing consequences
- **MEDIUM**: Incomplete risks, unclear context
- **LOW**: Minor phrasing improvements, optional details

### Phase 4: Interactive Refinement

**Objective**: Fill gaps through targeted questions

#### Question Format

For each gap requiring clarification:

```markdown
## Clarification [N]: [ADR-XXX] - [Gap Type]

**Current State**: 
[Quote current ADR content]

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

**ADR**: ADR-XXX - [Title]
**Constitution Principle**: §[Section] - [Principle Name]
**Issue**: This ADR documents a decision already mandated by constitution

**Options**:
| Option | Action | Result |
|--------|--------|--------|
| A | Remove ADR | Decision covered by constitution only |
| B | Convert to Reference | Keep ADR as "See Constitution §X" |
| C | Add Context | Keep ADR with "Aligns with Constitution §X" |
| D | Extend | Keep ADR as "Extends Constitution §X" |

Reply with your choice (A/B/C/D).
```

**For Violations (Option A PRIMARY - Amend Constitution)**:

```markdown
## Clarification [N]: Constitution Violation Detected ⭐

**ADR**: ADR-XXX - [Title]
**Decision**: [What the ADR decides]
**Constitution Principle**: §[Section] - [Principle]
**Conflict**: [How they conflict]

**The constitution should evolve with the project's needs.**

**⭐ RECOMMENDED: A. Amend Constitution**
Update constitution §[Section] to accommodate this decision. This establishes a new principle for future decisions.

**Alternative Options**:
B. Override in ADR - Document justification for deviation
C. Revise ADR - Change decision to comply with constitution
D. Remove ADR - Delete and follow existing constitution

**Consider Amendment If**:
- [ ] This decision will be used again in the future
- [ ] Team's approach has evolved since constitution was written
- [ ] Existing principle is too restrictive for current needs

**Amendment Text**: [If choosing A, provide the specific constitutional amendment]

Reply with: "A [amendment text]" or "B/C/D [reasoning]"
```

#### Clarification Rules

- Present **one clarification at a time**
- **Prioritize by severity** - address CRITICAL/HIGH gaps first
- **For constitution violations, Option A (Amend) is PRIMARY**
- **Limit to 5 clarifications** per session (increased to 10 if architecture present)
- Allow user to **skip** non-critical clarifications
- **Summarize changes** after each answer
- User can say "done" to end clarification early

### Phase 5: ADR Updates

**Objective**: Write refined ADRs back to file

1. **Apply Clarifications**:
   - Update ADR sections with new content
   - Preserve structure and formatting
   - Update "Last Updated" timestamps

2. **Resolve Conflicts**:
   - If cross-ADR conflicts were found, propose resolution
   - Document decision to favor one ADR over another
   - Add cross-references between related ADRs

3. **Update Index**:
   - Refresh ADR index table if titles changed
   - Update status if applicable

4. **Write File**:
   - Atomic write to `{REPO_ROOT}/.specify/drafts/adr.md`
   - Preserve any ADRs that weren't modified

### Phase 5.5: ADR Approval ⭐

**Objective**: Get user confirmation to approve ADRs before architecture generation

This step is **critical** because `implement` only processes ADRs with "Accepted" status. ADRs with "Discovered" or "Proposed" status will be skipped.

#### Approval Request

```markdown
## ADR Approval ⭐

**Total ADRs**: [N]
**Status Distribution**:
- Accepted: [N]
- Proposed: [N]
- Discovered: [N]

**⚠️ Important**: Only "Accepted" ADRs will be processed by `/architect.implement`

### Options

| Option | Action |
|--------|--------|
| A | Accept All - Change Proposed/Discovered → Accepted |
| B | Review Specific - Select individual ADRs to accept |
| C | Defer - Keep current status, decide later |

**Note**: You can also run `/architect.clarify` again later to approve additional ADRs.

Reply with A, B, or C (or "done" to skip).
```

#### Bulk Approval (Option A)

If user chooses Option A:

```markdown
## Confirm Bulk Approval

Change [N] ADRs from Proposed/Discovered → Accepted?

| ADR | Current Status | New Status |
|-----|----------------|-------------|
| ADR-001 | Proposed | Accepted |
| ADR-002 | Discovered | Accepted |

Reply with "yes" to confirm or "no" to cancel.
```

#### Selective Approval (Option B)

If user chooses Option B, present ADRs one-by-one:

```markdown
## ADR Approval: ADR-XXX

**Title**: [Title]
**Current Status**: [Proposed/Discovered]
**Context**: [Brief summary]

**Options**:
| Option | Action |
|--------|--------|
| A | Accept - Change to "Accepted" |
| B | Keep - Keep current status |
| C | Skip - Move to next ADR |

Reply with A, B, or C for ADR-XXX.
```

#### Post-Approval

After approval (or if user chooses C to defer):

```markdown
## ADRs Approved

**Status Changes Applied**:
- ADR-001: Proposed → Accepted
- ADR-002: Discovered → Accepted
- ADR-007: Kept as Proposed

**Ready for Implementation**:
- Accepted ADRs: [N]
- Pending Approval: [N]

Run `/architect.implement` to generate AD.md from accepted ADRs.
```

## Key Rules

### Non-Destructive Refinement

- **Never delete** existing ADRs without explicit user approval
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
- ADRs cannot override MUST principles without explicit justification
- Suggest constitution updates if conflict is systemic

### Quality Over Quantity

- Focus on **material gaps** that affect implementation
- Skip **cosmetic improvements** unless user requests
- **Defer minor issues** if major gaps remain

## Completion Report

After clarification ends (all gaps addressed or user signals "done"):

```markdown
## ADR Clarification Complete

**Changes Made**:
- ADR-001: Updated consequences section
- ADR-002: Added Common Alternatives (neutral trade-offs)
- ADR-003: Resolved conflict with ADR-001
- Constitution: Amended §DataStorage to allow NoSQL for document flexibility

**Risks & Gaps Status**:
- Critical gaps identified: [N] → [N resolved]
- High priority gaps: [N] → [N resolved]
- Cross-view inconsistencies: [N] → [N resolved]
- Integration with AD sections: [N updates]

**Remaining Gaps** (deferred):
- 3.6.2: Minor operational documentation (LOW)

**Cross-ADR Consistency**: ✅ Verified

**Constitution Alignment**:
- Duplicates resolved: [N]
- Violations addressed: [N]
- Constitution amended: [N] (if applicable)
- References added: [N]

**Recommended Next Steps**:
1. Review updated ADRs in `{REPO_ROOT}/.specify/drafts/adr.md`
2. Run `/architect.implement` to generate AD.md
3. Or run `/spec.specify` to start feature development
```

## Workflow Guidance & Transitions

### After `/architect.clarify`

**⚠️ Required**: You MUST run `/architect.clarify` before `/architect.implement` to approve ADRs.

**Status Workflow**:

- init → "Discovered" (brownfield)
- specify → "Proposed" (greenfield)
- **clarify → ask to approve → "Accepted"** ⭐
- implement → only reads "Accepted", skips Discovered/Proposed

Recommended next steps:

1. **Review Changes**: Verify ADR updates are accurate
2. **Approve ADRs**: Use Phase 5.5 to change status to "Accepted"
3. **Run `/architect.implement`**: Generate full AD.md from Accepted ADRs ⭐
4. **Start Features**: Use `/spec.specify` to create feature specs

### When to Use This Command

- **After `/architect.specify`**: Refine initial ADRs before architecture generation
- **ADR Review**: Validate ADRs before major milestones
- **New Team Member**: Ensure ADRs make sense to fresh eyes
- **Conflict Resolution**: Resolve identified inconsistencies

### When NOT to Use This Command

- **No ADRs exist**: Use `/architect.specify` first to create ADRs
- **Brownfield projects**: Use `/architect.init` to reverse-engineer ADRs from code

## Context

$ARGUMENTS