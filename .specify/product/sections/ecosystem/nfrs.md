## 8. Non-Functional Requirements

### 8.1 Performance Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **PERF-001** | Local workspace provisioning time | <30 seconds (95th percentile) | PDR-078 |
| **PERF-002** | Remote workspace provisioning time | <60 seconds (95th percentile) | PDR-078 |
| **PERF-003** | Worktree creation time | <10 seconds | PDR-079 |
| **PERF-004** | Local task startup time | <5 seconds (95th percentile) | PDR-079 |
| **PERF-005** | Remote task startup time | <15 seconds (including clone) | PDR-079 |
| **PERF-006** | State handoff cycle time | <30 seconds end-to-end | PDR-079 |
| **PERF-007** | CLI task completion time | <30 seconds for common tasks | PDR-080 |
| **PERF-008** | DAG build time from markers | <2 seconds | PDR-082 |
| **PERF-009** | Verification latency | <2 seconds (p95) | PDR-083 |
| **PERF-010** | Cost per verification | <$0.01 | PDR-083 |

### 8.2 Scalability Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **SCALE-001** | Supported AI agents | 20+ in configuration | PDR-081 |
| **SCALE-002** | Max concurrent agents | 4 agents (context window limit) | PDR-082 |
| **SCALE-003** | Parallel task utilization | >70% of theoretical maximum | PDR-082 |
| **SCALE-004** | Agent swap time | <1 hour between agents | PDR-081 |
| **SCALE-005** | New agent support time | <2 days to add adapter | PDR-081 |
| **SCALE-006** | Pod spawn success rate | >95% deployment telemetry | PDR-078 |
| **SCALE-007** | Team adoption | >70% projects using directives | PDR-086 |
| **SCALE-008** | Spec coverage | 100% of features | PDR-084 |

### 8.3 Reliability Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **REL-001** | Feature parity (local vs remote) | >90% coverage | PDR-078 |
| **REL-002** | Core feature parity (agents) | 100% across all agents | PDR-081 |
| **REL-003** | Conflict resolution rate | <5% retry with sequential fallback | PDR-082 |
| **REL-004** | Verification false positive rate | <5% | PDR-083 |
| **REL-005** | Verification false negative rate | <10% | PDR-083 |
| **REL-006** | Classification accuracy | >85% auto-predicted | PDR-085 |
| **REL-007** | Spec round-trip fidelity | 100% UI → CLI → UI | PDR-080 |
| **REL-008** | Non-developer task completion | >80% self-service | PDR-080 |

### 8.4 Security Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **SEC-001** | Workspace isolation | Local and remote fully isolated | PDR-078 |
| **SEC-002** | Schema-level tool restrictions | 100% enforcement | PDR-082 |
| **SEC-003** | Unauthorized tool access | 0 incidents | PDR-081 |
| **SEC-004** | Complete audit logging | All agent actions logged | PDR-081 |
| **SEC-005** | Security isolation (remote) | Dedicated pods per workspace | PDR-078 |
| **SEC-006** | State handoff encryption | Encrypted commit/push/pull | PDR-079 |

### 8.5 Usability Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **USE-001** | Progressive disclosure | UI → CLI graduation path | PDR-080 |
| **USE-002** | Command completion | CLI supports tab completion | PDR-080 |
| **USE-003** | UI guided workflows | Step-by-step spec creation | PDR-080 |
| **USE-004** | Real-time progress visibility | Dashboard updates <5s latency | PDR-080 |
| **USE-005** | Sync status indicators | Clear local/remote state UX | PDR-079 |
| **USE-006** | Manual override capability | User can override auto-selection | PDR-078, PDR-083 |

### 8.6 Maintainability Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **MAINT-001** | Directive freshness | <30 days average age | PDR-086 |
| **MAINT-002** | Contribution acceptance rate | >60% CDRs approved | PDR-086 |
| **MAINT-003** | Version stability | 95% projects on stable versions | PDR-086 |
| **MAINT-004** | Spec-to-code drift | <5% quarterly audit | PDR-084 |
| **MAINT-005** | Adapter maintenance overhead | <1 day per agent per quarter | PDR-081 |

### 8.7 Compliance Requirements

| NFR | Requirement | Target | Source |
|-----|-------------|--------|--------|
| **COMP-001** | Audit trail completeness | 100% of decisions traceable | PDR-081, PDR-086 |
| **COMP-002** | Semantic versioning | All directives versioned | PDR-086 |
| **COMP-003** | Peer review process | All CDRs reviewed before merge | PDR-086 |
| **COMP-004** | Quality gates | Evals required for acceptance | PDR-087 |

---

**Source PDRs**: PDR-078, PDR-079, PDR-080, PDR-081, PDR-082, PDR-083, PDR-084, PDR-085, PDR-086, PDR-087, PDR-088
