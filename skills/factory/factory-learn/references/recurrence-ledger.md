# Recurrence Ledger

Append-only validated evidence for repeated REVIEW.md findings across PRs.
Lives in `adlc-team-skills` where findings originate.

## Schema (TSV, exact column order)

`PR	pass	check-item	verdict-head	run	iter	author	assoc	verified-how	verified-at	standing	tier	note`

- `verified-how`: always `live-head` in v1.
- `standing`: always `live-head-at-verification` — the marker head equaled
  the independently fetched live PR head at `verified-at` (UTC helper clock).
  Not a claim the PR still has that head. `check-verdict-head.sh` remains the
  live merge-gate authority.
- Rows are appended only by `scripts/bash/verify-recurrence.sh run`; never edited.
  Conflicts resolve via `retire --key <PR,pass,check-item,iter> --reason`.

## Trust model

Trusted because committed here and reviewed via normal PR review. No
cryptographic tamper detection. Protection: append-only, observation-identity
idempotence (recurrence rerun-idempotency decision: duplicate = same recurrence key + same provenance with
`verified-at` excluded as confirmation metadata; reruns report DUPLICATE and
never restamp the stored row), abort on provenance conflict, strict
branch-freshness merge rules. Git history is the audit trail. `memory.jsonl` is untouched.
