---
description: Interactive PRD exploration and Product Decision Record creation (greenfield)
handoffs:
- label: Validate PDRs
  agent: product.clarify
  prompt: Validate product requirements and decisions - confirm priorities, scope,
    and assumptions
  send: true
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "specify {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "specify {ARGS}"
agent_scripts:
  sh: scripts/bash/update-agent-context.sh __AGENT__
  ps: scripts/powershell/update-agent-context.ps1 -AgentType __AGENT__
---


<!-- Extension: product -->
<!-- Config: .specify/extensions/product/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"B2B SaaS platform for supply chain management with real-time inventory tracking"`
- `"Mobile-first e-commerce app with offline support and social features"`
- `"Internal developer platform for self-service infrastructure provisioning"`
- `"Consumer fintech app for personal budget management with AI insights"`

When users provide product context like this, use it to drive the product exploration conversation.

## Goal

Transform a high-level product idea or description into well-documented Product Decision Records (PDRs) through interactive exploration and trade-off analysis.

**Key Insight**: Unlike direct PRD generation, this command prioritizes **discussion and exploration** before committing to formal documentation. The goal is to surface trade-offs, validate assumptions, and make informed decisions collaboratively.

### Flags

- `--sections SECTIONS`: PRD sections to include in final output
  - `all` (default): All 9 sections
  - Custom: comma-separated (e.g., `overview,problem,requirements`)

- `--pdr-heuristic HEURISTIC`: PDR generation strategy
  - `surprising` (default): Skip obvious product defaults
  - `all`: Document all decisions discussed
  - `minimal`: Only high-risk/unconventional decisions

- `--no-decompose`: Disable automatic feature decomposition (default: auto-decompose if multiple domains detected)

## Role & Context

You are acting as a **Product Strategist** facilitating a product discovery session. Your role involves:

- **Exploring** possible product directions and their trade-offs
- **Asking** clarifying questions to surface hidden requirements
- **Proposing** options with clear consequences
- **Documenting** decisions in PDR format once consensus is reached

### Two-Level Product System

| Level | Location | PDR File | PRD Document |
|-------|----------|----------|--------------|
| **Product** | Main branch | `{REPO_ROOT}/.specify/drafts/pdr.md` | `PRD.md` (root) |
| **Feature** | Feature branch | `specs/{feature}/pdr.md` | `specs/{feature}/PRD.md` |

This command operates at the **Product level**, creating PDRs in `{REPO_ROOT}/.specify/drafts/pdr.md`.

## Outline

Given the product input, execute this workflow:

1. **Feature Detection** (Phase 0): Decompose product into feature areas (auto-detect if multiple domains)
2. **Parse Product Context**: Extract key problems, market position, and constraints (per feature area if decomposed)
3. **Load Constitution**: Check `{REPO_ROOT}/.specify/memory/constitution.md` for product vision/strategy constraints
4. **Exploration Phase**: Interactive discussion to surface trade-offs and options (per feature area)
5. **Decision Phase**: Document decisions as PDRs with full rationale (organized by feature area)
6. **Output**: Write PDRs to `{REPO_ROOT}/.specify/drafts/pdr.md` with feature area organization

**NOTE:** This is an interactive command. You will engage the user in conversation before finalizing PDRs.

## Execution Steps

### Phase 0: Feature Detection (Greenfield)

**Objective**: Decompose large product into manageable feature areas automatically

**When**: This phase runs automatically when the product is detected as having multiple distinct domains. Use `--no-decompose` to skip.

#### Step 1: Domain Analysis

Analyze the product for distinct business domains and functional areas:

| Domain Category | Typical Keywords |
|-----------------|------------------|
| Authentication | login, auth, oauth, sso, permissions, roles, access |
| User Management | profile, registration, preferences, settings, account |
| Payments | billing, checkout, subscription, invoicing, pricing |
| Orders | cart, checkout, order management, fulfillment |
| Inventory | stock, warehouse, products, catalog, sku |
| Notifications | email, sms, push, alerts, webhooks |
| Analytics | metrics, reporting, dashboards, data |
| Search | search, indexing, elasticsearch |
| Media | upload, images, video, cdn |
| Messaging | chat, realtime, websocket |

#### Step 2: Boundary Detection

Identify boundaries between feature areas based on:

1. **User Journey**: What user workflows belong together?
2. **Team Ownership**: Are different teams responsible for different areas?
3. **Deployment Independence**: Can feature areas be released separately?
4. **Integration Points**: How do feature areas communicate?

#### Step 3: Feature Area Proposal (Interactive)

Present detected feature areas to user for confirmation:

```markdown
## Detected Feature Areas

I've identified the following feature areas from your product description:

| # | Feature Area | Key Domains | Rationale |
|---|--------------|-------------|-----------|
| 1 | **Auth** | Authentication, Authorization | Core user entry |
| 2 | **Core** | User Management, Profiles | Core data |
| 3 | **Business** | Payments, Subscriptions | Revenue domain |
| 4 | **Operations** | Inventory, Fulfillment | Physical goods |

### Questions for Confirmation:

1. **Are these feature areas correct?** [Y/n]
2. **Should any areas be merged?** (e.g., Auth + User Management)
3. **Should any areas be split?** (e.g., Payments into Billing + Subscriptions)
4. **Any missing areas?** (e.g., Analytics, Notifications)

**Reply** with:
- `Y` to confirm and proceed
- `n` to disable decomposition (generate monolithic PDRs)
- Specific changes (e.g., "merge 1+2", "split 3", "add Notifications")
```

#### Step 4: Decomposition Decision

Based on user response:

| Response | Action |
|----------|--------|
| `Y` / Enter | Proceed with detected feature areas |
| `n` | Skip decomposition, generate monolithic PDRs |
| Modifications | Adjust feature areas, then proceed |
| Empty/Default | Auto-proceed if ≤3 areas, ask if >3 |

**Threshold Logic**:

- **≤3 areas**: Auto-approve, show summary
- **4-6 areas**: Show summary, ask to confirm
- **>6 areas**: Show summary, suggest grouping, ask to confirm

#### Step 5: Output

After confirmation, output structured feature area data:

```json
{
  "decomposition": "enabled",
  "feature_areas": [
    {"id": "auth", "name": "Auth", "domains": ["Authentication", "Authorization"], "rationale": "Core security boundary"},
    {"id": "core", "name": "Core", "domains": ["User Management", "Profiles"], "rationale": "Core data ownership"},
    {"id": "business", "name": "Business", "domains": ["Payments", "Subscriptions"], "rationale": "Revenue domain"}
  ],
  "next_phase": "Product Analysis (per feature area)"
}
```

**If decomposition disabled**:

```json
{
  "decomposition": "disabled",
  "reason": "user_requested",
  "next_phase": "Product Analysis (monolithic)"
}
```

---

### Phase 1: Product Analysis

**Objective**: Extract product drivers from the input

**Note**: If feature area decomposition is enabled (Phase 0), repeat this analysis **per feature area** to ensure focused, manageable PDRs.

1. **Identify Problem Drivers**:
   - What core problem does this product solve?
   - Who experiences this problem?
   - What are the current workarounds?

2. **Identify Market Drivers**:
   - Target market segments
   - Competitive landscape
   - Market trends and timing

3. **Identify Business Drivers**:
   - Revenue model
   - Scaling expectations
   - Strategic importance

4. **Identify Constraint Drivers**:
   - Technology mandates or prohibitions
   - Budget and timeline constraints
   - Team skills and organizational factors
   - Regulatory or compliance requirements

5. **Load Constitution**:
   - Read `{REPO_ROOT}/.specify/memory/constitution.md` if it exists
   - Extract product vision and strategy principles
   - Note any constraints that limit product choices

6. **Check Existing Documentation**:
   - Scan `README.md` for already-documented product vision
   - Check `AGENTS.md` for project context
   - Review `CONTRIBUTING.md` for dev guidelines
   - Note: Don't duplicate - reference existing docs

**Output**: Internal summary of product drivers (do not write to file yet)

**If decomposed**: Generate separate analysis for each feature area, noting cross-area dependencies

### Phase 2: Product Exploration (Interactive)

**Objective**: Explore solution options through guided discussion

For each major product decision area, present options and facilitate discussion:

#### Decision Areas to Explore

1. **Problem Scope**
   - Core problem vs nice-to-have problems
   - Target market breadth
   - Geographic scope

2. **Target Personas**
   - Primary vs secondary users
   - B2B vs B2C vs B2B2C
   - Enterprise vs SMB vs Consumer

3. **Solution Approach**
   - Build vs buy vs partner
   - Platform vs single product
   - Self-serve vs high-touch

4. **Monetization**
   - Pricing model (subscription, usage, transaction)
   - Target customer segment
   - Revenue timeline

5. **Go-to-Market**
   - Launch strategy
   - Distribution channels
   - Marketing approach

6. **Success Metrics**
   - Primary KPIs
   - Leading vs lagging indicators
   - Measurement approach

#### Exploration Format

For each decision area requiring user input, present:

```markdown
## Product Decision: [Decision Area]

**Context**: [Why this decision matters based on product description]

**Options Being Considered**:

| Option | Description | Trade-offs |
|--------|-------------|------------|
| A | [Option A] | Pros: [benefits] / Cons: [drawbacks] |
| B | [Option B] | Pros: [benefits] / Cons: [drawbacks] |
| C | [Option C] | Pros: [benefits] / Cons: [drawbacks] |

**Recommended**: Option [X] - [Reasoning based on product requirements]

**Questions for Clarification**:
1. [Question about constraints or preferences]
2. [Question about trade-off priorities]

Reply with your choice (A/B/C), or provide additional context.
```

#### Exploration Rules

- Present **one decision area at a time** to maintain focus
- Always provide a **recommended option** with clear reasoning
- Ask **targeted questions** to surface hidden requirements
- Allow user to **propose alternatives** not in the initial options
- After user responds, **summarize the decision** before moving to next area
- Skip decisions that are **already determined** by product context or constitution
- Limit to **5-7 key decisions** (defer less critical decisions)

### Phase 3: Decision Documentation

**Objective**: Convert exploration outcomes into formal PDRs

**Note**: If feature area decomposition is enabled, organize PDRs **by feature area** with clear section headers.

After each decision is confirmed:

1. **Create PDR Entry**:
   - Use PDR format from `.specify/templates/pdr-template.md`
   - Document context, decision, consequences, and alternatives
   - Link to constitution principles if applicable
   - **Include Feature Area tag**: Mark each PDR with its parent feature area

2. **Feature Area Organization**:

If decomposed, structure the PDR file as:

```markdown
# Product Decision Records

## PDR Index

| ID | Feature Area | Decision | Status | Date | Owner |
|----|--------------|----------|--------|------|-------|
| PDR-001 | System | Target Market | Proposed | 2026-03-09 | User/AI |
| PDR-002 | Auth | Primary Persona | Proposed | 2026-03-09 | User/AI |
| PDR-003 | Business | Pricing Model | Proposed | 2026-03-09 | User/AI |

---

## System-Level PDRs

### PDR-001: [Decision Title]

[Full PDR content...]

---

## Auth Feature Area PDRs

### PDR-002: [Decision Title]

[Full PDR content...]

---

## Business Feature Area PDRs

### PDR-003: [Decision Title]

[Full PDR content...]
```

3. **Cross-Cutting PDRs**: Some decisions affect multiple feature areas (e.g., "Use freemium for all features"). Mark these as **System-Level** and note impact on each area.

4. **PDR Format**:

```markdown
## PDR-[NNN]: [Decision Title]

### Status
Proposed

### Date
[YYYY-MM-DD]

### Owner
[User/AI collaboration]

### Category
[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR]

### Context
**Problem/Opportunity:**
[Problem statement from exploration]

**Market Forces:**
- [Market factor 1]
- [Customer feedback]
- [Competitive pressure]

### Decision
**Decision Statement:**
[Clear statement of what was decided]

**Rationale:**
[Why this option was chosen]

### Consequences

#### Positive
- [Benefit 1]
- [Benefit 2]

#### Negative
- [Trade-off 1]
- [Trade-off 2]

#### Risks
- [Risk 1 with mitigation]

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [Method] |

### Common Alternatives

#### Option A: [Alternative Name]
**Description**: [Brief description]
**Trade-offs**: [Neutral comparison - when this would be better/worse, not "rejected because"]

#### Option B: [Alternative Name]
**Description**: [Brief description]
**Trade-offs**: [Neutral comparison]
```

3. **Number PDRs sequentially**: Start from PDR-001 for new products, or continue from highest existing number

### Phase 4: PDR Output

**Objective**: Write finalized PDRs to file

1. **Run Setup Script**:
   - Execute `.specify/extensions/product/scripts/bash/setup-product.sh "specify $ARGUMENTS"` to ensure `{REPO_ROOT}/.specify/drafts/pdr.md` exists
   - Script creates from template if file doesn't exist
   - Pass `--no-decompose` if decomposition was disabled

2. **Write PDRs**:
   - Append new PDRs to `{REPO_ROOT}/.specify/drafts/pdr.md`
   - Update PDR index table at top of file (include Feature Area column)
   - Preserve any existing PDRs (don't overwrite)
   - **If decomposed**: Add section headers for each feature area

3. **Report Summary**:
   - List of feature areas identified
   - PDRs created per feature area with IDs and titles
   - Constitution alignment status
   - Cross-cutting decisions noted
   - Recommended next steps

**Summary Format**:

```markdown
## Feature Area Decomposition Summary

### Feature Areas Identified: 3

| # | Feature Area | PDRs Created |
|---|--------------|--------------|
| 1 | System-Level | PDR-001: Target Market |
| 2 | Auth | PDR-002: Primary Persona, PDR-003: Authentication Approach |
| 3 | Business | PDR-004: Pricing Model, PDR-005: Payment Integration |

### Cross-Cutting Decisions
- PDR-001 affects all feature areas

### Next Steps
1. Review PDRs with /product.clarify
2. Generate PRD.md with /product.implement
```

## Key Rules

### Exploration First

- **Do NOT generate PRD directly** from product description
- **Engage in discussion** to validate assumptions
- **Surface trade-offs** before committing to decisions
- **Allow iteration** - user can revisit earlier decisions

### Constitution Compliance

- PDRs must **align with constitution** principles
- **Flag conflicts** between product requirements and constitution
- Constitution violations require explicit override with justification

### Incremental PDRs

- Create **focused PDRs** - one decision per PDR
- **Link related PDRs** when decisions interact
- **Defer decisions** that can be made later
- Mark **provisional decisions** that may need revision

### Quality Standards

- Every PDR must have **clear context** explaining why decision was needed
- **Consequences** must include both positive and negative outcomes
- **Alternatives** must explain trade-offs neutrally
- Decisions must be **actionable** - clear enough to implement

### Feature Area Decomposition

- **Auto-detect domains**: Analyze product description for distinct business domains automatically
- **Interactive confirmation**: Always confirm feature area breakdown with user
- **Balanced granularity**: Aim for 3-7 feature areas; avoid over-decomposition
- **Clear boundaries**: Each feature area should have distinct responsibilities
- **Cross-cutting concerns**: Document system-level decisions separately
- **Per-area exploration**: Run product exploration per feature area for focused decisions
- **Use --no-decompose**: Skip decomposition for simple/small products

## Workflow Guidance & Transitions

### After `/product.specify`

Recommended next steps:

1. **Review PDRs**: Ensure all decisions are accurate and complete
2. **Run `/product.clarify`**: Refine any ambiguous or incomplete PDRs
3. **Run `/product.implement`**: Generate full PRD from PDRs
4. **Proceed to features**: Use `/spec.specify` to create feature specs within this product

### When to Use This Command

- **New products**: Starting product strategy from scratch
- **Major pivots**: Significant product shifts requiring new decisions
- **Documentation**: Capturing verbal decisions as formal PDRs
- **Team onboarding**: Walking through product rationale with new members

### When NOT to Use This Command

- **Existing products**: Use `/product.init` instead to reverse-engineer from existing docs
- **Minor updates**: Use `/product.clarify` for PDR refinements
- **Feature-level**: Feature product decisions handled via `/spec.specify`

## Context

$ARGUMENTS