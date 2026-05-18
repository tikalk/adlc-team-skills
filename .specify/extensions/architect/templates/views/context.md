# Context View: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## 3.1 Context View

**Purpose**: Define system scope and external interactions

### 3.1.1 System Scope

[High-level description of what the system does and its boundaries]

### 3.1.2 External Entities

| Entity | Type | Interaction Type | Data Exchanged | Protocols |
|--------|------|------------------|----------------|-----------|
| [ENTITY_1] | User/System/API | [e.g., REST API, UI] | [e.g., User credentials] | [e.g., HTTPS] |
| [ENTITY_2] | [External System] | [Integration method] | [Data format] | [Protocol] |

### 3.1.3 Context Diagram

> **CRITICAL: Blackbox Requirement** - The system MUST appear as a single node. Do NOT show internal databases, services, or caches here (those belong in Deployment/Functional views).

```mermaid
graph TD
    %% Stakeholders (human actors)
    Users["Users/Clients"]
    Admins["Administrators"]
    
    %% THE SYSTEM - Single blackbox
    System["System<br/>(This Application)"]
    
    %% External Systems (third-party, outside your control)
    ExtPayment["Payment Provider<br/>(External)"]
    ExtAuth["Identity Provider<br/>(External)"]
    
    %% Stakeholder interactions
    Users -->|"Uses"| System
    Admins -->|"Manages"| System
    
    %% External system integrations
    System -->|"Processes payments"| ExtPayment
    System -->|"Authenticates via"| ExtAuth
    
    classDef systemNode fill:#f47721,stroke:#333,stroke-width:3px,color:#fff
    classDef stakeholderNode fill:#4a9eff,stroke:#333,stroke-width:1px,color:#fff
    classDef externalNode fill:#e0e0e0,stroke:#333,stroke-width:1px
    
    class System systemNode
    class Users,Admins stakeholderNode
    class ExtPayment,ExtAuth externalNode
```

### 3.1.4 External Dependencies

| Dependency | Purpose | SLA Expectations | Fallback Strategy |
|------------|---------|------------------|-------------------|
| [DEPENDENCY_1] | [Purpose] | [e.g., 99.9% uptime] | [e.g., Cache, degraded mode] |

---

## Perspective Considerations

_The following perspectives are applied to this view based on system requirements._

### Security Considerations

[Security concerns - e.g., external trust zones, entry points, authentication boundaries]
[See: templates/perspectives/security.md]

_Source ADRs: [ADR-XXX]_

### Performance Considerations

[Performance concerns - e.g., external SLAs, integration latency expectations]
[See: templates/perspectives/performance.md]

_Source ADRs: [ADR-XXX]_

### Location Considerations

[Location concerns - e.g., multi-region dependencies, data residency]
[See: templates/perspectives/location.md]

_Source ADRs: [ADR-XXX]_

### Regulation Considerations

[Regulation concerns - e.g., compliance scope, cross-border restrictions]
[See: templates/perspectives/regulation.md]

_Source ADRs: [ADR-XXX]_

---

**Validation Checklist** (verify before finalizing):

- [ ] System appears as exactly ONE node
- [ ] No internal databases shown (e.g., PostgreSQL, Redis)
- [ ] No internal services shown (e.g., AuthService, UserService)
- [ ] All entities are either stakeholders OR external systems
- [ ] All connections cross the system boundary
