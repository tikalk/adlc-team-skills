# Performance & Scalability Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to predictably execute within its mandated performance profile and to handle increased processing volumes.

**Include this perspective when:**
- System has explicit performance requirements (SLAs, latency targets)
- System is expected to handle significant throughput
- System needs to scale to meet demand
- Any system where performance is a concern (most systems)

**Skip this perspective when:**
- Systems with no performance requirements or constraints

## View Applicability

| View | Performance Concerns |
|------|---------------------|
| Context | External SLAs, integration latency expectations, traffic patterns |
| Functional | Critical paths, component latency budgets, caching opportunities |
| Information | Query patterns, data volume projections, indexing strategy |
| Concurrency | Throughput requirements, parallel processing opportunities, bottlenecks |
| Development | Build/test performance, development environment responsiveness |
| Deployment | Scaling strategy, resource allocation, auto-scaling triggers |
| Operational | Performance monitoring, alerting thresholds, capacity planning |

## Integration

When generating a view, add a **Performance Considerations** subsection addressing the relevant concerns from the table above.

---

## 4.2 Performance & Scalability Perspective

### 4.2.1 Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Response time (p95) | [e.g., <200ms] | [e.g., APM] |
| Throughput | [e.g., 1000 req/s] | [e.g., Load tests] |
| Concurrent users | [e.g., 10,000] | [Method] |

### 4.2.2 Scalability Model

- **Horizontal Scaling**: [Approach and limits]
- **Vertical Scaling**: [Approach and limits]
- **Auto-scaling Triggers**: [e.g., CPU > 70%]

### 4.2.3 Capacity Planning

- **Current Capacity**: [e.g., 5,000 concurrent users]
- **Growth Projections**: [e.g., 20% YoY]
- **Bottlenecks**: [Identified constraints]

### 4.2.4 Caching Strategy

| Cache Layer | Purpose | TTL | Invalidation |
|-------------|---------|-----|--------------|
| [CACHE_1] | [Purpose] | [TTL] | [Strategy] |

---

**ADR Traceability:**

| ADR | Decision | Impact on Performance |
|-----|----------|----------------------|
| [ADR-XXX] | [Decision] | [How it affects performance] |