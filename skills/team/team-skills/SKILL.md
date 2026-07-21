---
name: team-skills
description: Browse and install team skills from the team directives knowledge base. Use when listing, adding, or onboarding team skills to the current agent's skills directory.
disable-model-invocation: true
---

# team-skills

## Overview

Browse available skills from the team directives knowledge base and install
selected ones to the current agent's skills directory. Required skills are
installed automatically during init; this skill handles recommended, internal,
and remote skills on demand.

## When to Use

- When the user asks to browse, list, or install team skills.
- When the input names a specific skill to install.
- When extending the agent's capabilities with team-shared skills.

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
Run: specify init --team-ai-directives <path-or-url>
```

Helper scripts (relative to skill directory):

- `team-helpers.sh --json`
- `team-helpers.ps1 -Json`

### Step 1: Read Skills Manifest

Read `{REPO_ROOT}/.skills.json` (where `{REPO_ROOT}` denotes the project
root — the directory where `.adlc/` lives) and `{TEAM_AI_DIRECTIVE}/.skills.json`
(team directives manifest). Merge both, with project-root entries taking
precedence. Parse the `skills` section. Group by category:

| Category | Description | Auto-installed? |
|----------|-------------|-----------------|
| `required` | Must be installed | Yes (during init) |
| `recommended` | Suggested for the team | No |
| `internal` | Team-specific local skills | No |
| `blocked` | Rejected on install | N/A |

### Step 2: Show Available Skills

Present skills grouped by category. For each skill show:

- Name (the key, e.g. `local:./skills/github-actions`)
- Description
- Categories/tags
- Whether it's already installed (check agent skills directory)

Format:

```
Team Skills from {TEAM_AI_DIRECTIVE}

Required (auto-installed):
  [installed] team-dbt-template - DBT project templates and best practices

Recommended:
  [available] github-actions - GitHub Actions CI/CD pipeline patterns
  [available] helm-charts - Helm chart patterns for Kubernetes
  [available] crossplane - Crossplane Composition and XRD patterns
  [available] external-secrets - External Secrets Operator patterns
  [available] gke-workload-identity - GKE Workload Identity patterns

  Remote:
  [available] react-best-practices (vercel-labs) - React performance optimization
  [available] web-design-guidelines (vercel-labs) - Web interface best practices

Internal:
  [installed] team-dbt-template - DBT project templates
  [available] github-actions - GitHub Actions patterns
```

### Step 3: Install Selected Skills

If the user provided a skill name as input, install that skill directly.

If no input provided, ask the user which skills to install.

For **local skills** (`local:./skills/{name}`):

1. Locate `{TEAM_AI_DIRECTIVE}/skills/{name}/SKILL.md`
2. Determine the agent's skills directory:
   - Read `.adlc/integration.json` to get the current agent
   - Use `{agent_folder}/skills/` as the destination
3. Copy `SKILL.md` to `{skills_dir}/team-{name}/SKILL.md`
4. Update the `name` field in SKILL.md frontmatter to `team-{name}`

For **remote skills** (GitHub URLs):

1. Download SKILL.md from the `url` field in `.skills.json`
2. Save to `{skills_dir}/{name}/SKILL.md`

### Step 4: Confirm

```
Installed: team-github-actions
Location: .opencode/skills/team-github-actions/SKILL.md
Source: local:./skills/github-actions
```

### Notes

- Required skills are installed automatically during `specify init --team-ai-directives`
- This skill is for installing recommended/internal/remote skills on demand
- Skills are prefixed with `team-` to distinguish from other skills
- Blocked skills from `.skills.json` are never installed

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I'll copy SKILL.md without the `team-` prefix" | Loses traceability and collides with non-team skills | Always prefix installed skill names with `team-` |
| "Search tools will find `.adlc/init-options.json`" | Glob/find silently skip dotfile-prefixed path segments | Read the exact relative path directly |
| "Blocked skills are just strong recommendations" | `blocked` means explicitly rejected on install | Never install blocked skills |
| "Required skills need re-installing here" | They are auto-installed during init | Handle only recommended/internal/remote skills |
| "I'll skip merging the project-root manifest" | Project entries are meant to override team defaults | Merge both manifests; project-root wins conflicts |

## Red Flags

- Using glob, find, or grep to locate `.adlc/init-options.json` instead of reading the exact path.
- Installing a skill without the `team-` name prefix in its frontmatter.
- Installing a skill listed under the `blocked` category.
- Writing skills to any directory other than the agent's configured skills folder.
- Proceeding past an unset `team_ai_directive` field instead of stopping with the config message.

## Verification

- `.adlc/init-options.json` was read directly (no search tool) and `team_ai_directive` resolved to a path.
- Both `{REPO_ROOT}/.skills.json` and `{TEAM_AI_DIRECTIVE}/.skills.json` were merged; project-root entries won any conflicts.
- Each installed skill lives at `{skills_dir}/team-{name}/SKILL.md` with `name: team-{name}` in its frontmatter.
- No skill from the `blocked` category was installed.
- A confirmation block was emitted showing the installed name, on-disk location, and source.

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team-ai-directives knowledge base (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `.adlc/team-ai-directives/` relative to project root.
- `team-helpers.sh` / `team-helpers.ps1` — Shared scripts used for path resolution.

## 12-Factor Alignment

Factor XII (Team Capability) — manages team skill catalog and installation.
