# Product Requirements Document: [PRODUCT_NAME]

**Version:** X.X  
**Date:** YYYY-MM-DD  
**Author:** [Author]  
**Status:** Draft | Review | Approved  
**PDR Reference:** [.specify/drafts/pdr.md](.specify/drafts/pdr.md)

---

## 1. Overview

[High-level description of the product - what it is and why it exists]

[Derived from Problem PDRs and Vision/Constitution]

### Purpose

[Describe the business/technical problem this product solves]

### Scope

**In Scope:**

- [Core capability 1]
- [Core capability 2]

**Out of Scope:**

- [Explicitly excluded capability 1]
- [Explicitly excluded capability 2]

---

## 2. The Problem

[Problem statement - what pain point or opportunity this product addresses]

**Problem Context:**

- [Current state description]
- [Pain points experienced by users]
- [Impact of not solving this problem]

**Derived from:** PDR-XXX (Problem category)

---

## 3. Goals/Objectives

- **Primary Goal:** [Main product objective - what success looks like]
- **Technical Goal:** [Technical outcomes required]
- **Business Goal:** [Business value delivered]

**Goals traced to PDRs:**

| Goal | PDR | Category |
|------|-----|----------|
| [Goal] | PDR-XXX | [Category] |

---

## 4. Success Metrics

- **Adoption:** [Metric and target]
- **Engagement:** [Metric and target]
- **Revenue/Value:** [Metric and target]
- **Quality:** [Metric and target]

**Metrics traced to PDRs:**

| Metric | Target | PDR |
|--------|--------|-----|
| [Metric] | [Target] | PDR-XXX |

---

## 5. Personas

- **Primary Persona:** [Persona Name]
  - **Role:** [Job title/function]
  - **Needs:** [What they need from this product]
  - **Success Quote:** "[How they describe success]"
  - **PDR Reference:** PDR-XXX

- **Secondary Persona:** [Persona Name]
  - **Role:** [Job title/function]
  - **Needs:** [What they need from this product]
  - **Success Quote:** "[How they describe success]"
  - **PDR Reference:** PDR-XXX

---

## 6. Functional Requirements

### User Stories

| ID | Story | Persona | Priority | PDR |
|----|-------|---------|----------|-----|
| US-001 | [As a... I want to... So that...] | [Persona] | Must | PDR-XXX |
| US-002 | [As a... I want to... So that...] | [Persona] | Should | PDR-XXX |

### Feature Requirements

#### Feature 1: [Feature Name]

**Description:** [What the feature does]

**Requirements:**

- **REQ-001:** [Specific requirement]
- **REQ-002:** [Specific requirement]

**Acceptance Criteria:**

- [ ] [Criterion 1]
- [ ] [Criterion 2]

**Traced to:** PDR-XXX (Scope/Feature category)

#### Feature 2: [Feature Name]

**Description:** [What the feature does]

**Requirements:**

- **REQ-003:** [Specific requirement]
- **REQ-004:** [Specific requirement]

**Acceptance Criteria:**

- [ ] [Criterion 1]
- [ ] [Criterion 2]

**Traced to:** PDR-XXX (Scope/Feature category)

---

## 7. Non-Functional Requirements (NFRs)

### Performance

- [Performance requirement 1]
- [Performance requirement 2]

### Security

- [Security requirement 1]
- [Security requirement 2]

### Reliability

- [Reliability requirement 1]
- [Reliability requirement 2]

### Usability

- [Usability requirement 1]
- [Usability requirement 2]

### Scalability

- [Scalability requirement 1]
- [Scalability requirement 2]

**NFRs traced to PDRs:**

| NFR | Requirement | PDR |
|-----|--------------|-----|
| [Type] | [Requirement] | PDR-XXX |

---

## 8. Out of Scope

- **Features:**
  - [Explicitly excluded feature 1]
  - [Explicitly excluded feature 2]

- **Technical:**
  - [Technical exclusion 1]
  - [Technical exclusion 2]

- **Markets:**
  - [Market exclusion 1]
  - [Market exclusion 2]

**Scope decisions traced to PDRs:**

| Out of Scope | PDR | Rationale |
|--------------|-----|-----------|
| [Item] | PDR-XXX | [Why excluded] |

---

## 9. Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation Strategy | PDR |
|------|------------|--------|---------------------|-----|
| [Risk description] | H/M/L | H/M/L | [Mitigation approach] | PDR-XXX |

### Technical Risks

- [Technical risk 1]

### Market Risks

- [Market risk 1]

### Operational Risks

- [Operational risk 1]

*Risks traced to PDR consequence sections*

---

## 10. Roadmap & Milestones

<!-- Generated from Milestone PDRs -->

### Milestone 1: [Name] - [Target Date]

**Demo Sentence:** "After this milestone, the user can: [observable capability]"

**Status:** Planned | In Progress | Complete

**Release Goal:** [What this milestone achieves]

| Feature | Priority | Demo Sentence | Dependencies |
|---------|----------|---------------|--------------|
| [Feature spec name] | Must | "user can ___" | None (leaf) |
| [Feature spec name] | Must | "user can ___" | Depends on [Feature] |
| [Feature spec name] | Should | "user can ___" | Depends on [Feature], [Feature] |

**Success Criteria:**

| Metric | Target | Measurement |
|--------|--------|-------------|
| [Metric] | [Target] | [Method] |

---

### Milestone 2: [Name] - [Target Date]

**Demo Sentence:** "After this milestone, the user can: [observable capability]"

**Status:** Planned | In Progress | Complete

**Release Goal:** [What this milestone achieves]

| Feature | Priority | Demo Sentence | Dependencies |
|---------|----------|---------------|--------------|
| [Feature spec name] | Must | "user can ___" | None (leaf) |
| [Feature spec name] | Should | "user can ___" | Depends on [Feature] |

**Features Deferred from Previous:**

- [Feature] - deferred to this milestone

---

### Milestone 3: [Name] - [Target Date]

**Demo Sentence:** "After this milestone, the user can: [observable capability]"

**Status:** Planned | In Progress | Complete

**Release Goal:** [What this milestone achieves]

| Feature | Priority | Demo Sentence | Dependencies |
|---------|----------|---------------|--------------|
| [Feature spec name] | Must | "user can ___" | None (leaf) |

---

**Milestones traced to PDRs:**

| Milestone | PDR | Target Date |
|-----------|-----|--------------|
| Milestone 1 | PDR-XXX | [Date] |
| Milestone 2 | PDR-XXX | [Date] |
| Milestone 3 | PDR-XXX | [Date] |

---

## 11. PDR Summary

Detailed Product Decision Records are maintained in [.specify/drafts/pdr.md](.specify/drafts/pdr.md).

### Key Decisions

| ID | Category | Decision | Status | Impact |
|----|----------|----------|--------|--------|
| PDR-001 | [Category] | [Title] | Accepted | High/Med/Low |
| PDR-002 | [Category] | [Title] | Accepted | High/Med/Low |

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| PRD | Product Requirements Document - this document |
| PDR | Product Decision Record - documented product decisions |
| NFR | Non-Functional Requirement |

### B. References

- [Product vision document]
- [Market research]
- [Competitive analysis]
- [User research findings]
- [Relevant PDRs]

### C. Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | YYYY-MM-DD | [Author] | Initial version |
