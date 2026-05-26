---
description: Reverse-engineer PDRs from existing codebase and documentation using multi-agent feature-area analysis (brownfield)
handoffs:
  - label: Validate Discovered PDRs
    agent: adlc.product.clarify
    prompt: |
      Review PDRs discovered from brownfield analysis.
      **Pay special attention to inconsistency flags**:
      - PDRs with ⚠️ Inconsistency Flags need resolution
      - Cross-feature-area conflicts require alignment decisions
      - Run clarification questions to resolve priority conflicts
    send: true
  - label: Generate PRD
    agent: adlc.product.implement
    prompt: Generate full PRD from discovered PDRs (after resolving inconsistencies)
    send: false
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "init {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "init {ARGS}"
state:
  enabled: true
  location: ".specify/product/state.json"
  phases: ["discovery", "pattern_analysis", "synthesis"]
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"B2B SaaS platform with React frontend, Node.js API, Stripe billing"`
- `"Mobile-first e-commerce app with in-app purchases"`
- `"--resume"` - Resume from previous state
- Empty input: Scan entire codebase for all product signals

## Goal

Reverse-engineer product decisions from an **existing product** using **multi-agent feature-area analysis**. Create **Product Decision Records (PDRs)** with cross-feature-area pattern detection and inconsistency flagging.

**Key Features**:
- **Sequential sub-agent execution**: Discovery → Pattern Analysis → Synthesis
- **Comprehensive detection**: Directory + Documentation + Pricing tiers
- **Cross-feature-area analysis**: Detects patterns in ≥2 feature-areas
- **Inconsistency flagging**: Flags conflicts for clarify resolution
- **State persistence**: Resumable execution with `--resume` flag

**Output**:

1. **PDRs** added to `{REPO_ROOT}/.specify/drafts/pdr.md` with cross-feature-area metadata
2. **Inconsistency flags** embedded in PDRs (for clarify resolution)
3. **Cross-feature-area analysis** summary

## Role & Context

You are orchestrating a **three-phase analysis pipeline**:

1. **Discovery Agent**: Scans feature-area for raw product signals (code, docs, pricing)
2. **Pattern Agent**: Classifies signals into PDR categories, scores strategic importance
3. **Synthesis Agent**: Cross-feature-area analysis, flags inconsistencies

### Three-Phase Architecture

```
Phase 0-3: Setup (Environment, Feature-Area detection, TPD loading)
    ↓
Phase 4: Discovery Agent (Per feature-area, sequential)
    ↓
Phase 5: Pattern Agent (Per feature-area, sequential)
    ↓
Phase 6: Synthesis Agent (Cross-feature-area, once)
    ↓
Phase 7: Output (PDR generation with inconsistency flags)
```

### Comprehensive Feature-Area Detection

Detects from **three sources**:

1. **Directory Structure** (`src/auth/`, `features/payments/`)
2. **Documentation Analysis** (README, PRD, ROADMAP sections)
3. **Pricing Tier Mapping** (Starter/Pro/Enterprise features)

### Cross-Feature-Area Analysis (≥2 Areas)

The Synthesis Agent flags:

| Pattern Type | Detection | Action |
|--------------|-----------|--------|
| **Shared Personas** | Same persona in ≥2 areas | Note cross-area presence |
| **Conflicting Priorities** | Different areas prioritize differently | ⚠️ Flag for clarify |
| **Duplicate Problems** | Same problem, different solutions | ⚠️ Flag for clarify |
| **Inconsistent Metrics** | Same metric, different definitions | ⚠️ Flag for clarify |
| **Pricing Gaps** | Features without tier assignment | ⚠️ Flag for clarify |

## Outline

1. **Validate Environment** (Phase 1): Ensure team-product-directives configured
2. **Feature-Area Detection** (Phase 2): Detect from directory + docs + pricing
3. **Environment Setup** (Phase 3): Initialize state
4. **Load TPD** (Phase 4): Read existing directives
5. **Discovery Agent** (Phase 5): Scan each feature-area for signals
6. **Pattern Agent** (Phase 6): Classify and score patterns
7. **Synthesis Agent** (Phase 7): Cross-feature-area analysis
8. **PDR Generation** (Phase 8): Generate PDRs with inconsistency flags
9. **Output** (Phase 9): Write PDRs and summary

## Execution Steps

### Phase 1: Validate Environment

**Objective**: Ensure prerequisites

#### Step 1: Verify Team Product Directives

If not configured, **STOP**:
```
Team Product Directives repository not configured.
Run: specify init --team-product-directives <path-or-url>
```

### Phase 2: Feature-Area Detection (Comprehensive)

**Objective**: Detect feature-areas from three sources

#### Step 1: Directory Structure Analysis

Analyze codebase structure:

| Pattern | Likely Feature-Area |
|---------|-------------------|
| `src/auth/`, `features/auth/` | Auth |
| `src/billing/`, `features/payments/` | Business |
| `src/analytics/`, `features/reports/` | Growth |
| `src/inventory/`, `features/ops/` | Operations |

#### Step 2: Documentation Analysis

Scan for feature sections:
- README.md sections → Feature categories
- ROADMAP.md → Planned feature areas
- PRD.md → Existing feature breakdown

#### Step 3: Pricing Tier Analysis

Parse pricing for feature mapping:

```markdown
## Pricing Tier Analysis

| Tier | Features | Implied Feature-Area |
|------|----------|---------------------|
| Starter | Basic auth, core features | Core |
| Pro | Billing, reporting | Business + Growth |
| Enterprise | SSO, audit logs, API | Auth + Operations + Platform |
```

#### Step 4: Feature-Area Proposal (Interactive)

Present detected areas:

```markdown
## Detected Feature-Areas (Comprehensive Analysis)

| # | Feature-Area | Sources | Evidence |
|---|--------------|---------|----------|
| 1 | **Core** | Directory + Docs | src/users/, README "Core Features" |
| 2 | **Business** | Directory + Pricing | src/billing/, pricing.md tiers |
| 3 | **Growth** | Docs + Pricing | docs/analytics.md, Pro tier features |

**Reply**: Y to confirm, n for monolithic, or suggest changes
```

**Threshold Logic**:
- **≤3 areas**: Auto-approve
- **4-6 areas**: Confirm with user
- **>6 areas**: Suggest grouping

### Phase 3: Environment Setup

#### Step 1: Initialize State

Create `{REPO_ROOT}/.specify/product/state.json`:

```json
{
  "version": "1.1.0",
  "command": "init",
  "created_at": "2026-01-20T10:00:00Z",
  "phase": "discovery",
  "current_feature_area_index": 0,
  "feature_areas": [
    {
      "id": "core",
      "name": "Core",
      "path": "src/core",
      "sources": ["directory", "documentation"],
      "progress": {
        "discovery": "pending",
        "pattern_analysis": "pending"
      }
    }
  ],
  "workflow": {
    "init_completed": false,
    "total_feature_areas": 3,
    "completed_feature_areas": 0
  }
}
```

#### Step 2: Check for Resume

If `--resume`: Load existing state, skip completed areas.

### Phase 4: Load Team Product Directives

**Objective**: Load existing TPD for comparison

Scan and load:
- `{TPD}/product_modules/pdrs/**/*.md`
- `{TPD}/pricing_models/*.md`
- `{TPD}/personas/*.md`

### Phase 5: Discovery Agent (Per Feature-Area, Sequential)

**Objective**: Scan each feature-area for product signals

**Execution**: For each feature-area in order:

#### Step 1: Check State

Load state.json, skip if `discovery == "completed"`.

#### Step 2: Run Discovery Agent

Use template: `templates/subagents/discovery-prompt.md`

**Input**:
```json
{
  "feature_area": {
    "id": "business",
    "name": "Business",
    "path": "src/billing/"
  },
  "detection_sources": ["directory", "documentation", "pricing_tiers"]
}
```

**Tasks**:
1. Scan directory for monetization, user flows, features
2. Analyze documentation (README, PRD, pricing)
3. Identify pricing tier mappings
4. Document evidence

#### Step 3: Update State

Save discovery results:
```json
{
  "feature_areas": [{
    "id": "business",
    "progress": { "discovery": "completed" },
    "discovery_results": {
      "signals_found": 6,
      "signals": [...]
    }
  }]
}
```

#### Step 4: Progress Report

```
Discovery Agent: business feature-area
├── Directory signals: 4
├── Documentation signals: 2
├── Pricing signals: 1
└── Status: ✓ Completed
```

Continue to next feature-area.

### Phase 5.5: Discovery Visualization

**Objective**: Generate preliminary visualizations from discovery results

After all feature-areas have been scanned by the Discovery Agent:

1. **Generate Feature-Area Map**:
   ```mermaid
   graph TD
       subgraph "Detected Feature-Areas"
           A["Feature-Area 1"] --> B["Feature-Area 2"]
           B --> C["Feature-Area 3"]
       end
   ```

2. **Document in Summary**:
   - Visual representation of detected areas
   - Evidence sources for each area
   - Preliminary monetization model (if detected)

These preliminary visualizations will be refined during the Pattern and Synthesis phases.

### Phase 6: Pattern Agent (Per Feature-Area, Sequential)

**Objective**: Classify and score patterns

**Execution**: For each feature-area:

#### Step 1: Check State

Skip if `pattern_analysis == "completed"`.

#### Step 2: Run Pattern Agent

Use template: `templates/subagents/pattern-prompt.md`

**Tasks**:
1. Categorize signals into PDR categories
2. Score strategic importance (0.0-1.0)
3. Check TPD for duplicates/similarity
4. Identify cross-area candidates

#### Step 3: Update State

```json
{
  "feature_areas": [{
    "id": "business",
    "progress": { "pattern_analysis": "completed" },
    "pattern_results": {
      "patterns": [...],
      "high_strategic": 4,
      "cross_area_candidates": 2
    }
  }]
}
```

Continue to next feature-area.

### Phase 7: Synthesis Agent (Cross-Feature-Area)

**Objective**: Cross-feature-area analysis and PDR generation

#### Step 1: Load All Data

Load all pattern results from state.

#### Step 2: Run Synthesis Agent

Use template: `templates/subagents/synthesis-prompt.md`

**Tasks**:

**1. Cross-Area Pattern Detection**:
```json
{
  "pattern_id": "P001",
  "pattern_name": "Admin Persona",
  "feature_area_presence": {
    "core": true,
    "business": true
  },
  "presence_count": 2,
  "is_cross_area": true
}
```

**2. Inconsistency Detection**:
- Priority conflicts
- Duplicate problems
- Inconsistent metrics
- Generate flags (not separate PDRs)

**3. PDR Generation**:
- High-strategic patterns (>0.7)
- Cross-area patterns (≥2 areas)
- Embed inconsistency flags

#### Step 3: Update State

```json
{
  "phase": "synthesis_completed",
  "cross_feature_area_analysis": {
    "cross_area_patterns": 5,
    "inconsistencies": [
      {
        "flag_id": "FLG-001",
        "type": "priority_conflict",
        "severity": "medium",
        "pdrs_affected": ["PDR-003"]
      }
    ]
  },
  "pdrs_generated": 9,
  "workflow": { "init_completed": true }
}
```

### Phase 8: Write PDRs

**Objective**: Write PDRs with cross-area metadata

#### Step 1: Format PDRs

Use template with:
- Cross-feature-area metadata section
- Inconsistency flags (if any)
- Team-TPD comparison

#### Step 2: Write to File

Append to `{REPO_ROOT}/.specify/drafts/pdr.md`:

```markdown
# Product Decision Records

## PDR Index

| ID | Feature-Area | Category | Cross-Area | Status | Date |
|----|--------------|----------|------------|--------|------|
| PDR-001 | business | Business Model | ✓ | Discovered | 2026-01-20 |
| PDR-002 | core | Persona | ✓ | Discovered | 2026-01-20 |
| PDR-003 | business | Prioritization | | Discovered | 2026-01-20 |

---

## Cross-Feature-Area Analysis Summary

### Cross-Area Patterns
| Pattern | Feature-Areas | PDR |
|---------|---------------|-----|
| Admin Persona | core, business | PDR-002 |

### Inconsistencies Flagged
| Flag ID | Type | PDRs Affected | Severity |
|---------|------|---------------|----------|
| FLG-001 | Priority Conflict | PDR-003 | Medium |

---

## PDR-001: Tiered Subscription Model

### Cross-Feature-Area Metadata
- **Appears in**: [business, growth]
- **Cross-area count**: 2
- **Is cross-area pattern**: ✓

### ⚠️ Inconsistency Flags
*None*

...

## PDR-003: UX Prioritization Framework

### ⚠️ Inconsistency Flags
**Flag FLG-001**: Priority Conflict
- **Severity**: Medium
- **Issue**: Core area prioritizes "ease of use" while Business prioritizes "revenue"
- **Recommended Action**: Run `/product.clarify`
```

### Phase 9: Output Summary

```markdown
## Product Init Complete ✓

### Execution Stats
- **Feature-areas analyzed**: 3
- **Discovery Agent runs**: 3
- **Pattern Agent runs**: 3
- **Synthesis Agent runs**: 1

### Patterns Discovered
| Feature-Area | Patterns | High Strategic |
|--------------|----------|----------------|
| core | 5 | 3 |
| business | 6 | 4 |
| growth | 4 | 2 |

### Cross-Feature-Area Analysis
- **Cross-area patterns**: 5 (≥2 areas)
- **Inconsistencies flagged**: 2

### PDRs Generated
| Category | Count | Cross-Area |
|----------|-------|------------|
| Business Model | 2 | ✓ |
| Persona | 3 | ✓ |
| Problem | 2 | |
| Prioritization | 1 | |
| **With Inconsistency Flags** | **2** | |

### Inconsistencies Requiring Clarification
**PDR-003**: Priority Conflict (Core vs Business)
- Run `/product.clarify` to align priorities

### Next Steps
1. Review PDRs: `{REPO_ROOT}/.specify/drafts/pdr.md`
2. **Resolve inconsistencies**: Run `/product.clarify`
3. Generate PRD: Run `/product.implement`
```

## State Management

### State File
`{REPO_ROOT}/.specify/product/state.json`

### Resumability
- `--resume` flag continues from checkpoint
- Skips completed feature-areas
- Preserves intermediate results

## Key Differences from Legacy Init

| Feature | Legacy | Sub-Agent Version |
|---------|--------|-------------------|
| Execution | Single pass | 3-phase pipeline |
| Detection | Directory only | Comprehensive (3 sources) |
| Feature-areas | Parallel | Sequential per-phase |
| Cross-area analysis | None | Full (≥2 areas) |
| Inconsistencies | Manual | Auto-flagged |
| State | None | Full checkpoint |
| Resume | No | Yes |

## Output Files

| File | Description |
|------|-------------|
| `{REPO_ROOT}/.specify/drafts/pdr.md` | Generated PDRs with flags |
| `{REPO_ROOT}/.specify/product/state.json` | Execution state |

## Notes

- Inconsistency flags are embedded in PDRs (not separate)
- Cross-area threshold is ≥2 feature-areas
- Checkpoint in implement is after Requirements (not in init)
- Comprehensive detection uses directory + docs + pricing

## Context

{ARGS}
