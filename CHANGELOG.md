# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.11.1] - 2026-07-23

### Fixed

- **`team-discover` (plan-mode regression)**: v0.11.0 made every invocation persist `.adlc/drafts/team-context.md`, which broke read-only / plan-mode sessions (the skill would attempt a forbidden file write). Restored a no-write fallback: if `$ARGUMENTS` contains `--no-write` **or** the session is in plan mode / any read-only phase (a system reminder bars file writes), discovery runs inline — the table and `search_metadata` are still produced, only persistence is skipped. Build-mode sessions still persist per prompt (delta-aware). Updated Modes, Step 6, Red Flags, and Verification.
- **`team-boot` (hollow-trigger hardening)**: strengthened Step 5 into an **output contract** — the visible response MUST contain the `team-discover` table and `search_metadata` line before the task response; if either is absent, discovery did not run and must be executed. Addresses a session-trace defect where `team-discover` was invoked but its Core Process never executed (no table produced), yet the agent proceeded. Added a matching Red Flag and updated Verification item 5. Step 4 now notes that plan mode runs discovery inline (no file writes).

## [0.11.0] - 2026-07-23

### Changed

- **`team-boot`**: Step 4 retitled "Run Discovery" — `team-discover` is now invoked on **every prompt** (specify, plan, implement, question, debugging, chat) with no spec/plan gate and no continuation exemption. Reverses the 0.10.0 phase-gated design, where discovery ran only on spec/plan prompts and other prompts referenced the persisted `team-context.md`. A session trace showed follow-up implementation prompts like "fix the help message" skipping discovery entirely (the model treated them as "direct continuation" and skipped `team-boot`, and `team-discover` has no standalone trigger for plain follow-ups). The acknowledgment (Step 5) must now appear in the **visible response**, not only in reasoning. Full bootstrap (constitution + PDR/ADR indexes) still happens once per session; subsequent prompts skip Steps 1–3 but always run Steps 4–5.
- **`team-discover`**: lifecycle switched from generate-then-reference (0.10.0) to **regenerate-per-prompt**. Runs on every user prompt (auto-invoked by `team-boot`) and persists `.adlc/drafts/team-context.md` each run; same-feature repeats are delta-aware, different features reset. Frontmatter description updated to reflect every-prompt invocation. The `phase` metadata field extended to `specify | plan | implement | chat | manual` (informational).

### Fixed

- **`team-discover`**: added an execution-contract red flag — loading this SKILL.md is not discovery; the run is incomplete until the Discovered Team Context table and `search_metadata` exist, and matches must never be fabricated. Addresses a session-trace defect where `team-discover` was invoked but its Core Process was never executed (no index read, no table produced), yet "discovery matches" were reported in reasoning.

## [0.10.0] - 2026-07-23

### Added

- **New skill: `mission-brief`** — mission-driven SDD orchestrator, detached from spec-kit. Takes a feature description, structures it into a Mission Brief (goal, constraints, success criteria), generates an ordered step list with prompts that trigger installed SDD skills via model invocation or command-file discovery, and walks those steps to converged implementation. No YAML workflow files, no per-framework profiles — step prompts use canonical SDD terminology (specify, plan, implement, converge) that works with any installed skill set (addyosmani/agent-skills, mattpocock/skills, superpowers, openspec, agentic-* presets, or custom). Supports 30+ agents via externalized command discovery (`references/agent-integrations.md`). Sync (default, gated inline) / `--async` (forces ungated, checkpoint across sessions via `.adlc/workflow/.mission-state.json`) / `mission-brief --resume` (explicit resume; fresh `mission-brief` asks before clobbering an interrupted state). Keeps supervision modes, do-while converge loop, circuit breaker, converge-independence hint, spec-correction routing (config-gated), per-step model tiers (optional `models: {strong, fast}`), and `iterations.md` + `mission-log.json` audit trail. Replaces the earlier `mission` skill (removed).

### Changed

- **`team-discover`**: persists `.adlc/drafts/team-context.md` on every run (skill, model-triggered, or manual) instead of no-write inline-only for skill invocations. New lifecycle contract: discovery runs only during spec/plan phases; all other prompts reference the persisted file. `team-context.md` carries a metadata header (`feature`/`phase`/`generated`); same-feature re-runs are delta-aware, different-feature re-runs reset. Removed spec-kit hook machinery (`before_specify`/`before_plan`/`before_implement`, `SPECIFY_*` env vars, `specs/` feature dirs) — single canonical location `.adlc/drafts/team-context.md`.
- **`team-boot`**: Step 4 renamed to "Reference or Run Team Context" — the model assesses each prompt: spec/plan/design requests invoke `team-discover` (persist), everything else references the existing `team-context.md`. Full bootstrap (constitution + PDR/ADR indexes) happens once per session; subsequent prompts skip Steps 1–3 but always run Step 4.
- **`team-skills`**: new `--all` mode installs every `default` and `external` skill (skipping `blocked` and already-installed). Dropped the `team-` prefix convention — skills install under their original names with unchanged frontmatter. Fixed stale category table to match schema v2.0.0 (`default`/`external`/`blocked`).
- **`team-setup`**: Post-Setup step 4 offers to install team skills from `.skills.json` via `/team-skills --all` (skip on empty manifest or `auto_install_default: false`). Mode 4 reports installed-vs-missing and offers the same. Mode 3 scaffold `.skills.json` now uses the real schema v2.0.0 shape (`version`/`source`/`description`/`default`/`external`/`blocked`/`policy`). Scrubbed spec-kit references (`specify init`, `update-agent-context.sh`, `agent-context` extension).

### Security

- **`team-setup` (Mode 2)**: fixed command-injection vulnerability — `team_ai_directive` path is now passed to Python via the environment (`os.environ`), not interpolated into Python source. Added an Input Validation section covering all modes: paths, team names, and clone URLs are validated before interpolation into shell commands.
- **`team-setup` (Mode 1)**: clone URLs must use `https://`; `file://`/`ssh://`/other schemes are rejected unless explicitly confirmed.
- **`team-setup` (all modes)**: user-supplied paths and team names are validated for shell metacharacters before use in `mkdir`/`git clone`/`git commit`/heredocs.

### Fixed

- Scrubbed spec-kit operational references from `team-skills`, `team-repair`, `team-helpers.sh`/`.ps1`, and `architect-implement` (`specify init` → `/team-setup`; `before_plan` hook mention removed). Explanatory spec-kit comparisons in `team-constitution`, `levelup-*`, and `workflow/mission-brief` left intact.

### Changed (MADR Alignment)

- **Architect ADRs aligned to [MADR 3.0.0](https://adr.github.io/madr/)**: `adr-template.md` rewritten across all 5 architect skills (specify/init/clarify/implement/analyze). Added YAML frontmatter (status, date, decision-makers, consulted, informed, sub-system, superseded-by — MADR-0013); H1 title (no numbers in headings — MADR-0002); explicit Considered Options list; Decision Outcome + Consequences (Good/Bad/Neutral, MADR v3.0.0 merged) + Confirmation; Pros and Cons of the Options with per-option Good/Bad/Neutral arguments (MADR-0014); More Information; links between ADRs (MADR-0009); asterisk list markers (MADR-0011); `rejected` status (MADR-0008).
- **Project extensions retained**: `sub-system` frontmatter field (MADR-0010 categories equivalent); `discovered` status (brownfield reverse-engineering via `/architect-init`); Constitution Alignment + Related ADRs sections.
- **Filename convention**: `ADR-{NNN}.md` kept (MADR-0005 explicitly permits other patterns); stable numeric ID used by `adr.md` index, supersession refs, and architect skills.
- **`setup-architect.sh`** (all 5 copies): `generate_adr_index` now parses MADR frontmatter + H1 title via new `parse_fm_field`/`parse_fm_title` helpers instead of prose `### Status`/`### Date`/`### Owner`/`### Sub-System` sections. Index column renamed `Owner` → `Decision Makers` (populated from `decision-makers` frontmatter). Sub-system extraction in view generation also reads frontmatter.
- **`setup-architect.ps1`** (all 5 copies): fixed stale monolith `adr.md` path assumptions — ADR count now uses `Get-ChildItem -Filter "ADR-*.md"` (was `Get-Content $adrDir -Raw` on a directory + `^## ADR-` regex that no longer matches the H1 title format). Sub-system extraction reads the generated `adr.md` index file.
- **`architect-specify/SKILL.md` + `architect-init/SKILL.md`**: ADR Format examples updated to MADR frontmatter + sections.

## [0.9.1] - 2026-07-22

### Changed

- **Moved `product-*` and `architect-*` skills** from `skills/team/` to `skills/workflow/` — product and architecture skills now live in their own top-level directory parallel to `team/`. Skill names, frontmatter, and command references unchanged. Re-install required: `npx skills add tikalk/adlc-team-skills`.
- **README.md** rewritten to mattpocock/skills style: problem-first quickstart, 12-factor-oriented rationale sections, reference with user-invoked/model-invoked split, collapsible details for output layout, OKF compliance, workflows, and 12-factor alignment.
- **`team-boot`** no longer falls back to `.adlc/drafts/` for PDR/ADR indexes — accepted (memory) decisions only. PDR: memory → legacy PRD.md heading skim → none. ADR: memory → none.

## [0.9.0] - 2026-07-22

### Added

- **New skill: `team-constitution`** — interactively create or amend the team constitution in team-ai-directives. Detects the scaffold placeholder ("No team-wide principles defined yet") for create mode, or reviews existing principles in amend mode. Ports the interactive elicitation flow from spec-kit's `spec.constitution` without the SDD machinery (no hooks, no template tokens, no template propagation). Output uses the established team format: OKF frontmatter + numbered principles + lightweight Governance section; versioning is git history, not semantic version stamps.
- **PDR/ADR index loading in `team-boot`**: new Step 3 (Load Product & Architecture Context) reads `.adlc/memory/pdr/pdr.md` and `.adlc/memory/adr/adr.md` (drafts fallback) for awareness-level product/architecture context. Legacy fallback: heading-level skim of monolithic `PRD.md` when no PDR index exists. Full PRD/AD bodies and individual PDR/ADR records are never loaded during boot.
- **PDR/ADR matching in `team-discover`**: new Step 3b (Load Project Decision Indexes) matches project PDRs and ADRs against the feature context alongside team CDR matching. Output table gains `Type: PDR` / `Type: ADR` rows; High-relevance records load inline bodies; `search_metadata` reports per-source counts.
- Setup scripts for `team-constitution` (bash + PowerShell) outputting `CONSTITUTION_STATE` (`missing`|`placeholder`|`populated`), `TD_IS_GIT`, `TD_CLEAN`.
- **Four-layer milestone model** in `product-roadmap`: tracks Decision (PDR status) + Execution (live issue states via MCP) + Evidence (code-vs-PDR verification) + Gates (milestone acceptance criteria). A milestone is "live" only when all four layers are green.
- **Issue-driven progress**: PDRs can carry `### Issues` sections with full URLs. Roadmap queries live issue states via MCP tools (GitHub / GitLab / Jira / Linear) with CLI fallback and graceful degradation. Optional `### Tracker Milestone` link pulls native tracker progress directly.
- **Code-vs-PDR verification** (init concept): PDRs can carry `### Evidence` sections with code paths/symbols. Roadmap verifies paths exist (Mode A: explicit). Fallback to heuristic directory detection (Mode B: init-style). Missing evidence on "Completed" items triggers done-means warnings with hand-off suggestion to `/product.init`.
- **Gate model**: Milestone PDRs can declare `### Gates` tables (type: engineering/sign-off/time, owner, criterion, status, evidence). Roadmap rolls up gate states; `--update` blocks milestone completion when gates are pending.
- **Done-means warnings**: Milestone PDRs carry a `### Done Means` field defining what "live" means explicitly. Roadmap warns when layers disagree with the claimed completion state.
- PDR template updated: `### Issues`, `### Evidence`, `### Gates`, `### Done Means`, `### Tracker Milestone` fields added to `pdr-file-template.md`.
- `product-implement` PRD §11 gains `### 11.2 Milestone Gates & Progress` subsection.

### Changed

- `team-boot`: steps renumbered (Run Discovery → Step 4, Acknowledge → Step 5); acknowledgment now reports index entry counts; description, verification, and red flags updated for decision-record loading.
- `team-discover`: description, output table docs, and verification updated for PDR/ADR matching.
- `team-setup` Mode 3: scaffold follow-up now directs the user to run `/team-constitution` to fill the placeholder constitution; file table notes the placeholder's purpose.
- `team-helpers.sh` / `.ps1`: team AI directives AGENTS.md templates (scaffold + agents-only) now list the `traces/` directory.
- README: Team Directives table (5 → 6 skills), `team-boot`/`team-discover` row updates, skill count fix (22 skills), Output section gains memory-scope PDR/ADR index entries.
- `product-roadmap` description updated to reflect four-layer tracking model.
- `product-roadmap` `--update` semantics: blocks on pending issues, missing evidence, or pending gates unless explicit override.
- Backward compatible: PDRs without gates/issues/evidence work as before (reported with hints to adopt the new fields).

### Fixed

- CHANGELOG duplicate `## [0.8.0]` section — the Product skills entry is now correctly numbered `## [0.8.1]`.

## [0.8.1] - 2026-07-22

### Added

- `levelup-publish` now publishes the session trace to the team AI directives alongside context modules and skills. The trace is copied from `.adlc/drafts/trace.md` to `traces/{BRANCH}.md` in the team AI directives, following the `spec.trace` branch-based naming convention.
- `--skip-trace` flag on `levelup-publish` to opt out of trace publication (useful for the brownfield `levelup-init` path where no implementation session exists).
- If no trace exists when `levelup-publish` runs, it invokes `/levelup-trace` to generate one before publishing.
- New Phase 6 (Session Trace Publication) in `levelup-publish` — phases renumbered (6→7→8→9→10→11).
- `traces/` directory in the team AI directives output.
- `TRACE_FILE` and `TRACE_EXISTS` fields in `setup-levelup-publish.sh` / `.ps1` JSON output.

### Changed

- `levelup-publish` description updated to mention session trace publication.
- `levelup-publish` commit message template now includes the trace path.
- `levelup-publish` summary report includes a Traces row in the Artifacts Created table.
- `levelup-publish` verification checklist includes trace publication check.
- README LevelUp skills table and team AI directives output section updated to reflect trace publication.

## [0.8.0] - 2026-07-22

### Added

- **6 new Product skills** under `skills/workflow/product-*`: `product-init`, `product-specify`, `product-clarify`, `product-implement`, `product-analyze`, `product-roadmap`. Ported from `agentic-sdlc-spec-kit/extensions/product/` with all spec-kit dependencies removed.
- **PDR individual-file format**: PDRs are now stored as individual `PDR-{NNN}.md` files in `.adlc/drafts/pdr/` (mirroring architect ADR and levelup CDR patterns), with an auto-generated `pdr.md` index. Accepted PDRs are promoted to `.adlc/memory/pdr/` on implement.
- Product templates: `pdr-file-template.md`, `prd-template.md`, 15 section templates, 3 subagent prompt templates — all under `skills/workflow/product-templates/` and `skills/workflow/product-implement/templates/`.
- Validation scripts: `validate-pdr.sh` and `validate-prd.sh` under `product-implement/scripts/bash/`.
- README: new Product / PDR Lifecycle section, updated 12-Factor table (Factor III added), updated Output section with PDR/PRD paths, full lifecycle diagram.

### Changed

- **Moved `architect-*` skills** from `skills/architect/` to `skills/team/` — all guardrails and directive lifecycles now live in one group. Skill names unchanged; no user action required.
- `product-implement` PDR lifecycle: Accepted PDRs are **moved** from `.adlc/drafts/pdr/` to `.adlc/memory/pdr/` (was: copied to monolithic `.specify/memory/pdr.md`).
- `product-roadmap`: milestone tracking derived from PDR status fields only (feature-spec reading from `specs/*/` removed).

### Removed

- `product-validate` (feature-spec validation against PRD) — purpose disappears when stripping feature-spec reading; PDR↔PRD consistency covered by `product-analyze`.
- `product-link` (PDR linker for spec-kit hooks) — existed only to feed the `before_specify` hook.
- `extension.yml` — spec-kit extension manifest; not needed in Agent Skills format.
- All `.specify/` paths → `.adlc/`, all `/spec.specify` references removed, all hook references removed.

## [0.7.0] - 2026-07-22

### Added

- **OKF compliance**: Generated context modules now include OKF v0.1 fields (`resource`, `tags`, `timestamp`) alongside custom fields in YAML frontmatter.
- `team-repair` now generates OKF-compliant `index.md` (progressive disclosure) and `log.md` (chronological change history) per context module directory (`rules/`, `personas/`, `examples/`).
- `team-setup` scaffold now includes OKF `index.md` files for each context module directory (14 files instead of 10).
- `team-helpers.sh` and `team-helpers.ps1` scaffold templates updated with OKF frontmatter and index.md files.
- OKF compliance section in README.

### Changed

- `levelup-publish` frontmatter template now generates OKF fields: `resource` (relative path), `tags` (context type), `timestamp` (ISO 8601 datetime).
- `team-repair` output section updated to include index.md/log.md generation (was 9 phases, now 10).
- `team-repair` summary report includes OKF index/log generation counts.
- `team-repair` repair targets table includes OKF index.md and log.md targets.
- `team-repair` freshness phase now updates `timestamp` field alongside `verified`.
- Scaffold file count: 10 → 14 (4 new index.md files).

## [0.6.0] - 2026-07-21

### Added

- New skill: `levelup-trace` — generates a session execution trace from the current agent session (not from spec-kit artifacts). Captures what the agent did, decisions made, files changed, and reusable patterns. Output: `.adlc/drafts/trace.md`.

### Changed

- **Renamed** `levelup-implement` → `levelup-publish` to clarify its purpose (publishing CDRs to the team AI directives, not implementing features).
- **Decoupled `levelup-specify` from spec-kit**: primary source is now the session trace (from `levelup-trace`) or direct session review. Removed all spec-kit artifact reading (`spec.md`, `plan.md`, `tasks.md`, `specs/` directory search). No spec-kit dependency.
- `levelup-specify` setup scripts no longer search for feature directories or spec-kit artifacts.
- `levelup-specify` setup scripts now output `TRACE_FILE` path (`.adlc/drafts/trace.md`).
- CDR lifecycle updated: `levelup-trace → levelup-specify → levelup-clarify → levelup-publish`.
- README updated: 5 LevelUp skills (was 4), session-based workflow, renamed references.

### Removed

- `levelup-specify` no longer reads `specs/{feature}/spec.md`, `plan.md`, `tasks.md`, or `tasks_meta.json`.
- `levelup-specify` setup scripts no longer detect feature directories or search `specs/` subdirectories.
- `--feature NAME` flag removed from `levelup-specify` (no longer needed — session-based, not feature-artifact-based).

## [0.5.1] - 2026-07-21

### Changed

- Default team-ai-directive path changed from `.adlc/team-ai-directives` to `team-ai-directives` (repo root) across all scripts, helpers, and SKILL.md files.
- `team-setup` Mode 1 clone default destination: `./.adlc/team-ai-directives` → `./team-ai-directives`.
- `team-setup` Mode 3 scaffold default: "current directory" → `./team-ai-directives`.

### Added

- `levelup-specify` Phase 6 Summary now includes a prominent **Handover** section with handoff JSON context, directing the agent to run `/levelup-clarify` next.

## [0.5.0] - 2026-07-21

### Fixed

- **Critical**: All 4 levelup setup scripts (`setup-levelup-{specify,clarify,implement,init}.sh`) are now self-contained — no dependency on the missing `levelup-helpers.sh`. Inline path resolution, CDR numbering, and grep logic.
- **Critical**: CDR format changed from two-line fields (`### Status\n**Accepted**`) to single-line (`### Status: **Accepted**`). All grep patterns updated to match.
- **Critical**: Fixed `regenerate_cdr_index` in `levelup-helpers.sh` to extract fields from single-line format; added `|| true` to prevent `set -e` exit on missing optional fields.
- `team-setup` Mode 3 now runs `git init` + initial commit, enabling `/levelup-implement` branch/commit/PR flow.
- `levelup-helpers.sh` team-helpers path now tries multiple candidate paths (source repo + installed flat layout).
- Fixed `set -euo pipefail` crash when no CDR files exist (ls/grep return non-zero on no matches).
- Fixed wrong script paths in SKILL.md files (`skills/levelup/...` → `scripts/bash/...` relative to skill base dir).

### Changed

- Standardized all parameter naming to `TEAM_AI_DIRECTIVE` (env var), `team_ai_directive` (JSON field), `$TeamAiDirective` (PowerShell variable), `resolve_team_ai_directive` (bash function). Removed `ADLC_` prefix, made singular. 0 old-pattern refs remain.
- Replaced `levelup-helpers.sh --index` references in SKILL.md with inline index generation instructions.
- Replaced `levelup-helpers.sh --signal-gate` reference with inline 4-criteria semantic evaluation.
- `levelup-implement` Phase 9: added git decision tree (Case A: git repo with remote/`gh`/no-remote fallbacks; Case B: not git repo with `git init` or write-only options).
- `levelup-clarify`: added option D ("Accept all remaining") for bulk accept.
- `levelup-specify`: feature detection now searches `{REPO_ROOT}/specs/` and `{REPO_ROOT}/*/specs/` for monorepo layouts.
- Removed unused `{tags}` from `levelup-implement` frontmatter template.
- All PowerShell variables standardized to PascalCase convention.

### Added

- PowerShell setup scripts for all 4 levelup skills (`setup-levelup-{specify,clarify,implement,init}.ps1`).
- Rewritten `team-repair` and `team-skills` PowerShell setup scripts with `TEAM_AI_DIRECTIVE` env var support.
- "12-Factor Alignment" section in README: Factor XI (Directives as Code), Factor XII (Team Capability), Factor IV, IX, X.
- Setup script fallback instructions in all 4 levelup SKILL.md files.
- `git init` verification checkbox and red flag in `team-setup` SKILL.md.
- `TD_IS_GIT` field in `setup-levelup-implement.sh` output.

### Removed

- All `hermes-project` references replaced with generic monorepo language.
- `levelup-helpers.sh` / `team-helpers.sh` dependency removed from all 4 levelup setup scripts.

## [0.4.1] - 2026-07-21

### Changed

- README reorganized: team skills now appear first (Team Directives → LevelUp → Architecture) across intro, Available Skills, Output, and former Usage/Workflows sections.
- Workflow blocks attached under each skill group; standalone `### Workflows` section removed.
- Added "Say" trigger column to each skills table; standalone `### Usage` section removed.
- Removed `## Scripts & Templates` section.

## [0.4.0] - 2026-07-21

### Added

- Four new LevelUp skills under `skills/team/` aligned with the architect-* workflow:
  - `levelup-init` — brownfield CDR discovery from codebase.
  - `levelup-specify` — greenfield CDR extraction from feature implementation context.
  - `levelup-clarify` — interactive review/accept/reject/defer of CDRs.
  - `levelup-implement` — compile accepted CDRs into team-ai-directives artifacts and create a draft PR.
- Shared `levelup-helpers.sh` / `levelup-helpers.ps1` under `skills/team/` — CDR numbering, index generation, signal gate, and rule-conflict scanning.
- CDRs stored as individual files `.adlc/drafts/cdr/CDR-{NNN}.md` with auto-generated `.adlc/drafts/cdr/cdr.md` index.
- `team-repair` conflict scanning and freshness verification (from former `/levelup.validate`).
- `team-repair` flags: `--validate`, `--conflicts`, `--freshness`.

### Changed

- `team-repair` description updated to include conflict scanning and freshness verification.
- `README.md` reorganized with separate LevelUp / CDR Lifecycle section.

## [0.3.0] - 2026-07-20

### Added

- New skill: `team-setup` — interactive team AI directives setup with 4 modes (clone, local path, scaffold, check).
- Shared `team-helpers.sh` / `team-helpers.ps1` — merged path resolution, team AI directives validation, and 11-file scaffold.
- `team-repair` Phase 0: Health Check (7 verification checks) merged from `team-verify`.
- `--health-only` flag on `team-repair`.
- `Configuration` sections documenting `TEAM_AI_DIRECTIVE` env var on all 5 team skills.

### Changed

- `team-skills` → user-invoked (`disable-model-invocation: true`).
- `team-repair` references `team-helpers.sh` instead of `scripts/bash/setup-team.sh`.
- Env var renamed from `SPECIFY_TEAM_DIRECTIVES` → `TEAM_AI_DIRECTIVE`.
- Team skill phases renumbered (Phase 0: Health Check, phases 1-8 for existing repair steps).
- Mode 3 default path changed from `./.adlc/team-ai-directives` to current directory.

### Removed

- `team-curate` — not production ready.
- `team-evolve` — not production ready.
- `team-verify` — merged into `team-repair` as Phase 0.
- `manifest.yml` from scaffold — orphaned metadata from abandoned draft PR #104.

## [0.2.0] - 2026-07-18

### Added

- Seven team-ai-directives skills: `team-boot`, `team-discover`, `team-curate`, `team-evolve`, `team-repair`, `team-skills`, `team-verify`.
- Model-invoked skills (`team-boot`, `team-discover`, `team-skills`) for automatic session bootstrap and context discovery.
- User-invoked skills (`team-curate`, `team-evolve`, `team-repair`, `team-verify`) for CDR lifecycle management.
- Bundled `setup-team.sh` and `setup-team.ps1` scripts in `team-repair` and `team-skills`.
- Unified `{TEAM_DIRECTIVES}` variable naming across all team skills.
- 12-Factor Alignment notes on each skill (Factor XI: Directives as Code, Factor XII: Team Capability).
- Common Rationalizations and Red Flags sections on all team skills.

### Changed

- `.specify/` → `.adlc/` across all team skills and scripts.

## [0.1.0] - 2026-07-17

### Added

- Initial externalization of architect extension capabilities into standalone Agent Skills.
- Five user-invoked architecture skills: `architect-init`, `architect-specify`, `architect-clarify`, `architect-implement`, `architect-analyze`.
- Bundled bash and PowerShell setup scripts and ADR/AD view templates.
- `npx skills add tikalk/adlc-team-skills` installation support.
