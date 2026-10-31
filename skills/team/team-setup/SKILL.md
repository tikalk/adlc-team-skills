---
name: team-setup
description: Use when bootstrapping a team directives repository from scratch, cloning an existing one, pointing to a local path, or checking an existing configuration.
---

# team-setup

## Overview

`team-setup` is an interactive skill that guides you through setting up the team AI directives. It presents four modes, explains each option, confirms your choice, and executes the setup.

It is invoked in two ways:
- **User-invoked** (`/team-setup`) — anytime, to configure or check a project.
- **Model-invoked by `team-boot`** — automatically at session start when a project has no `.adlc/init-options.json` configuration (self-install), so an unconfigured project wires itself without the user knowing the command.

The skill is non-destructive: it never overwrites existing files or directories. If the target path already contains a configured team AI directives, it detects this and offers the "Already configured" mode instead.

## When to Use

- Starting a new team from scratch and need a neutral team AI directives scaffold to fill in later.
- Your team already has a directives repo on GitHub and you want to clone it locally.
- You have a local team AI directives directory already (e.g., from a previous project) and want to wire it up.
- You're unsure whether the team AI directives is already configured and want a quick check.
- When the project isn't yet wired to a team AI directives (no `.adlc/init-options.json` `team_ai_directives` field).
- Automatically via `team-boot` when it detects an unconfigured project at session start (self-install).

## Decline Handling (when model-invoked by team-boot)

When `team-boot` invokes this skill because the project is unconfigured, the
user may choose not to set up team AI directives right now. Handle decline
explicitly to avoid a re-prompt loop:

- If the user declines at mode selection, do **not** run any mode. Exit
  cleanly and tell `team-boot` the user declined.
- Offer a persistent opt-out: *"Don't ask again for this project?"* On yes
  (build mode only), write `.adlc/init-options.json` with
  `team_ai_directives: null`:
  ```bash
  echo '{"team_ai_directives": null}' > ".adlc/init-options.json"
  ```
  This marker makes `team-boot` skip setup silently on every future prompt.
- In plan/read-only mode, a persistent opt-out cannot be written — the
  decline is session-scoped only; tell `team-boot` to defer.
- Never force a mode; the setup is user-consented at every step.

## Core Process

### Goal

Set up a team AI directives using one of four modes.

### Security: Input Validation (all modes)

Before executing any mode, validate every user-supplied value (paths, URLs, team
names). These values are interpolated into shell commands; unvalidated input is
a command-injection vector.

- **Paths** (`{DEST}`, `{ABSOLUTE_PATH}`): reject if they contain any of
  `` ` ``, `$`, `;`, `|`, `&`, `(`, `)`, `<`, `>`, newline, or backslash.
  Resolve to an absolute path with `realpath`/`Resolve-Path` before use.
- **Team name**: must match `^[A-Za-z0-9 ._-]+$`. Reject anything else.
- **Clone URL** (Mode 1): must start with `https://`. Reject `file://`, `ssh://`,
  and any non-`https` scheme unless the user explicitly confirms the risk.
  Cloning runs no code from the repo, but the cloned content is read by agents
  later — only clone repositories you trust.

If any value fails validation, report which value and why, and re-ask. Never
interpolate a user value into a Python/eval source string — pass it through the
environment (see Mode 2).

**Fast path:** if `.adlc/init-options.json` already contains a valid `team_ai_directives` path, skip to Mode 4 (Already Configured) — do not re-clone, re-point, or re-scaffold.

### Modes at a Glance

| # | Mode | When | Details in |
|---|------|------|-----------|
| 1 | Clone from GitHub | team already has a directives repo | `references/mode-clone.md` |
| 2 | Point to existing local path | directives dir already exists locally | `references/mode-local.md` |
| 3 | Scaffold new empty directives | starting a team from scratch | `references/mode-scaffold.md` |
| 4 | Already configured | check / verify existing wiring | `references/mode-configured.md` |

### Mode 1: Clone from GitHub

Full walkthrough in `references/mode-clone.md`.

### Mode 2: Point to Existing Local Path

Full walkthrough in `references/mode-local.md`.

### Mode 3: Scaffold New Empty team AI directives

Full walkthrough in `references/mode-scaffold.md`.

### Mode 4: Already Configured

Full walkthrough in `references/mode-configured.md`.

### Mode Selection Flow

1. **Explore**: Present the user with four options:
   ```
   How would you like to set up team-ai-directives?

   1) Clone from GitHub — Clone an existing repository
   2) Point to existing local path — Use a team AI directives you already have
   3) Scaffold new empty team AI directives — Create a fresh neutral team AI directives
   4) Already configured — Check existing configuration
   ```

2. **Present**: For the chosen mode, explain what will happen and show details.

3. **Confirm**: Ask the user to confirm before executing.

4. **Write/Execute**: Perform the setup for the chosen mode.

### Script Entry Points (deterministic, headless use)

The Mode 1/2 validation and wiring logic has ONE home — the shared helper
scripts — and is exposed as flags so headless callers (e.g. `adlc-cli team
setup --directives <path>`) run the same checks without an LLM session:

- `scripts/bash/team-helpers.sh [--validate DIR] [--wire DIR]`
- `scripts/powershell/team-helpers.ps1 [-Validate DIR] [-Wire DIR]`

`--validate DIR` runs the Verification structure check (exit 0 when complete,
exit 1 with `MISSING:` lines when not). `--wire DIR` validates, then merges
the absolute path into the project's `.adlc/init-options.json` as
`team_ai_directives` (existing keys preserved; refuses to wire an invalid
structure). Both twins behave identically. Interactive sessions still go
through Mode Selection above; the in-session path and the headless path share
the same implementation.
### Post-Setup Configuration

After any mode completes successfully, update the project configuration:

1. Write `team_ai_directives` to `.adlc/init-options.json`
2. Verify the team AI directives is accessible by running a quick health check:
   - `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md` exists
   - `{TEAM_AI_DIRECTIVES}/.skills.json` exists and is valid JSON
3. Check the `.gitignore` convention (layout allowlist — see the Gitignore Convention Check step below).
4. Inject the project-level `AGENTS.md` directive — full command and managed-section contract in `references/post-setup-agents.md`.
5. Install MCP config — copy-once contract (seed the project's `.mcp.json`
   only when absent; an existing project file wins and is never merged into)
   in `references/post-setup-mcp.md`.

#### Gitignore Convention Check

Verify `.gitignore` follows the ADLC allowlist — a fresh `team setup` must
never leave a wholesale `.adlc/` ignore in place (it would hide the tracked
`.adlc/` artifacts the team model relies on):

1. If `.gitignore` contains a bare `.adlc/` rule, replace it (and any
   `.adlc/*` + `!.adlc/...` lines that conflict) with the R7 allowlist:
   ignore `.adlc/*`, `.adlc/evals/results/`, `.adlc/memory/*`,
   `.adlc/team-learn-report.md`, `.adlc/team-levelup-report.md`, and
   `graphify-out/`, while re-including `!.adlc/init-options.json`,
   `!.adlc/workspace.yml`, `!.adlc/drafts/`, `!.adlc/evals/`,
   `!.adlc/memory/`, `!.adlc/memory/evals/`, and
   `!.adlc/memory/evals/holdout.json`. The canonical rule list lives in the
   workspace skill's `scripts/bash/paths.sh` (`GITIGNORE_RULES_ALLOWLIST`,
   mirrored in `scripts/powershell/paths.ps1`).
2. Also verify the agent-install surface rules are ignored (`.agents/`,
   `.opencode/`, `.claude/`, `.cursor/`, `.codex/`, `.gemini/`, `.qwen/`,
   `.devin/`, `.tabnine/`, `skills-lock.json`, `.skills.json`,
   `.events.json`, `.pytest_cache/`, `.ruff_cache/`). Note that `.mcp.json`
   is deliberately **not** in this list: it is committed project source —
   human-edited, never generated — so a `.gitignore` entry for it is a defect
   to report, not a missing rule to add; its guardrail is variable *names*
   only, never literal secrets — `env` indirection is the guard, not
   `.gitignore`.
3. Never remove unrelated (non-ADLC) rules; only add missing allowlist rules.
4. Tracked legacy files keep working — the allowlist gates only untracked
   files, so no migration is required before the switch.

## Common Rationalizations

| Rationalization | Why it's wrong | What to do instead |
|---|---|---|
| "I'll just clone it manually." | Manual cloning skips the `.adlc/init-options.json` wiring, so agents won't find the team AI directives. | Use Mode 1 — it clones AND configures. |
| "I already have a team AI directives directory, I'll just use it." | The directory may be incomplete (missing required files) or not wired in config. | Use Mode 2 — it validates the structure and creates the config entry. |
| "I'll just create a few files by hand." | An incomplete scaffold breaks health checks and agent discovery. | Use Mode 3 — it creates all 10 required files with valid structure. |
| "I'm sure it's already configured." | The path may be stale, moved, or the env var may point to a deleted dir. | Use Mode 4 — it validates the existing configuration. |
| "Scaffolding without a team name is fine." | The team name is used in `README.md` — a blank name makes the team AI directives anonymous and harder to audit. | Always provide a team name in Mode 3. |

## Red Flags

- **Cloning over an existing directory** — Mode 1 refuses if the destination already exists to prevent overwrites.
- **Pointing to a non-existent path** — Mode 2 validates the path exists before proceeding.
- **Scaffolding without required dirs being writable** — Mode 3 creates directories with `mkdir -p` but will fail on permission errors; check permissions first.
- **Skipping the `team_ai_directives` config write** — without this field in `init-options.json`, agents cannot discover the team AI directives.
- **Using a relative path in `init-options.json`** — always resolve to an absolute path so the config is portable across working directories.
- **Skipping `git init` in Mode 3** — a scaffolded team AI directives without git cannot be used by `/team-levelup` (branch/commit/PR flow). Mode 3 runs `git init` automatically; if you skip it, run `git init` manually before `/team-levelup`.
- **Skipping the project-level AGENTS.md injection** — without the `<!-- TEAM_AI_DIRECTIVES START -->` managed section in the project's `AGENTS.md`, agents without event support have no session-start instruction to load team context. The `.adlc/init-options.json` config alone is insufficient — it tells skills where the team AI directives is, but nothing tells the agent to check. (For agents with event support, the session-start hook injects the orientation regardless, but AGENTS.md remains the fallback and the source of the Team Context in Use output contract.)
- **Interpolating user input into Python/shell source strings** — pass paths through the environment (`os.environ`) instead; string interpolation of `$ABSOLUTE_PATH` into a Python one-liner is a command-injection vector.
- **Cloning a non-`https://` URL in Mode 1** — reject `file://`/`ssh://`/other schemes; cloned content is read by agents later, so only clone trusted repos.
- **Skipping the MCP config install** — a project with no `.mcp.json` of its own is never seeded and loses access to team-declared MCP servers; a project that has one only loses the gap report (its file is never written either way).
- **Accepting shell metacharacters in paths or team names** — validate before interpolating into `mkdir`/`git commit`/heredocs (see Input Validation).
- **Treating user decline as an error** — declining setup is a valid outcome; exit cleanly, tell `team-boot` the user declined, and offer the `team_ai_directives: null` opt-out marker (build mode only).
- **Writing the opt-out marker in plan/read-only mode** — a persistent opt-out requires a write; in plan mode the decline is session-scoped and setup defers instead.

## Verification

- [ ] The team AI directives directory exists at the configured path.
- [ ] `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md` exists.
- [ ] `{TEAM_AI_DIRECTIVES}/context_modules/rules/` exists.
- [ ] `{TEAM_AI_DIRECTIVES}/context_modules/personas/` exists.
- [ ] `{TEAM_AI_DIRECTIVES}/context_modules/examples/` exists.
- [ ] `{TEAM_AI_DIRECTIVES}/CDR.md` exists.
- [ ] `{TEAM_AI_DIRECTIVES}/.skills.json` exists and is valid JSON.
- [ ] `.adlc/init-options.json` contains a `team_ai_directives` field with the absolute path.
- [ ] `.gitignore` follows the layout allowlist (no wholesale `.adlc/` ignore; tracked exceptions `!.adlc/init-options.json`, `!.adlc/workspace.yml`, `!.adlc/drafts/`, `!.adlc/evals/`, `!.adlc/memory/evals/holdout.json` present).
- [ ] Project-level `AGENTS.md` exists and contains the `<!-- TEAM_AI_DIRECTIVES START -->` managed section with the event-hook awareness note, fallback `team-boot` invocation, and the Team Context in Use output contract.
- [ ] (Mode 3 only) `git rev-parse --is-inside-work-tree` succeeds inside `{TEAM_AI_DIRECTIVES}`.
- [ ] Running `team-verify` (Phase 0 of team-repair) passes all 7 checks.
- [ ] All user-supplied paths/URLs/team names passed Input Validation (no shell metacharacters; clone URL is `https://`).
- [ ] Mode 2 wrote `team_ai_directives` via the environment (no `$ABSOLUTE_PATH` interpolation into Python source).
- [ ] If `{TEAM_AI_DIRECTIVES}/.mcp.json` exists: the project's `.mcp.json` was seeded from it only when the project had none — an existing project file was left untouched (never merged into or rewritten), any gap between the two was reported rather than closed, and unresolved env vars were highlighted.
- [ ] (Model-invoked by `team-boot`) a user decline exited cleanly without running any mode; the persistent opt-out was offered, and `team_ai_directives: null` was written only in build mode.

## Configuration

- `TEAM_AI_DIRECTIVES` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directives` field.
- Default fallback: `team-ai-directives/` relative to project root.
- `team-helpers.sh` / `team-helpers.ps1` — Shared scripts used for scaffolding and path resolution.

## 12-Factor Alignment

Factor XI (Directives as Code) — establishes a version-controlled team directives repository.
