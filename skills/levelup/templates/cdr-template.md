---
# CDR template — full format for /levelup-specify extraction and /levelup-clarify enrichment.
# Written to .adlc/drafts/cdr/CDR-{NNN}.md, published to team-ai-directives via PR by /levelup-publish.
status: proposed  # proposed | accepted | rejected | superseded
date: YYYY-MM-DD
type: pattern  # pattern | rule | persona | example | skill | constitution
evidence: confirmed  # confirmed | inferred | unknown
source: ""  # session YYYY-MM-DD, interview, issue, commit
target-module: ""  # context_modules/rules/[domain]/[file].md or skills/[skill-name]/
descriptor: ""  # one-line "when to use" summary
revisit-when: ""  # concrete trigger or "N/A"
---

# CDR-NNN: {Title}

## Status

{proposed | accepted | rejected | superseded}

## Context Type

{pattern | rule | persona | example | skill | constitution amendment}

## Target Module

`{context_modules/rules/[domain]/[file].md or skills/[skill-name]/}`

## Descriptor

{One-line "when to use" summary.}

## Context

{What reusable pattern was identified. What problem does it solve?}

## Decision

{What should be contributed to team-ai-directives — the rule, persona,
example, or skill.}

## Rejected Alternatives

* {alternative 1} — {why it lost}
* {alternative 2} — {why it lost}

## Reason

{Why the chosen approach is the right team-wide pattern.}

## Evidence

**Session**: [brief session description]
**Branch**: [branch-name]

**Implementation Evidence**:
- {file/path}: {description}
- `{commit-sha}`: {commit message}

## Revisit When

{When this should be re-checked, or "N/A". A concrete trigger, not age.}
