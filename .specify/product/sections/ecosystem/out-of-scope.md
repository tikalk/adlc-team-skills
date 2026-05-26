## 9. Out of Scope

### 9.1 Explicitly Excluded Features

| Feature | Reason | Future Consideration |
|---------|--------|---------------------|
| **Full IDE Integration** | Focus on CLI/UI bimodal, not IDE plugins | May add VS Code extension later |
| **Mobile App Development** | Desktop/cloud-first approach | Mobile companion app possible |
| **Self-Hosted AI Models** | Cloud API providers (Claude, GPT-4, Gemini) | Enterprise on-prem considered |
| **Real-Time Collaboration** | Async-first architecture | Real-time sync for Squad mode |
| **Legacy Language Support** | Modern languages priority (Python, JS, Go, Rust) | Expand based on demand |
| **GUI Builder/Designer** | Spec-first, not visual programming | May add visual spec editor |

### 9.2 Phase 2+ (Future Releases)

| Feature | Current Status | Target Phase |
|---------|----------------|--------------|
| **Visual UI Implementation** | Design complete, 60% mature | Phase 2 (Q3 2026) |
| **Advanced Analytics Dashboard** | Not started | Phase 2 (Q3 2026) |
| **Enterprise SSO/SAML** | Architecture planned | Phase 2 (Q4 2026) |
| **Multi-Region Support** | Not started | Phase 3 (2027) |
| **AI Agent Training/Fine-tuning** | Out of scope | Future consideration |
| **Custom Eval Framework** | PromptFoo integration only | Phase 2 (Q3 2026) |

### 9.3 Not Supported

| Item | Explanation |
|------|-------------|
| **Windows Native Support** | Docker/WSL2 required for Windows; Linux/macOS native |
| **On-Premises Kubernetes** | Cloud K8s only (GKE, EKS, AKS); no self-managed |
| **Non-Git Version Control** | Git only; no SVN, Mercurial, Perforce support |
| **Monorepo Optimization** | Standard repo handling; no monorepo-specific features |
| **Binary/Asset Management** | Code-focused; no large binary management |
| **Non-English Specs** | English specification language only |

### 9.4 By Design Decisions

| Decision | Rationale |
|----------|-----------|
| **No Single Remote-Only** | Hybrid strategy intentional - local speed required for iteration |
| **No Single Local-Only** | Remote isolation required for security and scale |
| **No Universal SYNC** | ASYNC delegation essential for efficiency |
| **No Universal ASYNC** | SYNC gates required for complex/ambiguous work |
| **No Hardcoded Agents** | Abstraction layer prevents vendor lock-in |
| **No UI-Only or CLI-Only** | Bimodal dual-primary serves both personas equally |
| **No Unlimited Parallelism** | Context window limits require max 4 concurrent agents |

### 9.5 External Dependencies

The following are handled by external systems, not core ecosystem:

| Dependency | Handled By |
|------------|------------|
| **Container Registry** | Docker Hub, GHCR, ECR, GCR |
| **Kubernetes Platform** | GKE, EKS, AKS (user-provided) |
| **Git Hosting** | GitHub, GitLab, Bitbucket |
| **CI/CD Pipeline** | GitHub Actions, GitLab CI, Jenkins |
| **AI Model APIs** | Anthropic, OpenAI, Google |
| **Monitoring/Observability** | Datadog, New Relic, Grafana (integration only) |

### 9.6 Success Metrics Out of Scope

The following metrics are tracked but NOT targets:

| Metric | Reason |
|--------|--------|
| **Lines of Code Generated** | Quality over quantity; LOC not indicative of value |
| **Agent Session Duration** | Shorter not always better; task-dependent |
| **Total API Calls** | Cost controlled, not minimized; value per call matters |
| **User Daily Active Users** | Developer tool; task-based usage more relevant |
| **Feature Usage Count** | Adoption coverage matters more than frequency |

---

**Source PDRs**: PDR-078, PDR-079, PDR-080, PDR-081, PDR-082, PDR-083, PDR-084, PDR-085, PDR-086, PDR-087, PDR-088
