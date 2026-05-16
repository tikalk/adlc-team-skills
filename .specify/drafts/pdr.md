# Product Decision Records

## PDR Index

| ID | Title | Key Decision | Section | Status | Date |
|----|-------|--------------|---------|--------|------|
| PDR-078 | Hybrid Workspace Provisioning Strategy | Local dev containers + Remote cloud pods | 6.1, 4.1 | Accepted | 2026-05-07 |
| PDR-079 | Layered Hybrid Git Strategy | Worktrees (local) + Clones (remote) | 6.2, 4.2 | Accepted | 2026-05-07 |
| PDR-080 | Bimodal UX Strategy | CLI (developers) + Visual UI (non-devs), dual-primary | 6.3, 5, 4.3 | Accepted | 2026-05-07 |
| PDR-081 | Unified Abstraction Agent Model | Single SDLC interface with adapters | 6.4, 4.4 | Accepted | 2026-05-07 |
| PDR-082 | Dependency-Driven Async Orchestration | Marker-based DAG (`[P]`, `[ASYNC]`, `[SYNC]`) | 6.4, 4.4 | Accepted | 2026-05-07 |

---

## PDR-078: Hybrid Workspace Provisioning Strategy

**Status**: Accepted

**Date**: 2026-05-07

**Owner**: Product Team

### Context

Current AI coding tools force uncomfortable trade-offs between local development (speed) and remote execution (isolation). Developers need both capabilities without choosing one permanently.

**Problem Statement**:
- Local tools are fast but limited by user machine resources
- Cloud tools provide isolation but introduce latency and forced workflows
- No solution adapts to context (task type, security needs, resource requirements)

### Decision

Implement **two workspace types** with unified abstraction:

1. **Local Workspaces** (Docker dev containers)
   - Target: <30 second provisioning
   - Use case: Quick tasks, offline work, developer iteration
   - Strategy: Worktree-based git (immediate state visibility)

2. **Remote Workspaces** (Kubernetes pods)
   - Target: <60 second provisioning
   - Use case: Long-running tasks, resource-intensive work, security isolation
   - Strategy: Clone-based git (isolation guarantees)

**Selection Criteria**:
- Auto-select based on task context
- Manual override with user acknowledgment
- >90% feature parity between both types

### Consequences

**Positive**:
- Optimal environment for each use case
- Progressive adoption path (start local, graduate to remote)
- Security isolation when needed
- Fast iteration when preferred

**Negative**:
- Dual code paths increase complexity
- Testing matrix covers both environments
- Documentation must cover both strategies

**Metrics**:
| Metric | Target |
|--------|--------|
| Local provisioning | <30 seconds (95th percentile) |
| Remote provisioning | <60 seconds (95th percentile) |
| Feature parity | >90% coverage |

### Related ADRs

- ADR-007: Docker-Based OpenCode Server (local)
- ADR-006: K8s Subagent Pattern (remote)
- ADR-016: Hybrid Workspace Provisioning
- ADR-014: Dev Container Spec Tool Provisioning

---

## PDR-079: Layered Hybrid Git Strategy

**Status**: Accepted

**Date**: 2026-05-07

**Owner**: Product Team

### Context

Git workflows must adapt to workspace type. Local workspaces need speed (worktrees), remote workspaces need isolation (clones). A one-size-fits-all strategy fails both use cases.

**Problem Statement**:
- Async agent tasks require constant commit/push cycles with clone-based workflows
- Worktrees provide immediate visibility but don't work for remote isolation
- State handoff between local and remote is manual and error-prone

### Decision

Implement **layered git strategy** adapted to workspace type:

1. **Local (Worktree Strategy)**
   - Multiple working directories from single clone
   - Immediate file change visibility (<1 second)
   - Parallel async tasks on separate worktrees
   - Automatic conflict detection

2. **Remote (Clone Strategy)**
   - Fresh clone per remote workspace
   - Optimized clones (shallow where appropriate)
   - Explicit commit/push for state sharing
   - <30 second commit/push/pull cycle

**State Handoff**:
- Local → Remote: Commit and push
- Remote → Local: Pull and merge
- Clear UX indicators of sync status

### Consequences

**Positive**:
- Optimal for each environment
- Fast local iteration (<5s task startup)
- Secure remote isolation (<15s task startup)
- Clear sync semantics

**Negative**:
- Two strategies to learn and maintain
- Handoff requires explicit user action
- Potential for sync conflicts

**Metrics**:
| Metric | Target |
|--------|--------|
| Local task startup | <5 seconds |
| Remote task startup | <15 seconds (including clone) |
| State handoff cycle | <30 seconds |

### Related ADRs

- ADR-017: Layered Git Strategy
- ADR-013: Git-Based Workspace Lifecycle

---

## PDR-080: Bimodal UX Strategy

**Status**: Accepted

**Date**: 2026-05-07

**Owner**: Product Team

### Context

AI tools historically serve either developers (CLI) or non-developers (GUI), excluding one group. The platform must serve both personas equally without compromise.

**Problem Statement**:
- CLI tools exclude non-developers (Product Managers, Designers)
- GUI tools limit developer efficiency
- Spec format divergence between tools creates confusion
- Team fragmentation across tool preferences

### Decision

Implement **dual-primary bimodal interface**:

1. **CLI (Developers)**
   - Optimized for speed (<30s common tasks)
   - Command completion and scripting
   - Direct spec file editing
   - Shows UI equivalents for learning

2. **Visual UI (Non-Developers)**
   - Guided workflows for spec creation
   - Real-time progress dashboards
   - >80% task completion rate target
   - "Open in CLI" links for skill building

**Shared Foundation**:
- Single YAML/Markdown spec format
- 100% round-trip fidelity
- Schema validation on import/export
- Progressive disclosure (UI → CLI graduation)

### Consequences

**Positive**:
- Serves both personas equally
- Shared source of truth
- Collaboration across skill levels
- No team fragmentation

**Negative**:
- Two interfaces to maintain
- Feature parity requirements
- Design complexity for shared format

**Personas**:

**Persona A: AI Team Lead (Developer)**
- Role: Senior engineer managing AI adoption
- Goals: Fast iteration, local control, git integration
- Quote: *"I want agents that work with my existing dev setup, not replace it."*

**Persona B: Product Manager (Non-Developer)**
- Role: PM, designer, TPM
- Goals: Self-service workflows, visibility, collaboration
- Quote: *"I want to kick off specs and see agent progress without touching the command line."*

**Metrics**:
| Metric | Target |
|--------|--------|
| Non-developer task completion | >80% |
| Developer CLI efficiency | <30s common tasks |
| Spec round-trip fidelity | 100% |

### Related ADRs

- ADR-018: Bimodal Interface
- ADR-015: Hybrid Client Extension

---

## PDR-081: Unified Abstraction Agent Model

**Status**: Accepted

**Date**: 2026-05-07

**Owner**: Product Team

### Context

AI agents (Claude, GPT-4, Gemini) have proprietary interfaces. Hardcoding creates vendor lock-in and prevents using best-fit models per task.

**Problem Statement**:
- Each vendor has unique APIs and capabilities
- Switching agents requires workflow changes
- Teams cannot optimize model selection per task
- Agent-specific bugs hidden by lack of abstraction

### Decision

Implement **unified SDLC command abstraction**:

**Adapter Pattern**:
- Single command interface: `specify`, `plan`, `implement`, `validate`
- Vendor-specific adapters implement interface
- Versioned API for stability
- Feature parity tracking across agents

**Reference Implementations**:
- Claude (primary)
- GPT-4
- Gemini

**Swap Criteria**:
- <1 hour to switch workspace between agents
- 100% core feature parity
- <2 days to add new agent support

### Consequences

**Positive**:
- Vendor independence
- Best-fit model per task
- Unified tooling
- Future-proof for new agents

**Negative**:
- Adapter maintenance overhead
- Lowest-common-denominator risk
- Comprehensive test suite required per agent

**Security**:
- All agent actions through SDLC command layer
- No unauthorized tool access
- Complete audit logging

**Metrics**:
| Metric | Target |
|--------|--------|
| Agent swap time | <1 hour |
| Core feature parity | 100% |
| New agent support | <2 days |

### Related ADRs

- ADR-004: Multi-Agent Abstraction Layer
- ADR-008: Context Engineering

---

## PDR-082: Dependency-Driven Async Orchestration

**Status**: Accepted

**Date**: 2026-05-07

**Owner**: Product Team

### Context

Task dependencies are often implicit. Parallel execution opportunities are missed. Manual coordination wastes time.

**Problem Statement**:
- No visibility into parallel vs sequential tasks
- Dependency misdeclaration causes conflicts
- Manual task coordination is error-prone
- Context window limits concurrent agents

### Decision

Implement **marker-based DAG orchestration**:

**Execution Markers**:
- `[P]` - Parallel (can execute concurrently)
- `[ASYNC]` - Autonomous (no human gate)
- `[SYNC]` - Human-gated (requires approval)

**DAG Builder**:
- Parse markers from Markdown specs
- Build dependency graph in <2 seconds
- Execute according to graph topology
- Enforce sequential dependencies

**Constraints**:
- Max 4 concurrent agents (context window limit)
- Automatic retry with sequential fallback on conflict
- <5% conflict resolution rate target

### Consequences

**Positive**:
- >70% parallel utilization
- Dependency clarity in spec
- Automatic optimization
- Human gates at appropriate points

**Negative**:
- Marker syntax learning curve
- Misdeclaration risk
- Runtime conflict detection needed

**Workflow**:
```
User Request → Parse Markers → Build DAG → Execute Tasks
                    ↓
            [P] Parallel → Concurrent execution
            [ASYNC] Autonomous → No human gate
            [SYNC] Human-gated → Pause for approval
```

**Metrics**:
| Metric | Target |
|--------|--------|
| Parallel utilization | >70% |
| DAG build time | <2 seconds |
| Conflict resolution rate | <5% |
| Marker prediction accuracy | >85% |

### Related ADRs

- ADR-019: Marker-Based DAG Orchestration
- ADR-010: Three-Level Work Decomposition

---

## Constitution Alignment

All PDRs align with constitutional principles:

| Principle | PDRs |
|-----------|------|
| **Spec-Driven Development** | PDR-080 (shared spec format) |
| **Human-in-the-Loop** | PDR-082 (`[SYNC]` markers), PDR-078 (commit gates) |
| **Context as Budget** | PDR-082 (parallel limits), PDR-081 (context engineering) |
| **Multi-Agent Agnosticism** | PDR-081 (unified abstraction) |
| **Safety Through Constraints** | PDR-078 (workspace isolation), PDR-082 (schema validation) |

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **CLI** | Command-Line Interface |
| **DAG** | Directed Acyclic Graph |
| **MST** | Milestone/Slice/Task hierarchy |
| **PDR** | Product Decision Record |
| **UI** | User Interface |
| **Worktree** | Git feature for multiple working directories |

## Appendix B: File Locations

| Artifact | Location |
|----------|----------|
| This PDR | `.specify/drafts/pdr.md` |
| ADRs | `.specify/memory/adr.md` |
| Constitution | `.specify/memory/constitution.md` |
| PRD | `PRD.md` (parent document) |

---

*This file is auto-generated from PRD.md. Last updated: 2026-05-09*
