## 10. Risks & Mitigation

### 10.1 High Severity Risks

| Risk ID | Risk | Likelihood | Impact | Mitigation Strategy |
|---------|------|------------|--------|---------------------|
| **RISK-001** | **Feature Parity Drift** - CLI and UI implementations diverge over time | High | High | Automated cross-interface testing suite; parity dashboard; feature gating until both interfaces ready; shared component library |
| **RISK-002** | **Vendor Lock-in** - Single AI agent dominates, reducing flexibility | Medium | High | Maintain 20+ agent configurations; quarterly adapter testing; <1hr swap time requirement; avoid proprietary features |
| **RISK-003** | **Classification Errors** - SYNC/ASYNC misclassification causes quality issues | Medium | High | >85% accuracy target; manual override always available; verification gates catch errors; escalation metrics tracked |
| **RISK-004** | **Verification False Positives** - Evaluator passes incomplete work | Medium | High | Require explicit test output in transcript; three-layer evaluation; human gates at [SYNC] points; <5% false positive target |

### 10.2 Medium Severity Risks

| Risk ID | Risk | Likelihood | Impact | Mitigation Strategy |
|---------|------|------------|--------|---------------------|
| **RISK-005** | **Context Window Exhaustion** - Parallel agents exceed limits | Medium | Medium | Max 4 concurrent agents hard limit; context budget mindset; fast models for verification; sequential fallback |
| **RISK-006** | **Grader Maintenance Burden** - Evals require ongoing updates | High | Medium | Version-controlled evals; automated regression detection; 100-point framework structure; CDR contribution process |
| **RISK-007** | **Cost Escalation** - High evaluation volume increases costs | Medium | Medium | Fast model (Haiku-3.5) for screening; full-power model only for final judgment; usage monitoring alerts; <$0.01 per verification |
| **RISK-008** | **Spec-Code Drift** - Specifications become stale vs implementation | High | Medium | <5% drift target (quarterly audit); living documentation practices; verification gates enforce alignment |
| **RISK-009** | **Persona Conflict** - Dev vs non-dev needs create friction | Medium | Medium | Shared governance model; persona councils; progressive disclosure path; collaboration features |
| **RISK-010** | **Workspace Sync Conflicts** - Local/remote state conflicts | Medium | Medium | Clear handoff semantics; conflict detection; <30s handoff cycle; explicit user action required |

### 10.3 Low Severity Risks

| Risk ID | Risk | Likelihood | Impact | Mitigation Strategy |
|---------|------|------------|--------|---------------------|
| **RISK-011** | **Learning Curve** - New users struggle with markers/specs | Medium | Low | Guided UI workflows; CLI help shows equivalents; documentation; >80% completion rate |
| **RISK-012** | **Calibration Drift** - Evaluators become less accurate over time | Medium | Low | Gold sets for calibration; periodic recalibration; drift detection in CI |
| **RISK-013** | **Model Selection Confusion** - Users unsure which agent to use | Low | Low | Default recommendations; performance metrics per agent; swap capability |
| **RISK-014** | **Mode Switching Overhead** - Squad ↔ Spec handoff friction | Low | Low | <5% rework target; clear handoff documentation; context preservation |

### 10.4 Technical Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Kubernetes Dependency** | Remote workspaces require K8s expertise | Automated provisioning; sensible defaults; escape hatch to local |
| **Docker Requirement** | Local workspaces require Docker | WSL2 support for Windows; clear installation guide; VM alternative |
| **Git Complexity** | Worktrees and clones have learning curve | Documentation; automated scripts; clear error messages |
| **API Rate Limits** | AI provider rate limiting | Retry with backoff; queue management; local caching |
| **Network Latency** | Remote execution sensitive to latency | Edge deployment option; offline local fallback; progress indicators |

### 10.5 Business Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Adoption Resistance** | Teams reluctant to change workflows | >80% adoption target; progressive migration; demonstrate value |
| **Competitive Pressure** | Other AI dev tools enter market | Differentiation through methodology; ecosystem approach; team focus |
| **AI Capability Changes** | Vendor API changes break functionality | Adapter pattern; abstraction layer; multi-agent support |
| **Talent Scarcity** - Hard to find platform engineering expertise | Documentation; managed service option; community support |

### 10.6 Risk Monitoring

| Metric | Threshold | Action |
|--------|-----------|--------|
| Feature parity drift | >10% | Halt new features, fix parity |
| Classification accuracy | <80% | Retrain triage model |
| False positive rate | >5% | Tighten verification criteria |
| Cost per verification | >$0.02 | Optimize evaluation pipeline |
| Spec-code drift | >10% | Mandatory audit sprint |
| User override rate | >20% | Review classification criteria |

### 10.7 Deferred Risk Analysis

The following risks are acknowledged but detailed analysis deferred to implementation phase:

| Area | Risk | Deferred To |
|------|------|-------------|
| Eval-Driven Development | False positive/negative rates in LLM judges | Implementation spec grader design |
| Eval-Driven Development | Grader maintenance burden evolution | Team Directives contribution process |
| Eval-Driven Development | Calibration drift triggers | Evals Extension calibration spec |
| Eval-Driven Development | Cost escalation thresholds | Implementation spec cost model |
| Eval-Driven Development | Model selection trade-offs | ADR-081 adapter documentation |

---

**Source PDRs**: PDR-078, PDR-079, PDR-080, PDR-081, PDR-082, PDR-083, PDR-084, PDR-085, PDR-086, PDR-087, PDR-088
