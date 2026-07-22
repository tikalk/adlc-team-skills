---
name: product-init
description: Reverse-engineer Product Decision Records (PDRs) from an existing codebase and documentation using multi-agent feature-area analysis (brownfield). Use when documenting product decisions inferred from an already-built product.
disable-model-invocation: true
---

# product-init

## What this skill does

Reverse-engineers product decisions from an **existing product** using a **three-phase analysis pipeline**:

1. **Discovery Agent**: Scans each feature-area for raw product signals (code, docs, pricing)
2. **Pattern Agent**: Classifies signals into PDR categories, scores strategic importance
3. **Synthesis Agent**: Cross-feature-area analysis, flags inconsistencies

**Output**: Individual `PDR-{NNN}.md` files (status **Discovered**) in `.adlc/drafts/pdr/` with an auto-generated `pdr.md` index.

## When to use

- Existing product with no formal PDRs
- Brownfield codebase needs product documentation
- Team onboarding — walking through product rationale
- Post-acquisition or inherited codebase

## When NOT to use

- New product (use `/product.specify` instead)
- Minor PDR updates (use `/product.clarify` instead)

## Execution Steps

### Phase 0: Environment Setup

**Run setup script** to resolve paths and detect feature-areas:

```bash
sh: scripts/bash/setup-product-init.sh [--json]
ps: scripts/powershell/setup-product-init.ps1
```

**Setup output** (JSON):
```json
{
  "REPO_ROOT": "/path/to/project",
  "PDR_DRAFTS_DIR": "/path/to/project/.adlc/drafts/pdr",
  "PRD_FILE": "/path/to/project/PRD.md",
  "feature_areas": ["core", "business", "growth"],
  "next_pdr": "001"
}
```

**Create directories**:
```bash
mkdir -p "{REPO_ROOT}/.adlc/drafts/pdr"
mkdir -p "{REPO_ROOT}/.adlc/product"
```

### Phase 1: Feature-Area Detection

Detect feature-areas from **three sources**:

| Source | Detection Pattern |
|---|---|
| Directory Structure | `src/auth/`, `features/payments/`, `modules/` |
| Documentation | README sections, existing PRD, ROADMAP |
| Pricing Tiers | Starter/Pro/Enterprise feature mapping |

**Present detected areas**:
```markdown
## Detected Feature-Areas

| # | Feature-Area | Sources | Evidence |
|---|--------------|---------|----------|
| 1 | **Core** | Directory + Docs | src/users/, README "Core Features" |
| 2 | **Business** | Directory + Pricing | src/billing/, pricing.md tiers |

Reply: Y to confirm, n for monolithic, or suggest changes.
```

**Threshold Logic**:
- ≤3 areas: Auto-approve
- 4-6 areas: Confirm with user
- >6 areas: Suggest grouping

### Phase 2: Discovery Agent (Per Feature-Area)

For each feature-area in order:

1. **Scan directory** for monetization signals, user flows, features
2. **Analyze documentation** (README, PRD, pricing)
3. **Identify pricing tier mappings**
4. **Document evidence**

**Progress report per area**:
```
Discovery Agent: business feature-area
├── Directory signals: 4
├── Documentation signals: 2
├── Pricing signals: 1
└── Status: ✓ Completed
```

### Phase 3: Pattern Agent (Per Feature-Area)

For each feature-area:

1. **Categorize signals** into PDR categories (Problem, Persona, Scope, Metric, etc.)
2. **Score strategic importance** (0.0-1.0)
3. **Check for duplicates** against existing PDRs
4. **Identify cross-area candidates**

### Phase 4: Synthesis Agent (Cross-Feature-Area)

**1. Cross-Area Pattern Detection**:
```json
{
  "pattern_id": "P001",
  "pattern_name": "Admin Persona",
  "feature_area_presence": {"core": true, "business": true},
  "is_cross_area": true
}
```

**2. Inconsistency Detection**:
- Priority conflicts
- Duplicate problems
- Inconsistent metrics
- Generate flags (embedded in affected PDRs)

**3. PDR Generation**: High-strategic patterns (>0.7) and cross-area patterns (≥2 areas)

### Phase 5: Write Individual PDR Files

For each discovered PDR:

1. **Assign ID**: PDR-{NNN} using next available number
2. **Write file**: `{REPO_ROOT}/.adlc/drafts/pdr/PDR-{NNN}.md`

**PDR file format** (individual file, no frontmatter):
```markdown
## PDR-001: [Decision Title]

### Status

**Discovered** (Inferred from existing product)

### Date

YYYY-MM-DD

### Owner

[Inferred from codebase/authors]

### Category

[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR]

### Feature-Area

[core | business | growth | ...]

### Cross-Feature-Area Metadata
- **Appears in**: [business, growth]
- **Cross-area count**: 2
- **Is cross-area pattern**: ✓

### ⚠️ Inconsistency Flags
*None* (or flag details if detected)

### Context
**Problem/Opportunity:**
[Clear description]

**Market Forces:**
- [Market factor 1]
- [Customer feedback]

### Decision
**Decision Statement:**
[Clear statement]

**Rationale:**
[Why this option]

### Consequences
#### Positive
- [Benefit 1]

#### Negative
- [Trade-off 1]

#### Risks
- [Risk with mitigation]

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [Method] |

### Alternatives Considered
#### Option A: [Alternative Name]
**Description:** [Brief description]
**Trade-offs:** [Neutral comparison]
```

### Phase 6: Regenerate PDR Index

Generate `{REPO_ROOT}/.adlc/drafts/pdr/pdr.md` from all `PDR-*.md` files:

```bash
# For each PDR-*.md file, extract ID, title, status, date
# Build index table
```

**Index format**:
```markdown
# Product Decision Records

## PDR Index

| ID | Feature-Area | Category | Status | Date | Owner |
|----|--------------|----------|--------|------|-------|
| PDR-001 | business | Business Model | Discovered | 2026-01-20 | [Inferred] |
| PDR-002 | core | Persona | Discovered | 2026-01-20 | [Inferred] |

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

*Individual PDR files are in this directory (PDR-*.md)*
```

### Phase 7: Output Summary

```markdown
## Product Init Complete ✓

### Execution Stats
- **Feature-areas analyzed**: 3
- **Discovery Agent runs**: 3
- **Pattern Agent runs**: 3
- **Synthesis Agent runs**: 1

### PDRs Generated
| Category | Count | Cross-Area |
|----------|-------|------------|
| Business Model | 2 | ✓ |
| Persona | 3 | ✓ |
| Problem | 2 | |
| Prioritization | 1 | |
| **With Inconsistency Flags** | **2** | |

### Next Steps
1. Review PDRs: `{REPO_ROOT}/.adlc/drafts/pdr/`
2. **Resolve inconsistencies**: Run `/product.clarify`
3. Generate PRD: Run `/product.implement`
```

## PDR Numbering Rules

- Scan `{REPO_ROOT}/.adlc/drafts/pdr/` for existing `PDR-*.md` files
- Extract numeric suffix, find maximum
- Next PDR = max + 1, zero-padded to 3 digits (PDR-001, PDR-002, ...)
- Never reuse numbers, even for deleted PDRs

## State Management

**State file**: `{REPO_ROOT}/.adlc/product/state.json`

```json
{
  "version": "1.0",
  "command": "product-init",
  "created_at": "2026-01-20T10:00:00Z",
  "phase": "completed",
  "feature_areas": [
    {"id": "core", "name": "Core", "progress": {"discovery": "completed", "pattern": "completed"}}
  ],
  "pdrs_generated": 9,
  "cross_area_patterns": 5,
  "inconsistencies": 2
}
```

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr` (individual PDR files)
- `PDR_INDEX` — `{REPO_ROOT}/.adlc/drafts/pdr/pdr.md` (auto-generated index)
- `PRD_FILE` — `{REPO_ROOT}/PRD.md`
- `STATE_FILE` — `{REPO_ROOT}/.adlc/product/state.json`

## 12-Factor Alignment

- **Factor III (Mission Definition)**: Discovers the "what & why" behind existing code
- **Factor IX (Traceability)**: Every inferred decision is documented with evidence

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The code is self-documenting." | Code shows *how*, not *why*. PDRs capture rationale that code cannot. |
| "I'll just read the README." | READMEs describe features, not decisions. PDRs capture the decision tree. |
| "Brownfield products don't need PDRs." | Every product has implicit decisions. Making them explicit prevents repeated mistakes. |

## Red Flags

- **Generating PDRs without codebase evidence** — brownfield PDRs must be grounded in actual code/docs, not fabricated rationales.
- **Skipping inconsistency flags** — cross-area conflicts are real signals, not noise.
- **Assigning "Proposed" status to discovered PDRs** — brownfield PDRs are **Discovered**, not proposed.

## Verification

- [ ] Setup script returns valid JSON with all paths
- [ ] `.adlc/drafts/pdr/` directory exists
- [ ] At least one `PDR-*.md` file created with status "Discovered"
- [ ] `pdr.md` index auto-generated with correct table
- [ ] State file written to `.adlc/product/state.json`
- [ ] Inconsistency flags embedded in affected PDRs (not separate files)
- [ ] Cross-feature-area analysis summary in index
- [ ] No duplicate PDR IDs
