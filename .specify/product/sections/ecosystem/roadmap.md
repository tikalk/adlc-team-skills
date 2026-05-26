## 11. Roadmap

### 11.1 Phase 1: Foundation (Current - Q2 2026)

**Status**: In Progress (65% Complete)

| Milestone | Target Date | Key Deliverables | PDRs |
|-----------|-------------|------------------|------|
| **M1.1** | May 2026 | Constitution & PDR consolidation | PDR-084 to PDR-088 |
| **M1.2** | May 2026 | Spec-Driven Development stable | PDR-084 |
| **M1.3** | June 2026 | Hybrid Workspace (local) complete | PDR-078, PDR-079 |
| **M1.4** | June 2026 | Multi-Agent Abstraction GA | PDR-081 |
| **M1.5** | June 2026 | Team Directives v1.0.0 | PDR-086 |

**Success Criteria**:
- 100% spec coverage of existing features
- 20+ agents in AGENT_CONFIG
- >70% local workspace stability
- v1.0.0 directive release

### 11.2 Phase 2: Scale (Q3 2026)

**Focus**: Visual UI, Remote Infrastructure, Verification

| Milestone | Target Date | Key Deliverables | PDRs |
|-----------|-------------|------------------|------|
| **M2.1** | July 2026 | Bimodal Visual UI Beta | PDR-080 |
| **M2.2** | July 2026 | Hybrid Workspace (remote) | PDR-078, PDR-079 |
| **M2.3** | August 2026 | Milestone Verification GA | PDR-083 |
| **M2.4** | August 2026 | Dual Execution Loops complete | PDR-085 |
| **M2.5** | September 2026 | Eval-Driven Development v1.0 | PDR-087 |

**Success Criteria**:
- >80% non-developer task completion (UI)
- >95% pod spawn success rate
- <2s verification latency
- 100-point skill framework adopted

### 11.3 Phase 3: Orchestration (Q4 2026)

**Focus**: Squad + Spec Mode, Enterprise Features, Ecosystem Maturity

| Milestone | Target Date | Key Deliverables | PDRs |
|-----------|-------------|------------------|------|
| **M3.1** | October 2026 | Squad Mode (Outer Loop) | PDR-088 |
| **M3.2** | October 2026 | Spec Mode (Inner Loop) GA | PDR-088 |
| **M3.3** | November 2026 | Enterprise SSO & Compliance | - |
| **M3.4** | November 2026 | Advanced Analytics Dashboard | - |
| **M3.5** | December 2026 | Ecosystem v2.0 Release | All PDRs |

**Success Criteria**:
- <3 NEEDS CLARIFICATION flags per PRD (Squad)
- >90% first-pass verification rate (Spec)
- SOC2 Type II compliance
- >70% parallel utilization

### 11.4 Phase 4: Expansion (2027)

**Focus**: Multi-Region, Advanced AI, Ecosystem Growth

| Quarter | Key Deliverables |
|---------|------------------|
| **Q1 2027** | Multi-region K8s support; Advanced agent routing |
| **Q2 2027** | Custom eval framework; Plugin architecture |
| **Q3 2027** | AI training pipeline integration; Marketplace |
| **Q4 2027** | Ecosystem v3.0; 50+ supported agents |

### 11.5 Priority Matrix

| Priority | Requirements | Timeline |
|----------|--------------|----------|
| **P0** | REQ-001 to REQ-007 (Workspace/Git) | Q2 2026 |
| **P0** | REQ-008 to REQ-013 (UX/Agents) | Q2 2026 |
| **P0** | REQ-014 to REQ-019 (Orchestration) | Q2-Q3 2026 |
| **P1** | REQ-020 to REQ-025 (Spec/Execution) | Q3 2026 |
| **P1** | REQ-026 to REQ-028 (Directives) | Q2 2026 |
| **P1** | REQ-029 to REQ-031 (Evals) | Q3 2026 |
| **P2** | REQ-032 to REQ-034 (Squad+Spec) | Q4 2026 |

### 11.6 Dependency Graph

```
Phase 1 (Foundation)
├── Workspace Local (PDR-078) ──────────┐
├── Git Worktrees (PDR-079) ────────────┤──→ Phase 2 (Scale)
├── Agent Abstraction (PDR-081) ────────┤    ├── Remote Workspace
├── Bimodal UX (PDR-080) ───────────────┤    ├── Verification (PDR-083)
└── Team Directives (PDR-086) ──────────┘    └── Dual Execution (PDR-085)
                                              │
Phase 3 (Orchestration) ←─────────────────────┘
├── Squad Mode (PDR-088)
├── Spec Mode (PDR-088)
└── Enterprise Features
```

### 11.7 Risk-Adjusted Timeline

| Scenario | Phase 2 Completion | Phase 3 Completion |
|----------|-------------------|-------------------|
| **Optimistic** (+20%) | August 2026 | November 2026 |
| **Base Case** | September 2026 | December 2026 |
| **Pessimistic** (-20%) | October 2026 | February 2027 |

**Key Risk Factors**:
- Visual UI complexity (could delay 4-6 weeks)
- K8s remote workspace stability (could delay 2-4 weeks)
- Verification model accuracy (could delay 2-3 weeks)

### 11.8 Success Milestones

| Date | Milestone | Measurement |
|------|-----------|-------------|
| June 2026 | Foundation Stable | All P0 requirements shipped |
| September 2026 | Scale Achieved | >70% parallel utilization, >80% UI completion |
| December 2026 | Orchestration Live | Squad + Spec modes operational |
| March 2027 | Enterprise Ready | SOC2, SSO, enterprise customers |
| June 2027 | Ecosystem Mature | 50+ agents, marketplace, training pipeline |

---

**Source PDRs**: PDR-078, PDR-079, PDR-080, PDR-081, PDR-082, PDR-083, PDR-084, PDR-085, PDR-086, PDR-087, PDR-088
