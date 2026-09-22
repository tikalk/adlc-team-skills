---
name: team-diagnose
description: Use when the team context did not appear at session start, a skill failed to trigger, the install behaves unexpectedly, or someone asks why a session ran without team rules — walks the failure chain with commands and evidence before any conclusion.
---

# team-diagnose

## Overview

Evidence-first diagnosis of broken adlc-team-skills wiring. The chain has
exactly five links, each checkable with one command — a diagnosis without
command output is a guess, and guesses get pasted into bug reports.

**Boundary:** this repo owns `.events.json` and the boot scripts' output.
The injection side (dispatchers, generated per-agent plugins) is owned by
[adlc-cli](https://github.com/tikalk/adlc-cli) — the
`docs/event-hook-contract.md` file in the adlc-team-skills repo draws the
line. Diagnose up to it, then route.

## When to Use

- Team context missing at session start (no `Team Context in Use` section).
- A rule that should have matched didn't load.
- Install behaves unexpectedly after an update.

**When NOT to use:** for application bugs unrelated to the team-context
chain, or for skill *behavior* debates (that's a goldset/eval question).

## Core Process

Run the checks **in order** — stop at the first failure, fix, re-run:

| # | Symptom area | Check (run it) | Green means |
|---|---|---|---|
| 1 | Not configured | `cat .adlc/init-options.json` | A `team_ai_directives` path that exists |
| 2 | Missing tool | `command -v jq` | jq on PATH (skills registry needs it) |
| 3 | Broken handler | `bash .agents/skills/team-boot/scripts/boot.sh` from the project root | The directives index on stdout, wrapped in `EXTREMELY_IMPORTANT` |
| 4 | Stale install | `pytest tests/unit/test_generated_artifacts_sync.py -q` (in the skills repo) or compare `skills/**/SKILL.md` vs `.agents/skills/` names | Mirror matches source |
| 5 | Injection side | Generated plugin present and loaded for the agent? | If 1–4 are green and the session still lacks context → **adlc-cli's territory** — file there with the outputs of checks 1–4 attached |

For "a rule didn't load" specifically: confirm the session began with the
index (check 3's content), then check the task actually matched the rule's
descriptor — on-demand pull is match-driven, not mind-reading.

**Whole-loop check:** `scripts/acceptance-test.sh` scratch-installs and
asserts the chain end-to-end (add `--live` for a real agent session).

## Report format

For a bug report, include: the failing check number, the command, its
verbatim output, agent name/version, and how the repo was installed
(`npx skills add` vs `adlc-cli`). No scrubbed narrative — raw
output.

## Red Flags

- Concluding before running a command — every check is one command.
- "Reinstall everything" before reading check 3's output.
- Blaming a skill's content when check 1–3 failed (config, not skills).
- Filing injection-side bugs in adlc-team-skills (check 5 routes them).

**All of these mean: run the checks, then report.**

## Verification

A diagnosis is done when:

- [ ] Checks 1–4 each ran with output captured (or 5 routed with evidence)
- [ ] The failing link is named with its command output
- [ ] The report routes to the owning repo
