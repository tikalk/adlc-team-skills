# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2026-07-22

### Added

- **New skill: `team-constitution`** — interactively create or amend the team constitution in team-ai-directives. Detects the scaffold placeholder ("No team-wide principles defined yet") for create mode, or reviews existing principles in amend mode. Ports the interactive elicitation flow from spec-kit's `spec.constitution` without the SDD machinery (no hooks, no template tokens, no template propagation). Output uses the established team format: OKF frontmatter + numbered principles + lightweight Governance section; versioning is git history, not semantic version stamps.
- **PDR/ADR index loading in `team-boot`**: new Step 3 (Load Product & Architecture Context) reads `.adlc/memory/pdr/pdr.md` and `.adlc/memory/adr/adr.md` (drafts fallback) for awareness-level product/architecture context. Legacy fallback: heading-level skim of monolithic `PRD.md` when no PDR index exists. Full PRD/AD bodies and individual PDR/ADR records are never loaded during boot.
- **PDR/ADR matching in `team-discover`**: new Step 3b (Load Project Decision Indexes) matches project PDRs and ADRs against the feature context alongside team CDR matching. Output table gains `Type: PDR` / `Type: ADR` rows; High-relevance records load inline bodies; `search_metadata` reports per-source counts.
- Setup scripts for `team-constitution` (bash + PowerShell) outputting `CONSTITUTION_STATE` (`missing`|`placeholder`|`populated`), `TD_IS_GIT`, `TD_CLEAN`.

### Changed

- `team-boot`: steps renumbered (Run Discovery → Step 4, Acknowledge → Step 5); acknowledgment now reports index entry counts; description, verification, and red flags updated for decision-record loading.
- `team-discover`: description, output table docs, and verification updated for PDR/ADR matching.
- `team-setup` Mode 3: scaffold follow-up now directs the user to run `/team-constitution` to fill the placeholder constitution; file table notes the placeholder's purpose.
- `team-helpers.sh` / `.ps1`: KB AGENTS.md templates (scaffold + agents-only) now list the `traces/` directory.
- README: Team Directives table (5 → 6 skills), `team-boot`/`team-discover` row updates, skill count fix (22 skills), Output section gains memory-scope PDR/ADR index entries.

### Fixed

- CHANGELOG duplicate `## [0.8.0]` section — the Product skills entry is now correctly numbered `## [0.8.1]`.

## [0.8.1] - 2026-07-22

### Added

- `levelup-publish` now publishes the session trace to the team-ai-directives KB alongside context modules and skills. The trace is copied from `.adlc/drafts/trace.md` to `traces/{BRANCH}.md` in the KB, following the `spec.trace` branch-based naming convention.
- `--skip-trace` flag on `levelup-publish` to opt out of trace publication (useful for the brownfield `levelup-init` path where no implementation session exists).
- If no trace exists when `levelup-publish` runs, it invokes `/levelup-trace` to generate one before publishing.
- New Phase 6 (Session Trace Publication) in `levelup-publish` — phases renumbered (6→7→8→9→10→11).
- `traces/` directory in the team-ai-directives KB output.
- `TRACE_FILE` and `TRACE_EXISTS` fields in `setup-levelup-publish.sh` / `.ps1` JSON output.

### Changed

- `levelup-publish` description updated to mention session trace publication.
- `levelup-publish` commit message template now includes the trace path.
- `levelup-publish` summary report includes a Traces row in the Artifacts Created table.
- `levelup-publish` verification checklist includes trace publication check.
- README LevelUp skills table and KB output section updated to reflect trace publication.

## [0.8.0] - 2026-07-22

### Added

- **6 new Product skills** under `skills/team/product-*`: `product-init`, `product-specify`, `product-clarify`, `product-implement`, `product-analyze`, `product-roadmap`. Ported from `agentic-sdlc-spec-kit/extensions/product/` with all spec-kit dependencies removed.
- **PDR individual-file format**: PDRs are now stored as individual `PDR-{NNN}.md` files in `.adlc/drafts/pdr/` (mirroring architect ADR and levelup CDR patterns), with an auto-generated `pdr.md` index. Accepted PDRs are promoted to `.adlc/memory/pdr/` on implement.
- Product templates: `pdr-file-template.md`, `prd-template.md`, 15 section templates, 3 subagent prompt templates — all under `skills/team/product-templates/` and `skills/team/product-implement/templates/`.
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

- **Renamed** `levelup-implement` → `levelup-publish` to clarify its purpose (publishing CDRs to the KB, not implementing features).
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

- New skill: `team-setup` — interactive KB setup with 4 modes (clone, local path, scaffold, check).
- Shared `team-helpers.sh` / `team-helpers.ps1` — merged path resolution, KB validation, and 11-file scaffold.
- `team-repair` Phase 0: Health Check (7 verification checks) merged from `team-verify`.
- `--health-only` flag on `team-repair`.
- `Configuration` sections documenting `ADLC_TEAM_AI_DIRECTIVES` env var on all 5 team skills.

### Changed

- `team-skills` → user-invoked (`disable-model-invocation: true`).
- `team-repair` references `team-helpers.sh` instead of `scripts/bash/setup-team.sh`.
- Env var renamed from `SPECIFY_TEAM_DIRECTIVES` → `ADLC_TEAM_AI_DIRECTIVES`.
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
