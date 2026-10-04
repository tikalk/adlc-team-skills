# Operational View: safety

**Sub-System**: safety
**ADRs**: ADR-004, ADR-005 (plus PDR-007 invariants)
**Generated**: 2026-10-04
**Dependencies**: Deployment (safety/)

---

## Operational (safety)

**Purpose**: Operating the safety machinery — monitoring the monitors, handling holds/rollbacks/overrides, and disaster postures.

### Operational Responsibilities

| Activity | Owner | Frequency | Automation |
|----------|-------|-----------|------------|
| Threshold band review | Team | Per incident / quarterly | Verdict history from archives |
| Override review | Team lead + factory-learn | Per occurrence / periodic retro | Override annotations aggregated |
| Approval hygiene (rubber-stamp watch) | Team lead | Periodic | Approval latency ≈ 0 + zero rejections = smell |
| Wake schedule audit | Operator | Per arming (pre-flight) + on missed wake | Schedule-exists check; stale-lease detection |
| Blackout window config | Repo maintainer | On change | Declarable per repo |

### Monitoring & Alerting

- **Key Metrics**: Verdict distribution (advance/hold/rollback) per release; override rate; missed-wake count; gate approval latency.
- **Alerting Rules**: Missed wake with live lease → investigate scheduler; override without retrospective follow-up within one cycle → escalate to team lead; rubber-stamp pattern (instant approvals, zero rejections) → process review.
- **Logging Strategy**: Every verdict/gate/override lands in run archive + bus markers; retention follows run-retention rules.

### Disaster Recovery

- **RTO**: Resume-capable immediately (state + markers intact); full re-verification path if state corrupt (halt, human resumes from markers).
- **RPO**: Last completed stage (program counter); in-flight stage work is replayable by design.
- **Backup Strategy**: Dual-channel state (archive authoritative, markers projective); either side rebuilds the narrative.

### Support Model

- **Tier 1**: Run operator (holds, resumes, routine approvals).
- **Tier 2**: Code-owner (merge-gate readiness, override orders).
- **Tier 3**: Skill maintainer (threshold tuning, invariant changes — ADR-gated).
- **On-call**: Future factory-monitor owns production on-call; deploy runs never page.
