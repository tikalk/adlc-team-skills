# Agent Integrations — Command & Skills Discovery

Reference table for the `mission-brief` executor. Lists every known agent
integration and where its commands/skills live in a project. Used at
generation time (Phase 4) to discover which directories actually exist in the
current project and record them in `.mission-state.json` under
`discovered.skills_dirs` and `discovered.commands_dirs`.

Sourced from the spec-kit integration registry
(`specify_cli/integrations/*/`). Update this file when new agents are added or
conventions change.

## Three patterns

| Pattern | Extension | Notes |
|---|---|---|
| **Skills-based** | `/SKILL.md` | One directory per skill: `<skills_dir>/<skill-name>/SKILL.md` |
| **Commands-based** | `.md` | One file per command: `<commands_dir>/<command-name>.md` |
| **Other formats** | `.toml`, `.yaml`, `.mdc` | Format differs; the prompt may not map 1:1 — note the extension |

## Skills-based agents

| Agent | Skills dir | Notes |
|---|---|---|
| claude | `.claude/skills` | multi_install_safe |
| cursor | `.cursor/skills` | multi_install_safe |
| codex | `.agents/skills` | multi_install_safe |
| agy | `.agents/skills` | shared with codex/zed |
| zed | `.agents/skills` | shared |
| copilot | `.github/skills` | also `.github/agents` (`.agent.md`) |
| devin | `.devin/skills` | |
| kimi | `.kimi-code/skills` | |
| lingma | `.lingma/skills` | |
| rovodev | `.rovodev/skills` | |
| trae | `.trae/skills` | |
| vibe | `.vibe/skills` | |
| zcode | `.zcode/skills` | |
| hermes | `~/.hermes/skills` | home-level, not project-level |

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

## Discovery algorithm (executor, at generation time)

1. Read this table.
2. For each **skills dir**, check if `<project_root>/<dir>` exists and contains
   at least one `<name>/SKILL.md`. If yes, add `dir` to
   `discovered.skills_dirs`.
3. For each **commands dir**, check if `<project_root>/<dir>` exists and
   contains at least one matching file (any `.md`/`.toml`/`.yaml`/`.mdc`).
   If yes, add `dir` + its extension to `discovered.commands_dirs`.
4. For **home-level** dirs (e.g. `~/.hermes/skills`), expand `~` and check
   existence.
5. Record results in `.mission-state.json.discovered`:
   ```json
   "discovered": {
     "skills_dirs": [".claude/skills"],
     "commands_dirs": [{"dir": ".opencode/commands", "ext": ".md"}]
   }
   ```
6. If `discovered` is empty, the delegation prompt falls back to instructing
   the subagent to consult this reference file, or to proceed with direct
   execution (path 3 of the three-path delegation prompt).

## Maintenance

When spec-kit adds a new integration or an agent changes its directory
convention, update this file. The executor reads it at generation time, so no
code changes are needed — just this reference.
