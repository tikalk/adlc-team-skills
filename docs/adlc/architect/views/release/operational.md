# Operational View: release

**Sub-System**: release
**ADRs**: ADR-006, PDR-010
**Generated**: 2026-10-04
**Dependencies**: Deployment (release/)

---

## Operational (release)

**Purpose**: Closing out and handing off — first-hour verification, packet delivery, and the boundary where deploy's job ends.

### Operational Responsibilities

| Activity | Owner | Frequency | Automation |
|----------|-------|-----------|------------|
| First-hour verification | Deploy run (`full` stage) | Per release | Health/error/latency/flow/logs/rollback-ready checks |
| Handoff packet delivery | Deploy run (`publish` stage) | Per release | Built from record + verification results |
| Flag-expiry follow-through | Releasing code-owner | Within 2 weeks post-rollout | Expiry recorded; removal confirmed or escalated |
| Telemetry-presence gate | Deploy run (`verify` stage) | Per release | Missing telemetry = halt + route to build |
| Record mining (downstream) | factory-learn | Periodic | ChDR candidates from rollback/revert/hotfix runs |

### Monitoring & Alerting

- **Key Metrics**: First-hour signals (health 200, new error types = 0, latency normal, logs flowing); packet completeness (all fields present).
- **Alerting Rules**: This skill defines no production alerts — symptom alerting belongs to the future monitor; deploy's "alerts" are stage verdicts with bounded retries → human.
- **Logging Strategy**: Structured run outputs (verdicts, gates, previews, records) in archive + bus; application telemetry is read, never written, by deploy.

### Disaster Recovery

- **RTO**: Rollback plan targets — flag <1min, redeploy <5min, DB <15min (plan exists pre-stage or the run never started).
- **RPO**: Release-scoped only (artifact + tag + notes reproducible from record); production data recovery is out of scope (monitor/platform concern).
- **Backup Strategy**: Tag immutable on host; notes mirrored tracker + archive; record + packet in archive.

### Support Model

- **Tier 1**: Run operator (verification checks, packet confirmation).
- **Tier 2**: Code-owner (flag-expiry enforcement, handoff questions).
- **Tier 3**: Monitor team (future) — accepts packet, owns everything after close.
- **On-call**: Explicitly not this skill (PDR-010 boundary).
