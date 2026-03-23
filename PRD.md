# Agentic SDLC Ecosystem - Product Requirements Document

**Version**: 1.4.0  
**Generated**: 2026-03-23  
**Source**: `.specify/memory/pdr.md` (61 PDRs)  
**Status**: Draft

---

## Table of Contents

1. [Overview](#1-overview)
2. [The Problem](#2-the-problem)
3. [Goals & Objectives](#3-goals--objectives)
4. [Success Metrics](#4-success-metrics)
5. [Personas](#5-personas)
6. [Functional Requirements](#6-functional-requirements)
7. [Non-Functional Requirements](#7-non-functional-requirements)
8. [Out of Scope](#8-out-of-scope)
9. [Risks & Mitigation](#9-risks--mitigation)
10. [Roadmap & Milestones](#10-roadmap--milestones)
11. [PDR Traceability](#11-pdr-traceability)

---

## 1. Overview

### 1.1 Product Description

The **Agentic SDLC Ecosystem** is a comprehensive suite of tools, methodologies, and infrastructure for integrating AI coding agents into the software development lifecycle. Built on the **Twelve-Factor Agentic SDLC** methodology, the ecosystem enables teams to systematically leverage AI agents for specification, planning, implementation, and quality assurance.

### 1.2 Product Suite

| Product | Purpose | Key PDRs |
|---------|---------|----------|
| **Spec Kit** | Methodology toolkit for Spec-Driven Development | PDR-001 to PDR-008, PDR-016 to PDR-041 |
| **Runner** | K8s-based async agent execution infrastructure | PDR-003, PDR-009 to PDR-012, PDR-018 |
| **Team Directives** | Version-controlled AI behavior configuration | PDR-013 to PDR-015, PDR-029 |
| **Agents Workspaces** | Cloud-native persistent development environments | PDR-042 to PDR-048, PDR-051 |
| **Agent Runner** | Unified Squad + Spec orchestration | PDR-053 |

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
- **AutoHarness-style harness synthesis (PDR-019, PDR-053)**

**Out of Scope:**
- Custom AI model training
- IDE/editor development
- Cloud provider billing management
- General-purpose CI/CD pipelines

---

## 2. The Problem

### 2.1 Problem Statement

Software development teams are struggling to systematically integrate AI coding agents into their workflows. Current approaches are:

1. **Ad-hoc and inconsistent** - Each developer uses AI agents differently, leading to unpredictable quality
2. **Context-challenged** - AI agents lose coherence over long sessions due to context window limits
3. **Verification-weak** - No systematic way to verify AI-generated code meets requirements
4. **Knowledge-siloed** - AI guidance isn't shared or versioned across teams
5. **Infrastructure-limited** - Local execution limits scalability and collaboration

### 2.2 Current State Pain Points

| Pain Point | Impact | Source PDR |
|------------|--------|------------|
| AI agents produce inconsistent results | Quality variance; rework | PDR-002 |
| Context rot in long sessions | Coherence loss by task 3-4 | PDR-016, PDR-023 |
| No systematic task decomposition | Scope creep; incomplete work | PDR-020 |
| Verification is "all steps done" not "goals met" | Stubs pass; integration fails | PDR-025 |
| AI behavior not version-controlled | Knowledge loss; inconsistency | PDR-013 |
| Local machine limitations | Resource constraints; session loss | PDR-042 |

### 2.3 Impact of Not Solving

- **Productivity Loss**: Teams spend more time fixing AI mistakes than building features
- **Quality Degradation**: AI-generated code requires extensive manual review
- **Knowledge Erosion**: Best practices for AI usage aren't captured or shared
- **Scalability Ceiling**: Can't leverage AI for parallel or autonomous work
- **Collaboration Friction**: Developers can't share AI development environments

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

### 3.2 Technical Goals

| Goal | Description | Source PDRs |
|------|-------------|-------------|
| **Multi-Agent Support** | Support 20+ AI agents with unified abstraction | PDR-001 |
| **LLM/Deterministic Split** | Separate judgment work from mechanical operations | PDR-022 |
| **Cloud-Native Infrastructure** | K8s-based execution with GitOps deployment | PDR-009, PDR-011 |
| **Safety by Architecture** | Schema-level tool restrictions for security | PDR-019 |
| **Observable Systems** | Expose logs, metrics, traces to agents | PDR-035 |

### 3.3 Business Goals

| Goal | Description | Source PDRs |
|------|-------------|-------------|
| **Open Source Adoption** | Build developer community through OSS | PDR-005 |
| **Ecosystem Completeness** | Provide end-to-end solution (methodology + execution + environment) | PDR-042 |
| **Enterprise Readiness** | Support enterprise security, multi-cloud, compliance | PDR-012, PDR-044 |

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

### 4.4 Efficiency Metrics

| Metric | Target | Measurement | Source PDR |
|--------|--------|-------------|------------|
| Human time saved | 40%+ | Comparison to all-SYNC | PDR-003 |
| Token efficiency | 50%+ saved | vs LLM-only approach | PDR-022 |
| Context reduction | 50%+ | Peak consumption reduction | PDR-016 |

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

**Pain Points**:
- Each developer uses AI differently
- No visibility into AI agent activities
- Local execution limits parallelization
- AI guidance isn't version-controlled

**Success Quote**: *"I want my team to leverage AI agents consistently and safely, with clear visibility into what's being generated and why."*

**Source PDRs**: PDR-002, PDR-013, PDR-037

---

### 5.2 Secondary Persona: Individual Developer

**Name**: Jordan Lee  
**Role**: Senior Software Engineer

**Needs**:
- Get AI help without losing context mid-session
- Verify AI-generated code meets requirements
- Resume work after interruptions
- Collaborate with teammates on AI-assisted work

**Pain Points**:
- AI loses context after 3-4 tasks
- Hard to verify AI work meets goals
- Sessions lost when laptop closes
- Can't share AI environment with pair

**Success Quote**: *"I want AI to be a reliable pair programmer that remembers what we decided and doesn't produce stubs."*

**Source PDRs**: PDR-016, PDR-025, PDR-028, PDR-048

---

### 5.3 Secondary Persona: DevOps Engineer

**Name**: Sam Patel  
**Role**: DevOps/SRE Engineer

**Needs**:
- Deploy AI agent infrastructure safely
- Monitor agent execution and resource usage
- Secure secrets and credentials
- GitOps-based deployment workflows

**Pain Points**:
- No standard way to deploy AI agents
- Secret management for agent access
- Resource isolation for parallel agents
- Observability into agent activities

**Success Quote**: *"I want AI agent infrastructure that follows GitOps principles and integrates with our existing K8s stack."*

**Source PDRs**: PDR-009, PDR-011, PDR-012, PDR-035

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

**Acceptance Criteria**:
- [ ] All supported agents listed in AGENT_CONFIG
- [ ] Each agent has command templates generated
- [ ] Cross-agent test pass rate > 95%

---

#### FR-SK-002: Spec-Driven Development Workflow

**Description**: Implement specification-first development workflow

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| `/spec.specify` command | Must | PDR-002 |
| `/spec.plan` command | Must | PDR-002 |
| `/spec.tasks` command | Must | PDR-002 |
| `/spec.implement` command | Must | PDR-002 |
| Specs stored in `specs/{feature}/` | Must | PDR-002 |

**Acceptance Criteria**:
- [ ] Complete workflow from spec to implementation
- [ ] All artifacts version-controlled in git
- [ ] Spec freshness < 1 week stale

---

#### FR-SK-003: Three-Level Work Decomposition

**Description**: Implement Milestone → Slice → Task hierarchy

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Milestones as shippable versions | Must | PDR-020 |
| Slices as demo-able vertical capabilities | Must | PDR-020 |
| Tasks fit in one context window | Must | PDR-020 |
| Demo sentence for each slice | Should | PDR-020 |

**Acceptance Criteria**:
- [ ] 3-7 tasks per slice average
- [ ] Each slice has demo sentence
- [ ] Task quality consistent across session

---

#### FR-SK-004: Context Engineering

**Description**: Treat context as finite budget with graduated compaction

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Five-stage graduated compaction (70/80/85/90/99%) | Must | PDR-016 |
| Per-tool-type summarization | Should | PDR-016 |
| Large output offloading (> 8,000 chars) | Should | PDR-016 |
| Dual-memory architecture | Should | PDR-017 |

**Acceptance Criteria**:
- [ ] Session length 30+ turns before compaction
- [ ] Context reduction 50%+
- [ ] Critical identifiers preserved > 95%

---

#### FR-SK-005: Verification Ladder

**Description**: Implement goal-backward verification with 4-tier ladder

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Static verification (files, exports, wiring) | Must | PDR-025 |
| Command verification (tests, build, lint) | Must | PDR-025 |
| Behavioral verification (browser, API) | Should | PDR-025 |
| Stub detection | Must | PDR-025 |

**Acceptance Criteria**:
- [ ] Verification pass rate > 95%
- [ ] 100% of stubs caught
- [ ] Human verification < 10%

---

#### FR-SK-006: Superpowers Workflow Patterns

**Description**: Enforce strict workflow discipline inspired by Superpowers

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Brainstorm-Then-Build gate | Must | PDR-054 |
| Baseline verification before work | Must | PDR-010, PDR-055 |
| Structured branch completion (A/B/C/D) | Must | PDR-027 |
| Evidence over claims (show output) | Must | PDR-056 |
| Rationalization detection (confidence markers) | Should | PDR-057 |
| Systematic debugging workflow | Must | PDR-058 |
| Verification before completion | Must | PDR-059 |
| Receiving and applying code review | Should | PDR-060 |

**Acceptance Criteria**:
- [ ] No implementation before design approval
- [ ] All claims substantiated with output
- [ ] Rationalization confidence levels visible
- [ ] Structured completion for every branch

---

### 6.2 Runner Requirements

#### FR-RN-001: Dual Execution Loop

**Description**: Support SYNC (interactive) and ASYNC (autonomous) execution

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| `[SYNC]` marker for human interaction | Must | PDR-003 |
| `[ASYNC]` marker for autonomous execution | Must | PDR-003 |
| `[P]` marker for parallel execution | Must | PDR-003 |
| Task marker parsing in tasks.md | Must | PDR-003 |

**Acceptance Criteria**:
- [ ] ASYNC task success rate > 90%
- [ ] Human time saved 40%+
- [ ] Correct routing by marker

---

#### FR-RN-002: K8s Subagent Pattern

**Description**: Spawn K8s pods for ASYNC task execution

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Pod spawning via spawn-pod.sh | Must | PDR-009 |
| Log streaming to main session | Must | PDR-009 |
| Continue-Here file on interruption | Should | PDR-009, PDR-028 |
| Fractal summaries via git | Should | PDR-009, PDR-024 |

**Acceptance Criteria**:
- [ ] Pod spawn success rate > 95%
- [ ] Log streaming latency < 5s
- [ ] Continue file recovery rate > 95%

---

#### FR-RN-003: Worktree Isolation

**Description**: Git worktree isolation for parallel tasks

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Local worktrees for `[P]` tasks | Must | PDR-010 |
| Spec branches for `[ASYNC]` tasks | Must | PDR-010 |
| Auto-cleanup after completion | Must | PDR-010 |
| Branch naming: `specs/<feature>/task-NNN-async` | Must | PDR-010 |

**Acceptance Criteria**:
- [ ] Parallel task conflicts 0%
- [ ] Cleanup success rate > 99%
- [ ] Worktree creation < 10s

---

#### FR-RN-004: OpenSandbox Integration

**Description**: Container-level isolation for ASYNC task execution via OpenSandbox

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| OpenSandbox K8s runtime deployment | Must | PDR-054 |
| gVisor RuntimeClass configuration | Must | PDR-054 |
| Python SDK integration with Spec Runner | Must | PDR-054 |
| BatchSandbox pooling (min 5, max 20) | Should | PDR-054 |
| Egress policy controls | Should | PDR-054 |
| CodeInterpreter for multi-language execution | Could | PDR-054 |

**Acceptance Criteria**:
- [ ] Sandbox creation time < 5s (pooled)
- [ ] Container isolation: gVisor enforced
- [ ] ASYNC task success rate > 90%
- [ ] Task contamination incidents: 0

---

### 6.3 Team Directives Requirements

#### FR-TD-001: Directives as Code

**Description**: Version-control all AI agent behavior

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Constitution file | Must | PDR-013 |
| Persona files in `context_modules/personas/` | Must | PDR-014 |
| Skills as versioned dependencies | Must | PDR-006 |
| Fork-and-customize pattern | Should | PDR-013 |

**Acceptance Criteria**:
- [ ] 100% of behaviors in version control
- [ ] Review compliance > 90%
- [ ] Fork adoption tracked

---

#### FR-TD-002: MCP Protocol Integration

**Description**: Integrate Model Context Protocol for tool access

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| `.mcp.json` configuration | Must | PDR-015 |
| GitHub MCP server support | Must | PDR-015 |
| Tool call success rate > 90% | Should | PDR-015 |

---

### 6.4 Agents Workspaces Requirements

#### FR-AW-001: Cluster-per-Workspace

**Description**: Provision dedicated K8s cluster per workspace

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Physical cluster per workspace | Must | PDR-043 |
| Three namespaces: dev, stg, prd | Must | PDR-043 |
| Terraform + Crossplane provisioning | Must | PDR-043 |
| Provisioning time < 15 min | Should | PDR-043 |

**Acceptance Criteria**:
- [ ] Cluster provisioning success > 98%
- [ ] Cost per workspace trackable
- [ ] Explicit destroy only

---

#### FR-AW-002: Multi-Cloud Support

**Description**: Support GCP, AWS, Azure from v1.0

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| GKE support | Must | PDR-044 |
| EKS support | Must | PDR-044 |
| AKS support | Must | PDR-044 |
| Feature parity > 90% | Should | PDR-044 |

---

#### FR-AW-003: OpenCode Server Attach

**Description**: CLI-to-server attachment for workspace interaction

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| kubectl port-forward for BYOC | Must | PDR-045 |
| Managed ingress for cloud | Should | PDR-045 |
| Attach latency < 5s | Should | PDR-045 |
| Multi-user collaboration | Should | PDR-048 |

---

#### FR-AW-004: Base Image with Tools

**Description**: Pre-installed agentic tools in base image

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| OpenCode server pre-installed | Must | PDR-046 |
| Spec Kit pre-installed | Must | PDR-046 |
| Spec Runner pre-installed | Must | PDR-046 |
| Base image size < 2GB | Should | PDR-046 |

---

### 6.5 Agent Runner Requirements

#### FR-AR-001: Squad Mode (Outer Loop)

**Description**: PRD → Implementation workflow with human-in-the-loop

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| PRD conversation interface | Must | PDR-053 |
| `/spec.specify` command | Must | PDR-053 |
| Eval clarification phase | Must | PDR-053 |
| Plan generation | Must | PDR-053 |
| Triage/prioritization | Must | PDR-053 |
| tasks.md output | Must | PDR-053 |

**Acceptance Criteria**:
- [ ] Human can pick from PRD
- [ ] Plan approval required before execution
- [ ] Results reviewable by human

---

#### FR-AR-002: Spec Mode (Inner Loop)

**Description**: Task → Implementation execution with Autoresearch pattern

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Task → Spec → Impl → Verify | Must | PDR-053 |
| Time-bounded execution | Should | PDR-053 |
| Eval-gated keep/reset | Should | PDR-053 |
| Results logging | Should | PDR-053 |

**Acceptance Criteria**:
- [ ] Spec mode is backward-compatible with spec-runner
- [ ] Time budget configurable per task
- [ ] Results observable

---

#### FR-AR-003: Harness Synthesis (Optional)

**Description**: AutoHarness-style validation of generated code

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Action verifier harness | Should | PDR-053 |
| Code-as-policy generation | Could | PDR-053 |
| Max synthesis iterations | Should | PDR-053 |
| Harness type configuration | Should | PDR-053 |

**Acceptance Criteria**:
- [ ] Smaller model + harness > larger model
- [ ] Automatic validation beyond manual tests

---

#### FR-AR-004: Multi-Squad Support

**Description**: Multiple independent squads without coordination

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Multiple squad definitions | Must | PDR-053 |
| Squad-specific roles | Must | PDR-053 |
| Per-squad workflow config | Must | PDR-053 |
| Standalone operation | Must | PDR-053 |

**Acceptance Criteria**:
- [ ] Each squad operates independently
- [ ] No cross-squad coordination required

---

#### FR-AR-005: Multi-Agent Workspace Management

**Description**: Manage multiple terminal sessions via cmux for squad coordination

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| cmux session multiplexing | Must | PDR-061 |
| Named windows per agent role | Must | PDR-061 |
| Inter-window communication | Must | PDR-061 |
| Log aggregation from all windows | Should | PDR-061 |
| Session state persistence | Should | PDR-061 |
| tmuxp compatibility | Should | PDR-061 |

**Acceptance Criteria**:
- [ ] 5+ concurrent agent sessions visible
- [ ] Logs from all windows aggregated
- [ ] Session recovery after disconnection

---

### 6.6 System Requirements

#### FR-SYS-001: Agent Observability

**Description**: Runtime visibility into agent activities

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Agent activity logging | Must | PDR-049 |
| Metrics collection | Must | PDR-049 |
| Trace aggregation | Should | PDR-049 |
| Dashboard visualization | Should | PDR-049 |

---

#### FR-SYS-002: Evals Extension

**Description**: Evaluation framework integration with Runner

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| Runner eval integration | Must | PDR-050 |
| Eval result storage | Must | PDR-050 |
| Trending analysis | Should | PDR-050 |

---

#### FR-SYS-003: Sandbox Compute

**Description**: Secure isolated execution environment

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| WASM sandbox isolation | Must | PDR-051 |
| Resource limits | Must | PDR-051 |
| Network isolation | Should | PDR-051 |

---

#### FR-SYS-004: Repository Split

**Description**: Separate open source and commercial extensions

| Requirement | Priority | Source PDR |
|-------------|----------|------------|
| GitHub open source repo | Must | PDR-052 |
| GitLab commercial repo | Must | PDR-052 |
| Extension catalog sync | Must | PDR-052 |

## 7. Non-Functional Requirements

### 7.1 Performance

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Pod spawn time | < 60s | PDR-009 |
| Worktree creation | < 10s | PDR-010 |
| Context compaction | < 2s per stage | PDR-016 |
| Cluster provisioning | < 15 min | PDR-043 |
| Workspace startup | < 60s (pre-pulled) | PDR-046 |
| Sandbox creation (pooled) | < 5s | PDR-054 |

### 7.2 Security

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Schema-level tool restrictions | 100% enforced | PDR-019 |
| External Secrets Operator | Required for production | PDR-012 |
| No hardcoded secrets | 0 violations | PDR-012 |
| Five-layer defense-in-depth | Implemented | PDR-019 |
| Safety violations | 0 | PDR-019 |
| AutoHarness illegal action prevention | 100% | PDR-019, PDR-053 |
| Container isolation (gVisor) | Enforced | PDR-054 |
| Task contamination | 0 incidents | PDR-054 |
| gVisor compatibility | > 80% tools | PDR-054 |

### 7.3 Reliability

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Pod spawn success rate | > 95% | PDR-009 |
| ASYNC task success rate | > 90% | PDR-003 |
| Cluster provisioning success | > 98% | PDR-043 |
| Session stability | > 99% | PDR-045 |
| Workspace uptime | > 99.5% | PDR-042 |

### 7.4 Scalability

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| Parallel local agents | 5+ via [P] | PDR-009 |
| Parallel K8s pods | Limited by cluster | PDR-009 |
| Concurrent workspace users | Up to 5 | PDR-048 |
| Projects per cluster | Tracked | PDR-043 |

### 7.5 Usability

| Requirement | Target | Source PDR |
|-------------|--------|------------|
| New agent addition | < 1 day | PDR-001 |
| Spec freshness | < 1 week stale | PDR-002 |
| Extension activation rate | > 60% | PDR-007 |
| Auto-detection accuracy | > 95% | PDR-047 |

---

## 8. Out of Scope

### 8.1 Explicitly Excluded

| Exclusion | Rationale | Related PDR |
|-----------|-----------|-------------|
| Custom AI model training | Focus on using existing agents | PDR-001 |
| IDE/editor development | Integrate with existing tools | PDR-001 |
| Cloud billing management | Use native cloud tools | PDR-043 |
| General CI/CD pipelines | Focus on agentic workflows | PDR-009 |
| Web UI for workspaces (v1) | CLI-first approach | PDR-045 |

### 8.2 Deferred to Future

| Feature | Target Phase | Related PDR |
|---------|--------------|-------------|
| Managed multi-tenant clusters | v2.0 | PDR-043 |
| Scheduled workspace hibernation | v2.0 | PDR-043 |
| Web UI for workspace access | v2.0 | PDR-045 |
| Cross-workspace collaboration | v2.0 | PDR-048 |

---

## 9. Risks & Mitigation

### 9.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation | Source PDR |
|------|------------|--------|------------|------------|
| Context rot in long sessions | High | High | Graduated compaction; dual-memory | PDR-016, PDR-017 |
| Agent API divergence over time | Medium | High | Abstraction layer; version pinning | PDR-001 |
| Doom-loop (infinite tool repetition) | Medium | Medium | MD5 fingerprinting; escalation | PDR-018 |
| Cluster provisioning failures | Low | High | Retry logic; health checks | PDR-043 |
| Git worktree bugs | Low | Low | Stable git versions; fallback | PDR-010 |

### 9.2 Market/Adoption Risks

| Risk | Likelihood | Impact | Mitigation | Source PDR |
|------|------------|--------|------------|------------|
| Teams bypass process for "vibe coding" | High | Medium | Clear value demonstration; tooling | PDR-002 |
| Skills ecosystem may not grow | Medium | Medium | Quality evaluation framework | PDR-006 |
| MCP protocol changes | Medium | Low | Protocol version pinning | PDR-015 |
| Competitors fork without contributing | Low | Low | Community engagement | PDR-005 |

### 9.3 Operational Risks

| Risk | Likelihood | Impact | Mitigation | Source PDR |
|------|------------|--------|------------|------------|
| Cost explosion (cluster per workspace) | High | High | Cost alerts; size limits; auto-shutdown | PDR-043 |
| ESO not configured before GitOps | Medium | High | Pre-flight checks; documentation | PDR-011 |
| Orphaned clusters | Medium | High | Explicit destroy policy | PDR-043 |
| Base image bloat | Medium | Medium | Modular images (minimal/standard/full) | PDR-046 |

---

## 10. Roadmap & Milestones

### 10.1 Product Maturity by Component

| Product | Status | Maturity | Key Gaps |
|---------|--------|----------|----------|
| **Spec Kit** | Active Development | 80% | Worktrunk integration, parallel execution |
| **Runner** | Active Development | 70% | Continue-Here recovery, observability |
| **Team Directives** | Stable | 90% | Fork sync automation |
| **Agents Workspaces** | Implementation Started | 15% | Infra issues open (6 GitLab, 3 GitHub) |

### 10.2 Milestone 1: Spec Kit Parallel Execution

**Target**: Q2 2026  
**Demo Sentence**: *"After this milestone, developers can run 5+ agents in parallel with worktree isolation."*

| Feature | Priority | Dependencies | Source PDR |
|---------|----------|--------------|------------|
| Worktrunk integration | Must | None | PDR-010 |
| Dependency-aware orchestration | Must | Worktrunk | PDR-020 |
| Continue-Here for pods | Should | K8s Runner | PDR-028 |
| Progress.md logging | Should | None | PDR-009 |

**Success Criteria**:
- Multiple [P] tasks execute simultaneously
- Pre-merge hooks prevent merging with unmet dependencies
- ASYNC tasks receive worktree branch context

---

### 10.3 Milestone 2: Agents Workspaces Alpha

**Target**: Q3 2026  
**Demo Sentence**: *"After this milestone, developers can provision a cloud workspace and attach via CLI."*

**Implementation Status**: In Progress  
**GitLab Repo**: https://gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-agent-workspaces  
**GitHub Milestone**: https://github.com/tikalk/agentic-sdlc-spec-kit/milestone/1

| Feature | Priority | GitLab Issue | GitHub Issue | Status |
|---------|----------|--------------|--------------|--------|
| GCP Cluster Provisioning | Must | SPEC-001 | - | Open |
| Crossplane Integration | Must | SPEC-002 | - | Open |
| Base Image Layers | Must | SPEC-007 | - | Open |
| Dockerfile Overlay System | Should | SPEC-008 | - | Open |
| OpenCode Server in Pods | Must | SPEC-004 | - | Open |
| CLI-to-Server Attach | Must | SPEC-005 | - | Open |
| Extension Manifest (extension.yml) | Must | - | #85 | Open |
| Commands (init/attach/list/status/destroy) | Must | - | #85 | Open |
| Hooks Integration | Must | - | #86 | Open |
| Config Template | Should | - | #87 | Open |

**Infrastructure Architecture**:
- **Runtime Layer**: `agentic-sdlc-runner` provides Docker base image, Helm charts, and pod management scripts
- **Provisioning**: Crossplane workspace-specific compositions (Option A)
- **Registry**: `gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-agent-workspaces`

**Success Criteria**:
- Cluster provisioning < 15 min
- Attach latency < 5s
- Base image < 2GB

---

### 10.4 Milestone 3: Multi-Cloud & Collaboration

**Target**: Q4 2026  
**Demo Sentence**: *"After this milestone, teams can collaborate on workspaces across any major cloud."*

| Feature | Priority | Dependencies | Source PDR |
|---------|----------|--------------|------------|
| AWS (EKS) support | Must | Terraform modules | PDR-044 |
| Azure (AKS) support | Must | Terraform modules | PDR-044 |
| Multi-user sessions | Should | Session manager | PDR-048 |
| Presence indicators | Should | Multi-user | PDR-048 |

**Success Criteria**:
- Feature parity > 90% across clouds
- Concurrent users up to 5
- Collaboration satisfaction > 80%

---

### 10.5 Milestone 4: Agent Runner

**Target**: Q2 2026  
**Demo Sentence**: *"After this milestone, the Agent Runner can take a PRD, generate a spec, plan implementation, and execute via Spec Runner."*

| Feature | Priority | Dependencies | Source PDR |
|---------|----------|--------------|------------|
| Squad mode implementation | Must | Spec Kit | PDR-053 |
| Spec mode (from spec-runner) | Must | Spec Kit | PDR-053 |
| PRD conversation interface | Must | None | PDR-053 |
| Triage/prioritization | Must | /spec.plan | PDR-053 |
| Multi-squad config | Should | None | PDR-053 |

**Success Criteria**:
- PRD → tasks.md generation works
- Spec Runner integration functional
- Human-in-the-loop at PRD selection and plan approval

---

### 10.6 Milestone 5: Harness Synthesis

**Target**: Q3 2026  
**Demo Sentence**: *"After this milestone, Agent Runner can auto-synthesize validation harnesses for generated code."*

| Feature | Priority | Dependencies | Source PDR |
|---------|----------|--------------|------------|
| Action verifier harness | Should | Agent Runner | PDR-053 |
| Eval-gated keep/reset | Should | Agent Runner | PDR-053 |
| Time-bounded execution | Should | Agent Runner | PDR-053 |
| Code-as-policy generation | Could | Agent Runner | PDR-053 |

**Success Criteria**:
- Harness synthesis reduces invalid implementations
- Smaller model + harness > larger model

---

## 11. PDR Traceability

### 11.1 PDR Summary by Product

| Product | PDR Count | Categories |
|---------|-----------|------------|
| Spec Kit | 36 | System, Technical, Workflow, Quality, Architecture |
| Runner | 7 | System, Infrastructure, Technical, Security |
| Team Directives | 4 | System |
| Agents Workspaces | 7 | System, Infrastructure, Runtime, Workspace, Session |
| Agent Runner | 2 | System, Orchestration |
| **Total** | **61** | |

### 11.2 PDR Coverage by PRD Section

| PRD Section | PDRs Referenced |
|-------------|-----------------|
| 1. Overview | PDR-001, PDR-002, PDR-004, PDR-005, PDR-042 |
| 2. The Problem | PDR-002, PDR-013, PDR-016, PDR-023, PDR-025 |
| 3. Goals & Objectives | PDR-002, PDR-003, PDR-016, PDR-022, PDR-025 |
| 4. Success Metrics | PDR-001, PDR-002, PDR-003, PDR-009, PDR-016, PDR-023, PDR-025 |
| 5. Personas | PDR-002, PDR-013, PDR-016, PDR-025, PDR-037, PDR-042, PDR-048 |
| 6. Functional Requirements | All 56 PDRs |
| 7. Non-Functional Requirements | PDR-009, PDR-012, PDR-016, PDR-019, PDR-043, PDR-046 |
| 8. Out of Scope | PDR-001, PDR-043, PDR-045 |
| 9. Risks & Mitigation | All PDRs (consequence sections) |
| 10. Roadmap & Milestones | PDR-010, PDR-020, PDR-028, PDR-043, PDR-044, PDR-045, PDR-048, PDR-053, PDR-061 |

### 11.3 Full PDR Index

| ID | Product | Feature Area | Decision | Status |
|----|---------|--------------|----------|--------|
| PDR-001 | Spec Kit | System | Multi-Agent Ecosystem Strategy | Discovered |
| PDR-002 | Spec Kit | System | Spec-Driven Development Core | Discovered |
| PDR-003 | Runner | System | Dual Execution Loop (SYNC/ASYNC) | Discovered |
| PDR-004 | Spec Kit | System | 12-Factor Agentic SDLC Integration | Discovered |
| PDR-005 | Spec Kit | Business | Open Source B2D Model | Discovered |
| PDR-006 | Spec Kit | System | Skills as Versioned Dependencies | Discovered |
| PDR-007 | Spec Kit | System | Extension-Based Architecture | Discovered |
| PDR-008 | Spec Kit | System | Two-Level Architecture System | Discovered |
| PDR-009 | Runner | Infrastructure | K8s Subagent Pattern | Discovered |
| PDR-010 | Runner | Infrastructure | Worktree Isolation (Local + Remote) | Discovered |
| PDR-011 | Runner | Infrastructure | GitOps-First Deployment | Discovered |
| PDR-012 | Runner | Security | External Secrets Operator Integration | Discovered |
| PDR-013 | Team Directives | System | Directives as Code | Discovered |
| PDR-014 | Team Directives | System | Persona-Driven Context Loading | Discovered |
| PDR-015 | Team Directives | System | MCP Protocol Integration | Discovered |
| PDR-016 | Spec Kit | Technical | Context Engineering (Context as Budget) | Research-Backed |
| PDR-017 | Spec Kit | Technical | Dual-Memory Architecture | Research-Backed |
| PDR-018 | Runner | Technical | Harness Runtime Orchestration | Research-Backed |
| PDR-019 | System | Security | Safety Through Architectural Constraints | Research-Backed |
| PDR-020 | Spec Kit | Workflow | Three-Level Work Decomposition | GSD-Backed |
| PDR-021 | Spec Kit | Workflow | Boundary Maps (Interface-First) | GSD-Backed |
| PDR-022 | Spec Kit | Architecture | LLM/Deterministic Split | GSD-Backed |
| PDR-023 | Spec Kit | Technical | Context Pruning via Anchors | GSD-Backed |
| PDR-024 | Spec Kit | Technical | Fractal Summaries | GSD-Backed |
| PDR-025 | Spec Kit | Quality | Verification Ladder (Goal-Backward) | GSD-Backed |
| PDR-026 | Spec Kit | Workflow | Discuss Phase (Alignment Before Action) | GSD-Backed |
| PDR-027 | Spec Kit | Workflow | Git Strategy (Branch-Per-Slice) | GSD-Backed |
| PDR-028 | Spec Kit | Workflow | Continue-Here (Interruption Survival) | GSD-Backed |
| PDR-029 | Team Directives | System | Repository as System of Record | Harness-Backed |
| PDR-030 | Spec Kit | System | AGENTS.md as Table of Contents | Harness-Backed |
| PDR-031 | Spec Kit | Architecture | Agent Legibility First | Harness-Backed |
| PDR-032 | Spec Kit | Architecture | Mechanical Enforcement of Constraints | Harness-Backed |
| PDR-033 | Spec Kit | Workflow | High-Throughput Merge Philosophy | Harness-Backed |
| PDR-034 | Spec Kit | System | Golden Principles for Code Quality | Harness-Backed |
| PDR-035 | Spec Kit | Technical | Observability for Agents | Harness-Backed |
| PDR-036 | Spec Kit | Quality | UI Validation by Agents | Harness-Backed |
| PDR-037 | Spec Kit | System | End-to-End Agent Autonomy | Harness-Backed |
| PDR-038 | Spec Kit | System | Garbage Collection for Technical Debt | Harness-Backed |
| PDR-039 | Spec Kit | Quality | Human Veto Gates (The Great Filter) | 12-Factor Gap |
| PDR-040 | Spec Kit | Quality | AI Test Generation Strategy | 12-Factor Gap |
| PDR-041 | Spec Kit | System | Evals Framework for Continuous Improvement | 12-Factor Gap |
| PDR-042 | Agents Workspaces | System | New Product: Cloud-Native Agent Workspaces | Proposed |
| PDR-043 | Agents Workspaces | Infrastructure | Cluster-per-Workspace with IaC Provisioning | Proposed |
| PDR-044 | Agents Workspaces | Infrastructure | Multi-Cloud Support (GCP, AWS, Azure) | Proposed |
| PDR-045 | Agents Workspaces | Runtime | OpenCode Server with CLI-to-Server Attach | Proposed |
| PDR-046 | Agents Workspaces | Runtime | Base Image with Agentic Tools Pre-installed | Proposed |
| PDR-047 | Agents Workspaces | Workspace | Multi-Format Tool Configuration | Proposed |
| PDR-048 | Agents Workspaces | Session | Multi-User Collaborative Sessions | Proposed |
| PDR-049 | System | Technical | Agent Observability Platform | Gap Identified |
| PDR-050 | Spec Kit | Quality | Evals Extension with Runner Integration | Proposed |
| PDR-051 | Agent Workspaces | Security | Sandbox Compute (gVisor + Firecracker) | Proposed |
| PDR-052 | System | Architecture | Repository Split - Open Source vs Tikal | Proposed |
| PDR-053 | Agent Runner | System | Agent Runner - Unified Squad + Spec Runner | Proposed |
| PDR-054 | Spec Kit | Workflow | Brainstorm-Then-Build (Superpowers) | Proposed |
| PDR-055 | Spec Kit | Workflow | Session Knowledge Persistence (Compound Eng.) | Proposed |
| PDR-056 | Spec Kit | Quality | Evidence Over Claims (Superpowers) | Proposed |
| PDR-057 | Spec Kit | Quality | Rationalization Detection (Superpowers) | Proposed |
| PDR-058 | Spec Kit | Quality | Systematic Debugging (Superpowers) | Proposed |
| PDR-059 | Spec Kit | Quality | Verification Before Completion (Superpowers) | Proposed |
| PDR-060 | Spec Kit | Collaboration | Receiving Code Review (Superpowers) | Proposed |
| PDR-061 | Agent Runner | System | Multi-Agent Workspace Management (cmux) | Proposed |

---

## Appendix A: References

- **12-Factor Agentic SDLC**: https://tikalk.github.io/agentic-sdlc-12-factors/
- **Spec Kit Repository**: https://github.com/tikalk/agentic-sdlc-spec-kit
- **Agentic Workspaces (GitLab)**: https://gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-agent-workspaces
- **Research Paper**: arXiv:2603.05344v1 - "Building AI Coding Agents for the Terminal"
- **GSD 2.0 System**: "How We Built The World's Most Powerful Coding Agent"
- **Harness Engineering**: OpenAI Engineering Blog (February 2026)
- **Squad**: bradygaster/squad - Multi-agent teams for any project
- **Autoresearch**: karpathy/autoresearch - Bounded optimization for agents
- **AutoHarness**: arXiv:2603.03329 - Improving LLM agents by synthesizing code harnesses

---

## Appendix B: Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-09 | AI-Generated | Initial PRD from 48 PDRs |
| 1.1.0 | 2026-03-14 | AI-Generated | Added PDR-049 to PDR-053 (Agent Runner, AutoHarness) |
| 1.2.0 | 2026-03-16 | AI-Generated | Added PDR-054 (OpenSandbox Integration) |
| 1.3.0 | 2026-03-23 | AI-Generated | Added PDR-055 to PDR-061 (Superpowers patterns, Multi-Agent Workspace Management) |
| 1.4.0 | 2026-03-23 | AI-Generated | Added Milestone 2 implementation details: GitLab repo, issues, GitHub issues |

---

*This PRD is generated from Product Decision Records. For decision rationale, see `.specify/memory/pdr.md`.*