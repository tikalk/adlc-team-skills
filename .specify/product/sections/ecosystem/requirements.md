## 7. Functional Requirements

### 7.1 Hybrid Workspace Provisioning (PDR-078)

**REQ-001**: Local Workspace Support
- **Description**: Support Docker dev containers for local development
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Provisioning completes in <30 seconds (95th percentile)
  - Supports offline work capability
  - Integrates with existing dev setup (not replacement)
- **Source**: PDR-078

**REQ-002**: Remote Workspace Support  
- **Description**: Support Kubernetes pods for cloud execution
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Provisioning completes in <60 seconds (95th percentile)
  - Provides security isolation for sensitive work
  - Handles resource-intensive tasks
- **Source**: PDR-078

**REQ-003**: Unified Workspace Abstraction
- **Description**: Common interface for both workspace types
- **Priority**: Must Have
- **Acceptance Criteria**:
  - >90% feature parity between local and remote
  - Auto-selection based on task context
  - Manual override with user acknowledgment
- **Source**: PDR-078

**REQ-004**: Progressive Adoption Path
- **Description**: Allow users to start local and graduate to remote
- **Priority**: Should Have
- **Acceptance Criteria**:
  - Clear migration path documented
  - State preservation during transition
  - Gradual feature exposure
- **Source**: PDR-078

### 7.2 Layered Hybrid Git Strategy (PDR-079)

**REQ-005**: Local Worktree Strategy
- **Description**: Use git worktrees for local parallel task execution
- **Priority**: Must Have
- **Acceptance Criteria**:
  - <1 second file change visibility
  - Multiple working directories from single clone
  - Automatic conflict detection
  - <5 second task startup
- **Source**: PDR-079

**REQ-006**: Remote Clone Strategy
- **Description**: Use optimized clones for remote isolation
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Fresh clone per remote workspace
  - Shallow clones where appropriate
  - <30 second commit/push/pull cycle
  - <15 second task startup (including clone)
- **Source**: PDR-079

**REQ-007**: State Handoff Mechanism
- **Description**: Clear semantics for local ↔ remote state transfer
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Local → Remote: Commit and push
  - Remote → Local: Pull and merge
  - Clear UX indicators of sync status
  - <30 second state handoff cycle
- **Source**: PDR-079

### 7.3 Bimodal UX Strategy (PDR-080)

**REQ-008**: CLI Interface
- **Description**: Command-line interface optimized for developers
- **Priority**: Must Have
- **Acceptance Criteria**:
  - <30s completion for common tasks
  - Command completion and scripting support
  - Direct spec file editing capability
  - Shows UI equivalents for learning
- **Source**: PDR-080

**REQ-009**: Visual UI Interface
- **Description**: Web-based interface for non-developers
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Guided workflows for spec creation
  - Real-time progress dashboards
  - >80% task completion rate target
  - "Open in CLI" links for skill building
- **Source**: PDR-080

**REQ-010**: Shared Spec Format
- **Description**: Single YAML/Markdown format for both interfaces
- **Priority**: Must Have
- **Acceptance Criteria**:
  - 100% round-trip fidelity
  - Schema validation on import/export
  - Progressive disclosure (UI → CLI graduation)
  - No data loss between interfaces
- **Source**: PDR-080

### 7.4 Unified Agent Abstraction (PDR-081)

**REQ-011**: SDLC Command Interface
- **Description**: Unified commands: specify, plan, implement, validate
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Same commands work across all agents
  - Vendor-specific adapters implement interface
  - Versioned API for stability
- **Source**: PDR-081

**REQ-012**: Multi-Agent Support
- **Description**: Support 20+ AI agents through adapters
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Claude, GPT-4, Gemini reference implementations
  - <1 hour to swap workspace between agents
  - 100% core feature parity across agents
  - <2 days to add new agent support
- **Source**: PDR-081

**REQ-013**: Security & Audit
- **Description**: All agent actions through SDLC command layer
- **Priority**: Must Have
- **Acceptance Criteria**:
  - No unauthorized tool access
  - Complete audit logging
  - Schema-level tool restrictions
- **Source**: PDR-081

### 7.5 Marker-Based DAG Orchestration (PDR-082)

**REQ-014**: Execution Markers
- **Description**: Support [P], [ASYNC], [SYNC] markers in specs
- **Priority**: Must Have
- **Acceptance Criteria**:
  - [P] = Parallel (can execute concurrently)
  - [ASYNC] = Autonomous (no human gate)
  - [SYNC] = Human-gated (requires approval)
  - Parseable from Markdown specs
- **Source**: PDR-082

**REQ-015**: DAG Builder
- **Description**: Build and execute dependency graph from markers
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Parse markers in <2 seconds
  - Build dependency graph automatically
  - Execute according to graph topology
  - Enforce sequential dependencies
- **Source**: PDR-082

**REQ-016**: Execution Constraints
- **Description**: Safety limits for parallel execution
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Max 4 concurrent agents (context window limit)
  - Automatic retry with sequential fallback on conflict
  - <5% conflict resolution rate target
  - >70% parallel utilization
- **Source**: PDR-082

### 7.6 Milestone-Level Verification (PDR-083)

**REQ-017**: /goal-Style Verification
- **Description**: Fast transcript-based evaluation at milestone completion
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Mission brief serves as implicit goal
  - Fast model (Haiku-3.5 equivalent) reads transcript
  - Binary pass/fail judgment
  - <2s verification latency (p95)
- **Source**: PDR-083

**REQ-018**: Bounded Retries
- **Description**: Auto-retry with limit for failed verifications
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Auto-retry up to 3 iterations
  - User can override mid-run (Ctrl+C)
  - <15% user override rate
  - <5% false positive rate
  - <10% false negative rate
- **Source**: PDR-083

**REQ-019**: Verification Integration Points
- **Description**: Run at key workflow points
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Verify at milestone completion
  - Mandatory verification before [SYNC] gates
  - Block until passed at sync points
  - Structured output format
- **Source**: PDR-083

### 7.7 Spec-Driven Development (PDR-084)

**REQ-020**: Spec-First Development
- **Description**: Every feature starts with spec.md
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Mandated in spec template
  - Each story independently testable
  - P1/P2/P3 prioritization required
  - 100% spec coverage of features
- **Source**: PDR-084

**REQ-021**: Spec-Driven Workflow
- **Description**: spec → plan → implement → verify workflow
- **Priority**: Must Have
- **Acceptance Criteria**:
  - /spec.specify - Create specification
  - /spec.plan - Generate implementation plan
  - /spec.implement - Execute implementation
  - Verification gates at each step
  - <30 min spec creation time
- **Source**: PDR-084

**REQ-022**: Living Documentation
- **Description**: Specs evolve with code as source of truth
- **Priority**: Should Have
- **Acceptance Criteria**:
  - <5% spec-to-code drift (quarterly audit)
  - Audit trail from "why" to "how"
  - >80% team adoption of /spec.* commands
- **Source**: PDR-084

### 7.8 Dual Execution Loops (PDR-085)

**REQ-023**: SYNC Mode
- **Description**: Human-in-the-loop for complex/ambiguous work
- **Priority**: Must Have
- **Acceptance Criteria**:
  - For: Complex, ambiguous, high-risk work
  - Pattern: Interactive, continuous micro-reviews
  - Examples: Architecture, security, unclear requirements
  - <5% defect rate post-classification
- **Source**: PDR-085

**REQ-024**: ASYNC Mode
- **Description**: Autonomous execution for well-defined tasks
- **Priority**: Must Have
- **Acceptance Criteria**:
  - For: Well-defined, low-risk, mechanical tasks
  - Pattern: Batch processing, macro-reviews (PR/CI)
  - Examples: Test generation, refactoring, docs
  - <15% escalation rate
  - >70% review efficiency gain
- **Source**: PDR-085

**REQ-025**: Task-Level Classification
- **Description**: Classify at task granularity, not project level
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Triage decision tree with clear criteria
  - [P] marker for parallel execution
  - >85% auto-prediction accuracy
  - Manual override available
- **Source**: PDR-085

### 7.9 Team Directives as Code (PDR-086)

**REQ-026**: Git Version Control
- **Description**: All AI directives in Git repository
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Semantic versioning (v1.0.0, v1.5.0-tikal1)
  - Branch-based development workflow
  - Fork-and-customize capability
  - Merge upstream changes support
- **Source**: PDR-086

**REQ-027**: Directive Structure
- **Description**: Organized hierarchy of AI behavior guidance
- **Priority**: Must Have
- **Acceptance Criteria**:
  - constitution.md - Core principles (always loaded)
  - personas/ - Role-specific guidance
  - rules/ - Domain-specific patterns
  - skills/ - Self-contained capabilities
  - examples/ - Reference implementations
- **Source**: PDR-086

**REQ-028**: CDR-Based Contributions
- **Description**: Structured process for directive changes
- **Priority**: Should Have
- **Acceptance Criteria**:
  - Context Decision Records for approved changes
  - Peer review by AI Development Guild
  - Signal gate criteria (team-wide, high value, unique, evidence)
  - >60% contribution acceptance rate
- **Source**: PDR-086

### 7.10 Eval-Driven Development (PDR-087)

**REQ-029**: Eval-Gated Acceptance
- **Description**: Evals define acceptance criteria
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Structured evaluations become spec
  - Eval pass/fail as acceptance criteria
  - Quality gates in CI/CD
  - 100-point skill scoring framework
- **Source**: PDR-087

**REQ-030**: Three-Layer Evaluation
- **Description**: Defense-in-depth quality assessment
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Code Assertions (pytest) - deterministic
  - LLM-as-a-Judge (PromptFoo) - semantic
  - Human Review - final approval
  - Multiple evaluation suites (constitution, personas, rules, skills)
- **Source**: PDR-087

**REQ-031**: Skill Scoring Framework
- **Description**: Objective quality measurement
- **Priority**: Should Have
- **Acceptance Criteria**:
  - Frontmatter: 20 points
  - Content Organization: 30 points
  - Self-containment: 30 points
  - Documentation: 20 points
  - 85-95 average target score
- **Source**: PDR-087

### 7.11 Squad + Spec Orchestration (PDR-088)

**REQ-032**: Squad Mode (Outer Loop)
- **Description**: High-level planning workflow
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Input: PRD (Product Requirements Document)
  - Workflow: PRD → Specify → Eval → Plan → Triage → tasks.md
  - Pattern: Human-in-the-loop at each gate
  - Target: AI Team Leads, Product Managers
  - <3 NEEDS CLARIFICATION flags per PRD
  - >80% planning accuracy
  - 100% gate approvals
- **Source**: PDR-088

**REQ-033**: Spec Mode (Inner Loop)
- **Description**: Task execution workflow
- **Priority**: Must Have
- **Acceptance Criteria**:
  - Input: Task from tasks.md
  - Workflow: Task → Spec → Implement → Verify
  - Pattern: Autonomous execution with verification
  - Target: Developers, Engineers
  - >90% first-pass verification rate
  - <2 hours average for [ASYNC] tasks
  - >85% autonomous completion
- **Source**: PDR-088

**REQ-034**: Mode Handoff
- **Description**: Clear context transfer between modes
- **Priority**: Should Have
- **Acceptance Criteria**:
  - <5% rework due to handoff issues
  - <10% mode switches post-assignment
  - Context preservation across handoff
  - Clear handoff documentation
- **Source**: PDR-088

---

**Source PDRs**: PDR-078, PDR-079, PDR-080, PDR-081, PDR-082, PDR-083, PDR-084, PDR-085, PDR-086, PDR-087, PDR-088
