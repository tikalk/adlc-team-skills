# Development View: Runner

**Sub-System**: Runner
**ADRs Referenced**: ADR-006
**Generated**: 2026-05-20
**Dependencies**: Functional View

---

## 3.5 Development View

**Purpose**: Constraints for developers - code organization, dependencies, CI/CD

### 3.5.1 Code Organization

```text
packages/runner/
├── src/
│   ├── orchestrator/     # Pod Orchestrator
│   ├── scheduler/        # Resource Scheduler
│   ├── runtime/          # Subagent Runtime
│   ├── health/           # Health Monitor
│   └── metrics/          # Metrics Collector
├── k8s/
│   ├── manifests/        # Kubernetes manifests
│   ├── charts/           # Helm charts
│   └── configs/          # ConfigMaps and Secrets
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── package.json
```

### 3.5.2 Technology Stack Mapping

| Functional Role | Technology Choice | Version/Variant | ADR Reference |
|-----------------|-------------------|-----------------|---------------|
| K8s Client | @kubernetes/client-node | v1.x | ADR-006 |
| Pod Orchestration | Kubernetes API | v1.29+ | ADR-006 |
| Metrics Collection | Prometheus client | v15.x | ADR-006 |
| Health Checks | Kubernetes probes | Built-in | ADR-006 |
| Container Runtime | containerd | v1.7+ | ADR-006 |
| Task Queue | BullMQ (Redis) | v5.x | ADR-006 |
| Resource Monitoring | @opentelemetry | v1.x | ADR-006 |

### 3.5.3 Technology Architecture

```mermaid
graph TD
    K8sClient[@kubernetes/client-node]:::k8s
    Scheduler[BullMQ Scheduler]:::queue
    Prometheus[Prometheus Metrics]:::metrics
    ContainerD[containerd Runtime]:::runtime
    OpenTelemetry[OpenTelemetry]:::otel
    
    K8sClient -->|Manage| ContainerD
    Scheduler -->|Queue| K8sClient
    Prometheus -->|Collect| ContainerD
    OpenTelemetry -->|Trace| K8sClient
    
    classDef k8s fill:#326ce5,stroke:#333,stroke-width:2px,color:#fff
    classDef queue fill:#dc382d,stroke:#333,stroke-width:2px,color:#fff
    classDef metrics fill:#e6522c,stroke:#333,stroke-width:2px,color:#fff
    classDef runtime fill:#4a9eff,stroke:#333,stroke-width:2px,color:#fff
    classDef otel fill:#f5a623,stroke:#333,stroke-width:2px,color:#fff
```

### 3.5.4 Module Dependencies

**Dependency Rules:**

- Orchestrator depends on K8s Client
- Scheduler depends on Queue and Orchestrator
- Runtime executes in pods (isolated)
- Metrics collected from all layers
- No direct pod-to-pod communication

```mermaid
graph LR
    Scheduler["Scheduler Layer"]
    Orchestrator["Orchestrator Layer"]
    K8sClient["K8s Client Layer"]
    Runtime["Runtime Layer"]
    
    Scheduler --> Orchestrator
    Orchestrator --> K8sClient
    K8sClient -.->|Manages| Runtime
    
    classDef layer fill:#326ce5,stroke:#333,stroke-width:2px,color:#fff
    class Scheduler,Orchestrator,K8sClient,Runtime layer
```

### 3.5.5 Build & CI/CD

- **Build System**: Docker multi-stage builds
- **CI Pipeline**: Lint → Test → Build Image → Push to Registry → Deploy Staging
- **Deployment Strategy**: Helm charts for K8s deployment
- **Testing**: Integration tests against kind (K8s in Docker)

### 3.5.6 Development Standards

- **Coding Standards**: ESLint + Kubernetes best practices
- **Review Requirements**: 2 approvals, security review for RBAC changes
- **Testing Requirements**: E2E tests for pod lifecycle

---

## Perspective Considerations

### Security Considerations

- **RBAC**: Principle of least privilege for K8s roles
- **Network Policies**: Default-deny, explicit allow
- **Image Scanning**: Trivy scans on build
- **Secret Management**: K8s secrets, never in code

_Source ADRs: ADR-006, ADR-012_

### Performance Considerations

- **Resource Limits**: CPU/memory quotas enforced
- **HPA**: Horizontal Pod Autoscaler for scaling
- **Metrics**: Prometheus for performance monitoring
- **Caching**: Image pull policy optimization

_Source ADRs: ADR-006_

### Availability Considerations

- **Pod Disruption Budgets**: Graceful handling
- **Multi-zone**: Pod anti-affinity
- **Health Probes**: Proper readiness/liveness
- **Circuit Breakers**: Fail fast patterns

_Source ADRs: ADR-006_

---

## Validation Checklist

- [x] **Technology Mapping**: All functional elements mapped
- [x] **ADR References**: All choices reference ADRs
- [x] **Diagram Parity**: Mirrors Functional View structure
- [x] **Code Alignment**: Organization matches stack
- [x] **Dependency Rules**: Clear layer dependencies

---

**ADR Traceability:**

| ADR | Decision | Impact on Development View |
|-----|----------|----------------------------|
| ADR-006 | K8s Subagent Pattern | All technologies: K8s client, containerd, etc. |
