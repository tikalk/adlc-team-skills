---
description: Generate full Product Requirements Document (PRD) from PDRs using multi-agent DAG orchestration
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "implement {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "implement {ARGS}"
---

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
  - `all` (default): All 11 sections
  - Custom: comma-separated (e.g., `problem,scope,requirements`)

## Goal

Transform Product Decision Records (PDRs) into a comprehensive Product Requirements Document (PRD) using a **multi-agent DAG orchestration** approach:

1. **Plan Agent**: Analyze PDRs, detect feature-areas, generate customized DAG, get user approval
2. **Execute Agent**: Generate sections per feature-area following the DAG, with dependency context
3. **Summarize Agent**: Aggregate all sections, resolve conflicts, generate unified PRD.md

**Key Insight**: PDRs capture **why** decisions were made; the PRD captures **what** the product will deliver as a result of those decisions.

## Role & Context

You are acting as a **Product Orchestrator** managing a multi-phase documentation generation workflow. Your role involves:

- **Planning** the generation DAG based on feature-area analysis
- **Executing** section generation with proper dependency ordering
- **Summarizing** sections into a unified Product Requirements Document
- **Persisting** state for resumability across AI agent sessions

### Product Document Hierarchy

| Document | Purpose | Location |
|----------|---------|----------|
| `{REPO_ROOT}/.specify/drafts/pdr.md` | Product decisions with rationale | Input |
| `{REPO_ROOT}/.specify/product/state.json` | DAG execution state | State |
| `{REPO_ROOT}/.specify/product/sections/{feature-area}/{section}.md` | Per-section outputs | Intermediate |
| `PRD.md` (root) | Full Product Requirements Document | Output |

**Output**: PRD.md (project root)
**Sections Mode**: [all|custom]
**Feature-Areas Processed**: N

**Sections Generated**:
| Feature-Area | Sections | Status |
|--------------|----------|--------|
| Core | All 11 | ✓ |
| Auth | All 11 | ✓ |
| Data | All 11 | ✓ |

**Conflicts Resolved**: M
**PDR Coverage**: X/Y PDRs incorporated

**PDR Lifecycle**:
- Promoted to canonical: N PDRs
- Remaining in drafts: M PDRs

**Recommended Next Steps**:
1. Review generated PRD for accuracy
2. Run `/product.analyze` for consistency validation
3. Share with stakeholders for review
4. Begin feature development with `/spec.specify`
```

---

## State File Schema

**Location**: `{REPO_ROOT}/.specify/product/state.json`

```json
{
  "version": "1.1.0",
  "created_at": "ISO8601 timestamp",
  "updated_at": "ISO8601 timestamp",
  "phase": "planning | plan_approved | executing | summarizing | completed",
  "sections_mode": "all | custom",
  "feature_areas": [
    {
      "id": "lowercase-kebab-case",
      "name": "Display Name",
      "pdrs": ["PDR-001", "PDR-002"],
      "characteristics": ["b2b", "platform"],
      "dag": ["overview", "problem", "goals", "metrics", "personas", "requirements", "nfrs", "out-of-scope", "risks", "roadmap", "pdr-summary"],
      "progress": {
        "overview": "pending | in_progress | completed | skipped",
        "problem": "pending | in_progress | completed | skipped"
      }
    }
  ],
  "conflicts_detected": [],
  "conflicts_resolved": [],
  "output_file": "PRD.md"
}
```

---

## Key Rules

### PDR Traceability

- **Every section** must reference source PDRs
- **No content** without PDR backing
- **PDRs are source of truth** for conflict resolution

### State Persistence

- **Always update** state.json after each operation
- **Resume gracefully** from any interruption
- **Track progress** at section granularity

### Multi-Agent Compatibility

- State file works with any AI agent (Claude, Copilot, Cursor, etc.)
- No agent-specific dependencies
- Human-readable state for debugging

### Quality Standards

- **Validate** requirements are actionable
- **Ensure** acceptance criteria are testable
- **Check** metric definitions are measurable

---

## Workflow Guidance & Transitions

### After `/product.implement`

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

---

## Context

{ARGS}
