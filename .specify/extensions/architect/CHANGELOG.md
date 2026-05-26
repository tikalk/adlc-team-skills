# Changelog

All notable changes to the Architect extension will be documented in this file.

## [2.1.0] - 2026-05-20

### Added

- **Functional View template**: Technology Abstraction Rule and validation checklist
  - Added explicit instruction to use architectural roles (Database, Object Storage) not product names
  - Added forward cross-reference to Development View §3.5.2
  - Added 5-point validation checklist for technology neutrality
- **Development View template**: Enhanced structure for technology mapping
  - Added §3.5.2 Technology Stack Mapping table (role → technology → ADR)
  - Added §3.5.3 Technology Architecture diagram with concrete technology labels
  - Added backward cross-reference to Functional View §3.2
  - Added 5-point validation checklist for view parity
- **Analyze Pass E.6**: Technology Neutrality check
  - Scans Functional View for product/vendor names in elements and diagrams
  - Distinguishes architectural roles (acceptable) from product names (flagged)
  - Severity: MEDIUM (reported, not blocking)
- **Analyze Pass E.7**: Functional-Development Mapping check
  - Verifies Technology Stack Mapping table exists in Development View
  - Checks that Functional View elements have corresponding mapping entries
  - Supports N:1 mappings (multiple elements → one technology)
  - Severity: MEDIUM if elements missing, LOW if table absent
- **Config options**: `technology_neutrality` and `view_parity` toggles in `analysis:` section

### Changed

- Development View section renumbering:
  - §3.5.2 → §3.5.4 (Module Dependencies)
  - §3.5.3 → §3.5.5 (Build & CI/CD)
  - §3.5.4 → §3.5.6 (Development Standards)
- Functional View template example: `[e.g., REST /auth/*]` → `[e.g., API /auth/*]` (technology-neutral)

## [2.0.8] - 2026-05-17

### Fixed

- **P1-Critical**: Fixed setup-architect.sh clarify action to check drafts/adr.md (not memory) with fallback
- **P1-Critical**: Removed duplicate ADR_FILE variable definition in setup-architect.sh
- **P2-High**: Hardened implement.md pre-flight validation with hard enforcement and --force flag
- **P2-High**: Added workflow state tracking for clarify → implement pipeline enforcement
- **P3-Medium**: Added placeholder validation to catch unfilled [TBD], [STAKEHOLDER_*] patterns
- **P4-Low**: Added missing 3.1.2 Stakeholders subsection to context view template
- **P4-Low**: Clarified stakeholder vs external entities distinction in AD-template.md

### Added

- `--force` flag for emergency bypass of workflow validation (with clear warnings)
- Workflow state tracking in state.json (`workflow.clarify_completed`, etc.)
- Placeholder validation report template
- ADR fallback logic in clarify action (drafts → memory)

## [2.0.7] - 2026-05-16

### Fixed

- **Sub-System Detection Hardening** for `/architect.init` and `/architect.specify`:
  - Added **Detection Source Reconciliation** rules to handle script vs AI detection mismatches
  - Made **Step 4 (Sub-System Proposal) MANDATORY** when sub-systems are identified through ANY method
  - Added **Critical Enforcement Note**: Cannot skip to monolithic if sub-systems exist
  - Strengthened **Threshold Logic Enforcement** with mandatory user confirmation for 4+ sub-systems
  - Added **Self-Check Requirements** before proceeding to Phase 1
  - Prevents agents from ignoring AI-identified sub-systems when script reports "none detected"

### Changed

- Step 4 headers now explicitly marked as "MANDATORY if sub-systems identified"
- Threshold logic now presented as enforcement table with "Can Skip?" column
- Clear rules for when user confirmation is required vs optional
- Added explicit prohibition on proceeding as monolithic when sub-systems detected

## [2.0.6] - 2026-05-16

### Fixed

- **Hardened `/architect.implement`** with mandatory execution constraints to prevent phase skipping:
  - Added pre-flight validation: Check ADRs exist with "Accepted" status before starting
  - Added Phase 2→3 verification gate: All view files must exist on disk before aggregation
  - Enforced disk-read requirement: Phase 3 MUST read views from disk, not memory
  - Added completion verification: 7-point checklist before marking state "completed"
- **Strengthened `/architect.init`**: Enforce "Discovered" status (never "Accepted")
- **Strengthened `/architect.specify`**: Enforce "Proposed" status (never "Accepted")
- **Strengthened `/architect.clarify`**: Made Phase 5.5 approval gateway explicit with verification
- **Added empty views detection** to `/architect.analyze` to catch state.json/views mismatches

### Changed

- All architect commands now have stricter enforcement of workflow boundaries
- Added mandatory constraints blocks with bright-line rules
- Enhanced verification gates between phases

## [2.0.4] - 2026-04-30

### Fixed

- **Fragile path sourcing**: Fixed bash script using fragile relative paths to source common.sh.

## [2.0.3] - 2026-04-23

### Changed

- **Removed team-ai-directives integration**: ADRs now stored only in `.specify/drafts/` and `.specify/memory/`, no longer copied to team-ai-directives

## [2.0.2] - 2026-04-19

### Fixed

- **Auto-handoff to clarify**: Changed `send: false` to `send: true` in init.md and specify.md for automatic validation of discovered/created ADRs

### Changed

- `/architect.init` now auto-triggers `/architect.clarify` to validate brownfield findings
- `/architect.specify` now auto-triggers `/architect.clarify` to validate greenfield decisions

## [2.0.1] - 2026-04-13

### Fixed

- **Script path resolution**: Fixed session execution failures by using fully-qualified paths in command files
  - Changed from relative `scripts/bash/setup-architect.sh` to `.specify/extensions/architect/scripts/bash/setup-architect.sh`
  - This bypasses the path rewriting bug in the spec-kit CLI that incorrectly rewrites `scripts/` to `.specify/scripts/`

## [2.0.0] - 2026-04-12

### Breaking Changes

- **Methodology realignment**: Now strictly follows Rozanski & Woods Viewpoints and Perspectives framework
- **`before_plan` hook changed**: From `architect.specify` (create feature ADRs) to `architect.validate` (validate against existing architecture)
- **Feature-level ADRs removed**: `spec.*` commands no longer create feature-level ADRs
  - `spec.*` commands now validate against existing system ADRs and escalate if new architectural decisions detected
  - Use `architect.clarify` to create new system-level ADRs when needed
- **Perspective application**: Moved from Phase 3 (Summarize) to Phase 2 (Execute) - perspectives now applied inline during view generation
- **State file schema**: Updated to v2.0.0 with new execution strategy fields

### Added

- **Functional View Checkpoint**: Mandatory pause after Functional view generation
  - User must approve before subsequent views are generated
  - Functional view is the "cornerstone" that shapes all other views
  - Use `--no-checkpoint` to skip (not recommended)
- **Dynamic Viewpoint Selection**: Auto-detect from ADRs, user confirms which viewpoints to include
  - Core viewpoints (Context, Functional): Always included
  - Optional viewpoints (Information, Concurrency, Development, Deployment, Operational): Auto-detected
- **Dynamic Perspective Selection**: Auto-detect from requirements, user confirms which perspectives to apply
  - Core perspectives (Security, Performance): Always recommended
  - Optional perspectives: Auto-detected based on system characteristics
- **Inter-view Consistency Checking**: Validate impacts between views after each generation
- **Escalation Mechanism**: `validate` command signals when new architectural decisions need documentation
- **8 New Perspective Templates**: Complete R&W catalog:
  - `templates/perspectives/accessibility.md` - Ability to be used by people with disabilities
  - `templates/perspectives/availability.md` - Ability to be operational when required
  - `templates/perspectives/evolution.md` - Flexibility for change balanced against cost
  - `templates/perspectives/internationalization.md` - Independence from language/country/culture
  - `templates/perspectives/location.md` - Overcome geographic distribution problems
  - `templates/perspectives/regulation.md` - Conform to laws and regulations
  - `templates/perspectives/usability.md` - Ease of effective use
  - `templates/perspectives/development-resource.md` - Design within resource constraints
- **View Applicability Guidance**: Each perspective now documents which views it applies to
- **R&W Dependency Graph**: Explicit viewpoint dependencies based on R&W methodology

### Changed

- **`/architect.implement`**: Complete restructure with R&W alignment
  - Phase 1 (Plan): Now shows R&W dependency graph in approval output
  - Phase 2 (Execute): Now includes Functional checkpoint and inline perspectives
  - Phase 3 (Summarize): Simplified to aggregation only (perspectives already applied)
- **`/architect.specify`**: Added R&W alignment, quality requirements exploration phase
- **`/architect.init`**: Added R&W viewpoint mapping for brownfield discovery
- **`/architect.validate`**: Added escalation output for new architectural decisions
- **All perspective templates**: Added view applicability tables and integration guidance
- **All view templates**: Added perspective consideration sections
- **extension.yml**: Version bumped to 2.0.0, new execution defaults, viewpoint/perspective catalog
- **Defaults**: Sequential execution (quality > speed), Functional checkpoint enabled, perspectives inline

### Removed

- **Feature-level ADRs**: No longer supported (use system ADRs only)
- **Feature AD template**: Deleted `templates/feature-AD-template.md`
- **Feature ADR handling**: Removed from scripts and hooks

### Migration

- **State files**: Auto-upgraded (new fields have sensible defaults)
- **Feature ADRs**: Move to system ADRs or remove (no automatic migration)
- **Hook behavior**: Update any custom tooling that relied on `before_plan` calling `architect.specify`

## [1.1.5] - 2026-04-11

### Fixed

- **Template path resolution**: Updated all command templates to use `{REPO_ROOT}` prefix for `.specify/` paths
- **Team directives placeholder**: Changed hardcoded `team-ai-directives/` paths to use `{TEAM_DIRECTIVES}` placeholder
- **Monorepo support**: Templates now correctly resolve paths when running from subdirectories

## [1.1.1] - 2026-04-11

### Fixed

- **.specify directory detection**: Scripts now search upward for `.specify` directory before falling back to git root, fixing file creation in monorepo/sub-project setups
- **REPO_ROOT initialization order**: Moved common.sh sourcing before first REPO_ROOT usage to prevent undefined variable errors

## [1.1.0] - 2026-04-10

### Added

- **Multi-agent DAG orchestration** for `/architect.implement` command
  - Three-phase workflow: Plan → Execute → Summarize
  - State persistence in `.specify/architect/state.json` for resumability
  - Per-view outputs in `.specify/architect/views/{subsystem}/{view}.md`
  - Works with any AI agent (Claude, Copilot, Cursor, etc.)

- **View templates** extracted from AD-template.md:
  - `templates/views/context.md` - Context View template
  - `templates/views/functional.md` - Functional View template
  - `templates/views/information.md` - Information View template
  - `templates/views/concurrency.md` - Concurrency View template
  - `templates/views/development.md` - Development View template
  - `templates/views/deployment.md` - Deployment View template
  - `templates/views/operational.md` - Operational View template

- **Perspective templates**:
  - `templates/perspectives/security.md` - Security Perspective template
  - `templates/perspectives/performance.md` - Performance Perspective template

- **New script actions** for DAG workflow:
  - `plan-dag` - Phase 1: Generate DAG execution plan for user approval
  - `execute-dag` - Phase 2: Execute DAG to generate views per sub-system
  - `summarize` - Phase 3: Aggregate views into unified AD.md

- **DAG customization rules** based on sub-system characteristics:
  - Serverless → Deployment view first
  - Event-driven → Include Concurrency view
  - Data-intensive → Information view priority
  - Microservices → Expanded Functional view

### Changed

- **`/architect.implement`** completely rewritten with DAG orchestration
  - Sub-system detection from ADR index table
  - Dependency context passing between views
  - Cross-subsystem conflict resolution using ADRs as source of truth
  - Unified AD.md generation from per-view outputs

- **extension.yml** updated with DAG configuration:

  ```yaml
  dag:
    enabled: true
    base_location: ".specify/architect/"
    state_location: ".specify/architect/state.json"
    views_location: ".specify/architect/views/"
    view_templates: "templates/views/"
    perspective_templates: "templates/perspectives/"
  ```

### Migration

- Existing projects: No action needed (DAG workflow is opt-in via `/architect.implement`)
- Previous single-context generation still works if state.json doesn't exist

## [1.0.1] - 2026-04-09

### Fixed

- **Documentation accuracy**: Removed references to non-existent `--architecture` flag
  - Updated command documentation to correctly describe hook-based integration
  - Feature architecture now correctly documented as `before_plan` hook in `.specify/extensions.yml`
  - Clarified that architect extension must be installed for feature architecture generation

## [1.0.0] - 2026-03-04

### Added

- Initial release as extension (migrated from built-in commands)
- `/architect.init` - Brownfield ADR discovery from existing codebase
- `/architect.specify` - Greenfield PRD exploration to create ADRs
- `/architect.clarify` - ADR refinement and validation through questions
- `/architect.implement` - AD.md generation using Rozanski & Woods methodology
- `/architect.analyze` - **NEW** ADR to AD consistency analysis with 7 detection passes

### Changed

- Commands now use `speckit.architect.*` naming with `architect.*` aliases
- Handoffs defined in extension.yml instead of individual command files
- Scripts moved to extension directory

### Migration

- Users with existing architect commands: extension is auto-bundled during `specify init`
- Existing `.specify/memory/adr.md` and `AD.md` files are fully compatible
