# gated-merge

Both gates green on the same SHA at the exact head — or halt.

## The check

At merge execution time, re-read both gates fresh:

- The **review-owned Merge Gate** (readiness): green at SHA S, approver recorded.
- **Deploy Gate checkpoint 3** (authorization): green at SHA S, approver recorded.

Merge proceeds only when both are green on the **same SHA** S **and** S is
the exact head under review right now. "Both gates green" with two different
SHAs is not approval — halt.

## Halt on identity mismatch

Re-read the PR head at merge time. If the head moved since either gate went
green (**head-moved**), discard all gate evidence and **re-verify** from the
verify stage at the new head. There is no shortcut: a small diff moves the
head exactly as much as a large one.

## Head-moved restart

1. Discard gate evidence for the old SHA.
2. Re-run entry checks at the new head.
3. Collect both gates green again on the new same SHA.
4. Only then merge.

## Risk-band routing (downstream of both gates, never instead)

After both gates are green on the same SHA with a recorded human, the
verdict's `**Merge risk: <low|medium|high>**` band (factory-review) routes
review effort — it never authorizes anything on its own:

- **low** → fast-lane single-review queue (ADR-360 Tier 3 depth) + batch-review grouping.
- **medium** → standard review.
- **high** → full review.

No auto-approve tier exists: a low-risk label with no recorded human halts — the band routes review effort, never approval. A single gate is never enough, and CI-green is not a gate.

## --no-merge path

When the head is already merged (pre-merged), skip the mutation but keep the
identity discipline: verify the merged SHA is the exact reviewed head. A
pre-merged head at the wrong SHA still halts.
