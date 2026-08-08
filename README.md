# adlc-team-skills

Agent skills that give coding agents your team's context at session start,
so they stop working like strangers.

## The problem

Coding agents start every session knowing nothing about your team. They don't
know your conventions, which patterns you deprecated, or why service X never
calls service Y. Developers compensate with personal CLAUDE.md files, but
those live on one machine, drift out of date, and don't transfer between
teammates or tools.

## What this does

### #1: The agent doesn't know how your team works

`team-boot` runs at session start and injects an *index* of your team's
rules, personas, and decisions — names and one-line descriptors, roughly a
hundred tokens. Not the rules themselves. When the active task matches a
rule, the agent pulls that rule's full text on demand. A task touching SQL
loads the SQL rule; nothing else loads.

```
team-boot        → auto-runs at session start (event hook), injects the index
team-discover    → /team-discover for a structured match table
team-constitution → interactively define your team's principles
team-repair      → re-index, conflict scan, freshness check
```

The index lives in a git repo ([team-ai-directives](https://github.com/tikalk/agentic-sdlc-team-ai-directives))
— versioned, reviewed by PR, shared by the whole team.

### #2: The agent guesses instead of asking

LLMs fill ambiguity with invention. `mission-brief` forces a contract first:
goal, constraints, non-goals, success criteria — then runs
specify → plan → tasks → implement ↔ converge. When the agent gets something
wrong, you fix the spec, not the code.

```
mission-brief "add user profile API with JWT"
mission-brief --resume    # continue an interrupted mission
```

### #3: The maker grades its own work

The `evals` skills build executable evaluation suites (PromptFoo or DeepEval).
Anything that can be checked by code gets a binary grader — plain assertions,
Tier 1. LLM judges are Tier 2, reserved for what static checks can't verify.
Nothing auto-merges; the pipeline ends at a PR a human reviews.

```
evals-init → evals-specify → evals-clarify → evals-implement → evals-validate → evals-analyze
```

### #4: Session learnings evaporate

When a session surfaces a hard-won fix, `levelup-specify` extracts it as a
Context Directive Record (CDR) and commits it back to the team repo — the
next session starts smarter.

```
levelup-init → levelup-specify → levelup-clarify → levelup-publish
```

### #5: Product and architecture decisions are invisible

`product-*` skills capture product decisions as PDR files and compile them
into `PRD.md`. `architect-*` skills capture architecture decisions as ADRs
(Rozanski & Woods viewpoints) and compose them into `AD.md`. Every decision
traces from record to document to code.

```
product-init|specify → product-clarify → product-implement → product-analyze
architect-init|specify → architect-clarify → architect-implement → architect-analyze
```

### #6: Rules pile up and rot

Base models improve; yesterday's scaffolding becomes today's context noise.
`team-repair --build-to-delete` re-runs evals *without* a rule; if the model
passes anyway, the rule is proposed for deletion. Rules should shrink over
time, not grow.

## A note on context stuffing

Long contexts measurably degrade LLM performance — even with perfect retrieval
([arXiv:2510.05381](https://arxiv.org/abs/2510.05381), 13.9%–85% degradation by
length alone). This repo exists because of that failure mode, not in spite of
it: agents get an index by default and pull full rules only when relevant. If
your instinct is "more rules in context don't work" — we agree. That's the
design.

## Install

```bash
# Skills + slash commands + session_start events
npx adlc-skills-cli add tikalk/adlc-team-skills -a opencode

# Or plain skills (no commands/events)
npx skills add tikalk/adlc-team-skills -a claude -g
```

Works with any agent supporting the [Agent Skills standard](https://agentskills.io) —
Claude Code, Codex, OpenCode, Cursor, Copilot, and others.

[`adlc-skills-cli`](https://github.com/tikalk/adlc-skills-cli) wraps `npx skills add`
and additionally generates `/name` slash commands and wires `session_start` event
hooks (via `.events.json`) for 9 coding agents. Skills repos without `.events.json`
get commands only.

**First run:** `team-boot` fires at session start. On an unconfigured project
it points you to `/team-setup`, which clones, links, or scaffolds your
team-ai-directives repo. `team-constitution` fills in your principles.

**Using `agentic-sdlc-spec-kit` alongside this repo?** See
[Coexistence with Spec Kit](docs/spec-kit-integration.md) for the
conflict-free install flow.

## Universal orchestration

`mission-brief` doesn't force a proprietary ecosystem. At mission start it
scans installed skills directories, reads each `SKILL.md` frontmatter, and
hands the inventory to the subagent — the model picks the skill that fits
each step. Works alongside:

| Source | Examples |
|---|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | `/tdd`, `/grill-me`, `/code-review` |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Exit-criteria checklists |
| [superpowers](https://github.com/obra/superpowers) | Workflow skills |
| spec-kit / [agentic-sdlc-spec-kit](https://github.com/tikalk/agentic-sdlc-spec-kit) / OpenSpec | SDD command frameworks |
| This repo | `product-specify`, `architect-specify`, `evals-validate`, `levelup-specify` |
| Your own | Anything following the `SKILL.md` standard |

## Security

On 2026-07-27 a supply-chain worm briefly injected a malicious payload into
this repo's `.claude/` and `.vscode/` directories via a stolen maintainer
token (exposure window ~11:06–18:30 UTC). The payload only executed if you
cloned the repo and opened it in VS Code or started a Claude Code session
inside it; the `npx skills` install path never shipped or ran those files.

History was rewritten to strip the payload from all commits and tags, tokens
and secrets were rotated, and branch protection now blocks the vector used.
Details and remediation steps: [issue #1](https://github.com/tikalk/adlc-team-skills/issues/1).

Lesson for any repo: treat `.vscode/tasks.json` and `.claude/settings.json`
in a clone as executable code, and disable editor auto-run tasks.

## Reference

### Team Directives

- **`team-boot`** — session-start bootstrap; injects the directives index. Auto-triggered.
- **`team-discover`** — manual re-scan; structured match table (`/team-discover`).
- **`team-setup`** — clone, link, or scaffold a team-ai-directives repo.
- **`team-constitution`** — define or amend team principles interactively.
- **`team-repair`** — re-index, conflict scan, freshness, `--build-to-delete`.
- **`team-skills`** — browse/install team skills from the directives repo.

### LevelUp / CDR lifecycle

- **`levelup-init`** — brownfield CDR discovery from an existing codebase.
- **`levelup-specify`** — extract CDRs + paired evals from the current session.
- **`levelup-clarify`** — review, accept, reject, or defer pending CDRs.
- **`levelup-publish`** — compile accepted CDRs into directives + goldensets + draft PR.

### Product (PDRs)

- **`product-init`** — brownfield PDR discovery. **`product-specify`** — greenfield creation.
- **`product-clarify`** — refine and approve. **`product-implement`** — generate `PRD.md`.
- **`product-analyze`** — PDR↔PRD consistency. **`product-roadmap`** — milestone progress.

### Architecture (ADRs)

- **`architect-init`** — reverse-engineer ADRs. **`architect-specify`** — create ADRs.
- **`architect-clarify`** — refine. **`architect-implement`** — generate `AD.md`.
- **`architect-analyze`** — ADR↔AD consistency.

### Evals

- **`evals-init`** — scaffold `evals/{system}/` with security baseline.
- **`evals-specify`** — extract criteria from specs / failure traces.
- **`evals-clarify`** — cluster, isolate holdout, publish goldset.
- **`evals-implement`** — generate graders + unit tests.
- **`evals-validate`** — run evaluation pyramid, TPR/TNR + SLA headroom.
- **`evals-analyze`** — route failures to rules or evaluator backlog.

### Orchestration & misc

- **`mission-brief`** — spec-contract pipeline with converge loop, circuit breaker, resume.
- **`tech-radar-context`** — injects Tikal Tech Radar context for tech choices. Auto-triggered.
- **`workspace`** — multi-repo workspace: `--init` creates `.adlc/` structure + `.gitignore`, discover/link/audit child repos.

---

<details>
<summary><strong>Repository layout</strong></summary>

Skills are organized into category subdirectories under `skills/`:

```
skills/
├── architect/             # architect-* (5 skills)
├── product/               # product-* (6 skills) + product-templates/
├── levelup/               # levelup-* (4 skills) + levelup-helpers.{sh,ps1}
├── mission-brief/         # core SDD orchestrator (1 skill)
├── evals/                 # evals-* (6 skills) + evals-templates/
├── tech-radar/            # tech-radar-* (1 skill) + resources/radar.json
├── workspace/             # workspace (1 skill) — multi-repo coordination
└── team/                  # team-* (6 skills) + team-helpers.{sh,ps1}
```

This places every single skill exactly 2 levels deep, fully resolving the default depth limit of the `skills` CLI and ensuring all skills install out of the box.

</details>

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

**Workspace** (inside parent repo root):

- `.gitmodules` — Git submodule registrations for child repos (created by `--link`)
- `.adlc/` — shared team context (PDRs, ADRs, CDRs); parent is the single source of truth
- Child repos discovered at depth 1; each child's `.adlc/` presence is reported (informational)

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
team-setup → team-constitution → team-boot (auto at session start)
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

**Multi-repo workspace:**
```
workspace --init → create .adlc/ structure + configure .gitignore
product-specify / architect-specify → create shared PDRs/ADRs in parent .adlc/
workspace --link → register child repos as submodules
workspace --status → audit branch, dirty, unpushed, SHA drift
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

This repo implements the [Twelve-Factor Agentic SDLC](https://github.com/tikalk/agentic-sdlc-12-factors).

| Factor | Skills | How |
|--------|--------|-----|
| **III — Mission Definition** | Product skills | PRD/PDR lifecycle ensures product decisions are documented, reviewed, and traceable before execution |
| **IV — Structured Planning** | Architecture skills | ADRs and AD.md provide structured planning artifacts using Rozanski & Woods viewpoints |
| **VII — Verification-First Evals** | LevelUp + Evals skills | LevelUp creates directive-compliance eval CDRs; evals skills build and run application-level evaluation suites (PromptFoo/DeepEval) with binary graders, holdout splits, and statistical validation |
| **VIII — Ratchet Effect** | LevelUp + Evals skills | Each session extracts eval CDRs alongside directive CDRs; each goldset publication adds criteria that monotonically increase quality — `evals-clarify` publishes, `evals-validate` enforces |
| **IX — Traceability** | Product + Architecture | Every decision traces from PDR → PRD → feature and from ADR → AD → code |
| **X — Context Engineering** | Team Directives | `team-boot` assembles constitution, CDR index, and PDR/ADR indexes into the system prompt at session start; `team-discover` provides manual re-scan |
| **XI — Directives as Code** | Team + LevelUp + Product + Architecture | All directive lifecycles (CDR, PDR, ADR) live in version-controlled repos, each with draft → clarify → accept → publish → analyze stages |
| **XII — Build to Delete** | team-repair + evals-analyze | `--build-to-delete` runs evals without directives via LLM calls; if model passes, proposes deletion (Harness Decay); `evals-analyze` routes spec failures to `levelup-specify` (rules) and generalization failures to the evaluator backlog — the feedback loop that makes build-to-delete verifiable |

</details>

---

## Release Process

See [RELEASE.md](./RELEASE.md) for the release runbook, tag naming conventions, and recovery procedures.

## License

MIT — see [LICENSE](./LICENSE).
