# Regulation Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to conform to local and international laws, quasi-legal regulations, company policies, and other rules and standards.

**Include this perspective when:**
- System is subject to laws or regulations (GDPR, HIPAA, PCI-DSS, SOX)
- System handles regulated data (financial, healthcare, personal data)
- System is used in regulated industries
- System needs compliance auditing

**Skip this perspective when:**
- System operates in unregulated industries
- No legal or regulatory requirements apply

## View Applicability

| View | Regulation Concerns |
|------|----------------------|
| Context | Compliance scope |
| Functional | Authorized operations |
| Information | Data governance, retention, privacy |
| Concurrency | Audit trails for regulated processes |
| Development | Compliance in development |
| Deployment | Regulation-compliant deployment |
| Operational | Compliance monitoring, reporting |

## Integration

When generating views (especially Information and Operational), add a **Regulation Considerations** subsection if this perspective applies.

---

## Regulation Perspective

### Applicable Regulations

| Regulation | Jurisdiction | Applicability | Compliance Target |
|------------|--------------|----------------|-------------------|
| [REG_1] | [Jurisdiction] | [Scope] | [Target] |
| [REG_2] | [Jurisdiction] | [Scope] | [Target] |

### Compliance Requirements

| Requirement | Standard | Implementation | View(s) Affected |
|-------------|----------|----------------|------------------|
| [REQ_1] | [Standard] | [Implementation] | [Views] |
| [REQ_2] | [Standard] | [Implementation] | [Views] |

### Data Classification

| Classification | Handling | Retention | Views Affected |
|----------------|----------|-----------|------------|----------------|
| [CLASS_1] | [Handling] | [Retention] | [Views] |
| [CLASS_2] | [Handling] | [Retention] | [Views] |

### Audit & Compliance

- **Audit Logging**: [What's logged, retention]
- **Compliance Reporting**: [Frequency, audience]
- **Compliance Audits**: [Frequency, auditor]
- **Certification**: [Certifications held]

---

**ADR Traceability:**

| ADR | Decision | Impact on Regulation |
|-----|----------|---------------------|
| [ADR-XXX] | [Decision] | [How it affects compliance] |