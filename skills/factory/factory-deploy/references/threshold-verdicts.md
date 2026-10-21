# threshold-verdicts

Green advances, yellow holds, red rolls back — measured, never voted.

## Bands

Error rate vs frozen baseline: green ≤ +10%, yellow +10–100%, red > 2x.
p95 latency vs frozen baseline: green ≤ +20%, yellow +20–50%, red > +50%.
JS errors and error-budget burn: green ≤ 20% consumed, yellow 20–100%,
red on frozen-budget override only (explicit human order, recorded).

## Armed evaluator

The evaluator arms at canary start and fires on scheduled wake-ups only —
no continuous polling. Each wake-up reads the frozen baselines and the
unified budget, then emits one verdict: green, yellow, or red.

## Frozen baselines

Baselines freeze before the canary starts (or under a waiver with a recorded
approver — a baseline **waiver**). Mid-canary baseline edits are rejected;
a changed world means re-freeze and restart the canary, not a quiet edit.

## Scheduled wake-ups

Wake-ups arrive on the executor-provided cron binding. A missed wake-up is
neutral (evaluate at the next one); it never defaults to green.

## Outage as hold

A tracker outage surfaces as hold-and-investigate: cached gate or verdict
state is never trusted across an outage. Re-read everything when the tracker
returns.
