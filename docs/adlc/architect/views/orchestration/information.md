# Information View: orchestration

**Sub-System**: orchestration
**ADRs**: ADR-003
**Generated**: 2026-10-04
**Dependencies**: Context, Functional (orchestration/)

---

## Information (orchestration)

**Purpose**: Run-state data — what the pipeline remembers, where, and which copy wins.

### Data Entities

| Entity | Storage Location | Owner Component | Lifecycle | Access Pattern |
|--------|------------------|-----------------|-----------|----------------|
| Run brief | Run archive (`brief`) | Brief Keeper | Create at intake → frozen → archived | Read-heavy (every resume, every worker) |
| Program counter state | Run archive (`state.json`) | State Keeper | Advance per stage; terminal at close | Write-on-transition, read-on-resume |
| Lease record | Lease store | Lease Manager | Acquire → heartbeat-renew → release/expire | Frequent renew writes; read on resume |
| Stage drafts/previews | Run archive (scratchpads) | Stage Runner | Create per stage → approved → superseded | Write-once, read-at-gate |
| Comment markers | Tracker (issue/PR comments) | Marker Projector | Append-only per decision/verdict | Append-only; read on cross-session resume |
| Route classification | Brief (frozen field) | Route Classifier | Decided once at intake | Read-only after intake |

### Data Flow

**Key Data Flows:**

1. **Intake flow**: Invoker metadata → Route Classifier → brief (route frozen) → State Keeper (counter at zero).
2. **Stage flow**: Stage Runner reads brief + state → executes → writes files → Marker Projector mirrors decision/verdict → State Keeper advances counter.
3. **Resume flow**: Lease check → state read → markers cross-checked → execution continues at counter (closed stages skipped by key, never re-run).
4. **Correction flow**: Hold/rollback outcome → Correction Loop → human decision → recorded back into state + markers.

### Data Quality & Integrity

- **Consistency Model**: Program counter authoritative; markers are the readable projection. On disagreement, state wins and markers are backfilled.
- **Validation Rules**: Route field immutable after intake; counter monotonic (never decremented); closed-stage keys present before advance.
- **Retention Policy**: Run archive retained per run-retention rule (retained if unsaved work); markers persist with the tracker issue.
- **Backup Strategy**: Archive is the backup of record; markers rebuild context, never state.
