---
name: product-specify
description: Interactive PRD exploration and Product Decision Record (PDR) creation for greenfield products. Facilitates product discovery discussions, surfaces trade-offs, and documents decisions as individual PDR files. Use when starting a new product or major pivot.
disable-model-invocation: true
---

# product-specify

## What this skill does

Transforms a high-level product idea into documented Product Decision Records (PDRs) through **interactive exploration** and trade-off analysis.

**Key insight**: Discussion and exploration happen *before* committing to formal documentation. The goal is to surface trade-offs, validate assumptions, and make informed decisions collaboratively.

**Output**: Individual `PDR-{NNN}.md` files (status **Proposed**) in `.adlc/drafts/pdr/` with an auto-generated `pdr.md` index.

## When to use

- New product from scratch
- Major product pivots
- Documenting verbal decisions formally
- Team onboarding — walking through product rationale

## When NOT to use

- Existing product (use `/product.init` instead)
- Minor PDR updates (use `/product.clarify` instead)

## Execution Steps

### Phase 0: Environment Setup

```bash
sh: scripts/bash/setup-product-specify.sh [--json]
ps: scripts/powershell/setup-product-specify.ps1
```

**Setup output** (JSON):
```json
{
  "REPO_ROOT": "/path/to/project",
  "PDR_DRAFTS_DIR": "/path/to/project/.adlc/drafts/pdr",
  "PRD_FILE": "/path/to/project/PRD.md",
  "next_pdr": "001"
}
```

### Phase 1: Feature-Area Decomposition (Optional)

Analyze the product for distinct business domains. Auto-decompose if multiple domains detected. Use `--no-decompose` to skip.

**Present detected areas**:
```markdown
## Detected Feature Areas

| # | Feature Area | Key Domains | Rationale |
|---|--------------|-------------|-----------|
| 1 | **Auth** | Authentication, Authorization | Core user entry |
| 2 | **Core** | User Management, Profiles | Core data |
| 3 | **Business** | Payments, Subscriptions | Revenue domain |

Reply: Y to confirm, n for monolithic, or suggest changes.
```

**Threshold**:
- ≤3 areas: Auto-approve
- 4-6 areas: Confirm with user
- >6 areas: Suggest grouping

### Phase 2: Product Analysis

Extract product drivers:

1. **Problem Drivers**: Core problem, who experiences it, current workarounds
2. **Market Drivers**: Target segments, competitive landscape, trends
3. **Business Drivers**: Revenue model, scaling expectations, strategic importance
4. **Constraint Drivers**: Technology mandates, budget, team skills, regulatory
5. **Load Constitution**: Read `{REPO_ROOT}/.adlc/memory/constitution.md` if exists
6. **Check Existing Docs**: Scan `README.md`, `AGENTS.md`, `CONTRIBUTING.md` for context

### Phase 3: Product Exploration (Interactive)

For each major decision area, present options and facilitate discussion:

**Decision areas** (5-7 key decisions):
1. Problem Scope
2. Target Personas
3. Solution Approach (build vs buy vs partner)
4. Monetization
5. Go-to-Market
6. Success Metrics

**Exploration format**:
```markdown
## Product Decision: [Decision Area]

**Context**: [Why this decision matters]

**Options**:
| Option | Description | Trade-offs |
|--------|-------------|------------|
| A | [Option A] | Pros: [X] / Cons: [Y] |
| B | [Option B] | Pros: [X] / Cons: [Y] |

**Recommended**: Option [X]

**Questions**:
1. [Question about constraints]
2. [Question about trade-off priorities]
```

**Rules**:
- Present **one decision area at a time**
- Always provide a **recommended option** with reasoning
- Ask **targeted questions** to surface hidden requirements
- Skip decisions already determined by context or constitution
- Limit to **5-7 key decisions**

### Phase 4: Cross-Feature-Area Pre-Analysis

During exploration, watch for:

| Pattern | Detection | Action |
|---------|-----------|--------|
| Shared Personas | Same user type in multiple areas | Note for cross-area metadata |
| Priority Tensions | Areas prioritize differently | ⚠️ Flag potential conflict |
| Feature Overlap | Similar features in different areas | ⚠️ Flag for consolidation |
| Metric Conflicts | Same metric, different targets | ⚠️ Flag for alignment |

### Phase 5: Decision Documentation

After each decision is confirmed, create a PDR file.

**PDR file format** (individual file):
```markdown
## PDR-[NNN]: [Decision Title]

### Status

**Proposed**

### Date

YYYY-MM-DD

### Owner

[User/AI collaboration]

### Category

[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR | Milestone]

### Feature-Area

[core | business | growth | ...]

### Context
**Problem/Opportunity:**
[Clear description]

**Market Forces:**
- [Market factor 1]
- [Customer feedback]

### Decision
**Decision Statement:**
[Clear statement of what was decided]

**Rationale:**
[Why this option was chosen]

### Consequences
#### Positive
- [Benefit 1]

#### Negative
- [Trade-off 1]

#### Risks
- [Risk with mitigation]

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [Method] |

### Alternatives Considered
#### Option A: [Alternative Name]
**Description:** [Brief description]
**Trade-offs:** [Neutral comparison]

### Constitution/Vision Alignment
| Principle | Alignment | Notes |
|-----------|-----------|-------|
| [Vision Principle] | ✅ Compliant / ⚠️ Deviation | [Explanation] |
```

### Phase 6: Write PDR Files and Regenerate Index

1. **Number sequentially**: Start from highest existing PDR number + 1
2. **Write individual files**: `{REPO_ROOT}/.adlc/drafts/pdr/PDR-{NNN}.md`
3. **Regenerate index**: `{REPO_ROOT}/.adlc/drafts/pdr/pdr.md`

**Index format**:
```markdown
# Product Decision Records

## PDR Index

| ID | Feature-Area | Category | Status | Date | Owner |
|----|--------------|----------|--------|------|-------|
| PDR-001 | System | Target Market | Proposed | 2026-03-09 | User/AI |
| PDR-002 | Auth | Primary Persona | Proposed | 2026-03-09 | User/AI |

---

*Individual PDR files: PDR-*.md in this directory*
```

### Phase 7: Summary Report

```markdown
## Feature Area Decomposition Summary

### Feature Areas Identified: 3

| # | Feature Area | PDRs Created |
|---|--------------|--------------|
| 1 | System-Level | PDR-001: Target Market |
| 2 | Auth | PDR-002: Primary Persona, PDR-003: Authentication Approach |
| 3 | Business | PDR-004: Pricing Model, PDR-005: Payment Integration |

### Next Steps
1. Review PDRs with /product.clarify
2. Generate PRD.md with /product.implement
```

## PDR Numbering Rules

- Scan `{REPO_ROOT}/.adlc/drafts/pdr/` for existing `PDR-*.md` files
- Extract numeric suffix, find maximum
- Next PDR = max + 1, zero-padded to 3 digits
- Never reuse numbers

## Key Rules

### Exploration First
- **Do NOT generate PRD directly** from product description
- **Engage in discussion** to validate assumptions
- **Surface trade-offs** before committing to decisions
- **Allow iteration** — user can revisit earlier decisions

### Constitution Compliance
- PDRs must **align with constitution** principles
- **Flag conflicts** between product requirements and constitution
- Constitution violations require explicit override with justification

### Incremental PDRs
- Create **focused PDRs** — one decision per PDR
- **Link related PDRs** when decisions interact
- **Defer decisions** that can be made later
- Mark **provisional decisions** that may need revision

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `PDR_INDEX` — `{REPO_ROOT}/.adlc/drafts/pdr/pdr.md`
- `PRD_FILE` — `{REPO_ROOT}/PRD.md`
- `CONSTITUTION` — `{REPO_ROOT}/.adlc/memory/constitution.md`

## 12-Factor Alignment

- **Factor III (Mission Definition)**: Defines the product mission before execution
- **Factor XI (Directives as Code)**: PDRs are version-controlled decision records

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Let's just write the PRD directly." | PRDs without PDRs lack traceable rationale. Decisions become undocumented assumptions. |
| "We already know what to build." | Even "obvious" decisions have alternatives. Documenting them prevents future reversal. |
| "Exploration takes too long." | A 10-minute discussion now prevents weeks of rework later. |

## Red Flags

- **Generating PRD before PDRs are accepted** — `/product.implement` requires Accepted status; Proposed PDRs will be skipped.
- **Skipping the constitution check** — misaligned decisions propagate into the PRD and become expensive to fix.
- **No alternatives documented** — a PDR without alternatives is a statement, not a decision.

## Verification

- [ ] Setup script returns valid JSON with all paths
- [ ] `.adlc/drafts/pdr/` directory exists
- [ ] At least one `PDR-*.md` file created with status "Proposed"
- [ ] `pdr.md` index auto-generated with correct table
- [ ] Constitution alignment checked (if constitution exists)
- [ ] Cross-feature-area conflicts flagged
- [ ] No duplicate PDR IDs
- [ ] Each PDR has at least 2 alternatives documented
