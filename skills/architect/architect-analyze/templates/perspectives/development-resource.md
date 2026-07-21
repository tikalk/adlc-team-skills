# Development Resource Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to be designed, built, deployed, and operated within known constraints around people, budget, time, and materials.

**Include this perspective when:**
- Significant constraints on development team (size, skills, availability)
- Limited budget for tooling or infrastructure
- Tight deadlines that affect architectural decisions
- Hardware or third-party service budgets are constrained

**Skip this perspective when:**
- Unconstrained resources (rare in real projects)
- This is typically a consideration in most projects

## View Applicability

| View | Development Resource Concerns |
|------|-------------------------------|
| Context | Team constraints, timeline |
| Functional | Feature scope given resources |
| Information | Data scope given resources |
| Concurrency | N/A for this perspective |
| Development | Team skills, tooling, build process |
| Deployment | Infrastructure budget |
| Operational | Operations team constraints |

## Integration

When generating the Development view, add a **Development Resource Considerations** subsection. This perspective often applies to most projects.

---

## Development Resource Perspective

### Resource Constraints

| Resource | Constraint | Impact on Architecture |
|----------|------------|---------------------|
| Team size | [Size] | [Architectural implications] |
| Team skills | [Skills] | [Technology choices] |
| Budget | [Amount] | [Infrastructure, tooling] |
| Timeline | [Duration] | [Scope, approach] |

### Technology Constraints

- **Preferred languages**: [Languages the team knows]
- **Prohibited technologies**: [What to avoid]
- **Existing investments**: [What to reuse]

### Build & Deployment Constraints

| Constraint | Value | Mitigation |
|-----------|-------|------------|
| CI/CD capacity | [Limitation] | [Strategy] |
| Environment limits | [Limits] | [Strategy] |
| Third-party budget | [Amount] | [Cost management] |

### Efficiency Tactics

| Tactic | Implementation | Resource Savings |
|--------|----------------|-----------------|
| Use managed services | [Services] | Development time |
| Reuse components | [Components] | Development time |
| Automate testing | [Automation] | Testing time |
| Simplify deployment | [Approach] | Operations time |
| COTS instead of build | [Products] | Both |

---

**ADR Traceability:**

| ADR | Decision | Impact on Resources |
|-----|----------|--------------------|
| [ADR-XXX] | [Decision] | [How it affects resource requirements] |