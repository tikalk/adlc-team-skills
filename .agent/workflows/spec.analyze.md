---
description: Perform cross-artifact consistency and quality analysis. Automatically detects pre vs post-implementation context based on project state.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Perform consistency and quality analysis across artifacts and implementation with automatic context detection:

**Auto-Detection Logic**:

- **Pre-Implementation**: When spec.md exists but no implementation artifacts detected (tasks.md and plan.md required)
- **Post-Implementation**: When implementation artifacts exist (source code, build outputs, etc.)

**Pre-Implementation Analysis**: Identify inconsistencies, duplications, ambiguities, and underspecified items across available artifacts (spec.md, plan.md, tasks.md required). This command should run after `/spec.tasks` has successfully produced a complete `tasks.md`.

**Architecture Cross-Validation** (NEW): When architecture artifacts exist (`AD.md`, `.specify/memory/adr.md`, or `specs/{feature}/AD.md`), validate spec and plan alignment with system and feature-level architecture constraints.

**Post-Implementation Analysis**: Analyze actual implemented code against documentation to identify refinement opportunities, synchronization needs, and real-world improvements.

This command adapts its behavior based on project state.

## Operating Constraints

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured analysis report. Offer an optional remediation plan (user must explicitly approve before any follow-up editing commands would be invoked manually).

**Auto-Detection Logic**:

1. Auto-detect project state:
    - **Pre-implementation**: No implementation artifacts exist (check for source code, compiled outputs, deployment artifacts)
    - **Post-implementation**: Implementation artifacts exist (source code directories, compiled outputs, or deployment artifacts)
2. Apply analysis depth:
    - **Pre-implementation**: Comprehensive analysis with full validation
    - **Post-implementation**: Code-focused analysis with refinement recommendations

**Constitution Authority**: The project constitution (`.specify/memory/constitution.md`) is **non-negotiable** within this analysis scope. Constitution conflicts are automatically CRITICAL and require adjustment of the spec, plan, or tasks—not dilution, reinterpretation, or silent ignoring of the principle. If a principle itself needs to change, that must occur in a separate, explicit constitution update outside `/spec.analyze`.

## Execution Steps

### 1. Initialize Analysis Context

Run `.specify/scripts/bash/check-prerequisites.sh --json --include-tasks` once from repo root and parse JSON for FEATURE_DIR and AVAILABLE_DOCS. Derive absolute paths:

- SPEC = FEATURE_DIR/spec.md
- PLAN = FEATURE_DIR/plan.md
- TASKS = FEATURE_DIR/tasks.md

For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Auto-Detect Analysis Mode

**Context Analysis**:

1. **Analyze Project State**:
   - Scan for implementation artifacts (src/, build/, dist/, *.js,*.py, etc.)
   - Check git history for implementation commits
   - Verify if `/implement` has been run recently
2. **Determine Analysis Type**:
   - **Pre-Implementation**: spec.md + tasks.md exist, no implementation artifacts (plan.md recommended)
   - **Post-Implementation**: Implementation artifacts exist
3. **Apply Analysis Depth**:
   - **Pre-Implementation**: Comprehensive analysis with full validation
   - **Post-Implementation**: Code-focused analysis with refinement recommendations

### 3. Load Artifacts (Auto-Detected Mode)

**Pre-Implementation Mode Artifacts:**
Load available artifacts (spec.md required, plan.md and tasks.md recommended):

**From spec.md (required):**

- Overview/Context
- Functional Requirements
- Non-Functional Requirements
- User Stories
- Edge Cases (if present)

**From plan.md (recommended):**

- Architecture/stack choices
- Data Model references
- Phases
- Technical constraints

**From tasks.md (recommended):**

- Task IDs
- Descriptions
- Phase grouping
- Parallel markers [P]
- Referenced file paths

**Post-Implementation Mode Artifacts:**
Load documentation artifacts plus analyze actual codebase:

**From Documentation:**

- All artifacts as above (if available)
- Implementation notes and decisions

**From Codebase:**

- Scan source code for implemented functionality
- Check for undocumented features or changes
- Analyze performance patterns and architecture usage
- Identify manual modifications not reflected in documentation

**From constitution:**

- Load `.specify/memory/constitution.md` for principle validation (both modes)

**From architecture (if exists):**

- Load `AD.md` (root) for system-level architecture context
- Load `.specify/memory/adr.md` for system-level ADRs
- Load `specs/{feature}/AD.md` for feature-level architecture (if `--architecture` was enabled)
- Load `specs/{feature}/adr.md` for feature-level ADRs (if `--architecture` was enabled)

### 3. Build Semantic Models

Create internal representations (do not include raw artifacts in output):

- **Requirements inventory**: Each functional + non-functional requirement with a stable key (derive slug based on imperative phrase; e.g., "User can upload file" → `user-can-upload-file`)
- **User story/action inventory**: Discrete user actions with acceptance criteria
- **Task coverage mapping**: Map each task to one or more requirements or stories (inference by keyword / explicit reference patterns like IDs or key phrases)
- **Constitution rule set**: Extract principle names and MUST/SHOULD normative statements

### 4. Detection Passes (Auto-Detected Analysis)

Focus on high-signal findings. Limit to 50 findings total; aggregate remainder in overflow summary.

**BRANCH BY AUTO-DETECTED MODE:**

#### Pre-Implementation Detection Passes

#### A. Duplication Detection

- Identify near-duplicate requirements
- Mark lower-quality phrasing for consolidation

#### B. Ambiguity Detection

- Flag vague adjectives (fast, scalable, secure, intuitive, robust) lacking measurable criteria
- Flag unresolved placeholders (TODO, TKTK, ???, `<placeholder>`, etc.)

#### C. Underspecification

- Requirements with verbs but missing object or measurable outcome
- User stories missing acceptance criteria alignment
- Tasks referencing files or components not defined in spec/plan (if tasks.md exists)

#### D. Constitution Alignment

- Any requirement or plan element conflicting with a MUST principle
- Missing mandated sections or quality gates from constitution

#### E. Coverage Gaps

- Requirements with zero associated tasks (if tasks.md exists)
- Tasks with no mapped requirement/story (if tasks.md exists)
- Non-functional requirements not reflected in tasks (if tasks.md exists)

#### F. Inconsistency

- Terminology drift (same concept named differently across files)
- Data entities referenced in plan but absent in spec (or vice versa)
- Task ordering contradictions (e.g., integration tasks before foundational setup tasks without dependency note)
- Conflicting requirements (e.g., one requires Next.js while other specifies Vue)

#### Post-Implementation Detection Passes

##### G. Documentation Drift

- Implemented features not documented in spec.md
- Code architecture differing from plan.md
- Manual changes not reflected in documentation
- Deprecated code still referenced in docs

##### H. Implementation Quality

- Performance bottlenecks not anticipated in spec
- Security issues discovered during implementation
- Scalability problems with current architecture
- Code maintainability concerns

##### I. Real-World Usage Gaps

- User experience issues not covered in requirements
- Edge cases discovered during testing/usage
- Integration problems with external systems
- Data validation issues in production

##### J. Refinement Opportunities

- Code optimizations possible
- Architecture improvements identified
- Testing gaps revealed
- Monitoring/logging enhancements needed

#### K. Architecture Cross-Validation (Both Modes - if architecture exists)

**Purpose**: Ensure feature spec/plan alignment with system and feature-level architecture.

**System-Level Validation** (if `AD.md` and `.specify/memory/adr.md` exist):

1. **Context View Alignment**:
   - Does spec respect system boundaries defined in AD.md?
   - Are new external dependencies within acceptable scope?
   - Do integration points match Context View entities?

2. **Functional View Alignment**:
   - Do planned components fit existing functional structure?
   - Are responsibilities consistent with established patterns?
   - Do interactions follow documented patterns?

3. **Information View Alignment**:
   - Do data entities align with Information View?
   - Are data flows consistent with existing architecture?
   - Do lifecycle requirements match established patterns?

4. **ADR Compliance**:
   - Does spec violate any system-level ADRs?
   - Are technology choices consistent with ADR decisions?
   - Are architectural patterns followed?

**Feature-Level Validation** (if `specs/{feature}/AD.md` and `specs/{feature}/adr.md` exist):

1. **Feature ADR Consistency**:
   - Do feature ADRs align with system ADRs (marked "Aligns with ADR-XXX")?
   - Are there VIOLATION flags requiring resolution?
   - Are feature-specific decisions well-documented?

2. **Feature Architecture Completeness**:
   - Are all new/modified components documented?
   - Are integration points with system components clear?
   - Are data design implications documented?

**Architecture Validation Gaps to Detect**:

- **Boundary violations**: Feature exceeds system scope defined in Context View
- **Component conflicts**: Feature introduces components that overlap with existing
- **Data inconsistencies**: Feature entities conflict with Information View
- **ADR violations**: Feature contradicts accepted system decisions
- **Missing feature ADRs**: Complex feature decisions not documented
- **Stale architecture**: System AD.md out of date with feature changes

**Severity Assignment**:

- **CRITICAL**: ADR violations, boundary violations
- **HIGH**: Component conflicts, data inconsistencies
- **MEDIUM**: Missing feature ADRs, stale architecture
- **LOW**: Documentation gaps, minor inconsistencies

#### L. Smart Trace Validation (Both Modes)

**Purpose**: Ensure spec-to-issue traceability is maintained throughout the SDD workflow using `@issue-tracker ISSUE-123` syntax.

**Detection Logic**:

1. **Scan all artifacts** for existing `@issue-tracker` references
2. **Extract issue IDs** from patterns like `@issue-tracker PROJ-123`, `@issue-tracker #456`, `@issue-tracker GITHUB-789`
3. **Validate coverage**:
   - **Spec-level traces**: Every major feature/user story should have at least one issue reference
   - **Task-level traces**: Implementation tasks should reference parent spec issues
   - **Cross-artifact consistency**: Same issue IDs used across spec.md, plan.md, tasks.md
4. **Check MCP configuration**: Verify `.mcp.json` exists and issue tracker is properly configured

**Traceability Gaps to Detect**:

- **Missing spec traces**: User stories or major features without `@issue-tracker` references
- **Orphaned tasks**: Implementation tasks not linked to spec-level issues
- **Inconsistent issue references**: Same feature referenced with different issue IDs across artifacts
- **Invalid issue formats**: Malformed issue references that won't integrate with MCP
- **MCP misconfiguration**: Issue tracker not configured in `.mcp.json`

**Validation Rules**:

- **Minimum coverage**: ≥80% of user stories/requirements should have traceable issue links
- **Format validation**: Issue references must match configured tracker patterns (GitHub/Jira/Linear/GitLab)
- **Consistency check**: Issue IDs should be consistent across spec.md → plan.md → tasks.md
- **MCP readiness**: `.mcp.json` must exist and contain valid issue tracker configuration

### 5. Severity Assignment

Use this heuristic to prioritize findings:

**Pre-Implementation Severities:**

- **CRITICAL**: Violates constitution MUST, missing spec.md, or requirement with zero coverage that blocks baseline functionality
- **HIGH**: Duplicate or conflicting requirement, ambiguous security/performance attribute, untestable acceptance criterion
- **MEDIUM**: Terminology drift, missing non-functional task coverage, underspecified edge case, missing plan.md/tasks.md
- **LOW**: Style/wording improvements, minor redundancy not affecting execution order

**Post-Implementation Severities:**

- **CRITICAL**: Security vulnerabilities, data corruption risks, or system stability issues
- **HIGH**: Performance problems affecting user experience, undocumented breaking changes
- **MEDIUM**: Code quality issues, missing tests, documentation drift
- **LOW**: Optimization opportunities, minor improvements, style enhancements

### 6. Produce Compact Analysis Report (Auto-Detected)

Output a Markdown report (no file writes) with auto-detected mode-appropriate structure. Include detection summary at the top:

#### Pre-Implementation Report Structure

## Pre-Implementation Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Duplication | HIGH | spec.md:L120-134 | Two similar requirements ... | Merge phrasing; keep clearer version |

**Coverage Summary Table:**

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|

**Constitution Alignment Issues:** (if any)

**Unmapped Tasks:** (if any)

**Metrics:**

- Total Requirements
- Total Tasks
- Coverage % (requirements with >=1 task)
- Ambiguity Count
- Duplication Count
- Critical Issues Count

**Traceability Validation:**

- **Issue Coverage**: X/Y user stories have @issue-tracker references (Z%)
- **MCP Status**: ✅ Configured (GitHub) / ❌ Missing .mcp.json
- **Format Validation**: All issue references use valid formats
- **Consistency Check**: Issue IDs consistent across artifacts

**Architecture Alignment:**

- **System AD**: ✅ Compliant / ⚠️ Issues Found / Not Available
- **System ADRs**: X violations, Y alignments documented
- **Feature AD**: ✅ Complete / ⚠️ Gaps Found / Not Generated
- **Feature ADRs**: X decisions documented

### Post-Implementation Report Structure

## Post-Implementation Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| G1 | Documentation Drift | HIGH | src/auth.js | JWT implementation not in spec | Update spec.md to document JWT usage |

**Implementation vs Documentation Gaps:**

| Area | Implemented | Documented | Gap Analysis |
|------|-------------|------------|--------------|
| Authentication | JWT + OAuth2 | Basic auth only | Missing OAuth2 in spec |

**Code Quality Metrics:**

- Lines of code analyzed
- Test coverage percentage
- Performance bottlenecks identified
- Security issues found

**Refinement Opportunities:**

- Performance optimizations
- Architecture improvements
- Testing enhancements
- Documentation updates needed

**Traceability Validation:**

- **Issue Coverage**: X/Y user stories have @issue-tracker references (Z%)
- **MCP Status**: ✅ Configured (GitHub) / ❌ Missing .mcp.json
- **Format Validation**: All issue references use valid formats
- **Consistency Check**: Issue IDs consistent across artifacts

**Architecture Alignment:**

- **System AD**: ✅ Compliant / ⚠️ Issues Found / Not Available
- **Feature AD**: ✅ Consistent / ⚠️ Drift Detected / Not Generated
- **ADR Status**: Implementation matches documented decisions

### 7. Provide Next Actions (Auto-Detected)

At end of report, output a concise Next Actions block based on detected mode and findings:

**Pre-Implementation Next Actions:**

- If CRITICAL issues exist: Recommend resolving before `/spec.implement`
- If only LOW/MEDIUM: User may proceed, but provide improvement suggestions
- Provide explicit command suggestions: e.g., "Run /spec.specify with refinement", "Run /spec.plan to adjust architecture", "Manually edit tasks.md to add coverage for 'performance-metrics'"
- **Traceability**: If <80% coverage: "Add @issue-tracker ISSUE-123 references to major user stories in spec.md"
- **Architecture**: If violations found: "Resolve ADR violations before proceeding" or "Run /architect.clarify to update system ADRs"
- **Feature Architecture**: If gaps found: "Run /spec.plan --architecture to generate feature-level architecture"

**Post-Implementation Next Actions:**

- If CRITICAL issues exist: Recommend immediate fixes for security/stability
- If HIGH issues exist: Suggest prioritization for next iteration
- **Traceability**: If gaps found: "Update issue status in tracker and ensure all implemented features are linked via @issue-tracker references"
- Provide refinement suggestions: e.g., "Consider performance optimization", "Update documentation for new features", "Add missing test coverage"
- Suggest follow-up commands: e.g., "Run /plan to update architecture docs", "Run /specify to document new requirements"

### 8. Offer Remediation

Ask the user: "Would you like me to suggest concrete remediation edits for the top N issues?" (Do NOT apply them automatically.)

### 9. Documentation Evolution (Post-Implementation Only)

**When Post-Implementation Analysis Detects Significant Changes:**

If the analysis reveals substantial implementation changes that should be reflected in documentation, offer to evolve the documentation:

**Documentation Evolution Options:**

- **Spec Updates**: Add newly discovered requirements, edge cases, or user experience insights
- **Plan Updates**: Document architecture changes, performance optimizations, or integration decisions
- **Task Updates**: Mark completed tasks, add follow-up tasks for refinements

**Evolution Workflow:**

1. **Identify Changes**: Flag implemented features not in spec.md, architecture deviations from plan.md
2. **Propose Updates**: Suggest specific additions to documentation artifacts
3. **Preserve Intent**: Ensure updates maintain original requirements while incorporating implementation learnings
4. **Version Tracking**: Create new versions of documentation with clear change rationale

**Evolution Triggers:**

- New features implemented but not specified
- Architecture changes for performance/security reasons
- User experience improvements discovered during implementation
- Integration requirements not anticipated in planning

### 10. Rollback Integration

**When Analysis Reveals Critical Issues:**

If post-implementation analysis identifies critical problems requiring rollback:

**Rollback Options:**

- **Task-Level Rollback**: Revert individual tasks while preserving completed work
- **Feature Rollback**: Roll back entire feature implementation
- **Documentation Preservation**: Keep documentation updates even when code is rolled back

**Rollback Workflow:**

1. **Assess Impact**: Determine which tasks/code to rollback
2. **Preserve Documentation**: Keep spec/plan updates that reflect learnings
3. **Clean Revert**: Remove problematic implementation while maintaining good changes
4. **Regenerate Tasks**: Create new tasks for corrected implementation approach

## Operating Principles

### Context Efficiency

- **Minimal high-signal tokens**: Focus on actionable findings, not exhaustive documentation
- **Progressive disclosure**: Load artifacts incrementally; don't dump all content into analysis
- **Token-efficient output**: Limit findings table to 50 rows; summarize overflow
- **Deterministic results**: Rerunning without changes should produce consistent IDs and counts

### Analysis Guidelines

- **NEVER modify files** (this is read-only analysis)
- **NEVER hallucinate missing sections** (if absent, report them accurately)
- **Prioritize constitution violations** (these are always CRITICAL)
- **Use examples over exhaustive rules** (cite specific instances, not generic patterns)
- **Report zero issues gracefully** (emit success report with coverage statistics)

### Auto-Detection Guidelines

- **Context awareness**: Analyze project state to determine appropriate analysis type
- **Progressive enhancement**: Start with basic detection, allow user override if needed
- **Clear communication**: Always report which analysis mode was auto-selected

### Post-Implementation Guidelines

- **Code analysis scope**: Focus on high-level architecture and functionality, not line-by-line code review
- **Documentation synchronization**: Identify gaps between code and docs without assuming intent
- **Refinement focus**: Suggest improvements based on real implementation experience
- **Performance awareness**: Flag obvious bottlenecks but don't micro-optimize

## Context

$ARGUMENTS
