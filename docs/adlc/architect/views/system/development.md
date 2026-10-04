# Development View: system

**Sub-System**: system
**ADRs**: ADR-001, ADR-002
**Generated**: 2026-10-04
**Dependencies**: Functional (system/)

---

## Development (system)

**Purpose**: Code organization for the runtime and port seams — what lives where, and what contributors must not break.

### Code Organization

```text
skills/factory/factory-deploy/
├── SKILL.md                  # Orchestrator contract (stages, gates, invariants)
├── references/
│   ├── executor.md           # Re-export or pointer: shared contract (DO NOT FORK)
│   ├── tracker-integration.md# Re-export or pointer: bus/lease conventions
│   ├── ports.md              # TrackerPort + FlagPort definitions (NEW)
│   ├── thresholds.md         # Verbatim band table + budget bands (NEW)
│   └── deploy-record-schema.md # deploy-record/1 JSON schema (NEW)
└── (adapters live in provider bindings, not here)
```

### Module Dependencies

**Dependency Rules:**

- Stages depend on ports, never on provider SDKs (grep-verifiable: no SDK imports outside adapters).
- Default TrackerPort adapter depends on mission's tracker-integration layer (wrap, don't fork).
- FlagPort default adapter is standalone; in-memory fakes live beside tests.
- Nothing in the skill depends on factory-monitor or factory-learn (they consume outputs).

### Build & CI/CD

- **Build System**: None (skill is Markdown + referenced scripts; validation via pytest suites).
- **CI Pipeline**: `test_playbook_integrity` (depth, frontmatter, token budget) + `test_generated_artifacts_sync` (mirror + commands) — both must stay green; mirror entry required for every new skill file set.
- **Deployment Strategy**: Skills install via adlc-cli (`skills add`); `.agents/skills/` mirror + `.opencode/commands/` regenerated on change (non-invocable orchestrators get mirror only, no command file).

### Development Standards

- **Executor contract**: Read-only. Any diff to shared executor files in a deploy change is rejected in review.
- **Port discipline**: New provider capability → port extension proposal with evidence, never stage-level branching.
- **Additive primitives**: Env locks + wake binding prove in pilot before any contract-promotion proposal.
