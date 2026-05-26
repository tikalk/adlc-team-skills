# Product Extension Quick Start

Create and manage Product Requirements Documents (PRD) and Product Decision Records (PDR) for systematic product development.

## Overview

The Product extension parallels the Architect extension but focuses on product management:

- **PDRs (Product Decision Records)** - Document the *why* behind product decisions
- **PRD (Product Requirements Document)** - Synthesize PDRs into comprehensive requirements

## Quick Start

### Brownfield (Existing Product) - Run Once

> **Note**: Use `.init` only once for initial product setup. For ongoing work, use `.specify`.

```bash
# 1. Discover PDRs from existing product (ONE-TIME setup)
/product.init "B2B SaaS analytics platform"

# 2. Auto-clarification runs
/product.clarify

# 3. Generate PRD
/product.implement

# 4. Validate consistency
/product.analyze
```

### Ongoing Product Work

After initial setup, use `.specify` for new product decisions:

```bash
# Add new product decisions
/product.specify "Add enterprise tier pricing"
/product.clarify
/product.implement
/product.analyze
```

### Greenfield (New Product)

```bash
# 1. Interactive product exploration
/product.specify "Internal developer platform"

# 2. Refine PDRs
/product.clarify

# 3. Generate full PRD
/product.implement --sections all

# 4. Validate
/product.analyze
```

## Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/product.init` | Reverse-engineer PDRs from existing product | Brownfield analysis |
| `/product.specify` | Interactive PRD exploration to create PDRs | Greenfield products |
| `/product.clarify` | Refine and validate PDRs | After init/specify |
| `/product.implement` | Generate PRD from PDRs | After PDRs are clear |
| `/product.analyze` | Validate PDR-PRD consistency | After implementation |
| `/product.validate` | Check feature spec alignment (READ-ONLY) | During feature dev |
| `/product.roadmap` | Track milestone progress | During development |
| `/product.link` | Link feature to PDR | Manual PDR association |

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| PDRs (draft) | `.specify/drafts/pdr.md` | Working PDRs during discovery |
| PDRs (accepted) | `.specify/memory/pdr.md` | Canonical project PDRs |
| Product Requirements | `PRD.md` (root) | Full PRD document |

## PDR Format

```markdown
### PDR-001: Freemium Pricing Model

#### Status
Accepted

#### Date
2024-01-15

#### Context
We need a pricing strategy that balances user acquisition with revenue.

#### Decision
Implement a freemium model with:
- Free tier: 3 projects, basic features
- Pro tier: $29/month, unlimited projects
- Enterprise: Custom pricing, SSO, SLA

#### Consequences
##### Positive
- Lower barrier to entry
- Viral growth potential

##### Negative
- Support costs for free users

#### Alternatives Considered
##### Option A: Pure SaaS Subscription
**Description**: No free tier, paid only
**Trade-offs**: Higher immediate revenue, slower adoption

#### Success Metrics
- Free-to-paid conversion rate > 5%
- Monthly churn < 3%
```

## PRD Structure

The PRD contains 11 sections:

1. **Overview** - Product summary and vision
2. **The Problem** - Problem statement and market need
3. **Goals/Objectives** - What we're trying to achieve
4. **Success Metrics** - How we measure success
5. **Personas** - Target users and their needs
6. **Functional Requirements** - What the product does
7. **Non-Functional Requirements** - Performance, security, etc.
8. **Out of Scope** - What's explicitly not included
9. **Risks & Mitigation** - Potential issues and solutions
10. **Roadmap & Milestones** - Timeline and deliverables
11. **PDR Summary** - Decision record index

## Configuration

```yaml
# .specify/extensions/product/product-config.yml
pdr:
  heuristic: "surprising"  # surprising | all | minimal
  drafts_location: ".specify/drafts/pdr.md"
  memory_location: ".specify/memory/pdr.md"

prd:
  location: "PRD.md"
  sections: "all"  # all | core | comma-separated list
```

## DAG Customization

The `/product.implement` command adapts based on product type:

| Feature-Area Pattern | DAG Modification |
|---------------------|------------------|
| B2B Focus | Expand Personas, NFRs earlier |
| B2C Focus | Prioritize UX in Requirements |
| Platform Product | Requirements before Personas |
| Data Product | Metrics has higher priority |
| Marketplace | Multiple Persona branches |

## Integration with Other Extensions

### Architect Extension

The Product extension feeds into the Architect extension:

```
PRD → /architect.specify → ADRs → AD.md
```

After creating your PRD, use it as input to `/architect.specify` to define the technical architecture.

### Spec Extension

Product validates feature specs via hooks:

| Hook | When it Runs | Purpose |
|------|--------------|---------|
| `before_specify` | Before spec creation | Link feature to existing PDR |
| `after_specify` | After spec creation | Validate feature spec alignment with PRD |
| `before_clarify` | Before clarification | Load PDR context |
| `after_clarify` | After clarification | Validate clarifications against PRD |

### LevelUp Extension

After implementing features, capture product patterns:

```bash
/levelup.init              # Discover product patterns
/levelup.skills prd-format # Build skill for PRD creation
/levelup.implement         # Contribute to team-ai-directives
```

## Workflow Summary

```
Brownfield: /product.init → /product.clarify → /product.implement → /product.analyze
Greenfield: /product.specify → /product.clarify → /product.implement → /product.analyze
```

**Next Steps:**
1. Run the appropriate workflow for your product
2. Review generated PRD.md
3. Proceed to `/architect.specify` to define architecture
4. Use hooks during feature development for validation

For detailed examples, see the [CNE Agent PRD example](../../CNE%20Agent%20(2).md).
