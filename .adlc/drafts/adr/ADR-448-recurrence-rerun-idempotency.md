---
# Lightweight ADR draft — written by the capture skill (/architect-specify).
# Enriched to full MADR format by /architect-clarify before promotion to docs/adlc/memory/.
status: accepted
date: 2026-11-11
decision-makers: [User, AI collaboration]
sub-system: Factory (factory-learn / recurrence evidence)
type: decision
evidence: confirmed
source: "Work item #90 recurrence idempotency architecture decision (session 2026-11-11). Approved Option A over Option B. Implements verified-at-as-metadata: recurrence key + provenance columns define duplicate identity; verified-at excluded."
revisit-when: "Recurrence ledger schema changes, observation identity redefined, or a second provenance-conflict class emerges"
---

# ADR-448: Repeated live-head verification is an idempotent duplicate (verified-at is metadata)

## Context

Work item #90 introduced `skills/factory/factory-learn/scripts/verify-recurrence.sh` with the contract
"full-row equality defines idempotency". The implementation stamps `verified-at` with the current UTC
second on every `run`, so two consecutive `run` operations for the same live-head observation produce
rows that differ in `verified-at`. The run-path locked append used byte-exact matching, classifying the
second run as a provenance conflict (exit 2) instead of a duplicate (exit 0). The same-commit test
`test_run_appends_valid_live_head` requires rerun success with no duplicate row — the test is the
specification, the contract text was imprecise.

## Decision

A repeated `run` for the same recurrence key and same live-head observation is an **idempotent
duplicate**, even when `verified-at` differs. `verified-at` is observation metadata (when this host
confirmed), not observation identity. Duplicate reruns exit 0, leave ledger bytes unchanged, report a
distinct `DUPLICATE` result, and never restamp the stored row.

Duplicate identity: same recurrence key `(PR, pass, check-item, iter)` = TSV columns `(0,1,2,5)`,
plus same provenance columns `(3,4,6,7,8,10,11,12)` with `verdict-head` (col 3) compared
case-insensitively and `verified-at` (col 9) excluded. Any other provenance difference on the same
key remains a fail-closed provenance conflict (exit 2, ledger unchanged, no VALID output).

## Rejected Alternatives

* Option B (strict full-row equality; rerun = conflict, fix the test) — rejected: makes `run`
  single-shot per key, forces a human `retire` (evidence deletion) just to re-verify, and contradicts
  the test-authored specification. Retries and CI re-runs must be safe.
* Restamping the stored row with the newer `verified-at` — rejected: falsifies first-observation
  evidence and violates the aggregate ORIG no-restamp rule.

## Reason

Two timestamps on the same fact are two true attestations of one observation, not conflicting
provenance. This mirrors the existing aggregate ORIG path (byte-identical original → DUPLICATE,
restamped companion suppressed) and keeps append-only + fail-closed intact: conflicts still abort
on any `who/what/how` difference; only `when` is excluded.

## Revisit When

Recurrence ledger schema changes, observation identity is redefined, or a second
provenance-conflict class emerges.
