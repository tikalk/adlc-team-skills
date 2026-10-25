# release-chdr

One change record per non-obvious release. Routine green mints none.

## Trigger list

A draft mints only on this list:

- **budget**-freeze override (explicit human order shipped past an exhausted budget).
- Baseline **waiver** (canary ran on unfrozen or re-frozen baselines).
- **blackout** override (release crossed a declared blackout window).
- **rollback** (mechanical or human-ordered; the rollback itself is the rationale).

## One per run via tag key

The release tag is the idempotency key: at most one draft per release. If
two triggers fire on the same release, they fold into a single draft naming
both.

## Change-clarify governance

Drafts go through change-clarify review before promotion — the draft records
what happened and why, never a standing permission. Routine green releases
mint nothing: no draft, no log line claiming a record.

## Routine green

A release that stayed green on frozen baselines, inside budget, outside
blackout, with no rollback, produces zero drafts. Silence is the correct
audit trail.
