# ADLC Team Skills

Agent skills for the Agentic SDLC (ADLC) workflow — architecture and team directives.

## Install

```bash
npx skills add tikalk/adlc-team-skills
```

The skills work with any agent that supports the [Agent Skills standard](https://agentskills.io), including Claude Code, Codex, Cursor, OpenCode, GitHub Copilot, Pi, and Antigravity.

## Available Skills

### Architecture (5 skills)

| Skill | Use when |
|---|---|
| `architect-init` | Reverse-engineering architecture from an existing codebase (brownfield) |
| `architect-specify` | Creating ADRs from a PRD or feature description (greenfield) |
| `architect-clarify` | Refining and validating existing ADRs |
| `architect-implement` | Generating an Architecture Description (AD.md) from accepted ADRs |
| `architect-analyze` | Checking ADR↔AD consistency and architecture quality |

All architecture skills use the Rozanski & Woods viewpoints and perspectives methodology.

### Team Directives (5 skills)

| Skill | Use when | Invocation |
|---|---|---|
| `team-boot` | Bootstrap session — load constitution, discover context | Model-invoked (auto) |
| `team-discover` | Find relevant personas, rules, examples for current task | Model-invoked (auto) |
| `team-repair` | Re-index CDR.md, .skills.json, AGENTS.md; health check + auto-fix | User-invoked |
| `team-skills` | Browse and install team skills from the directives KB | User-invoked |
| `team-setup` | Clone, scaffold, or configure a team-ai-directives KB | User-invoked |

### Workflows

**Architecture**:
```text
Brownfield: architect-init → architect-clarify → architect-implement → architect-analyze
Greenfield: architect-specify → architect-clarify → architect-implement → architect-analyze
```

**Team Directives**:
```text
First time:   team-setup (clone/scaffold) → team-boot auto-loads on every session
Health check: team-repair (or team-repair --health-only)
Repair:       team-repair (Phase 0 health check → Phase 1-8 repairs)
Skills:       team-skills (browse, install team skills)
```

## Output

Architecture skills write to `.adlc/` inside the target project:

- `.adlc/drafts/adr/ADR-{NNN}.md` — proposed/discovered ADRs (individual files)
- `.adlc/drafts/adr/adr.md` — auto-generated ADR index
- `.adlc/memory/adr/ADR-{NNN}.md` — accepted ADRs (individual files)
- `AD.md` — architecture description (in repo root)
- `.adlc/architect/` — per-view DAG artifacts (for multi-subsystem projects)

Team skills read from and write to the team-ai-directives knowledge base configured in `.adlc/init-options.json` or the `ADLC_TEAM_AI_DIRECTIVES` env var.

## OpenCode

opencode doesn't support slash commands for skills. Skills are **agent-driven**:
the agent auto-selects the right skill based on your request description.

### Install (global — recommended)

```bash
npx skills add tikalk/adlc-team-skills -a opencode -g
```

Installs to `~/.config/opencode/skills/` — opencode auto-loads these globally.

### Install (project-level)

`npx skills add -a opencode` installs to `.agents/skills/`, which opencode
doesn't scan at project level by default. Configure `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": {
    "paths": [".agents/skills"]
  }
}
```

### Usage

| Say | Skill triggered |
|---|---|
| "Reverse-engineer architecture from this codebase" | architect-init |
| "Create ADRs from this PRD" | architect-specify |
| "Refine and validate my ADRs" | architect-clarify |
| "Generate AD.md from my ADRs" | architect-implement |
| "Analyze architecture consistency" | architect-analyze |
| "Set up team directives for this project" | team-setup |
| "Check our team directives health" | team-repair --health-only |
| "Repair our CDR index" | team-repair |
| "Show me available team skills" | team-skills |

## Scripts & Templates

Skills reference bundled scripts from the skill directory:

- `team-helpers.sh` / `team-helpers.ps1` — shared path resolution, KB validation, and scaffolding (used by team-setup, team-repair, team-skills).

Architecture skills seed templates into `.adlc/templates/` on first run.

## License

MIT — see [LICENSE](./LICENSE).
