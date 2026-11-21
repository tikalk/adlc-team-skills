# Recurrence Ledger

Append-only validated evidence for repeated REVIEW.md findings across PRs.
Lives in `adlc-team-skills` where findings originate.

## Seed contract

This ledger is one seed input, not the only one. Full seed admissibility
(event-stream signals, reproduction rule, check-vs-eval split, authoring
threshold, temporal holdout): `eval-seed-taxonomy.md` (ADR-524). Same
contract on every row: 2 reproduced occurrences in ≥2 distinct runs before
a criterion is authored; comment-only observations are Tier-3 preferences.

## Schema (TSV, exact column order)

`PR	pass	check-item	verdict-head	run	iter	author	assoc	verified-how	verified-at	standing	tier	note`

- `verified-how`: always `live-head` in v1.
- `standing`: always `live-head-at-verification` — the marker head equaled
  the independently fetched live PR head at `verified-at` (UTC helper clock).
  Not a claim the PR still has that head. `check-verdict-head.sh` remains the
  live merge-gate authority.
- Rows are appended only by `scripts/bash/verify-recurrence.sh run` (or its PowerShell twin `scripts/powershell/verify-recurrence.ps1 run`); never edited.
  Conflicts resolve via `retire --key <PR,pass,check-item,iter> --reason`.

## Trust model

Trusted because committed here and reviewed via normal PR review. No
cryptographic tamper detection. Protection: append-only, observation-identity
idempotence (recurrence rerun-idempotency decision: duplicate = same recurrence key + same provenance with
`verified-at` excluded as confirmation metadata; reruns report DUPLICATE and
never restamp the stored row), abort on provenance conflict, single-active-writer
`ledger-writer` label gating across `references/recurrence-ledger.tsv`,
`scripts/bash/verify-recurrence.sh`, and `scripts/powershell/verify-recurrence.ps1`,
and strict branch-freshness merge rules. Git history is the audit trail. `memory.jsonl` is untouched.
