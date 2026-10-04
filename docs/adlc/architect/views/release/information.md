# Information View: release

**Sub-System**: release
**ADRs**: ADR-006
**Generated**: 2026-10-04
**Dependencies**: Context, Functional (release/)

---

## Information (release)

**Purpose**: Artifact and evidence data — the release cut's inputs/outputs and the versioned schema decoupled consumers read.

### Data Entities

| Entity | Storage Location | Owner Component | Lifecycle | Access Pattern |
|--------|------------------|-----------------|-----------|----------------|
| Idempotency keys | Run state (SHA / tag-name / content-hash per cut step) | Cut Sequencer | Derived pre-step → checked → marked complete | Read-before-act, write-on-complete |
| SemVer tag | Git host (immutable ref) | Version Enforcer | Validated → created → pushed | Write-once |
| Changelog section | Tracker (published) + archive (preview + approved draft) | Changelog Builder | Generated → approver-edited → published | Draft → approve → publish |
| `deploy-record/1` JSON | Run archive | Record Writer | Assembled at close from run outputs | Write-once; read by miners |
| Handoff packet | Run archive | Packet Builder | Built from record + verification results | Write-once; read by future monitor |
| Flag lifecycle state | Flag provider + run record | Cleanup Enforcer | Active → expired → removed (≤2 weeks) | Read at `full`; confirm removal |

### Data Flow

**Key Data Flows:**

1. **Cut flow**: Both-green gates → merge (SHA key) → tag (name key) → changelog (content-hash key) → cleanup; each step checks its key first.
2. **Preview flow**: Planned mutation → rendered diff → archive → approver edit → approved content becomes the write payload.
3. **Evidence flow**: Gates + verdicts + SHAs → Record Writer → `deploy-record/1` → Packet Builder → handoff file; miners read without parsing prose.

### Data Quality & Integrity

- **Consistency Model**: Tag is source of truth for version; approved preview is source of truth for changelog content; keys make re-execution converge (skip-if-present).
- **Validation Rules**: Schema-validated record (`1.x` additive accepted, unknown breaking rejected); tag/version/changelog triple cross-checked at close.
- **Retention Policy**: Records and packets persist with the run archive; tags immutable on the host.
- **Backup Strategy**: Archive + tracker hold copies of notes; git holds tags; no single store is irreplaceable except the host tag (standard git redundancy applies).
