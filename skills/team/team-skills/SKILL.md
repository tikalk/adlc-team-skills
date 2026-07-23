---
name: team-skills
description: Browse and install team skills from the team AI directives. Use when listing, adding, or onboarding team skills to the current agent's skills directory. Supports --all to install every default and external skill at once.
disable-model-invocation: true
---

# team-skills

## Overview

Browse available skills from the team AI directives and install
selected ones to the current agent's skills directory. Use `--all` to
install every `default` and `external` skill in one pass. Skills are
installed under their **original names** (no prefix) so they stay in sync
with the manifest.

## When to Use

- When the user asks to browse, list, or install team skills.
- When the input names a specific skill to install.
- When extending the agent's capabilities with team-shared skills.
- When `team-setup` delegates `/team-skills --all` after initial configuration.

```text
$ARGUMENTS
```

## Core Process

### Setup

Read the file `.adlc/init-options.json` directly. Do NOT use glob, find,
or any file-search tool to locate it — search tools may silently skip
dotfile-prefixed path segments. Read the file at the exact relative path
`.adlc/init-options.json` from the current working directory.

If that read fails (file not found), walk up parent directories by reading
`../.adlc/init-options.json`, then `../../.adlc/init-options.json`,
and so on — up to 4 levels. Stop at the first successful read.

From the JSON, extract the `team_ai_directive` field:

```json
{
  "team_ai_directive": "/path/to/team-ai-directives"
}
```

If `team_ai_directive` is not set, STOP:

```
Team AI directives not configured.
Run: /team-setup
```

Helper scripts (relative to skill directory):

- `team-helpers.sh --json`
- `team-helpers.ps1 -Json`

### Step 1: Read Skills Manifest

Read `{REPO_ROOT}/.skills.json` (where `{REPO_ROOT}` denotes the project
root — the directory where `.adlc/` lives) and `{TEAM_AI_DIRECTIVE}/.skills.json`
(team directives manifest). Merge both, with project-root entries taking
precedence. Parse the manifest sections (schema v2.0.0):

| Section | Description | Installed by `--all`? |
|---------|-------------|-----------------------|
| `default` | Local skills (in `skills/{name}/`) auto-installed during setup | Yes |
| `external` | Remote skills fetched by URL, installed on demand | Yes |
| `blocked` | Rejected — must never be installed | Never |

### Step 2: Show Available Skills

Present skills grouped by section. For each skill show:

- Name (the key, e.g. `github-actions` for local, `react-best-practices` for external)
- Description
- Whether it's already installed (check agent skills directory)

Format:

```
Team Skills from {TEAM_AI_DIRECTIVE}

Default (local, installed by --all):
  [installed] dbt-template - DBT project templates and best practices
  [available] github-actions - GitHub Actions CI/CD pipeline patterns
  [available] helm-charts - Helm chart patterns for Kubernetes
  [available] crossplane - Crossplane Composition and XRD patterns
  [available] external-secrets - External Secrets Operator patterns
  [available] gke-workload-identity - GKE Workload Identity patterns

External (remote, installed by --all):
  [available] react-best-practices - React performance optimization
  [available] web-design-guidelines - Web interface best practices
```

### Step 3: Install Selected Skills

Determine the install target from the arguments:

- **`--all`**: Install every `default` skill **and** every `external` skill,
  skipping anything in `blocked` and anything already installed.
- **A skill name**: Install that one skill directly.
- **No input**: Ask the user which skills to install.

Determine the agent's skills directory:
1. Read `.adlc/integration.json` to get the current agent
2. Use `{agent_folder}/skills/` as the destination

Install under the **original name** (no prefix), frontmatter `name` unchanged:

For **local skills** (`default` list — names map to `skills/{name}/`):

1. Locate `{TEAM_AI_DIRECTIVE}/skills/{name}/SKILL.md`
2. Copy `SKILL.md` to `{skills_dir}/{name}/SKILL.md`

For **external skills** (`external` map — entries have a `url`):

1. Download `SKILL.md` from the entry's `url` field
2. Save to `{skills_dir}/{name}/SKILL.md`

Never install any skill listed in `blocked`. Skip skills already present at the
destination (report them as `[installed]`).

### Step 4: Confirm

```
Installed: github-actions
Location: .opencode/skills/github-actions/SKILL.md
Source: default (local:./skills/github-actions)
```

### Notes

- Default skills are installed via `--all`, typically invoked by `team-setup`
  after initial configuration or run manually at any time.
- Skills are installed under their original names — no `team-` prefix — so the
  on-disk name matches the manifest key.
- Skills from the `blocked` list are never installed.
- External skills are fetched over HTTPS from the URL in the manifest.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I'll add a `team-` prefix to installed skills" | Diverges the on-disk name from the manifest key, breaking lookups | Install under the original name; frontmatter `name` stays unchanged |
| "Search tools will find `.adlc/init-options.json`" | Glob/find silently skip dotfile-prefixed path segments | Read the exact relative path directly |
| "Blocked skills are just strong recommendations" | `blocked` means explicitly rejected on install | Never install blocked skills |
| "Default skills already auto-installed elsewhere" | Only `--all` (via team-setup or manual) installs them | Run `/team-skills --all` to onboard the default set |
| "I'll skip merging the project-root manifest" | Project entries are meant to override team defaults | Merge both manifests; project-root wins conflicts |

## Red Flags

- Using glob, find, or grep to locate `.adlc/init-options.json` instead of reading the exact path.
- Renaming a skill or adding a `team-` prefix on install — install under the original name so it matches the manifest.
- Installing a skill listed under the `blocked` section.
- Writing skills to any directory other than the agent's configured skills folder.
- Proceeding past an unset `team_ai_directive` field instead of stopping with the config message.
- Fetching an external skill over a non-HTTPS URL.

## Verification

- `.adlc/init-options.json` was read directly (no search tool) and `team_ai_directive` resolved to a path.
- Both `{REPO_ROOT}/.skills.json` and `{TEAM_AI_DIRECTIVE}/.skills.json` were merged; project-root entries won any conflicts.
- Each installed skill lives at `{skills_dir}/{name}/SKILL.md` with its original `name` in frontmatter (no prefix).
- No skill from the `blocked` section was installed.
- `--all` installed every `default` and `external` skill (skipping `blocked` and already-installed).
- A confirmation block was emitted showing the installed name, on-disk location, and source.

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `team-ai-directives/` relative to project root.
- `team-helpers.sh` / `team-helpers.ps1` — Shared scripts used for path resolution.

## 12-Factor Alignment

Factor XII (Team Capability) — manages team skill catalog and installation.
