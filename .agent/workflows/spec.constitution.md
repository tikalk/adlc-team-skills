---
description: Create or update the project constitution from interactive or provided principle inputs, ensuring all dependent templates stay in sync.
validation_scripts:
   sh: .specify/scripts/bash/validate-constitution.sh
   ps: .specify/scripts/powershell/validate-constitution.ps1
handoffs:
  - label: Build Specification
    agent: adlc.spec.specify
    prompt: Implement the feature specification based on the updated constitution. I want to build...
---

## Role & Context

You are a **Constitution Architect** responsible for establishing and maintaining the project's governance framework. Your role involves:

- **Inheriting** foundational principles from team constitutions
- **Adapting** principles to project-specific contexts
- **Ensuring** constitutional compliance across all project activities
- **Maintaining** version control and amendment history

**Key Principles:**

- Constitution supersedes all other practices
- Changes require justification and validation
- Principles must be testable and enforceable

## User Input

```text
$ARGUMENTS
```

**Input Processing:** Analyze the user input for:

- Specific principle amendments or additions
- Project context requiring constitutional guidance
- Validation requests or compliance checks

**Execution Strategy:**
You are updating the project constitution at `.specify/memory/constitution.md`. This file is a TEMPLATE containing placeholder tokens in square brackets (e.g. `[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`). Your job is to (a) collect/derive concrete values, (b) fill the template precisely, and (c) propagate any amendments across dependent artifacts.

**Note**: If `.specify/memory/constitution.md` does not exist yet, it should have been initialized from `.specify/templates/constitution-template.md` during project setup. If it's missing, copy the template first.

**Chain of Thought Approach:**

1. **Understand Context** → Analyze project needs and team inheritance
2. **Load Foundations** → Access team constitution and project templates
3. **Apply Inheritance** → Map team principles to project context
4. **Validate Integrity** → Ensure compliance and consistency
5. **Generate Outputs** → Create validated constitution artifacts
6. **Propagate Changes** → Update dependent templates with constitutional changes
7. **Finalize** → Write validated constitution to `.specify/memory/constitution.md`

## Detailed Workflow

### Phase 1: Context Analysis & Inheritance

**Objective:** Establish constitutional foundation through team inheritance

**Consistency propagation checklist:**

- Read `.specify/templates/plan-template.md` and ensure any "Constitution Check" or rules align with updated principles.
- Read `.specify/templates/spec-template.md` for scope/requirements alignment—update if constitution adds/removes mandatory sections or constraints.
- Read `.specify/templates/tasks-template.md` and ensure task categorization reflects new or removed principle-driven task types (e.g., observability, versioning, testing discipline).
- Read each command file in `.specify/templates/commands/*.md` (including this one) to verify no outdated references (agent-specific names like CLAUDE only) remain when generic guidance is required.
- Read any runtime guidance docs (e.g., `README.md`, `docs/quickstart.md`, or agent-specific guidance files if present). Update references to principles changed.

1. **Load Team Constitution**
   - Execute: `.specify/scripts/bash/setup-constitution.sh` to access team directives
   - Parse JSON output for team constitution path
   - Extract core principles using pattern: numbered list with `**Principle Name**`
   - Validate team constitution structure and completeness

2. **Analyze Project Context**
   - Determine project name from repository or branch context
   - Identify project-specific requirements or constraints
   - Assess existing codebase patterns (optional: run artifact scanning)

3. **Map Inheritance Rules**
   - **Direct Mapping:** Team principles → Project principles (preserve core governance)
   - **Contextual Adaptation:** Adjust descriptions for project-specific application
   - **Extension Points:** Identify areas for project-specific additions

### Phase 2: Constitution Assembly

**Objective:** Construct validated constitution document

1. **Template Processing**
   - Load constitution template from `.specify/memory/constitution.md`
   - Identify and categorize placeholder tokens:
     - `[PROJECT_NAME]`: Repository-derived identifier
     - `[PRINCIPLE_X_*]`: Team principle mappings
     - `[SECTION_*]`: Governance structure elements
     - `[VERSION_*]`: Version control metadata

2. **Content Generation**
   - **Principle Synthesis:** Combine team inheritance with project context
   - **Governance Framework:** Establish amendment procedures and compliance rules
   - **Version Initialization:** Set semantic version (1.0.0) and ratification dates

3. **Quality Assurance**
   - **Clarity Check:** Ensure principles use declarative, testable language
   - **Consistency Validation:** Verify alignment across all sections
   - **Completeness Audit:** Confirm all required elements are present

### Phase 3: Validation & Synchronization

**Objective:** Ensure constitutional integrity and system alignment

1. **Automated Validation**
   - Execute: `{VALIDATION_SCRIPT} --compliance --strict .specify/memory/constitution.md`
   - Parse validation results for critical failures and warnings
   - **Critical Failures:** Block constitution acceptance
   - **Warnings:** Allow override with explicit justification

2. **Template Synchronization**
   - **Dependency Scan:** Identify templates referencing constitutional elements
   - **Consistency Checks:** Validate alignment with updated principles
   - **Update Propagation:** Modify dependent templates as needed

3. **Impact Assessment**
   - Generate Sync Impact Report with version changes and affected components
   - Document amendment rationale and expected outcomes
   - Identify follow-up actions and monitoring requirements

### Phase 4: Finalization & Documentation

**Objective:** Complete constitution establishment with proper tracking

1. **Artifact Generation**
   - Write validated constitution to `.specify/memory/constitution.md`
   - Update version metadata and amendment timestamps
   - Generate amendment history entry

2. **User Communication**
   - **Success Report:** Version, changes, and impact summary
   - **Action Items:** Required follow-ups and manual interventions
   - **Commit Guidance:** Suggested commit message with constitutional context

## Error Handling & Edge Cases

**Missing Team Constitution:**

- Use default project constitution template
- Flag for team constitution setup requirement
- Allow manual principle specification

**Validation Failures:**

- Provide detailed error breakdown by category
- Suggest remediation steps for each failure type
- Support override mechanisms for justified exceptions

**Template Synchronization Issues:**

- Report affected templates with specific change requirements
- Generate automated update scripts where possible
- Maintain backward compatibility during transitions

## Output Standards

**Formatting Requirements:**

- Markdown headers: Exact hierarchy preservation
- Line length: <100 characters for readability
- Spacing: Single blank lines between sections
- Encoding: UTF-8 with no trailing whitespace

**Version Control:**

- Semantic versioning: MAJOR.MINOR.PATCH
- ISO dates: YYYY-MM-DD format
- Amendment tracking: Timestamped change history

**Validation Reporting:**

- Structured JSON output for automation integration
- Human-readable summaries with actionable guidance
- Color-coded status indicators (✅ PASS / ❌ FAIL / ⚠️ WARN)

Do not create a new template; always operate on the existing `.specify/memory/constitution.md` file.
