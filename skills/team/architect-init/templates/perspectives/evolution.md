# Evolution Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to be flexible in the face of the inevitable change that all systems experience after deployment, balanced against the costs of providing such flexibility.

**Include this perspective when:**
- System is expected to have a long lifetime (years)
- System will be widely used across multiple teams
- System requirements are likely to evolve significantly
- System needs to support multiple versions or configurations

**Skip this perspective when:**
- Short-lived systems (prototypes, one-off solutions)
- Systems that will not require significant changes after deployment

## View Applicability

| View | Evolution Concerns |
|------|-------------------|
| Context | Change scope, stakeholder evolution expectations |
| Functional | Extension points, plugin architecture, versioning |
| Information | Schema evolution, data migration |
| Concurrency | N/A for this perspective |
| Development | Modular design, build systems |
| Deployment | Progressive rollouts, rollback capabilities |
| Operational | Feature flags, configuration-driven changes |

## Integration

When generating views (especially Functional and Development), add an **Evolution Considerations** subsection if this perspective applies.

---

## Evolution Perspective

### Change Characteristics

| Dimension | Assessment | Impact |
|-----------|------------|--------|
| Magnitude of change | [Small/Moderate/Large] | [Planning implications] |
| Likelihood of change | [Low/Medium/High] | [Flexibility investment] |
| Timescale for change | [Short/Medium/Long] | [Architecture approach] |
| External drivers | [List] | [Constraints] |

### Evolution Tactics

| Tactic | Implementation | When to Use |
|--------|----------------|-------------|
| Contain change | [Module isolation] | [When to use] |
| Extensible interfaces | [Plugin architecture] | [When to use] |
| Design techniques | [Clean Architecture patterns] | [When to use] |
| Variation points | [Feature flags, config] | [When to use] |
| Standard extension points | [Standardized hooks] | [When to use] |
| Reliable change | [Automated testing] | [When to use] |
| Preserve environments | [Dev/test parity] | [When to use] |

### Extension Points

| Extension Point | Type | Versioning Strategy |
|-----------------|------|---------------------|
| [POINT_1] | [Type] | [Strategy] |
| [POINT_2] | [Type] | [Strategy] |

---

**ADR Traceability:**

| ADR | Decision | Impact on Evolution |
|-----|----------|---------------------|
| [ADR-XXX] | [Decision] | [How it affects evolution capability] |