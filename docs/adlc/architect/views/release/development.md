# Development View: release

**Sub-System**: release
**ADRs**: ADR-006
**Generated**: 2026-10-04
**Dependencies**: Functional (release/)

---

## Development (release)

**Purpose**: Cut-and-evidence code shape — sequencer, builders, and the schema contributors extend additively.

### Code Organization

```text
release (within factory-deploy references + run tooling)/
├── cut-sequence.md           # Fixed order + per-step idempotency keys
├── semver.md                 # Spec-kit decision tree + strict X.Y.Z gate + tag-as-truth
├── changelog.md              # Tracker grouping rules + approver-edit flow
├── previews.md               # Dry-run renderer contract per mutation type
├── deploy-record-schema.md   # deploy-record/1 fields + 1.x additive rule + 2.0 trigger
└── handoff-packet.md         # Monitor packet fields + build-from-record rule
```

### Module Dependencies

**Dependency Rules:**

- Cut Sequencer depends on both-green gate outputs (safety) — it never checks gates itself, it receives authorization.
- Changelog Builder depends on preview approval content — published notes equal approved draft, byte-relevant.
- Record/Packet builders depend on run outputs only — they format evidence, they never decide.
- Schema changes: additive fields need changelog note; breaking changes need ADR amendment + major bump.

### Build & CI/CD

- **Build System**: Same as system view.
- **CI Pipeline**: Crash drill (kill between tag and changelog → resume skips tag, writes notes once); schema validator fixture (accepts additive `1.x`, rejects undeclared breaking).
- **Deployment Strategy**: Ships with the skill.

### Development Standards

- **Fixed order**: Cut-sequence reordering is an ADR amendment, not a config tweak.
- **Preview parity**: Every mutation type has a renderer; a mutation without a preview path is unshippable by construction.
- **Evidence completeness**: A closed run without record + packet fails verification (Phase 5 check analogue).
