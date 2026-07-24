---
name: product-analyze
description: Read-only analysis of PDR↔PRD consistency, PDR quality, cross-PDR conflicts, and staleness. Outputs a structured markdown report with severity-assigned findings. Use after /product.implement or periodically to detect drift.
disable-model-invocation: true
---

# product-analyze

## What this skill does

Performs **read-only** product consistency analysis:

1. **PDR Quality** — completeness, clarity, standards compliance
2. **PDR→PRD Drift** — decisions not reflected in PRD
3. **PRD→PDR Drift** — PRD elements without supporting PDRs
4. **Cross-PDR Consistency** — conflicts between PDRs
5. **Staleness** — outdated references, placeholders, deprecated PDRs still referenced

**Output**: Structured markdown analysis report (no files modified)

## When to use

- After `/product.implement` to validate generated PRD
- After `/product.clarify` to verify refinements
- Before feature development to ensure product is solid
- Periodically to detect drift as product evolves

## When NOT to use

- No product artifacts exist (use `/product.init` or `/product.specify` first)
- You want to modify files (this is analysis-only)

## Execution Steps

### Phase 1: Load Artifacts

```bash
sh: scripts/bash/setup-product-analyze.sh [--json]
ps: scripts/powershell/setup-product-analyze.ps1
```

**Read**:
- `PRD.md` (project root)
- `{REPO_ROOT}/.adlc/drafts/pdr/PDR-*.md` (individual PDR files)
- `{REPO_ROOT}/.adlc/memory/constitution.md` (if exists)

**Build inventory**:
```markdown
| Artifact | Path | Status |
|----------|------|--------|
| Product PRD | PRD.md | Found/Missing |
| Product PDRs | .adlc/drafts/pdr/ | [N] files |
| Constitution | .adlc/memory/constitution.md | Found/Missing |
```

### Phase 2: PDR Quality Analysis

For each PDR file, check:

| Dimension | Check | Severity |
|-----------|-------|----------|
| Context | Problem clearly stated | MEDIUM |
| Decision | Actionable, testable | HIGH |
| Consequences | Positive AND negative | HIGH |
| Success Metrics | Defined with targets | HIGH |
| Alternatives | At least 2 with neutral trade-offs | HIGH |
| Constitution | Aligns with vision | CRITICAL |

### Phase 3: Inter-PDR Consistency

1. **Conflicting Decisions**: PDRs that contradict (e.g., B2B vs B2C)
2. **Missing Dependencies**: PDRs that should reference each other
3. **Terminology Drift**: Same concept named differently
4. **Strategy Coherence**: Problem/persona/metric alignment

### Phase 4: PDR→PRD Drift (Forward Sync)

For each PDR, check if decision appears in PRD:

| PDR Element | Expected in PRD | Section |
|-------------|-----------------|---------|
| Problem decision | Problem statement | 3 |
| Persona decision | Personas | 6 |
| Scope decision | Requirements / Out of Scope | 7 / 9 |
| Metric decision | Success Metrics | 5 |
| Business Model | Overview | 2 |
| NFR decision | Non-Functional Requirements | 8 |

### Phase 5: PRD→PDR Drift (Backward Sync)

1. **Requirements Without PDRs**: User stories without scope justification
2. **Personas Without PDRs**: Personas with no persona PDR
3. **Metrics Without PDRs**: Success metrics with no metric PDR
4. **Risks Without PDRs**: Risks without consequence documentation

### Phase 6: Staleness Detection

1. **Deprecated PDRs Still Referenced**: PRD references status "Deprecated"
2. **Placeholders**: `[TODO]`, `[TBD]`, `[PRODUCT_NAME]`, `[DATE]`
3. **Date Inconsistencies**: PDR dates older than PRD last-updated
4. **Orphaned References**: PDR IDs mentioned but file doesn't exist

### Phase 7: Severity Assignment

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Constitution violation, major requirement undocumented |
| **HIGH** | PDR→PRD drift affecting requirements, conflicting PDRs |
| **MEDIUM** | Incomplete consequences, staleness, terminology drift |
| **LOW** | Style improvements, minor documentation gaps |

### Phase 8: Generate Report

```markdown
## Product Analysis Report

### Analysis Summary
| Attribute | Value |
|-----------|-------|
| Mode | [Full/PDRs/Sections] |
| Files Analyzed | [List] |
| Analysis Date | [Current date] |

### Findings
| ID | Pass | Severity | Location | Summary | Recommendation |
|----|------|----------|----------|---------|----------------|
| A1 | PDR Quality | MEDIUM | PDR-003 | Missing success metrics | Add metrics section |
| B1 | Inter-PDR | HIGH | PDR-002, PDR-005 | Conflicting target markets | Resolve B2B vs B2C |
| C1 | PDR→PRD | HIGH | PRD:5 | Persona not in PRD | Update PRD section 5 |
| D1 | PRD→PDR | HIGH | PRD:6 | Feature has no PDR | Create PDR |
| F1 | Staleness | LOW | PRD:1 | [PRODUCT_NAME] placeholder | Fill product name |

### Coverage Metrics
| Metric | Value |
|--------|-------|
| PDR Count | [N] |
| PRD Sections Complete | [N]/12 |
| PDR→PRD Coverage | [N]% |
| PRD→PDR Coverage | [N]% |

### Issue Distribution
| Severity | Count |
|----------|-------|
| CRITICAL | [N] |
| HIGH | [N] |
| MEDIUM | [N] |
| LOW | [N] |

### Next Actions
- **CRITICAL issues**: Resolve constitution violations before proceeding
  - Command: `/product.clarify`
- **HIGH PDR quality**: Address missing alternatives and consequences
  - Command: `/product.clarify`
- **PDR→PRD drift**: Update PRD to reflect PDR decisions
  - Command: `/product.implement --update`
- **PRD→PDR drift**: Create missing PDRs
  - Command: `/product.specify` or `/product.init`
```

## Key Rules

### Analysis Integrity
- **NEVER modify files** — this is read-only
- **NEVER hallucinate missing content** — report absences accurately
- **Prioritize constitution violations** — always CRITICAL
- **Use evidence-based findings** — cite specific locations

### Reporting Standards
- **Limit to 50 findings** — aggregate overflow in summary
- **Include location** — always cite file or section
- **Provide actionable recommendations** — each finding gets a fix suggestion
- **Calculate coverage metrics** — quantify completeness

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `PRD_FILE` — `{REPO_ROOT}/PRD.md`
- `CONSTITUTION` — `{REPO_ROOT}/.adlc/memory/constitution.md`

## 12-Factor Alignment

- **Factor IX (Verification-First)**: Validates artifacts before downstream work
- **Factor XI (Directives as Code)**: Checks version-controlled directive quality

## Verification

- [ ] All artifacts loaded and inventoried
- [ ] PDR quality checklist applied to each file
- [ ] Cross-PDR consistency verified
- [ ] Bidirectional drift detection completed
- [ ] Staleness scan performed
- [ ] Severities assigned correctly
- [ ] Report structured with findings table
- [ ] Coverage metrics calculated
- [ ] Next actions recommended with commands
- [ ] Zero files modified
