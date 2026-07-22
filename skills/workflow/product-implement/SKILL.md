---
name: product-implement
description: Generate a full Product Requirements Document (PRD.md) from accepted PDRs using multi-agent DAG orchestration. Reads individual PDR files, generates PRD sections from templates, validates output, and promotes accepted PDRs to memory. Use after /product.clarify.
disable-model-invocation: true
---

# product-implement

## What this skill does

Transforms **accepted PDRs** into a comprehensive, self-contained `PRD.md` using a **three-phase DAG**:

1. **Plan Agent**: Analyze PDRs, detect feature-areas, generate customized DAG, get user approval
2. **Execute Agent**: Generate sections per feature-area with **mandatory checkpoint after Requirements**
3. **Summarize Agent**: Aggregate sections, resolve conflicts, produce unified `PRD.md`

**Output**:
- `PRD.md` (repo root) — self-contained product requirements
- `{REPO_ROOT}/.adlc/product/sections/{feature-area}/{section}.md` — intermediate section files
- Accepted PDRs **moved** to `{REPO_ROOT}/.adlc/memory/pdr/`

## When to use

- After `/product.clarify` has approved PDRs
- After `/product.init` to document existing product
- PDR updates requiring PRD regeneration

## When NOT to use

- No Accepted PDRs (run `/product.clarify` first)
- Minor PRD edits (edit `PRD.md` directly)

## Pre-Flight Validation

**Before starting, verify prerequisites:**

1. **Check PDRs exist**: `{REPO_ROOT}/.adlc/drafts/pdr/PDR-*.md`
2. **Check for Accepted PDRs**: Count files with status "Accepted"
   - If **zero**: STOP and output:
     ```
     Cannot proceed: No Accepted PDRs found.
     Run /product.clarify to review and approve PDRs first.
     ```
   - If ≥1: Proceed

## Three-Phase DAG Workflow

```
┌─────────────────────────────────────────────────────────┐
│ PHASE 1: PLAN (Plan Agent)                              │
│ Load PDRs → Detect Feature-Areas → Generate DAG → Approve│
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 2: EXECUTE (Execute Agent)                        │
│ Overview → Problem → Goals → Metrics → Personas         │
│ → [REQUIREMENTS CHECKPOINT] ← MANDATORY USER APPROVAL   │
│ → NFRs → Out-of-Scope → Risks → Roadmap → PDR-Summary   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 3: SUMMARIZE (Summarize Agent)                    │
│ Read sections → Detect conflicts → Resolve → PRD.md     │
└─────────────────────────────────────────────────────────┘
```

## Execution Steps

### Phase 1: Plan

**Step 1.1: Load and Analyze PDRs**

1. Read all `PDR-*.md` files from `.adlc/drafts/pdr/`
2. Filter to **Accepted** status only
3. Parse feature-area from each PDR
4. Group PDRs by feature-area

**Step 1.2: Detect Feature-Area Characteristics**

| Characteristic | Detection Pattern | DAG Customization |
|---------------|-------------------|-------------------|
| B2B SaaS | Enterprise, admin, SSO | Include compliance sections |
| Consumer App | Mobile, freemium, social | Simplify requirements |
| Platform | API, integrations, developer | Expand NFRs |
| Marketplace | Multi-sided, transaction | Add business model sections |

**Step 1.3: Generate Customized DAG**

**Default DAG** (all 15 sections):
```
Document Information → Executive Summary → Overview → Problem
→ Market Opportunity → Goals → Metrics → Personas
→ [CHECKPOINT: Requirements]
→ NFRs → Out-of-Scope → Risks → Investment
→ Roadmap → Go-to-Market → PDR-Summary
```

**Section numbering** (fixed):
- 1. Document Information
- 1.5 Executive Summary
- 2. Overview
- 3. The Problem
- 3.5 Market Opportunity
- 4. Goals & Objectives
- 5. Success Metrics
- 6. Personas
- 7. Functional Requirements
- 8. Non-Functional Requirements
- 9. Out of Scope
- 10. Risks & Mitigation
- 10.5 Investment & Resources
- 11. Roadmap & Milestones
- 11.5 Go-to-Market Strategy
- 12. PDR Summary

**Step 1.4: Present Plan for Approval**

```markdown
## DAG Execution Plan

**Feature-Areas detected**: 3
**Total sections**: 15

**Feature-Area: Core**
**PDRs**: PDR-001, PDR-005, PDR-008
**DAG**: Document Info → Executive Summary → Overview → Problem
→ Market Opportunity → Goals → Metrics → Personas
→ [Requirements Checkpoint] → NFRs → Out-of-Scope → Risks
→ Investment → Roadmap → GTM → PDR-Summary

**Approve this plan?** [Yes/Modify/Cancel]
```

**Step 1.5: Write state.json**

```json
{
  "version": "1.0",
  "phase": "plan_approved",
  "feature_areas": [
    {
      "id": "core",
      "name": "Core",
      "pdrs": ["PDR-001", "PDR-005"],
      "dag": ["document-info", "executive-summary", "overview", "problem", ...],
      "progress": {}
    }
  ],
  "checkpoint": {
    "enabled": true,
    "after_section": "requirements",
    "status": "pending"
  }
}
```

### Phase 2: Execute

For each section in the DAG:

1. **Check dependencies** — ensure all prerequisites completed
2. **Load section template** — `templates/sections/{section}.md`
3. **Generate content** — fill template with PDR-derived content
4. **Write section file** — `.adlc/product/sections/{feature-area}/{section}.md`
5. **Validate** — run `scripts/bash/validate-prd.sh {section}.md`
6. **Update state.json** — mark section as "completed"

**Section template usage** (MANDATORY):
- Read template FIRST
- Fill ALL [PLACEHOLDERS]
- NEVER generate from scratch

**In-section diagrams** (MANDATORY):
- Use ` ```mermaid ` code blocks
- Use `flowchart` keyword (NOT deprecated `graph`)
- ASCII box-drawing characters are PROHIBITED
- Diagrams embedded in their home sections

| Section | Diagram Type | Subsection |
|---------|-------------|------------|
| 2. Overview | Feature Hierarchy (`flowchart TD`) | 2.4 |
| 2. Overview | Architecture (`flowchart TB`) | 2.5 |
| 6. Personas | User Journey (`journey`) | 6.4 |
| 7. Requirements | Req Dependencies (`flowchart LR`) | 7.4 |
| 7. Requirements | Feature Dependencies (`flowchart LR`) | 7.5 |
| 11. Roadmap | Gantt Chart (`gantt`) | 11.1 |

**Requirements Checkpoint** (MANDATORY):

After generating Requirements section:
```markdown
## CHECKPOINT: Requirements Section Complete

The Requirements section has been generated.

**Why checkpoint here?** Requirements shapes:
- NFRs (how requirements are met)
- Out-of-Scope (what's NOT required)
- Risks (technical feasibility)
- Roadmap (priority and sequencing)

**Options**:
A) Approve — Continue to remaining sections
B) Modify — Edit requirements, then continue
C) Restart — Regenerate from Problem phase
D) Cancel — Stop execution
```

### Phase 3: Summarize

**Step 3.1: Read All Sections FROM DISK**

> CRITICAL: Read each section file from filesystem. Do NOT use content from memory.

1. Scan `.adlc/product/sections/` for all `.md` files
2. Read each file
3. Validate: ≥20 lines, proper headers

**Step 3.2: Detect Cross-Feature-Area Conflicts**

| Conflict Type | Detection | Resolution |
|--------------|-----------|------------|
| Duplicate requirements | Same requirement, different wording | Standardize to PDR terminology |
| Priority mismatch | Same feature, different priority | Defer to PDR |
| Metric inconsistency | Same metric, different definition | Use PDR definition |

**Step 3.3: Aggregate into PRD.md**

> CRITICAL: PRD.md MUST be SELF-CONTAINED.
> - ALL diagrams embedded IN-SECTION
> - ZERO reader-facing links to `.adlc/` paths
> - Use in-document anchors only: `[Section 2.4](#24-feature-hierarchy)`
> - PDR references as plain text: `PDR-078` (NOT linked)

**PRD structure** (must match template):
```markdown
# Product Requirements Document: [Product Name]

## 1. Document Information
[Quick Stats, revision history, approval]

## 1.5 Executive Summary
[Business case, ROI, recommendation]

## 2. Overview
[Product description, scope]
### 2.4 Feature Hierarchy [MERMAID flowchart TD]
### 2.5 Architecture Overview [MERMAID flowchart TB]

## 3. The Problem
[Problem statement, validation evidence]

## 3.5 Market Opportunity
[TAM/SAM/SOM, competitive landscape]

## 4. Goals & Objectives
[Primary, technical, business goals traced to PDRs]

## 5. Success Metrics
[Adoption, engagement, quality]
### 5.5 Business Outcome Metrics
### 5.6 Financial Metrics

## 6. Personas
[Primary, secondary, anti-personas]
### 6.4 User Journey [MERMAID journey]

## 7. Functional Requirements [CHECKPOINT]
[User stories, REQ-XXX IDs, priority matrix]
### 7.4 Requirement Dependencies [MERMAID flowchart LR]
### 7.5 Feature Dependencies [MERMAID flowchart LR]

## 8. Non-Functional Requirements
[Performance, security, reliability, scalability]

## 9. Out of Scope
[Feature, technical, market exclusions]

## 10. Risks & Mitigation
[Risk summary, technical, market, operational]
### 10.4 Business Risks

## 10.5 Investment & Resources
[Team, budget, ROI, go/no-go criteria]

## 11. Roadmap & Milestones
### 11.1 Roadmap Overview [MERMAID gantt]
[Milestone details with demo sentences]

### 11.2 Milestone Gates & Progress
[Per milestone: done-means definition, feature rollup, gate table, issue/evidence status — sourced from milestone PDRs]

## 11.5 Go-to-Market Strategy
[Launch phases, pricing, messaging]

## 12. PDR Summary
[Key decisions, constitution alignment — NO external links]
```

### Phase 4: PDR Lifecycle Management (MANDATORY)

**Step 4.1: Move Accepted PDRs to Memory**

For each PDR with status "Accepted":
1. Read from `.adlc/drafts/pdr/PDR-{NNN}.md`
2. Write to `.adlc/memory/pdr/PDR-{NNN}.md`
3. Update status to "Completed" in memory copy

**Step 4.2: Clean Up Drafts**

- Remove moved PDRs from `.adlc/drafts/pdr/`
- Retain Proposed/Discovered PDRs in drafts
- Regenerate `pdr.md` index

**Step 4.3: Update state.json**

```json
{
  "phase": "completed",
  "pdr_lifecycle": {
    "pdrs_promoted": [N],
    "memory_pdr_written": true,
    "drafts_retained": true,
    "drafts_reason": "Proposed/Discovered PDRs remain"
  }
}
```

### Phase 5: Final Verification

Before marking complete, verify ALL checks:

| # | Check | Expected |
|---|-------|----------|
| 1 | Section files on disk | N files in `.adlc/product/sections/` |
| 2 | PRD.md exists | Yes |
| 3 | PRD.md content size | >200 lines |
| 4 | PRD.md has all sections | Sections 1-12 + sub-sections |
| 5 | PRD.md is self-contained | 0 `.adlc/` links |
| 6 | Diagrams embedded | ≥4 `mermaid` blocks |
| 7 | Memory PDRs written | `.adlc/memory/pdr/PDR-*.md` exist |
| 8 | state.json consistent | All sections "completed" |

**Gate Rule**: If ANY check fails → do NOT mark as completed. Report failures.

## PDR Traceability Rules

- **Every section** must reference source PDRs with ID
- **Every requirement** (REQ-XXX) must trace to a PDR
- **No content** without PDR backing
- **PDRs are source of truth** for conflict resolution

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `PDR_MEMORY_DIR` — `{REPO_ROOT}/.adlc/memory/pdr`
- `PRD_FILE` — `{REPO_ROOT}/PRD.md`
- `SECTIONS_DIR` — `{REPO_ROOT}/.adlc/product/sections`
- `STATE_FILE` — `{REPO_ROOT}/.adlc/product/state.json`

## 12-Factor Alignment

- **Factor III (Mission Definition)**: Compiles mission decisions into actionable requirements
- **Factor IV (Structured Planning)**: DAG orchestration separates planning from execution
- **Factor IX (Traceability)**: Every PRD element traces back to a PDR

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll skip the checkpoint and just generate everything." | Requirements shapes NFRs, Out-of-Scope, Risks, and Roadmap. Skipping the checkpoint risks cascading errors. |
| "The PRD can reference section files." | PRD.md MUST be self-contained. External references break when section files are moved or deleted. |
| "I don't need to move PDRs to memory." | Without promotion, drafts and memory diverge. The next clarify session sees stale data. |

## Red Flags

- **Generating PRD from non-Accepted PDRs** — implement skips Proposed/Discovered; the PRD will be incomplete.
- **Writing PRD.md directly from PDRs** — content MUST come from section files to ensure validation passed.
- **Missing the Requirements checkpoint** — this is the cornerstone section; errors here cascade.
- **Leaving `.adlc/` links in PRD.md** — breaks self-containment; readers cannot follow internal paths.

## Verification

- [ ] Pre-flight: ≥1 Accepted PDR exists
- [ ] Plan approved by user
- [ ] state.json written with DAG
- [ ] Each section file ≥20 lines
- [ ] validate-prd.sh passes for each section
- [ ] Requirements checkpoint approved by user
- [ ] PRD.md >200 lines with all 15 sections
- [ ] Zero `.adlc/` links in PRD.md
- [ ] ≥4 Mermaid diagrams embedded in-section
- [ ] All requirements trace to PDRs
- [ ] Accepted PDRs moved to `.adlc/memory/pdr/`
- [ ] Final completion verification: all 8 checks pass
