# Agentic SDLC Ecosystem - Product Requirements Document

**Version**: 1.9.0  
**Generated**: 2026-03-23  
**Updated**: 2026-04-05 (Added PDR-070 to PDR-078: Three-Layer Framework + "You Don't Know AI Agents" Integration)  
**Source**: `.specify/memory/pdr.md` (78 PDRs)  
**Status**: Draft

---

## 1. Overview

### 1.1 Product Description

The **Agentic SDLC Ecosystem** is a comprehensive suite of tools, methodologies, and infrastructure for integrating AI coding agents into the software development lifecycle. Built on the **Twelve-Factor Agentic SDLC** methodology, the ecosystem enables teams to systematically leverage AI agents for specification, planning, implementation, and quality assurance.

### 1.2 Product Suite

| Product | Purpose | Key PDRs |
|---------|---------|----------|
| **Spec Kit** | Methodology toolkit for Spec-Driven Development | PDR-001 to PDR-008, PDR-016 to PDR-041, PDR-054 to PDR-061 |
| **Runner** | K8s-based async agent execution infrastructure | PDR-003, PDR-009 to PDR-012, PDR-018 |
| **Team Directives** | Version-controlled AI behavior configuration | PDR-013 to PDR-015, PDR-029 |
| **Agents Workspaces** | Cloud-native persistent development environments | PDR-042 to PDR-048, PDR-051 |
| **Agent Runner** | Unified Squad + Spec orchestration | PDR-053, PDR-061 |
| **Evals Extension** | Eval-Driven Development (EDD) with PromptFoo | PDR-065 to PDR-069, PDR-050 (superseded by PDR-067) |

### 1.3 Ecosystem Architecture

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

### 1.4 Scope Summary

**In Scope:**
- Multi-agent ecosystem supporting 20+ AI agents (PDR-001)
- Spec-Driven Development workflows (PDR-002)
- Dual execution loops: SYNC and ASYNC (PDR-003)
- K8s-based subagent orchestration (PDR-009)
- Cloud-native workspace provisioning (PDR-042)
- Open source B2D model (PDR-005)
- **Agent Runner: Squad + Spec orchestration (PDR-053)**
- **Eval-Driven Development (EDD) with PromptFoo integration (PDR-065 to PDR-069)**
- **Three-Layer Framework: Decision Gates → Research-Driven Planning → Multi-Reviewer Ensemble (PDR-070 to PDR-072)**
- **Eval Metrics: Pass@k vs Pass^k distinction (PDR-074)**
- **Eval Completeness: Transcript + Outcome dual evaluation (PDR-075)**
- **Grader Selection Framework: Code → Model → Human (PDR-076)**

**Out of Scope:**
- Custom AI model training
- IDE/editor development
- Cloud provider billing management
- General-purpose CI/CD pipelines
- Custom eval tooling (uses PromptFoo as default)

---

## 2. The Problem

### 2.1 Problem Statement

Software development teams are struggling to systematically integrate AI coding agents into their workflows. Current approaches are:

1. **Ad-hoc and inconsistent** - Each developer uses AI agents differently, leading to unpredictable quality
2. **Context-challenged** - AI agents lose coherence over long sessions due to context window limits
3. **Verification-weak** - No systematic way to verify AI-generated code meets requirements
4. **Knowledge-siloed** - AI guidance isn't shared or versioned across teams
5. **Infrastructure-limited** - Local execution limits scalability and collaboration

---

## 3. Goals & Objectives

### 3.1 Primary Goals

| Goal | Description | Source PDRs |
|------|-------------|-------------|
| **Systematic AI Integration** | Provide a structured methodology for AI-assisted development | PDR-002, PDR-004 |
| **Context Preservation** | Maintain agent coherence across long sessions and multi-task work | PDR-016, PDR-017, PDR-023 |
| **Goal-Backward Verification** | Verify outcomes, not just task completion | PDR-025 |
| **Team Knowledge Sharing** | Version-control AI behavior and share best practices | PDR-013, PDR-029 |
| **Scalable Execution** | Enable parallel and autonomous AI agent execution | PDR-003, PDR-009 |
| **Eval-Driven Development** | Define "good" through structured evals that become spec + acceptance criteria | PDR-065, PDR-067 |

### 3.2 Technical Goals

| Goal | Description | Source PDRs |
|------|-------------|-------------|
| **Multi-Agent Support** | Support 20+ AI agents with unified abstraction | PDR-001 |
| **LLM/Deterministic Split** | Separate judgment work from mechanical operations | PDR-022 |
| **Cloud-Native Infrastructure** | K8s-based execution with GitOps deployment | PDR-009, PDR-011 |
| **Safety by Architecture** | Schema-level tool restrictions for security | PDR-019 |
| **Eval-Gated Execution** | Task completion determined by eval pass/fail, not file existence | PDR-068, PDR-069 |

---

## 4. Success Metrics

### 4.1 Adoption Metrics

| Metric | Target | Measurement | Source PDR |
|--------|--------|-------------|------------|
| Supported AI agents | 20+ | Count in AGENT_CONFIG | PDR-001 |
| GitHub stars | Growing | GitHub metrics | PDR-005 |
| Active contributors | 10+ | GitHub contributors graph | PDR-005 |
| Spec coverage | 100% of features | Features with specs/ directory | PDR-002 |

### 4.2 Quality Metrics

| Metric | Target | Measurement | Source PDR |
|--------|--------|-------------|------------|
| Context coherence | Task 7 ≈ Task 1 | Quality consistency | PDR-023 |
| Verification pass rate | >95% | Before declaring done | PDR-025 |
| Stubs caught | 100% | No stubs pass verification | PDR-025 |
| ASYNC task success rate | >90% | Completed without escalation | PDR-003 |

### 4.3 Infrastructure Metrics

| Metric | Target | Measurement | Source PDR |
|--------|--------|-------------|------------|
| Pod spawn success rate | >95% | Deployment telemetry | PDR-009 |
| Worktree creation time | <10s | Script timing | PDR-010 |
| Cluster provisioning time | <15 min | End-to-end timing | PDR-043 |
| Workspace startup time | <60s | With pre-pulled image | PDR-046 |

---

## 5. Personas

### 5.1 Primary Persona: Platform Engineering Lead

**Name**: Alex Chen  
**Role**: Platform Engineering Lead at mid-size tech company  
**Team Size**: 5-15 engineers

**Needs**:
- Standardize how team uses AI agents across projects
- Ensure AI-generated code meets quality standards
- Scale AI usage beyond individual developer sessions
- Share AI best practices across team

**Success Quote**: *"I want my team to leverage AI agents consistently and safely, with clear visibility into what's being generated and why."*

---

## 6. Functional Requirements

### 6.1 Spec Kit Requirements

#### FR-SK-001: Multi-Agent Support

**Description**: Support multiple AI agents through unified abstraction layer

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Support 20+ AI agents | Must | PDR-001 |
| Unified CLI interface (`--ai <agent>`) | Must | PDR-001 |
| Agent-specific command generation | Must | PDR-001 |
| New agent addition < 1 day | Should | PDR-001 |

#### FR-SK-002: Spec-Driven Development Workflow

**Description**: Implement specification-first development workflow

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| `/spec.specify` command | Must | PDR-002 |
| `/spec.plan` command | Must | PDR-002 |
| `/spec.tasks` command | Must | PDR-002 |
| `/spec.implement` command | Must | PDR-002 |

### 6.2 Runner Requirements

#### FR-RN-001: Dual Execution Loop

**Description**: Support SYNC (interactive) and ASYNC (autonomous) execution

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| `[SYNC]` marker for human interaction | Must | PDR-003 |
| `[ASYNC]` marker for autonomous execution | Must | PDR-003 |
| `[P]` marker for parallel execution | Must | PDR-003 |

### 6.5 Agent Runner Requirements

#### FR-AR-001: Squad Mode (Outer Loop)

**Description**: PRD → Implementation workflow with human-in-the-loop

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| PRD conversation interface | Must | PDR-053 |
| `/spec.specify` command | Must | PDR-053 |
| Eval clarification phase | Must | PDR-053 |
| Plan generation | Must | PDR-053 |

#### FR-AR-002: Spec Mode (Inner Loop)

**Description**: Task → Implementation execution with Autoresearch pattern

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Task → Spec → Impl → Verify | Must | PDR-053 |
| Time-bounded execution | Should | PDR-053 |
| Eval-gated keep/reset | Should | PDR-053 |

---

## 7. Non-Functional Requirements

### 7.1 Performance

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Pod spawn time | < 60s | PDR-009 |
| Worktree creation | < 10s | PDR-010 |
| Cluster provisioning | < 15 min | PDR-043 |
| Sandbox creation (pooled) | < 5s | PDR-054 |

### 7.2 Security

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Schema-level tool restrictions | 100% enforced | PDR-019 |
| External Secrets Operator | Required for production | PDR-012 |
| Five-layer defense-in-depth | Implemented | PDR-019 |
| Container isolation (gVisor) | Enforced | PDR-054 |

### 7.3 Reliability

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Pod spawn success rate | > 95% | PDR-009 |
| ASYNC task success rate | > 90% | PDR-003 |
| Cluster provisioning success | > 98% | PDR-043 |
| Workspace uptime | > 99.5% | PDR-042 |

---

## 8. Out of Scope

### 8.1 Explicitly Excluded

| Exclusion | Rationale | Related PDR |
|-----------|-----------|------------|
| Custom AI model training | Focus on using existing agents | PDR-001 |
| IDE/editor development | Integrate with existing tools | PDR-001 |
| Cloud billing management | Use native cloud tools | PDR-043 |
| General CI/CD pipelines | Focus on agentic workflows | PDR-009 |

---

## 9. Risks & Mitigation

### 9.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation | Source PDR |
|------|------------|--------|------------|------------|
| Context rot in long sessions | High | High | Graduated compaction; dual-memory | PDR-016, PDR-017 |
| Agent API divergence over time | Medium | High | Abstraction layer; version pinning | PDR-001 |
| Doom-loop (infinite tool repetition) | Medium | Medium | MD5 fingerprinting; escalation | PDR-018 |
| Cluster provisioning failures | Low | High | Retry logic; health checks | PDR-043 |

---

## 10. Roadmap & Milestones

### 10.1 Product Maturity by Component

| Product | Status | Maturity | Key Gaps |
|---------|--------|----------|----------|
| **Spec Kit** | Active Development | 80% | Worktrunk integration, parallel execution |
| **Runner** | Active Development | 70% | Continue-Here recovery, observability |
| **Team Directives** | Stable | 90% | Fork sync automation |
| **Agents Workspaces** | Implementation Started | 15% | Infra issues open |

### 10.2 Milestone 1: Spec Kit Parallel Execution

**Target**: Q2 2026  
**Demo Sentence**: *"After this milestone, developers can run 5+ agents in parallel with worktree isolation."*

### 10.3 Milestone 2: Agents Workspaces Alpha

**Target**: Q3 2026  
**Demo Sentence**: *"After this milestone, developers can provision a cloud workspace and attach via CLI."*

**GitLab Repo**: https://gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-agent-workspaces  
**GitHub Repo**: https://github.com/tikalk/agentic-sdlc-agent-runner

### 10.4 Milestone 3: Multi-Cloud & Collaboration

**Target**: Q4 2026  
**Demo Sentence**: *"After this milestone, teams can collaborate on workspaces across any major cloud."*

### 10.5 Milestone 4: Agent Runner

**Target**: Q2 2026  
**Demo Sentence**: *"After this milestone, the Agent Runner can take a PRD, generate a spec, plan implementation, and execute via Spec Runner."*

### 10.6 Milestone 5: Harness Synthesis

**Target**: Q3 2026  
**Demo Sentence**: *"After this milestone, Agent Runner can auto-synthesize validation harnesses for generated code."*

---

## 11. PDR Traceability

### 11.1 PDR Summary by Product

| Product | PDR Count | Categories |
|---------|-----------|------------|
| Spec Kit | 41 | System, Technical, Workflow, Quality, Architecture |
| Runner | 7 | System, Infrastructure, Technical, Security |
| Team Directives | 4 | System |
| Agents Workspaces | 7 | System, Infrastructure, Runtime, Workspace, Session |
| Agent Runner | 2 | System, Orchestration |
| Evals Extension | 5 | System, Workflow, Integration, Quality |
| **Total** | **68** | (1 superseded: PDR-050) |

---

## Appendix A: References

- **12-Factor Agentic SDLC**: https://tikalk.github.io/agentic-sdlc-12-factors/
- **Spec Kit Repository**: https://github.com/tikalk/agentic-sdlc-spec-kit
- **Agentic Workspaces (GitLab)**: https://gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-agent-workspaces
- **Research Paper**: arXiv:2603.05344v1 - "Building AI Coding Agents for the Terminal"
- **Braintrust Blog**: "Evals Replace PRDs" - Eval-Driven Development paradigm (April 2026)
- **GitHub Issue #78**: Evals Extension - Full EDD Implementation

---

## Appendix B: Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-09 | AI-Generated | Initial PRD from 48 PDRs |
| 1.1.0 | 2026-03-14 | AI-Generated | Added PDR-049 to PDR-053 (Agent Runner, AutoHarness) |
| 1.2.0 | 2026-03-16 | AI-Generated | Added PDR-054 (OpenSandbox Integration) |
| 1.3.0 | 2026-03-23 | AI-Generated | Added PDR-055 to PDR-061 (Superpowers patterns) |
| 1.5.0 | 2026-04-05 | AI-Generated | Added PDR-065 to PDR-069 (Eval-As-Spec paradigm), PDR-050 superseded by PDR-067 |

---

*This PRD is generated from Product Decision Records.*