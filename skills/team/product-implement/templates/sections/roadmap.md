# Roadmap & Milestones: [FEATURE_AREA_NAME]

**Feature Area**: [FEATURE_AREA_NAME]
**PDRs Referenced**: [PDR_IDS]
**Generated**: [DATE]
**Dependencies**: Requirements, Metrics

---

## 11. Roadmap & Milestones

**Purpose**: Define product release milestones with feature groupings

### 11.1 Roadmap Overview

```mermaid
gantt
    title Product Development Roadmap
    dateFormat YYYY-MM-DD
    axisFormat %b %Y
    
    section Foundation
    Authentication       :done, auth, 2024-01-01, 30d
    User Profile         :done, profile, after auth, 20d
    Core Infrastructure  :active, infra, after profile, 25d
    
    section Business
    Billing Setup        :billing, after infra, 20d
    Payment Processing   :payment, after billing, 25d
    Subscription Mgmt    :sub, after payment, 15d
    
    section Growth
    Analytics Dashboard  :analytics, after payment, 30d
    API Access           :api, after infra, 20d
    Developer Portal     :portal, after api, 25d
    
    section Milestones
    Alpha Release        :milestone, m1, 2024-02-15, 0d
    Beta Release         :milestone, m2, 2024-04-01, 0d
    GA Release           :milestone, m3, 2024-05-15, 0d
```

### 11.2 Milestone 1: [Name] - [Target Date]

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

**PDR Reference:** PDR-XXX

---

### 11.3 Milestone 2: [Name] - [Target Date]

**Demo Sentence:** "After this milestone, the user can: [observable capability]"

**Status:** Planned | In Progress | Complete

**Release Goal:** [What this milestone achieves]

| Feature | Priority | Demo Sentence | Dependencies |
|---------|----------|---------------|--------------|
| [Feature spec name] | Must | "user can ___" | None (leaf) |
| [Feature spec name] | Should | "user can ___" | Depends on [Feature] |

**Features Deferred from Previous:**

- [Feature] - deferred to this milestone

**Success Criteria:**

| Metric | Target | Measurement |
|--------|--------|-------------|
| [Metric] | [Target] | [Method] |

**PDR Reference:** PDR-XXX

---

### 11.4 Milestone 3: [Name] - [Target Date]

**Demo Sentence:** "After this milestone, the user can: [observable capability]"

**Status:** Planned | In Progress | Complete

**Release Goal:** [What this milestone achieves]

| Feature | Priority | Demo Sentence | Dependencies |
|---------|----------|---------------|--------------|
| [Feature spec name] | Must | "user can ___" | None (leaf) |

**PDR Reference:** PDR-XXX

---

### 11.5 Milestones Traced to PDRs

| Milestone | PDR | Target Date | Status |
|-----------|-----|-------------|--------|
| Milestone 1 | PDR-XXX | [Date] | [Status] |
| Milestone 2 | PDR-XXX | [Date] | [Status] |
| Milestone 3 | PDR-XXX | [Date] | [Status] |

---

**PDR Traceability:**

| PDR | Decision | Impact on Roadmap |
|-----|----------|-------------------|
| [PDR-XXX] | [Decision] | [How it shapes milestones] |
