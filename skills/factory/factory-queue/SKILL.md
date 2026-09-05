---
name: factory-queue
description: Control Plane Ingestion & Planning Engine. Manages the Mission Brief Queue (triage, AI-assisted advisory scoring, and gating label stamping) and product planning.
---

# factory-queue

## What this skill does

`factory-queue` manages the ingestion, triage, and planning boundaries of the software factory (deck slide 12 The Queue stage). It operates directly against the external issue tracker (the Queue) as the single source of truth (ADR-317) using the tracker-agnostic integration layer (`factory-mission/references/tracker-integration.md`).

It performs two primary control-plane operations:
1. **Advisory Triage & Ingestion** (default `triage` mode): Pulls un-triaged candidate briefs, runs stateless AI triage scoring (PDR-048), presents the Intent Gate to the human, and stamps gating/dispatch labels.
2. **Product Planning** (`plan` mode, PDR-020): Reads accepted PDRs+ADRs and the PRD/AD, generates milestones (done-means) and epics, and pushes them as structured, labeled issues to the Q.

---

## When to use

- At product intake, to triage candidate briefs and approve them for execution.
- After a product/architect lifecycle converges, to decompose the specification into prioritized tracker issues.
- You want to run an advisory-only Intent Gate with automatic label transition gating.

**When NOT to use**:
- For inner-loop feature execution (use `factory-mission` instead).
- As a standalone markdown generator (this requires issue-tracker connectivity).

---

## Operating Modes

### 1. Ingestion & Triage Mode (default)

Operates on candidate issues (labeled `intent`) or local draft briefs:

1. **Pull Candidate Briefs**: Discover the active tracker provider and fetch issues with status `intent` (`factory-mission/references/tracker-integration.md`).
2. **AI Triage Scoring (PDR-048)**: Compute stateless advisory scores on three dimensions:
   - **Risk**: Blast radius, data sensitivity, and architectural impact (Low / Medium / High).
   - **Complexity**: Scope and cross-service dependencies (Low / Medium / High).
   - **Agent Confidence**: Estimation of end-to-end execution success (0-100%, High/Medium/Low bands).
3. **Intent Gate Presentation**: Present candidate briefs + advisory scores to the human. **The Human Intent Gate is non-negotiable**; no brief is auto-approved or auto-rejected.
4. **Label Stamping (ADR-318)**:
   - On approval: Transition lifecycle label `intent` ──► `spec-gated`. Stamp automation-gating (`agent-can-execute` or `human-required`) and dispatch (`autonomous` | `supervised` | `interactive`) labels.
   - On rejection: Transition `intent` ──► `cancelled` (or delete draft).
   - On deferral: Move to backlog.

### 2. Plan Mode (PDR-020)

Operates post-lifecycle convergence to populate the backlog:

1. **Load Artifacts**: Read accepted PDRs + ADRs and the generated `PRD.md` / `AD.md`.
2. **Generate Milestones & Epics**: Extract sequencing, requirement groupings, and "done-means" definitions into prioritized epics and milestones.
3. **Deduplication Check**: Fetch existing issues to match task summaries and prevent duplicates.
4. **Push to Q**: Push epics and milestone issues to the tracker via MCP. Stamp appropriate automation-gating and dispatch labels on each generated issue based on AI triage.
5. **Output**: Write a versioned `.adlc/roadmap.md` linking the local spec elements to the newly created external tracker issues.

---

## Invariants & Safety Constraints

1. **Stateless (ADR-317)**: The platform holds no queue state of its own. All queries and mutations are performed live via the tracker's MCP/CLI connectors.
2. **Dry-Run Gating**: **No tracker write may occur without dry-run confirmation**. The skill must output a detailed preview of all issues, comments, or label changes, requiring the user to explicitly confirm before execution.
3. **Advisory Scores**: Scores are advisory metadata and never bypass human gates.
