# ADLC Team Skills

Agent skills for the [**Twelve-Factor Agentic SDLC**](https://github.com/tikalk/agentic-sdlc-12-factors) workflow — architecture analysis and team directives management.

**How the pieces fit:**

- **[12-Factor Agentic SDLC](https://github.com/tikalk/agentic-sdlc-12-factors)** — the methodology (strategic mindset, structured planning, directives as code, traceability)
- **[team-ai-directives](https://github.com/tikalk/agentic-sdlc-team-ai-directives)** — version-controlled team knowledge base (constitution, personas, rules, CDRs)
- **This repo** — agent skills that implement the methodology

The architecture skills implement Factor IV (Structured Planning via ADRs and Architecture Descriptions) and Factor IX (Traceability). The team skills implement Factor XI (Directives as Code) — automating discovery, repair, and setup of your team-ai-directives knowledge base.

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
| `team-repair` | Re-index CDR.md, .skills.json, AGENTS.md; health check; conflict scan; freshness verification | User-invoked |
| `team-skills` | Browse and install team skills from the directives KB | User-invoked |
| `team-setup` | Clone, scaffold, or configure a team-ai-directives KB | User-invoked |

### LevelUp / CDR Lifecycle (4 skills)

Located under `skills/team/`. Contribute reusable patterns back to team-ai-directives via Context Directive Records (CDRs).

| Skill | Use when | From |
|---|---|---|
| `levelup-init` | Brownfield CDR discovery from existing codebase | `/levelup.init` |
| `levelup-specify` | Greenfield CDR extraction from a completed feature | `/levelup.specify` |
| `levelup-clarify` | Review/accept/reject/defer CDRs | `/levelup.clarify` |
| `levelup-implement` | Compile accepted CDRs into KB artifacts + draft PR | `/levelup.implement` |

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
Repair:       team-repair (re-index, health check, conflict scan, freshness verification)
Skills:       team-skills (browse, install team skills)
```

**LevelUp / CDR Lifecycle**:
```text
Brownfield: levelup-init → levelup-clarify → levelup-implement → team-repair
Greenfield: levelup-specify → levelup-clarify → levelup-implement → team-repair
```

## Output

Architecture skills write to `.adlc/` inside the target project:

- `.adlc/drafts/adr/ADR-{NNN}.md` — proposed/discovered ADRs (individual files)
- `.adlc/drafts/adr/adr.md` — auto-generated ADR index
- `.adlc/memory/adr/ADR-{NNN}.md` — accepted ADRs (individual files)
- `AD.md` — architecture description (in repo root)
- `.adlc/architect/` — per-view DAG artifacts (for multi-subsystem projects)

Team skills read from and write to the team-ai-directives knowledge base configured in `.adlc/init-options.json` or the `ADLC_TEAM_AI_DIRECTIVES` env var.

## Agent Support

Skills are **agent-driven**: the model auto-selects the right skill based on your request description. They work with any agent that supports the Agent Skills standard.

### Install

```bash
# Global install (recommended)
npx skills add tikalk/adlc-team-skills -a <agent> -g

# Project-level install
npx skills add tikalk/adlc-team-skills -a <agent>
```

Replace `<agent>` with your agent name (e.g., `claude`, `codex`, `opencode`, `gemini`, `qwen`).

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
| "Scan for rule conflicts" | team-repair --conflicts |
| "Verify directive freshness" | team-repair --freshness |
| "Show me available team skills" | team-skills |
| "Discover directives from this codebase" | levelup-init |
| "Extract lessons from this feature" | levelup-specify |
| "Review pending CDRs" | levelup-clarify |
| "Publish accepted CDRs to team KB" | levelup-implement |
| "Build one skill from a CDR" | levelup-implement --skill CDR-NNN |

## Scripts & Templates

Skills reference bundled scripts from the skill directory:

- `team-helpers.sh` / `team-helpers.ps1` — shared path resolution, KB validation, and scaffolding (used by team-setup, team-repair, team-skills).
- `levelup-helpers.sh` / `levelup-helpers.ps1` — shared CDR numbering, index generation, signal gate, and conflict detection (used by all levelup-* skills).

Architecture skills seed templates into `.adlc/templates/` on first run.

## License

MIT — see [LICENSE](./LICENSE).
