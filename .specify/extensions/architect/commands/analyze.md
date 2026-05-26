---
description: Analyze architecture for consistency between ADRs and AD, completeness, and quality issues
scripts:
  sh: .specify/extensions/architect/scripts/bash/setup-architect.sh "analyze {ARGS}"
  ps: .specify/extensions/architect/scripts/powershell/setup-architect.ps1 "analyze {ARGS}"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"system"` - Focus on root-level AD.md and adr.md only
- `"feature auth"` - Focus on specific feature architecture
- `"adrs"` - Focus on ADR quality and inter-ADR consistency
- `"views"` - Focus on AD.md view completeness and internal consistency
- Empty input: Full analysis of all architecture artifacts

## Goal

Perform **read-only** architecture consistency analysis between ADRs (Architecture Decision Records) and AD (Architecture Description). Identify discrepancies, quality issues, and gaps without modifying any files.

**Key Analysis Dimensions**:

1. **ADR Quality** - Completeness, clarity, and standards compliance
2. **ADR to AD Consistency** - Bidirectional drift detection
3. **Internal Consistency** - Cross-artifact coherence
4. **Staleness Detection** - Outdated references and placeholders

This command is the architectural equivalent of `/spec.analyze` - it validates architecture artifacts the same way `/spec.analyze` validates specification artifacts.

## Operating Constraints

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured analysis report. Offer remediation suggestions (user must explicitly approve before any follow-up editing commands would be invoked manually).

**Constitution Authority**: The project constitution (`memory/constitution.md`) is **non-negotiable** within this analysis scope. Constitution conflicts are automatically CRITICAL.

## Role & Context

You are acting as an **Architecture Analyst** validating architecture documentation quality. Your role involves:

- **Validating** ADR completeness against MADR standards
- **Detecting** drift between ADRs and AD.md
- **Identifying** internal inconsistencies across artifacts
- **Flagging** staleness and quality issues

### Architecture Document Hierarchy

| Document | Location | Purpose |
|----------|----------|---------|
| `AD.md` | Project root | Full Architecture Description (Rozanski & Woods) |
| `adr.md` | `{REPO_ROOT}/.specify/memory/` | System-level Architecture Decision Records |
| `constitution.md` | `{REPO_ROOT}/.specify/memory/` | Governance principles and constraints |

## Outline

1. **Initialize Analysis Context** - Load architecture artifacts
2. **Determine Analysis Scope** - System, feature, or full
3. **Execute Detection Passes** - A through G
4. **Assign Severities** - CRITICAL/HIGH/MEDIUM/LOW
5. **Generate Report** - Structured markdown analysis
6. **Provide Next Actions** - Remediation suggestions

## Execution Steps

### Phase 1: Initialize Analysis Context

**Objective**: Load all architecture artifacts for analysis

1. **Run Setup Script**:
   - Execute `{SCRIPT}` from repo root
   - Parse JSON for file paths and existence status

2. **Load System-Level Artifacts**:
   - Read `AD.md` (project root) if exists
   - Read ADRs from all locations (priority order):
     1. `{REPO_ROOT}/.specify/memory/adr.md` (canonical - Accepted ADRs)
     2. `{REPO_ROOT}/.specify/drafts/adr.md` (working copy - Proposed/Discovered)
   - Read `{REPO_ROOT}/.specify/memory/constitution.md` if exists

3. **Load Feature-Level Artifacts** (if analyzing features):
   - Scan `specs/*/AD.md` for feature architectures
   - Scan `specs/*/adr.md` for feature ADRs

4. **Build Artifact Inventory**:

   | Artifact | Path | Status |
   |----------|------|--------|
   | System AD | `AD.md` | Found/Missing |
   | System ADRs (canonical) | `{REPO_ROOT}/.specify/memory/adr.md` | Found/Missing |
   | System ADRs (drafts) | `{REPO_ROOT}/.specify/drafts/adr.md` | Found/Missing |
   | Constitution | `{REPO_ROOT}/.specify/memory/constitution.md` | Found/Missing |
   | Feature ADs | `specs/*/AD.md` | Count: N |
   | Feature ADRs | `specs/*/adr.md` | Count: N |

### Phase 2: Determine Analysis Scope

**Objective**: Focus analysis based on user input

**Scope Selection**:

| User Input | Scope | Artifacts Analyzed |
|------------|-------|-------------------|
| (empty) | Full | All system artifacts |
| `"system"` | System only | AD.md, system ADR locations |
| `"adrs"` | ADR quality | All adr.md files |
| `"views"` | AD completeness | AD.md |

### Phase 3: Execute Detection Passes

Focus on high-signal findings. Limit to **50 findings total**; aggregate remainder in overflow summary.

#### Pass A: ADR Quality Analysis

**Objective**: Validate each ADR against MADR standards

**Quality Dimensions**:

| Dimension | Check | Severity if Missing |
|-----------|-------|---------------------|
| Context | Problem clearly stated, forces documented | MEDIUM |
| Decision | Actionable, testable decision statement | HIGH |
| Positive Consequences | Benefits documented | MEDIUM |
| Negative Consequences | Trade-offs acknowledged | HIGH |
| Risks | Identified with mitigations | MEDIUM |
| Alternatives | At least 2 options with neutral trade-offs | HIGH |
| Status | Valid status (Proposed/Accepted/Deprecated/Superseded/Discovered) | LOW |
| Constitution Alignment | MUST principles complied with | CRITICAL |

**ADR Quality Checklist**:

For each ADR, verify:

- [ ] Clear context explaining the problem/opportunity
- [ ] Explicit, actionable decision statement
- [ ] Positive AND negative consequences documented
- [ ] **Common Alternatives** with neutral trade-offs (not "Rejected because")
- [ ] Risks identified with mitigation strategies
- [ ] Valid status value
- [ ] No conflicts with constitution MUST principles

#### Pass B: Inter-ADR Consistency

**Objective**: Detect conflicts and inconsistencies between ADRs

**Checks**:

1. **Conflicting Decisions**:
   - ADRs that contradict each other (e.g., one chooses PostgreSQL, another assumes MongoDB)
   - Technology stack incoherence

2. **Missing Dependencies**:
   - ADRs that should reference each other but don't
   - Implicit assumptions about other decisions

3. **Terminology Drift**:
   - Same concept named differently across ADRs
   - Inconsistent component naming

4. **Technology Stack Coherence**:
   - Frontend/backend/infrastructure choices align
   - No conflicting framework decisions

#### Pass C: ADR to AD Drift (Forward Sync)

**Objective**: Detect ADR decisions not reflected in AD.md

**Checks**:

| ADR Element | Expected in AD.md | View/Section |
|-------------|-------------------|--------------|
| System architecture style | Context View | 3.1 |
| Database choice | Information View | 3.3 |
| API style | Functional View | 3.2 |
| Authentication approach | Security Perspective | 4.1 |
| Deployment platform | Deployment View | 3.6 |
| CI/CD approach | Development View | 3.5 |
| Scaling strategy | Performance Perspective | 4.2 |
| Caching strategy | Information View | 3.3 |

**Detection Logic**:

For each ADR:

1. Identify the ADR's primary view impact (use mapping table above)
2. Search AD.md for reflection of that decision
3. Flag if decision is absent or contradicted

#### Pass D: AD to ADR Drift (Backward Sync)

**Objective**: Detect AD.md elements without supporting ADRs

**Checks**:

1. **Components Without ADRs**:
   - Major components shown in Functional View without decision rationale
   - External dependencies in Context View without ADR justification

2. **Patterns Without Rationale**:
   - Architectural patterns described but not explained via ADR
   - Technology choices embedded in views without supporting decision

3. **Infrastructure Decisions**:
   - Deployment topology without infrastructure ADR
   - Scaling approach without performance ADR

#### Pass E: AD Internal Consistency

**Objective**: Validate AD.md coherence across views

**Checks**:

1. **Cross-View Consistency**:
   - Same components named identically across all views
   - Data entities in Information View match Functional View references
   - Deployment nodes consistent with Functional components

2. **Diagram-Text Alignment**:
   - Mermaid diagrams match prose descriptions
   - No components in diagrams missing from text
   - No components in text missing from diagrams

3. **View Completeness**:
   - Required sections present (Introduction, Stakeholders, Views, Perspectives)
   - Core views included (Context, Functional, Information, Development, Deployment)
   - Perspectives addressed (Security, Performance)

4. **Diagram Syntax Validation**:
   - Mermaid syntax valid (no broken diagrams)
   - Consistent styling across diagrams

5. **View File Consistency** (DAG State Validation):
    - Check if `.specify/architect/state.json` exists and reports views as "completed"
    - Check if `.specify/architect/views/` directory exists
    - Verify that for each "completed" view in state.json, a corresponding file exists on disk
    - **Flag as HIGH severity if**:
      - state.json reports views "completed" but views/ directory is empty
      - View files exist but are under 20 lines (placeholder/skeleton content)
      - View files cannot be read (corrupted/missing permissions)
    - **Report format**:
      ```
      DAG State Inconsistency Detected:
      - State reports: [N] views completed
      - Files on disk: [M] view files found
      - Missing files: [list of missing views]
      - Recommendation: Regenerate views or reset state.json
      ```

6. **Technology Neutrality** (Functional View):
    - Scan Functional View (§3.2) for product/vendor names in element descriptions and Mermaid diagrams
    - **Architectural roles** (acceptable): Database, Object Storage, Cache, Message Queue, AI Gateway, Workflow Runtime, App Shell, API Gateway, Authentication Service, etc.
    - **Product names** (flag as MEDIUM): PostgreSQL, Neon, Vercel, Next.js, Redis, MongoDB, AWS, Azure, S3, etc.
    - **Severity**: MEDIUM - Not blocking but indicates abstraction violation
    - **Note**: ADR Traceability sections may reference products (that's acceptable); only flag element descriptions and diagram labels

7. **Functional-Development Mapping**:
    - Verify Development View (§3.5) contains a Technology Stack Mapping table (§3.5.2)
    - Check that every element in Functional View's element table (§3.2.1) has at least one corresponding entry in the mapping table
    - N:1 mappings (multiple functional elements → one technology) are acceptable
    - **Severity**: MEDIUM if elements are missing; LOW if mapping table is absent
    - **Cross-check**: Technology Architecture diagram (§3.5.3) should mirror Functional View diagram (§3.2.2) structure

#### Pass F: Staleness Detection

**Objective**: Identify outdated references and placeholders

**Checks**:

1. **Deprecated ADRs Still Referenced**:
   - AD.md references ADRs with status "Deprecated"
   - Superseded decisions still implemented

2. **Placeholder Detection**:
   - `[TODO]`, `[TBD]`, `[PLACEHOLDER]` markers
   - `[SYSTEM_NAME]`, `[STAKEHOLDER_*]` unfilled
   - `???`, `...`, `<placeholder>` patterns

3. **Date Inconsistencies**:
   - ADR dates significantly older than AD last-updated
   - Feature architecture out of sync with system architecture

4. **Orphaned References**:
   - ADR IDs mentioned but ADR doesn't exist
   - Component names referenced but not defined

#### Pass G: Feature-System Alignment (if feature architecture exists)

**Objective**: Validate feature architecture fits within system boundaries

**Checks**:

1. **Feature ADR Alignment**:
   - Feature ADRs marked "Aligns with ADR-XXX" reference valid system ADRs
   - No VIOLATION flags without documented justification
   - Feature decisions consistent with system constraints

2. **Boundary Compliance**:
   - Feature components fit within system Functional View structure
   - Feature data entities align with system Information View
   - Feature doesn't exceed system scope (Context View)

3. **Integration Points**:
   - Feature-to-system interfaces documented
   - Data flow across feature boundary consistent

### Phase 4: Severity Assignment

**Severity Criteria**:

| Severity | Criteria | Examples |
|----------|----------|----------|
| **CRITICAL** | Constitution violation, security/data integrity gap, missing core ADR | ADR violates MUST principle, major component undocumented |
| **HIGH** | ADR to AD drift affecting implementation, conflicting ADRs, missing alternatives | Database choice in ADR but wrong DB in AD, two ADRs conflict |
| **MEDIUM** | Incomplete consequences, staleness, terminology drift, missing optional views | ADR lacks negative consequences, TODO placeholders |
| **LOW** | Style improvements, minor documentation gaps, optional details | Inconsistent formatting, minor wording issues |

### Phase 5: Generate Analysis Report

**Output Format**:

```markdown
## Architecture Analysis Report

### Analysis Summary

| Attribute | Value |
|-----------|-------|
| **Mode** | [Full/System/Feature/ADRs/Views] |
| **Scope** | [Description of what was analyzed] |
| **Files Analyzed** | [List of files] |
| **Analysis Date** | [Current date] |

### Findings

| ID | Pass | Severity | Location | Summary | Recommendation |
|----|------|----------|----------|---------|----------------|
| A1 | ADR Quality | MEDIUM | ADR-003 | Missing negative consequences | Add trade-offs section |
| B1 | Inter-ADR | HIGH | ADR-002, ADR-005 | Conflicting database choices | Resolve PostgreSQL vs MongoDB conflict |
| C1 | ADR->AD Drift | HIGH | ADR-005 | Caching decision not in Information View | Update AD.md 3.3 |
| D1 | AD->ADR Drift | HIGH | AD.md:3.2 | Redis component has no ADR | Create ADR for cache choice |
| E1 | AD Consistency | MEDIUM | AD.md:3.2/3.6 | Component naming mismatch | Standardize "AuthService" naming |
| F1 | Staleness | LOW | AD.md:3.1 | [SYSTEM_NAME] placeholder | Fill in system name |
| G1 | Feature Align | HIGH | specs/auth/adr.md | VIOLATION flag unresolved | Document override justification |

### Coverage Metrics

| Metric | System | Feature: auth | Feature: payments |
|--------|--------|---------------|-------------------|
| ADR Count | 13 | 3 | 2 |
| AD Views Complete | 5/7 | 3/5 | 3/5 |
| ADR->AD Coverage | 85% | 100% | 67% |
| AD->ADR Coverage | 92% | 100% | 100% |
| Quality Score | 78% | 85% | 72% |

### Constitution Alignment

| Status | Count | Details |
|--------|-------|---------|
| Compliant | [N] | ADRs following MUST principles |
| Violations | [N] | ADRs violating MUST principles (CRITICAL) |
| Deviations | [N] | Justified SHOULD principle deviations |

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
- Command: `/architect.clarify` to address ADR compliance

**If HIGH ADR quality issues:**
- **Refine**: Address missing alternatives and consequences
- Command: `/architect.clarify` to improve ADR quality

**If ADR->AD drift detected:**
- **Sync AD**: Update AD.md to reflect ADR decisions
- Command: `/architect.implement --update` to regenerate views

**If AD->ADR drift detected:**
- **Document**: Create missing ADRs for undocumented decisions
- Command: `/architect.specify` or `/architect.init` to add ADRs

**If feature alignment issues:**
- **Align**: Resolve feature-system boundary violations
- Command: Run `/spec.plan` (architect extension `before_plan` hook will update feature architecture if enabled)
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

- **Cross-reference everything** - validate bidirectionally (ADR to AD)
- **Check all levels** - system and feature architecture must align
- **Validate terminology** - same concepts must use same names
- **Verify diagrams** - Mermaid syntax must be valid

### Reporting Standards

- **Limit to 50 findings** - aggregate overflow in summary
- **Include location** - always cite file:line or section
- **Provide actionable recommendations** - each finding gets a fix suggestion
- **Calculate coverage metrics** - quantify completeness

## Workflow Guidance & Transitions

### After `/architect.analyze`

Based on findings, recommended next steps:

| Finding Type | Recommended Command |
|--------------|---------------------|
| ADR quality issues | `/architect.clarify` |
| ADR->AD drift | `/architect.implement --update` |
| AD->ADR drift (missing ADRs) | `/architect.specify` or `/architect.init` |
| Feature alignment issues | `/spec.plan` (triggers `before_plan` hook) |
| Spec alignment issues | `/spec.analyze` |

### When to Use This Command

- **After `/architect.implement`** - Validate generated AD.md
- **After `/architect.clarify`** - Verify ADR refinements
- **Before feature development** - Ensure architecture is solid
- **During architecture review** - Quality gate for architecture docs
- **Periodically** - Detect drift as codebase evolves

### When NOT to Use This Command

- **No architecture artifacts exist** - Use `/architect.init` or `/architect.specify` first
- **Want to create architecture** - This is analysis-only, not generation
- **Need spec validation** - Use `/spec.analyze` for specification artifacts

## Context

{ARGS}
