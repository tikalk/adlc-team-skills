---
description: Reverse-engineer PDRs from existing codebase and documentation (brownfield)
handoffs:
- label: Validate PDRs
  agent: product.clarify
  prompt: Validate product requirements discovered from brownfield analysis - confirm
    feature priorities and scope
  send: true
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "init {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "init {ARGS}"
---


<!-- Extension: product -->
<!-- Config: .specify/extensions/product/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Existing B2B SaaS product with React frontend, Node.js API"`
- `"Legacy monolith with documented roadmap"`
- `"Mobile app with in-app purchase monetization"`
- Empty input: Scan entire codebase and infer product decisions

When users provide context, use it to focus the reverse-engineering effort.

## Goal

Reverse-engineer product decisions from an **existing product** (brownfield) to create PDRs documenting discovered decisions, then **auto-trigger clarification** to validate findings.

**Output**:

1. **PDRs** documenting inferred product decisions in `{REPO_ROOT}/.specify/drafts/pdr.md`
2. **Auto-handoff** to `/product.clarify` to validate brownfield findings

**Key Difference from `/product.specify`**:

- `/product.init` (this command) = **Discovers** what's already established in product
- `/product.specify` = **Explores** new possibilities for greenfield products

This command focuses on **current state analysis** - what IS, not what SHOULD BE.

### Flags

- `--pdr-heuristic HEURISTIC`: PDR generation strategy
  - `surprising` (default): Skip obvious product defaults, document only surprising/risky decisions
  - `all`: Document all discovered decisions
  - `minimal`: Only high-risk decisions

- `--no-decompose`: Disable automatic sub-system detection from code structure (default: auto-detect if multiple modules detected)

## Role & Context

You are acting as a **Product Archaeologist** uncovering implicit product decisions from existing artifacts. Your role involves:

- **Scanning** codebase, docs, and existing artifacts for product choices
- **Inferring** product decisions from feature sets and monetization
- **Documenting** discovered patterns as PDRs
- **Identifying** gaps where decisions are unclear

### Brownfield vs Greenfield

| Scenario | Command | Input | Output |
|----------|---------|-------|--------|
| **Brownfield** (existing product) | `/product.init` | Codebase/docs scan | Inferred PDRs |
| **Greenfield** (new product) | `/product.specify` | Product idea | Discussed PDRs |

## Outline

1. **Sub-System Detection** (Phase 0): Identify sub-systems from code structure (auto-detect)
2. **Product Scan**: Analyze existing docs and codebase for product signals (per area if decomposed)
3. **Documentation Deduplication**: Scan existing docs to avoid repeating
4. **Signal Detection**: Identify product patterns and decisions in use
5. **PDR Generation**: Create PDRs for discovered decisions (marked "Discovered"), organized by area
6. **Gap Analysis**: Identify areas where decisions are unclear
7. **Output**: Write PDRs to `{REPO_ROOT}/.specify/drafts/pdr.md` (NO PRD.md creation)
8. **Auto-Handoff**: Trigger `/product.clarify` to validate brownfield findings

## Execution Steps

### Phase 0: Subsystem Detection (Brownfield)

**Objective**: Identify sub-systems from existing product structure automatically

**When**: This phase runs automatically when the product is detected as having multiple distinct sub-systems. Use `--no-decompose` to skip.

#### Step 1: Directory Structure Analysis

Analyze the codebase for distinct sub-systems based on directory structure:

| Pattern | Likely Sub-System |
|---------|------------------|
| `src/auth/` | Authentication sub-system |
| `src/users/` | User management sub-system |
| `features/payment/` | Payments sub-system |
| `modules/inventory/` | Inventory sub-system |
| `apps/mobile/`, `apps/web/` | Multi-platform product |
| `lib/shared/` | Shared (not a sub-system) |

#### Step 2: Documentation Analysis

Detect feature areas from documentation:

| Pattern | Detection Method | Sub-System Evidence |
|---------|------------------|----------------------|
| README sections | Product description | Feature sections |
| Roadmap | Feature list | Planned feature areas |
| Pricing page | Monetization signals | Business model |
| Target market | Marketing copy | Problem scope |

#### Step 3: Monetization Detection

Identify business model from existing artifacts:

| Evidence | Business Model |
|----------|---------------|
| Subscription tiers | SaaS/Recurring |
| Transaction fees | Transaction-based |
| In-app purchases | Consumer freemium |
| Enterprise pricing | B2B Enterprise |

#### Step 4: Sub-System Proposal (Interactive)

Present detected sub-systems to user for confirmation:

```markdown
## Detected Sub-Systems

I've identified the following sub-systems from your product:

| # | Sub-System | Detection Method | Evidence |
|---|------------|-----------------|----------|
| 1 | **Auth** | Directory + Documentation | src/auth/, login flows |
| 2 | **Core** | Directory | src/users/, user profiles |
| 3 | **Business** | Documentation | Payments section, pricing |
| 4 | **Operations** | Directory | src/inventory/, fulfillment |

### Questions for Confirmation:

1. **Are these sub-systems correct?** [Y/n]
2. **Should any sub-systems be merged?** (e.g., Auth + Core → Identity)
3. **Should any sub-systems be split?** (e.g., Business → Billing + Subscriptions)
4. **Any missing sub-systems?** (e.g., Analytics, Notifications)

**Reply** with:
- `Y` to confirm and proceed
- `n` to disable decomposition (generate monolithic PDRs)
- Specific changes (e.g., "merge 1+2", "split 3", "add Analytics")
```

#### Step 5: Decomposition Decision

Based on user response:

| Response | Action |
|----------|--------|
| `Y` / Enter | Proceed with detected sub-systems |
| `n` | Skip decomposition, generate monolithic PDRs |
| Modifications | Adjust sub-systems, then proceed |
| Empty/Default | Auto-proceed if ≤3 sub-systems, ask if >3 |

**Threshold Logic**:

- **≤3 sub-systems**: Auto-approve, show summary
- **4-6 sub-systems**: Show summary, ask to confirm
- **>6 sub-systems**: Show summary, suggest grouping, ask to confirm

#### Step 6: Output

After confirmation, output structured sub-system data:

```json
{
  "decomposition": "enabled",
  "subsystems": [
    {"id": "auth", "name": "Auth", "detection_method": "directory", "evidence": "src/auth/"},
    {"id": "core", "name": "Core", "detection_method": "directory", "evidence": "src/users/"},
    {"id": "business", "name": "Business", "detection_method": "documentation", "evidence": "Pricing page"}
  ],
  "next_phase": "Product Analysis (per sub-system)"
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

**Objective**: Discover what product decisions are in use

**Note**: If sub-system decomposition is enabled (Phase 0), analyze each sub-system **separately** to provide focused insights.

1. **Run Setup Script**:
   - Execute `.specify/extensions/product/scripts/bash/setup-product.sh "init $ARGUMENTS"` to initialize product files
   - Script scans existing artifacts and outputs structured findings
   - Pass `--no-decompose` if decomposition was disabled

2. **Product Signal Detection (Per Area)**:

   | Signal | Category | Sources to Check |
   |--------|----------|------------------|
   | Target users | Persona | README, marketing docs |
   | Problem solved | Problem | Product description |
   | Features offered | Scope | Feature lists, roadmap |
   | Pricing model | Business | Pricing page, billing code |
   | Success metrics | Metric | Analytics, OKRs |

3. **Monetization Detection**:

   | Evidence | Model |
   |----------|-------|
   | Stripe/Payment integration | Subscription/Transaction |
   | In-app purchases | Consumer freemium |
   | Enterprise pricing page | B2B SaaS |
   | No monetization signals | MVP/Exploring |

### Phase 2: Pattern Recognition

**Objective**: Identify product patterns from existing structure

#### Product Strategy Detection

| Pattern | Evidence | PDR Category |
|---------|----------|--------------|
| **B2B SaaS** | Enterprise pricing, team features | Business Model |
| **Consumer App** | Mobile-first, freemium | Business Model |
| **Marketplace** | Multi-sided, transaction fees | Business Model |
| **Platform** | API, developer features | Scope |

#### User Segmentation

| Pattern | Evidence |
|---------|----------|
| **Enterprise** | SSO, admin controls, audit logs |
| **SMB** | Self-serve, simpler onboarding |
| **Consumer** | Mobile, social, personal use |

### Phase 1.5: Documentation Deduplication

**Objective**: Scan existing docs to avoid repeating documented information

**Scan for**:

- `README.md` - Product description, features
- `PRD.md` - Existing product requirements
- `ROADMAP.md` - Planned features
- `PRICING.md` - Monetization details
- `AGENTS.md` - Project context
- `CONTRIBUTING.md` - Development guidelines

**Deduplication Rules**:

| Finding | Action |
|---------|--------|
| PRD exists | Offer update vs. create new |
| Pricing documented | Reference in PDR, don't duplicate |
| Features in README | Reference, focus on decisions |
| Roadmap exists | Link to planned decisions |

**Process**:

1. Run `.specify/extensions/product/scripts/bash/setup-product.sh "init $ARGUMENTS"` which calls `scan_existing_docs()`
2. Parse findings from output
3. For each finding, determine: Skip PDR / Reference existing / Document new
4. Report: "X decisions covered by existing docs, Y new PDRs created"

### Phase 2: Signal Documentation

**Objective**: Document discovered decisions as PDRs

For each discovered product decision:

1. **Identify the Decision**:
   - What product direction was chosen?
   - What alternatives were available?
   - What forces likely drove this decision?

2. **Create PDR Entry**:

```markdown
## PDR-[NNN]: [Discovered Decision]

### Status
Discovered (Inferred from existing product)

### Date
[Current date]

### Owner
Legacy/Inferred

### Category
[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR]

### Context
**Problem/Opportunity:**
[Inferred problem statement based on product signals]

**Evidence Found**:
- [Documentation evidence 1]
- [Feature evidence 2]

### Decision
**Decision Statement:**
[Statement of what was decided, inferred from product]

### Consequences

#### Positive (Observed)
- [Benefit visible in product]

#### Negative (Potential)
- [Trade-off inherent to this choice]

#### Risks
- [Risk if this decision is not well understood]

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Inferred] | [TBD] | [Method needed] |

### Common Alternatives
#### [Likely Alternative]
**Description**: [What it is]
**Trade-offs**: [Neutral assessment - NO "Rejected because"]
← DO NOT fabricate rejection rationale - we don't know why it wasn't chosen

### Confidence Level
[HIGH/MEDIUM/LOW] - [Explanation of confidence in inference]
```

3. **PDR Categories to Generate** (apply surprise-value heuristic):

   **Skip if obvious** (heuristic: surprising):
   - Standard user registration → Covered by product defaults
   - Basic CRUD features → Standard expectation
   - Email notifications → Conventional feature

   **Document as PDRs**:
   - **PDR-001**: Target Market (B2B vs B2C vs Market)
   - **PDR-002**: Primary Persona (user segment)
   - **PDR-003**: Monetization Model (how product makes money)
   - **PDR-004**: Pricing Strategy (tiers, positioning)
   - **PDR-005**: Core Problem (what problem solved)
   - **PDR-006**: Success Metrics (how success measured)
   - **Additional**: Any non-standard product decisions

4. **Sub-System Organization** (if Phase 0 decomposition enabled):

    Structure PDRs by sub-system in the output file:

   ```markdown
   # Product Decision Records

   ## PDR Index

   | ID | Feature Area | Decision | Status | Date | Confidence |
   |----|--------------|----------|--------|------|------------|
   | PDR-001 | System | B2B SaaS Model | Discovered | 2026-03-09 | HIGH |
   | PDR-002 | Auth | Enterprise SSO | Discovered | 2026-03-09 | HIGH |
   | PDR-003 | Business | Subscription Pricing | Discovered | 2026-03-09 | MEDIUM |

   ---

   ## System-Level PDRs

   ### PDR-001: B2B SaaS Model
   [Full PDR content...]

   ---

   ## Auth Feature Area PDRs

   ### PDR-002: Enterprise SSO
   [Full PDR content...]

   ---

   ## Business Feature Area PDRs

   ### PDR-003: Subscription Pricing
   [Full PDR content...]
   ```

   - Mark each PDR with its parent feature area in the index
   - Add section headers for each feature area
   - Document cross-cutting patterns (e.g., unified pricing) as System-Level

### Phase 5: Gap Analysis

**Objective**: Identify areas where decisions are unclear

After scanning, report:

```markdown
## Product Discovery Report

### Signals Detected
| Category | Finding | Confidence | Evidence |
|----------|---------|------------|----------|
| Problem | Supply chain visibility | HIGH | README section |
| Model | B2B SaaS | HIGH | Enterprise pricing |
| Persona | Enterprise ops teams | MEDIUM | Target market copy |
| Metrics | Time-to-value | LOW | Not documented |

### Documentation Deduplication
✓ README.md: Problem documented (lines 10-20)
  → Referenced in Problem PDR, skipping duplication
✓ PRICING.md: Monetization documented
  → Referenced in Business Model PDR

### PDRs Generated (Surprising/Risky decisions only)
| ID | Decision | Confidence | Why Documented |
|----|----------|------------|----------------|
| PDR-001 | B2B target market | HIGH | Strategic choice |
| PDR-002 | Enterprise pricing | HIGH | Revenue model |
| PDR-003 | Self-serve onboarding | MEDIUM | UX differentiator |

### Skipped (Covered by existing docs or obvious)
| Decision | Reason |
|----------|--------|
| User authentication | Covered by README |
| Mobile responsive | Standard expectation |

### Unclear Areas (Need Human Input)
| Area | Question | Suggestion |
|------|----------|------------|
| Success metrics | How is success measured? | Need stakeholder input |
| Competitive position | What makes us different? | Need market research |
| Pricing elasticity | How price-sensitive? | Need customer data |

### Recommended Clarifications
1. Run `/product.clarify` to refine PDRs with human input
2. Focus on [specific unclear area]
3. Consider documenting [undocumented pattern]
```

### Phase 6: Output Generation

**Objective**: Write discovered PDRs to file (NO PRD.md creation)

1. **Write PDRs**:
   - Create or update `{REPO_ROOT}/.specify/drafts/pdr.md` with discovered PDRs
   - Mark PDRs as "Discovered (Inferred)" status ← USE THIS STATUS
   - Use "Common Alternatives" section with neutral trade-offs (no "Rejected because")
   - Note confidence level for each
   - Tag assumptions that need validation

2. **DO NOT Create PRD.md**:
   - Product Requirements Document will be generated later via `/product.implement`
   - Only AFTER PDRs are validated through clarification

3. **Generate Summary**:
   - Product signals discovered
   - PDRs created with confidence levels
   - Gaps identified
   - Assumptions made (to be validated in clarify phase)

### Phase 7: Auto-Handoff to Clarify

**Objective**: Validate brownfield findings with user

After generating PDRs, **automatically trigger `/product.clarify`** with brownfield context:

**Questions Clarify Should Ask** (Brownfield-Specific):

| Question Type | Example |
|---------------|---------|
| **Current State Validity** | "I detected B2B SaaS model - is this still your current approach?" |
| **Decision Rationale** | "Enterprise SSO is used - was this chosen for specific requirements?" |
| **Monetization** | "Subscription model detected - any plans for usage-based pricing?" |
| **Success Metrics** | "No success metrics found - how do you measure product success?" |
| **Roadmap Plans** | "Feature area X seems underdeveloped - planned for future?" |

**Context Passed to Clarify**:

```json
{
  "source": "brownfield",
  "product_signals_detected": ["detected signals"],
  "inferred_decisions": ["list of PDRs with confidence levels"],
  "assumptions": ["things that need validation"],
  "artifacts_analyzed": "count"
}
```

The clarify phase will refine PDRs based on your input, then you can run `/product.implement` to generate the full PRD.

## Key Rules

### Evidence-Based Documentation

- **Only document what's found** - don't invent decisions
- **Cite specific evidence** for each PDR
- **Mark confidence levels** honestly
- **Flag uncertainties** explicitly

### Confidence Levels

| Level | Criteria |
|-------|----------|
| **HIGH** | Multiple clear evidence sources, unambiguous choice |
| **MEDIUM** | Some evidence, but could be interpreted differently |
| **LOW** | Limited evidence, significant uncertainty |

### Non-Destructive

- **Don't overwrite** existing PDRs without user approval
- **Merge intelligently** with existing documentation
- **Preserve manual additions** to product files

### No Fabricated Rejection Rationale

- **NEVER invent "Rejected because" reasons** for reverse-engineered PDRs
- Use "Common Alternatives" with neutral "Trade-offs" framing instead
- Only document alternatives that were likely considered
- Be honest: "We don't know why X wasn't chosen" is acceptable

### Interactive When Needed

- For **LOW confidence** discoveries, ask user for confirmation
- For **contradictory evidence**, present options
- For **gaps**, suggest clarification questions

### Sub-System Decomposition

- **Auto-detect from structure**: Analyze directories, docs automatically
- **Interactive confirmation**: Always confirm sub-system breakdown with user
- **Balanced granularity**: Aim for 3-7 areas; avoid over-decomposition
- **Clear evidence**: Cite specific files as evidence for each area
- **Per-area analysis**: Run signal detection per area for focused PDRs
- **Cross-cutting patterns**: Detect and document system-wide patterns separately
- **Use --no-decompose**: Skip decomposition for simple/small products

## Workflow Guidance & Transitions

### After `/product.init`

**Auto-triggered**: `/product.clarify` runs immediately to validate findings.

After clarification completes:

1. **Review Validated PDRs**: Check `{REPO_ROOT}/.specify/drafts/pdr.md` for accuracy
2. **Run `/product.implement`**: Generate full PRD from validated PDRs
3. **Update As Needed**: Refine documentation as you learn more

### Complete Brownfield Flow

```text
/product.init "B2B SaaS, team of 5"
    ↓
[Scan codebase + docs] → Detect signals, patterns
    ↓
[Generate PDRs] → Write to {REPO_ROOT}/.specify/drafts/pdr.md (marked "Discovered")
    ↓
[Auto-trigger /product.clarify]
    ↓
[Clarify asks] → "Is B2B model still valid?"
                 "How do you measure success?"
    ↓
[Update PDRs] → Refined with your validation
    ↓
[User runs /product.implement]
    ↓
[Generate PRD] → Full product requirements document
```

### When to Use This Command

- **Existing products**: Without formal product documentation
- **Product refresh**: Understanding current state before major changes
- **Team onboarding**: Quickly documenting implicit product decisions
- **Acquisition/integration**: Understanding acquired product strategy

### When NOT to Use This Command

- **Greenfield products**: Use `/product.specify` for new products
- **PRD exists**: If `PRD.md` exists, use `/product.clarify` to refine
- **Feature-level**: Feature product decisions via `/spec.specify`

## Context

$ARGUMENTS