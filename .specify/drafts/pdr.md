# Product Decision Records

## PDR Index

| ID | Title | Key Decision | Section | Status | Date |
|----|-------|--------------|---------|--------|------|
| PDR-078 | Hybrid Workspace Provisioning Strategy | Local dev containers + Remote cloud pods | 6.1, 4.1 | Accepted | 2026-05-07 |
| PDR-079 | Layered Hybrid Git Strategy | Worktrees (local) + Clones (remote) | 6.2, 4.2 | Accepted | 2026-05-07 |
| PDR-080 | Bimodal UX Strategy | CLI (developers) + Visual UI (non-devs), dual-primary | 6.3, 5, 4.3 | Accepted | 2026-05-07 |
| PDR-081 | Unified Abstraction Agent Model | Single SDLC interface with adapters | 6.4, 4.4 | Accepted | 2026-05-07 |
| PDR-082 | Dependency-Driven Async Orchestration | Marker-based DAG (`[P]`, `[ASYNC]`, `[SYNC]`) | 6.4, 4.4 | Accepted | 2026-05-07 |
| PDR-083 | Milestone-Level Verification with /goal Pattern | Fast transcript-based evaluator, 3-retry limit | 6.5, 4.5 | Accepted | 2026-05-16 |

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

## PDR-083: Milestone-Level Verification with /goal Pattern

**Status**: Accepted

**Date**: 2026-05-16

**Owner**: Product Team

### Context

Current agentic-sdlc executes milestones and tasks without explicit verification of completion quality. Users must manually review agent output to determine if work meets requirements. This creates friction, slows iteration, and leads to inconsistent quality gates.

**Problem Statement**:
- No automated way to verify milestone completion against intent
- Manual review required for every milestone, even routine ones
- No bounded retry mechanism when work doesn't meet criteria
- Inconsistent quality standards across different users/specs

**Market Context**:
- Anthropic's /goal feature (May 2026) demonstrated fast, transcript-based verification using lightweight models
- Outcomes API showed isolated grading pattern, but adds significant overhead
- Community demand for autonomous agent execution with reliable completion detection

### Decision

Implement **milestone-level verification** using a **/goal-style fast evaluator pattern**:

**Core Mechanism**:
1. **Implicit Goal Derivation**: Mission brief (spec description) serves as the goal condition
2. **Transcript-Based Evaluation**: Fast model (Haiku-3.5 equivalent) reads conversation transcript
3. **Binary Judgment**: Pass/fail based on whether goal appears achieved
4. **Bounded Retries**: Auto-retry up to 3 iterations, user can override mid-run
5. **Integration Points**: Runs at milestone completion and before `[SYNC]` gates

**Verification Trigger Points**:
| Point | Behavior |
|-------|----------|
| Milestone Complete | Verify achievement, continue if passed |
| Before `[SYNC]` Gate | Mandatory verification, block until passed |
| User Override | Ctrl+C or explicit stop command aborts verification |

**Structured Output Format**:
```
✓ Milestone "Implement Auth API" verified (1/3)
  Goal: "User login endpoint returns 200 with valid JWT token"
  Result: PASS - Tests pass, endpoint responds correctly
  Duration: 1.2s
```

### Consequences

**Positive**:
- **Autonomous execution**: Agents can run multiple iterations without babysitting
- **Fast verification**: Sub-second evaluation using lightweight model
- **Zero config**: Mission brief = goal, no extra fields needed
- **Bounded safety**: 3-retry limit prevents infinite loops
- **Human override**: Users can interrupt when things go wrong
- **Quality gates**: Automatic verification before human `[SYNC]` reviews

**Negative**:
- **Transcript dependency**: Evaluator only sees what agent explicitly outputs
- **Cost overhead**: Additional LLM call per verification (~$0.001-0.005 per check)
- **Vague goal risk**: Poorly written mission briefs lead to unreliable verification
- **Model limitations**: Fast model may miss subtle issues vs. full-power model

**Risks**:
- **False positives**: Evaluator may pass incomplete work if agent describes it well
  - *Mitigation*: Require explicit test output or file diffs in transcript
- **False negatives**: Evaluator may fail valid work due to strict interpretation
  - *Mitigation*: User override capability, retry with clearer agent prompts

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Verification latency | <2s (p95) | Time from milestone complete to result |
| False positive rate | <5% | Verification passes but human finds issues |
| False negative rate | <10% | Verification fails but work is actually complete |
| User override rate | <15% | Users manually stopping verification loops |
| Cost per verification | <$0.01 | API costs for fast model evaluation |

### Common Alternatives

#### Option A: Outcomes-Style Isolated Grading
**Description**: Separate isolated grader reads only output + rubric, not conversation
**Trade-offs**: Higher accuracy (no reasoning bias), but 10x cost and 5-10s latency per verification. Better for final deliverables than iterative milestone checks.

#### Option B: Human-in-the-Loop Only
**Description**: No automated verification, pause at every milestone for human review
**Trade-offs**: Zero automation overhead, but removes autonomous execution benefit. Suitable for highly sensitive work where human judgment is mandatory.

#### Option C: Agent Self-Evaluation
**Description**: Agent evaluates its own completion without separate model
**Trade-offs**: Near-zero cost, but high false positive risk (agents tend to declare success prematurely). Not recommended for quality-critical workflows.

### Related ADRs

- ADR-082: Marker-Based DAG Orchestration (`[SYNC]` gate integration)
- ADR-081: Unified Abstraction Agent Model (evaluator model selection)
- ADR-080: Bimodal UX Strategy (structured output format for CLI/UI)

---

## Constitution Alignment

All PDRs align with constitutional principles:

| Principle | PDRs |
|-----------|------|
| **Spec-Driven Development** | PDR-080 (shared spec format), PDR-083 (mission brief as goal) |
| **Human-in-the-Loop** | PDR-082 (`[SYNC]` markers), PDR-078 (commit gates), PDR-083 (user override) |
| **Context as Budget** | PDR-082 (parallel limits), PDR-081 (context engineering), PDR-083 (fast model) |
| **Multi-Agent Agnosticism** | PDR-081 (unified abstraction) |
| **Safety Through Constraints** | PDR-078 (workspace isolation), PDR-082 (schema validation), PDR-083 (3-retry limit) |

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

*This file is auto-generated from PRD.md. Last updated: 2026-05-16*
