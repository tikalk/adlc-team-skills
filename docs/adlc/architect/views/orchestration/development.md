# Development View: orchestration

**Sub-System**: orchestration
**ADRs**: ADR-003
**Generated**: 2026-10-04
**Dependencies**: Functional (orchestration/)

---

## Development (orchestration)

**Purpose**: Pipeline code shape — classifier, runner, keepers, and the resume contract contributors implement against.

### Code Organization

```text
orchestration (within factory-deploy references + run tooling)/
├── classify.md               # Short-path rule text (docs-only / flag-off / patch-with-budget)
├── stages.md                 # 8-stage table: inputs, outputs, output_type per stage
├── resume.md                 # Program-counter protocol: read state → cross-check markers → continue
├── correction-loop.md        # Hold/rollback → bounded retry → human routing
└── state-schema.md           # state.json fields: counter, route, keys, lease ref
```

### Module Dependencies

**Dependency Rules:**

- Stage Runner depends on Brief Keeper (route) and State Keeper (counter) — never the reverse.
- Marker Projector depends on TrackerPort (ADR-002) — orchestration never touches tracker APIs directly.
- Correction Loop depends on safety verdicts as input; it routes, it never evaluates.
- Short-path rule text is versioned with the skill; rule changes are ADR amendments.

### Build & CI/CD

- **Build System**: Same as system view (Markdown + pytest gates).
- **CI Pipeline**: Kill-and-resume drill (mid-canary kill → resume with zero duplicated actions) as a future automated check; marker/file consistency assertion per stage transition.
- **Deployment Strategy**: Ships with the skill; no separate deployable.

### Development Standards

- **Counter monotonicity**: Code must never decrement the program counter; resume only advances.
- **Closed-stage keys**: Every mutating stage declares its idempotency key up front (release owns the keys; orchestration enforces the check).
- **No mid-run re-routing**: Stage code has no route-changing paths; adaptation flows through the correction loop only.
