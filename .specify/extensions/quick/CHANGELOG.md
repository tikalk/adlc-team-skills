# Changelog

All notable changes to the Quick Extension will be documented in this file.

## [1.1.0] - 2026-05-15

### Changed

- **BREAKING: Per-task auto-commits replaced with hook dispatch**: `quick.implement` no longer hardcodes `git add -A && git commit` after each task. Instead, it dispatches `before_task_execute` / `after_task_execute` extension hooks using the standard hook mechanism.
  - To restore auto-commit behavior: install the git extension and set `after_task_execute.enabled: true` in `.specify/extensions/git/git-config.yml`
  - This enables any extension to hook into per-task execution (commits, tests, lint, etc.)
- **WIP commits on error now hook-driven**: Error handling dispatches `after_task_execute` hooks instead of hardcoded git commands, allowing configurable WIP checkpoint behavior
- Updated Design Principles and Critical Constraints to reflect hook-driven architecture

## [1.0.4] - 2026-05-11

### Fixed

- **Hook execution compliance**: Restructured hook sections in `implement.md` to use "Pre-Execution Checks" pattern
  - Root cause: Agents were skipping prose hook instructions because they treated them as informational text
  - Changed from loose prose to numbered steps with explicit MUST/CRITICAL language
  - Added visual indicators (🔴 MANDATORY, ⚠️ WARNING) to improve visibility
  - Matches the pattern used in preset commands that have better agent compliance

## [1.0.3] - 2026-05-11

### Added

- **Extension hook support**: `quick.implement` now checks for `before_implement` and
  `after_implement` extension hooks. This enables TDD and other extensions to integrate
  with the quick workflow without requiring file artifacts.
- **TDD integration**: When the TDD extension is installed, running `/quick.implement`
  automatically triggers TDD's RED→GREEN→REFACTOR workflow via the `before_implement` hook.
  TDD runs entirely in-session with no file artifacts, preserving quick's philosophy.

### Changed

- Added "Extension Hooks (before implementation)" section after Task Breakdown
- Added "Extension Hooks (after implementation)" section after task completion
- Hook checking uses the same prose pattern as standard spec commands for consistency

## [1.0.2] - 2026-05-07

### Fixed

- Hook execution deadlock: Updated hook execution pattern to match TDD extension fix

## [1.0.1] - 2026-04-13

### Changed

- Mission Brief pattern aligned with spec.specify preset
- Added "mode: quick" frontmatter for Copilot skill generation

## [1.0.0] - 2026-03-07

### Added

- Initial release of Quick Extension
- Session-based ad-hoc task execution via `/quick.implement`
- Low-friction 1-stop workflow (Mission Brief only)
- Task-level commits as checkpoints
- Auto-proceed between tasks with no pauses
- Error handling with WIP commits
- No file artifacts philosophy

### Features

- 3-question Mission Brief (Goal, Success Criteria, Constraints)
- Brief Context Discovery phase
- Auto-generated Task Breakdown
- Sequential task execution with git commits
- Error recovery with user decision points
