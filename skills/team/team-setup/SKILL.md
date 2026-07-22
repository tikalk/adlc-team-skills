---
name: team-setup
description: Interactive setup of team AI directives. Use when bootstrapping a team directives repository from scratch, cloning an existing one, pointing to a local path, or checking an existing configuration.
disable-model-invocation: true
---

# team-setup

## Overview

`team-setup` is a user-invoked interactive skill that guides you through setting up the team AI directives. It presents four modes, explains each option, confirms your choice, and executes the setup.

The skill is non-destructive: it never overwrites existing files or directories. If the target path already contains a configured team AI directives, it detects this and offers the "Already configured" mode instead.

## When to Use

- Starting a new team from scratch and need a neutral team AI directives scaffold to fill in later.
- Your team already has a directives repo on GitHub and you want to clone it locally.
- You have a local team AI directives directory already (e.g., from a previous project) and want to wire it up.
- You're unsure whether the team AI directives is already configured and want a quick check.
- After `specify init` when `--team-ai-directives` wasn't provided.

## Core Process

### Goal

Set up a team AI directives using one of four modes.

### Mode 1: Clone from GitHub

Clone an existing team-ai-directives repository from GitHub.

**Explore**:
1. Ask the user for the GitHub repository URL (default: `https://github.com/tikalk/agentic-sdlc-team-ai-directives`)
2. Ask where to clone it (default: `./team-ai-directives`)
3. Check that the destination does not already exist

**Present**:
Show the user:
- Source URL
- Destination path
- Estimated size (from remote repo info if available)

**Confirm**:
```
Clone team-ai-directives from {URL} to {DEST}?
[Y/n]
```

**Write/Execute**:
```bash
git clone "{URL}" "{DEST}"
```

After clone, verify the team AI directives structure exists:
- `{DEST}/context_modules/constitution.md`
- `{DEST}/context_modules/rules/`
- `{DEST}/context_modules/personas/`
- `{DEST}/context_modules/examples/`
- `{DEST}/CDR.md`
- `{DEST}/.skills.json`

### Mode 2: Point to Existing Local Path

Wire an existing local team-ai-directives directory into the project.

**Explore**:
1. Ask the user for the path to their existing team AI directives directory
2. Validate the path exists
3. Validate the team AI directives structure (same checks as Mode 1 post-clone)
4. If validation fails, explain what's missing and ask the user to fix it or choose a different mode

**Present**:
Show the user:
- Resolved absolute path
- Validation results (which required files/dirs exist and which are missing)

**Confirm**:
```
Use existing team-ai-directives at {ABSOLUTE_PATH}?
[Y/n]
```

**Write/Execute**:
Update the project's `.adlc/init-options.json` to set the `team_ai_directive` field to the resolved path.

```bash
# Read existing or create new
if [[ -f ".adlc/init-options.json" ]]; then
  CONFIG=$(cat ".adlc/init-options.json")
else
  CONFIG="{}"
fi

# Update or add team_ai_directive field
echo "$CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
config['team_ai_directive'] = '$ABSOLUTE_PATH'
print(json.dumps(config, indent=2))
" > ".adlc/init-options.json"
```

### Mode 3: Scaffold New Empty team AI directives

Create a fresh, neutral team AI directives at a specified path.

**Explore**:
1. Ask the user where to create the team AI directives (default: `./team-ai-directives`)
2. Ask for the team name
3. Check the destination does not already exist or is empty

**Present**:
Show the user the 10 files that will be created:

| # | File | Purpose |
|---|------|---------|
| 1 | `README.md` | Getting started documentation |
| 2 | `AGENTS.md` | Agent instructions (loading order, rules, skills) |
| 3 | `CDR.md` | Empty CDR index table |
| 4 | `.skills.json` | Empty skills manifest (schema v2.0.0) |
| 5 | `.mcp.json.example` | Empty MCP servers config example |
| 6 | `context_modules/constitution.md` | Placeholder constitution (OKF frontmatter) — fill via `/team-constitution` |
| 7 | `context_modules/index.md` | OKF toplevel index linking sub-directories |
| 8 | `context_modules/rules/index.md` | OKF progressive disclosure (rules) |
| 9 | `context_modules/rules/.gitkeep` | Rules directory placeholder |
| 10 | `context_modules/personas/index.md` | OKF progressive disclosure (personas) |
| 11 | `context_modules/personas/.gitkeep` | Personas directory placeholder |
| 12 | `context_modules/examples/index.md` | OKF progressive disclosure (examples) |
| 13 | `context_modules/examples/.gitkeep` | Examples directory placeholder |
| 14 | `skills/.gitkeep` | Skills directory placeholder |

**Confirm**:
```
Scaffold empty team-ai-directives at {DEST} with team name "{TEAM_NAME}"?
[Y/n]
```

**Write/Execute**:

Create directory structure:
```bash
mkdir -p "{DEST}/context_modules/rules"
mkdir -p "{DEST}/context_modules/personas"
mkdir -p "{DEST}/context_modules/examples"
mkdir -p "{DEST}/skills"
```

Create `{DEST}/README.md`:
```markdown
# {TEAM_NAME} Team AI Directives

Team AI directives repository for {TEAM_NAME}.

## Getting Started

1. Initialize a project with this directives repository:
   ```
   specify init my-project --team-ai-directives ./path/to/this/dir
   ```

2. Add context modules to `context_modules/` (rules, personas, examples).

3. Add skills to `skills/`.

4. Update `CDR.md` as context modules are approved.

See [Agentic SDLC Spec Kit](https://github.com/tikalk/agentic-sdlc-spec-kit) for full documentation.
```

Create `{DEST}/AGENTS.md`:
```markdown
# Agent Instructions

## Structure

- `context_modules/constitution.md` — Team constitution
- `context_modules/rules/` — Team rules and workflows
- `context_modules/personas/` — Team personas
- `context_modules/examples/` — Team examples
- `skills/` — Team skills
- `CDR.md` — Context Directive Records

## Loading Order

1. Load constitution.md first
2. Load relevant rules for the current task
3. Load relevant personas for the current task
4. Load relevant examples for the current task

## Using Skills

Skills are located in the `skills/` directory. Browse available skills using `team-skills` and install them as needed.

## CDR.md

The CDR.md file tracks approved context contributions. Update it when adding new context modules.
```

Create `{DEST}/CDR.md`:
```markdown
# Context Directive Records

Context Directive Records (CDRs) track decisions about contributing context modules (rules, personas, examples, skills) to team-ai-directives.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|

**Stats**: 0 entries | Last Updated: {TODAY}
```

Create `{DEST}/.skills.json`:
```json
{
  "schema_version": "2.0.0",
  "default": [],
  "skills": {},
  "external": {}
}
```

Create `{DEST}/.mcp.json.example`:
```json
{
  "mcpServers": {}
}
```

Create `{DEST}/context_modules/constitution.md`:
```markdown
---
type: Constitution
title: "{TEAM_NAME} Constitution"
description: "Team-wide principles and governance"
resource: ./context_modules/constitution.md
tags: [constitution]
timestamp: {TODAY}T00:00:00Z
---

# {TEAM_NAME} Constitution

No team-wide principles defined yet. Add principles as they are established.
```

Create OKF-compliant `index.md` files for progressive disclosure:

Create `{DEST}/context_modules/index.md`:
```markdown
# Context Modules

| Directory | Description |
|-----------|-------------|
| [rules/](rules/index.md) | Team rules and workflows |
| [personas/](personas/index.md) | Team personas |
| [examples/](examples/index.md) | Team examples |
```

Create `{DEST}/context_modules/rules/index.md`:
```markdown
# Rules

No rules defined yet. Use `/levelup-specify` to create rules via CDRs.
```

Create `{DEST}/context_modules/personas/index.md`:
```markdown
# Personas

No personas defined yet. Use `/levelup-specify` to create personas via CDRs.
```

Create `{DEST}/context_modules/examples/index.md`:
```markdown
# Examples

No examples defined yet. Use `/levelup-specify` to create examples via CDRs.
```

Create gitkeep files:
```bash
touch "{DEST}/context_modules/rules/.gitkeep"
touch "{DEST}/context_modules/personas/.gitkeep"
touch "{DEST}/context_modules/examples/.gitkeep"
touch "{DEST}/skills/.gitkeep"
```

Initialize git (required for `/levelup-publish` branch/commit/PR flow):
```bash
cd "{DEST}" && git init && git add -A && git commit -m "Initial team-ai-directives scaffold"
```

**Follow-up**: The scaffolded `context_modules/constitution.md` is a placeholder ("No team-wide principles defined yet"). Tell the user:

```text
Scaffold complete. Run /team-constitution next to establish your team's
principles interactively — it detects the placeholder and walks you through
creating the real constitution.
```

After scaffold, run the post-setup configuration (same as Mode 4 below).

### Mode 4: Already Configured

The team AI directives is already configured. Verify and report status.

**Explore**:
1. Check `.adlc/init-options.json` for `team_ai_directive` field
2. If found, resolve the path and validate the team AI directives structure
3. Check `TEAM_AI_DIRECTIVE` env var as fallback
4. Check default path `team-ai-directives` as final fallback

**Present**:
Show the user the resolved team AI directives path and validation results.

**Write/Execute**:
No writes needed — the team AI directives is already configured.

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

### Post-Setup Configuration

After any mode completes successfully, update the project configuration:

1. Write `team_ai_directive` to `.adlc/init-options.json`
2. Verify the team AI directives is accessible by running a quick health check:
   - `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md` exists
   - `{TEAM_AI_DIRECTIVE}/.skills.json` exists and is valid JSON
3. Inject the project-level `AGENTS.md` directive so agents auto-invoke `team-boot` at session start:

```bash
# Bash
bash "$(dirname "$0")/team-helpers.sh" --inject-agents "{PROJECT_ROOT}"

# PowerShell
pwsh "$(Split-Path $PSCommandPath -Parent)/team-helpers.ps1" -InjectAgents "{PROJECT_ROOT}"
```

This creates or updates the project's `AGENTS.md` with a managed section (between `<!-- TEAM_AI_DIRECTIVES START -->` and `<!-- TEAM_AI_DIRECTIVES END -->` markers) containing:

- **Strict Compliance** directive: "You MUST invoke the `team-boot` skill BEFORE responding to any task or question"
- **Anti-pattern counter-rationalizations** (same as spec-kit's `agent-context` extension)
- **Team Constitution** reference path
- **team-discover** invocation guidance

This is the skills-based equivalent of the spec-kit's `update-agent-context.sh` — without it, the agent has no session-start instruction to invoke `team-boot`, and the team AI directives repository remains invisible until manually loaded. The section is idempotent: re-running `team-setup` or `team-repair` updates the section in place without duplicating content.

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
- **Skipping the `team_ai_directive` config write** — without this field in `init-options.json`, agents cannot discover the team AI directives.
- **Using a relative path in `init-options.json`** — always resolve to an absolute path so the config is portable across working directories.
- **Skipping `git init` in Mode 3** — a scaffolded team AI directives without git cannot be used by `/levelup-publish` (branch/commit/PR flow). Mode 3 runs `git init` automatically; if you skip it, run `git init` manually before `/levelup-publish`.
- **Skipping the project-level AGENTS.md injection** — without the `<!-- TEAM_AI_DIRECTIVES START -->` managed section in the project's `AGENTS.md`, agents have no session-start instruction to invoke `team-boot`. The `.adlc/init-options.json` config alone is insufficient — it tells skills where the team AI directives is, but nothing tells the agent to check skills before responding.

## Verification

- [ ] The team AI directives directory exists at the configured path.
- [ ] `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md` exists.
- [ ] `{TEAM_AI_DIRECTIVE}/context_modules/rules/` exists.
- [ ] `{TEAM_AI_DIRECTIVE}/context_modules/personas/` exists.
- [ ] `{TEAM_AI_DIRECTIVE}/context_modules/examples/` exists.
- [ ] `{TEAM_AI_DIRECTIVE}/CDR.md` exists.
- [ ] `{TEAM_AI_DIRECTIVE}/.skills.json` exists and is valid JSON.
- [ ] `.adlc/init-options.json` contains a `team_ai_directive` field with the absolute path.
- [ ] Project-level `AGENTS.md` exists and contains the `<!-- TEAM_AI_DIRECTIVES START -->` managed section with the `team-boot` strict-compliance directive.
- [ ] (Mode 3 only) `git rev-parse --is-inside-work-tree` succeeds inside `{TEAM_AI_DIRECTIVE}`.
- [ ] Running `team-verify` (Phase 0 of team-repair) passes all 7 checks.

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `team-ai-directives/` relative to project root.
- `team-helpers.sh` / `team-helpers.ps1` — Shared scripts used for scaffolding and path resolution.

## 12-Factor Alignment

Factor XI (Directives as Code) — establishes a version-controlled team directives repository.
