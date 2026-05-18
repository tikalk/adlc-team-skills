# Changelog

All notable changes to the Product extension will be documented in this file.

## [1.1.11] - 2026-04-30

### Fixed

- **Fragile path sourcing**: Fixed bash and PowerShell scripts using fragile relative paths to source common.sh.

## [1.1.10] - 2026-04-23

### Changed

- **Removed team-ai-directives integration**: PDRs now stored only in `.specify/drafts/` and `.specify/memory/`, PRD.md now always outputs to project root

## [1.1.9] - 2026-04-19

### Fixed

- **Auto-handoff to clarify**: Changed `send: false` to `send: true` in init.md and specify.md for automatic validation of discovered PDRs

### Changed

- `/product.init` now auto-triggers `/product.clarify` to validate brownfield findings
- `/product.specify` now auto-triggers `/product.clarify` to validate greenfield decisions

## [1.1.8] - 2026-04-13

### Fixed

- **Script path resolution**: Fixed session execution failures by using fully-qualified paths in command files
  - Changed from relative `scripts/bash/setup-product.sh` to `.specify/extensions/product/scripts/bash/setup-product.sh`

## [1.1.7] - 2026-04-13

### Added

- **New command `adlc.product.link`**: Lightweight PDR linking for `before_specify` hook
  - Checks for PDRs in team-directives, memory, and drafts locations
  - **Silent exit** if no PDRs exist (eliminates noisy AI output)
  - Presents selection table if PDRs exist
  - Designed for hook use to eliminate "No PDR file found" noise

### Changed

- **`before_specify` hook**: Changed from `adlc.product.specify` to `adlc.product.link`
  - Old command was full interactive exploration (~535 lines), too noisy for hook
  - New command exits silently if no PDRs, reducing spurious AI output

## [1.1.6] - 2026-04-13

### Changed

- **Hook event names**: Renamed hooks to align with upstream template convention
  - `before_spec` → `before_specify`
  - `after_spec` → `after_specify`
  - Matches naming in `templates/commands/specify.md` and `EXTENSION-API-REFERENCE.md`

## [1.1.5] - 2026-04-11

### Fixed

- **Template path resolution**: Updated all command templates to use `{REPO_ROOT}` prefix for `.specify/` paths
- **Monorepo support**: Templates now correctly resolve paths when running from subdirectories

## [1.1.1] - 2026-04-11

### Fixed

- **.specify directory detection**: Scripts now properly search upward for `.specify` directory instead of using git root directly

## [1.1.0] - 2026-04-10

### Added

- **Multi-agent DAG orchestration** for `/product.implement` command
  - Three-phase workflow: Plan → Execute → Summarize
  - State persistence in `.specify/product/state.json` for resumability
  - Per-section outputs in `.specify/product/sections/{feature-area}/{section}.md`
  - Works with any AI agent (Claude, Copilot, Cursor, etc.)

- **Section templates** extracted from prd-template.md:
  - `templates/sections/overview.md` - Overview section template
  - `templates/sections/problem.md` - Problem section template
  - `templates/sections/goals.md` - Goals/Objectives section template
  - `templates/sections/metrics.md` - Success Metrics section template
  - `templates/sections/personas.md` - Personas section template
  - `templates/sections/requirements.md` - Functional Requirements section template
  - `templates/sections/nfrs.md` - Non-Functional Requirements section template
  - `templates/sections/out-of-scope.md` - Out of Scope section template
  - `templates/sections/risks.md` - Risks & Mitigation section template
  - `templates/sections/roadmap.md` - Roadmap & Milestones section template
  - `templates/sections/pdr-summary.md` - PDR Summary section template

- **New script actions** for DAG workflow:
  - `plan-dag` - Phase 1: Generate DAG execution plan for user approval
  - `execute-dag` - Phase 2: Execute DAG to generate sections per feature-area
  - `summarize` - Phase 3: Aggregate sections into unified PRD.md

- **DAG customization rules** based on feature-area characteristics:
  - B2B Focus → Expand Personas, NFRs earlier
  - B2C Focus → Prioritize UX in Requirements
  - Platform → Technical Requirements first
  - Data-heavy → Metrics section priority
  - Marketplace → Multiple Persona branches

### Changed

- **`/product.implement`** completely rewritten with DAG orchestration
  - Feature-area detection from PDR index table
  - Dependency context passing between sections
  - Cross-feature-area conflict resolution using PDRs as source of truth
  - Unified PRD.md generation from per-section outputs

- **extension.yml** updated with DAG configuration:

  ```yaml
  dag:
    enabled: true
    base_location: ".specify/product/"
    state_location: ".specify/product/state.json"
    sections_location: ".specify/product/sections/"
    section_templates: "templates/sections/"
  ```

### Migration

- Existing projects: No action needed (DAG workflow is opt-in via `/product.implement`)
- Previous single-context generation still works if state.json doesn't exist

## [1.0.2] - 2026-04-09

### Changed

- **Removed hardcoded architect handoff**: External extension integration now via hooks only
  - Removed handoff from `product.implement` to `architect.specify` in extension.yml
  - Architect integration now configured in project-level `.specify/extensions.yml`
  - Ensures extensions are fully decoupled - architect only referenced if installed

### Migration

- Existing projects: Architect integration now requires explicit configuration in `.specify/extensions.yml`
- See README.md for hook configuration examples

## [1.0.1] - 2026-03-20

### Changed

- **PDR lifecycle alignment** with architect extension pattern
  - `extension.yml`: Added explicit `drafts_location` and `memory_location` keys
  - `extension.yml`: Added lifecycle documentation comment
  - `commands/implement.md`: Renamed "Cleanup Phase" to "Phase 6: PDR Lifecycle Management"
  - `commands/implement.md`: Added structured lifecycle steps matching architect pattern
  - `templates/pdr-template.md`: Updated integration section with 3-location model

### Migration

- Existing projects: No action needed (changes are additive/non-breaking)
- PDR files in `.specify/drafts/pdr.md` continue to work as before

## [1.0.0] - 2026-03-09

### Added

- Initial release of Product extension

#### Commands

- `adlc.product.specify` - Interactive PRD exploration for greenfield products
- `adlc.product.init` - Brownfield discovery from existing products
- `adlc.product.clarify` - Refine and validate PDRs
- `adlc.product.implement` - Generate PRD from PDRs
- `adlc.product.analyze` - Validate PDR-PRD consistency
- `adlc.product.validate` - Validate feature spec alignment with PRD

#### Templates

- `templates/pdr-template.md` - Product Decision Record template
- `templates/prd-template.md` - Product Requirements Document template (9 sections)

#### Configuration

- `config-template.yml` - Extension configuration

#### Hooks

- `before_spec` - Trigger `/product.specify` before feature specification
- `after_spec` - Trigger `/product.validate` after feature specification

#### Features

- Two-level product system (Product + Feature)
- Feature area decomposition for complex products
- PDR categories: Problem, Persona, Scope, Metric, Prioritization, Business Model, Feature, NFR
- Constitution integration for vision/strategy constraints
- PDR traceability throughout PRD
- Read-only validation commands

---

## Upgrade Notes

### From 0.x

This is the initial release. No upgrade path needed.

## Future Considerations

- Template customization per industry (SaaS, E-commerce, etc.)
- Integration with product management tools (Jira, Productboard)
- Export to common formats (Markdown, Confluence, HTML)
- PDR review workflow automation
