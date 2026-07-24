# Location Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to overcome problems brought about by the absolute location of its elements and the distances between them.

**Include this perspective when:**
- System is deployed across multiple geographic regions
- System has distributed components (edge, fog, cloud in multiple regions)
- System has latency-sensitive operations across geographic distances
- Data residency requirements exists (data must stay in specific locations)

**Skip this perspective when:**
- System is deployed in a single location
- Geographic distribution is not a concern

## View Applicability

| View | Location Concerns |
|------|-------------------|
| Context | Multi-region dependencies |
| Functional | Region-aware routing |
| Information | Data residency requirements |
| Concurrency | Distributed processing |
| Deployment | Multi-region deployment |
| Operational | Distributed operations |

## Integration

When generating views (especially Deployment and Context), add a **Location Considerations** subsection if this perspective applies.

---

## Location Perspective

### Geographic Distribution

| Location | Components | Data Residency | Latency Requirements |
|----------|------------|----------------|-------------------|
| [REGION_1] | [Components] | [Yes/No] | [Requirements] |
| [REGION_2] | [Components] | [Yes/No] | [Requirements] |

### Data Residency

| Data Class | Required Region | Legal Basis |
|------------|----------------|-------------|
| [DATA_1] | [Region] | [Regulation] |
| [DATA_2] | [Region] | [Regulation] |

### Distribution Tactics

| Tactic | Implementation | Purpose |
|--------|----------------|----------|
| Edge deployment | [Implementation] | [Reduce latency] |
| CDN usage | [Implementation] | [Static content delivery] |
| Geo-routing | [Implementation] | [Route to nearest region] |
| Database replication | [Implementation] | [Data proximity] |
| Read replicas | [Implementation] | [Query latency] |

### Inter-Site Communication

- **Link Type**: [Dedicated lines, VPN, Internet]
- **Bandwidth**: [Capacity]
- **Redundancy**: [Multi-path, failover]

---

**ADR Traceability:**

| ADR | Decision | Impact on Location |
|-----|----------|-------------------|
| [ADR-XXX] | [Decision] | [How it affects geographic distribution] |