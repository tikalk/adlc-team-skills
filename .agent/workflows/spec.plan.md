---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
handoffs: 
  - label: Create Tasks
    agent: adlc.spec.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: adlc.spec.checklist
    prompt: Create a checklist for the following domain...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

### Parameters

Parse the following parameters from `$ARGUMENTS`:

## Framework Options Detection

1. **Auto-Detect from Spec**: Parse the spec.md header to extract framework options from the `**Framework Options**` metadata line (e.g., contracts, data-models). This determines which optional artifacts to generate.

2. **Framework Options**: Respect detected framework options (contracts, data-models) when planning implementation approach and deliverables.

## Pre-Execution Hooks

**Check for extension hooks (before planning)**:
- Check if `.specify/extensions.yml` exists in the project root
- If it exists, read it and look for entries under the `hooks.before_plan` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter to only hooks where `enabled: true`
- For hooks with conditions, skip condition evaluation (leave to HookExecutor)
- For hooks without conditions, treat as executable

**For each executable hook**:
- **Optional hook** (`optional: true`):
  ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    This is an optional hook. You can choose to skip it.
  ```
  Wait for the result of the hook command before proceeding to the Outline.

- **Mandatory hook** (`optional: false`):
  ```
    ## Extension Hooks

    **Mandatory Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    This is a mandatory hook. Waiting for completion...
  ```
  The hook MUST complete before proceeding to the next step.

- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

**Note on Architecture Integration**:
- If architect extension registered and adr.md exists, before_plan hook may create feature ADRs
- Command: `/architect.specify` or `/architect.init` (greenfield vs brownfield)
- Purpose: Generate feature-specific ADRs for architectural consistency
- Note: Architecture validation happens in after_plan hook (not at this stage)

## Role & Context

You are a **Technical Planning Architect** responsible for transforming feature specifications into executable implementation plans. Your role involves:

- **Analyzing** feature requirements and technical constraints
- **Designing** system architecture and component interactions
- **Ensuring** constitutional compliance throughout planning
- **Coordinating** research, design, and validation activities

**Key Principles:**

- Plans must be testable and implementable
- Unknowns require research before commitment
- Constitution governs all technical decisions
- Quality gates prevent premature advancement

## Input Processing

```text
$ARGUMENTS
```

**Input Processing:** The user input represents feature context or planning directives. Analyze for:

- Specific planning requirements or constraints
- Technical preferences or architectural decisions
- Timeline or resource considerations
- Quality or compliance requirements

## Execution Strategy

**Chain of Thought Approach:**

1. **Establish Context** → Load specifications and constitutional requirements
2. **Analyze Scope** → Identify technical unknowns and research needs
3. **Design Architecture** → Create system models and component definitions
4. **Validate Compliance** → Ensure constitutional alignment
5. **Generate Artifacts** → Produce implementation-ready documentation

## Core Workflow

### Phase 1: Planning Setup & Context Loading

**Objective:** Establish planning environment and load all required context

1. **Environment Initialization**
   - Execute: `.specify/scripts/bash/setup-plan.sh --json` from repository root
   - Parse JSON output for: FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH
   - Validate all required paths exist and are accessible
   - Handle argument escaping for special characters

2. **Context Acquisition**
   - **Specification Loading:** Read FEATURE_SPEC for requirements and constraints
   - **Constitutional Loading:** Read `.specify/memory/constitution.md` for governance rules
   - **Template Loading:** Load appropriate template
   - **Validation:** Ensure all context sources are available and consistent

### Phase 2: Technical Analysis & Research Planning

**Objective:** Identify technical scope and knowledge gaps requiring research

 1. **Technical Context Mapping**
    - Extract technical requirements from feature specification
    - Identify technology stack and architectural patterns
    - Map integration points and external dependencies
    - **NEEDS CLARIFICATION Flag:** Mark unknowns preventing confident planning

 2. **Constitutional Compliance Assessment**
    - Map feature requirements against constitution principles
    - Identify potential conflicts or additional requirements
    - Document compliance strategy and justification
    - **Gate Evaluation:** Block progression for unjustified violations

 3. **Research Planning**
    - **Gap Analysis:** Convert NEEDS CLARIFICATION items to research tasks
    - **Dependency Research:** Plan investigation of critical integrations
    - **Best Practice Research:** Identify technology-specific recommendations
    - Generate research.md with prioritized investigation plan

## Execution Flow

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts (Configurable)

**Prerequisites:** `research.md` complete

**Framework Options Check:**

- Detect framework options by parsing the `**Framework Options**` line from spec.md header
- Respect framework configuration for contracts and data models

1. **Extract entities from feature spec** → `data-model.md` (if data models enabled):
    - Only generate if data models are enabled in current settings
    - Entity name, fields, relationships
    - Validation rules from requirements
    - State transitions if applicable

2. **Generate API contracts** from functional requirements (if contracts enabled):
    - Only generate if API contracts are enabled in current settings
    - For each user action → endpoint
    - Use standard REST/GraphQL patterns
    - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Agent context update**:
    - Run `.specify/scripts/bash/update-agent-context.sh agy`
    - These scripts detect which AI agent is in use
    - Update the appropriate agent-specific context file
    - Add only new technology from current plan
    - Preserve manual additions between markers

**Output**: Conditionally generated artifacts based on framework option settings:

- data-model.md (if data models enabled)
- /contracts/* (if contracts enabled)
- quickstart.md, agent-specific file (always generated)

### Phase 2: Feature Architecture (via architect extension)

**Prerequisites:** Research complete

**Trigger**: architect extension installed and adr.md exists (.specify/memory/adr.md from system-level architecture)

**Note**: Architecture workflow now handled via architect extension hooks:

**before_plan hook (if architect extension present)**:
- `/architect.specify`: Create feature-level ADRs
- `/architect.clarify`: Refine feature ADRs
- `/architect.implement`: Generate feature AD.md (optional)

**after_plan hook (if architect extension present)**:
- `/architect.validate --for-plan`: Validate plan alignment with architecture (READ-ONLY)
- Parse findings: BLOCKING, HIGH-SEVERITY, WARNINGS
- Document validation report in plan.md

**If architect extension NOT available**:
- Architecture workflow does not run
- Plan generation continues with spec-based information only

**Cross-Validation (if architect installed)**:
1. **Load System Architecture**:
   - Read `AD.md` (root) for system-level architecture context
   - Read `.specify/memory/adr.md` for system-level ADRs
   - Extract relevant viewpoints and constraints

2. **Identify Feature-Specific Decisions**:
   - What new components does this feature introduce?
   - What existing components are modified?
   - What data entities are added/changed?
   - What integration points are affected?

3. **Generate Feature ADRs** (via before_plan hook):
   - Create `specs/{feature}/adr.md` with feature-level decisions
   - Each ADR should reference system ADRs: "Aligns with ADR-XXX"
   - Flag any conflicts: "VIOLATION: Conflicts with ADR-XXX"

4. **Generate Feature Architecture Description** (via before_plan hook, \`/architect.implement\`):
   - Use `.specify/templates/feature-AD-template.md` as base
   - Focus on feature context, functional design, data design
   - Include integration points with system architecture
   - Generate feature-specific diagrams

5. **Cross-Validate Against System AD** (via after_plan hook validation):
   - Verify feature doesn't violate system boundaries
   - Ensure consistency with system component patterns
   - Check data model compatibility with Information View
   - Validate deployment approach fits Deployment View

**Output**:

- `specs/{feature}/adr.md` (feature-level decisions)
- `specs/{feature}/AD.md` (feature architecture description)

## Triage Framework: [SYNC] vs [ASYNC] Task Classification

**Purpose**: Guide the classification of implementation tasks as [SYNC] (human-reviewed) or [ASYNC] (agent-delegated) to optimize execution efficiency and quality.

#### Triage Decision Framework

**Evaluate Each Implementation Task Against These Criteria:**

##### [SYNC] Classification (Human Execution Required)

- **Complex Business Logic**: Non-trivial algorithms, state machines, or domain-specific calculations
- **Architectural Decisions**: System design choices, component boundaries, or integration patterns
- **Security-Critical Code**: Authentication, authorization, encryption, or data protection
- **External Integrations**: Third-party APIs, legacy systems, or complex data transformations
- **Ambiguous Requirements**: Unclear specifications requiring interpretation or clarification
- **High-Risk Changes**: Database schema changes, API contract modifications, or breaking changes

##### [ASYNC] Classification (Agent Delegation Suitable)

- **Well-Defined CRUD**: Standard create/read/update/delete operations with clear schemas
- **Repetitive Tasks**: Boilerplate code, standard library usage, or template-based generation
- **Clear Specifications**: Unambiguous requirements with complete acceptance criteria
- **Independent Components**: Self-contained modules with minimal external dependencies
- **Standard Patterns**: Established frameworks, libraries, or architectural patterns
- **Testable Units**: Components with comprehensive automated test coverage

#### Triage Process

1. **Task Identification**: Break down the feature into discrete, implementable tasks
2. **Criteria Evaluation**: Assess each task against the [SYNC]/[ASYNC] criteria above
3. **Rationale Documentation**: Record the reasoning for each classification decision
4. **Risk Assessment**: Consider the impact of incorrect classification
5. **Review Checkpoint**: Validate triage decisions before task generation

#### Triage Audit Trail

**Document for Each Task:**

- Classification: [SYNC] or [ASYNC]
- Primary Criteria: Which criteria drove the classification
- Risk Level: Low/Medium/High (impact of misclassification)
- Rationale: 1-2 sentence explanation

#### Triage Effectiveness Metrics

**Track Over Time:**

- Classification Accuracy: Percentage of tasks correctly classified (measured post-implementation)
- Review Efficiency: Time spent on [SYNC] reviews vs [ASYNC] execution time
- Quality Impact: Defect rates by classification type
- Learning Opportunities: Common misclassification patterns

## Key Rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications
- **TRIAGE REQUIREMENT**: All implementation tasks must be classified as [SYNC] or [ASYNC] with documented rationale
- Comprehensive research required before design decisions
- Full constitutional compliance validation
- Detailed triage analysis for all tasks
- Complete design artifacts and validation

**Planning Approach:**

- Comprehensive research-driven planning with full validation
- Detailed technical analysis and constitutional compliance
- Complete design artifacts and thorough triage

**Architecture Integration** (via architect extension):

- architect extension hooks handle architecture workflow automatically
- **before_plan hook**: Create feature ADRs (if before_plan hook configured)
- **after_plan hook**: Validate plan alignment (READ-ONLY validation via architect.validate)
- Feature ADRs auto-validated against system ADRs in `.specify/memory/adr.md`
- Conflicts flagged as VIOLATION requiring resolution
- Aligned decisions noted with "Aligns with ADR-XXX"

### Two-Level Architecture System

| Level | Location | ADR File | Architecture Description | Generated By | Hook |
|-------|----------|----------|--------------------------|--------------|------|
| **System** | Main branch | `.specify/memory/adr.md` | `AD.md` (root) | `/architect.*` commands | N/A |
| **Feature** | Feature branch | `specs/{feature}/adr.md` | `specs/{feature}/AD.md` | `/architect.specify → /architect.clarify → /architect.implement` | before_plan |
| **Validation** | Plan level | READ-ONLY via `/architect.validate --for-plan` | Validates plan alignment | architect extension | after_plan |

Feature architecture inherits and extends system architecture, ensuring consistent governance across all development.

### AI-Powered Context/Skills Refresh (Always Enabled)

**When feature scope changes during planning:**

1. **Re-run discovery** (same approach as /specify)
   - Extract keywords from updated plan requirements
   - AI semantic search (not grep-based)
   - Update candidates with new relevant items

2. **Merge with existing selections**
   - Keep manually selected directives and skills
   - Append newly discovered items
   - On conflicts: Keep higher confidence score, annotate the change

3. **Show refresh status** in context.md
   - What changed: New items, removed items, score changes
   - Mark items that moved between baseline and AI categories

**Detection logic**: Use same AI semantic approach as /specify command to ensure consistency.


## Post-Execution Hooks

**Check for extension hooks (after planning)**:
- After plan is generated, check if `.specify/extensions.yml` exists in the project root
- If it exists, read it and look for entries under the `hooks.after_plan` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter to only hooks where `enabled: true`

**For each executable hook**:
- **Optional hook** (`optional: true`):
  ```
    ## Extension Hooks

    **Optional Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Would you like to run this optional hook? (Y/n)
  ```

- **Mandatory hook** (`optional: false`):
  ```
    ## Extension Hooks

    **Mandatory Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Running mandatory hook...
  ```

- Wait for hook command completion
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

**Note on Architecture Validation**:
- If architect extension registered and adr.md exists, after_plan hook may validate architecture:
  - `/architect.validate --for-plan --json` (READ-ONLY)
  - Parse JSON findings: blocking, high-severity, warnings
  - Document validation report in plan.md
  - BLOCK task generation if BLOCKING issues found
  - Continue if only MEDIUM/LOW issues
