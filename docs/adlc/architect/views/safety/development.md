# Development View: safety

**Sub-System**: safety
**ADRs**: ADR-004, ADR-005
**Generated**: 2026-10-04
**Dependencies**: Functional (safety/)

---

## Development (safety)

**Purpose**: Gate and verdict code shape — observers, keepers, evaluator, and the invariant checks contributors extend carefully.

### Code Organization

```text
safety (within factory-deploy references + run tooling)/
├── gates.md                  # Merge Gate observer + Deploy Gate keeper + checkpoint markers
├── merge-guard.md            # Execution-time re-read + SHA assertion + refuse/halt paths
├── forgery-response.md       # Identity-mismatch halt protocol (resumable)
├── evaluator.md              # Arm → wake → evaluate → verdict (idempotent by step+wake#)
├── budget-reader.md          # Unified SLO/burn reads per verdict
└── invariants.md             # Eight mechanical checks + override annotation path
```

### Module Dependencies

**Dependency Rules:**

- Merge Guard depends on both gate observers + git host state — never on cached approvals.
- Evaluator depends on metrics port + frozen snapshot — never on gate state (verdicts ≠ authorizations).
- Invariant Enforcer wraps both; it constrains, it never computes or approves.
- Budget Reader is a sub-reader of the evaluator, not a standalone gate (unified verdicts).

### Build & CI/CD

- **Build System**: Same as system view.
- **CI Pipeline**: Gate drill matrix (both-green merges / either-red refuses / head-moved re-verifies / forged-marker halts / tracker-outage halts); verdict drill (duplicate wake converges; outage holds, never green).
- **Deployment Strategy**: Ships with the skill.

### Development Standards

- **Bright-line rule**: No code path where evaluation output authorizes action, and none where gate code computes bands — reviewers reject crossings.
- **Bands are config**: Threshold/budget numbers live in run config (`thresholds.md`), never hard-coded; tuning bands is not a code change.
- **Halt over degrade**: Any new failure mode defaults to halt-first; convenience paths require ADR-level justification.
