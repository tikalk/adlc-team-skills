## 2. Product Overview

### 2.1 Product Description

The **Agentic SDLC Ecosystem** is a comprehensive suite of tools, methodologies, and infrastructure for integrating AI coding agents into the software development lifecycle. Built on the **Twelve-Factor Agentic SDLC** methodology, the ecosystem enables teams to systematically leverage AI agents for specification, planning, implementation, and quality assurance.

**Core Value Proposition**: Transform ad-hoc AI coding into systematic, enterprise-ready software development through specification-driven workflows with autonomous agent execution.

**Key Differentiators**:
- **Hybrid Execution**: Seamless local (dev containers) and remote (K8s pods) workspace provisioning
- **Bimodal Interface**: Equal-first-class CLI for developers and Visual UI for non-developers
- **Multi-Agent Agnostic**: Unified abstraction supporting Claude, GPT-4, Gemini, and 20+ agents
- **Eval-Driven Quality**: Structured evaluations define "good" and gate execution
- **Team Knowledge as Code**: Version-controlled AI behavior directives

### 2.2 Ecosystem Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Agentic SDLC Ecosystem                                │
├───────────────────┬───────────────────┬─────────────────┬─────────────────┤
│     Spec Kit      │      Runner       │ Team Directives │    Agents       │
│   (Methodology)   │    (Execution)    │   (Behavior)   │   Workspaces   │
│                   │                   │                 │ (Environment)   │
├───────────────────┼───────────────────┼─────────────────┼─────────────────┤
│ • /spec.specify   │ • [ASYNC] pods    │ • Personas      │ • Clusters     │
│ • /spec.plan      │ • [P] subagents   │ • Rules         │ • OpenCode     │
│ • /spec.implement │ • K8s orchestrate │ • Skills        │ • Attach       │
│ • /spec.tasks     │ • Worktree isol.  │ • MCP servers   │ • Collaborate   │
└───────────────────┴───────────────────┴─────────────────┴─────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Agent Runner                                         │
│              (Squad + Spec Orchestration)                                  │
│   ┌─────────────────────────┐   ┌─────────────────────────┐                 │
│   │    SQUAD MODE          │   │     SPEC MODE          │                 │
│   │  (Outer Loop)          │   │   (Inner Loop)         │                 │
│   │  PRD → Specify →      │   │  Task → Spec → Impl →  │                 │
│   │  Eval → Plan →        │   │  Verify               │                 │
│   │  Triage → tasks.md   │   │                       │                 │
│   └─────────────────────────┘   └─────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                ┌───────────────────────────────────┐
                │   12-Factor Agentic SDLC          │
                │   (Foundational Methodology)      │
                └───────────────────────────────────┘
```

### 2.3 Key Components

| Component | Purpose | Status | Key PDRs |
|-----------|---------|--------|----------|
| **Spec Kit** | Methodology toolkit for Spec-Driven Development | 80% Mature | PDR-080, PDR-081, PDR-084 |
| **Runner** | K8s-based async agent execution | 70% Mature | PDR-078, PDR-079, PDR-082 |
| **Team Directives** | Version-controlled AI behavior | 90% Mature | PDR-086, PDR-087 |
| **Agents Workspaces** | Cloud-native dev environments | 15% Started | PDR-078 |
| **Agent Runner** | Squad + Spec orchestration | In Progress | PDR-083, PDR-088 |
| **Evals Extension** | Eval-Driven Development | Active | PDR-083, PDR-087 |

### 2.4 Product Maturity

**Overall Maturity**: 65% - Core methodology established, execution infrastructure maturing, verification and orchestration in active development.

| Capability Area | Maturity | Notes |
|-----------------|----------|-------|
| Spec-Driven Development | 80% | Core /spec.* commands stable, wide adoption |
| Hybrid Workspaces | 40% | Local containers mature, remote pods early |
| Bimodal UX | 60% | CLI mature, Visual UI in development |
| Multi-Agent Support | 75% | 20+ agents configured, adapters stable |
| Eval-Driven Quality | 50% | Framework defined, tooling in progress |
| Team Directives | 90% | Version control, contribution process established |
| Squad + Spec Orchestration | 35% | Architecture defined, implementation started |

---

**Source PDRs**: PDR-078, PDR-080, PDR-081, PDR-084, PDR-086, PDR-088
