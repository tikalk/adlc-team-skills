# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
