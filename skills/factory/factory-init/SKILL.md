---
name: factory-init
description: Use when onboarding a brownfield repo onto ADLC end-to-end, or running the recurring PDR↔ADR↔ChDR↔code alignment sweep (--refresh).
disable-model-invocation: true
---

# factory-init

## What this skill does

`factory-init` orchestrates the **unified brownfield bootstrap**: one command that reverse-engineers an existing codebase onto all three project-memory layers and measures how well they align with the code.

It coordinates the leaf lifecycle skills directly — `product-init`, `product-clarify`, `product-implement`, `product-analyze`, `architect-init`, `architect-clarify`, `architect-implement`, `architect-analyze`, `change-init`, `change-clarify`, `change-publish` — **never** the peer orchestrators `factory-product` / `factory-architect` / `factory-learn`.

Its own final step, the **sweep**, is the only cross-layer analysis in the factory: it builds the **coverage matrix** (`.adlc/coverage/coverage.md`) — a feature-area pivot plus the four traceability relations PDR↔ADR, PDR↔code, ADR↔code, ChDR↔code — and diffs it against the previous sweep to detect drift.

It operates as a **Kind-A DAG orchestrator** in alignment with the shared executor engine contract in `factory-mission/references/executor.md`.

**Scope boundary**: project-local memory only (PDR, ADR, ChDR + code). Team context directives (CDR / `levelup-init`) are NOT bootstrapped here — they publish to the external `team-ai-directives` repo and are owned by `factory-learn`. The sweep's final output includes a prose recommendation to run `factory-learn` / `/levelup-init` for reusable patterns spotted during bootstrap.

---

## When to use

- You adopt ADLC on an **existing repo** (code exists, no/partial PDRs, ADRs, ChDRs) and want the full bootstrap in one run.
- You want a **recurring cross-layer alignment audit** (`--refresh`): which decisions are undocumented, which code is undecreed, where product and architecture disagree.

**When NOT to use**:
- Greenfield / empty project → run `factory-product` and `factory-architect` (specify routes) instead.
- Single-layer work → `factory-product` / `factory-architect` / `factory-learn` directly.
- CDR / team-directives contribution → `factory-learn`.
- Feature implementation → `factory-mission`.

---

## Route Classification

| Condition | Route |
|--|--|
| Code exists, no memory records | **Bootstrap** (full pipeline) |
| `.adlc/coverage/coverage.md` exists, or `--refresh` | **Refresh** (sweep only) |
| Partial state | Bootstrap with **per-layer skip** (below) |
| No code | Halt: greenfield — use `factory-product` / `factory-architect` specify routes |

**Per-layer skip** — each track classifies independently; a layer whose memory AND compiled artifact both exist skips its init/implement and runs only its analyze:

| Layer | Skip init/implement when | Always runs |
|--|--|--|
| product | `.adlc/memory/pdr/` non-empty AND `PRD.md` exists | product-analyze |
| architecture | `.adlc/memory/adr/` non-empty AND `AD.md` exists | architect-analyze |
| change | `.adlc/memory/chdr/` non-empty AND `.adlc/memory/chdr.md` exists | (ChDRs feed the sweep directly) |

---

## Lifecycle DAG & Step Resolution

`factory-init` implements a **fixed named-skill DAG** (`fixed` step resolution). Tracks run **sequentially** — each track completes before the next starts. Rationale: the human gets one coherent review session per domain; `architect-clarify` reads the accepted PDR decisions as context (architecture serves product); the sweep receives the most mature inputs.

### Bootstrap Route (12 steps, 3 clarify gates + final matrix review)

| # | Step | Skill | Phase | output_type |
|--|--|--|--|--|
| 1 | `product-init` | product-init | generate | draft (`.adlc/drafts/pdr/`) |
| 2 | `product-clarify`⭐ | product-clarify | clarify | decision |
| 3 | `product-implement` | product-implement | build | artifact-ref (`PRD.md`) |
| 4 | `architect-init` | architect-init | generate | draft (`.adlc/drafts/adr/`) |
| 5 | `architect-clarify`⭐ | architect-clarify (reads accepted PDR list) | clarify | decision |
| 6 | `architect-implement` | architect-implement | build | artifact-ref (`AD.md`) |
| 7 | `change-init` | change-init | generate | draft (`.adlc/drafts/chdr/`) |
| 8 | `change-clarify`⭐ | change-clarify | clarify | decision |
| 9 | `change-publish` | change-publish | build | artifact-ref (`.adlc/memory/chdr/`) |
| 10 | `product-analyze` | product-analyze | analyze | findings |
| 11 | `architect-analyze` | architect-analyze | analyze | findings |
| 12 | `sweep` | inline (this skill, §The Sweep Step) | analyze | findings (`.adlc/coverage/coverage.md` + history) |

### Refresh Route (1 step + loop)

| # | Step | Phase | output_type |
|--|--|--|--|
| 1 | `sweep` (rescan + rebuild + drift diff) | analyze | findings |

### Correction Loops

- `product-analyze` / `architect-analyze` CRITICAL/HIGH → route back to **their own track's clarify**⭐ (executor default, bounded by `max_corrections`, default 2).
- `sweep` CRITICAL/HIGH findings route **by layer tag** (ADR-361): every finding carries `[layer: product|architecture|change|cross]` and routes to the matching track's clarify (`product-clarify` / `architect-clarify` / `change-clarify`). `cross` findings route to the track owning the cited record; ambiguous → halt for the human (hybrid gate). Bounded by `max_corrections`.

---

## The Sweep Step (inline composite step)

The sweep is executed by this orchestrator (step `skill: factory-init`, prompt = this section), not by a leaf skill.

### Inputs (all read-only)

| Source | Yields |
|--|
| `product-init` + `architect-init` setup scripts (re-run; idempotent JSON scanners) | sub-systems, feature-areas, tech stack |
| `.adlc/memory/pdr/`, `.adlc/memory/adr/`, `.adlc/memory/chdr/` (+ indexes) | accepted decisions per layer |
| `PRD.md`, `AD.md` | compiled artifacts |
| `.adlc/coverage/coverage.md` (if exists) | previous matrix → drift diff |

### Output: `.adlc/coverage/coverage.md` (+ `history/<date>-<run_id>.md`)

**1. Pivot: Area Coverage** — row axis is the **union of sub-systems ∪ feature-areas**, reconciled by name/directory overlap with a mapping column; unreconciled rows stay separate and are flagged. Every cell cites evidence (record IDs, file paths) — no fabricated cells.

```markdown
## Pivot: Area Coverage

| Area | Feature-Area | Sub-System | PDRs | ADRs | ChDRs | Code Evidence | Coverage |
|------|--------------|------------|------|------|-------|---------------|----------|
| payments | billing | payments | 3 | 1 | 4 | present (src/payments/) | 62% |
```

**2. Relations** — four pairwise, bidirectional; each section has a `Coverage: N%` line and gap lines citing record IDs or paths, each tagged `[layer: ...]`:

| Relation | Gap directions |
|--|--|
| `PDR↔ADR` | product decision with no architectural support; orphan ADR (no product grounding — MEDIUM, not auto-defect) |
| `PDR↔code` | decided-but-unimplemented; implemented-but-undocumented |
| `ADR↔code` | decided-but-not-reflected-in-code; code pattern without ADR |
| `ChDR↔code` | ChDR-dense area with no ADR (active change, no architectural record); ChDR describing code that no longer matches (superseded decision) |

PDR↔ADR mapping requires textual overlap between records — proposed, never asserted.

Every gap line uses the form:

```markdown
- Gap: <description citing PDR-NNN / ADR-NNN / ChDR-NNN or a file path> [layer: product|architecture|change|cross]
```

**3. Severity model** (family standard): constitution violation = CRITICAL; accepted decision contradicted by code = HIGH; undocumented/undecided mismatches = MEDIUM; unreconciled areas, style = LOW.

**4. Drift section** — `## Drift vs <previous date> sweep` (or `## Baseline` on first sweep): new gaps, closed gaps, regressed areas. On refresh, this diff IS the report.

**5. Findings output** — severity-ranked summary published as `output_type: findings` (comment bus if tracker-integrated, else `.adlc/workflow/findings/sweep.md`); every finding tagged `[layer: ...]` for correction routing (ADR-361). The matrix file itself is the artifact; the matrix **never edits records** — it reports, clarify fixes.

---

## Shared Executor Overrides

`factory-init` overrides the shared executor engine primitives as follows:

1. **Publish Target**: Fixed to `local`. Outputs are written to `.adlc/` (drafts, memory, coverage) and `PRD.md` / `AD.md` at project root. If tracker-integrated, a `tracker` completion summary comment is also posted.
2. **Output Types** (per PDR-050): init steps → `draft`; clarify⭐ → `decision`; implement/publish → `artifact-ref`; analyze + sweep → `findings`.
3. **Supervision Default**: `hybrid`. Human gates hard-enforced at the three clarify⭐ steps (PDR, ADR, ChDR approvals) and at final coverage-matrix review.
4. **Pre-flight Check**: Verifies that the `product-*`, `architect-*`, and `change-*` lifecycle skills are installed. Team AI directives configuration is NOT required (CDR excluded); `architect-init`'s team-directives dedup degrades gracefully if unconfigured.
5. **Worktree / lease / heartbeat**: follow the shared executor contract, as sibling orchestrators do.
6. **Route for CDR hand-off**: after the sweep, present (prose only, no step): "Reusable patterns spotted during bootstrap → run `factory-learn` or `/levelup-init`."

---

## Deconfliction

- **`factory-product` / `factory-architect`** brownfield routes remain the **single-layer** entry points; `factory-init` is the unified one. Per-layer skip keeps a re-run cheap on repos that already have one layer documented.
- **`factory-learn`** Historical Mining route = **ongoing/incremental** ChDR mining (post-incident, pre-refactor); `factory-init` = **one-time deep bootstrap** (full window). Both reuse the same `change-*` leaf skills.
- **`levelup-init`** (brownfield CDR) has no factory route today — a known gap in `factory-learn`, out of scope here.

---

## Red Flags

- **Fabricating matrix cells** — every coverage cell and gap must cite a record ID or file path. An uncited gap is context poisoning.
- **Asserted PDR↔ADR mappings** — mapping is proposed on textual evidence; "we think these relate" without overlap text is a fabrication.
- **Silent reconciliation** — merging a feature-area with a sub-system without flagging the mapping (or flagging unreconciled rows as gaps) hides product/architecture disagreement.
- **Skipping clarify gates** — the sweep is last because it audits ACCEPTED decisions; sweeping drafts or auto-accepted records defeats the pipeline.
- **Blind correction routing** — sweep findings must carry `[layer: ...]` tags; routing everything to "the preceding clarify" sends product gaps to architecture review.
- **The matrix editing records** — the sweep reports; only clarify⭐ steps modify decisions with human approval.

## Verification

- [ ] All 12 bootstrap steps completed (or per-layer skip applied with reason recorded in state)
- [ ] `PRD.md`, `AD.md`, `.adlc/memory/pdr/`, `.adlc/memory/adr/`, `.adlc/memory/chdr/` populated per track
- [ ] `.adlc/coverage/coverage.md` written with Pivot (all layer columns), four relations each with `Coverage: N%`, layer-tagged + cited gap lines, and Drift/Baseline section
- [ ] Prior matrix archived to `.adlc/coverage/history/<date>-<run_id>.md`
- [ ] Every sweep finding tagged `[layer: ...]`; CRITICAL/HIGH routed to the matching track's clarify (bounded `max_corrections`)
- [ ] Three clarify gates (product, architecture, change) plus the final matrix review fired in hybrid mode
- [ ] CDR hand-off recommendation presented in the final output
- [ ] Zero records modified by the sweep itself

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `ADR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/adr`
- `CHDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/chdr`
- `COVERAGE_DIR` — `{REPO_ROOT}/.adlc/coverage` (`coverage.md` + `history/`)
- `PRD_FILE` — `{REPO_ROOT}/PRD.md` | `AD_FILE` — `{REPO_ROOT}/AD.md`
- State file — `{REPO_ROOT}/.adlc/workflow/.factory-factory-init-state.json` (executor lease/resume)

## References

- `factory-mission/references/executor.md` — shared executor contract (step schema, phases, correction loop, output types)
- `factory-mission/references/tracker-integration.md` — comment bus, marker comments, distributed lease
- PDR-072 (factory-init skill — unified brownfield bootstrap + coverage matrix)
- ADR-361 (sweep layer-tagged correction routing)
- ADR-341 (workflows as graphs — fixed DAG chosen; declarative graphs remain an option)
- PDR-050 (output type classification — draft/decision/findings/artifact-ref)
- `factory-product/SKILL.md`, `factory-architect/SKILL.md`, `factory-learn/SKILL.md` — sibling orchestrators; single-layer entry points
