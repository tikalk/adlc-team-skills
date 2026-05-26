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
| PDR-084 | Spec-Driven Development | spec.md as single source of truth, 100% spec coverage | Ecosystem | Accepted | 2026-05-18 |
| PDR-085 | Dual Execution Loops | SYNC vs ASYNC execution model with classification | Ecosystem | Accepted | 2026-05-18 |
| PDR-086 | Team Directives as Code | Version-controlled AI behavior in Git | Ecosystem | Accepted | 2026-05-18 |
| PDR-087 | Eval-Driven Development | Define "good" through structured evals | Tikal Directives | Accepted | 2026-05-18 |
| PDR-088 | Squad + Spec Orchestration | Outer loop (Squad) + Inner loop (Spec) modes | Agent Runner | Accepted | 2026-05-18 |

---

## Cross-Feature-Area Analysis Summary

**Generated**: 2026-05-18  
**Command**: `product init`  
**Feature-Areas Analyzed**: 6 (Spec Kit, Runner, Agent Runner, Team Directives, 12-Factors, Tikal Directives)  
**Patterns Discovered**: 20  
**Cross-Area Patterns**: 19  
**Inconsistencies Flagged**: 7

### Cross-Area Patterns (≥2 Feature-Areas)

| Pattern | Feature-Areas | PDR |
|---------|---------------|-----|
| Hybrid Workspace | Runner, Agent Runner | PDR-078 |
| Layered Git Strategy | Runner, Agent Runner | PDR-079 |
| Bimodal UX | Spec Kit, 12-Factors | PDR-080 |
| Unified Agent Abstraction | Spec Kit, Team Directives, Agent Runner | PDR-081 |
| Marker-Based DAG | Runner, Agent Runner, 12-Factors | PDR-082 |
| Milestone Verification | Agent Runner, Evals | PDR-083 |
| Spec-Driven Development | Spec Kit, 12-Factors, Agent Runner, Team Directives | PDR-084 |
| Dual Execution Loops | Runner, Agent Runner, 12-Factors, Evals | PDR-085 |
| Team Directives as Code | Team Directives, Tikal Directives, 12-Factors | PDR-086 |
| Eval-Driven Development | Tikal Directives, Spec Kit | PDR-087 |
| Squad + Spec Orchestration | Agent Runner | PDR-088 |

### Inconsistency Flags Summary

| Flag ID | Type | Severity | Feature-Areas | PDRs Affected |
|---------|------|----------|---------------|---------------|
| FLG-001 | Priority Conflict | ✅ RESOLVED | Spec Kit, Runner, Agent Runner, 12-Factors | PDR-082, PDR-085 |
| FLG-002 | Implementation Divergence | ✅ RESOLVED | Spec Kit, Runner, 12-Factors | PDR-079 |
| FLG-003 | Metric Inconsistency | 🟡 MEDIUM | Agent Runner, Team Directives, Tikal | PDR-083, PDR-087 |
| FLG-004 | Architecture Conflict | 🟡 MEDIUM | Spec Kit, Runner, 12-Factors | PDR-078 |
| FLG-005 | Persona Mismatch | 🟢 LOW | Team Directives, Tikal, Agent Runner | PDR-088 |
| FLG-006 | Duplicate Problems | 🟡 MEDIUM | Spec Kit, Team Directives, 12-Factors | PDR-084 |
| FLG-007 | Implementation Divergence | 🟡 MEDIUM | Agent Runner, Tikal | PDR-083, PDR-087 |

**Resolution Summary**:
1. ✅ FLG-001 and FLG-002 (HIGH severity) - **RESOLVED** via `/product.clarify`
2. 🔄 FLG-004 - Schedule architecture review for local/remote execution alignment
3. 🔄 FLG-003 - Create unified quality metrics taxonomy  
4. 🔄 FLG-006 - Document context management approach boundaries

**All PDRs (PDR-084 to PDR-088) updated to "Accepted" status and ready for PRD generation**

See `.specify/drafts/pdr-cross-feature-analysis.md` for detailed analysis.

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

### Alternatives Considered

| Alternative | Trade-offs | Why Not Chosen |
|-------------|------------|----------------|
| **Local-Only** | Simpler implementation, faster provisioning, works offline | Excludes resource-intensive tasks, forces machine upgrades, no security isolation for sensitive work, limits team scalability |
| **Remote-Only** | Uniform environment, infinite scaling, centralized security | Requires constant connectivity, latency for every operation, excludes offline development, higher baseline cost |
| **User-Selects-Permanently** | Reduced complexity, clear mental model | Locks users into suboptimal choice, doesn't adapt to task context, creates team fragmentation |
| **Context-Aware Auto (No Override)** | Fully automated, no user decision fatigue | Removes user agency, unpredictable behavior, difficult to troubleshoot when selection is wrong |

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

### Alternatives Considered

| Alternative | Trade-offs | Why Not Chosen |
|-------------|------------|----------------|
| **Clone-Only** | Simpler mental model, uniform workflow everywhere | Slow local iteration (30-60s per task), excessive disk usage for parallel tasks, poor developer experience for quick iterations |
| **Worktree-Only** | Fast everywhere, consistent git semantics | Doesn't work for remote isolation requirements, security concerns with shared working directories, complicates remote workspace provisioning |
| **Stash-Based** | Single working directory, minimal disk usage | Stash conflicts are hard to resolve, no parallel task support, stash stack complexity, easy to lose work |
| **Branch-Based** | Standard git workflow, well understood | Constant context switching overhead, no parallel work capability, working directory pollution, branch management complexity |

### ⚠️ Inconsistency Flags

**Flag FLG-002**: Implementation Divergence - **RESOLVED**
- **Severity**: HIGH
- **Issue**: PDR-079 defines unified hybrid git strategy, but Spec Kit only implements worktrees and Runner only implements clones
- **Resolution**: High priority implementation plan approved
  - Phase 1: Add clone support to Spec Kit (next milestone)
  - Phase 2: Add worktree support to Runner (following milestone)
  - Phase 3: Implement unified selection logic in both products
- **Status**: ✓ Resolved - Implementation scheduled

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

### Risks and Mitigation

| Risk | Likelihood | Impact | Mitigation Strategy |
|------|------------|--------|---------------------|
| **Feature Parity Drift** | High | High | Automated cross-interface testing suite; parity dashboard; feature gating until both interfaces ready |
| **Persona Conflict** | Medium | Medium | Shared governance model with both dev and non-dev representatives; persona councils for major UX decisions |
| **Spec Format Divergence** | Medium | High | Schema validation on both import and export; automated round-trip testing; format versioning |
| **Training Cost for Dual Skills** | Medium | Low | Progressive disclosure (UI → CLI graduation path); contextual help showing CLI equivalents; skill badges |
| **Interface Fragmentation** | Medium | High | Single shared component library; design system enforcement; unified user research |

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

---

## PDR-084: Spec-Driven Development

**Status**: Accepted

**Date**: 2026-05-18

**Owner**: Product Team

### Cross-Feature-Area Metadata
- **Appears in**: Spec Kit, 12-Factors, Agent Runner, Team Directives
- **Cross-area count**: 4
- **Is cross-area pattern**: ✓

### Context

spec.md as single source of truth. All features must have specs/ directory. Specification-first development where specifications are the primary artifact throughout the development lifecycle.

**Problem Statement**:
- Code has been king while specifications were discarded scaffolding
- No systematic way to verify AI-generated code meets requirements
- Context loss between requirements and implementation

### Decision

Formalize Spec-Driven Development as core methodology:

1. **Every feature starts with spec.md**
   - Mandated in spec template
   - Each story independently testable
   - P1/P2/P3 prioritization required

2. **100% spec coverage required**
   - Features with specs/ directory
   - spec.md drives plan.md
   - plan.md drives implementation

3. **spec → plan → implement → verify workflow**
   - `/spec.specify` - Create specification
   - `/spec.plan` - Generate implementation plan
   - `/spec.implement` - Execute implementation
   - Verification gates at each step

### Alternatives Considered

| Alternative | Trade-off | Why Not Chosen |
|-------------|-----------|----------------|
| **Code-First Development** | Fast initial iteration, no upfront overhead | Leads to rework, undocumented decisions, technical debt accumulation |
| **README-Only Documentation** | Simple, familiar format | Insufficient structure for verification, prone to staleness, not executable |
| **Test-Driven Development as Primary Specs** | Tests verify functionality | Tests describe "how" not "why"; misses requirements, architecture decisions, and user context |
| **Custom Presets** | Flexibility per project | Fragmentation across projects, loss of shared methodology, harder onboarding |

### Evidence

- Spec Kit: "Specification-first development workflow" (FR-SK-002)
- 12-Factors: Factor III - Mission Definition establishes spec.md as "unambiguous source of truth"
- Agent Runner: Squad Mode starts with PRD → Specify → Eval → Plan → Triage

### Consequences

**Positive**:
- Clear requirements with reduced ambiguity
- Verifiable outcomes against specifications
- Living documentation that evolves with code
- Audit trail from "why" to "how"

**Negative**:
- Upfront specification overhead
- Requires discipline to maintain spec-code parity
- Learning curve for specification format

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Spec coverage | 100% | Features with specs/ directory |
| Spec-to-code drift | <5% | Quarterly audit of spec-code alignment |
| Spec creation time | <30 min | Time from mission brief to approved spec |
| Team adoption | >80% | Developers using /spec.* commands |

### ⚠️ Inconsistency Flags

**Flag FLG-006**: Duplicate Problems
- **Severity**: Medium
- **Issue**: Context management problem solved differently across areas:
  - Team Directives: Three-layer hierarchy (Constitution → Persona → Skill)
  - 12-Factors: Three-tier context (Local @codebase, Team @team, External @web)
  - Spec Kit: Template-based context injection
- **Recommended Action**: Align context management approaches or document boundaries
- **Status**: Documented - Each approach serves different use cases; no unification required

### Related PDRs

- PDR-080: Bimodal UX Strategy (shared spec format)
- PDR-083: Milestone Verification (mission brief as goal)

---

## PDR-085: Dual Execution Loops

**Status**: Accepted

**Date**: 2026-05-18

**Owner**: Product Team

### Cross-Feature-Area Metadata
- **Appears in**: Runner, Agent Runner, 12-Factors, Evals Extension
- **Cross-area count**: 4
- **Is cross-area pattern**: ✓

### Context

AI-assisted development requires different execution modes for different types of work. Some tasks need human collaboration while others can run autonomously.

**Problem Statement**:
- All tasks treated the same regardless of complexity
- No systematic way to classify work for optimal execution
- Human time wasted on tasks agents could handle
- Agents making decisions that need human judgment

### Decision

Maintain dual execution model:

1. **[SYNC] - Synchronous Collaboration**
   - For: Complex, ambiguous, high-risk work
   - Pattern: Human-in-the-loop, interactive
   - Quality Gates: Micro-reviews (continuous)
   - Examples: Architecture decisions, security reviews, unclear requirements

2. **[ASYNC] - Asynchronous Delegation**
   - For: Well-defined, low-risk, mechanical tasks
   - Pattern: Autonomous execution, batch processing
   - Quality Gates: Macro-reviews (PR, CI)
   - Examples: Test generation, refactoring, documentation

3. **Classification at task level**
   - Not project-level, but task-level granularity
   - Triage decision tree with clear criteria
   - [P] marker for parallel execution

### Classification Strategy

**Spec Kit leads with auto-prediction** (Option A from FLG-001 resolution):
- Spec Kit auto-predicts [SYNC]/[ASYNC]/[P] markers (>85% accuracy)
- Manual override available for edge cases
- Runner and Agent Runner accept pre-classified markers
- Verification gates validate but don't override classification

### Evidence

- Runner: "Dual Execution Loop (SYNC/ASYNC)" (FR-RN-001)
- 12-Factors: Factor V - Dual Execution Loops
- Agent Runner: Squad Mode (outer loop) + Spec Mode (inner loop)

### Consequences

**Positive**:
- Optimal human-AI collaboration
- Safety for complex work
- Efficiency through delegation
- Clear responsibility boundaries
- Unified classification across ecosystem

**Negative**:
- Classification overhead
- Potential misclassification
- Training required for triage
- Dependency on Spec Kit's prediction accuracy

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Classification accuracy | >85% | Auto-predicted vs manual override rate |
| [SYNC] task defects | <5% | Post-hoc classification corrections |
| [ASYNC] task defects | <15% | Escalations requiring human intervention |
| Review efficiency | >70% | Time saved by ASYNC delegation vs SYNC review |

### ⚠️ Inconsistency Flags

**Flag FLG-001**: Priority Conflict - **RESOLVED**
- **Severity**: HIGH
- **Issue**: Different feature-areas prioritize classification differently
- **Resolution**: Spec Kit leads with auto-prediction; Runner and Agent Runner accept pre-classified markers; verification gates validate but don't override
- **Status**: ✓ Resolved - Classification strategy unified

### Related PDRs

- PDR-082: Marker-Based DAG Orchestration ([SYNC]/[ASYNC]/[P] markers)
- PDR-083: Milestone Verification (verification at [SYNC] gates)

---

## PDR-086: Team Directives as Code

**Status**: Accepted

**Date**: 2026-05-18

**Owner**: Product Team

### Cross-Feature-Area Metadata
- **Appears in**: Team Directives, Tikal Directives, 12-Factors, Spec Kit
- **Cross-area count**: 4
- **Is cross-area pattern**: ✓

### Context

AI behavior guidance scattered across prompts, wiki pages, and individual knowledge. No systematic way to version, share, or evolve AI guidance across teams.

**Problem Statement**:
- Critical knowledge siloed with individuals
- No shared standards for AI interaction
- Team's collective intelligence never improves
- Inconsistent AI output across team members

### Decision

Treat AI directives as code:

1. **Git version control**
   - All directives in Git repository
   - Semantic versioning (v1.0.0, v1.5.0-tikal1)
   - Branch-based development

2. **Fork-and-customize workflow**
   - Start with forkable foundation
   - Customize for organization needs
   - Merge upstream changes

3. **Structure**
   - `constitution.md` - Core principles (always loaded)
   - `personas/` - Role-specific guidance
   - `rules/` - Domain-specific patterns
   - `skills/` - Self-contained capabilities
   - `examples/` - Reference implementations

4. **CDR-based contribution tracking**
   - Context Decision Records for approved changes
   - Peer review by AI Development Guild
   - Signal gate criteria (team-wide, high value, unique, evidence)

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Directive freshness | <30 days | Average age of verified directives |
| Contribution acceptance rate | >60% | CDRs approved vs submitted |
| Team adoption | >70% | Projects using team-ai-directives |
| Version stability | 95% | Projects pinned to stable versions |

### Evidence

- Team Directives: "Forkable foundation for version-controlled AI agent behavior"
- 12-Factors: Factor XI - Directives as Code
- Tikal: 1.5.0-tikal1 versioning with upstream merge strategy

### Consequences

**Positive**:
- Reproducible AI outputs over time
- Team knowledge sharing
- Version stability for compliance
- Organizational learning

**Negative**:
- Maintenance overhead
- Sync complexity with upstream
- Learning curve for directive format

### ⚠️ Inconsistency Flags

*None* - Pattern is consistently implemented across all feature-areas

### Related PDRs

- PDR-080: Bimodal UX Strategy (shared source of truth)
- PDR-081: Unified Abstraction (directives support multi-agent)

---

## PDR-087: Eval-Driven Development

**Status**: Accepted

**Date**: 2026-05-18

**Owner**: Product Team

### Cross-Feature-Area Metadata
- **Appears in**: Tikal Directives, Spec Kit, Evals Extension
- **Cross-area count**: 3
- **Is cross-area pattern**: ✓

### Context

Traditional code review can't scale with AI-generated code volume. No systematic way to define "good" or catch regressions in AI behavior.

**Problem Statement**:
- Manual review doesn't scale
- No objective quality metrics
- Regressions in AI output go undetected
- "Good" is undefined and subjective

### Decision

Eval-Driven Development paradigm:

1. **Evals define acceptance criteria**
   - Structured evaluations become spec
   - Eval pass/fail as acceptance criteria
   - Quality gates in CI/CD

2. **PromptFoo for LLM-as-a-Judge**
   - Multiple evaluation suites (constitution, personas, rules, skills)
   - Python graders for security (PII, injection, hallucination)
   - Gold sets for calibration

3. **Three-layer evaluation**
   - Code Assertions (pytest) - deterministic
   - LLM-as-a-Judge (PromptFoo) - semantic
   - Human Review - final approval

4. **100-point skill scoring framework**
   - Frontmatter: 20 points
   - Content Organization: 30 points
   - Self-containment: 30 points
   - Documentation: 20 points

### Evidence

- Tikal: "100-point skill scoring framework"
- Evals Extension: "Quality assurance with PromptFoo integration"
- Spec Kit: Eval-gated execution (PDR-068, PDR-069)

### Consequences

**Positive**:
- Measurable quality
- Regression prevention
- Objective "good" definition
- Automated quality gates

**Negative**:
- Evaluation overhead
- Calibration complexity
- Grader maintenance

### Risks and Mitigation

**Risk Assessment**: Deferred to implementation phase (see Implementation Spec)

**Intentional Deferral Rationale**: Eval-Driven Development is a paradigm decision. Detailed risk analysis requires implementation context (evaluation volume, grader types, cost thresholds) that will be defined in the feature specification. Early mitigation strategies are documented below.

**Known Risk Areas with Initial Mitigations**:

| Risk | Likelihood | Initial Mitigation | Detailed Analysis In |
|------|------------|-------------------|---------------------|
| False positive/negative rates in LLM judges | Medium | Three-layer evaluation provides defense in depth; human review as final gate | Implementation spec grader design |
| Grader maintenance burden as patterns evolve | High | Version-controlled evals with automated regression detection; skill scoring framework provides structure | Team Directives contribution process |
| Calibration drift over time | Medium | Gold sets for calibration; periodic recalibration triggers; drift detection in CI | Evals Extension calibration spec |
| Cost escalation with high evaluation volume | Medium | Fast model (Haiku-3.5) for screening; full-power model only for final judgment; usage monitoring | Implementation spec cost model |
| Model selection trade-offs (speed vs accuracy) | Low | Documented selection criteria; benchmarking protocol; swap capability per PDR-081 | ADR-081 adapter documentation |

**Trigger for Detailed Analysis**: Implementation spec must include complete risk matrix before development begins.

### ⚠️ Inconsistency Flags

**Flag FLG-003**: Metric Inconsistency
- **Severity**: Medium
- **Issue**: Different quality metrics without mapping:
  - Agent Runner/PDR-083: Binary pass/fail
  - Tikal Directives: 100-point skill scoring
  - Team Directives: No formal scoring (peer review)
- **Recommended Action**: Create unified quality metrics taxonomy

**Flag FLG-007**: Implementation Divergence
- **Severity**: Medium
- **Issue**: Evaluation uses different models:
  - PDR-083: Fast model (Haiku-3.5 equivalent) for speed
  - Tikal: Full-power model for graders for accuracy
- **Recommended Action**: Document evaluation model selection criteria

### Related PDRs

- PDR-083: Milestone-Level Verification (eval-gated execution)
- PDR-085: Dual Execution Loops (quality gates differ by mode)

---

## PDR-088: Squad + Spec Orchestration

**Status**: Accepted

**Date**: 2026-05-18

**Owner**: Product Team

### Cross-Feature-Area Metadata
- **Appears in**: Agent Runner
- **Cross-area count**: 1
- **Is cross-area pattern**: ✗

### Context

Different types of work require different orchestration patterns. High-level planning needs different workflow than task execution.

**Problem Statement**:
- Single execution mode doesn't fit all work
- PRD-to-implementation gap
- Task execution without planning
- No separation between planning and doing

### Decision

Two-mode orchestration:

1. **Squad Mode (Outer Loop)**
   - Input: PRD (Product Requirements Document)
   - Workflow: PRD → Specify → Eval → Plan → Triage → tasks.md
   - Pattern: Human-in-the-loop at each gate
   - Target: AI Team Leads, Product Managers

2. **Spec Mode (Inner Loop)**
   - Input: Task from tasks.md
   - Workflow: Task → Spec → Implement → Verify
   - Pattern: Autonomous execution with verification
   - Target: Developers, Engineers

### Evidence

- Agent Runner PRD: "Squad Mode (Outer Loop)" and "Spec Mode (Inner Loop)"
- Agent Runner SPEC.md: Dual-mode architecture diagram

### Consequences

**Positive**:
- Appropriate mode for different work types
- Clear handoff between planning and execution
- Scalable from high-level to low-level

**Negative**:
- Mode context switching
- Training overhead for dual modes
- Potential mode confusion

### Success Metrics (Goal-Oriented)

**Squad Mode Goals**:
| Goal | Success Criteria | Target |
|------|------------------|--------|
| PRD Clarity | Requirements ambiguity resolved before planning | <3 NEEDS CLARIFICATION flags per PRD |
| Planning Accuracy | Tasks generated match implementation reality | >80% task completion without replanning |
| Stakeholder Alignment | All reviewers approve plan | 100% gate approvals |

**Spec Mode Goals**:
| Goal | Success Criteria | Target |
|------|------------------|--------|
| Implementation Quality | Tasks pass verification | >90% first-pass verification rate |
| Efficiency | Time from task to completion | <2 hours average for [ASYNC] tasks |
| Autonomy | Tasks completed without escalation | >85% autonomous completion |

**Cross-Mode Goals**:
| Goal | Success Criteria | Target |
|------|------------------|--------|
| Handoff Clarity | Context successfully transferred | <5% rework due to handoff issues |
| Mode Selection | Appropriate mode chosen | <10% mode switches post-assignment |

### ⚠️ Inconsistency Flags

**Flag FLG-005**: Persona Mismatch
- **Severity**: LOW
- **Issue**: AI Team Lead defined differently:
  - Agent Runner: "Senior engineer managing AI adoption, orchestrates Squad"
  - 12-Factors: "Developer elevated to orchestrator"
- **Recommended Action**: Align persona definitions or document context-specific variations

### Related PDRs

- PDR-080: Bimodal UX Strategy (dual interfaces)
- PDR-085: Dual Execution Loops (SYNC/ASYNC)

---

*This file is auto-generated from cross-feature-area analysis. Last updated: 2026-05-18*
