# Security Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to reliably control, monitor, and audit who can perform what actions on what resources and to detect and recover from failures in security mechanisms.

**Include this perspective when:**
- System processes sensitive data (PII, credentials, financial)
- System is exposed to external users or networks
- System has regulatory compliance requirements (GDPR, SOC2, HIPAA)
- Any system where security is a concern (most systems)

**Skip this perspective when:**
- Truly isolated internal systems with no security requirements (rare)

## View Applicability

| View | Security Concerns |
|------|-------------------|
| Context | System boundaries, external trust zones, entry points |
| Functional | Authentication model, authorization patterns, secure component interactions |
| Information | Data classification, encryption requirements, access controls, PII handling |
| Concurrency | Process isolation, secure IPC, thread safety for sensitive operations |
| Development | SAST/DAST integration, secure coding standards, dependency scanning |
| Deployment | Network security, secrets management, container security, firewall rules |
| Operational | Security monitoring, audit logging, incident response, patch management |

## Integration

When generating a view, add a **Security Considerations** subsection addressing the relevant concerns from the table above.

---

## 4.1 Security Perspective

### 4.1.1 Authentication & Authorization

- **Identity Provider**: [e.g., OAuth2 via Auth0]
- **Authorization Model**: [e.g., RBAC, ABAC]
- **Session Management**: [e.g., JWT with 1-hour expiry]

### 4.1.2 Data Protection

- **Encryption at Rest**: [e.g., AES-256]
- **Encryption in Transit**: [e.g., TLS 1.3]
- **Secrets Management**: [e.g., AWS Secrets Manager]
- **PII Handling**: [e.g., Data minimization]

### 4.1.3 Threat Model

| Threat | View Affected | Likelihood | Impact | Mitigation |
|--------|---------------|------------|--------|------------|
| [THREAT_1] | [View] | [H/M/L] | [H/M/L] | [Mitigation] |

### 4.1.4 Compliance Requirements

| Requirement | Standard | Status | Notes |
|-------------|----------|--------|-------|
| [REQ_1] | [e.g., GDPR, SOC2] | [Compliant/In Progress] | [Notes] |

---

**ADR Traceability:**

| ADR | Decision | Impact on Security |
|-----|----------|-------------------|
| [ADR-XXX] | [Decision] | [How it affects security] |