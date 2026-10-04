# Information View: safety

**Sub-System**: safety
**ADRs**: ADR-004, ADR-005
**Generated**: 2026-10-04
**Dependencies**: Context, Functional (safety/)

---

## Information (safety)

**Purpose**: Evaluation inputs and authorization evidence — baselines, verdicts, gate records, and what makes each reproducible.

### Data Entities

| Entity | Storage Location | Owner Component | Lifecycle | Access Pattern |
|--------|------------------|-----------------|-----------|----------------|
| Baseline snapshot | Run state (frozen at arm time) | Armed Evaluator | Snapshot → frozen → referenced by verdicts | Write-once, read-per-verdict |
| Stage verdict | Run state + bus marker | Armed Evaluator | Computed per wake → recorded → acted on | Write-once, read-by-advance |
| Threshold bands | Run config (verbatim ship table) | Invariant Enforcer | Fixed per skill version; tuning is config | Read-only at evaluation |
| Gate approval record | Tracker markers + run state | Deploy Gate Keeper | Proposed → approved (identity + timestamp + SHA) → consumed | Read at checkpoints + merge re-read |
| Merge Gate observation | Tracker state (approval/label) | Merge Gate Observer | Observed → re-read at execution | Read twice (observe + execute) |
| SLO/burn snapshot | Evaluation input per wake | Budget Reader | Fresh per evaluation (never cached across wakes) | Read-per-verdict |
| Override annotation | Run record + bus | Invariant Enforcer | Written on explicit human order only | Append-only, feeds retrospectives |

### Data Flow

**Key Data Flows:**

1. **Arm flow**: Thresholds + baseline snapshot + wake schedule recorded → evaluator armed → worker released (nothing held open).
2. **Verdict flow**: Wake → fresh metrics + burn reads → band evaluation against frozen snapshot → verdict recorded → advance/hold/rollback.
3. **Gate flow**: Approval observed → checkpoint marker (identity/SHA) → execution-time re-read → SHA equality asserted → act or refuse/halt.
4. **Override flow**: Explicit human order → annotation (who/when/why) → action → retrospective feed.

### Data Quality & Integrity

- **Consistency Model**: Frozen inputs per verdict (snapshot at arm, fresh reads at wake); re-computation against the same snapshot yields the same verdict.
- **Validation Rules**: Verdict without frozen baseline is invalid (first-run waiver path instead); gate action without identity is invalid; budget reads older than the wake are invalid.
- **Retention Policy**: Verdicts and gate records persist with the run archive; burn snapshots retained per evaluation for audit.
- **Backup Strategy**: Bus markers mirror verdicts/gates; archive holds inputs — either side rebuilds the narrative, state holds the truth.
