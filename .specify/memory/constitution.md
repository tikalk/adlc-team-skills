# Agentic SDLC Constitution

## Core Principles

### I. Spec-Driven Development
Every feature starts with a spec.md file that serves as the single source of truth throughout the development lifecycle. Specifications are living documents that evolve with the code, providing an audit trail from "why" to "how". Code is derived from specs, not the other way around.

### II. Human-in-the-Loop
AI autonomy is bounded by intentional human gates. `[SYNC]` markers indicate mandatory human review points, while `[ASYNC]` enables autonomous execution. Users retain override capability at all times - no agent runs without an off-switch. Human judgment remains the final arbiter for complex, ambiguous, or high-risk decisions.

### III. Context as Budget
Context window is a finite resource to be managed deliberately. Parallel execution is limited (max 4 concurrent agents) to preserve context quality. Fast, lightweight models are preferred for verification tasks to minimize context consumption. Every context injection must justify its value against the budget.

### IV. Multi-Agent Agnosticism
The platform must work with any capable AI agent (Claude, GPT-4, Gemini, etc.) through a unified abstraction layer. Vendor lock-in is unacceptable. Teams can select best-fit models per task, swap agents in under 1 hour, and add new agent support in under 2 days.

### V. Safety Through Constraints
Safety is achieved through systematic constraints, not unlimited freedom. Workspace isolation (local vs remote) provides security boundaries. Retry limits (3 attempts) prevent infinite loops. Schema validation enforces structural correctness. Constraints make the system predictable and trustworthy.

### VI. Bimodal by Design
The platform serves both developers (CLI) and non-developers (Visual UI) as equal first-class citizens. No persona is secondary. Both interfaces share a single spec format with 100% round-trip fidelity. Progressive disclosure enables users to graduate from UI to CLI as skills develop.

### VII. Eval-Driven Quality
"Good" is defined through structured evaluations, not subjective judgment. Evals serve as acceptance criteria and quality gates. Three-layer evaluation (code assertions, LLM-as-judge, human review) provides defense in depth. Quality is measurable, regressions are preventable, and standards are objective.

### VIII. Team Directives as Code
AI behavior guidance is version-controlled, peer-reviewed code - not scattered prompts or individual knowledge. Directives follow semantic versioning, support fork-and-customize workflows, and improve through structured contribution processes. Organizational AI knowledge accumulates and evolves.

## Execution Philosophy

### Dual Execution Loops
Work is classified at the task level as either:
- **[SYNC]**: Complex, ambiguous, high-risk - human-in-the-loop, interactive
- **[ASYNC]**: Well-defined, low-risk, mechanical - autonomous execution

Classification happens at task granularity, not project level. Spec Kit leads with auto-prediction (>85% accuracy), with manual override available.

### Dependency-Driven Orchestration
Task dependencies are explicit via `[P]` (parallel), `[ASYNC]`, and `[SYNC]` markers. The system builds and executes a DAG automatically. Parallel utilization target >70%, with automatic retry and sequential fallback on conflict.

### Hybrid Workspace Strategy
Developers choose workspace type based on context:
- **Local**: Docker dev containers, worktree git, <30s provisioning
- **Remote**: Kubernetes pods, clone-based git, <60s provisioning

Auto-selection based on task context, with manual override and >90% feature parity.

## Governance

### Constitution Supersedes All Practices
These principles take precedence over individual PDRs, feature specifications, and implementation details. Any deviation requires explicit justification and documentation.

### Amendment Process
1. Propose amendment via standard PDR process
2. Demonstrate alignment with existing principles or justify principled departure
3. Document migration plan for affected PDRs
4. Obtain review from product governance
5. Update constitution version and ratification date

### Compliance Verification
All PRs, specs, and product decisions must verify compliance with constitutional principles. Complexity must be justified against these principles. When in doubt, prefer simplicity and explicit constraints.

---

**Version**: 1.0.0 | **Ratified**: 2026-05-19 | **Last Amended**: 2026-05-19

**Derived From**: PDR-078 through PDR-088 cross-feature-area analysis
