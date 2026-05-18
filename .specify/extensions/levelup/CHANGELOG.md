# Changelog

All notable changes to the LevelUp extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.8] - 2026-04-30

### Fixed

- **Fragile path sourcing**: Fixed bash and PowerShell scripts using fragile relative paths to source common.sh. Now uses robust project-root-finding pattern that works regardless of script location.

## [1.1.7] - 2026-04-19

### Fixed

- **Auto-handoff to clarify**: Changed `send: false` to `send: true` in init.md (clarify handoff) and validate.md for automatic validation of discovered CDRs

### Changed

- `/adlc.levelup.init` now auto-triggers `/adlc.levelup.clarify` to validate discovered patterns
- `/adlc.levelup.validate` now auto-triggers `/adlc.levelup.clarify` to resolve conflicts

## [1.1.6] - 2026-04-13

### Fixed

- **Script path resolution**: Fixed session execution failures by using fully-qualified paths in command files
  - Changed from relative `scripts/bash/setup-levelup.sh` to `.specify/extensions/levelup/scripts/bash/setup-levelup.sh`

## [1.1.5] - 2026-04-11

### Fixed

- **Template path resolution**: Updated command templates to use `{REPO_ROOT}` prefix for `.specify/` paths
- **Team directives placeholder**: Changed relative `context_modules/` paths to use `{TEAM_DIRECTIVES}` prefix
- **Monorepo support**: Templates now correctly resolve paths when running from subdirectories

## [1.1.1] - 2026-04-11

### Fixed

- **.specify directory detection**: All scripts now use `get_repo_root()` from common.sh to properly locate `.specify` directory when running from subdirectories

## [1.1.0] - 2026-04-04

### Added

- **Skill Types Taxonomy** (Issue #84): Added 9-category skill type taxonomy from Anthropic's "Lessons from Building Claude Code: How We Use Skills"
  - `cdr-template.md`: Added Skill Type field with taxonomy table
  - `extension.yml`: Added `type` field to CDR defaults
  - `README.md`: Added Skill Types Taxonomy section with descriptions
  - `init.md`: Added Skill Type Classification phase during CDR discovery

- **Rule Conflict Detection** (Issue #68): Added rule conflict detection capabilities
  - `validate.md`: New command for scanning team-ai-directives for conflicts
  - `validate-directives.sh`: Main validation script with JSON/Markdown output
  - `validate-rule-conflicts.sh`: Helper script for detecting conflict types
  - `conflict-cdr-template.md`: Template for conflict resolution CDRs
  - `conflict-report-template.md`: Template for conflict reports
  - `clarify.md`: Added conflict detection phase (Questions 11-13) for rule CDRs
  - `extension.yml`: Registered `levelup.validate` command with handoffs

### Changed

- `clarify.md`: Updated status determination logic to account for conflict detection
- `README.md`: Added `/levelup.validate` to commands table and updated flow diagram
- Updated version to 1.1.0

## [1.0.0] - 2026-03-03

### Added

- Initial release of LevelUp extension
- `levelup.init` command for brownfield CDR discovery
- `levelup.clarify` command for resolving CDR ambiguities
- `levelup.specify` command for refining CDRs from feature context
- `levelup.skills` command for building skills from accepted CDRs
- `levelup.implement` command for creating PRs to team-ai-directives
- Context Directive Record (CDR) template
- Support for both submodule and clone paths for team-ai-directives
- Bash and PowerShell scripts for setup and analysis

### Related

- GitHub Issue: [#56](https://github.com/tikalk/agentic-sdlc-spec-kit/issues/56)
- Replaces monolithic `/spec.levelup` command
