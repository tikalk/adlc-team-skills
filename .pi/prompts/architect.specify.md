---
description: Interactive PRD exploration and system-level ADR creation (greenfield)
handoffs:
- label: Validate ADRs
  agent: architect.clarify
  prompt: Validate architecture decisions - confirm selections for system architecture,
    database, API style, and deployment
  send: true
scripts:
  sh: .specify/extensions/architect/scripts/bash/setup-architect.sh "specify {ARGS}"
  ps: .specify/extensions/architect/scripts/powershell/setup-architect.ps1 "specify
    {ARGS}"
agent_scripts:
  sh: scripts/bash/update-agent-context.sh __AGENT__
  ps: scripts/powershell/update-agent-context.ps1 -AgentType __AGENT__
---


<!-- Extension: architect -->
<!-- Config: .specify/extensions/architect/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"B2B SaaS platform for supply chain management with real-time inventory tracking"`
- `"Mobile-first e-commerce app with offline support and social features"`
- `"Legacy system modernization: migrate from monolith to microservices"`
- `"IoT platform for smart home devices with edge computing requirements"`

When users provide PRD context like this, use it to drive the architectural exploration conversation.

## Goal

Transform a PRD (Product Requirements Document) or high-level system description into well-documented Architecture Decision Records (ADRs) through interactive exploration and trade-off analysis.

**Key Insight**: Unlike direct architecture generation, this command prioritizes **discussion and exploration** before committing to formal documentation. The goal is to surface trade-offs, validate assumptions, and make informed decisions collaboratively.

### Flags

- `--views VIEWS`: Architecture views to include in final AD.md
  - `core` (default): Context, Functional, Information, Development, Deployment
  - `all`: All 7 views including Concurrency and Operational
  - Custom: comma-separated (e.g., `concurrency,operational`)

- `--adr-heuristic HEURISTIC`: ADR generation strategy
  - `surprising` (default): Skip obvious ecosystem defaults
  - `all`: Document all decisions discussed
  - `minimal`: Only high-risk/unconventional decisions

- `--no-decompose`: Disable automatic sub-system decomposition (default: auto-decompose if multiple domains detected)

## Role & Context

You are acting as a **Solutions Architect** facilitating an architectural discovery session. Your role involves:

- **Exploring** possible solutions and their trade-offs
- **Asking** clarifying questions to surface hidden requirements
- **Proposing** options with clear consequences
- **Documenting** decisions in MADR format once consensus is reached

### Rozanski & Woods Alignment

When creating ADRs, consider how they map to R&W viewpoints:

| ADR Topic | Primary Viewpoint | Impact on Other Views |
|-----------|-------------------|----------------------|
| Architecture Style | **Functional** (cornerstone) | Shapes all other views |
| Database Choice | Information | Affects Functional, Deployment |
| API Style | Functional | Affects Information, Development |
| Auth Mechanism | Functional | Affects all views (security perspective) |
| Deployment Platform | Deployment | Affects Development, Operational |
| Communication Pattern | Functional, Concurrency | Affects Information, Deployment |

**Functional-as-Cornerstone Principle**:
> "The Functional view is the cornerstone of most ADs... It usually drives the shape of other system structures." — Rozanski & Woods

During exploration, prioritize decisions that affect the Functional view:
1. System architecture style (monolith/microservices/serverless)
2. Component responsibilities and boundaries
3. Interface contracts between components
4. Integration patterns

These decisions drive all subsequent architectural views.

### Two-Level Architecture System

| Level | Location | ADR File | Architecture Description |
|-------|----------|----------|--------------------------|
| **System** | Main branch | `{REPO_ROOT}/.specify/drafts/adr.md` | `{REPO_ROOT}/AD.md` |

This command operates at the **System level**, creating ADRs in `{REPO_ROOT}/.specify/drafts/adr.md`.

**IMPORTANT - Path Resolution**:

- The setup script outputs `REPO_ROOT` - use this to determine the correct paths
- REPO_ROOT is found by searching upward from current directory for `.specify` directory
- NEVER use relative paths like `.specify/drafts/adr.md` - always use `{REPO_ROOT}/.specify/drafts/adr.md`
- When running from a subdirectory (e.g., `hermes-project/`), `.specify` may be in the parent directory

## Outline

Given the PRD input, execute this workflow:

1. **Sub-System Detection** (Phase 0): Decompose PRD into sub-systems (auto-detect if multiple domains)
2. **Parse PRD Context**: Extract key requirements, constraints, and quality attributes (per sub-system if decomposed)
3. **Load Governance**: Check `{REPO_ROOT}/.specify/memory/constitution.md` for architectural constraints
4. **Exploration Phase**: Interactive discussion to surface trade-offs and options (per sub-system)
5. **Decision Phase**: Document decisions as ADRs with full rationale (organized by sub-system)
6. **Output**: Write ADRs to `{REPO_ROOT}/.specify/drafts/adr.md` with sub-system organization

**NOTE:** This is an interactive command. You will engage the user in conversation before finalizing ADRs.

## Execution Steps

### Phase 0: Sub-System Detection (Greenfield)

**Objective**: Decompose large PRD into manageable sub-systems automatically

**When**: This phase runs automatically when the PRD is detected as having multiple distinct domains. Use `--no-decompose` to skip.

#### Step 1: Domain Analysis

Analyze the PRD for distinct business domains and functional areas:

| Domain Category | Typical Keywords |
|-----------------|------------------|
| Authentication | login, auth, oauth, sso, permissions, roles, access control |
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

Identify boundaries between sub-systems based on:

1. **Data Ownership**: What data belongs to which domain?
2. **Team Boundaries**: Are different teams responsible for different areas?
3. **Deployment Independence**: Can sub-systems be deployed separately?
4. **Integration Points**: How do sub-systems communicate?

#### Step 3: Sub-System Proposal (Interactive)

Present detected sub-systems to user for confirmation:

```markdown
## Detected Sub-Systems

I've identified the following sub-systems from your PRD:

| # | Sub-System | Key Domains | Rationale |
|---|------------|-------------|-----------|
| 1 | **Auth** | Authentication, Authorization | Core security boundary |
| 2 | **Users** | User Management, Profiles | User data ownership |
| 3 | **Payments** | Billing, Subscriptions | Financial domain |
| 4 | **Inventory** | Products, Stock | Physical goods management |

### Questions for Confirmation:

1. **Are these sub-systems correct?** [Y/n]
2. **Should any sub-systems be merged?** (e.g., Auth + Users)
3. **Should any sub-systems be split?** (e.g., Payments into Billing + Subscriptions)
4. **Any missing sub-systems?** (e.g., Analytics, Search)

**Reply** with:
- `Y` to confirm and proceed
- `n` to disable decomposition (generate monolithic ADRs)
- Specific changes (e.g., "merge 1+2", "split 3", "add Notifications")
```

#### Step 4: Decomposition Decision

Based on user response:

| Response | Action |
|----------|--------|
| `Y` / Enter | Proceed with detected sub-systems |
| `n` | Skip decomposition, generate monolithic ADRs |
| Modifications | Adjust sub-systems, then proceed |
| Empty/Default | Auto-proceed if ≤3 sub-systems, ask if >3 |

**Threshold Logic**:

- **≤3 sub-systems**: Auto-approve, show summary
- **4-6 sub-systems**: Show summary, ask to confirm
- **>6 sub-systems**: Show summary, suggest grouping, ask to confirm

#### Step 5: Output

After confirmation, output structured sub-system data:

```json
{
  "decomposition": "enabled",
  "subsystems": [
    {"id": "auth", "name": "Auth", "domains": ["Authentication", "Authorization"], "rationale": "Security boundary"},
    {"id": "users", "name": "Users", "domains": ["User Management", "Profiles"], "rationale": "User data ownership"},
    {"id": "payments", "name": "Payments", "domains": ["Billing", "Subscriptions"], "rationale": "Financial domain"}
  ],
  "next_phase": "PRD Analysis (per sub-system)"
}
```

**If decomposition disabled**:

```json
{
  "decomposition": "disabled",
  "reason": "user_requested",
  "next_phase": "PRD Analysis (monolithic)"
}
```

---

### Phase 1: PRD Analysis

**Objective**: Extract architectural drivers from the PRD

**Note**: If sub-system decomposition is enabled (Phase 0), repeat this analysis **per sub-system** to ensure focused, manageable ADRs.

1. **Identify Functional Drivers**:
   - Core capabilities the system must provide
   - Key user interactions and workflows
   - Integration requirements with external systems
   - **For sub-systems**: Focus on the specific sub-system's responsibilities

2. **Identify Quality Attribute Drivers**:
   - Performance requirements (latency, throughput)
   - Scalability expectations (users, data volume)
   - Availability/reliability targets
   - Security and compliance constraints
   - Maintainability and extensibility needs

3. **Identify Constraints**:
   - Technology mandates or prohibitions
   - Budget and timeline constraints
   - Team skills and organizational factors
   - Regulatory or compliance requirements

4. **Load Constitution**:
   - Read `{REPO_ROOT}/.specify/memory/constitution.md` if it exists
   - Extract architectural principles that must be honored
   - Note any constraints that limit architectural choices

5. **Check Existing Documentation**:
   - Scan `README.md` for already-documented tech stack
   - Check `AGENTS.md` for project context
   - Check team directives: Run `.specify/extensions/architect/scripts/bash/setup-architect.sh "specify $ARGUMENTS"` and look for `TEAM_AGENTS_MD` in output - if present, this file contains usage instructions for team-wide agent directives
   - Review `CONTRIBUTING.md` for dev guidelines
   - Note: Don't duplicate - reference existing docs

**Output**: Internal summary of architectural drivers (do not write to file yet)

**If decomposed**: Generate separate analysis for each sub-system, noting cross-sub-system dependencies

### Phase 2: Architectural Exploration (Interactive)

**Objective**: Explore solution options through guided discussion

For each major architectural decision area, present options and facilitate discussion:

#### Decision Areas to Explore

1. **System Architecture Style**
   - Monolith vs Microservices vs Modular Monolith
   - Event-driven vs Request-response
   - Serverless vs Traditional hosting

2. **Data Architecture**
   - Database selection (SQL vs NoSQL vs Hybrid)
   - Data partitioning and scaling strategy
   - Caching approach
   - Event sourcing vs CRUD

3. **Integration Architecture**
   - API style (REST vs GraphQL vs gRPC)
   - Async messaging patterns
   - Third-party integration approach

4. **Security Architecture**
   - Authentication mechanism
   - Authorization model
   - Data protection strategy

5. **Deployment Architecture**
   - Cloud provider selection
   - Container orchestration
   - CI/CD approach

#### Exploration Format

For each decision area requiring user input, present:

```markdown
## Architectural Decision: [Decision Area]

**Context**: [Why this decision matters based on PRD]

**Options Being Considered**:

| Option | Description | Trade-offs |
|--------|-------------|------------|
| A | [Option A] | Pros: [benefits] / Cons: [drawbacks] |
| B | [Option B] | Pros: [benefits] / Cons: [drawbacks] |
| C | [Option C] | Pros: [benefits] / Cons: [drawbacks] |

**Recommended**: Option [X] - [Reasoning based on PRD requirements]

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
- Skip decisions that are **already determined** by PRD or constitution
- Limit to **5-7 key decisions** (defer less critical decisions)

### Phase 3: Decision Documentation

**Objective**: Convert exploration outcomes into formal ADRs

**Note**: If sub-system decomposition is enabled, organize ADRs **by sub-system** with clear section headers.

After each decision is confirmed:

1. **Create ADR Entry**:
   - Use MADR format from `.specify/templates/adr-template.md`
   - Document context, decision, consequences, and alternatives
   - Link to constitution principles if applicable
   - **Include Sub-System tag**: Mark each ADR with its parent sub-system

### Phase 3.5: Quality Requirements Exploration (Optional)

**Objective**: Identify which R&W perspectives apply to this system

Before completing ADRs, discuss quality requirements to help `/architect.implement`:

**Core (Always Recommended)**:
- Security - Authentication, authorization, data protection
- Performance - Response time, throughput, scalability

**Situational (Select Based on Requirements)**:

| Quality | Question | If Yes → Apply Perspective |
|---------|----------|---------------------------|
| Availability | Does the system need high uptime (>99%)? | Availability & Resilience |
| Evolution | Will the system need to change significantly over time? | Evolution |
| Regulation | Is the system subject to laws/regulations (GDPR, HIPAA)? | Regulation |
| Accessibility | Will users with disabilities use this system? | Accessibility |
| Internationalization | Will the system support multiple languages/regions? | Internationalization |
| Location | Are there geographic distribution concerns? | Location |
| Usability | Is ease of use a critical success factor? | Usability |
| Resources | Are there significant constraints on people/budget/time? | Development Resource |

**Present to user**:
```markdown
## Quality Requirements

Based on your PRD, which quality properties are important for this system?

### Core (Always Recommended)
- [x] Security
- [x] Performance

### Situational
- [ ] Availability (high uptime requirement)
- [ ] Evolution (long-lived system)
- [ ] Regulation (GDPR, HIPAA, etc.)
- [ ] Other: ___________

Please indicate which apply (e.g., "Availability, Regulation").
```

Store selected perspectives in ADR metadata for `/architect.implement`:
```markdown
<!-- Quality Requirements -->
<!-- perspectives: security, performance, availability, regulation -->
```

2. **Sub-System Organization**:

If decomposed, structure the ADR file as:

```markdown
# Architecture Decision Records

## ADR Index

| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|
| ADR-001 | System | Architecture Style | Proposed | 2026-02-26 | User/AI |
| ADR-002 | Auth | JWT Authentication | Proposed | 2026-02-26 | User/AI |
| ADR-003 | Payments | Stripe Integration | Proposed | 2026-02-26 | User/AI |

---

## System-Level ADRs

### ADR-001: [Decision Title]

[Full ADR content...]

---

## Auth Sub-System ADRs

### ADR-002: [Decision Title]

[Full ADR content...]

---

## Payments Sub-System ADRs

### ADR-003: [Decision Title]

[Full ADR content...]
```

3. **Cross-Cutting ADRs**: Some decisions affect multiple sub-systems (e.g., "Use PostgreSQL for all sub-systems"). Mark these as **System-Level** and note impact on each sub-system.

4. **ADR Format**:

```markdown
## ADR-[NNN]: [Decision Title]

### Status
Proposed

### Date
[YYYY-MM-DD]

### Owner
[User/AI collaboration]

### Context
[Problem statement and forces from exploration]

### Decision
[Clear statement of what was decided]

### Consequences

#### Positive
- [Benefit 1]
- [Benefit 2]

#### Negative
- [Trade-off 1]
- [Trade-off 2]

#### Risks
- [Risk 1 with mitigation]

### Common Alternatives

#### Option A: [Alternative Name]
**Description**: [Brief description]
**Trade-offs**: [Neutral comparison - when this would be better/worse, not "rejected because"]

#### Option B: [Alternative Name]
**Description**: [Brief description]
**Trade-offs**: [Neutral comparison]
```

3. **Number ADRs sequentially**: Start from ADR-001 for new projects, or continue from highest existing number

### Phase 4: ADR Output

**Objective**: Write finalized ADRs to file

1. **Run Setup Script**:
   - Execute `.specify/extensions/architect/scripts/bash/setup-architect.sh "specify $ARGUMENTS"` to ensure `{REPO_ROOT}/.specify/drafts/adr.md` exists
   - Script creates from template if file doesn't exist
   - Pass `--no-decompose` if decomposition was disabled

2. **Write ADRs**:
   - Append new ADRs to `{REPO_ROOT}/.specify/drafts/adr.md`
   - Update ADR index table at top of file (include Sub-System column)
   - Preserve any existing ADRs (don't overwrite)
   - **If decomposed**: Add section headers for each sub-system

3. **Report Summary**:
   - List of sub-systems identified
   - ADRs created per sub-system with IDs and titles
   - Constitution alignment status
   - Cross-cutting decisions noted
   - Recommended next steps

**Summary Format**:

```markdown
## Sub-System Decomposition Summary

### Sub-Systems Identified: 3

| # | Sub-System | ADRs Created |
|---|------------|--------------|
| 1 | System-Level | ADR-001: Architecture Style |
| 2 | Auth | ADR-002: JWT Authentication, ADR-003: OAuth2 Integration |
| 3 | Payments | ADR-004: Stripe Integration, ADR-005: Payment Webhooks |

### Cross-Cutting Decisions
- ADR-001 affects all sub-systems

### Next Steps
1. Review ADRs with /architect.clarify
2. Generate AD.md with /architect.implement
```

## Key Rules

### Exploration First

- **Do NOT generate architecture directly** from PRD
- **Engage in discussion** to validate assumptions
- **Surface trade-offs** before committing to decisions
- **Allow iteration** - user can revisit earlier decisions

### Constitution Compliance

- ADRs must **align with constitution** principles
- **Flag conflicts** between PRD requirements and constitution
- Constitution violations require explicit override with justification

### Incremental ADRs

- Create **focused ADRs** - one decision per ADR
- **Link related ADRs** when decisions interact
- **Defer decisions** that can be made later
- Mark **provisional decisions** that may need revision

### Quality Standards

- Every ADR must have **clear context** explaining why decision was needed
- **Consequences** must include both positive and negative outcomes
- **Alternatives** must explain why they were rejected
- Decisions must be **actionable** - clear enough to implement

### Sub-System Decomposition

- **Auto-detect domains**: Analyze PRD for distinct business domains automatically
- **Interactive confirmation**: Always confirm sub-system breakdown with user
- **Balanced granularity**: Aim for 3-7 sub-systems; avoid over-decomposition
- **Clear boundaries**: Each sub-system should have distinct responsibilities
- **Cross-cutting concerns**: Document system-level decisions separately
- **Per-sub-system exploration**: Run architectural exploration per sub-system for focused decisions
- **Use --no-decompose**: Skip decomposition for simple/small systems

## Workflow Guidance & Transitions

### After `/architect.specify`

Recommended next steps:

1. **Review ADRs**: Ensure all decisions are accurate and complete
2. **Run `/architect.clarify`**: Refine any ambiguous or incomplete ADRs
3. **Run `/architect.implement`**: Generate full Architecture Description from ADRs
4. **Proceed to features**: Use `/spec.specify` to create feature specs within this architecture

### When to Use This Command

- **New projects**: Starting system architecture from scratch
- **Major changes**: Significant architectural shifts requiring new decisions
- **Documentation**: Capturing verbal decisions as formal ADRs
- **Team onboarding**: Walking through architectural rationale with new members

### When NOT to Use This Command

- **Brownfield projects**: Use `/architect.init` instead to reverse-engineer from code
- **Minor updates**: Use `/architect.clarify` for ADR refinements
- **Feature-level**: Feature architecture via `before_plan` hook (when architect extension is installed and system ADRs exist)

## Context

$ARGUMENTS