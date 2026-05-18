---
description: Analyze product for consistency between PDRs and PRD, completeness, and
  quality issues
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "analyze {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "analyze {ARGS}"
---


<!-- Extension: product -->
<!-- Config: .specify/extensions/product/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"product"` - Focus on root-level PRD.md and pdr.md only
- `"feature auth"` - Focus on specific feature product
- `"pdrs"` - Focus on PDR quality and inter-PDR consistency
- `"sections"` - Focus on PRD section completeness and internal consistency
- Empty input: Full analysis of all product artifacts

## Goal

Perform **read-only** product consistency analysis between PDRs (Product Decision Records) and PRD (Product Requirements Document). Identify discrepancies, quality issues, and gaps without modifying any files.

**Key Analysis Dimensions**:

1. **PDR Quality** - Completeness, clarity, and standards compliance
2. **PRD to PDR Consistency** - Bidirectional drift detection
3. **Internal Consistency** - Cross-artifact coherence
4. **Staleness Detection** - Outdated references and placeholders

This command is the product equivalent of `/spec.analyze` - it validates product artifacts the same way `/spec.analyze` validates specification artifacts.

## Operating Constraints

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured analysis report. Offer remediation suggestions (user must explicitly approve before any follow-up editing commands would be invoked manually).

**Constitution Authority**: The project constitution (`.specify/memory/constitution.md`) is **non-negotiable** within this analysis scope. Constitution conflicts are automatically CRITICAL.

## Role & Context

You are acting as a **Product Analyst** validating product documentation quality. Your role involves:

- **Validating** PDR completeness against standards
- **Detecting** drift between PDRs and PRD.md
- **Identifying** internal inconsistencies across artifacts
- **Flagging** staleness and quality issues

### Product Document Hierarchy

| Document | Location | Purpose |
|----------|----------|---------|
| `PRD.md` | Project root | Full Product Requirements Document |
| `pdr.md` | `{REPO_ROOT}/.specify/memory/` | Product Decision Records |
| `constitution.md` | `{REPO_ROOT}/.specify/memory/` | Product vision/strategy |
| Feature `PRD.md` | `specs/{feature}/` | Feature-level product (if exists) |
| Feature `pdr.md` | `specs/{feature}/` | Feature-level PDRs (if exists) |

## Outline

1. **Initialize Analysis Context** - Load product artifacts
2. **Determine Analysis Scope** - Product, feature, or full
3. **Execute Detection Passes** - A through G
4. **Assign Severities** - CRITICAL/HIGH/MEDIUM/LOW
5. **Generate Report** - Structured markdown analysis
6. **Provide Next Actions** - Remediation suggestions

## Execution Steps

### Phase 1: Initialize Analysis Context

**Objective**: Load all product artifacts for analysis

1. **Run Setup Script**:
   - Execute `.specify/extensions/product/scripts/bash/setup-product.sh "analyze $ARGUMENTS"` from repo root
   - Parse JSON for file paths and existence status

2. **Load System-Level Artifacts**:
   - Read `PRD.md` (project root) if exists
   - Read `{REPO_ROOT}/.specify/drafts/pdr.md` if exists
   - Read `{REPO_ROOT}/.specify/memory/constitution.md` if exists

3. **Load Feature-Level Artifacts** (if analyzing features):

4. **Build Artifact Inventory**:

   | Artifact | Path | Status |
   |----------|------|--------|
   | Product PRD | `PRD.md` | Found/Missing |
   | Product PDRs | `{REPO_ROOT}/.specify/drafts/pdr.md` | Found/Missing |
   | Constitution | `{REPO_ROOT}/.specify/memory/constitution.md` | Found/Missing |
   | Feature PRDs | `specs/*/PRD.md` | Count: N |
   | Feature PDRs | `specs/*/pdr.md` | Count: N |

### Phase 2: Determine Analysis Scope

**Objective**: Focus analysis based on user input

**Scope Selection**:

| User Input | Scope | Artifacts Analyzed |
|------------|-------|-------------------|
| (empty) | Full | All system + all feature artifacts |
| `"product"` | Product only | PRD.md, {REPO_ROOT}/.specify/drafts/pdr.md |
| `"feature {name}"` | Single feature | specs/{name}/PRD.md, specs/{name}/pdr.md |
| `"pdrs"` | PDR quality | All pdr.md files (system + feature) |
| `"sections"` | PRD completeness | All PRD.md files (system + feature) |

### Phase 3: Execute Detection Passes

Focus on high-signal findings. Limit to **50 findings total**; aggregate remainder in overflow summary.

#### Pass A: PDR Quality Analysis

**Objective**: Validate each PDR against standards

**Quality Dimensions**:

| Dimension | Check | Severity if Missing |
|-----------|-------|---------------------|
| Context | Problem clearly stated, forces documented | MEDIUM |
| Decision | Actionable, testable decision statement | HIGH |
| Positive Consequences | Benefits documented | MEDIUM |
| Negative Consequences | Trade-offs acknowledged | HIGH |
| Success Metrics | Metrics defined with targets | HIGH |
| Risks | Identified with mitigations | MEDIUM |
| Alternatives | At least 2 options with neutral trade-offs | HIGH |
| Status | Valid status (Proposed/Accepted/Deprecated/Superseded/Discovered) | LOW |
| Constitution Alignment | Vision principles complied with | CRITICAL |

**PDR Quality Checklist**:

For each PDR, verify:

- [ ] Clear context explaining the problem/opportunity
- [ ] Explicit, actionable decision statement
- [ ] Positive AND negative consequences documented
- [ ] **Alternatives Considered** with neutral trade-offs (not "Rejected because")
- [ ] Success metrics defined
- [ ] Risks identified with mitigation strategies
- [ ] Valid status value
- [ ] No conflicts with constitution vision principles

#### Pass B: Inter-PDR Consistency

**Objective**: Detect conflicts and inconsistencies between PDRs

**Checks**:

1. **Conflicting Decisions**:
   - PDRs that contradict each other (e.g., one chooses B2B, another assumes B2C)
   - Target market incoherence
   - Pricing model conflicts

2. **Missing Dependencies**:
   - PDRs that should reference each other but don't
   - Implicit assumptions about other decisions

3. **Terminology Drift**:
   - Same concept named differently across PDRs
   - Inconsistent metric definitions

4. **Product Strategy Coherence**:
   - Problem statement alignment
   - Target persona alignment
   - Success metric alignment

#### Pass C: PDR to PRD Drift (Forward Sync)

**Objective**: Detect PDR decisions not reflected in PRD.md

**Checks**:

| PDR Element | Expected in PRD | Section |
|-------------|-----------------|---------|
| Problem decision | Problem statement | 2 |
| Persona decision | Personas section | 5 |
| Scope decision | Functional Requirements / Out of Scope | 6 / 8 |
| Metric decision | Success Metrics | 4 |
| Business Model | Overview | 1 |
| NFR decision | Non-Functional Requirements | 7 |

**Detection Logic**:

For each PDR:

1. Identify the PDR's primary section impact (use mapping table above)
2. Search PRD for reflection of that decision
3. Flag if decision is absent or contradicted

#### Pass D: PRD to PDR Drift (Backward Sync)

**Objective**: Detect PRD.md elements without supporting PDRs

**Checks**:

1. **Requirements Without PDRs**:
   - User stories without scope PDR justification
   - Features without feature PDRs
   - NFRs without NFR PDRs

2. **Personas Without PDRs**:
   - Personas defined but no persona PDR exists

3. **Metrics Without PDRs**:
   - Success metrics defined but no metric PDR exists

4. **Risks Without PDRs**:
   - Risks documented but no consequence section in relevant PDR

#### Pass E: PRD Internal Consistency

**Objective**: Validate PRD.md coherence across sections

**Checks**:

1. **Cross-Section Consistency**:
   - Problem statement aligns with Goals
   - Personas align with Scope
   - Metrics align with Requirements

2. **Traceability**:
   - All sections have PDR references
   - No orphaned requirements

3. **Section Completeness**:
   - All required sections present (9 sections)
   - Each section has substantial content
   - All required elements in each section

4. **Template Compliance**:
   - Section structure matches template
   - Required tables present

#### Pass F: Staleness Detection

**Objective**: Identify outdated references and placeholders

**Checks**:

1. **Deprecated PDRs Still Referenced**:
   - PRD references PDRs with status "Deprecated"
   - Superseded decisions still in PRD

2. **Placeholder Detection**:
   - `[TODO]`, `[TBD]`, `[PLACEHOLDER]` markers
   - `[PRODUCT_NAME]`, `[TARGET_USER]` unfilled
   - `???`, `...`, `<placeholder>` patterns

3. **Date Inconsistencies**:
   - PDR dates significantly older than PRD last-updated
   - Feature product out of sync with product PRD

4. **Orphaned References**:
   - PDR IDs mentioned but PDR doesn't exist
   - Section references broken

#### Pass G: Feature-Product Alignment (if feature product exists)

**Objective**: Validate feature product fits within product boundaries

**Checks**:

1. **Feature PDR Alignment**:
   - Feature PDRs marked "Aligns with PDR-XXX" reference valid product PDRs
   - No VIOLATION flags without documented justification
   - Feature decisions consistent with product constraints

2. **Boundary Compliance**:
   - Feature scope fits within product Functional Requirements
   - Feature personas align with product Personas
   - Feature doesn't exceed product scope

3. **Traceability**:
   - Feature requirements traced to product requirements
   - Dependencies documented

### Phase 4: Severity Assignment

**Severity Criteria**:

| Severity | Criteria | Examples |
|----------|----------|----------|
| **CRITICAL** | Constitution violation, market positioning gap, missing core PDR | PDR violates vision principle, major requirement undocumented |
| **HIGH** | PDR to PRD drift affecting requirements, conflicting PDRs, missing alternatives | Target market in PDR but wrong segment in PRD, two PDRs conflict |
| **MEDIUM** | Incomplete consequences, staleness, terminology drift, missing optional sections | PDR lacks negative consequences, TODO placeholders |
| **LOW** | Style improvements, minor documentation gaps, optional details | Inconsistent formatting, minor wording issues |

### Phase 5: Generate Analysis Report

**Output Format**:

```markdown
## Product Analysis Report

### Analysis Summary

| Attribute | Value |
|-----------|-------|
| **Mode** | [Full/Product/Feature/PDRs/Sections] |
| **Scope** | [Description of what was analyzed] |
| **Files Analyzed** | [List of files] |
| **Analysis Date** | [Current date] |

### Findings

| ID | Pass | Severity | Location | Summary | Recommendation |
|----|------|----------|----------|---------|----------------|
| A1 | PDR Quality | MEDIUM | PDR-003 | Missing success metrics | Add metrics section |
| B1 | Inter-PDR | HIGH | PDR-002, PDR-005 | Conflicting target markets | Resolve B2B vs B2C conflict |
| C1 | PDR->PRD Drift | HIGH | PRD:5 | Persona not in PRD | Update PRD section 5 |
| D1 | PRD->PDR Drift | HIGH | PRD:6 | Feature has no PDR | Create PDR for feature |
| E1 | PRD Consistency | MEDIUM | PRD:2/4 | Problem/metrics mismatch | Align statements |
| F1 | Staleness | LOW | PRD:1 | [PRODUCT_NAME] placeholder | Fill in product name |
| G1 | Feature Align | HIGH | specs/auth/pdr.md | VIOLATION flag unresolved | Document override justification |

### Coverage Metrics

| Metric | Product | Feature: auth | Feature: payments |
|--------|---------|---------------|-------------------|
| PDR Count | 13 | 3 | 2 |
| PRD Sections Complete | 9/9 | 5/5 | 5/5 |
| PDR->PRD Coverage | 85% | 100% | 67% |
| PRD->PDR Coverage | 92% | 100% | 100% |
| Quality Score | 78% | 85% | 72% |

### Constitution Alignment

| Status | Count | Details |
|--------|-------|---------|
| Compliant | [N] | PDRs following vision principles |
| Violations | [N] | PDRs violating vision MUST principles (CRITICAL) |
| Deviations | [N] | Justified strategy principle deviations |

### Issue Distribution

| Severity | Count |
|----------|-------|
| CRITICAL | [N] |
| HIGH | [N] |
| MEDIUM | [N] |
| LOW | [N] |

### Next Actions

Based on findings, recommended actions:

**If CRITICAL issues exist:**
- **Immediate**: Resolve constitution violations before proceeding
- Command: `/product.clarify` to address PDR compliance

**If HIGH PDR quality issues:**
- **Refine**: Address missing alternatives and consequences
- Command: `/product.clarify` to improve PDR quality

**If PDR->PRD drift detected:**
- **Sync PRD**: Update PRD to reflect PDR decisions
- Command: `/product.implement --update` to regenerate sections

**If PRD->PDR drift detected:**
- **Document**: Create missing PDRs for undocumented decisions
- Command: `/product.specify` or `/product.init` to add PDRs

**If feature alignment issues:**
- **Align**: Resolve feature-product boundary violations
- Command: `/spec.plan --product` to update feature product
```

### Phase 6: Offer Remediation

After presenting the report, ask:

> "Would you like me to suggest specific remediation steps for the top [N] issues? I can provide detailed guidance for each finding, though I will not make any changes automatically."

## Key Rules

### Analysis Integrity

- **NEVER modify files** - this is read-only analysis
- **NEVER hallucinate missing content** - report absences accurately
- **Prioritize constitution violations** - these are always CRITICAL
- **Use evidence-based findings** - cite specific locations and content

### Consistency Standards

- **Cross-reference everything** - validate bidirectionally (PDR to PRD)
- **Check all levels** - system and feature product must align
- **Validate terminology** - same concepts must use same names
- **Verify section structure** - all required elements present

### Reporting Standards

- **Limit to 50 findings** - aggregate overflow in summary
- **Include location** - always cite file:line or section
- **Provide actionable recommendations** - each finding gets a fix suggestion
- **Calculate coverage metrics** - quantify completeness

## Workflow Guidance & Transitions

### After `/product.analyze`

Based on findings, recommended next steps:

| Finding Type | Recommended Command |
|--------------|---------------------|
| PDR quality issues | `/product.clarify` |
| PDR->PRD drift | `/product.implement --update` |
| PRD->PDR drift (missing PDRs) | `/product.specify` or `/product.init` |
| Feature alignment issues | `/spec.plan --product` |
| Spec alignment issues | `/spec.analyze` |

### When to Use This Command

- **After `/product.implement`**: Validate generated PRD
- **After `/product.clarify`**: Verify PDR refinements
- **Before feature development**: Ensure product is solid
- **During product review**: Quality gate for product docs
- **Periodically**: Detect drift as product evolves

### When NOT to Use This Command

- **No product artifacts exist**: Use `/product.init` or `/product.specify` first
- **Want to create product**: This is analysis-only, not generation
- **Need spec validation**: Use `/spec.analyze` for specification artifacts

## Context

$ARGUMENTS