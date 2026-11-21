# Eval Seed Taxonomy (ADR-524)

Seed contract for Tier-2 correction routing: what may become a check or an
eval criterion, how the check-vs-eval split is decided, and how a seeded
criterion is confirmed or retired. Amends the ladder in
`factory-review/SKILL.md` §5 and the correction-elimination ladder decision; the recurrence ledger
(`references/recurrence-ledger.md`) is one input, not the only one.

## Three thresholds

1. **Twice-Mistake route identity** — recurrence keyed on the same signal
   class (same pass + same check item, or same event-stream signal),
   observed twice. Routes the correction to the ladder; does not by itself
   authorize a criterion.
2. **Authoring threshold** — a check or eval criterion is authored only at
   **2 reproduced occurrences in ≥2 distinct runs**. One run, however loud,
   is a note in the ledger, not a criterion.
3. **Temporal holdout** — confirmation holds out **later runs**, never a
   random slice. Seed window = the runs where the recurrence was observed;
   holdout = everything after the change ships. Random splits leak the seed
   window into the holdout and confirm noise.

## Evidence rule (reproduction)

Seeds come from the run event stream, never from comment text. A prose
comment (review remark, issue note) is admissible **only if the failure it
describes was reproduced**: failing test, CI red, diff, screenshot, revert,
or recorded state transition. Unreproduced comments are Tier-3 preferences.

## Signal table

| Signal | Source | Status |
|---|---|---|
| Repeated REVIEW.md findings (same pass + check item) | review scratchpads + verdict markers → `recurrence-ledger.tsv` | live (ledger) |
| Converge CONTINUE / score-regression / circuit-breaker events | `runs/<run_id>/state.json` | start here (high frequency) |
| Gate rejects with revise routing | gate payload + state transitions | start here (high frequency) |
| Human edit between gate approval and merge | gate SHA (`head=<sha>`) vs merged diff | start here (high frequency) |
| Reopen after merge | `factory-tickets` reopen signal | start here (high frequency) |
| `SPEC_CORRECTION_NEEDED` / `max_spec_corrections` exhaustion | `state.json` | normalize next |
| Park / resume events | `state.json` | normalize next |
| Dependency-gate blocks | `state.json` | normalize next |
| Review self-heal dispatches | review-loop records | normalize next |

Start with the four high-frequency signals; do not normalize all of them on
day one (the event stream is not one schema: `state.json` vs marker comments
vs lifecycle labels).

## Check-vs-eval split (decidability)

| Property shape | Vehicle | Examples |
|---|---|---|
| Decidable from the artifact alone; must hold on every change | **Deterministic check** (lint rule, schema validation, required marker, forbidden path, missing section, exit code, unit test, pre-commit hook, CI job) | secret exposure; missing `head=<sha>` marker; forbidden path touched; unfilled placeholder |
| A distribution over model behavior; needs sampled judgment | **Eval criterion** (`/evals-specify`: goldset criterion + cases + binary grader) | asked before acting; picked the right lane; stopped at the gate; stated what green proved |

Neither stands in for the other. A check cannot grade behavior (it passes
forever while behavior rots); an eval cannot enforce a decidable property
(oracle independence — a prose judgment is not an oracle).

## Seeding procedure (8 steps)

1. **Detect recurrence** — same signal class twice, in ≥2 distinct runs;
   below that, append to the ledger and wait.
2. **Classify the tier** — ladder first (structural → mechanical →
   judgment); classification before scoring.
3. **Split by decidability** — mechanical corrections route to a check or
   an eval per the table above; state which and why in one line. The
   graded decision is a `tier2-route` record (the fenced JSON block the
   EVAL-017 grader reads): `{"tier": 2, "routes": [{"class":
   "decidable"|"behavioral", "vehicle": "check"|"eval"|"none", "seed":
   "event-stream"|"comment"|"tier-3", "evidence": ["failing test"|"ci red"|
   "diff"|"screenshot"|"revert"|"recorded state transition"|"state.json"],
   "runs": 2}]}`. Prose around it is rationale and is not graded. A
   `tier-3` seed (vehicle `none`, empty evidence, runs 0) declines an
   inadmissible seed to a Tier-3 preference — never a reproduced
   recurrence, which must route to its check or eval vehicle.
4. **Verify the evidence rule** — every occurrence reproduced by artifact,
   not by assertion; a comment-only occurrence fails here.
5. **Author the vehicle** — check via team-levelup action P; eval criterion
   via `/evals-specify` (goldset block + cases + grader + config wiring per
   `docs/testing.md`).
6. **Wire the grader twin** — a SKILL.md edit without its grader twin is
   not coverage (`docs/testing.md`); the criterion lands with its grader or
   not at all.
7. **Declare the holdout** — later runs only; record the seed-window run
   ids in the criterion (`seed_window_run_ids` in the eval-criterion
   template — factory-seeded criteria only, temporal holdout still
   applies).
8. **Close the back edge** — after the change ships, re-measure recurrence
   on the holdout: drop → keep; no change after 2 cycles → retire the
   criterion (build-to-delete applies to evals too).

## Anti-patterns

- **Comment-as-criterion** — turning a review remark into a goldset case
  without reproduction. No oracle, no criterion.
- **Check-for-behavior** — linting what is actually a behavioral
  distribution; the check passes forever while the behavior rots.
- **Eval-for-decidable** — asking a model to judge what a lint decides;
  spends judgment where none is needed.
- **Random-split holdout** — leakage; confirms noise.
- **Single-run confirmation** — one run proves nothing (arXiv 2610.34938:
  of 7 measurable harness changes, 3 helped; single-run pass rates cannot
  tell you which 3).
- **Immortal criterion** — a criterion no recurrence data can ever retire.
