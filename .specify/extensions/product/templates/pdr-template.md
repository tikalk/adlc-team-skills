# Product Decision Records

## PDR Index

| ID | Category | Cross-Area | Status | Date | Owner |
|----|----------|------------|--------|------|-------|
| PDR-001 | [Category] | ✓ | Proposed | YYYY-MM-DD | [Owner] |
| PDR-002 | [Category] | | Proposed | YYYY-MM-DD | [Owner] |

---

## PDR-001: [Decision Title]

### Status

**Proposed** | Accepted | Deprecated | Superseded by PDR-XXX | **Discovered** (Inferred from existing product)

### Date

YYYY-MM-DD

### Owner

[Product Manager / Team / Stakeholder]

### Category

[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR | **Milestone**]

This field indicates what type of product decision this PDR represents.

### Feature-Area

[core | business | growth | operations | platform | auth | ...]

The primary feature-area this PDR belongs to.

### Cross-Feature-Area Metadata
> Populated automatically when pattern is detected across multiple feature-areas during multi-agent analysis

- **Appears in**: [List of feature-area IDs where pattern was found - e.g., core, business, growth]
- **Cross-area count**: [Number of feature-areas with this pattern]
- **Is cross-area pattern**: [✓ | ] (if appears in ≥2 feature-areas)
- **Strategic score**: [0.0-1.0 calculated by Pattern Agent]
- **Team-product-directives match**: [None | Partial | Exact]
  - **Similar patterns**: [List of similar existing TPD patterns with similarity scores]

### Cross-Feature-Area Analysis

Analysis of pattern across feature-areas:

| Feature-Area | Implementation | Confidence | Evidence | Notes |
|--------------|----------------|------------|----------|-------|
| core | [Pattern details or "Not implemented"] | High/Medium/Low | [File/line refs] | [Any notes] |
| business | [Pattern details or "Not implemented"] | High/Medium/Low | [File/line refs] | [Any notes] |
| growth | [Pattern details or "Not implemented"] | High/Medium/Low | [File/line refs] | [Any notes] |

**Cross-area findings**:
- **Feature-areas with pattern**: [N] of [Total]
- **Implementations consistent**: [Yes/No]
- **Variance noted**: [Description of differences if inconsistent]

### ⚠️ Inconsistency Flags
> Populated by Synthesis Agent when conflicts detected across feature-areas

**Flag [FLG-XXX]**: [Inconsistency Type]
- **Severity**: [High | Medium | Low]
- **Issue**: [Description of conflict]
- **Affected feature-areas**: [List of areas]
- **Conflicting PDRs**: [List of related PDRs]
- **Recommended Action**: Run `/product.clarify` to resolve
- **Resolution**: [Pending | Resolved - see resolution details]

### Team-Product-Directives Comparison

Comparison against existing team-product-directives content:

- **Exact match**: [Yes/No - is this already in TPD?]
- **Similar existing patterns**: 
  - `[pricing/saas-subscription.md]` - Similarity: 0.65 - [Description]
- **Gap identified**: [Yes/No - should this be added to TPD?]
- **Potential conflict**: [Any existing patterns that might conflict]
- **Enhancement opportunity**: [Could enhance existing TPD pattern]

### Context

**Problem/Opportunity:**
[Clear description of what needs to be decided - the product challenge or opportunity]

**Market Forces:**

- [Market factor 1 - competitive pressure, trends]
- [Customer feedback or demand]
- [Industry regulation or standard]
- [Internal business priority]

**Product Vision Alignment:**

- [How this decision relates to product vision]
- [Relevant constitutional principles from vision/strategy]

### Decision

**Decision Statement:**
[Clear statement of what was decided]

**Rationale:**
[Why this option was chosen over alternatives]

### Decision Flow

```mermaid
flowchart LR
    Problem[Problem:<br/>[Problem Statement]] --> Options{Options}
    Options --> A[Option A:<br/>[Alternative A]]
    Options --> B[Option B:<br/>[Chosen Option]]
    Options --> C[Option C:<br/>[Alternative C]]
    
    A -->|Rejected| WhyA[Reason:<br/>[Why not]]
    C -->|Rejected| WhyC[Reason:<br/>[Why not]]
    B -->|Selected| Decision[Decision:<br/>[Decision Statement]]
    
    style B fill:#4a9eff,color:#fff,stroke:#333,stroke-width:2px
    style Decision fill:#f47721,color:#fff,stroke:#333,stroke-width:2px
```

> 💡 **Visual Impact Analysis**: [View detailed impact map](visuals/impact-map.md) for this decision.

### Consequences

#### Positive

- [User benefit 1]
- [Business benefit 1]
- [Metric improvement]

#### Negative

- [Trade-off 1]
- [Opportunity cost 1]
- [User limitation]

#### Risks

- [Market risk with mitigation strategy]
- [Adoption risk with monitoring approach]
- [Revenue risk with contingency]

### Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric name] | [Target value] | [How to measure] |

### Eval Criteria

> **NOTE:** This section enables the eval-as-spec paradigm. Eval criteria transform PDRs into actionable specifications for AI agents. See [PDR-065](./pdr.md#pdr-065-eval-criteria-section-in-pdr-template) for context.

**Pass Condition:**
[Precise spec constraint that defines success - must be measurable and automated]

**Fail Condition:**
[Precise spec violation that defines failure - binary, not scale]

**Failure Type:**

- `specification_failure`: → fix directive (issue is in spec, not implementation)
- `generalization_failure`: → build evaluator (issue is model/agent capability)

**Evaluation Method:**

- `algorithmic`: (string matching, format validation, regex, SQL syntax)
- `llm-judge`: (semantic quality assessment with golden examples)
- `human`: (manual review required - only for deeply subjective cases)

**Eval Dimensions** *(optional)*:

| Dimension | What It Measures | Target |
|-----------|------------------|--------|
| correctness | Does output meet requirements? | >90% |
| efficiency | Time/tokens to completion | <budget |
| style | Code quality, conventions | >80% |
| safety | Security, no harmful outputs | 100% |

### Alternatives Considered

#### Option A: [Alternative Name]

**Description:** [Brief description of alternative]
**Trade-offs:** [Neutral comparison - when this would be better/worse]

#### Option B: [Alternative Name]

**Description:** [Brief description of alternative]
**Trade-offs:** [Neutral comparison]

### Constitution/Vision Alignment

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| [Vision Principle] | ✅ Compliant / ⚠️ Deviation / ❌ Override | [Explanation] |

**Constitution References**:

- [Link to relevant constitutional principles]
- [Link to product vision statement]

**Override Justification** (if applicable):
[Why this PDR deviates from vision/strategy guidance]

### Related PDRs

- [PDR-XXX: Related decision]
- [PDR-XXX: Dependency]

---

## Milestone PDR Fields *(use when Category = Milestone)*

### Release Goal

[What this milestone/release achieves - one sentence]

### Demo Sentence

**After this milestone, the user can:** [observable capability]

### Target Date

[Target release date - e.g., "Q1 2026" or "2026-03-31"]

### Features Included

| Feature Spec | Priority | Demo Sentence | Boundary Dependencies |
|--------------|----------|---------------|----------------------|
| [Feature name] | Must | "user can ___" | None (leaf) |
| [Feature name] | Must | "user can ___" | Depends on [Feature] |
| [Feature name] | Should | "user can ___" | Depends on [Feature], [Feature] |

### Features Deferred

- [Feature deferred to next milestone]
- [Feature deferred to next milestone]

### Milestone Success Criteria

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [How to measure] |

### References

- [Link to documentation, market research, or stakeholder input]
- [Link to competitive analysis]

---

## PDR Template Quick Reference

**Status Values:**

- **Proposed**: Decision under discussion
- **Accepted**: Decision approved and in effect
- **Deprecated**: Decision no longer applicable
- **Superseded**: Replaced by newer decision (reference successor PDR)
- **Discovered**: Inferred from existing product/market (brownfield reverse-engineering)

**Category Values:**

- **Problem**: Target market, core problem solved
- **Persona**: User segments, customer types
- **Scope**: Features included/excluded
- **Metric**: Success criteria, KPIs
- **Prioritization**: What goes in MVP, roadmaps
- **Business Model**: Pricing, monetization, target customer
- **Feature**:- **NFR Specific feature decisions
**: Non-functional requirements (security, performance, etc.)
- **Milestone**: Release planning, feature groupings, roadmap decisions

**Good PDR Practices:**

- One decision per PDR
- Keep context concise but complete
- Document all seriously considered alternatives
- Be honest about trade-offs and risks
- Link related decisions for traceability
- Update status when decisions evolve

**Integration with PRD:**

- Working PDRs go in `.specify/drafts/pdr.md`
- Accepted PDRs go in `.specify/memory/pdr.md` (project canonical)
- PRD synthesizes all PDRs into a cohesive requirements document
- PDRs should reference each other for dependencies
- Conflicts with product vision should be flagged as VIOLATION

**PDR Lifecycle:**

1. init/specify → drafts (Proposed/Discovered status)
2. clarify → drafts (refines in place)
3. implement → Accepted PDRs to memory (.specify/memory)
4. analyze/validate → read from all locations
