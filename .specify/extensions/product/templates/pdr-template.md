# Product Decision Records

## PDR Index

| ID | Category | Decision | Status | Date | Owner |
|----|----------|----------|--------|------|-------|
| PDR-001 | [Category] | [First decision title] | Proposed | YYYY-MM-DD | [Owner] |

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
