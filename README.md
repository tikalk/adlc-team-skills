# ADLC Team Skills — Agentic SDLC for Engineering Teams

> **Stop Vibe Coding in Silos. Build a Shared Cognitive Layer for Your Engineering Team.**

Individual prompt hacks create quick wins for solo developers, but when scaled across a team, "vibe coding" leads to chaotic technical debt, context rot, unreviewable PRs, and lost code ownership. **Speed is solved; Trust and Verification is the new bottleneck in AI engineering.**

**ADLC Team Skills** (`tikalk/adlc-team-skills`) is the open-source **Team Layer** of the **Twelve-Factor Agentic SDLC**. It turns AI agents from isolated guessers into compliant, accountable team members that share your team's constitution, product strategy, architectural standards, and evaluation benchmarks.

---

## Quickstart

```bash
# Install skills + generate slash commands + wire session_start/user_prompt_submit events
npx adlc-agents-cli add tikalk/adlc-team-skills -a opencode

# Or with npx skills only (skills without commands/events)
npx skills add tikalk/adlc-team-skills -a claude -g
```

Works out of the box with any agent supporting the [Agent Skills standard](https://agentskills.io) — Claude Code, Codex, OpenCode, Cursor, GitHub Copilot, and others.

**Slash commands + events:** [`adlc-agents-cli`](https://github.com/tikalk/adlc-agents-cli) wraps `npx skills add` and additionally generates `/name` slash commands and wires `session_start`/`user_prompt_submit` event hooks (via `.events.json`) for 9 coding agents. Skills repos without `.events.json` get commands only.

**Universal orchestration:** `mission-brief` auto-discovers skills from *any* source (mattpocock/skills, addy osmani/agent-skills, superpowers, spec-kit, or your own) and dynamically wires them into the mission pipeline. No vendor lock-in.

**Before anything else:** Run `team-setup` once per project to link your team's central `team-ai-directives` repository.

---

## Directives as Code: The Four Team Pillars

```
                             [ THE GREAT FILTER ]
                      (Human Team Lead Macro-Review)
                                     ▲
                                     │
                  ┌──────────────────┴──────────────────┐
                  │   Pillar 4: Governance & Evals      │
                  │   (Tier 1 Fast Checks + LLM Judges) │
                  └──────────────────▲──────────────────┘
                                     │
                  ┌──────────────────┴──────────────────┐
                  │   Pillar 3: Spec-Driven Workflow    │
                  │   (Contract-First Mission Pipeline) │
                  └──────────────────▲──────────────────┘
                                     │
                  ┌──────────────────┴──────────────────┐
                  │   Pillar 2: Product & Architecture  │
                  │   (Product PDRs + Architecture ADRs)│
                  └──────────────────▲──────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 │   Pillar 1: Strategy & Team Directives│
                 │   (team-boot / levelup / CDR repository) │
                 └───────────────────────────────────────┘
```

### 🏛️ Pillar 1: Strategy & Team Directives (Team-First Alignment)

**Factor I — Developer as Orchestrator. Factor X — Context Engineering. Factor XI — Directives as Code.**

Put the **team** at the center of your AI strategy. Instead of individual developers hoarding prompt shortcuts on local machines, team standards live in a version-controlled Git repository (`team-ai-directives`).

*   **`team-boot`**: Auto-bootstraps agent sessions on start, injecting your version-controlled Team Constitution so every agent behaves as an aligned team member.
*   **`team-discover`**: Dynamically fetches *only* the specific personas, architectural rules, PDRs, and ADRs relevant to the current task — zero prompt-wall bloat.
*   **`team-constitution`**: Interactively define, review, or amend your engineering team's core principles.
*   **`team-repair`**: Re-index CDR.md, scan for rule conflicts, and verify directive freshness.

```
team-boot        → auto-loads constitution + PDR/ADR indexes + discover
team-discover    → fetches rules/personas/examples for the current task
team-constitution → create or amend the team constitution interactively
team-repair      → re-index CDR.md, scan for conflicts, verify freshness
```

---

### 🎯 Pillar 2: Product Strategy & Architectural Governance (PDRs & ADRs)

**Factor III — Mission Definition. Factor IV — Structured Planning. Factor IX — Traceability.**

Without documented decisions, every implementation session re-derives (or misinterprets) product intent and architectural rules.

*   **Product Decision Records (`product-*`)**: Capture product decisions as individual PDR files, resolve ambiguities through an interactive clarification workflow, and compile them into a self-contained `PRD.md`.
*   **Architectural Decision Records (`architect-*`)**: Reverse-engineer or define architectural decisions using Rozanski & Woods viewpoints (Functional, Security, Deployment, Performance) and compose them into a unified `AD.md`.
*   **`product-roadmap`**: Track milestone progress across four layers of truth — decisions (PDRs), execution (live issues via MCP), code evidence, and milestone gates.

```
Product:      product-init → product-clarify → product-implement → product-analyze
Architecture: architect-init → architect-clarify → architect-implement → architect-analyze
Roadmap:      product-roadmap (tracks PDRs + issues + code + gates)
```

---

### 📐 Pillar 3: Spec-Driven Workflow ("Debug the Spec, Not the Code")

**Factor III — Mission Definition. Factor IV — Structured Planning. Factor V — Triage & Execution. Factor XIII — Loop Engineering.**

AI is an obsessive guesser — when faced with ambiguity, it invents solutions instead of asking questions. Move from a *Conversational* model to a *Contract* model.

*   **`mission-brief`**: The team's autonomous pipeline runner. Takes a feature prompt, derives a formal contract (Goal, Constraints, Non-Goals, Success Criteria), generates an ordered step list, and walks a `specify → plan → tasks → implement ↺ converge` loop to completion.
*   **Mantra: "Debug the Spec, Not the Code"**: When an agent makes a mistake, don't just patch the code — add the missing constraint to the specification so the mistake is never repeated.

```
mission-brief "add user profile API with JWT"
  ├── Phase 2: Brief (Goal, Constraints, Non-Goals, Success Criteria)
  ├── Phase 3: Route Classification (spec | change | quick)
  ├── Phase 4: Discovery (auto-wires local installed skills & SDD frameworks)
  └── Phase 5: Execute (specify → plan → tasks → implement ↺ converge)
```

---

### 🛡️ Pillar 4: Team Governance, Verification-First Evals & "Build to Delete"

**Factor VII — Verification-First Evals. Factor VIII — Ratchet Effect. Factor IX — Traceability. Factor XII — Build to Delete.**

Never let the agent that wrote the code decide if the code is good. "Separate the Maker from the Checker."

*   **`evals` skills**: Build application-level evaluation suites (PromptFoo or DeepEval) using Eval-Driven Development (EDD). Runs Tier 1 fast checks + Tier 2 LLM judge subagents to test code against defined business risks *before* human macro-review in **The Great Filter**.
*   **`levelup`**: Capture session wins into permanent team memory. `levelup-specify` extracts session execution traces and commits them to Git as reusable rules (Context Directive Records — CDRs).
*   **"Build to Delete"**: Prune outdated rules and prompt scaffolding as underlying foundation models improve using `team-repair --build-to-delete`.

```
LevelUp: levelup-init → levelup-specify → levelup-clarify → levelup-publish
Evals:   evals-init → evals-specify → evals-clarify → evals-implement → evals-validate → evals-analyze
```

---

## 🌐 Universal Skill & SDD Framework Orchestration — Zero Lock-In

**Factor XII — Build to Delete. Factor XIII — Loop Engineering.**

`mission-brief` acts as an open, vendor-agnostic orchestrator across all popular agent skill repositories and Spec-Driven Development (SDD) frameworks:

| SDD Framework / Skill Source | Supported Workflows |
| :--- | :--- |
| **Agentic SDLC Spec-Kit** (`tikalk/agentic-sdlc-spec-kit`) | Twelve-Factor SDD pipeline, native specify CLI discovery, contract verification |
| **Spec-Kit** (`specify_cli`) | Native command discovery and specification templates |
| **OpenSpec** | Structured edge-case contracts and verification schemas |
| **[mattpocock/skills](https://github.com/mattpocock/skills)** | `/tdd`, `/grill-me`, `/grill-with-docs`, `/code-review`, `/prototype` |
| **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** | Exit criteria checklists, quality gate skills |
| **[superpowers](https://github.com/obra/superpowers)** | Developer tooling & workflow skills |
| **ADLC Team Skills** (this repo) | `product-specify`, `architect-specify`, `evals-validate`, `levelup-specify` |
| **Your Custom Skills** | Any skill following the `SKILL.md` standard |

### How it works

1. **Discovery** — At mission start, `mission-brief` scans all skills directories (`.claude/skills`, `.agents/skills`, etc.) and reads every `SKILL.md` frontmatter to build a vendor-agnostic inventory of installed skills with their names and descriptions.
2. **LLM-decided routing** — Each step's delegation prompt includes the full skills inventory. The subagent decides which skill (if any) fits the current phase — the LLM matches, not a brittle lookup table.
3. **Graceful fallback** — If no skill matches, the subagent executes directly. If a skill matches, it's invoked. Either way, the mission pipeline continues.

```bash
# Install skills from multiple team or community sources
npx skills add mattpocock/skills
npx skills add tikalk/adlc-team-skills

# mission-brief discovers and routes them automatically
mission-brief "add user profile API with JWT"
```

---

## Repository Layout

Skills are organized under the four pillars of the Twelve-Factor Agentic SDLC, flattened directly under the `skills/` directory:

```
skills/
├── architect/             # architect-* (5 skills)
├── product/               # product-* (6 skills) + product-templates/
├── levelup/               # levelup-* (4 skills) + levelup-helpers.{sh,ps1}
├── mission-brief/         # core SDD orchestrator (1 skill)
├── evals/                 # evals-* (6 skills) + evals-templates/
└── team/                  # team-* (6 skills) + team-helpers.{sh,ps1}
```

This places every single skill exactly 2 levels deep, fully resolving the default depth limit of the `skills` CLI and ensuring all skills install out of the box.

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

All user-invoked. Capture and publish reusable patterns to team-ai-directives, including paired directive compliance evals.

- **`levelup-init`** — Brownfield CDR discovery from existing codebase, including paired eval CDRs from code patterns. Say "Discover directives from this codebase."
- **`levelup-specify`** — Extract CDRs and paired eval CDRs from the current session. Say "Extract lessons from this session."
- **`levelup-clarify`** — Review, accept, reject, or defer pending CDRs. Evals regression gate runs by default. Say "Review pending CDRs."
- **`levelup-publish`** — Compile accepted CDRs into team directives artifacts, evals goldensets, and draft PR. Say "Publish accepted CDRs" or "Build one skill from a CDR" (`--skill CDR-NNN`).

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

### Governance / Verification (6 skills)

All user-invoked. Build and maintain application-level evaluation suites following EDD (Eval-Driven Development) principles (PromptFoo or DeepEval).

- **`evals-init`** — Initialize evaluation directory structure (`evals/{system}/`) with security baseline. Say "Initialize my evaluation harness."
- **`evals-specify`** — Extract eval criteria from specs and production failure traces (bottom-up open coding). Say "Specify evaluation criteria from this failure log."
- **`evals-clarify`** — Cluster related patterns, refine criteria, isolate 20% holdout split, and publish goldset. Say "Clarify and accept my draft evaluations."
- **`evals-implement`** — Generate executable graders and test configs, automatically running unit tests to verify evaluator correctness. Say "Generate graders from the goldset."
- **`evals-validate`** — Run the evaluation pyramid (Tier 1 fast checks + Tier 2 LLM judges) and compute quality metrics (TPR/TNR, SLA headroom). Say "Validate my evaluation suite."
- **`evals-analyze`** — Deep-analyze trajectory failure traces, routing spec-level failures to `levelup-specify` (rules) and generalization failures to backlog. Say "Analyze evaluation failures."

### Missions (1 skill)

User-invoked. Structure a feature description into a Mission Brief and run it end-to-end with any installed SDD skill set.

- **`mission-brief`** — Takes a description, structures it into a Mission Brief (goal, constraints, success criteria), generates an ordered step list with prompts that trigger installed SDD skills, and walks those steps to converged implementation. Sync (gated) or `--async` (ungated, checkpoint across sessions). Say "Build this feature end to end" or `mission-brief "add dark mode"`. Resume with `mission-brief --resume`.

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
- `evals/{directive-id}/goldset.md` + `goldset.json` — directive compliance goldensets

**LevelUp** (inside `.adlc/` of the target project):

- `.adlc/drafts/cdr/CDR-{NNN}.md` — proposed/discovered CDRs (including eval CDRs)
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

**Missions** (inside `.adlc/` of the target project):

- `.adlc/workflow/workflow-config.yml` — mission execution/supervision/budgets config
- `.adlc/workflow/.mission-state.json` — step list, completed steps, brief, discovery results
- `.adlc/workflow/runs/<feature>/mission-log.json` — final audit trail
- `.adlc/workflow/runs/<feature>/iterations.md` — per-implement audit entries

**Governance** (inside target project and repo root):

- `.adlc/drafts/evals/EVAL-{NNN}.md` — proposed/discovered eval criteria drafts
- `.adlc/drafts/evals/evals.md` — draft evals index
- `.adlc/memory/evals/EVAL-{NNN}.md` — accepted/completed eval criteria
- `.adlc/memory/evals/evals.md` — accepted evals index
- `.adlc/memory/evals/holdout.json` — isolated/reserved holdout test dataset
- `evals/{system}/goldset.md` — published goldset (human-readable)
- `evals/{system}/goldset.json` — published goldset (machine-readable)
- `evals/{system}/config.yml` — evaluation framework configuration
- `evals/{system}/config.{js,py}` — framework test config
- `evals/{system}/graders/check_*.py` — generated binary Python graders / metrics
- `evals/{system}/tests/test_check_*.py` — generated unit tests verifying grader correctness
- `evals/results/validation_report.md` — statistical validation results report

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
Session:    levelup-specify → levelup-clarify → levelup-publish → team-repair
Build to Delete: team-repair --build-to-delete → levelup-clarify (review deletion CDRs)
```

**Mission:**
```
mission-brief "feature" → review brief → execute steps → converge → mission-log.json
```

**Application Evaluation lifecycle:**
```
Greenfield (Spec-Driven): evals-init → evals-specify (from spec) → evals-clarify → evals-implement → evals-validate
Brownfield (Error-Driven): evals-init → evals-specify (from failures) → evals-clarify → evals-implement → evals-validate → evals-analyze
```

**Full product → architecture → team:**
```
Product:     product-specify → product-clarify → product-implement → product-analyze
Architecture: architect-specify → architect-clarify → architect-implement → architect-analyze
Team:        levelup-specify → levelup-clarify → levelup-publish → team-repair
```

</details>

<details>
<summary><strong>12-Factor Alignment</strong></summary>

| Factor | Skills | How |
|--------|--------|-----|
| **III — Mission Definition** | Product skills | PRD/PDR lifecycle ensures product decisions are documented, reviewed, and traceable before execution |
| **IV — Structured Planning** | Architecture skills | ADRs and AD.md provide structured planning artifacts using Rozanski & Woods viewpoints |
| **VII — Verification-First Evals** | LevelUp + Evals skills | LevelUp creates directive-compliance eval CDRs; evals skills build and run application-level evaluation suites (PromptFoo/DeepEval) with binary graders, holdout splits, and statistical validation |
| **VIII — Ratchet Effect** | LevelUp + Evals skills | Each session extracts eval CDRs alongside directive CDRs; each goldset publication adds criteria that monotonically increase quality — `evals-clarify` publishes, `evals-validate` enforces |
| **IX — Traceability** | Product + Architecture | Every decision traces from PDR → PRD → feature and from ADR → AD → code |
| **X — Context Engineering** | Team Directives | `team-boot` and `team-discover` load only relevant context per task, preventing bloat |
| **XI — Directives as Code** | Team + LevelUp + Product + Architecture | All directive lifecycles (CDR, PDR, ADR) live in version-controlled repos, each with draft → clarify → accept → publish → analyze stages |
| **XII — Build to Delete** | team-repair + evals-analyze | `--build-to-delete` runs evals without directives via LLM calls; if model passes, proposes deletion (Harness Decay); `evals-analyze` routes spec failures to `levelup-specify` (rules) and generalization failures to the evaluator backlog — the feedback loop that makes build-to-delete verifiable |

</details>

---

## Release Process

See [RELEASE.md](./RELEASE.md) for the release runbook, tag naming conventions, and recovery procedures.

## License

MIT — see [LICENSE](./LICENSE).
