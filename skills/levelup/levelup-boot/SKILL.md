---
name: levelup-boot
description: Class boot for team context directives — deep-dives the CDR catalog by reading full context module bodies (personas, rules, examples) from team-ai-directives when a task matches CDR descriptors, and pairs it with decision capture via /levelup-specify. The compact CDR index is always injected by team-boot; invoke this for full-module context or when a reusable team pattern emerges.
---

# levelup-boot

## Overview

One of the five **class boots** surfaced by `team-boot`'s Class Boots
catalog. `team-boot` always injects the **compact CDR index** (ID, type,
descriptor) because team context is relevant to any task; this skill is the
deep-dive layer — it loads the **full context module bodies** from
team-ai-directives when a task matches one or more descriptors, and pairs
that with decision capture so reusable team patterns are recorded
(`/levelup-specify`) rather than staying session-local.

The team-ai-directives path comes from `.adlc/init-options.json` in the
current working directory (read it the same way `team-boot` does: do NOT
walk up parent directories, do NOT search for it).

## When to Use

Invoke when:

- A task matches one or more CDR descriptors in the injected index and the
  compact descriptor is not enough — the full rule/persona/example body is
  needed to apply it correctly.
- Multiple CDRs look relevant and they need to be compared or reconciled
  (possible rule conflict).
- The session produces a reusable team pattern: "we always do X", a rule
  that emerged, a persona or example worth sharing across the team.
- Preparing for `/levelup-clarify` or `/levelup-publish` and the current
  module bodies are needed as reference.

Do not invoke for tasks with no CDR matches — the compact index already
said `0 matched`.

## Core Process

### Step 1: Resolve the Directives Path

1. Read `.adlc/init-options.json` from the current working directory.
2. Extract `team_ai_directives`. If missing/null/absent, report that
   team-level CDR deep-dive is unavailable and continue; suggest
   `/team-setup` only if the user wants to configure directives.

### Step 2: Read Matched Module Bodies

From the injected CDR index, take the rows whose descriptors match the
current task (the same rows the Team Context in Use table listed) and read
the corresponding files under `{TEAM_AI_DIRECTIVES}/context_modules/`:

- Persona rows → `personas/<name>.md`
- Rule rows → `rules/<domain>/<name>.md`
- Example rows → `examples/<...>/<name>.md`

Read only the matched modules — not the whole tree.

### Step 3: Inject CDR Deep-Dive (Output Contract)

Emit before the task answer:

```markdown
## CDR Deep-Dive

| ID | Module | Key Directive |
|--|--|--|
| CDR-2026-021 | rules/security/sql_injection_prevention | Parameterized queries only; ... |

_Searched N CDRs, K matched._
```

- One row per matched module, with the module's operative rule condensed to
  one or two sentences (quote more fully when the rule is a hard constraint).
- `N` = total CDR index entries; `K` = modules read. K MUST equal the table
  rows shown.
- If matched modules conflict, add a **Conflicting Guidance** note and
  suggest `/team-repair --conflicts`.

### Step 4: Capture Team Patterns

| Trigger | Action |
|---------|--------|
| Reusable rule emerged, "we always do X" | CDR → suggest `/levelup-specify` |
| Team pattern proven across sessions | CDR → suggest `/levelup-specify` |
| Persona/example worth sharing | CDR → suggest `/levelup-specify` |
| CDR-class decision already in the ledger | verify capture happened; if not, re-surface |

Add/refresh rows in the **Session Decision Ledger** (Decision | Type |
Captured? | Skill) for every CDR-class decision detected this session —
including ones from before this boot was invoked. At session end, prompt to
run `/levelup-specify` for any unrecorded team patterns.

## Failure Handling

- Directives path unconfigured → note team-level deep-dive unavailable,
  continue the task; never block.
- Matched module file missing → note it in the table (`(file missing)`) and
  suggest `/team-repair`.

## Red Flags

- Reading the entire `context_modules/` tree instead of only matched modules.
- Fabricating module content — never fabricate; the table must summarize what was actually read.
- Injecting deep-dive context but ignoring capture — the pairing is the point.
- Walking up parent directories to find `.adlc/` or the directives repo.

## Verification

- [ ] CDR Deep-Dive table emitted with `_Searched N CDRs, K matched._`
      (K = modules read).
- [ ] Only matched modules were read.
- [ ] Session Decision Ledger updated with detected CDR-class decisions.
