# Architect Extension Quick Start

Create and manage Architecture Decision Records (ADRs) and Architecture Descriptions (AD.md) using Rozanski & Woods methodology.

## Overview

The Architect extension helps you document and maintain software architecture through:

- **ADRs (Architecture Decision Records)** - Track *why* architectural decisions were made
- **AD.md (Architecture Description)** - Document *what* the system looks like using 7 viewpoints

## Quick Start

### Brownfield (Existing Codebase) - Run Once

> **Note**: Use `.init` only once for initial project setup. For ongoing work, use `.specify`.

```bash
# 1. Discover ADRs from existing code (ONE-TIME setup)
/architect.init "E-commerce platform with microservices"

# 2. Validate discovered ADRs
/architect.clarify

# 3. Generate full Architecture Description
/architect.implement

# 4. Verify consistency
/architect.analyze
```

### Ongoing Architecture Work

After initial setup, use `.specify` for new architectural decisions:

```bash
# Add new architectural decisions
/architect.specify "Add caching layer for API responses"
/architect.clarify
/architect.implement
/architect.analyze
```

### Greenfield (New Project)

```bash
# 1. Create ADRs from PRD exploration
/architect.specify "Build a real-time data processing pipeline"

# 2. Refine ADRs
/architect.clarify

# 3. Generate Architecture Description
/architect.implement

# 4. Validate
/architect.analyze
```

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/architect.init` | Reverse-engineer ADRs from code | Brownfield projects |
| `/architect.specify` | Create ADRs from PRD (interactive) | Greenfield projects |
| `/architect.clarify` | Refine and validate ADRs | After init/specify |
| `/architect.implement` | Generate AD.md from ADRs | After ADRs are clear |
| `/architect.analyze` | Validate ADR-AD consistency | After implementation |
| `/architect.validate` | Check plan alignment (READ-ONLY) | During feature planning |

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| ADRs (draft) | `.specify/drafts/adr.md` | Working ADRs during discovery |
| ADRs (accepted) | `.specify/memory/adr.md` | Canonical project ADRs |
| Architecture Description | `AD.md` (root) | Full architecture document |
| Feature ADRs | `specs/{feature}/adr.md` | Feature-level decisions |
| Feature AD | `specs/{feature}/AD.md` | Feature-level architecture |

## ADR Format (MADR)

```markdown
### ADR-001: Use PostgreSQL for Primary Database

#### Status
Accepted

#### Date
2024-01-15

#### Context
We need a reliable relational database for user data.

#### Decision
Use PostgreSQL 15+ as our primary database.

#### Consequences
##### Positive
- ACID compliance for financial data
- Rich ecosystem and tooling

##### Negative
- Requires operational expertise

#### Common Alternatives
##### Option A: MySQL
**Description**: Widely used open-source RDBMS
**Trade-offs**: Good performance, less feature-rich
```

## Architecture Views (Rozanski & Woods)

The AD.md includes these viewpoints:

**Core Views:**
1. **Context View** - System scope and external interactions
2. **Functional View** - Internal components and responsibilities
3. **Information View** - Data storage and management
4. **Development View** - Code organization and CI/CD
5. **Deployment View** - Physical environment and infrastructure

**Optional Views:**
6. **Concurrency View** - Runtime processes and threads
7. **Operational View** - Operations and maintenance

**Perspectives:**
- Security Perspective
- Performance Perspective

## Analysis Passes

The `/architect.analyze` command performs 7 validation passes:

| Pass | What it Checks |
|------|----------------|
| A | ADR quality (completeness, clarity) |
| B | Inter-ADR consistency (conflicts, terminology) |
| C | ADR to AD drift (decisions not in AD) |
| D | AD to ADR drift (components without ADRs) |
| E | AD internal consistency (views align) |
| F | Staleness (placeholders, deprecated refs) |
| G | Feature-system alignment |

## Configuration

```yaml
# .specify/extensions/architect/architect-config.yml
adr:
  heuristic: "surprising"  # surprising | all | minimal
  location: ".specify/memory/adr.md"

views:
  default: "core"  # core | all | concurrency,operational

analysis:
  max_findings: 50
  block_on_critical: true
```

## Integration with Other Extensions

### Product Extension

The Product extension feeds into Architect:

```
PRD → /architect.specify → ADRs → AD.md
```

Use the PRD from Product extension as input to `/architect.specify`.

### Spec Extension

Architecture validates feature specs via hooks:

| Hook | When it Runs | Purpose |
|------|--------------|---------|
| `before_plan` | Before plan generation | Validate feature aligns with architecture |
| `after_plan` | After plan generation | Validate plan alignment (READ-ONLY) |

These hooks only run when `.specify/memory/adr.md` exists.

### LevelUp Extension

After implementing features, capture architectural patterns:

```bash
/levelup.init          # Discover patterns from your architecture
/levelup.skills adr-format  # Build skill for ADR creation
/levelup.implement     # Contribute to team-ai-directives
```

## Workflow Summary

```
Brownfield: /architect.init → /architect.clarify → /architect.implement → /architect.analyze
Greenfield: /architect.specify → /architect.clarify → /architect.implement → /architect.analyze
```

**Next Steps:**
1. Run the appropriate workflow for your project
2. Review generated AD.md
3. Iterate with `/architect.clarify` as needed
4. Use `/architect.validate` during feature planning

For detailed methodology, see [Rozanski & Woods](https://www.viewpoints-and-perspectives.info/).
