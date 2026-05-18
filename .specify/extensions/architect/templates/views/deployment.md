# Deployment View: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]
**Dependencies**: Context View, Functional View

---

## 3.6 Deployment View

**Purpose**: Physical environment - nodes, networks, storage

### 3.6.1 Runtime Environments

| Environment | Purpose | Infrastructure | Scale |
|-------------|---------|----------------|-------|
| Production | Live users | [e.g., AWS EKS] | [e.g., 10 nodes] |
| Staging | Pre-release | [e.g., AWS EKS] | [e.g., 3 nodes] |
| Development | Dev testing | [e.g., Docker Compose] | [e.g., 1 node] |

### 3.6.2 Network Topology

```mermaid
graph TB
    subgraph "Production"
        LB["Load Balancer"]
        
        subgraph "App Tier"
            Web1["Web Server 1"]
            Web2["Web Server 2"]
        end
        
        subgraph "Data Tier"
            DB["Database"]
            Cache["Cache"]
        end
    end
    
    Internet["Internet"] -->|HTTPS| LB
    LB --> Web1
    LB --> Web2
    Web1 --> DB
    Web2 --> DB
    Web1 --> Cache
    Web2 --> Cache
```

### 3.6.3 Hardware Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Web Server | [e.g., 2 cores] | [e.g., 4GB] | [e.g., 20GB] |
| Database | [Specs] | [Specs] | [Specs] |

### 3.6.4 Third-Party Services

| Service | Purpose | Provider | Tier |
|---------|---------|----------|------|
| [SERVICE_1] | [Purpose] | [Provider] | [Tier] |

---

## Perspective Considerations

_The following perspectives are applied to this view based on system requirements._

### Security Considerations

[Security concerns - e.g., network security, secrets management, container security, firewall]
[See: templates/perspectives/security.md]

_Source ADRs: [ADR-XXX]_

### Performance Considerations

[Performance concerns - e.g., scaling strategy, resource allocation, auto-scaling triggers]
[See: templates/perspectives/performance.md]

_Source ADRs: [ADR-XXX]_

### Availability Considerations

[Availability concerns - e.g., high-availability configurations, failover]
[See: templates/perspectives/availability.md]

_Source ADRs: [ADR-XXX]_

### Location Considerations

[Location concerns - e.g., multi-region deployment, data residency requirements]
[See: templates/perspectives/location.md]

_Source ADRs: [ADR-XXX]_

---

**ADR Traceability:**

| ADR | Decision | Impact on Deployment View |
|-----|----------|---------------------------|
| [ADR-XXX] | [Decision] | [How it affects this view] |
