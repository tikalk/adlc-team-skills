# Availability & Resilience Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to be fully or partly operational as and when required and to effectively handle failures that could affect system availability.

**Include this perspective when:**
- System has complex or extended availability requirements (24/7)
- System has complex recovery processes (failover, disaster recovery)
- System is high-profile (public-facing, revenue-critical)
- System cannot tolerate significant downtime

**Skip this perspective when:**
- Non-critical internal tools where occasional downtime is acceptable
- Systems where "best effort" availability is sufficient

## View Applicability

| View | Availability Concerns |
|------|----------------------|
| Context | SLA requirements, external dependencies uptime |
| Functional | Service level agreements per operation |
| Information | Data durability requirements, backup needs |
| Concurrency | Failover mechanisms, redundancy |
| Deployment | High-availability configurations |
| Operational | Monitoring, alerting, incident response |

## Integration

When generating views (especially Deployment and Operational), add an **Availability Considerations** subsection if this perspective applies.

---

## Availability & Resilience Perspective

### Availability Requirements

| Service Level | Target | Measurement |
|---------------|--------|-------------|
| Uptime | [e.g., 99.9%] | [Measurement method] |
| Planned Downtime | [e.g., 4h/month] | [Maintenance window] |
| Unplanned Downtime | [e.g., 30min/year] | [Recovery objectives] |
| Time to Repair | [e.g., < 4 hours] | [Recovery objective] |

### Classes of Service

| Class | Availability | Use Case |
|-------|--------------|----------|
| [CLASS_1] | [Target] | [Critical operations] |
| [CLASS_2] | [Target] | [Standard operations] |
| [CLASS_3] | [Target] | [Best effort operations] |

### Failure & Recovery tactics

| Tactic | Implementation | Affected Views |
|--------|----------------|---------------|
| Fault-tolerant hardware | [Implementation] | Deployment, Operational |
| High-availability clustering | [Implementation] | Deployment, Concurrency |
| Transaction logging | [Implementation] | Information |
| Design for failure | [Implementation] | Functional, Deployment |
| Component replication | [Implementation] | Deployment |
| Disaster recovery | [Implementation] | Deployment, Operational |

### Disaster Recovery

- **RTO (Recovery Time Objective)**: [Time target]
- **RPO (Recovery Point Objective)**: [Data loss tolerance]
- **Failover Strategy**: [Manual/Automatic]
- **Backup Strategy**: [Frequency, retention, location]

---

**ADR Traceability:**

| ADR | Decision | Impact on Availability |
|-----|----------|-----------------------|
| [ADR-XXX] | [Decision] | [How it affects availability] |