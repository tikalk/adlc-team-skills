# Agent Integrations — Commands-Dir Fallback

Fallback reference for the factory-mission executor. Skill routing is
harness-native: step prompts name skills by exact name and the dispatched
subagent resolves them through its own Skill tool — no filesystem scan.
This table covers the one case the harness cannot see: commands-based
frameworks whose integrations are command files on disk.

Sourced from the spec-kit integration registry
(`specify_cli/integrations/*/`). Update this file when new agents are added
or conventions change.

## Three patterns

| Pattern | Extension | Notes |
|---|---|---|
| **Skills-based** | `/SKILL.md` | Resolved by the harness Skill tool — not this file |
| **Commands-based** | `.md` | One file per command: `<commands_dir>/<command-name>.md` |
| **Other formats** | `.toml`, `.yaml`, `.mdc` | Format differs; the prompt may not map 1:1 — note the extension |

## Commands-based agents

| Agent | Commands dir | Extension | Notes |
|---|---|---|---|
| opencode | `.opencode/commands` | `.md` | legacy: `.opencode/command` |
| amp | `.agents/commands` | `.md` | shared namespace |
| auggie | `.augment/commands` | `.md` | multi_install_safe |
| bob | `.bob/commands` | `.md` | |
| codebuddy | `.codebuddy/commands` | `.md` | multi_install_safe |
| cline | `.clinerules/workflows` | `.md` | invoke_separator `-` |
| firebender | `.firebender/commands` | `.mdc` | |
| forge | `.forge/commands` | `.md` | |
| junie | `.junie/commands` | `.md` | |
| kilocode | `.kilocode/workflows` | `.md` | |
| kiro_cli | `.kiro/prompts` | `.md` | |
| omp | `.omp/commands` | `.md` | |
| pi | `.pi/prompts` | `.md` | |
| qodercli | `.qoder/commands` | `.md` | |
| qwen | `.qwen/commands` | `.md` | |
| shai | `.shai/commands` | `.md` | |
| tabnine | `.tabnine/agent/commands` | `.toml` | non-markdown |
| gemini | `.gemini/commands` | `.toml` | non-markdown |
| goose | `.goose/recipes` | `.yaml` | non-markdown |

## Fallback

When a step prompt targets a commands-based framework, check whether the
commands dir from the table above exists in the project; if it does, name
the command file in the step prompt. If the dir is absent, the step
executes directly — the subagent consults this file only as the fallback,
never as a skills inventory.

## Maintenance

When spec-kit adds a new integration or an agent changes its directory
convention, update this file. The executor reads it at step-list
generation, so no code changes are needed — just this reference.
