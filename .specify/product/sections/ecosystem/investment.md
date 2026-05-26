## 11.5 Investment & Resources

### 11.5.1 Team Composition

| Role | FTEs | Phase | Duration | Responsibility |
|------|------|-------|----------|----------------|
| Platform Engineer (Backend) | 2 | Phase 1-3 | 12 months | Workspace provisioning, K8s infrastructure, agent adapters |
| Full-Stack Engineer | 1 | Phase 2-3 | 9 months | Visual UI, bimodal interface, dashboards |
| DevEx Engineer | 1 | Phase 1-3 | 12 months | CLI tooling, spec workflows, developer experience |
| ML/AI Engineer | 1 | Phase 2-3 | 9 months | Verification models, eval framework, LLM-as-a-Judge |
| Product/DevRel | 0.5 | Phase 1-3 | 12 months | Documentation, community, adoption |

**Total:** 4.5 FTEs average, 5.5 FTEs peak (Phase 2)

### 11.5.2 Budget Estimate

| Category | Phase 1 (Q2) | Phase 2 (Q3) | Phase 3 (Q4) | Annual Run Rate |
|----------|---------|---------|---------|-----------------|
| **Personnel** | $150K | $200K | $200K | $750K |
| **Infrastructure** (K8s, CI/CD) | $15K | $25K | $25K | $80K |
| **AI API Costs** (Claude, GPT-4, Gemini) | $5K | $10K | $15K | $40K |
| **Tools & Licenses** | $5K | $5K | $5K | $20K |
| **Total** | **$175K** | **$240K** | **$245K** | **$890K** |

### 11.5.3 Risk-Adjusted ROI

| Scenario | Probability | 12-Month ROI | NPV (3-year) | Payback Period |
|----------|-------------|--------------|--------------|----------------|
| **Optimistic** | 25% | 180% | $2.5M | 5 months |
| **Base Case** | 50% | 120% | $1.5M | 8 months |
| **Pessimistic** | 25% | 40% | $0.4M | 14 months |
| **Weighted Average** | 100% | **115%** | **$1.5M** | **8 months** |

*ROI measured in developer productivity gains (30-50% on AI-assisted tasks) and reduced rework (20-30% reduction in AI-related defects).*

### 11.5.4 Key Assumptions

| Assumption | Basis | Risk if Wrong |
|------------|-------|---------------|
| AI API costs remain stable or decrease | Historical trend of LLM price drops | Budget overrun of 20-40% |
| 4-6 FTEs sufficient for Phase 1-3 | Comparable ecosystem projects | Delayed milestones by 2-4 weeks per missing FTE |
| >80% team adoption achievable in 12 months | Early adoption signals from spec kit | Lower ROI, longer payback period |
| Multi-agent support remains viable | 20+ agents already configured | Vendor consolidation risk |

### 11.5.5 Go/No-Go Criteria

| Checkpoint | Date | Criteria | Decision |
|------------|------|----------|----------|
| Phase 1 Review | June 2026 | 100% spec coverage, 20+ agents, local workspace stable | Go / No-Go |
| Phase 2 Review | September 2026 | >80% UI completion, <2s verification, remote workspace operational | Go / No-Go |
| Phase 3 Review | December 2026 | Squad+Spec operational, >70% parallel utilization | Go / No-Go |

---

**Source PDRs**: PDR-078, PDR-079, PDR-080, PDR-081, PDR-082, PDR-083, PDR-084, PDR-085, PDR-086, PDR-087, PDR-088
