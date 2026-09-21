---
# Lightweight EVAL draft — written by team-boot continuous capture.
# Enriched to full eval format by /evals-clarify before promotion to evals/{system}/.
id: EVAL-NNN
status: draft
name: {criterion name}
type: eval
evidence: confirmed  # confirmed | inferred | unknown
source: ""  # where the rationale came from
revisit-when: ""  # concrete trigger or "N/A"
pass-condition: ""  # binary yes/no — what passing looks like
fail-condition: ""  # binary yes/no — what failing looks like
---

# {Criterion Name}

## Context

{Why this eval criterion matters — 2-3 sentences. What failure pattern
does it catch?}

## Pass Condition

{Observable, binary yes/no. What does correct behavior look like?}

## Fail Condition

{Observable, binary yes/no. What does the failure look like?}

## Rejected Alternatives

* {alternative criterion 1} — {why it wasn't chosen}
* {alternative criterion 2} — {why it wasn't chosen}

## Reason

{Why this criterion is the right one to test.}

## Revisit When

{When this should be re-checked, or "N/A". A concrete trigger, not age.}
