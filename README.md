# ADLC Team Skills

Agent skills for the [**Twelve-Factor Agentic SDLC**](https://github.com/tikalk/agentic-sdlc-12-factors) workflow — team directives management and architecture analysis.

**How the pieces fit:**

- **[12-Factor Agentic SDLC](https://github.com/tikalk/agentic-sdlc-12-factors)** — the methodology (strategic mindset, structured planning, directives as code, team capability, traceability)
- **[team-ai-directives](https://github.com/tikalk/agentic-sdlc-team-ai-directives)** — version-controlled team knowledge base (constitution, personas, rules, CDRs)
- **This repo** — agent skills that implement the methodology

## 12-Factor Alignment

These skills implement six of the Twelve Factors:

| Factor | Implemented by | How |
|---|---|---|
| **Factor III — Mission Definition** | Product skills | PRD/PDR lifecycle ensures product decisions are documented, reviewed, and traceable before execution. "Debug the spec, not the code" starts at the PRD. |
| **Factor IV — Structured Planning** | Architecture skills | ADRs and Architecture Descriptions (AD.md) provide structured planning artifacts using the Rozanski & Woods methodology. |
| **Factor IX — Traceability** | Product + Architecture skills | Every product decision traces from PDR → PRD → feature, and every architecture decision from ADR → AD → code. |
| **Factor X — Context Engineering** | Team Directives skills | `team-boot` and `team-discover` load only the relevant context modules per task, preventing context bloat. |
| **Factor XI — Directives as Code** | Team Directives + LevelUp + Product + Architecture skills | All directive lifecycles (CDR, PDR, ADR) live in version-controlled repos, not in prompt walls. Each has draft → clarify → accept → publish → analyze stages. |
| **Factor XII — Team Capability** | All 20 skills | Skills are packaged, installable, and reusable across projects and agents. Teams build a shared capability library that any member can install via `team-skills`. |

## Install

```bash
npx skills add tikalk/adlc-team-skills
```

The skills work with any agent that supports the [Agent Skills standard](https://agentskills.io), including Claude Code, Codex, Cursor, OpenCode, GitHub Copilot, Pi, and Antigravity.

## Available Skills

### Team Directives (5 skills)

| Skill | Use when | Invocation | Say |
|---|---|---|---|
| `team-boot` | Bootstrap session — load constitution, discover context | Model-invoked (auto) | — |
| `team-discover` | Find relevant personas, rules, examples for current task | Model-invoked (auto) | — |
| `team-repair` | Re-index CDR.md, .skills.json, AGENTS.md; health check; conflict scan; freshness verification | User-invoked | "Check our team directives health" (`--health-only`)<br>"Repair our CDR index"<br>"Scan for rule conflicts" (`--conflicts`)<br>"Verify directive freshness" (`--freshness`) |
| `team-skills` | Browse and install team skills from the directives KB | User-invoked | "Show me available team skills" |
| `team-setup` | Clone, scaffold, or configure a team-ai-directives KB | User-invoked | "Set up team directives for this project" |

**Team Directives workflow:**
```text
First time:   team-setup (clone/scaffold) → team-boot auto-loads on every session
Health check: team-repair (or team-repair --health-only)
Repair:       team-repair (re-index, health check, conflict scan, freshness verification)
Skills:       team-skills (browse, install team skills)
```

### LevelUp / CDR Lifecycle (5 skills)

Contribute reusable patterns back to team-ai-directives via Context Directive Records (CDRs). Session-based — no spec-kit dependency.

| Skill | Use when | From | Say |
|---|---|---|---|
| `levelup-trace` | Generate a session trace after completing work | `/levelup.trace` | "Generate a trace of this session" |
| `levelup-init` | Brownfield CDR discovery from existing codebase | `/levelup.init` | "Discover directives from this codebase" |
| `levelup-specify` | Extract CDRs from session trace + implementation evidence | `/levelup.specify` | "Extract lessons from this session" |
| `levelup-clarify` | Review/accept/reject/defer CDRs | `/levelup.clarify` | "Review pending CDRs" |
| `levelup-publish` | Compile accepted CDRs into KB artifacts + session trace + draft PR | `/levelup.publish` | "Publish accepted CDRs to team KB"<br>"Build one skill from a CDR" (`--skill CDR-NNN`)<br>"Skip trace" (`--skip-trace`) |

**LevelUp / CDR Lifecycle workflow:**
```text
Brownfield: levelup-init → levelup-clarify → levelup-publish → team-repair
Session:    levelup-trace → levelup-specify → levelup-clarify → levelup-publish → team-repair
```

### Full Lifecycle (Product → Architecture → Team KB)

```text
Product:     product-specify → product-clarify → product-implement → product-analyze
Architecture: architect-specify → architect-clarify → architect-implement → architect-analyze
Team KB:     levelup-trace → levelup-specify → levelup-clarify → levelup-publish → team-repair
```

### Product / PDR Lifecycle (6 skills)

Document product decisions as individual PDR files and compile them into a self-contained PRD.md. No spec-kit dependency.

| Skill | Use when | Say |
|---|---|---|
| `product-init` | Brownfield PDR discovery from existing codebase/docs | "Discover product decisions from this codebase" |
| `product-specify` | Greenfield PDR creation through interactive exploration | "Let's define our product strategy" |
| `product-clarify` | Refine, validate, and approve PDRs before PRD generation | "Review our product decisions" |
| `product-implement` | Generate PRD.md from accepted PDRs (DAG orchestration) | "Generate our PRD" |
| `product-analyze` | Read-only PDR↔PRD consistency and quality analysis | "Analyze our product docs" |
| `product-roadmap` | Track milestone progress from PDR status | "Show roadmap progress" |

**Product / PDR Lifecycle workflow:**
```text
Brownfield: product-init → product-clarify → product-implement → product-analyze
Greenfield: product-specify → product-clarify → product-implement → product-analyze
Roadmap:    product-roadmap (anytime)
```

### Architecture (5 skills)

| Skill | Use when | Say |
|---|---|---|
| `architect-init` | Reverse-engineering architecture from an existing codebase (brownfield) | "Reverse-engineer architecture from this codebase" |
| `architect-specify` | Creating ADRs from a PRD or feature description (greenfield) | "Create ADRs from this PRD" |
| `architect-clarify` | Refining and validating existing ADRs | "Refine and validate my ADRs" |
| `architect-implement` | Generating an Architecture Description (AD.md) from accepted ADRs | "Generate AD.md from my ADRs" |
| `architect-analyze` | Checking ADR↔AD consistency and architecture quality | "Analyze architecture consistency" |

All architecture skills use the Rozanski & Woods viewpoints and perspectives methodology.

**Architecture workflow:**
```text
Brownfield: architect-init → architect-clarify → architect-implement → architect-analyze
Greenfield: architect-specify → architect-clarify → architect-implement → architect-analyze
```

## Output

Team skills read from and write to the team-ai-directives knowledge base configured in `.adlc/init-options.json` or the `TEAM_AI_DIRECTIVE` env var.

**Team Directives skills** (inside the team-ai-directives KB):

- `AGENTS.md` — agent instructions (loading order, rules, skills)
- `CDR.md` — index of approved context contributions
- `.skills.json` — skills manifest (schema v2.0.0)
- `.mcp.json.example` — MCP servers config example (scaffold)
- `context_modules/constitution.md` — team constitution (OKF frontmatter)
- `context_modules/{rules,personas,examples}/**/*.md` — context modules
- `context_modules/{type}/index.md` — OKF progressive disclosure per concept type
- `context_modules/{type}/log.md` — OKF chronological change log per concept type
- `skills/{name}/SKILL.md` + `.skills-entry.json` — published team skills
- `traces/{branch}.md` — published session traces (`levelup-publish`)

**LevelUp skills** write to `.adlc/` inside the target project:

- `.adlc/drafts/trace.md` — session execution trace (`levelup-trace`)
- `.adlc/drafts/cdr/CDR-{NNN}.md` — proposed/discovered CDRs (individual files)
- `.adlc/drafts/cdr/cdr.md` — auto-generated CDR index
- `.adlc/init-options.json` — `team_ai_directive` path config (`team-setup`)

**Product skills** write to `.adlc/` and repo root:

- `.adlc/drafts/pdr/PDR-{NNN}.md` — proposed/discovered PDRs (individual files)
- `.adlc/drafts/pdr/pdr.md` — auto-generated PDR index
- `.adlc/memory/pdr/PDR-{NNN}.md` — accepted/completed PDRs (individual files, promoted from drafts)
- `.adlc/product/sections/{feature-area}/{section}.md` — PRD section build artifacts (`product-implement`)
- `.adlc/product/state.json` — DAG execution state (`product-implement`)
- `PRD.md` — Product Requirements Document (repo root, self-contained)

**Architecture skills** write to `.adlc/` inside the target project:

- `.adlc/drafts/adr/ADR-{NNN}.md` — proposed/discovered ADRs (individual files)
- `.adlc/drafts/adr/adr.md` — auto-generated ADR index
- `.adlc/memory/adr/ADR-{NNN}.md` — accepted ADRs (individual files)
- `AD.md` — architecture description (in repo root)
- `.adlc/architect/` — per-view DAG artifacts (for multi-subsystem projects)

## OKF Compliance

Generated context modules include [Open Knowledge Format (OKF) v0.1](https://blog.agentics.org/open-knowledge-format/) compliant frontmatter alongside custom fields.

| OKF field | Status | Source |
|-----------|--------|--------|
| `type` | ✅ | CDR context type (Rule, Persona, Example, Constitution) |
| `title` | ✅ | CDR title |
| `description` | ✅ | CDR descriptor |
| `resource` | ✅ | Relative path to the artifact file |
| `tags` | ✅ | Context type tag |
| `timestamp` | ✅ | ISO 8601 datetime of creation/modification |

**Custom fields** (coexist with OKF fields in same frontmatter):
`id`, `cdr_ref`, `created`, `modified`, `verified`, `age_days`, `evidence`

**Directory structure** — OKF concepts:
- `context_modules/{type}/index.md` — progressive disclosure per concept type
- `context_modules/{type}/log.md` — chronological change history per concept type
- Cross-links between related concepts (e.g., rule → example, rule → persona)

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

## License

MIT — see [LICENSE](./LICENSE).
