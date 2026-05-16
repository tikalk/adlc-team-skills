---
description: Reverse-engineer architecture from existing codebase (brownfield) to
  create ADRs, then validate with clarifying questions
handoffs:
- label: Validate Architecture Findings
  agent: architect.clarify
  prompt: Validate brownfield architecture findings - confirm detected technologies,
    patterns, and decisions
  send: true
scripts:
  sh: .specify/extensions/architect/scripts/bash/setup-architect.sh "init {ARGS}"
  ps: .specify/extensions/architect/scripts/powershell/setup-architect.ps1 "init {ARGS}"
---


<!-- Extension: architect -->
<!-- Config: .specify/extensions/architect/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Django monolith with PostgreSQL, React frontend, AWS deployment"`
- `"Node.js microservices with MongoDB and RabbitMQ"`
- `"Legacy Java application, focus on understanding data layer"`
- Empty input: Scan entire codebase and infer architecture

When users provide context, use it to focus the reverse-engineering effort.

## Goal

Reverse-engineer architecture from an **existing codebase** (brownfield) to create ADRs documenting discovered decisions, then **validate the findings** by running clarify manually.

**Output**:

1. **ADRs** documenting inferred architectural decisions in `{REPO_ROOT}/.specify/drafts/adr.md`
2. **Validate Findings**: Run `/architect.clarify` to validate discovered decisions

**IMPORTANT - Path Resolution**:

- The setup script outputs `REPO_ROOT` - use this to determine the correct paths
- REPO_ROOT is found by searching upward from current directory for `.specify` directory
- NEVER use relative paths like `.specify/drafts/adr.md` - always use `{REPO_ROOT}/.specify/drafts/adr.md`
- When running from a subdirectory (e.g., `hermes-project/`), `.specify` may be in the parent directory

**Key Difference from `/architect.specify`**:

- `/architect.init` (this command) = **Discovers** what's already implemented in code
- `/architect.specify` = **Explores** new possibilities for greenfield projects

This command focuses on **current state analysis** - what IS, not what SHOULD BE.

### Flags

- `--adr-heuristic HEURISTIC`: ADR generation strategy
  - `surprising` (default): Skip obvious ecosystem defaults, document only surprising/risky decisions
  - `all`: Document all discovered decisions
  - `minimal`: Only high-risk decisions

- `--no-decompose`: Disable automatic sub-system detection from code structure (default: auto-detect if multiple modules detected)

## Role & Context

You are acting as an **Architecture Archaeologist** uncovering implicit architectural decisions from code. Your role involves:

- **Scanning** codebase for technology choices and patterns
- **Inferring** architectural decisions from code structure
- **Documenting** discovered patterns as ADRs
- **Identifying** gaps where decisions are unclear

### Brownfield vs Greenfield

| Scenario | Command | Input | Output |
|----------|---------|-------|--------|
| **Brownfield** (existing code) | `/architect.init` | Codebase scan | Inferred ADRs |
| **Greenfield** (new project) | `/architect.specify` | PRD/requirements | Discussed ADRs |

### Rozanski & Woods Alignment

When discovering ADRs from brownfield code, map findings to R&W viewpoints:

| Discovery Area | Primary Viewpoint | What to Look For |
|---------------|-------------------|------------------|
| Service structure | **Functional** | Component boundaries, responsibilities |
| Database schemas | Information | Data entities, relationships |
| Process/thread code | Concurrency | Runtime units, coordination |
| Directory structure | Development | Module organization, dependencies |
| Deployment configs | Deployment | Infrastructure, environments |
| Monitoring/alerting | Operational | Operations support |

**Functional-as-Cornerstone for Brownfield**:
Even in brownfield discovery, the **Functional structure is foundational**:

1. **Discover Functional first**: Identify components, services, modules
2. **Map other discoveries**: Relate data, deployment, operations to functional elements
3. **Document dependencies**: Note which ADRs affect the Functional view

**Priority order for ADR discovery**:
1. Architecture Style ADRs (monolith/microservices) → **Functional cornerstone**
2. Component/Service ADRs → Functional view
3. Database/Data ADRs → Information view
4. Infrastructure ADRs → Deployment view
5. Communication/Async ADRs → Concurrency view
6. Development/CI ADRs → Development view
7. Operations ADRs → Operational view

## Outline

1. **Sub-System Detection** (Phase 0): Identify sub-systems from code structure (auto-detect)
2. **Codebase Scan**: Analyze project structure and detect technologies (per sub-system if decomposed)
3. **Documentation Deduplication**: Scan existing docs (README, AGENTS.md, {TEAM_DIRECTIVES}/AGENTS.md if configured, etc.) to avoid repeating
4. **Pattern Detection**: Identify architectural patterns in use
5. **ADR Generation**: Create ADRs for discovered decisions (marked "Discovered"), organized by sub-system
6. **Gap Analysis**: Identify areas where decisions are unclear
7. **Output**: Write ADRs to `{REPO_ROOT}/.specify/drafts/adr.md` (NO AD.md creation)
8. **Validate Findings**: Run `/architect.clarify` to validate brownfield findings

## Execution Steps

### Phase 0: Sub-System Detection (Brownfield)

**Objective**: Identify sub-systems from existing code structure automatically

**When**: This phase runs automatically when the codebase is detected as having multiple distinct modules/packages. Use `--no-decompose` to skip.

#### Step 1: Directory Structure Analysis

Analyze the codebase for distinct sub-systems based on directory structure:

| Pattern | Likely Sub-System |
|---------|------------------|
| `src/auth/` | Authentication sub-system |
| `src/users/` | User management sub-system |
| `services/payment/` | Payment sub-system |
| `modules/inventory/` | Inventory sub-system |
| `apps/api/`, `apps/web/` | Monorepo with separate apps |
| `lib/core/`, `lib/shared/` | Shared libraries (not a sub-system) |

#### Step 2: Package/Module Detection

Detect sub-systems from package/module structures:

| Pattern | Detection Method | Sub-System Evidence |
|---------|------------------|-------------------|
| **Node.js workspaces** | package.json workspaces | Multiple packages = multiple sub-systems |
| **Python namespaces** | `__init__.py` hierarchy | Multiple top-level packages |
| **Go modules** | go.mod + directories | Multiple directories under cmd/ |
| **Maven/Gradle** | pom.xml modules | Multiple modules in multi-module project |
| **Docker services** | docker-compose services | Each service = sub-system |

#### Step 3: Database Schema Analysis

If database is accessible, detect sub-systems from schema:

| Pattern | Evidence |
|---------|----------|
| Table prefixes | `auth_`, `user_`, `payment_` tables = separate domains |
| PostgreSQL schemas | `auth.`, `payments.` schema separation |
| Separate databases | Multiple databases in docker-compose |

#### Step 4: Sub-System Proposal (Interactive)

Present detected sub-systems to user for confirmation:

```markdown
## Detected Sub-Systems

I've identified the following sub-systems from your codebase:

| # | Sub-System | Detection Method | Evidence |
|---|------------|-----------------|----------|
| 1 | **auth** | Directory + Module | src/auth/, auth/ package |
| 2 | **users** | Directory | src/users/, services/user/ |
| 3 | **payments** | Directory + Docker | services/payment/, payment service in docker-compose |
| 4 | **inventory** | Directory | src/inventory/, modules/stock/ |

### Questions for Confirmation:

1. **Are these sub-systems correct?** [Y/n]
2. **Should any sub-systems be merged?** (e.g., auth + users → identity)
3. **Should any sub-systems be split?** (e.g., payments → billing + subscriptions)
4. **Any missing sub-systems?** (e.g., analytics, reporting)

**Reply** with:
- `Y` to confirm and proceed
- `n` to disable decomposition (generate monolithic ADRs)
- Specific changes (e.g., "merge 1+2", "split 3", "add Notifications")
```

#### Step 5: Decomposition Decision

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

#### Step 6: Output

After confirmation, output structured sub-system data:

```json
{
  "decomposition": "enabled",
  "subsystems": [
    {"id": "auth", "name": "Auth", "detection_method": "directory", "evidence": "src/auth/"},
    {"id": "users", "name": "Users", "detection_method": "directory", "evidence": "src/users/"},
    {"id": "payments", "name": "Payments", "detection_method": "docker", "evidence": "payment service in docker-compose"}
  ],
  "next_phase": "Codebase Analysis (per sub-system)"
}
```

**If decomposition disabled**:

```json
{
  "decomposition": "disabled",
  "reason": "user_requested",
  "next_phase": "Codebase Analysis (monolithic)"
}
```

---

### Phase 1: Codebase Analysis

**Objective**: Discover what technologies and patterns are in use

**Note**: If sub-system decomposition is enabled (Phase 0), analyze each sub-system **separately** to provide focused insights.

1. **Run Setup Script**:
   - Execute `.specify/extensions/architect/scripts/bash/setup-architect.sh "init $ARGUMENTS"` to initialize architecture files
   - Script scans codebase and outputs structured findings
   - Pass `--no-decompose` if decomposition was disabled
   - **If decomposed**: Script outputs sub-system breakdown for targeted analysis

2. **Technology Detection (Per Sub-System)**:

   | Indicator | Technology Category | Files to Check |
   |-----------|---------------------|----------------|
   | `package.json` | Node.js ecosystem | Dependencies, scripts |
   | `requirements.txt` / `pyproject.toml` | Python ecosystem | Dependencies |
   | `pom.xml` / `build.gradle` | JVM ecosystem | Dependencies |
   | `Cargo.toml` | Rust | Dependencies |
   | `go.mod` | Go | Dependencies |
   | `Dockerfile` | Containerization | Base images, stages |
   | `docker-compose.yml` | Container orchestration | Services, networks |
   | `*.tf` / `*.tfvars` | Terraform/IaC | Infrastructure |
   | `kubernetes/*.yaml` | Kubernetes | Deployment configs |
   | `.github/workflows/*` | GitHub Actions | CI/CD |

3. **Framework Detection**:

   | Pattern | Framework | Evidence |
   |---------|-----------|----------|
   | `from django` imports | Django | Python web |
   | `@SpringBoot` | Spring Boot | Java web |
   | `import express` | Express.js | Node.js web |
   | `import { Component }` | React/Angular/Vue | Frontend |
   | `from fastapi` | FastAPI | Python API |

4. **Database Detection**:

   | Evidence | Database Type |
   |----------|---------------|
   | PostgreSQL connection strings | PostgreSQL |
   | MongoDB/mongoose imports | MongoDB |
   | Redis client imports | Redis cache |
   | ORM migrations | Relational DB |
   | DynamoDB SDK usage | AWS DynamoDB |

### Phase 2: Pattern Recognition

**Objective**: Identify architectural patterns from code structure

#### Architecture Style Detection

| Pattern | Evidence | ADR Topic |
|---------|----------|-----------|
| **Monolith** | Single deployable, shared database | ADR: System Architecture Style |
| **Microservices** | Multiple services, service discovery | ADR: System Architecture Style |
| **Modular Monolith** | Single deploy, module boundaries | ADR: System Architecture Style |
| **Event-Driven** | Message queue usage, event handlers | ADR: Communication Pattern |
| **Serverless** | Lambda functions, managed services | ADR: Deployment Model |

#### Code Organization Detection

| Pattern | Evidence |
|---------|----------|
| **Layered** | `controllers/`, `services/`, `repositories/` |
| **Feature-Based** | `features/`, `modules/` per domain |
| **Clean Architecture** | `domain/`, `application/`, `infrastructure/` |
| **Hexagonal** | `ports/`, `adapters/` |

#### API Style Detection

| Pattern | Evidence |
|---------|----------|
| **REST** | Route decorators, HTTP verbs, resource URLs |
| **GraphQL** | Schema files, resolvers, `gql` imports |
| **gRPC** | `.proto` files, gRPC client/server setup |
| **WebSocket** | Socket.io, WebSocket handlers |

### Phase 1.5: Documentation Deduplication

**Objective**: Scan existing docs to avoid repeating documented information

**Scan for**:

- `AGENTS.md` - Project context, overview
- `{TEAM_DIRECTIVES}/AGENTS.md` - Team-wide agent usage instructions (if configured)
- `README.md` - Tech stack, project description
- `CONTRIBUTING.md` - Development guidelines
- `AD.md` or `docs/architecture.md` - Existing architecture
- `LICENSE` - Legal context

**Deduplication Rules**:

| Finding | Action |
|---------|--------|
| Tech stack in README | Reference README in ADR, don't duplicate |
| Architecture exists | Auto-merge or offer update vs. create new |
| Guidelines in CONTRIBUTING | Reference in Development View |
| Context in AGENTS.md | Link from Context View |
| Team directives AGENTS.md | Reference for team-wide agent instructions |

**Process**:

1. Run `.specify/extensions/architect/scripts/bash/setup-architect.sh "init $ARGUMENTS"` which calls `scan_existing_docs()`
2. Parse findings from JSON output
3. For each finding, determine: Skip ADR / Reference existing / Document new
4. Report: "X decisions covered by existing docs, Y new ADRs created"

### Phase 2: Pattern Detection

**Objective**: Document discovered decisions as ADRs

For each discovered architectural decision:

1. **Identify the Decision**:
   - What technology/pattern was chosen?
   - What alternatives were available when this was built?
   - What forces likely drove this decision?

2. **Create ADR Entry**:

```markdown
## ADR-[NNN]: [Discovered Decision]

### Status
Discovered (Inferred from codebase)

### Date
[Current date]

### Owner
Legacy/Inferred

### Context
[Inferred problem statement based on code patterns]

**Evidence Found**:
- [File/pattern evidence 1]
- [File/pattern evidence 2]

### Decision
[Statement of what was decided, inferred from implementation]

### Consequences

#### Positive (Observed)
- [Benefit visible in codebase]

#### Negative (Potential)
- [Trade-off inherent to this choice]

#### Risks
- [Risk if this decision is not well understood]

### Common Alternatives
#### [Likely Alternative]
**Description**: [What it is]
**Trade-offs**: [Why it might have been considered, neutral assessment - NO "Rejected because"]
← DO NOT fabricate rejection rationale - we don't know why it wasn't chosen

### Confidence Level
[HIGH/MEDIUM/LOW] - [Explanation of confidence in inference]
```

3. **ADR Categories to Generate** (apply surprise-value heuristic):

   **Skip if obvious** (heuristic: surprising):
   - PostgreSQL for relational data → Covered by ecosystem default
   - React for SPA frontend → Standard framework choice
   - Docker for containerization → Conventional choice

   **Document as ADRs**:
   - **ADR-001**: System Architecture Style (monolith vs microservices)
   - **ADR-002**: Database Choice (only if non-obvious for context)
   - **ADR-003**: API Style (REST vs GraphQL vs gRPC)
   - **ADR-004**: Frontend Framework (only if unconventional)
   - **ADR-005**: Deployment Platform (serverless vs traditional)
   - **ADR-006**: CI/CD Approach (GitHub Actions vs Jenkins)
   - **Additional**: Any custom/in-house solutions, unusual patterns, risky choices

### Phase 1.5: Quality Requirements Detection

**Objective**: Detect which R&W perspectives apply from codebase evidence

Scan codebase for quality requirement indicators:

| Evidence | Detected Perspective |
|----------|---------------------|
| Health checks, circuit breakers, retry logic | Availability |
| Plugin systems, feature flags, extension points | Evolution |
| GDPR/HIPAA comments, audit logging, consent tracking | Regulation |
| ARIA attributes, screen reader support | Accessibility |
| i18n files, locale handling, translation keys | Internationalization |
| Multi-region configs, geo-routing, CDN setup | Location |
| Extensive UI tests, UX research artifacts | Usability |
| Resource constraints in README, limited CI runners | Development Resource |

**Present detected perspectives for confirmation**:
```markdown
## Quality Requirements Detected

Based on codebase analysis, the following quality perspectives may apply:

| Perspective | Evidence Found | Include? |
|-------------|----------------|----------|
| Security | Always recommended | ✓ (default) |
| Performance | Always recommended | ✓ (default) |
| Availability | Circuit breakers found | [Y/N] |
| Evolution | Feature flags found | [Y/N] |
| Regulation | GDPR comments found | [Y/N] |
| Accessibility | Not detected | [Y/N] |
| Internationalization | i18n files found | [Y/N] |
| Location | Multi-region config | [Y/N] |
| Usability | UI tests found | [Y/N] |
| Development Resource | Not detected | [Y/N] |

Please confirm which perspectives to document.
```

Store selected perspectives in state for `/architect.implement`.

4. **Sub-System Organization** (if Phase 0 decomposition enabled):

   Structure ADRs by sub-system in the output file:

   ```markdown
   # Architecture Decision Records

   ## ADR Index

   | ID | Sub-System | Decision | Status | Date | Confidence |
   |----|------------|----------|--------|------|------------|
   | ADR-001 | System | Monolithic Architecture | Discovered | 2026-02-26 | HIGH |
   | ADR-002 | Auth | JWT Authentication | Discovered | 2026-02-26 | HIGH |
   | ADR-003 | Payments | Stripe Integration | Discovered | 2026-02-26 | MEDIUM |

   ---

   ## System-Level ADRs

   ### ADR-001: Monolithic Architecture
   [Full ADR content...]

   ---

   ## Auth Sub-System ADRs

   ### ADR-002: JWT Authentication
   [Full ADR content...]

   ---

   ## Payments Sub-System ADRs

   ### ADR-003: Stripe Integration
   [Full ADR content...]
   ```

   - Mark each ADR with its parent sub-system in the index
   - Add section headers for each sub-system
   - Document cross-cutting patterns (e.g., shared database) as System-Level

### Phase 5: Gap Analysis

**Objective**: Identify areas where decisions are unclear

After scanning, report:

```markdown
## Architecture Discovery Report

### Technologies Detected
| Category | Technology | Confidence | Evidence |
|----------|------------|------------|----------|
| Backend | Django 4.2 | HIGH | requirements.txt, app structure |
| Database | PostgreSQL | HIGH | connection strings, migrations |
| Frontend | React 18 | MEDIUM | package.json, JSX files |
| Cache | Redis | HIGH | redis imports, docker-compose |

### Documentation Deduplication
✓ README.md: Tech stack documented (lines 20-45)
  → Referenced in Context View, skipping tech stack ADRs
✓ CONTRIBUTING.md: Development workflow documented
  → Referenced in Development View 3.5

### ADRs Generated (Surprising/Risky decisions only)
| ID | Decision | Confidence | Why Documented |
|----|----------|------------|----------------|
| ADR-001 | Monolithic Django architecture | HIGH | Architecture style choice |
| ADR-002 | Custom JWT authentication | MEDIUM | Security risk, non-standard |
| ADR-003 | Microservices for small team | HIGH | Scale mismatch, surprising |

### Skipped (Covered by existing docs or obvious)
| Decision | Reason |
|----------|--------|
| PostgreSQL choice | Ecosystem default + README covers |
| React frontend | Standard framework + README covers |
| Docker containerization | Conventional choice |

### Unclear Areas (Need Human Input)
| Area | Question | Suggestion |
|------|----------|------------|
| Auth | OAuth2 or custom JWT? | Found JWT usage, need confirmation |
| Caching | Redis strategy unclear | Cache-aside pattern inferred |
| Scaling | Horizontal scaling setup? | No auto-scaling config found |

### Recommended Clarifications
1. Run `/architect.clarify` to refine ADRs with human input
2. Focus on [specific unclear area]
3. Consider documenting [undocumented pattern]
```

### Phase 6: Output Generation

**Objective**: Write discovered ADRs to file (NO AD.md creation)

1. **Write ADRs**:
   - Create or update `{REPO_ROOT}/.specify/drafts/adr.md` with discovered ADRs
   - Mark ADRs as "Discovered (Inferred)" status ← USE THIS STATUS
   - Use "Common Alternatives" section with neutral trade-offs (no "Rejected because")
   - Note confidence level for each
   - Tag assumptions that need validation

2. **DO NOT Create AD.md**:
   - Architecture Description will be generated later via `/architect.implement`
   - Only AFTER ADRs are validated through clarification

3. **Generate Summary**:
   - Technologies discovered
   - ADRs created with confidence levels
   - Gaps identified
   - Assumptions made (to be validated in clarify phase)

### Phase 7: Validate with Clarify

**Objective**: Validate brownfield findings with user

After generating ADRs, **run `/architect.clarify`** with brownfield context to validate:

**Questions Clarify Should Ask** (Brownfield-Specific):

| Question Type | Example |
|---------------|---------|
| **Current State Validity** | "I detected microservices in docker-compose.yml - is this still your current approach?" |
| **Decision Rationale** | "PostgreSQL is used - was this chosen for specific requirements or inherited?" |
| **Team Context** | "Based on git history, team appears small - are current architecture decisions appropriate?" |
| **Technical Debt** | "Found custom authentication - are you considering migration to OAuth/OIDC?" |
| **Migration Plans** | "Legacy patterns detected in X module - any plans to modernize?" |
| **Deprecated Patterns** | "Monolithic deployment with hints of service separation - is microservices migration planned?" |

**Context Passed to Clarify**:

```json
{
  "source": "brownfield",
  "tech_stack_detected": ["detected technologies"],
  "inferred_decisions": ["list of ADRs with confidence levels"],
  "assumptions": ["things that need validation"],
  "files_analyzed": "count"
}
```

Run `/architect.clarify` to refine ADRs based on your input, then run `/architect.implement` to generate the full AD.md.

## Key Rules

### Evidence-Based Documentation

- **Only document what's found in code** - don't invent decisions
- **Cite specific evidence** for each ADR
- **Mark confidence levels** honestly
- **Flag uncertainties** explicitly

### Confidence Levels

| Level | Criteria |
|-------|----------|
| **HIGH** | Multiple clear evidence sources, unambiguous choice |
| **MEDIUM** | Some evidence, but could be interpreted differently |
| **LOW** | Limited evidence, significant uncertainty |

### Non-Destructive

- **Don't overwrite** existing ADRs without user approval
- **Merge intelligently** with existing documentation
- **Preserve manual additions** to architecture files

### No Fabricated Rejection Rationale

- **NEVER invent "Rejected because" reasons** for reverse-engineered ADRs
- **Use "Common Alternatives" with neutral "Trade-offs" framing** instead
- **Only document alternatives that were likely considered**
- **Be honest**: "We don't know why X wasn't chosen" is acceptable

### Interactive When Needed

- For **LOW confidence** discoveries, ask user for confirmation
- For **contradictory evidence**, present options
- For **gaps**, suggest clarification questions

### Sub-System Decomposition

- **Auto-detect from code**: Analyze directory structure, packages, services automatically
- **Interactive confirmation**: Always confirm sub-system breakdown with user
- **Balanced granularity**: Aim for 3-7 sub-systems; avoid over-decomposition
- **Clear evidence**: Cite specific directories/modules as evidence for each sub-system
- **Per-sub-system analysis**: Run pattern detection per sub-system for focused ADRs
- **Cross-cutting patterns**: Detect and document system-wide patterns separately
- **Use --no-decompose**: Skip decomposition for simple/small codebases

## Workflow Guidance & Transitions

### After `/architect.init`

**Required**: Run `/architect.clarify` to validate brownfield findings.

After clarification completes:

1. **Review Validated ADRs**: Check `{REPO_ROOT}/.specify/drafts/adr.md` for accuracy
2. **Approve ADRs**: Run `/architect.clarify` Phase 5.5 to change status to "Accepted"
3. **Run `/architect.implement`**: Generate full AD.md from Accepted ADRs

### Complete Brownfield Flow

```text
/architect.init "Node.js API, team of 2"
    ↓
[Scan codebase] → Detect technologies, patterns
    ↓
[Generate ADRs] → Write to {REPO_ROOT}/.specify/drafts/adr.md (marked "Discovered")
    ↓
[Run /architect.clarify] → Ask to validate decisions
    ↓
[Clarify asks] → "Is microservices decision still valid?"
                 "Custom auth detected - considering OAuth?"
    ↓
[Approve ADRs] → Phase 5.5 to change status to "Accepted"
    ↓
[Run /architect.implement] → Generate AD.md from Accepted ADRs
    ↓
[Generate AD.md] → Full architecture description
```

### When to Use This Command

- **Brownfield projects**: Existing code without architecture docs
- **Legacy modernization**: Understanding current state before changes
- **Team onboarding**: Quickly documenting implicit decisions
- **Technical debt assessment**: Identifying undocumented patterns

### When NOT to Use This Command

- **Greenfield projects**: Use `/architect.specify` for new projects
- **Architecture exists**: If `AD.md` exists, use `/architect.clarify` to refine
- **Feature-level**: Feature architecture via `before_plan` hook (configured in `.specify/extensions.yml`)

## Context

$ARGUMENTS