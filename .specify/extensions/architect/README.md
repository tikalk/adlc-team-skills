# Architect Extension

Create and manage Architecture Decision Records (ADRs) and Architecture Descriptions (AD.md) using Rozanski & Woods methodology.

## Overview

The Architect extension provides a complete workflow for documenting and maintaining software architecture:

- **ADRs (Architecture Decision Records)** - Track why decisions were made
- **AD.md (Architecture Description)** - Document what the system looks like

## Commands

| Command | Purpose |
|---------|---------|
| `/architect.init` | Reverse-engineer ADRs from existing codebase (brownfield) |
| `/architect.specify` | Interactive PRD exploration to create ADRs (greenfield) |
| `/architect.clarify` | Refine and validate ADRs through questions |
| `/architect.implement` | Generate AD.md from ADRs (Rozanski & Woods) |
| `/architect.analyze` | Validate ADR to AD consistency and quality |
| `/architect.validate --for-plan` | Validate plan alignment with architecture (READ-ONLY) |

## Quick Start

### Brownfield (Existing Codebase)

```bash
/architect.init        # Discover ADRs from code
/architect.clarify     # Validate discovered ADRs
/architect.implement   # Generate AD.md (uses DAG orchestration)
/architect.analyze     # Verify consistency
```

### Greenfield (New Project)

```bash
/architect.specify     # Create ADRs from PRD
/architect.clarify     # Refine ADRs
/architect.implement   # Generate AD.md (uses DAG orchestration)
/architect.analyze     # Verify consistency
```

## Multi-Agent DAG Orchestration (v1.1.0)

The `/architect.implement` command uses a three-phase DAG orchestration approach:

### Phase 1: Plan

- Analyzes ADRs and detects sub-systems from the ADR index table
- Generates customized DAG per sub-system based on characteristics
- Presents execution plan for user approval
- Saves approved plan to `.specify/architect/state.json`

### Phase 2: Execute

- Generates views per sub-system following the DAG order
- Passes dependency context between views (e.g., Context → Functional → Information)
- Writes per-view outputs to `.specify/architect/views/{subsystem}/{view}.md`
- Updates progress in state.json for resumability

### Phase 3: Summarize

- Reads all view files from all sub-systems
- Detects and resolves cross-subsystem conflicts using ADRs as source of truth
- Aggregates into unified AD.md
- Applies Security and Performance perspectives
- Moves Accepted ADRs to canonical location

### DAG Customization Rules

| Sub-system Pattern | DAG Modification |
|-------------------|------------------|
| Serverless | Deployment view first |
| Event-driven | Include Concurrency view |
| Data-intensive | Information view priority |
| Microservices | Expanded Functional view |
| Monolith | Simplified Functional, skip Concurrency |

### State Persistence

The DAG workflow persists state to `.specify/architect/state.json`, enabling:

- **Resumability**: Continue from any interruption
- **Multi-agent compatibility**: Works with Claude, Copilot, Cursor, etc.
- **Progress tracking**: View-level granularity

### View Templates

Located in `templates/views/` and `templates/perspectives/`:

- 7 view templates (context, functional, information, concurrency, development, deployment, operational)
- 2 perspective templates (security, performance)

## Command Flow

```text
Brownfield:   /architect.init --> /architect.clarify --> /architect.implement --> /architect.analyze
                                         ^                        |                        |
                                         +------------------------+------------------------+
                                                     (iterate on findings)

Greenfield:   /architect.specify --> /architect.clarify --> /architect.implement --> /architect.analyze
```

## Architecture Files

| File | Location | Purpose |
|------|----------|---------|
| System ADRs | `.specify/memory/adr.md` | Architecture Decision Records |
| System AD | `AD.md` (root) | Full Architecture Description |
| Feature ADRs | `specs/{feature}/adr.md` | Feature-level decisions |
| Feature AD | `specs/{feature}/AD.md` | Feature-level architecture |

## Two-Level Architecture System

| Level | Location | ADR File | Architecture Description | Hook Timing |
|-------|----------|----------|--------------------------|--------------|
| **System** | Main branch | `memory/adr.md` | `AD.md` (root) | N/A |
| **Feature** | Feature branch | `specs/{feature}/adr.md` | `specs/{feature}/AD.md` | before_plan hook |
| **Validation** | Plan level | READ-ONLY via architect.validate | Validates plan alignment | after_plan hook |

**Feature-level ADRs and AD.md** are created automatically via extension hooks during `/spec.plan` execution (if system architecture exists).

## Installation

The architect extension is **bundled by default** during project initialization:

```bash
specify init my-project
```

For manual installation:

```bash
specify extension add architect
```

## Using /architect.analyze

The analyze command validates consistency between ADRs and AD.md:

### Detection Passes

| Pass | What it Checks |
|------|----------------|
| A | ADR quality (completeness, clarity) |
| B | Inter-ADR consistency (conflicts, terminology) |
| C | ADR to AD drift (decisions not in AD) |
| D | AD to ADR drift (components without ADRs) |
| E | AD internal consistency (views align) |
| F | Staleness (placeholders, deprecated refs) |
| G | Feature-system alignment |

### Severity Levels

- **CRITICAL** - Constitution violations, security gaps
- **HIGH** - ADR to AD drift, conflicting decisions
- **MEDIUM** - Incomplete documentation, staleness
- **LOW** - Style improvements, minor gaps

### Example Output

```markdown
## Architecture Analysis Report

### Findings
| ID | Pass | Severity | Location | Summary |
|----|------|----------|----------|---------|
| C1 | ADR->AD Drift | HIGH | ADR-005 | Caching not in Info View |
| D1 | AD->ADR Drift | HIGH | AD.md:3.2 | Redis has no ADR |

### Next Actions
- Run /architect.clarify for ADR quality issues
- Run /architect.implement to sync AD.md
```

## Configuration

Optional configuration in `.specify/extensions/architect/architect-config.yml`:

```yaml
adr:
  heuristic: "surprising"  # surprising | all | minimal
  location: ".specify/memory/adr.md"

views:
  default: "core"  # core | all | concurrency,operational

analysis:
  max_findings: 50
  block_on_critical: true
```

### Views Selection (`--views`)

- `core` (default) - Generate the essential 5 views: Context, Functional, Information, Development, Deployment
- `all` - Include all 7 views including Concurrency and Operational
- `concurrency,operational` - Custom selection (comma-separated), always includes core views

```bash
# Default core views
/architect.init "E-commerce platform"

# All views including concurrency and operational
/architect.init --views all "High-throughput trading system"

# Custom selection
/architect.init --views concurrency "Real-time data processing pipeline"
```

### ADR Generation Heuristic (`--adr-heuristic`)

- `surprising` (default) - Only document decisions that deviate from obvious ecosystem defaults
- `all` - Document every architectural decision
- `minimal` - Document only high-risk or non-obvious decisions

```bash
# Skip documenting obvious choices (PostgreSQL for relational data, React for SPA)
/architect.specify --adr-heuristic surprising "Standard web application"

# Document every decision
/architect.specify --adr-heuristic all "Complex multi-tenant system"

# Minimal documentation
/architect.specify --adr-heuristic minimal "Internal tool with simple requirements"
```

## ADR Format (MADR)

Architecture Decision Records follow the MADR format:

```markdown
### ADR-001: [Decision Title]

#### Status
Proposed | Accepted | Deprecated | Superseded by ADR-XXX | Discovered

#### Date
YYYY-MM-DD

#### Context
What is the issue we're addressing?

#### Decision
What did we decide?

#### Consequences
##### Positive
- Benefits

##### Negative
- Trade-offs

#### Common Alternatives
##### Option A: [Name]
**Description**: Brief description
**Trade-offs**: Neutral comparison
```

## AD.md Structure (Rozanski & Woods)

The Architecture Description follows Rozanski & Woods with 7 viewpoints:

### Core Views (Always Generated)

1. **Context View (3.1)** - System scope and external interactions
2. **Functional View (3.2)** - Internal components and responsibilities
3. **Information View (3.3)** - Data storage and management
4. **Development View (3.5)** - Code organization and CI/CD
5. **Deployment View (3.6)** - Physical environment and infrastructure

### Optional Views

6. **Concurrency View (3.4)** - Runtime processes and threads
7. **Operational View (3.7)** - Operations and maintenance

### Perspectives

- **Security Perspective (4.1)** - Security considerations
- **Performance Perspective (4.2)** - Performance and scalability

## Integration with Spec Workflow

Architecture works with specification commands via extension hooks:

```text
/architect.specify --> /architect.clarify --> /architect.implement
                                                      |
                                                      v
                     architect extension hooks (before_plan / after_plan)
                                                      |
                                                      v
/spec.specify --> /spec.plan --> /spec.tasks --> /spec.implement
```

**Hooks only execute when `.specify/memory/adr.md` exists (architecture detection)**

| Hook | When it Runs | Command | Purpose |
|------|--------------|---------|---------|
| `before_plan` | Before plan generation | `adlc.architect.specify` | Create feature-level ADRs and AD.md |
| `after_plan` | After plan generation | `adlc.architect.validate` | Validate plan alignment (READ-ONLY) |

### Using /architect.validate

The validate command checks plan alignment with architecture:

- **Flags**: `--for-plan`, `--json`, `--system-only`, `--check-only [check]`
- **Returned Findings**:
  - `blocking` - Critical issues that must be fixed
  - `high_severity` - Issues that should be fixed
  - `warnings` - Recommendations
- **7 PILLAR Checks**:
  - PILLAR_1: Component ADR alignment
  - PILLAR_2: Interface contracts
  - PILLAR_3: Data model consistency
  - PILLAR_4: System context alignment
  - PILLAR_5: Functional consistency
  - PILLAR_6: Information view alignment
  - PILLAR_7: Development view alignment
- **Diagram Consistency**: System boundaries and data flows

The command is READ-ONLY and skips gracefully if no architecture exists.

## Related

- [Rozanski & Woods](https://www.viewpoints-and-perspectives.info/) - Architecture methodology
- [MADR](https://adr.github.io/madr/) - Markdown ADR format
- Issue #36 - Original feature request

## License

MIT
