<!-- 
TEMPLATE COMPLIANCE v1.5.2 - THIS IS A TEMPLATE, MUST BE FILLED:
✓ Use Mermaid diagrams (NOT ASCII art) - flowchart for dependencies
✓ Fill ALL [PLACEHOLDERS] with actual content
✓ Trace ALL requirements to source PDRs
✓ Use REQ-XXX format for requirements
✓ Validate with: ./scripts/validate-prd.sh --strict
NOTE: In final PRD, this becomes Section 7 (Requirements)
-->

# Functional Requirements: [FEATURE_AREA_NAME]

**Feature Area**: [FEATURE_AREA_NAME]
**PDRs Referenced**: [PDR_IDS]
**Generated**: [DATE]
**Dependencies**: Personas, Goals
**Section Number**: 7 (in final PRD)

> 🛑 **CHECKPOINT SECTION v1.5.2**: This is the **cornerstone** section that shapes NFRs, Out-of-Scope, Risks, and Roadmap. After generating this section, execution MUST pause for user approval before continuing.
>
> **Why?** Requirements define what gets built, what doesn't (Out-of-Scope), associated risks, and roadmap priority. User approval ensures alignment.
>
> **Checkpoint Options**:
> - **A) Approve**: Continue to NFRs, Out-of-Scope, Risks, Roadmap
> - **B) Modify**: Edit requirements now, then continue
> - **C) Restart**: Regenerate from Problem phase
> - **D) Cancel**: Stop execution

---

## 7. Functional Requirements

**Purpose**: Define what the product must do

### 7.1 User Stories

| ID | Story | Persona | Priority | PDR |
|----|-------|---------|----------|-----|
| US-001 | As a [persona], I want to [action] so that [benefit] | [Persona] | Must | PDR-XXX |
| US-002 | As a [persona], I want to [action] so that [benefit] | [Persona] | Should | PDR-XXX |
| US-003 | As a [persona], I want to [action] so that [benefit] | [Persona] | Could | PDR-XXX |

### 7.2 Feature Requirements

#### Feature 1: [Feature Name]

**Description:** [What the feature does]

**Requirements:**

- **REQ-001:** [Specific requirement]
- **REQ-002:** [Specific requirement]

**Acceptance Criteria:**

- [ ] [Criterion 1 - testable]
- [ ] [Criterion 2 - testable]
- [ ] [Criterion 3 - testable]

**Traced to:** PDR-XXX (Scope/Feature category)

#### Feature 2: [Feature Name]

**Description:** [What the feature does]

**Requirements:**

- **REQ-003:** [Specific requirement]
- **REQ-004:** [Specific requirement]

**Acceptance Criteria:**

- [ ] [Criterion 1 - testable]
- [ ] [Criterion 2 - testable]

**Traced to:** PDR-XXX (Scope/Feature category)

### 7.3 Requirements Priority Matrix

| Priority | Count | Description |
|----------|-------|-------------|
| Must | [N] | Critical for launch |
| Should | [N] | Important but not blocking |
| Could | [N] | Nice to have |
| Won't | [N] | Explicitly excluded |

---

**PDR Traceability:**

| PDR | Decision | Impact on Requirements |
|-----|----------|------------------------|
| [PDR-XXX] | [Decision] | [How it defines requirements] |

### 7.4 Requirement Dependencies

Visual representation of dependencies between requirements:

```mermaid
flowchart LR
    subgraph "Foundation Layer"
        REQ001["REQ-001:<br/>User Authentication"]
        REQ002["REQ-002:<br/>User Profile"]
    end
    
    subgraph "Business Layer"
        REQ003["REQ-003:<br/>Billing Setup"]
        REQ004["REQ-004:<br/>Payment Processing"]
    end
    
    subgraph "Growth Layer"
        REQ005["REQ-005:<br/>Analytics Dashboard"]
        REQ006["REQ-006:<br/>API Access"]
    end
    
    %% Dependencies
    REQ001 -->|"prerequisite"| REQ002
    REQ002 -->|"enables"| REQ003
    REQ001 -->|"required for"| REQ004
    REQ003 -->|"depends on"| REQ004
    REQ002 -->|"provides data"| REQ005
    REQ001 -->|"authorization"| REQ006
    REQ004 -->|"feeds events"| REQ005
    
    %% Styling
    classDef foundation fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    classDef business fill:#66c2a5,stroke:#333,stroke-width:2px,color:#fff
    classDef growth fill:#f47721,stroke:#333,stroke-width:2px,color:#fff
    
    class REQ001,REQ002 foundation
    class REQ003,REQ004 business
    class REQ005,REQ006 growth
```

**Dependency Notes**:
- Foundation layer requirements must be completed first
- Business layer builds on foundation
- Growth layer features can proceed in parallel after foundation
- Critical path: REQ-001 → REQ-002 → REQ-003 → REQ-004

### 7.5 Feature Dependencies

Cross-feature dependency map showing how features relate to each other:

```mermaid
flowchart LR
    F1["Feature 1:<br/>[Feature Name]"]
    F2["Feature 2:<br/>[Feature Name]"]
    F3["Feature 3:<br/>[Feature Name]"]
    F4["Feature 4:<br/>[Feature Name]"]

    F1 -->|"required by"| F2
    F1 -->|"enables"| F3
    F2 -->|"feeds into"| F4
    F3 -->|"optional for"| F4

    classDef core fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    classDef dependent fill:#66c2a5,stroke:#333,stroke-width:2px,color:#fff

    class F1,F2 core
    class F3,F4 dependent
```

### 7.6 State Transitions

> **Note**: Include state diagrams only when the feature involves stateful entities (e.g., orders, subscriptions, workflows). Omit this subsection if all requirements are stateless operations.

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Submitted : submit()
    Submitted --> InReview : assign_reviewer()
    InReview --> Approved : approve()
    InReview --> Rejected : reject()
    Rejected --> Draft : revise()
    Approved --> Active : activate()
    Active --> Suspended : suspend()
    Suspended --> Active : reactivate()
    Active --> [*] : complete()
```

> 📋 **Related Visuals**: See [State Machine](../../visuals/state-machine.md) for detailed state transitions.
