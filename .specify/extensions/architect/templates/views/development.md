# Development View: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]
**Dependencies**: Functional View

---

## 3.5 Development View

**Purpose**: Constraints for developers - code organization, dependencies, CI/CD

### 3.5.1 Code Organization

```text
project-root/
├── src/
│   ├── api/              # API endpoints
│   ├── services/         # Business logic
│   ├── models/           # Data models
│   └── repositories/     # Data access
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── infra/                # Infrastructure as code
```

### 3.5.2 Module Dependencies

**Dependency Rules:**

- API layer depends on Services layer (not vice versa)
- Services layer depends on Repositories layer
- No circular dependencies allowed

```mermaid
graph LR
    API["API Layer"]
    SVC["Service Layer"]
    REPO["Repository Layer"]
    
    API --> SVC
    SVC --> REPO
    
    classDef layer fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    class API,SVC,REPO layer
```

### 3.5.3 Build & CI/CD

- **Build System**: [e.g., npm, gradle, cargo]
- **CI Pipeline**: [Key stages]
- **Deployment Strategy**: [e.g., Blue-green, rolling]

### 3.5.4 Development Standards

- **Coding Standards**: [e.g., ESLint config, PEP 8]
- **Review Requirements**: [e.g., 2 approvals]
- **Testing Requirements**: [e.g., 80% coverage]

---

## Perspective Considerations

_The following perspectives are applied to this view based on system requirements._

### Security Considerations

[Security concerns - e.g., SAST/DAST integration, secure coding standards, dependency scanning]
[See: templates/perspectives/security.md]

_Source ADRs: [ADR-XXX]_

### Performance Considerations

[Performance concerns - e.g., build/test performance, development environment responsiveness]
[See: templates/perspectives/performance.md]

_Source ADRs: [ADR-XXX]_

### Evolution Considerations

[Evolution concerns - e.g., modular design, build systems, maintainability]
[See: templates/perspectives/evolution.md]

_Source ADRs: [ADR-XXX]_

### Development Resource Considerations

[Development resource concerns - e.g., team skills, tooling, build process optimization]
[See: templates/perspectives/development-resource.md]

_Source ADRs: [ADR-XXX]_

---

**ADR Traceability:**

| ADR | Decision | Impact on Development View |
|-----|----------|----------------------------|
| [ADR-XXX] | [Decision] | [How it affects this view] |
