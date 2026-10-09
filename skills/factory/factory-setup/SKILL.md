---
name: factory-setup
description: Use when configuring the factory tracker provider for a repo (first factory run, missing .adlc/issues-provider.yml), verifying provider wiring, or switching trackers.
---

# factory-setup

## Overview

`factory-setup` is an interactive skill that wires a repo to its issue tracker
for the factory (`factory-mission`, `factory-queue`, `factory-review`). It
asks which tracker the repo uses, then writes `.adlc/issues-provider.yml`
from the release template — provider and field mappings only, never
credentials. It is invoked three ways:

- **User-invoked** (`/factory-setup`) — anytime, to configure or check a project.
- **Model-invoked by `team-boot`** — suggested when factory skills are
  installed but no provider config resolves (self-install hint, like `team-setup`).
- **Headless via `adlc-cli factory setup`** — scripted runs; `--provider`
  pre-answers the pick so no question is asked.

The skill is non-destructive: it never overwrites an existing
`.adlc/issues-provider.yml`. If one exists, it verifies the wiring instead
(Mode 3).

## When to Use

- A tracker run halted with "no provider resolves" and named this skill.
- Setting up a new repo for factory runs (GitHub, GitLab, Linear, or Jira).
- You're unsure which tracker a repo is wired to and want a quick check.
- Switching a repo from one tracker to another (re-pick, file rewritten only
  on explicit confirmation).
- `team-boot` suggested it because factory skills are installed but no
  provider config resolves.

## Decline Handling (when model-invoked by team-boot)

The user may choose not to configure the tracker right now. Handle decline
explicitly to avoid a re-prompt loop:

- If the user declines, do **not** write anything. Exit cleanly; the decline
  is session-scoped only.
- There is deliberately **no persistent opt-out marker**: the marker would
  live in `.adlc/init-options.json`, whose schema is shared with adlc-cli —
  a tracker-specific key there is schema churn for a session preference.
  team-boot simply asks again next session.
- Never force a mode; setup is user-consented at every step. In headless
  runs there is no one to ask — `--provider` is required, else halt.

## Core Process

### Goal

Leave the repo with a committed-ready `.adlc/issues-provider.yml` carrying
the correct `provider:`, or verify the existing wiring.

### Security: Input Validation

The only free-form value this skill writes is the provider literal, which
must be exactly one of `github`, `gitlab`, `linear`, `jira` — anything else
is rejected before any write. Field-mapping values (project IDs, keys) are
written verbatim into YAML comments or values only after the user confirms
the rendered file content; never interpolate user values into shell — the
write path is file-only (`cp` template, edit the `provider:` line). If the
user pastes anything token-like (`glpat-`, `ghp_`, `xoxb-`, `sk-`), refuse
to write it and remind them credentials arrive via environment only.

**Fast path:** if `.adlc/issues-provider.yml` already exists with a valid
`provider:`, skip to Mode 3 (Already Configured) — do not re-detect,
re-pick, or rewrite.

### Modes at a Glance

| # | Mode | When | Details in |
|---|------|------|-----------|
| 1 | Detect from git remote | quick heuristic wanted (always confirmed) | `references/mode-detect.md` |
| 2 | Pick explicitly | heuristic wrong, non-git remote, or `--provider` given | `references/mode-pick.md` |
| 3 | Already configured | file exists — verify wiring | `references/mode-configured.md` |

### Mode Selection Flow

1. **Check**: read `.adlc/issues-provider.yml` in the repo root (CWD; do not
   walk up). Valid `provider:` present → Mode 3.
2. **Ask**: present the choice — detect from remote (show the remote URL) or
   pick from the four providers. In headless runs (`--provider` supplied),
   skip asking and use Mode 2 with the given literal.
3. **Confirm**: show the exact file content to be written and get explicit
   confirmation before writing (interactive runs). Headless runs write
   directly — the `--provider` flag IS the confirmation.
4. **Commit step**: copy the release template
   (`skills/factory/factory-mission/references/issues-provider.yml`) to
   `.adlc/issues-provider.yml`, set the `provider:` line, report the path,
   and remind the user to commit it. Never write credentials, never
   overwrite.

### Commit Step (shared by Modes 1–2)

1. Refuse if the target exists (route to Mode 3 instead) — unless the user
   explicitly confirmed a switch in Mode 2.
2. Copy the template; uncomment and set `provider: <literal>`.
3. Show the final content; write only on confirmation (interactive) or
   `--provider` (headless).
4. Report: path written, provider selected, reminder to commit, and that
   tracker runs will now resolve without halting.
