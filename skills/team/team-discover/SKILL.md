---
name: team-discover
description: Manually re-scan team context modules and produce a structured discovery table with relevance assessments. The CDR index is already in the system prompt; use this for explicit re-discovery.
---

# team-discover

## Overview

The CDR index is injected into the system prompt at session start by
team-boot. The LLM natively matches CDR descriptors against the current
task and reads full module bodies on demand.

Use `/team-discover` when you want a structured discovery table with
explicit relevance assessments — for example, when starting a complex
feature or verifying which directives apply.

## Process

1. Extract domain, technology, patterns, and actions from the task.
2. Scan the CDR index for matching entries.
3. Assess relevance: High / Medium / Low.
4. Read full module bodies for High-relevance entries.
5. Output:

| ID | Module | Type | Descriptor | Relevance |
|----|--------|------|------------|-----------|
| CDR-2026-003 | context_modules/personas/admin.md | Persona | Admin persona | High |

6. Include PDR/ADR matches from project indexes if relevant.
7. Include: `_Searched N CDR entries, M PDR entries, K ADR entries, J matches found._`

## Unconfigured projects

If team AI directives are not configured, invoke `team-setup`.
