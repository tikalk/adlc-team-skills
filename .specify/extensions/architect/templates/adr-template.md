# Architecture Decision Records

## ADR Index

| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|
| ADR-001 | System | [First decision title] | Proposed | YYYY-MM-DD | [Owner] |

---

## ADR-001: [Decision Title]

### Status

**Proposed** | Accepted | Deprecated | Superseded by ADR-XXX | **Discovered** (Inferred from codebase)

### Date

YYYY-MM-DD

### Owner

[Decision maker or team]

### Sub-System

[System | Auth | Payments | Users | Inventory | (other sub-system name)]

This field indicates which sub-system this ADR belongs to. Use "System" for cross-cutting decisions that affect the entire architecture.

### Context

Describe the issue motivating this decision. What is the problem or opportunity? What constraints exist?

**Problem Statement:**
[Clear description of what needs to be decided]

**Forces:**

- [Force 1 - technical, business, or organizational factor]
- [Force 2 - competing concern or constraint]
- [Force 3 - quality attribute requirement]

### Decision

State the decision that was made. Use active voice: "We will..." or "The system will..."

**Decision:**
[Clear statement of what was decided]

**Rationale:**
[Why this option was chosen over alternatives]

### Consequences

#### Positive

- [Benefit 1]
- [Benefit 2]

#### Negative

- [Trade-off 1]
- [Trade-off 2]

#### Risks

- [Risk 1 with mitigation strategy]
- [Risk 2 with monitoring approach]

### Common Alternatives

#### Option A: [Alternative Name]

**Description:** [Brief description]
**Trade-offs:** [Neutral comparison - when this would be better/worse, not "rejected because"]

#### Option B: [Alternative Name]

**Description:** [Brief description]
**Trade-offs:** [Neutral comparison]

### Constitution Alignment

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| [Principle Name] | ✅ Compliant / ⚠️ Deviation / ❌ Override | [Explanation] |

**Constitution References**:

- [Link to relevant constitutional principles]

**Override Justification** (if applicable):
[Why this ADR deviates from constitution guidance]

### Related ADRs

- [ADR-XXX: Related decision]

### References

- [Link to documentation, RFC, or discussion]

---

## MADR Template Quick Reference

**Status Values:**

- **Proposed**: Decision under discussion
- **Accepted**: Decision approved and in effect
- **Deprecated**: Decision no longer applicable
- **Superseded**: Replaced by newer decision (reference successor ADR)
- **Discovered**: Inferred from existing codebase (brownfield reverse-engineering)

**Good ADR Practices:**

- One decision per ADR
- Keep context concise but complete
- Document all seriously considered alternatives
- Be honest about trade-offs and risks
- Link related decisions for traceability
- Update status when decisions evolve

**Integration with Architecture:**

- System-level ADRs go in `.specify/memory/adr.md`
- System-level ADRs should reference the Architecture Description (AD.md)
- This template is for system-level architectural decisions only
