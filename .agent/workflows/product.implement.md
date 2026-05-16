---
description: Generate full Product Requirements Document (PRD) from PDRs
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "implement {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "implement
    {ARGS}"
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

- `"Focus on problem and scope sections - we need clear boundaries"`
- `"Generate full PRD with all sections"`
- `"Update existing PRD.md with new PDRs from recent decisions"`
- Empty input: Generate complete PRD from all PDRs

### Flags

- `--sections SECTIONS`: PRD sections to generate
  - `): All 9 sections
  -all` (default Custom: comma-separated (e.g., `problem,scope,requirements`)

## Goal

Transform Product Decision Records (PDRs) into a comprehensive Product Requirements Document (PRD) with all required sections.

**Key Insight**: PDRs capture **why** decisions were made; the PRD captures **what** the product will deliver as a result of those decisions.

## Role & Context

You are acting as a **Product Writer** synthesizing PDRs into comprehensive product documentation. Your role involves:

- **Translating** individual PDRs into cohesive product sections
- **Synthesizing** decisions into actionable requirements
- **Ensuring** consistency between PDRs and generated PRD
- **Producing** stakeholder-appropriate documentation

### Product Document Hierarchy

| Document | Purpose | Location |
|----------|---------|----------|
| `.specify/memory/pdr.md` | Product decisions with rationale | Input |
| `PRD.md` (root) | Full Product Requirements Document | Output |
| `.specify/memory/constitution.md` | Product vision/strategy | Constraint |

## Outline

1. **Load PDRs**: Parse all PDRs from `.specify/memory/pdr.md`
2. **Determine Sections**: Parse `--sections` flag to determine which sections to generate
3. **Generate Sections**: Create all requested PRD sections
4. **Output**: Write complete `PRD.md` to project root

## Execution Steps

### Phase 1: PDR Loading

**Objective**: Load and analyze existing PDRs

1. **Run Setup Script**:
   - Execute `{SCRIPT}` to prepare product files
   - Creates `PRD.md` from template if it doesn't exist

2. **Load PDRs**:
   - Read `.specify/memory/pdr.md`
   - Parse each PDR: ID, title, category, context, decision, consequences
   - Build decision index

3. **Load Constitution**:
   - Read `.specify/memory/constitution.md` for constraint validation
   - Extract principles that affect product documentation

4. **PDR-to-Section Mapping**:

   | PDR Category | Primary PRD Section | Secondary Sections |
   |--------------|---------------------|--------------------|
   | Problem | 2. The Problem | 1. Overview |
   | Persona | 5. Personas | 1. Overview |
   | Scope | 6. Functional Requirements | 8. Out of Scope |
   | Metric | 4. Success Metrics | 3. Goals/Objectives |
   | Prioritization | 6. Functional Requirements | 8. Out of Scope |
   | Business Model | 1. Overview | 4. Success Metrics |
   | Feature | 6. Functional Requirements | - |
   | NFR | 7. Non-Functional Requirements | - |

### Phase 2: Section Generation

**Objective**: Generate each PRD section from PDR content

**Section Selection Based on `--sections` Flag**:

| Flag Value | Sections to Generate |
|------------|----------------------|
| `all` | All 11 sections |
| `overview,problem,goals` | Sections 1, 2, 3 only |
| Custom | Specified sections |

**Generate sections in this order**:

#### Section 1: Overview

**Purpose**: High-level product description

**PDRs to Reference**: Problem, Business Model, Scope

**Generate**:
- Product name and description (from Problem PDRs)
- Purpose statement (from Business Model)
- In Scope / Out of Scope summary (from Scope PDRs)

#### Section 2: The Problem

**Purpose**: Articulate the problem being solved

**PDRs to Reference**: Problem category PDRs

**Generate**:
- Problem statement (from Problem PDR context)
- Current state description
- Pain points experienced
- Impact of not solving

#### Section 3: Goals/Objectives

**Purpose**: Define what success looks like

**PDRs to Reference**: Problem, Metric PDRs

**Generate**:
- Primary Goal
- Technical Goal
- Business Goal
- Goals traced to PDRs table

#### Section 4: Success Metrics

**Purpose**: Define measurable outcomes

**PDRs to Reference**: Metric category PDRs

**Generate**:
- Key metrics with targets
- Measurement methods
- Metrics traced to PDRs table

#### Section 5: Personas

**Purpose**: Define target users

**PDRs to Reference**: Persona category PDRs

**Generate**:
- Primary Persona with role, needs, success quote
- Secondary Personas
- Persona traced to PDRs

#### Section 6: Functional Requirements

**Purpose**: Define what the product must do

**PDRs to Reference**: Scope, Feature, Prioritization PDRs

**Generate**:
- User Stories table
- Feature requirements with acceptance criteria
- Requirements traced to PDRs

#### Section 7: Non-Functional Requirements (NFRs)

**Purpose**: Define quality attributes

**PDRs to Reference**: NFR category PDRs

**Generate**:
- Performance requirements
- Security requirements
- Reliability requirements
- Usability requirements
- Scalability requirements
- NFRs traced to PDRs

#### Section 8: Out of Scope

**Purpose**: Define explicit exclusions

**PDRs to Reference**: Scope PDRs (negative decisions)

**Generate**:
- Features excluded
- Technical exclusions
- Market exclusions
- Scope decisions traced to PDRs

#### Section 9: Risks & Mitigation

**Purpose**: Document product risks

**PDRs to Reference**: All PDRs (consequence sections)

**Generate**:
- Risk table with likelihood, impact, mitigation
- Technical risks
- Market risks
- Operational risks
- Risks traced to PDR consequence sections

#### Section 10: Roadmap & Milestones (NEW)

**Purpose**: Define product release milestones with feature groupings

**PDRs to Reference**: Milestone category PDRs

**Generate**:
- Milestone name and target date
- Demo sentence for each milestone
- Features included in each milestone (with priority)
- Feature dependencies (from Boundary Maps in specs)
- Success criteria per milestone
- Features deferred to future milestones
- Milestone-to-PDR traceability table

**Milestone Generation Logic**:
1. Filter PDRs for `Category = Milestone`
2. For each milestone PDR:
   - Extract release goal, target date, demo sentence
   - List features with priority (Must/Should/Could)
   - Map dependencies from Boundary Map
   - Extract success metrics
3. Build dependency graph to detect ordering
4. Identify features deferred (not in any milestone)

**Example Output**:
```markdown
### Milestone 1: Internal Alpha - Q1 2026

**Demo Sentence:** "After this milestone, developers can provision Postgres via the CNE Agent"

| Feature | Priority | Demo Sentence | Dependencies |
|---------|----------|---------------|--------------|
| SSO Auth | Must | "User can log in via Tikal SSO" | None |
| Postgres Provision | Must | "User can request a Postgres DB" | SSO Auth |

**Success Criteria:**
| Metric | Target |
|--------|--------|
 | ≥| Internal users2 |
| Time-to-provision | <15 min |

---

### Milestone 2: Production - Q2 2026

**Features Deferred from M1:**
- Web UI (deferred to M2)
```

### Phase 3: PDR Summary

**Objective**: Create traceable summary of all decisions

1. **Build Summary Table**:
   - All PDRs with ID, Category, Decision, Status, Impact
   - Links back to `.specify/memory/pdr.md`

2. **Cross-Reference Check**:
   - Verify all PDR categories are represented
   - Flag any gaps in coverage

### Phase 4: Output Generation

**Objective**: Write complete Product Requirements Document

1. **Structure Check**:
   - Ensure all **requested** sections are present (all 11 by default)
   - Ensure each section has content
   - Verify PDR traceability

2. **Write PRD.md**:
   - Use `templates/prd-template.md` as base
   - Replace placeholders with generated content
   - Write to project root as `PRD.md`

3. **Update References**:
   - Ensure `.specify/memory/pdr.md` link is correct
   - Update version and timestamp

4. **Generate Report**:

```markdown
## Product Requirements Document Generated

**Output**: PRD.md (project root)
**Sections**: [all|custom]

**Sections Generated**:
- [x] 1. Overview (based on PDR-001, PDR-003)
- [x] 2. The Problem (based on PDR-001)
- [x] 3. Goals/Objectives (based on PDR-001, PDR-004)
- [x] 4. Success Metrics (based on PDR-004)
- [x] 5. Personas (based on PDR-002)
- [x] 6. Functional Requirements (based on PDR-003, PDR-005)
- [x] 7. Non-Functional Requirements (based on PDR-006)
- [x] 8. Out of Scope (based on PDR-003)
- [x] 9. Risks & Mitigation (based on all PDRs)

**PDR Coverage**: X/Y PDRs incorporated

**Recommended Next Steps**:
1. Review generated PRD for accuracy
2. Run `/product.analyze` for consistency validation
3. Share with stakeholders for review
4. Begin feature development with `/spec.specify`
```

## Key Rules

### PDR Traceability

- **Every section** should reference source PDRs
- **No content** without PDR backing (except templates)
- **Flag gaps** where PDRs are missing

### Consistency

- **Terminology** must match across sections
- **Category labels** must be consistent
- **Metric definitions** exactly as stated in PDRs

### Completeness

- **All requested sections** must be generated (all 9 by default)
- **All sections** must have content (not just placeholders)
- **PDR coverage** should be maximized

### Quality Standards

- **Validate** requirements are actionable
- **Ensure** acceptance criteria are testable
- **Check** metric definitions are measurable

## Workflow Guidance & Transitions

### After `/product.implement`

Recommended next steps:

1. **Review PRD**: Verify product documentation is accurate
2. **Run `/product.analyze`**: Validate consistency and completeness
3. **Share for Review**: Get stakeholder feedback
4. **Start Features**: Use `/spec.specify` to create feature specs

### When to Use This Command

- **After `/product.specify`**: Generate PRD from discussed PDRs
- **After `/product.init`**: Document existing product
- **PDR Updates**: Regenerate PRD after new decisions
- **Documentation Sprint**: Create comprehensive product docs

### When NOT to Use This Command

- **No PDRs exist**: Use `/product.specify` or `/product.init` first
- **Feature-level**: Feature PRD generated via `/spec.plan --product`
- **Minor updates**: Use direct editing for small changes

## Context

{ARGS}