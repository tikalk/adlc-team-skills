# ADLC Team Skills

Agent skills for the [Twelve-Factor Agentic SDLC](https://github.com/tikalk/agentic-sdlc-12-factors) workflow — team directives management, product decision records, and architecture analysis.

**Relationship to 12 factors:** This repo is referenced from [team-ai-directives](https://github.com/tikalk/agentic-sdlc-team-ai-directives) and together with the 12-factor methodology forms the Foundation layer of the ADLC stack. The skills implement Factors III, IV, IX, X, XI, and XII.

## Quickstart

```bash
# Install skills globally
npx skills add tikalk/adlc-team-skills -a claude -g

# Or for a specific project
npx skills add tikalk/adlc-team-skills -a claude
```

Works with any agent that supports the [Agent Skills standard](https://agentskills.io) — Claude Code, Codex, OpenCode, Cursor, GitHub Copilot, and others.

**Before anything else:** Run `team-setup` once to configure the team AI directives path, or ensure `.adlc/init-options.json` is present.

---

## #1: The Agent Doesn't Know How Your Team Works

**Factor X — Context Engineering. Factor XI — Directives as Code. Factor XII — Team Capability.**

An agent assigned to your repo has no idea about your team's coding conventions, review standards, architectural principles, or product strategy. Without structured context injection, every session starts from zero — and every session drifts.

`team-boot` loads the team constitution, PDR and ADR indexes, and relevant context modules automatically on session start. `team-discover` retrieves the specific personas, rules, and examples relevant to the current task. No prompt walls, no manual context dumping.

```
team-boot      → auto-loads constitution + PDR/ADR indexes + discover
team-discover  → fetches rules/personas/examples for the current task
team-constitution → create or amend the team constitution interactively
team-repair    → re-index CDR.md, scan for conflicts, verify freshness
```

---

## #2: Lessons From Sessions Evaporate

**Factor IX — Traceability. Factor XI — Directives as Code. Factor XII — Team Capability.**

Every agent session surfaces patterns, gotchas, and team knowledge. Without a structured capture mechanism, that knowledge is lost when the session ends.

LevelUp skills capture session traces, extract reusable Context Directive Records (CDRs), and publish them back to the team AI directives repository as skills, rules, personas, or examples — creating a closed feedback loop where every session enriches the next.

```
levelup-trace    → generate session execution trace
levelup-specify  → extract CDRs from trace + evidence
levelup-clarify  → review, accept, reject, or defer CDRs
levelup-publish  → compile into team directives + draft PR
```

---

## #3: Product Decisions Are Invisible

**Factor III — Mission Definition.**

Without documented product decisions, every implementation session re-derives (or misinterprets) the product's intent. Feature scope, target audience, business constraints, and trade-offs are locked in someone's head or buried in a Slack thread.

Product skills capture product decisions as individual PDR files, refine them through a clarification workflow, and compile them into a self-contained PRD.md. The `product-roadmap` skill tracks milestone progress from decisions through execution, evidence, and gates — with live issue counting via MCP.

```
product-init      → discover PDRs from existing codebase/docs (brownfield)
product-specify   → create PDRs interactively (greenfield)
product-clarify   → refine, validate, and approve PDRs
product-implement → generate PRD.md from accepted PDRs
product-analyze   → check PDR↔PRD consistency
product-roadmap   → track milestone progress (decisions + issues + code + gates)
```

---

## #4: Architecture Decisions Are Invisible

**Factor IV — Structured Planning.**

Unrecorded architecture decisions produce inconsistent implementations, duplicated effort, and systems that are harder to maintain or evolve. The adage "the architecture is in the code" is only true if you're willing to reverse-engineer every decision from the source.

Architecture skills capture Architectural Decision Records (ADRs) and compose them into a unified Architecture Description (AD) using the Rozanski & Woods viewpoints methodology.

```
architect-init      → reverse-engineer ADRs from codebase (brownfield)
architect-specify   → create ADRs from PRD or feature description (greenfield)
architect-clarify   → refine and validate ADRs
architect-implement → generate AD.md from accepted ADRs
architect-analyze   → check ADR↔AD consistency and quality
```

---

## Reference

### Team Directives (6 skills)

#### Model-invoked

- **`team-boot`** — Bootstrap session: load constitution, PDR/ADR indexes, discover context. Auto-triggered on session start.
- **`team-discover`** — Fetch relevant personas, rules, examples, PDRs, and ADRs for the current task. Auto-triggered.

#### User-invoked

- **`team-constitution`** — Create or amend the team constitution interactively. Say "Create our team constitution" or "Amend our team principles."
- **`team-repair`** — Re-index CDR.md, .skills.json, AGENTS.md; health check; conflict scan; freshness verification. Say "Check our team directives health" (`--health-only`), "Repair our CDR index," or "Scan for rule conflicts" (`--conflicts`).
- **`team-skills`** — Browse and install team skills from the team AI directives. Say "Show me available team skills."
- **`team-setup`** — Clone, scaffold, or configure a team AI directives repository. Say "Set up team directives for this project."

### LevelUp / CDR Lifecycle (5 skills)

All user-invoked. Capture and publish reusable patterns to team-ai-directives.

- **`levelup-trace`** — Generate a session execution trace after completing work. Say "Generate a trace of this session."
- **`levelup-init`** — Brownfield CDR discovery from an existing codebase. Say "Discover directives from this codebase."
- **`levelup-specify`** — Extract CDRs from session trace and implementation evidence. Say "Extract lessons from this session."
- **`levelup-clarify`** — Review, accept, reject, or defer pending CDRs. Say "Review pending CDRs."
- **`levelup-publish`** — Compile accepted CDRs into team directives artifacts, session trace, and draft PR. Say "Publish accepted CDRs" or "Build one skill from a CDR" (`--skill CDR-NNN`).

### Product / PDR Lifecycle (6 skills)

All user-invoked. Document product decisions as individual PDRs and compile into a self-contained PRD.md.

- **`product-init`** — Brownfield PDR discovery from existing codebase and documentation. Say "Discover product decisions from this codebase."
- **`product-specify`** — Greenfield PDR creation through interactive product exploration. Say "Let's define our product strategy."
- **`product-clarify`** — Refine, validate, and approve PDRs before PRD generation. Say "Review our product decisions."
- **`product-implement`** — Generate PRD.md from accepted PDRs (multi-agent DAG orchestration). Say "Generate our PRD."
- **`product-analyze`** — Read-only PDR↔PRD consistency and quality analysis. Say "Analyze our product docs."
- **`product-roadmap`** — Track milestone progress: decision status, live issues via MCP, code evidence, and gates. Say "Show roadmap progress."

### Architecture (5 skills)

All user-invoked. Create and manage Architecture Decision Records using the Rozanski & Woods methodology.

- **`architect-init`** — Reverse-engineer ADRs from an existing codebase (brownfield). Say "Reverse-engineer architecture from this codebase."
- **`architect-specify`** — Create ADRs from a PRD or feature description (greenfield). Say "Create ADRs from this PRD."
- **`architect-clarify`** — Refine and validate existing ADRs. Say "Refine and validate my ADRs."
- **`architect-implement`** — Generate an Architecture Description (AD.md) from accepted ADRs. Say "Generate AD.md from my ADRs."
- **`architect-analyze`** — Check ADR↔AD consistency and architecture quality. Say "Analyze architecture consistency."

---

<details>
<summary><strong>Output File Layout</strong></summary>

All skills write to `.adlc/` (project root) and the team AI directives repo.

**Team Directives** (inside the team AI directives repository):

- `AGENTS.md` — agent instructions (loading order, rules, skills)
- `CDR.md` — index of approved context contributions
- `.skills.json` — skills manifest (schema v2.0.0)
- `.mcp.json.example` — MCP servers config example
- `context_modules/constitution.md` — team constitution (OKF frontmatter)
- `context_modules/{rules,personas,examples}/**/*.md` — context modules
- `context_modules/{type}/index.md` — progressive disclosure per concept type
- `context_modules/{type}/log.md` — chronological change log per concept type
- `skills/{name}/SKILL.md` + `.skills-entry.json` — published team skills
- `traces/{branch}.md` — published session traces

**LevelUp** (inside `.adlc/` of the target project):

- `.adlc/drafts/trace.md` — session execution trace
- `.adlc/drafts/cdr/CDR-{NNN}.md` — proposed/discovered CDRs (individual files)
- `.adlc/drafts/cdr/cdr.md` — auto-generated CDR index
- `.adlc/init-options.json` — team AI directives path config

**Product** (inside `.adlc/` and repo root):

- `.adlc/drafts/pdr/PDR-{NNN}.md` — proposed/discovered PDRs
- `.adlc/drafts/pdr/pdr.md` — auto-generated PDR index
- `.adlc/memory/pdr/PDR-{NNN}.md` — accepted/completed PDRs
- `.adlc/memory/pdr/pdr.md` — accepted PDR index
- `.adlc/product/sections/{feature-area}/{section}.md` — PRD section build artifacts
- `.adlc/product/state.json` — DAG execution state
- `PRD.md` — Product Requirements Document (repo root)

**Architecture** (inside `.adlc/` and repo root):

- `.adlc/drafts/adr/ADR-{NNN}.md` — proposed/discovered ADRs
- `.adlc/drafts/adr/adr.md` — auto-generated ADR index
- `.adlc/memory/adr/ADR-{NNN}.md` — accepted ADRs
- `.adlc/memory/adr/adr.md` — accepted ADR index
- `AD.md` — Architecture Description (repo root)
- `.adlc/architect/` — per-view DAG artifacts

</details>

<details>
<summary><strong>OKF Compliance</strong></summary>

Generated context modules include [Open Knowledge Format (OKF) v0.1](https://blog.agentics.org/open-knowledge-format/) compliant frontmatter alongside custom fields.

| OKF field | Status | Source |
|-----------|--------|--------|
| `type` | ✅ | CDR context type |
| `title` | ✅ | CDR title |
| `description` | ✅ | CDR descriptor |
| `resource` | ✅ | Relative path to artifact |
| `tags` | ✅ | Context type tag |
| `timestamp` | ✅ | ISO 8601 datetime |

Custom fields co-exist with OKF frontmatter: `id`, `cdr_ref`, `created`, `modified`, `verified`, `age_days`, `evidence`.

Directory structure: `context_modules/{type}/index.md` (progressive disclosure), `context_modules/{type}/log.md` (change history), cross-links between related concepts.

</details>

<details>
<summary><strong>Workflows</strong></summary>

**Team Directives setup:**
```
team-setup → team-constitution → team-boot (auto on every session)
```

**Product lifecycle:**
```
Brownfield: product-init → product-clarify → product-implement → product-analyze
Greenfield: product-specify → product-clarify → product-implement → product-analyze
Roadmap:    product-roadmap (anytime)
```

**Architecture lifecycle:**
```
Brownfield: architect-init → architect-clarify → architect-implement → architect-analyze
Greenfield: architect-specify → architect-clarify → architect-implement → architect-analyze
```

**LevelUp / CDR lifecycle:**
```
Brownfield: levelup-init → levelup-clarify → levelup-publish → team-repair
Session:    levelup-trace → levelup-specify → levelup-clarify → levelup-publish → team-repair
```

**Full product → architecture → team:**
```
Product:     product-specify → product-clarify → product-implement → product-analyze
Architecture: architect-specify → architect-clarify → architect-implement → architect-analyze
Team:        levelup-trace → levelup-specify → levelup-clarify → levelup-publish → team-repair
```

</details>

<details>
<summary><strong>12-Factor Alignment</strong></summary>

| Factor | Skills | How |
|--------|--------|-----|
| **III — Mission Definition** | Product skills | PRD/PDR lifecycle ensures product decisions are documented, reviewed, and traceable before execution |
| **IV — Structured Planning** | Architecture skills | ADRs and AD.md provide structured planning artifacts using Rozanski & Woods viewpoints |
| **IX — Traceability** | Product + Architecture | Every decision traces from PDR → PRD → feature and from ADR → AD → code |
| **X — Context Engineering** | Team Directives | `team-boot` and `team-discover` load only relevant context per task, preventing bloat |
| **XI — Directives as Code** | Team + LevelUp + Product + Architecture | All directive lifecycles (CDR, PDR, ADR) live in version-controlled repos, each with draft → clarify → accept → publish → analyze stages |
| **XII — Team Capability** | All 22 skills | Skills are packaged, installable, and reusable across projects and agents |

</details>

---

## Release Process

See [RELEASE.md](./RELEASE.md) for the release runbook, tag naming conventions, and recovery procedures.

## License

MIT — see [LICENSE](./LICENSE).
