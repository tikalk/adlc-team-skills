---
name: team-discover
description: Manually re-scan team context modules and produce a structured discovery table with relevance assessments. The CDR index is already in the system prompt; use this for explicit re-discovery.
---

# team-discover

## Overview

The CDR index is injected into the system prompt at session start by
team-boot. The LLM natively matches CDR descriptors against the current
task and reads full module bodies on demand. This native matching happens
per prompt without invoking this skill.

Use `/team-discover` when you want a structured discovery table with
explicit relevance assessments — for example, when starting a complex
feature or verifying which directives apply.

## Relationship to team-boot

`team-boot` is the session bootstrap: it injects the CDR index into the
system prompt via the `session_start` event hook. Per-prompt discovery
matching is **native** — the LLM matches the injected CDR index against the
current message on its own, so `team-boot` does **not** invoke this skill
as part of its bootstrap loop.

`/team-discover` is **user-invoked**: run it when you want an explicit,
structured re-scan with a relevance-rated table (complex features, audits, or
verifying which directives apply). It is not required for normal operation.

## Process

1. Extract domain, technology, patterns, and actions from the task.
2. Scan the CDR index for matching entries.
3. Assess relevance: High / Medium / Low.
4. Read full module bodies for High-relevance entries.
5. Output:

| ID | Module | Type | Descriptor | Relevance |
|----|--------|------|------------|-----------|
| CDR-2026-003 | context_modules/personas/admin.md | Persona | Admin persona | High |

6. Include PDR/ADR/ChDR matches from project indexes if relevant.
7. Include: `_Searched N CDR entries, M PDR entries, K ADR entries, C ChDR entries, J matches found._`

## Unconfigured projects

If team AI directives are not configured, invoke `team-setup`.
