# Product Decision Records - Agentic SDLC Ecosystem

## Cross-Feature-Area Analysis Summary

**Generated**: 2026-05-18  
**Command**: `product init`  
**Feature-Areas Analyzed**: 6  
**Patterns Discovered**: 20  
**Cross-Area Patterns**: 19  
**Inconsistencies Flagged**: 7  

---

## PDR Index

| ID | Feature-Area | Category | Cross-Area | Status | Date | Strategic Score |
|----|--------------|----------|------------|--------|------|-----------------|
| PDR-001 to PDR-077 | Various | Various | Various | Previously Documented | Pre-2026 | - |
| PDR-078 | Runner | Technical | ✓ | Accepted | 2026-05-07 | 0.95 |
| PDR-079 | Runner | Technical | ✓ | Accepted | 2026-05-07 | 0.88 |
| PDR-080 | Spec Kit | UX/UI | ✓ | Accepted | 2026-05-07 | 0.92 |
| PDR-081 | Spec Kit | Technical | ✓ | Accepted | 2026-05-07 | 0.93 |
| PDR-082 | Runner | Technical | ✓ | Accepted | 2026-05-07 | 0.91 |
| PDR-083 | Agent Runner | Metrics | ✓ | Accepted | 2026-05-16 | 0.89 |
| PDR-084 | Ecosystem | Prioritization | ✓ | Discovered | 2026-05-18 | 0.96 |
| PDR-085 | Ecosystem | Technical | ✓ | Discovered | 2026-05-18 | 0.94 |
| PDR-086 | Ecosystem | Technical | ✓ | Discovered | 2026-05-18 | 0.90 |
| PDR-087 | Tikal Directives | Metrics | ✓ | Discovered | 2026-05-18 | 0.87 |
| PDR-088 | Ecosystem | Technical | ✓ | Discovered | 2026-05-18 | 0.86 |

---

## Cross-Feature-Area Patterns (≥2 Areas)

| Pattern | Feature-Areas | PDRs |
|---------|---------------|------|
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

---

## Inconsistency Flags Summary

| Flag ID | Type | Severity | Feature-Areas | Status |
|---------|------|----------|---------------|--------|
| FLG-001 | Priority Conflict | 🔴 HIGH | Spec Kit, Runner, Agent Runner, 12-Factors | Open |
| FLG-002 | Implementation Divergence | 🔴 HIGH | Spec Kit, Runner, 12-Factors | Open |
| FLG-003 | Metric Inconsistency | 🟡 MEDIUM | Agent Runner, Team Directives, Tikal | Open |
| FLG-004 | Architecture Conflict | 🟡 MEDIUM | Spec Kit, Runner, 12-Factors | Open |
| FLG-005 | Persona Mismatch | 🟢 LOW | Team Directives, Tikal, Agent Runner | Open |
| FLG-006 | Duplicate Problems | 🟡 MEDIUM | Spec Kit, Team Directives, 12-Factors | Open |
| FLG-007 | Implementation Divergence | 🟡 MEDIUM | Agent Runner, Tikal | Open |

---

## Existing PDRs (PDR-078 to PDR-083)

### PDR-078: Hybrid Workspace Provisioning Strategy
**Status**: Accepted  
**Cross-Feature-Area**: ✓ (Runner, Agent Runner)

**Cross-Feature-Area Metadata**:
- **Appears in**: Runner, Agent Runner, Agents Workspaces
- **Cross-area count**: 3
- **Is cross-area pattern**: ✓

**Decision**: Implement two workspace types with unified abstraction:
1. Local Workspaces (Docker dev containers) - <30s provisioning
2. Remote Workspaces (K8s pods) - <60s provisioning

**⚠️ Inconsistency Flags**:
**FLG-004**: Architecture Conflict
- **Severity**: Medium
- **Issue**: PDR-078 proposes hybrid selection, but Spec Kit is local-first while Runner is remote-first
- **Recommendation**: Implement PDR-078 unified selection in all products

---

### PDR-079: Layered Hybrid Git Strategy
**Status**: Accepted  
**Cross-Feature-Area**: ✓ (Runner, Agent Runner)

**Cross-Feature-Area Metadata**:
- **Appears in**: Runner, Agent Runner
- **Cross-area count**: 2
- **Is cross-area pattern**: ✓

**Decision**: Layered git strategy adapted to workspace type:
1. Local (Worktree Strategy) - Multiple working directories from single clone
2. Remote (Clone Strategy) - Fresh clone per remote workspace

**⚠️ Inconsistency Flags**:
**FLG-002**: Implementation Divergence
- **Severity**: HIGH
- **Issue**: PDR-079 defines unified hybrid strategy, but Spec Kit only implements worktrees and Runner only implements clones
- **Recommendation**: Implement both strategies in all products per PDR-079

---

### PDR-080: Bimodal UX Strategy
**Status**: Accepted  
**Cross-Feature-Area**: ✓ (Spec Kit, 12-Factors)

**Cross-Feature-Area Metadata**:
- **Appears in**: Spec Kit, 12-Factors
- **Cross-area count**: 2
- **Is cross-area pattern**: ✓

**Decision**: Dual-primary bimodal interface:
1. CLI (Developers) - <30s common tasks
2. Visual UI (Non-Developers) - >80% completion rate

**⚠️ Inconsistency Flags**:
*None* - Pattern is consistently implemented

---

### PDR-081: Unified Abstraction Agent Model
**Status**: Accepted  
**Cross-Feature-Area**: ✓ (Spec Kit, Team Directives, Agent Runner)

**Cross-Feature-Area Metadata**:
- **Appears in**: Spec Kit, Team Directives, Agent Runner
- **Cross-area count**: 3
- **Is cross-area pattern**: ✓

**Decision**: Single SDLC command abstraction with vendor-specific adapters:
- Commands: specify, plan, implement, validate
- Reference implementations: Claude (primary), GPT-4, Gemini
- <1 hour to switch agents, <2 days to add new agent

**⚠️ Inconsistency Flags**:
*None* - Pattern is consistently implemented

---

### PDR-082: Dependency-Driven Async Orchestration
**Status**: Accepted  
**Cross-Feature-Area**: ✓ (Runner, Agent Runner, 12-Factors)

**Cross-Feature-Area Metadata**:
- **Appears in**: Runner, Agent Runner, 12-Factors
- **Cross-area count**: 3
- **Is cross-area pattern**: ✓

**Decision**: Marker-based DAG orchestration:
- [P] - Parallel execution
- [ASYNC] - Autonomous (no human gate)
- [SYNC] - Human-gated (requires approval)
- Max 4 concurrent agents (context window limit)

**⚠️ Inconsistency Flags**:
**FLG-001**: Priority Conflict
- **Severity**: HIGH
- **Issue**: Spec Kit auto-predicts markers for ease-of-use, Runner requires explicit classification for K8s orchestration, Agent Runner adds verification gates that may override both
- **Recommendation**: Standardize marker classification across all products

---

### PDR-083: Milestone-Level Verification with /goal Pattern
**Status**: Accepted  
**Cross-Feature-Area**: ✓ (Agent Runner, Evals Extension)

**Cross-Feature-Area Metadata**:
- **Appears in**: Agent Runner, Evals Extension
- **Cross-area count**: 2
- **Is cross-area pattern**: ✓

**Decision**: Fast transcript-based evaluation using lightweight model:
- Binary pass/fail judgment
- 3-retry limit
- User override capability
- <2s verification latency

**⚠️ Inconsistency Flags**:
**FLG-003**: Metric Inconsistency
- **Severity**: MEDIUM
- **Issue**: Binary pass/fail (PDR-083) vs 100-point scoring (Tikal) vs no scoring (Team Directives)
- **Recommendation**: Create unified quality metrics taxonomy

**FLG-007**: Implementation Divergence
- **Severity**: MEDIUM
- **Issue**: PDR-083 uses fast model (Haiku-3.5) while Tikal uses full-power model for graders
- **Recommendation**: Document when to use fast vs full-power evaluation

---

## New PDRs Discovered

### PDR-084: Spec-Driven Development
**Status**: Discovered  
**Category**: Prioritization  
**Cross-Feature-Area**: ✓ (Spec Kit, 12-Factors, Agent Runner, Team Directives)

**Cross-Feature-Area Metadata**:
- **Appears in**: Spec Kit, 12-Factors, Agent Runner, Team Directives
- **Cross-area count**: 4
- **Is cross-area pattern**: ✓

**Context**:
spec.md as single source of truth. All features must have specs/ directory. spec → plan → implement → verify workflow. Specification-first development where specifications are the primary artifact.

**Decision**:
Formalize Spec-Driven Development as core methodology:
1. Every feature starts with spec.md
2. 100% spec coverage required
3. spec.md drives plan.md
4. plan.md drives implementation

**Evidence**:
- Spec Kit: "Specification-first development workflow" (FR-SK-002)
- 12-Factors: Factor III - Mission Definition
- Agent Runner: Squad Mode starts with PRD → Specify

**Consequences**:
- Positive: Clear requirements, reduced ambiguity, verifiable outcomes
- Negative: Upfront specification overhead

**⚠️ Inconsistency Flags**:
**FLG-006**: Duplicate Problems
- **Severity**: MEDIUM
- **Issue**: Context management problem solved differently: Team Directives uses constitution hierarchy, 12-Factors uses three-tier context
- **Recommendation**: Align context management approaches

---

### PDR-085: Dual Execution Loops
**Status**: Discovered  
**Category**: Technical  
**Cross-Feature-Area**: ✓ (Runner, Agent Runner, 12-Factors, Evals Extension)

**Cross-Feature-Area Metadata**:
- **Appears in**: Runner, Agent Runner, 12-Factors, Evals Extension
- **Cross-area count**: 4
- **Is cross-area pattern**: ✓

**Context**:
SYNC (human-in-the-loop, interactive) vs ASYNC (autonomous, batch). SYNC for uncertain work, ASYNC for well-defined tasks.

**Decision**:
Maintain dual execution model:
1. [SYNC] - Human collaboration for complex, ambiguous work
2. [ASYNC] - Autonomous delegation for well-defined tasks
3. Classification at task level, not project level

**Evidence**:
- Runner: "Dual Execution Loop (SYNC/ASYNC)" (FR-RN-001)
- 12-Factors: Factor V - Dual Execution Loops
- Agent Runner: Squad Mode (outer) + Spec Mode (inner)

**Consequences**:
- Positive: Optimal human-AI collaboration, safety for complex work
- Negative: Classification overhead, potential misclassification

**⚠️ Inconsistency Flags**:
**FLG-001**: Priority Conflict (see PDR-082)

---

### PDR-086: Team Directives as Code
**Status**: Discovered  
**Category**: Technical  
**Cross-Feature-Area**: ✓ (Team Directives, Tikal Directives, 12-Factors, Spec Kit)

**Cross-Feature-Area Metadata**:
- **Appears in**: Team Directives, Tikal Directives, 12-Factors, Spec Kit
- **Cross-area count**: 4
- **Is cross-area pattern**: ✓

**Context**:
Version-controlled AI behavior in constitution.md, personas/, rules/, skills/. Git-tracked with fork-sync automation.

**Decision**:
Treat AI directives as code:
1. Git version control
2. Semantic versioning
3. Fork-and-customize workflow
4. CDR-based contribution tracking

**Evidence**:
- Team Directives: "Forkable foundation for version-controlled AI agent behavior"
- 12-Factors: Factor XI - Directives as Code
- Tikal: 1.5.0-tikal1 versioning

**Consequences**:
- Positive: Reproducibility, team knowledge sharing, version stability
- Negative: Maintenance overhead, sync complexity

**⚠️ Inconsistency Flags**:
*None* - Pattern is consistently implemented

---

### PDR-087: Eval-Driven Development
**Status**: Discovered  
**Category**: Metrics  
**Cross-Feature-Area**: ✓ (Tikal Directives, Spec Kit, Evals Extension)

**Cross-Feature-Area Metadata**:
- **Appears in**: Tikal Directives, Spec Kit, Evals Extension
- **Cross-area count**: 3
- **Is cross-area pattern**: ✓

**Context**:
Define "good" through structured evals that become spec + acceptance criteria. PromptFoo integration with gold sets and graders.

**Decision**:
Eval-Driven Development paradigm:
1. Evals define acceptance criteria
2. PromptFoo for LLM-as-a-Judge
3. Gold sets for calibration
4. Security graders as quality gates

**Evidence**:
- Tikal: "100-point skill scoring framework"
- Evals Extension: "Quality assurance with PromptFoo integration"
- Spec Kit: Eval-gated execution (PDR-068, PDR-069)

**Consequences**:
- Positive: Measurable quality, regression prevention
- Negative: Evaluation overhead, calibration complexity

**⚠️ Inconsistency Flags**:
**FLG-003**: Metric Inconsistency (see PDR-083)

**FLG-007**: Implementation Divergence (see PDR-083)

---

### PDR-088: Squad + Spec Orchestration
**Status**: Discovered  
**Category**: Personas  
**Cross-Feature-Area**: ✗ (Agent Runner only)

**Cross-Feature-Area Metadata**:
- **Appears in**: Agent Runner
- **Cross-area count**: 1
- **Is cross-area pattern**: ✗

**Context**:
Squad Mode (Outer Loop): PRD → Specify → Eval → Plan → Triage. Spec Mode (Inner Loop): Task → Spec → Impl → Verify.

**Decision**:
Two-mode orchestration:
1. Squad Mode: PRD conversation interface, human-in-the-loop
2. Spec Mode: Task execution with Autoresearch pattern

**Evidence**:
- Agent Runner PRD: "Squad Mode (Outer Loop)" and "Spec Mode (Inner Loop)"
- Agent Runner SPEC.md: Dual-mode architecture diagram

**Consequences**:
- Positive: Appropriate mode for different work types
- Negative: Mode context switching, training overhead

**⚠️ Inconsistency Flags**:
**FLG-005**: Persona Mismatch
- **Severity**: LOW
- **Issue**: AI Team Lead defined differently in Agent Runner (Squad orchestrator) vs 12-Factors (Developer as Orchestrator)
- **Recommendation**: Align persona definitions or document differences

---

## Appendix A: Inconsistency Flags Detail

### FLG-001: Priority Conflict - SYNC/ASYNC Classification
**Severity**: 🔴 HIGH

**Description**: Different feature-areas prioritize SYNC/ASYNC classification differently:
- Spec Kit: Auto-predicts markers for ease-of-use
- Runner: Requires explicit classification for K8s orchestration
- Agent Runner: Adds verification gates that may override
- 12-Factors: Theoretical framework without enforcement

**Feature-Areas Affected**: Spec Kit, Runner, Agent Runner, 12-Factors

**Evidence**:
- Spec Kit: "Marker prediction accuracy >85%" - automation priority
- Runner: "Manual classification required" - precision priority
- Agent Runner: "Verification at [SYNC] gates" - safety priority

**Recommended Action**:
Run `/product.clarify` to align on:
1. When to use auto-prediction vs manual classification
2. How verification gates interact with classification
3. Standardized classification taxonomy

---

### FLG-002: Implementation Divergence - Git Strategy
**Severity**: 🔴 HIGH

**Description**: PDR-079 defines unified hybrid git strategy (worktrees local + clones remote), but implementation is fragmented:
- Spec Kit: Only implements worktrees
- Runner: Only implements clones
- No unified approach exists

**Feature-Areas Affected**: Spec Kit, Runner, 12-Factors

**Evidence**:
- PDR-079: "Worktrees (local) + Clones (remote) with unified abstraction"
- Spec Kit: Worktree-based workflow, no clone strategy
- Runner: Clone-based workflow, no worktree strategy

**Recommended Action**:
Implement PDR-079 in both products:
1. Add clone strategy to Spec Kit
2. Add worktree strategy to Runner
3. Implement unified selection logic

---

### FLG-003: Metric Inconsistency - Quality Definitions
**Severity**: 🟡 MEDIUM

**Description**: Different quality metrics without mapping:
- Agent Runner/PDR-083: Binary pass/fail
- Tikal Directives: 100-point skill scoring
- Team Directives: No formal scoring

**Feature-Areas Affected**: Agent Runner, Team Directives, Tikal

**Evidence**:
- PDR-083: "Binary pass/fail based on goal achievement"
- Tikal: "100-point scoring framework: Frontmatter 20, Content 30, Self-containment 30, Documentation 20"
- Team Directives: "Peer review by AI Development Guild" - qualitative

**Recommended Action**:
Create unified quality taxonomy:
1. Map binary pass/fail to 100-point scale
2. Define which metrics apply to which artifacts
3. Document when to use each scoring approach

---

### FLG-004: Architecture Conflict - Local vs Remote Preference
**Severity**: 🟡 MEDIUM

**Description**: PDR-078 proposes hybrid workspace selection, but products have different defaults:
- Spec Kit: Local-first (worktrees)
- Runner: Remote-first (K8s pods)
- No unified selection logic

**Feature-Areas Affected**: Spec Kit, Runner, 12-Factors

**Evidence**:
- PDR-078: "Auto-select based on task context"
- Spec Kit: No remote workspace integration
- Runner: No local workspace support

**Recommended Action**:
1. Implement PDR-078 selection criteria in both products
2. Add configuration for default workspace type
3. Create unified workspace abstraction

---

### FLG-005: Persona Mismatch - AI Team Lead Definition
**Severity**: 🟢 LOW

**Description**: AI Team Lead persona defined differently across products:
- Agent Runner: "Senior engineer managing AI adoption, orchestrates Squad"
- 12-Factors: "Developer elevated to orchestrator"
- Tikal: Not explicitly defined

**Feature-Areas Affected**: Team Directives, Tikal, Agent Runner

**Evidence**:
- Agent Runner PDR-080: Persona A quote
- 12-Factors: "Developer as Orchestrator" - Strategic Mindset

**Recommended Action**:
Align persona definitions or document context-specific variations.

---

### FLG-006: Duplicate Problems - Context Management
**Severity**: 🟡 MEDIUM

**Description**: Context management problem solved differently:
- Team Directives: Three-layer hierarchy (Constitution → Persona → Skill)
- 12-Factors: Three-tier context (Local @codebase, Team @team, External @web)
- Spec Kit: Template-based context injection

**Feature-Areas Affected**: Spec Kit, Team Directives, 12-Factors

**Evidence**:
- Team Directives: "Loading Order: 1. Constitution 2. Persona 3. Skill"
- 12-Factors: Factor II - Context Scaffolding
- Spec Kit: Template resolution hierarchy

**Recommended Action**:
1. Map the three models to each other
2. Document when to use each approach
3. Consider unifying or clarifying boundaries

---

### FLG-007: Implementation Divergence - Evaluation Models
**Severity**: 🟡 MEDIUM

**Description**: Evaluation uses different models:
- PDR-083: Fast model (Haiku-3.5 equivalent)
- Tikal: Full-power model for graders
- No guidance on when to use which

**Feature-Areas Affected**: Agent Runner, Tikal

**Evidence**:
- PDR-083: "Fast model (Haiku-3.5 equivalent) reads conversation transcript"
- Tikal: "LLM-as-a-Judge with full model evaluation"

**Recommended Action**:
Document evaluation model selection criteria based on:
1. Cost constraints
2. Latency requirements
3. Accuracy needs

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **PDR** | Product Decision Record |
| **FLG** | Inconsistency Flag |
| **SYNC** | Synchronous, human-in-the-loop execution |
| **ASYNC** | Asynchronous, autonomous execution |
| **[P]** | Parallel execution marker |
| **Spec Kit** | Methodology toolkit for Spec-Driven Development |
| **Runner** | K8s-based async agent execution |
| **Agent Runner** | Unified Squad + Spec orchestration |
| **12-Factors** | Twelve-Factor Agentic SDLC methodology |
| **Tikal Directives** | Tikal-specific AI directives with evals |

---

*This file is auto-generated from cross-feature-area analysis.*  
*Last updated: 2026-05-18*
