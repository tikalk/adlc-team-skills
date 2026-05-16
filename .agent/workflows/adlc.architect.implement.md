---
description: Generate full Architecture Description (AD.md) from ADRs using Rozanski
  & Woods methodology
scripts:
  sh: .specify/extensions/architect/scripts/bash/setup-architect.sh "implement {ARGS}"
  ps: .specify/extensions/architect/scripts/powershell/setup-architect.ps1 "implement
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

- `"Focus on deployment and operational views - we need infrastructure docs"`
- `"Generate all views with emphasis on security perspective"`
- `"Update existing AD.md with new ADRs from recent decisions"`
- Empty input: Generate complete Architecture Description from all ADRs

### Flags

- `--views VIEWS`: Architecture views to generate
  - `core` (default): Context, Functional, Information, Development, Deployment (5 core views)
  - `all`: All 7 views including Concurrency and Operational
  - Custom: comma-separated (e.g., `concurrency,operational`) - always includes core views

**Important**: When `--views` is `core` (default), **skip** Concurrency View (3.4) and Operational View (3.7) entirely. Only generate them when explicitly requested via `--views all` or `--views concurrency,operational`.

## Goal

Transform Architecture Decision Records (ADRs) into a comprehensive Architecture Description (AD.md) following the Rozanski & Woods methodology with 7 viewpoints and 2 perspectives.

**Key Insight**: ADRs capture **why** decisions were made; the Architecture Description captures **what** the system looks like as a result of those decisions.

## Role & Context

You are acting as a **Technical Writer** synthesizing ADRs into comprehensive architecture documentation. Your role involves:

- **Translating** individual ADRs into cohesive viewpoints
- **Generating** diagrams for each architectural view
- **Ensuring** consistency between ADRs and generated views
- **Producing** stakeholder-appropriate documentation

### Architecture Document Hierarchy

| Document | Purpose | Location |
|----------|---------|----------|
| `.specify/memory/adr.md` | Architectural decisions with rationale | Input |
| `AD.md` (root) | Full Architecture Description | Output |
| `.specify/memory/constitution.md` | Governance principles | Constraint |

## Outline

1. **Load ADRs**: Parse all ADRs from `.specify/memory/adr.md`
2. **Determine Views**: Parse `--views` flag to determine which views to generate
3. **Generate Views**: Create requested viewpoints (core 5 by default, optionally +2)
4. **Apply Perspectives**: Add Security and Performance perspectives
5. **Output**: Write complete `AD.md` to project root

## Execution Steps

### Phase 1: ADR Loading

**Objective**: Load and analyze existing ADRs

1. **Run Setup Script**:
   - Execute `{SCRIPT}` to prepare architecture files
   - Creates `AD.md` from template if it doesn't exist

2. **Load ADRs**:
   - Read `.specify/memory/adr.md`
   - Parse each ADR: ID, title, context, decision, consequences
   - Build decision index

3. **Load Constitution**:
   - Read `.specify/memory/constitution.md` for constraint validation
   - Extract principles that affect architecture documentation

4. **ADR-to-View Mapping**:

   | ADR Topic | Primary View | Secondary Views |
   |-----------|--------------|-----------------|
   | System Architecture Style | Functional | Context, Deployment |
   | Database Choice | Information | Deployment, Operational |
   | API Style | Functional | Context, Development |
   | Authentication | Security Perspective | Functional |
   | Deployment Platform | Deployment | Operational |
   | CI/CD Approach | Development | Operational |
   | Scaling Strategy | Performance Perspective | Concurrency, Deployment |
   | Caching Strategy | Performance Perspective | Information, Concurrency |

### Phase 2: View Generation

**Objective**: Generate each Rozanski & Woods viewpoint from ADR content

**View Selection Based on `--views` Flag**:

| Flag Value | Views to Generate |
|------------|-------------------|
| `core` (default) | Context, Functional, Information, Development, Deployment |
| `all` | All 7 views (core + Concurrency + Operational) |
| `concurrency` | Core 5 + Concurrency |
| `operational` | Core 5 + Operational |
| `concurrency,operational` | All 7 views |

**Conditional Generation Rules**:

- **Always generate**: Context (3.1), Functional (3.2), Information (3.3), Development (3.5), Deployment (3.6)
- **Only if requested**: Concurrency (3.4), Operational (3.7)
- **Skip entirely** (not just mark as placeholder): Optional views not included in `--views`

Generate views in this order (earlier views inform later ones):

#### 3.1 Context View

**Purpose**: System scope and external interactions

**ADRs to Reference**: System style, integration patterns, external dependencies

> **CRITICAL: Blackbox Requirement**
>
> The Context View MUST show the system as a **single blackbox node**. This view answers: "What does the system connect to?" NOT "What's inside the system?"
>
> **DO include**:
>
> - The system as ONE unified node (no internal components)
> - Stakeholders/Users (human actors)
> - External systems (third-party services outside your control)
> - Data flows crossing the system boundary
>
> **DO NOT include**:
>
> - Internal databases (those go in Deployment View)
> - Internal services/microservices (those go in Functional View)
> - Internal caches, queues, or storage (those go in Deployment View)
> - Implementation details of any kind

**Generate**:

- System scope description (from system style ADR)
- External entities table - ONLY stakeholders and external systems
- Context diagram showing system as single blackbox
- External dependencies table (from dependency ADRs)

**Diagram Template**:

```mermaid
graph TD
    %% Stakeholders (human actors interacting with the system)
    Users["Users/Clients"]
    Admins["Administrators"]
    
    %% THE SYSTEM - Single blackbox (NO internal components)
    System["[System Name]<br/>(This System)"]
    
    %% External Systems (third-party, outside your control)
    ExtPayment["Payment Provider<br/>(External)"]
    ExtAuth["Identity Provider<br/>(External)"]
    ExtAPI["Partner API<br/>(External)"]
    
    %% Stakeholder interactions
    Users -->|"Uses"| System
    Admins -->|"Manages"| System
    
    %% External system integrations
    System -->|"Processes payments"| ExtPayment
    System -->|"Authenticates"| ExtAuth
    System -->|"Exchanges data"| ExtAPI
    
    %% Styling
    classDef systemNode fill:#f47721,stroke:#333,stroke-width:3px,color:#fff
    classDef stakeholderNode fill:#4a9eff,stroke:#333,stroke-width:1px,color:#fff
    classDef externalNode fill:#e0e0e0,stroke:#333,stroke-width:1px
    
    class System systemNode
    class Users,Admins stakeholderNode
    class ExtPayment,ExtAuth,ExtAPI externalNode
```

**Validation Checklist** (verify before finalizing Context View):

- [ ] System appears as exactly ONE node
- [ ] No internal databases shown (e.g., PostgreSQL, Redis)
- [ ] No internal services shown (e.g., AuthService, UserService)
- [ ] All entities are either stakeholders OR external systems
- [ ] All connections cross the system boundary

#### 3.2 Functional View

**Purpose**: Internal components, responsibilities, interactions

**ADRs to Reference**: System style, API style, component organization

**Generate**:

- Functional elements table (from architecture style ADR)
- Element interactions diagram
- Functional boundaries (from scope decisions)

**Diagram Template**:

```mermaid
graph TD
    subgraph "Application Layer"
        API["API Gateway"]
        Auth["Auth Service"]
    end
    
    subgraph "Business Layer"
        BL["Business Logic"]
    end
    
    subgraph "Data Layer"
        DA["Data Access"]
    end
    
    API --> Auth
    API --> BL
    BL --> DA
```

#### 3.3 Information View

**Purpose**: Data storage, management, and flow

**ADRs to Reference**: Database choice, data patterns, caching

**Generate**:

- Data entities table (from database ADRs)
- Data flow description
- Data quality/integrity requirements

**Diagram Template**:

```mermaid
erDiagram
    ENTITY1 ||--o{ ENTITY2 : "relationship"
    ENTITY2 }|--|| ENTITY3 : "relationship"
```

#### 3.4 Concurrency View (OPTIONAL - only if `--views all` or `--views concurrency`)

> **Skip this section entirely if `--views` is `core` (default)**

**Purpose**: Runtime processes, threads, coordination

**ADRs to Reference**: Scaling, async patterns, messaging

**Generate**:

- Process structure table
- Thread/async model description
- Coordination mechanisms

**Diagram Template**:

```mermaid
sequenceDiagram
    participant P1 as Process 1
    participant Q as Message Queue
    participant P2 as Process 2
    
    P1->>Q: Publish event
    Q-->>P2: Deliver event
    P2->>P2: Process
```

#### 3.5 Development View

**Purpose**: Code organization, dependencies, CI/CD

**ADRs to Reference**: CI/CD, development standards, framework choices

**Generate**:

- Code organization structure (directory tree)
- Module dependencies description
- Build & CI/CD pipeline description
- Development standards summary

#### 3.6 Deployment View

**Purpose**: Physical environment, nodes, networks

**ADRs to Reference**: Deployment platform, infrastructure, scaling

**Generate**:

- Runtime environments table
- Network topology diagram
- Hardware requirements table
- Third-party services table

**Diagram Template**:

```mermaid
graph TB
    subgraph "Production Environment"
        LB["Load Balancer"]
        subgraph "App Tier"
            App1["App 1"]
            App2["App 2"]
        end
        subgraph "Data Tier"
            DB["Database"]
            Cache["Cache"]
        end
    end
    
    Internet --> LB
    LB --> App1
    LB --> App2
    App1 --> DB
    App2 --> DB
    App1 --> Cache
    App2 --> Cache
```

#### 3.7 Operational View (OPTIONAL - only if `--views all` or `--views operational`)

> **Skip this section entirely if `--views` is `core` (default)**

**Purpose**: Operations, support, maintenance

**ADRs to Reference**: Monitoring, observability, support model

**Generate**:

- Operational responsibilities table
- Monitoring & alerting description
- Disaster recovery parameters
- Support model tiers

### Phase 3: Perspective Application

**Objective**: Add cross-cutting concerns

#### 4.1 Security Perspective

**ADRs to Reference**: Authentication, authorization, encryption, compliance

**Generate**:

- Authentication & authorization approach
- Data protection measures
- Threat model table (threats, mitigations)

#### 4.2 Performance & Scalability Perspective

**ADRs to Reference**: Scaling, caching, performance targets

**Generate**:

- Performance requirements table
- Scalability model description
- Capacity planning notes

### Phase 4: Global Sections

**Objective**: Complete cross-cutting sections

1. **Global Constraints & Principles**:
   - Extract from constitution and constraint ADRs
   - Document technical constraints
   - Document architectural principles

2. **ADR Summary**:
   - Create summary table linking to `.specify/memory/adr.md`
   - List key decisions with impact levels

3. **Tech Stack Summary**:
   - Synthesize from all technology ADRs
   - Languages, frameworks, databases, infrastructure

### Phase 5: Output Generation

**Objective**: Write complete Architecture Description

1. **Structure Check**:
   - Ensure all **requested** viewpoints are present (5 core, or 7 if `--views all`)
   - Ensure both perspectives are present
   - Validate diagram syntax

2. **Write AD.md**:
   - Use `templates/AD-template.md` as base
   - Replace placeholders with generated content
   - Write to project root as `AD.md`

3. **Update References**:
   - Ensure `.specify/memory/adr.md` link is correct
   - Update version and timestamp

4. **Generate Report**:

```markdown
## Architecture Description Generated

**Output**: AD.md (project root)
**Views Mode**: [core|all|custom]

**Views Generated** (based on --views flag):
- [x] Context View (based on ADR-001, ADR-003)
- [x] Functional View (based on ADR-001, ADR-002)
- [x] Information View (based on ADR-002)
- [x] Concurrency View (based on ADR-004) ← Only if --views includes concurrency
- [x] Development View (based on ADR-005)
- [x] Deployment View (based on ADR-006)
- [x] Operational View (based on ADR-007) ← Only if --views includes operational

**Perspectives Applied**:
- [x] Security (based on ADR-008)
- [x] Performance & Scalability (based on ADR-004, ADR-006)

**Diagrams Generated**: [5|6|7] (Mermaid format)

**ADR Coverage**: X/Y ADRs incorporated

**Recommended Next Steps**:
1. Review generated AD.md for accuracy
2. Run `/spec.analyze` for consistency validation
3. Share with stakeholders for review
4. Begin feature development with `/spec.specify`
```

**Example Report for `--views core` (default)**:

```markdown
## Architecture Description Generated

**Output**: AD.md (project root)
**Views Mode**: core (default)

**Views Generated**:
- [x] Context View
- [x] Functional View
- [x] Information View
- [x] Development View
- [x] Deployment View
- [ ] Concurrency View (skipped - use --views all to include)
- [ ] Operational View (skipped - use --views all to include)
```

## Diagram Generation

### Diagram Format

Diagrams are generated based on global configuration:

```json
{
  "architecture": {
    "diagram_format": "mermaid"  // or "ascii"
  }
}
```

Configuration location: `~/.config/specify/config.json`

### Diagram Types Per View

| View | Diagram Type | Mermaid Syntax |
|------|--------------|----------------|
| Context | System boundary | `graph TD` |
| Functional | Component diagram | `graph TD` |
| Information | ER diagram | `erDiagram` |
| Concurrency | Sequence diagram | `sequenceDiagram` |
| Development | Dependency graph | `graph LR` |
| Deployment | Infrastructure | `graph TB` |
| Operational | Flowchart | `flowchart TD` |

### ASCII Fallback

If Mermaid validation fails, fall back to ASCII diagrams:

```text
┌──────────────┐
│   Component  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Component  │
└──────────────┘
```

## Key Rules

### ADR Traceability

- **Every view section** should reference source ADRs
- **No content** without ADR backing (except templates)
- **Flag gaps** where ADRs are missing

### Consistency

- **Terminology** must match across views
- **Components** named consistently in all diagrams
- **Technology names** exactly as stated in ADRs

### Completeness

- **All requested viewpoints** must be generated (5 core by default, 7 if `--views all`)
- **Both perspectives** must be applied
- **All sections** must have content (not just placeholders)
- **Optional views** (Concurrency, Operational) are **skipped entirely** when not requested - do not include empty placeholders

### Diagram Quality

- **Validate** Mermaid syntax before writing
- **Fall back** to ASCII if Mermaid fails
- **Keep diagrams** simple and readable

## Workflow Guidance & Transitions

### After `/architect.implement`

Recommended next steps:

1. **Review AD.md**: Verify architecture documentation is accurate
2. **Run `/spec.analyze`**: Validate consistency and completeness
3. **Share for Review**: Get stakeholder feedback
4. **Start Features**: Use `/spec.specify` to create feature specs

### When to Use This Command

- **After `/architect.specify`**: Generate AD from discussed ADRs
- **After `/architect.init`**: Document brownfield architecture
- **ADR Updates**: Regenerate AD.md after new decisions
- **Documentation Sprint**: Create comprehensive architecture docs

### When NOT to Use This Command

- **No ADRs exist**: Use `/architect.specify` or `/architect.init` first
- **Feature-level**: Feature AD generated via `/spec.plan --architecture`
- **Minor updates**: Use direct editing for small changes

## Context

{ARGS}