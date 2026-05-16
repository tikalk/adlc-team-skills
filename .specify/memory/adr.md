# Architecture Decision Records

## ADR Index

### Greenfield ADRs (Target Architecture)

| ID | Sub-System | Decision | Status | Date | Confidence |
|----|------------|----------|--------|------|------------|
| ADR-004 | System | Multi-Agent Abstraction Layer | Accepted | 2026-04-25 | HIGH |
| ADR-005 | System | Extension-Based Architecture | Accepted | 2026-04-25 | HIGH |
| ADR-006 | Runner | K8s Subagent Pattern | Accepted | 2026-04-25 | HIGH |
| ADR-007 | Workspaces | Docker-Based OpenCode Server | Accepted | 2026-04-25 | HIGH |
| ADR-008 | System | Context Engineering | Accepted | 2026-04-25 | HIGH |
| ADR-009 | System | Safety Through Schema-Level Constraints | Accepted | 2026-04-25 | HIGH |
| ADR-010 | System | Three-Level Work Decomposition | Accepted | 2026-04-25 | HIGH |
| ADR-011 | Directives | Team AI Directives | Accepted | 2026-04-25 | HIGH |
| ADR-012 | Workspaces | Per-Workspace Pod Deployment | Accepted | 2026-04-25 | HIGH |
| ADR-013 | Workspaces | Git-Based Workspace Lifecycle | Accepted | 2026-04-25 | HIGH |
| ADR-014 | Workspaces | Dev Container Spec Tool Provisioning | Accepted | 2026-04-25 | HIGH |
| ADR-015 | Workspaces | Hybrid Client Extension | Accepted | 2026-04-25 | HIGH |
| ADR-016 | Workspaces | Hybrid Workspace Provisioning | Accepted | 2026-05-07 | HIGH |
| ADR-017 | Git Integration | Layered Git Strategy | Accepted | 2026-05-07 | HIGH |
| ADR-018 | User Interface | Bimodal Interface | Accepted | 2026-05-07 | HIGH |
| ADR-019 | Agent Runtime | Marker-Based DAG Orchestration | Proposed | 2026-05-07 | MEDIUM |
| ADR-020 | User Experience | Desktop Application Architecture | Accepted | 2026-05-07 | HIGH |

### Brownfield ADRs (Actual Implementation)

| ID | Sub-System | Decision | Status | Date | Confidence |
|----|------------|----------|--------|------|------------|
| ADR-101 | System | pnpm Workspace Monorepo | Accepted | 2026-05-07 | HIGH |
| ADR-102 | System | TypeScript-First Development | Accepted | 2026-05-07 | HIGH |
| ADR-103 | System | Modular App/Package Separation | Accepted | 2026-05-07 | HIGH |
| ADR-104 | Desktop | Electron with Embedded Daemon | Accepted | 2026-05-07 | HIGH |
| ADR-105 | Communication | JSON-RPC over Unix Socket | Accepted | 2026-05-07 | HIGH |
| ADR-106 | Storage | SQLite for Local Data | Accepted | 2026-05-07 | HIGH |
| ADR-107 | Web | React 19 with Radix UI | Accepted | 2026-05-07 | HIGH |
| ADR-108 | Integration | Model Context Protocol (MCP) | Accepted | 2026-05-07 | HIGH |
| ADR-109 | Build | Vite + tsup Build Pipeline | Accepted | 2026-05-07 | HIGH |
| ADR-110 | Testing | Vitest Unit Testing | Accepted | 2026-05-07 | HIGH |

---

## System-Level ADRs

### ADR-004: Multi-Agent Abstraction Layer

**Status**: Accepted

**Date**: 2026-04-25

**Context**

AI agents from different vendors (Claude, GPT-4, Gemini) have proprietary interfaces. Hardcoding to one agent creates vendor lock-in and prevents teams from using best-fit models per task.

**Decision**

Implement a unified SDLC command abstraction layer with adapter pattern. All agents implement the same command interface (specify, plan, implement, etc.) with vendor-specific adapters handling translation.

**Consequences**

**Positive**:
- Swap agents without workflow changes
- Use best-fit model per task
- Unified tooling across all agents

**Negative**:
- Adapter maintenance overhead
- Feature parity requires updates to all adapters

**Confidence Level**: HIGH — Adapter pattern is proven, interface can be versioned

---

### ADR-005: Extension-Based Architecture

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Agent capabilities vary. Teams need to customize integrations without modifying core platform code. Extension points must support both built-in and third-party integrations.

**Decision**

Extension system with `speckit.json` manifest. Extensions provide commands, templates, and hooks. Dynamic loading at runtime with standardized integration interface.

**Consequences**

**Positive**:
- Customizable without core changes
- Third-party ecosystem possible
- Teams share extensions via git

**Negative**:
- Extension API must be stable
- Version compatibility management

**Confidence Level**: HIGH — Extension pattern proven in many platforms

---

### ADR-006: K8s Subagent Pattern

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Remote agent execution requires isolation from host machines. Containers provide isolation but need orchestration for multi-agent workloads.

**Decision**

Kubernetes subagent pattern: Each remote workspace is a pod. Agent runtime schedules tasks as pods with resource constraints. Per-workspace isolation guarantees security.

**Consequences**

**Positive**:
- Strong isolation guarantees
- Resource quotas enforceable
- Auto-scaling possible

**Negative**:
- Infrastructure complexity
- 60s cold start vs 30s local

**Confidence Level**: HIGH — K8s standard for container orchestration

---

### ADR-007: Docker-Based OpenCode Server

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Local development needs fast iteration with familiar tooling. Remote patterns (clones) are too slow for local workflows.

**Decision**

Docker dev containers for local workspaces. Mount host filesystem for shared access. Worktree-based git for immediate state visibility. Complete in <30s.

**Consequences**

**Positive**:
- Fast startup (<30s)
- Familiar Docker tooling
- Immediate file visibility

**Negative**:
- Weaker isolation than K8s
- Docker Desktop dependency

**Confidence Level**: HIGH — Dev containers industry standard

---

### ADR-008: Context Engineering

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Agent context windows are limited (32K-200K tokens). Large specs exceed limits. Context must be intelligently managed.

**Decision**

Graduated context compaction: Full spec → Key sections → Summary → Pointer. Context as budget with smart truncation. Priority-based content inclusion.

**Consequences**

**Positive**:
- Fits within token limits
- Maintains critical context
- Performance optimization

**Negative**:
- Complexity in deciding what to keep
- Potential information loss

**Confidence Level**: HIGH — Necessary constraint of current LLM limits

---

### ADR-009: Safety Through Schema-Level Constraints

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Agent autonomy requires safety guardrails. Five-layer defense: schema, policy, sandbox, network, audit.

**Decision**

Safety schema validation at task structure level. Policy engine defines allowed/forbidden operations. Container sandboxing. Network egress filtering. Complete operation logging.

**Consequences**

**Positive**:
- Defense in depth
- Audit trail for compliance
- Configurable constraints

**Negative**:
- Performance overhead
- False positives possible

**Confidence Level**: HIGH — Multiple layers provide redundancy

---

### ADR-010: Three-Level Work Decomposition

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Work needs hierarchical organization for tracking and dependency management. Flat task lists become unmanageable.

**Decision**

Milestone/Slice/Task (MST) hierarchy: Milestones (major phases) → Slices (feature groups) → Tasks (executable units). DAG dependencies between tasks.

**Consequences**

**Positive**:
- Clear progress tracking
- Parallel execution opportunities
- Dependency visualization

**Negative**:
- Overhead for small projects
- Structure enforcement required

**Confidence Level**: HIGH — Proven pattern from Agile/Scrum

---

### ADR-011: Team AI Directives

**Status**: Accepted

**Date**: 2026-04-25

**Context**

AI agents need team-specific guidance (coding standards, patterns, preferences). This knowledge should be version-controlled and shared.

**Decision**

Team AI Directives repository: Constitution (principles), Personas (roles), Rules (patterns), Skills (capabilities). Git-versioned, forkable, extensible.

**Consequences**

**Positive**:
- Shared team knowledge
- Version-controlled guidance
- Reusable across projects

**Negative**:
- Repository maintenance
- Sync complexity

**Confidence Level**: HIGH — Essential for consistent agent behavior

---

## Workspace ADRs

### ADR-012: Per-Workspace Pod Deployment

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Remote workspaces need isolation. Shared pods compromise security and resource accounting.

**Decision**

Each remote workspace is a dedicated K8s pod. Pod-per-workspace model ensures complete isolation. Resource quotas per pod.

**Consequences**

**Positive**:
- Complete isolation
- Independent scaling
- Clean failure domains

**Negative**:
- Higher resource overhead
- Slower startup than shared

**Confidence Level**: HIGH — Industry standard for isolation

---

### ADR-013: Git-Based Workspace Lifecycle

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Workspace state must be versioned and recoverable. External databases add complexity and sync issues.

**Decision**

Git as source of truth for workspace state. Specs, code, and config in git. Workspace lifecycle tied to git operations.

**Consequences**

**Positive**:
- Version control built-in
- Audit trail
- Branch-based isolation

**Negative**:
- Git learning curve
- Binary file limitations

**Confidence Level**: HIGH — Git is standard for code versioning

---

### ADR-014: Dev Container Spec Tool Provisioning

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Local workspaces need consistent tooling. Ad-hoc tool installation is error-prone.

**Decision**

Dev Container specification for tool provisioning. Standardized container images with pre-installed tools. Tool versions pinned in spec.

**Consequences**

**Positive**:
- Consistent tooling
- Reproducible environments
- IDE integration

**Negative**:
- Container image maintenance
- Storage overhead

**Confidence Level**: HIGH — Dev containers widely adopted

---

### ADR-015: Hybrid Client Extension

**Status**: Accepted

**Date**: 2026-04-25

**Context**

Developers use both CLI and GUI tools. Context switching between tools is inefficient.

**Decision**

Hybrid client extension: CLI for power users, Visual UI for non-developers. Shared underlying workspace engine. JSON-RPC between UI and daemon.

**Consequences**

**Positive**:
- Serves both personas
- Shared core logic
- Progressive disclosure

**Negative**:
- Two UIs to maintain
- Feature parity requirements

**Confidence Level**: HIGH — Necessary for adoption across skill levels

---

### ADR-016: Hybrid Workspace Provisioning

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Different use cases require different isolation levels. Local for speed, remote for security.

**Decision**

Two workspace types: Local (Docker, <30s) and Remote (K8s, <60s). Unified abstraction hides differences. Auto-select based on context, allow manual override.

**Consequences**

**Positive**:
- Optimal for each use case
- Progressive adoption path
- Feature parity >90%

**Negative**:
- Dual code paths
- Testing matrix complexity

**Confidence Level**: HIGH — Necessary for security/speed trade-off

---

## Git Integration ADRs

### ADR-017: Layered Git Strategy

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Local and remote workflows need different git strategies. Local needs speed, remote needs isolation.

**Decision**

Worktrees for local (immediate visibility), clones for remote (isolation). Hybrid strategy auto-selects per workspace type. Explicit commit/push for state handoff.

**Consequences**

**Positive**:
- Optimal for each environment
- Clear sync semantics
- Fast local iteration

**Negative**:
- Two strategies to understand
- Handoff complexity

**Confidence Level**: HIGH — Matches workspace isolation requirements

---

## User Interface ADRs

### ADR-018: Bimodal Interface

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Developers prefer CLI efficiency. Non-developers need visual interfaces. Both must work with same specs.

**Decision**

CLI (developers) + Visual UI (non-developers). Shared YAML/Markdown spec format. 100% round-trip fidelity. CLI shows UI equivalents for learning.

**Consequences**

**Positive**:
- Serves both personas equally
- Shared source of truth
- Progressive skill building

**Negative**:
- Dual interface maintenance
- Complexity in sync

**Confidence Level**: HIGH — Required for team-wide adoption

---

## Agent Runtime ADRs

### ADR-019: Marker-Based DAG Orchestration

**Status**: Proposed

**Date**: 2026-05-07

**Context**

Tasks have dependencies. Parallel execution improves speed. Markers indicate execution semantics.

**Decision**

Markdown markers: `[P]` (parallel), `[ASYNC]` (autonomous), `[SYNC]` (human-gated). Parser builds DAG from markers. <2s build time. Runtime executes according to graph.

**Consequences**

**Positive**:
- Parallel execution >70%
- Dependency clarity
- Human gates where needed

**Negative**:
- Marker syntax learning
- Misdeclaration risk

**Confidence Level**: MEDIUM — Novel approach, needs validation

---

### ADR-020: Desktop Application Architecture

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Web UIs lack OS integration. Electron provides native feel with web tech. Daemon needed for background tasks.

**Decision**

Electron desktop app with embedded Node.js daemon. JSON-RPC over Unix socket. React 19 renderer. SQLite local storage. Bundled Node.js v24.

**Consequences**

**Positive**:
- Native OS integration
- Background processing
- Offline capability

**Negative**:
- Electron bundle size
- Memory overhead

**Confidence Level**: HIGH — Proven architecture (VS Code, Slack)

---

## Implementation ADRs

### ADR-101: pnpm Workspace Monorepo

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Multiple packages (desktop, web, daemon, shared) need coordinated development. Separate repos create friction.

**Decision**

pnpm workspace monorepo. Three packages: `apps/*`, `packages/*`. Catalog dependency pinning. Sequential builds (`--workspace-concurrency=1`).

**Consequences**

**Positive**:
- Atomic cross-package changes
- Shared dependency management
- TypeScript project references

**Negative**:
- Build serialization bottleneck
- pnpm-specific tooling

**Confidence Level**: HIGH — Proven pattern, explicit config

---

### ADR-102: TypeScript-First Development

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Type safety reduces bugs. Modern TS features improve developer experience. ESM is the future.

**Decision**

TypeScript 6.x strict mode. ES2022 target. ESM modules. Strict null checks. Path aliases for clean imports.

**Consequences**

**Positive**:
- Type safety across codebase
- Modern language features
- Better IDE support

**Negative**:
- Build step required
- Learning curve for JS devs

**Confidence Level**: HIGH — Industry standard for new projects

---

### ADR-103: Modular App/Package Separation

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Clear boundaries prevent spaghetti code. Apps vs packages have different concerns.

**Decision**

`apps/` for deployable applications. `packages/` for shared libraries. Clear dependency direction (packages → apps). No circular dependencies.

**Consequences**

**Positive**:
- Clear architecture boundaries
- Reusable packages
- Independent versioning

**Negative**:
- Refactoring overhead
- Dependency management

**Confidence Level**: HIGH — Clean architecture principle

---

### ADR-104: Electron with Embedded Daemon

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Desktop needs background processing. Main process blocks on heavy tasks. Separate process needed.

**Decision**

Electron main + renderer + embedded Node.js daemon. Daemon handles SQLite, agents, scheduling. JSON-RPC IPC. Bundled Node.js v24.

**Consequences**

**Positive**:
- Non-blocking main process
- Background task support
- Persistent state

**Negative**:
- Process management complexity
- IPC overhead

**Confidence Level**: HIGH — Pattern from VS Code, Slack

---

### ADR-105: JSON-RPC over Unix Socket

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Renderer ↔ Daemon communication needs secure, fast IPC. HTTP adds overhead. WebSocket too complex.

**Decision**

JSON-RPC 2.0 over Unix domain socket. Type-safe message definitions. Request-response + push notifications. Encrypted on macOS keychain.

**Consequences**

**Positive**:
- Low latency
- Type-safe
- Bidirectional

**Negative**:
- Socket file management
- Platform differences (Unix vs Windows)

**Confidence Level**: HIGH — Efficient for local IPC

---

### ADR-106: SQLite for Local Data

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Local app needs persistent storage. File-based is too simple. External DB adds ops overhead.

**Decision**

SQLite with WAL mode. better-sqlite3 for sync API. Versioned migrations. Foreign keys enforced. Electron safeStorage for secrets.

**Consequences**

**Positive**:
- Zero-config database
- ACID transactions
- Single file backup

**Negative**:
- Not for high concurrency
- Migration complexity

**Confidence Level**: HIGH — Proven for local apps

---

### ADR-107: React 19 with Radix UI

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Modern React features improve DX. Headless UI primitives needed. shadcn/ui provides accessible components.

**Decision**

React 19 (latest). Radix UI primitives (headless, accessible). shadcn/ui new-york theme. Tailwind CSS v3.4. Geist font.

**Consequences**

**Positive**:
- Modern React features
- Accessible by default
- Customizable styling

**Negative**:
- Newer ecosystem
- Breaking changes risk

**Confidence Level**: HIGH — React 19 stable, Radix proven

---

### ADR-108: Model Context Protocol (MCP)

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Agents need standardized tool access. Custom protocols fragment ecosystem. MCP is emerging standard.

**Decision**

Model Context Protocol integration. MCP SDK for tool definitions. Stdio transport for local tools. HTTP transport for remote. Tool registry in daemon.

**Consequences**

**Positive**:
- Standardized tool interface
- Ecosystem compatibility
- Vendor-neutral

**Negative**:
- Early standard (may change)
- Limited ecosystem currently

**Confidence Level**: HIGH — Anthropic-backed, growing adoption

---

### ADR-109: Vite + tsup Build Pipeline

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Fast dev builds needed. Production optimization required. Different tools for different packages.

**Decision**

Vite 8 for apps (dev + production). tsup for packages (fast library builds). esbuild under both. TypeScript strict.

**Consequences**

**Positive**:
- Fast HMR in dev
- Optimized production
- Fast package builds

**Negative**:
- Two build tools
- Config complexity

**Confidence Level**: HIGH — Modern standard tooling

---

### ADR-110: Vitest Unit Testing

**Status**: Accepted

**Date**: 2026-05-07

**Context**

Testing is mandatory per constitution. Jest is slower. Native ESM support needed.

**Decision**

Vitest for unit and integration tests. Playwright for E2E. Coverage reporting. CI gate on test failure.

**Consequences**

**Positive**:
- Fast test runs
- Native ESM
- Jest-compatible API

**Negative**:
- Newer ecosystem
- Migration from Jest if switching

**Confidence Level**: HIGH — Modern standard, fast

---

## Appendix A: Decision Themes

| Theme | ADRs | Key Principle |
|-------|------|---------------|
| Multi-Agent Support | ADR-004, ADR-006, ADR-019 | Agent-agnostic architecture |
| Hybrid Infrastructure | ADR-016, ADR-017 | Seamless local/remote experience |
| Git-Native Storage | ADR-013, ADR-017 | Version control as source of truth |
| Safety & Constraints | ADR-009, ADR-012 | Defense in depth |
| User Experience | ADR-018, ADR-020 | CLI + Desktop interfaces |
| Monorepo Structure | ADR-101, ADR-103 | pnpm workspaces, clear boundaries |
| Type Safety | ADR-102 | TypeScript-first development |
| Desktop Architecture | ADR-104, ADR-105 | Electron + JSON-RPC + Daemon |
| Local Data | ADR-106 | SQLite for persistence |
| Modern Web Stack | ADR-107, ADR-109 | React 19, Vite, ESM |
| AI Integration | ADR-108 | Model Context Protocol |
| Testing | ADR-110 | Vitest for unit tests |

---

*This file is auto-generated from AD.md. Last updated: 2026-05-09*
