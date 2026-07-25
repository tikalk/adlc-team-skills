---
name: architect-implement
description: Generate a full Architecture Description (AD.md) from accepted ADRs using multi-agent DAG orchestration. Use when accepted ADRs exist and you need to produce or update unified architecture documentation.
disable-model-invocation: true
---

# architect-implement

## What this skill does

Generate a full Architecture Description (AD.md) from Architecture Decision Records (ADRs) using a **multi-agent DAG orchestration** approach:

1. **Plan Agent**: Analyze ADRs, detect sub-systems, generate a customized DAG, and get user approval.
2. **Execute Agent**: Generate architecture views per sub-system following the DAG, with dependency context passing.
3. **Summarize Agent**: Aggregate all views, resolve cross-subsystem conflicts, and generate a unified AD.md.

**Key Insight**: ADRs capture **why** decisions were made; the Architecture Description captures **what** the system looks like as a result of those decisions.

## When to use

- **After `/architect-specify` or `/architect-clarify`**: Generate AD from discussed and accepted ADRs.
- **After `/architect-init`**: Document brownfield architecture.
- **ADR Updates**: Regenerate AD.md after new decisions.
- **Documentation Sprint**: Create comprehensive architecture docs.

### When NOT to use

- **No ADRs exist**: Use `/architect-specify` or `/architect-init` first.
- **Feature-level**: Feature AD is generated during the feature's plan phase, not by this skill.
- **Minor updates**: Use direct editing for small changes.

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Focus on deployment and operational views - we need infrastructure docs"`
- `"Generate all views with emphasis on security perspective"`
- `"Update existing AD.md with new ADRs from recent decisions"`
- Empty input: Generate complete Architecture Description from all ADRs

### Flags

- `--views VIEWS`: Architecture views to generate
  - `core` (default): Context, Functional, Information, Development, Deployment (5 core views)
  - `all`: All 7 views including Concurrency and Operational
  - Custom: comma-separated (e.g., `concurrency,operational`) - always includes core views

- `--sequential` (default): Execute views sequentially for maximum quality
  - Recommended: Allows checkpoint after Functional view
- `--parallel`: Allow parallel execution where dependency chains permit
  - Warning: May reduce cross-view consistency - use only when time-constrained

- `--no-checkpoint`: Skip Functional view checkpoint (not recommended)
  - Warning: Functional view is the "cornerstone" that shapes all others

- `--force`: Bypass workflow state validation (emergency use only)
  - **WARNING**: Use only when you understand the risks
  - Skips clarify Phase 5.5 completion check
  - Skips pre-flight ADR status validation
  - May result in incomplete or inconsistent architecture

**Important**: When `--views` is `core` (default), **skip** Concurrency View (3.4) and Operational View (3.7) entirely. Only generate them when explicitly requested via `--views all` or `--views concurrency,operational`.

### Rozanski & Woods Methodology Alignment

This command implements the **Viewpoints and Perspectives** framework from 
*Software Systems Architecture* (2nd Edition) by Nick Rozanski and Eoin Woods.

#### Core Principles

1. **Functional View is the Cornerstone**
   > "The Functional view is the cornerstone of most ADs... It usually drives 
   > the shape of other system structures such as the information structure, 
   > concurrency structure, deployment structure, and so on."
   > — Rozanski & Woods

2. **Views are Interrelated, Not Independent**
   > "The decisions taken in one view can have a considerable impact on the 
   > others, and it is a big part of the architect's job to make sure that 
   > these implications are understood."

3. **Perspectives Apply to Views**
   > "You never work with perspectives in isolation but instead use them with 
   > each view to analyze and validate the qualities of your architecture."

4. **Quality Over Speed**
   Architecture mistakes are expensive to fix. Sequential execution with 
   checkpoints is the default to ensure quality.

#### Viewpoint Dependency Graph

```text
                    ┌──────────┐
                    │ Context  │  (System boundaries)
                    └────┬─────┘
                         │
                         ▼
                 ┌───────────────┐
                 │  FUNCTIONAL   │  ★ CORNERSTONE ★
                 │  (Drives all  │  USER CHECKPOINT
                 │   other views)│  REQUIRED HERE
                 └───────┬───────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
   ┌───────────┐   ┌───────────┐   ┌───────────┐
   │Information│   │Concurrency│   │Development│
   │           │   │(optional) │   │           │
   └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
                         ▼
                  ┌────────────┐
                  │ Deployment │
                  └──────┬─────┘
                         │
                         ▼
                  ┌────────────┐
                  │ Operational│  (optional)
                  └────────────┘
```

#### Dynamic Viewpoint & Perspective Selection

Viewpoints and perspectives are selected dynamically based on system characteristics:

| Category | Always Included | Auto-Detected (Optional) |
|----------|-----------------|--------------------------|
| Viewpoints | Context, Functional | Information, Concurrency, Development, Deployment, Operational |
| Perspectives | Security, Performance | Accessibility, Availability, Evolution, Internationalization, Location, Regulation, Usability, Development Resource |

**Reference**: https://www.viewpoints-and-perspectives.info/

### Goal

Transform Architecture Decision Records (ADRs) into a comprehensive Architecture Description (AD.md) using a **multi-agent DAG orchestration** approach:

1. **Plan Agent**: Analyze ADRs, detect sub-systems, generate customized DAG, get user approval
2. **Execute Agent**: Generate views per sub-system following the DAG, with dependency context
3. **Summarize Agent**: Aggregate all views, resolve conflicts, generate unified AD.md

### Role & Context

You are acting as an **Architecture Orchestrator** managing a multi-phase documentation generation workflow. Your role involves:

- **Planning** the generation DAG based on sub-system analysis
- **Executing** view generation with proper dependency ordering
- **Summarizing** views into a unified Architecture Description
- **Persisting** state for resumability across AI agent sessions

#### Architecture Document Hierarchy

| Document | Purpose | Location |
|----------|---------|----------|
| `{REPO_ROOT}/.adlc/drafts/adr/` | Architectural decisions with rationale (individual file format) | Input |
| `{REPO_ROOT}/.adlc/architect/state.json` | DAG execution state | State |
| `{REPO_ROOT}/.adlc/architect/views/{subsystem}/{view}.md` | Per-view outputs | Reference |
| `{REPO_ROOT}/AD.md` | Full Architecture Description | Output |
| `{REPO_ROOT}/.adlc/memory/constitution.md` | Governance principles | Constraint |

**IMPORTANT - Path Resolution**:
- The setup script outputs `REPO_ROOT` - use this to determine the correct paths
- REPO_ROOT is found by searching upward from current directory for `.adlc` directory
- NEVER use relative paths like `.adlc/drafts/adr.md` - always use `{REPO_ROOT}/.adlc/drafts/adr/ADR-{NNN}.md`
- The setup script reads individual ADR files from the `adr/` directory
- When running from a subdirectory (e.g., a subproject directory), `.adlc` may be in the parent directory

#### View Templates

Located in the skill's `templates/` directory:

| Template | Purpose |
|----------|---------|
| `templates/views/context.md` | Context View template |
| `templates/views/functional.md` | Functional View template |
| `templates/views/information.md` | Information View template |
| `templates/views/concurrency.md` | Concurrency View template (optional) |
| `templates/views/development.md` | Development View template |
| `templates/views/deployment.md` | Deployment View template |
| `templates/views/operational.md` | Operational View template (optional) |

| Perspective Templates (10 total) |
|-----------------------------------|
| `templates/perspectives/security.md` |
| `templates/perspectives/performance.md` |
| `templates/perspectives/accessibility.md` |
| `templates/perspectives/availability.md` |
| `templates/perspectives/evolution.md` |
| `templates/perspectives/internationalization.md` |
| `templates/perspectives/location.md` |
| `templates/perspectives/regulation.md` |
| `templates/perspectives/usability.md` |
| `templates/perspectives/development-resource.md` |

### Three-Phase DAG Workflow

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          PHASE 1: PLAN                                      │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐ │
│  │ Load ADRs   │───▶│ Detect Sub-     │───▶│ Generate DAG per Sub-system │ │
│  │             │    │ systems         │    │ (apply customization rules) │ │
│  └─────────────┘    └─────────────────┘    └──────────────┬──────────────┘ │
│                                                           │                 │
│                                            ┌──────────────▼──────────────┐ │
│                                            │ Present Plan for Approval   │ │
│                                            │ (user confirms or modifies) │ │
│                                            └──────────────┬──────────────┘ │
│                                                           │                 │
│                                            ┌──────────────▼──────────────┐ │
│                                            │ Write state.json            │ │
│                                            └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          PHASE 2: EXECUTE                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  For each sub-system, execute DAG in topological order:             │   │
│  │                                                                      │   │
│  │  ┌─────────┐    ┌────────────┐    ┌─────────────┐    ┌───────────┐ │   │
│  │  │ Context │───▶│ Functional │───▶│ Information │───▶│Development│ │   │
│  │  └─────────┘    └────────────┘    └─────────────┘    └───────────┘ │   │
│  │                        │                                    │       │   │
│  │                        ▼                                    ▼       │   │
│  │               ┌─────────────┐                      ┌────────────┐  │   │
│  │               │ Concurrency │                      │ Deployment │  │   │
│  │               │ (optional)  │                      └────────────┘  │   │
│  │               └─────────────┘                             │        │   │
│  │                                                           ▼        │   │
│  │                                                   ┌─────────────┐  │   │
│  │                                                   │ Operational │  │   │
│  │                                                   │ (optional)  │  │   │
│  │                                                   └─────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Each view: Read dependencies → Generate content (with perspectives inline)
│             → Update state.json with progress                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          PHASE 3: SUMMARIZE                                 │
│  ┌──────────────────┐    ┌─────────────────────┐    ┌──────────────────┐   │
│  │ Read all view    │───▶│ Detect cross-       │───▶│ Resolve conflicts│   │
│  │ files            │    │ subsystem conflicts │    │ using ADRs       │   │
│  └──────────────────┘    └─────────────────────┘    └────────┬─────────┘   │
│                                                               │             │
│  ┌──────────────────┐                       ┌──────────────▼───────────┐ │
│  │ Move Accepted    │◀─────────────────────────│ Aggregate into            │ │
│  │ ADRs to memory   │                         │ unified AD.md (views include│ │
│  └──────────────────┘                         │ perspective sections)     │ │
│                                             └───────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **Note**: Perspectives (Security, Performance, etc.) are now applied **during** view generation in Phase 2, not as a separate step in Phase 3. This follows the R&W principle: "use them with each view to analyze and validate the qualities of your architecture."

### Pre-Flight Validation (MANDATORY - Hard Enforcement)

> **CRITICAL**: These validations are ENFORCED. Execution will HALT if checks fail.
> Use `--force` flag only in emergency situations with full understanding of risks.

**Before starting Phase 1, you MUST validate prerequisites:**

#### Workflow State Check (unless --force)

1. **Check clarify completion in state.json**:
   - Load `{REPO_ROOT}/.adlc/architect/state.json`
   - Check `workflow.clarify_completed` field
   - If `false` or missing:
     ```
     ❌ WORKFLOW VALIDATION FAILED

     The implement command requires ADRs to be approved via /architect-clarify first.

     Current workflow state: clarify_completed = false

     Required: Run /architect-clarify and complete Phase 5.5 (ADR Approval)

     Options:
     1. Run /architect-clarify to approve ADRs
     2. Use --force to bypass (NOT RECOMMENDED - may cause inconsistent architecture)

     ⚠️  Using --force skips important validation steps and may result in:
        - Processing unapproved ADRs
        - Missing critical architectural decisions
        - Incomplete architecture documentation
     ```
   - **HALT execution** (unless `--force` flag provided)

#### ADR Status Check

2. **Check ADRs exist**: Verify `{REPO_ROOT}/.adlc/drafts/adr/` or `{REPO_ROOT}/.adlc/memory/adr/` exists (individual file format)
3. **Check for Accepted ADRs**: Count ADRs with status "Accepted"
   - If **zero Accepted ADRs**: **STOP** and output:
     ```
     ❌ Cannot proceed: No Accepted ADRs found

     The implement command requires ADRs with "Accepted" status.
     Current ADRs are: [list statuses found]

     Run /architect-clarify to review and approve ADRs first.
     ```
   - If **≥1 Accepted ADR**: Proceed and report: "✓ Found N Accepted ADRs"

### Mandatory Execution Constraints

> **CRITICAL -- READ THIS BEFORE PROCEEDING**
>
> The following constraints are MANDATORY. Violation of any constraint
> invalidates the output and requires restart.
>
> #### Constraint 1: View Files MUST Be Written to Disk
> You **MUST** write each view to disk as a separate file before proceeding
> to the next view. Location: `{REPO_ROOT}/.adlc/architect/views/{subsystem}/{view}.md`
> - Do NOT hold views in memory and write only AD.md
> - Do NOT combine multiple views into a single write operation
> - Each file MUST be readable and standalone
> - Minimum content: 20 lines with proper section headers
>
> #### Constraint 2: State MUST Be Updated After EACH View
> You **MUST** update state.json immediately after EACH individual view
> file is written to disk and verified readable -- before starting the
> next view in the DAG. Do NOT batch updates per-subsystem or per-phase.
> Mark each view's progress as "completed" only AFTER the file exists on
> disk and you've verified it by reading it back.
>
> #### Constraint 3: Functional View Checkpoint is MANDATORY
> You **MUST** pause after Functional view for user checkpoint (unless `--no-checkpoint`).
> Do NOT silently continue. Present checkpoint options A/B/C/D and WAIT for response.
> The Functional view is the "cornerstone" -- user approval is required.
>
> #### Constraint 4: Phase "completed" Requires Verification
> You **MUST NOT** mark phase as "completed" in state.json until:
> - All view files exist on disk (verify by reading each file)
> - AD.md has been written with content aggregated from view files
> - Drafts cleanup has been performed and verified
> - The final verification table (10 checks) has been output
>
> #### Constraint 5: AD.md Content MUST Come From View Files
> You **MUST NOT** write AD.md directly from ADRs. AD.md content MUST come from
> reading the generated view files. The flow is strictly:
> ADRs → Views (files on disk) → AD.md (aggregated from views)
>
> #### Constraint 6: Phase 3 MUST Read From Disk
> You **MUST** read view files from disk in Phase 3, not from memory.
> Use file read operations. This ensures resumability and auditability.
> If a view file cannot be read, STOP and report the error.
>
> #### Constraint 7: Views MUST Be in Sub-system DAG
> You **MUST NOT** generate a view that is not listed in the sub-system's
> `dag` array in state.json. Before generating any view, check the DAG.
> If the view is absent, mark it as `skipped` in state.json and proceed.
> Generating views outside the DAG creates orphaned files and invalidates
> the architecture.
>
> #### Constraint 8: AD.md MUST Be Organized by Viewpoint
> You **MUST** organize AD.md by **viewpoint** (§3.1 Context, §3.2 Functional,
> §3.3 Information, etc.), **NOT** by subsystem. Each viewpoint section
> presents the **unified system-level** perspective that merges content
> from all subsystems. Subsystem-specific detail is accessible via
> "Subsystem Details" links (see Step 3.5).
>
> **WRONG** (per-subsystem — this is what subsystem view files are for):
> `## 5. Sub-System: Auth → ### 5.1 Context → ### 5.2 Functional`
>
> **RIGHT** (per-viewpoint — unified across ALL subsystems):
> `## 3. Architectural Views → ### 3.1 Context View → ### 3.2 Functional View`
>
> #### Constraint 9: Diagrams MUST Use Mermaid Syntax
> You **MUST** use Mermaid syntax for all architectural diagrams in both
> view files and AD.md. ASCII box-drawing art (characters like `┌`, `└`,
> `├`, `│`, `───`, `═══`) is **NOT** permitted for architecture diagrams.
>
> Accepted Mermaid diagram types:
> - `graph TB/LR` — architecture, topology, flow diagrams
> - `erDiagram` — data models and entity relationships
> - `sequenceDiagram` — interaction flows
> - `flowchart` — process flows
>
> Directory tree listings (code organization) may use plain `text`
> code blocks — these are not architectural diagrams.

### PHASE 1: PLAN (Plan Agent)

**Objective**: Analyze ADRs, detect sub-systems, generate customized DAG, get user approval

**Script Action**: Run `scripts/bash/setup-architect.sh` which calls `plan-dag` internally

#### Step 1.1: Load and Analyze ADRs

1. **Read ADR Directory**: Load ADRs from `{REPO_ROOT}/.adlc/drafts/adr/` (and check `{REPO_ROOT}/.adlc/memory/adr/` if drafts is empty)
2. **Parse ADR Index**: Extract sub-systems from `{REPO_ROOT}/.adlc/drafts/adr/adr.md` or individual ADR files
3. **Group ADRs by Sub-system**: Create mapping of sub-system → ADRs
4. **Validate ADR Status** (MANDATORY):
   - Count ADRs by status: Accepted / Proposed / Discovered
   - If **zero Accepted ADRs**: **STOP execution** and output error:
     ```
     ❌ PHASE 1 BLOCKED: No Accepted ADRs
     
     Found: [N] Proposed, [M] Discovered, [0] Accepted
     
     The implement command ONLY processes "Accepted" ADRs.
     Run /architect-clarify to approve ADRs before implementation.
     ```
   - Report to user: "✓ Found [N] Accepted ADRs ready for implementation"

**ADR Index Table Format**:

```markdown
| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|
| ADR-001 | Core | Microservices architecture | Accepted | 2024-01-15 | @architect |
| ADR-002 | Auth | OAuth2 with PKCE | Accepted | 2024-01-16 | @security |
| ADR-003 | Data | PostgreSQL primary store | Accepted | 2024-01-17 | @data |
```

#### Step 1.2: Detect Sub-systems and Characteristics

For each sub-system, analyze ADRs to detect:

| Characteristic | Detection Pattern | DAG Customization |
|---------------|-------------------|-------------------|
| Serverless | Lambda, Functions, serverless | Deployment view first |
| Event-driven | Events, messaging, async, Kafka, RabbitMQ | Include Concurrency view |
| Data-intensive | Analytics, ETL, data pipeline | Information view priority |
| API-first | REST, GraphQL, OpenAPI | Functional view priority |
| Multi-region | Global, multi-region, geo | Deployment + Operational |

#### Step 1.3: Generate Customized DAG per Sub-system

**Default DAG (Core Views)**:

```text
Context → Functional → Information → Development → Deployment
```

**Extended DAG (All Views)**:

```text
Context → Functional → Information ──┬─→ Development → Deployment → Operational
                                     └─→ Concurrency ─────────────────┘
```

**DAG Customization Rules**:

| Pattern Detected | DAG Modification |
|-----------------|------------------|
| Serverless | Deployment before Development |
| Event-driven | Add Concurrency after Information |
| Data-intensive | Information has highest priority after Context |
| Microservices | Add Concurrency, expand Functional |
| Monolith | Simplify Functional, skip Concurrency |

#### Step 1.4: Present Plan for User Approval

**Sub-System Count Threshold Enforcement** (MANDATORY):
Regardless of any prior approval from `/architect-specify`, you **MUST**
apply the following rules before presenting the DAG plan:

| Sub-System Count | Required Action |
|-----------------|-----------------|
| 1–3 | Present plan; auto-approve allowed |
| 4–6 | **MUST ask user confirmation** — do not proceed without explicit approval |
| >6 | **MUST suggest grouping** and **MUST ask confirmation** |

> **CRITICAL**: Approval from `/architect-specify` (Phase 0) does **NOT**
> substitute for DAG execution plan approval. The user must confirm the
> per-sub-system DAG plan independently.

Present the execution plan to the user:

```markdown
## DAG Execution Plan

**Sub-systems detected**: 3
**Total views to generate**: 15 (5 views × 3 sub-systems)

### Sub-system: Core
**ADRs**: ADR-001, ADR-005, ADR-008
**Characteristics**: Microservices, Event-driven
**DAG**: Context → Functional → Information → Concurrency → Development → Deployment

### Sub-system: Auth
**ADRs**: ADR-002, ADR-006
**Characteristics**: API-first
**DAG**: Context → Functional → Information → Development → Deployment

### Sub-system: Data
**ADRs**: ADR-003, ADR-004, ADR-007
**Characteristics**: Data-intensive
**DAG**: Context → Information → Functional → Development → Deployment

---

**Approve this plan?** [Yes/Modify/Cancel]
```

#### Step 1.5: Write state.json

After user approval, write the execution plan to `{REPO_ROOT}/.adlc/architect/state.json`:

```json
{
  "version": "1.1.0",
  "created_at": "2024-01-20T10:30:00Z",
  "updated_at": "2024-01-20T10:30:00Z",
  "phase": "plan_approved",
  "views_mode": "core",
  "workflow": {
    "clarify_completed": false,
    "clarify_completed_at": null,
    "adrs_approved_count": 0,
    "implement_started": false,
    "implement_started_at": null
  },
  "subsystems": [
    {
      "id": "core",
      "name": "Core",
      "adrs": ["ADR-001", "ADR-005", "ADR-008"],
      "characteristics": ["microservices", "event-driven"],
      "dag": ["context", "functional", "information", "concurrency", "development", "deployment"],
      "progress": {
        "context": "pending",
        "functional": "pending",
        "information": "pending",
        "concurrency": "pending",
        "development": "pending",
        "deployment": "pending"
      }
    },
    {
      "id": "auth",
      "name": "Auth",
      "adrs": ["ADR-002", "ADR-006"],
      "characteristics": ["api-first"],
      "dag": ["context", "functional", "information", "development", "deployment"],
      "progress": {
        "context": "pending",
        "functional": "pending",
        "information": "pending",
        "development": "pending",
        "deployment": "pending"
      }
    }
  ],
  "perspectives": ["security", "performance"],
  "output_file": "AD.md"
}
```

### PHASE 2: EXECUTE (Execute Agent)

**Objective**: Generate views per sub-system following the DAG, with dependency context passing

**Script Action**: The agent reads `state.json` and executes views in DAG order

#### Step 2.1: Read Execution State

1. Load `{REPO_ROOT}/.adlc/architect/state.json`
2. Identify next view(s) to generate (views with all dependencies completed)
3. Load relevant ADRs for the current sub-system

#### Step 2.2: Generate Views in DAG Order

For each view in the DAG:

0. **DAG Membership Check**: Confirm the view is listed in the sub-system's
   `dag` array in state.json. If absent → mark `skipped`, do NOT generate,
   continue to next view.
1. **Check Dependencies**: Ensure all dependency views are completed
2. **Load Dependency Context**: Read completed view files for context
3. **Load View Template**: Read from `templates/views/{view}.md`
4. **Generate View Content**: Fill template with ADR-derived content
5. **Write View File**: Save to `{REPO_ROOT}/.adlc/architect/views/{subsystem}/{view}.md`
6. **Update State**: Mark view as "completed" in state.json

**View Generation with Dependency Context**:

```markdown
## Generating: Functional View for "Core" sub-system

**Dependencies loaded**:
- Context View: {REPO_ROOT}/.adlc/architect/views/core/context.md (completed)

**ADRs for this view**: ADR-001 (Microservices), ADR-005 (API Gateway)

**Generating content...**
```

#### Step 2.3: View Templates and Placeholders

Each view template contains placeholders to be filled:

| Placeholder | Replacement |
|-------------|-------------|
| `[SUB_SYSTEM_NAME]` | Sub-system name from state.json |
| `[ADR_IDS]` | Comma-separated ADR IDs |
| `[DATE]` | Current date (YYYY-MM-DD) |
| `[ENTITY_N]` | Extracted from ADRs |
| `[COMPONENT_N]` | Extracted from ADRs |

#### Step 2.4: View Generation Details

##### Context View

**Purpose**: System scope and external interactions (blackbox view)
**Dependencies**: None (first in DAG)
**Template**: `templates/views/context.md`
**Key Content**:

- System scope description
- External entities table (stakeholders + external systems only)
- Context diagram (system as single blackbox)
- External dependencies table

##### Functional View (★ CORNERSTONE - USER CHECKPOINT)

**Purpose**: Internal components, responsibilities, interactions
**Dependencies**: Context View
**Template**: `templates/views/functional.md`
**Key Content**:

- Functional elements table
- Element interactions diagram
- Functional boundaries

> **IMPORTANT**: After generating the Functional view, execution **pauses** for user approval.
> This is the "cornerstone" view that shapes all subsequent views.
> 
> **Rozanski & Woods**: "The Functional view is the cornerstone... It usually drives the shape of other system structures."
> 
> **Checkpoint Options**:
> - **A**: Approve - Continue to remaining views
> - **B**: Modify - Edit functional view, then continue
> - **C**: Restart - Regenerate with feedback
> - **D**: Cancel - Stop execution

**If skipping checkpoint** (`--no-checkpoint` flag): Generate without pause but log warning.

##### Information View

**Purpose**: Data storage, management, and flow
**Dependencies**: Context View, Functional View
**Template**: `templates/views/information.md`
**Key Content**:

- Data entities table
- ER diagram
- Data flow description

##### Concurrency View (Optional)

**Purpose**: Runtime processes, threads, coordination
**Dependencies**: Functional View, Information View
**Template**: `templates/views/concurrency.md`
**Condition**: Only if `--views all` or `--views concurrency`
**Key Content**:

- Process structure table
- Sequence diagram
- Coordination mechanisms

##### Development View

**Purpose**: Code organization, dependencies, CI/CD
**Dependencies**: Functional View
**Template**: `templates/views/development.md`
**Key Content**:

- Code organization structure
- Module dependencies
- Build & CI/CD description

##### Deployment View

**Purpose**: Physical environment, nodes, networks
**Dependencies**: Development View
**Template**: `templates/views/deployment.md`
**Key Content**:

- Runtime environments table
- Network topology diagram
- Hardware requirements

##### Operational View (Optional)

**Purpose**: Operations, support, maintenance
**Dependencies**: Deployment View
**Template**: `templates/views/operational.md`
**Condition**: Only if `--views all` or `--views operational`
**Key Content**:

- Operational responsibilities
- Monitoring & alerting
- Disaster recovery

#### Step 2.5: Update Progress in state.json

> **WARNING**: Batching state updates (e.g., updating only after all views
> for a sub-system are complete) violates Constraint 2. Update state.json
> immediately after each individual view file is written and verified.

After each view is generated:

```json
{
  "progress": {
    "context": "completed",
    "functional": "completed",
    "information": "in_progress",
    "development": "pending",
    "deployment": "pending"
  },
  "updated_at": "2024-01-20T11:15:00Z"
}
```

#### Step 2.6: Resumability

If the agent session is interrupted:

1. Next session loads `state.json`
2. Identifies views with `"pending"` or `"in_progress"` status
3. Continues from where it left off
4. Skips already `"completed"` views

#### Phase 2→3 Gate: Verify View Files Exist (MANDATORY)

**Before proceeding to Phase 3, you MUST verify that all expected view files exist on disk:**

1. For each subsystem in state.json, check every view with status "completed"
2. Verify the file exists: `{REPO_ROOT}/.adlc/architect/views/{subsystem}/{view}.md`
3. Verify each file is readable and has minimum content (≥20 lines)
4. **Mermaid scan (Constraint 9)**: Scan each view file for ASCII box-drawing
   characters (`┌`, `└`, `├`, `│`, `═`, `───`). If found in any view that
   should contain architectural diagrams (context, functional, information,
   deployment), flag as a warning and note the file for correction.

**Verification Checklist** (output this table):

| Subsystem | View | File Path | Exists | Readable | Lines | Mermaid OK |
|-----------|------|-----------|--------|----------|-------|------------|
| {subsystem} | {view} | {path} | ✓/✗ | ✓/✗ | {N} | ✓/⚠ |

**Gate Decision:**
- If **ALL checks pass** → Proceed to Phase 3
- If **Mermaid warnings** → Log warnings but proceed (non-blocking). Output:
  ```
  ⚠️ MERMAID WARNING: ASCII box-drawing art detected in:
  - {subsystem}/{view}: Convert to Mermaid diagram syntax
  
  Proceeding to Phase 3. Fix ASCII diagrams in next iteration.
  ```
- If **ANY other check fails** → STOP and report:
  ```
  ❌ PHASE 2→3 GATE BLOCKED
  
  Missing or invalid view files detected:
  - {subsystem}/{view}: [reason]
  
  Regenerate missing views before proceeding to Phase 3.
  ```

### Placeholder Validation (MANDATORY)

**Before finalizing any view file, you MUST validate that all placeholders are filled:**

#### Placeholder Patterns to Check

| Pattern | Example | Severity | Action Required |
|---------|---------|----------|-----------------|
| `[TBD]` | `[TBD]` | CRITICAL | Must be filled before completion |
| `[STAKEHOLDER_*]` | `[STAKEHOLDER_1]` | CRITICAL | Must be replaced with actual stakeholder names |
| `[ENTITY_*]` | `[ENTITY_1]` | CRITICAL | Must be replaced with actual entity names |
| `[COMPONENT_*]` | `[COMPONENT_1]` | CRITICAL | Must be replaced with actual component names |
| `[SUB_SYSTEM_NAME]` | `[SUB_SYSTEM_NAME]` | CRITICAL | Must be replaced with actual sub-system name |
| `[ADR_IDS]` | `[ADR_IDS]` | HIGH | Must be replaced with actual ADR references |
| `[DATE]` | `[DATE]` | MEDIUM | Must be replaced with actual date |

#### Validation Process

1. **Scan each view file** after generation for unfilled placeholders
2. **Count occurrences** of each pattern
3. **Severity Assessment**:
   - **CRITICAL**: Blocks completion - view cannot be marked "completed"
   - **HIGH**: Should be filled but non-blocking if context is clear
   - **MEDIUM**: Nice to have but not required

#### Validation Report Template

```markdown
## Placeholder Validation Report

| View | Placeholder | Count | Severity | Status |
|------|-------------|-------|----------|--------|
| context | [STAKEHOLDER_1] | 3 | CRITICAL | ❌ UNFILLED |
| functional | [COMPONENT_1] | 5 | CRITICAL | ❌ UNFILLED |

### Critical Placeholders Unfilled

**❌ VALIDATION FAILED**: Cannot mark views as "completed" with unfilled critical placeholders.

**Required Actions**:
1. Review ADRs for stakeholder names → fill [STAKEHOLDER_*] placeholders
2. Review ADRs for component names → fill [COMPONENT_*] placeholders
3. Re-run view generation with complete information
```

#### Enforcement

- Views with unfilled CRITICAL placeholders **CANNOT** be marked "completed" in state.json
- Phase 2→3 gate **WILL FAIL** if any view has unfilled critical placeholders
- Use `--force` to bypass (emergency only - document all unfilled placeholders)

### PHASE 3: SUMMARIZE (Summarize Agent)

**Objective**: Aggregate all views, resolve conflicts, generate unified AD.md

**Script Action**: Run `summarize` action

#### Step 3.1: Read All View Files FROM DISK (MANDATORY)

> **CRITICAL**: You MUST read each view file from the filesystem using actual file read operations. 
> Do NOT use content from memory or from the ADRs directly. The view files are the SOLE source of truth.

1. **Scan Directory**: List `{REPO_ROOT}/.adlc/architect/views/` directory
2. **Read Each File** (MANDATORY - file by file):
   - For each subsystem/view combination in state.json
   - Read the file: `{REPO_ROOT}/.adlc/architect/views/{subsystem}/{view}.md`
   - If file cannot be read → **STOP** and report error:
     ```
     ❌ PHASE 3 ERROR: Cannot read view file
     File: {path}
     Error: {error details}
     
     View files must exist and be readable before AD.md generation.
     ```
3. **Validate Content** (MANDATORY):
   - Each view file MUST contain ≥20 lines
   - Each view MUST contain proper section headers (## or ###)
   - If content validation fails → **STOP** and report:
     ```
     ❌ PHASE 3 ERROR: Invalid view file content
     File: {path}
     Lines: {count} (minimum 20 required)
     
     View files must have substantial content before AD.md generation.
     ```
4. **Organize**: Group content by view type across all sub-systems

**Directory Structure**:

```text
{REPO_ROOT}/.adlc/architect/views/
├── core/
│   ├── context.md
│   ├── functional.md
│   ├── information.md
│   ├── concurrency.md
│   ├── development.md
│   └── deployment.md
├── auth/
│   ├── context.md
│   ├── functional.md
│   ├── information.md
│   ├── development.md
│   └── deployment.md
└── data/
    ├── context.md
    ├── functional.md
    ├── information.md
    ├── development.md
    └── deployment.md
```

#### Step 3.2: Detect Cross-Subsystem Conflicts

Compare views across sub-systems for:

| Conflict Type | Detection | Resolution |
|--------------|-----------|------------|
| Naming inconsistency | Same component, different names | Standardize to ADR terminology |
| Technology mismatch | Different tech for same purpose | Defer to relevant ADR |
| Boundary overlap | Components claimed by multiple sub-systems | Use ADR scope definitions |
| Diagram inconsistency | Same entity, different representations | Unify styling |

#### Step 3.3: Resolve Conflicts Using ADRs

**ADRs are the Source of Truth**. When conflicts are detected:

1. Find the relevant ADR(s) that govern the conflicting area
2. Apply the ADR decision to resolve the conflict
3. Document the resolution in the unified view

```markdown
## Conflict Resolution Log

| Conflict | ADR Reference | Resolution |
|----------|---------------|------------|
| Auth component naming | ADR-002 | Standardized to "AuthService" per ADR-002 |
| Database technology | ADR-003 | PostgreSQL confirmed as primary per ADR-003 |
```

#### Step 3.4: Aggregate into Unified AD.md

> **CRITICAL: Viewpoint-Organized Aggregation (Constraint 8)**
>
> The AD.md MUST follow the structure below, organized by **viewpoint**.
> Each viewpoint section merges content from ALL subsystems into a unified
> system-level description. Do NOT organize by subsystem -- that structure
> belongs in the subsystem view files, not in the aggregated AD.md.
>
> For each viewpoint:
> 1. Present a **system-level summary** that shows how all subsystems relate
> 2. Include a **unified Mermaid diagram** showing cross-subsystem interactions
> 3. Summarize each subsystem's role within this viewpoint
> 4. Link to subsystem details (if 2+ subsystems, per Step 3.5)

##### Per-Viewpoint Aggregation Recipe

| Viewpoint | How to Aggregate |
|-----------|-----------------|
| **Context** | Single system-level blackbox diagram (Mermaid `graph`). Subsystems appear as internal blocks only if they have independent external interfaces. Merge and deduplicate stakeholder and external entity tables across all subsystems. |
| **Functional** | Merged component inventory table across all subsystems. Single unified interaction diagram showing cross-subsystem data flows. Use Mermaid `subgraph` blocks per subsystem to show boundaries. |
| **Information** | Consolidated ER diagram (Mermaid `erDiagram`) combining all subsystem entities. Unified data flow showing how data moves across subsystem boundaries (Mermaid `flowchart`). Deduplicate entity tables. |
| **Concurrency** | Merged process structure table. Unified sequence/flow diagrams showing cross-subsystem async interactions. |
| **Development** | Single code organization tree showing all subsystems as top-level directories. Merged build process and CI/CD pipeline tables. Unified technology stack mapping. |
| **Deployment** | Single deployment topology diagram (Mermaid `graph`) showing all subsystems in their runtime environments. Merged runtime environments and hardware requirements tables. |
| **Operational** | Merged operational responsibilities table. Unified monitoring, alerting, and DR strategy across all subsystems. |

**Structure of Unified AD.md**:

```markdown
# Architecture Description: [Project Name]

## 1. Document Information
[Version, date, authors, status]

## 2. Architectural Goals & Constraints
[From constitution and constraint ADRs]

## 3. Architectural Views

### 3.1 Context View
[Unified from all sub-system context views]
[Single system-level context diagram]

> **Subsystem Details**: [Core](.adlc/architect/views/core/context.md) | [Auth](.adlc/architect/views/auth/context.md) | [Data](.adlc/architect/views/data/context.md)

### 3.2 Functional View
[Merged functional elements from all sub-systems]
[Unified component diagram]

> **Subsystem Details**: [Core](.adlc/architect/views/core/functional.md) | [Auth](.adlc/architect/views/auth/functional.md) | [Data](.adlc/architect/views/data/functional.md)

### 3.3 Information View
[Consolidated data model]
[Unified ER diagram]

> **Subsystem Details**: [Core](.adlc/architect/views/core/information.md) | [Auth](.adlc/architect/views/auth/information.md) | [Data](.adlc/architect/views/data/information.md)

### 3.4 Concurrency View (if applicable)
[Merged from sub-systems with concurrency]

> **Subsystem Details**: [Core](.adlc/architect/views/core/concurrency.md) | [Auth](.adlc/architect/views/auth/concurrency.md)

### 3.5 Development View
[Unified code organization]

> **Subsystem Details**: [Core](.adlc/architect/views/core/development.md) | [Auth](.adlc/architect/views/auth/development.md) | [Data](.adlc/architect/views/data/development.md)

### 3.6 Deployment View
[Consolidated deployment topology]

> **Subsystem Details**: [Core](.adlc/architect/views/core/deployment.md) | [Auth](.adlc/architect/views/auth/deployment.md) | [Data](.adlc/architect/views/data/deployment.md)

### 3.7 Operational View (if applicable)
[Merged operational concerns]

> **Subsystem Details**: [Core](.adlc/architect/views/core/operational.md) | [Auth](.adlc/architect/views/auth/operational.md)

## 4. Architectural Perspectives

### 4.1 Security Perspective
[Apply security template across all views]

### 4.2 Performance & Scalability Perspective
[Apply performance template across all views]

## 5. Architecture Decision Records Summary
[Index linking to {REPO_ROOT}/.adlc/memory/adr.md]

## 6. Tech Stack Summary
[Consolidated from all ADRs]
```

#### Step 3.5: Generate Subsystem View Links (CONDITIONAL)

**Condition**: Only generate links if `len(state.json.subsystems) > 1`

For each view section in AD.md:

1. **Collect subsystem links**:
   - For each subsystem in state.json
   - Check if view exists in subsystem's `dag` array
   - Build link: `[SubsystemName](.adlc/architect/views/{subsystem-id}/{view}.md)`

2. **Format link block**:
   ```markdown
   > **Subsystem Details**: [Core](path) | [Auth](path) | [Data](path)
   ```

3. **Handle missing views**:
   - If a subsystem doesn't have a particular view (not in `dag`), skip that subsystem's link
   - Example: If Auth doesn't have Concurrency view, omit from Concurrency links

4. **Single subsystem case**:
   - If only 1 subsystem exists, **SKIP** adding links entirely
   - The unified view is identical to the subsystem view, making links redundant

**Example Output** (3 subsystems, all have Context view):
```markdown
### 3.1 Context View
[Unified system-level context]

> **Subsystem Details**: [Core](.adlc/architect/views/core/context.md) | [Auth](.adlc/architect/views/auth/context.md) | [Data](.adlc/architect/views/data/context.md)
```

**Example Output** (2 subsystems, only Core has Concurrency):
```markdown
### 3.4 Concurrency View
[Merged concurrency concerns]

> **Subsystem Details**: [Core](.adlc/architect/views/core/concurrency.md)
```

#### Step 3.6: Apply Perspectives

Load perspective templates and apply across all views:

##### Security Perspective (`templates/perspectives/security.md`)

- Authentication & authorization approach
- Data protection measures
- Threat model table

##### Performance Perspective (`templates/perspectives/performance.md`)

- Performance requirements table
- Scalability model
- Capacity planning

#### Step 3.7: ADR Lifecycle Management (MANDATORY)

After generating AD.md, perform ALL of the following steps:

**Step 1: Filter Accepted ADRs**
- Identify ADRs with **exact** status "Accepted" only
- **MUST remain in drafts**: Any ADR with status "Proposed", "Discovered",
  "Deprecated", or "Superseded" — these are NOT eligible for promotion
- **Verification**: After filtering, count non-Accepted ADRs in the promotion
  set. If >0, STOP and fix before proceeding.

**Step 2: Copy to Canonical Location (MANDATORY)**
- Move Accepted ADR files into `{REPO_ROOT}/.adlc/memory/adr/`
- Create the file if it doesn't exist, or merge with existing content
- **VERIFY**: Read the file back and confirm ADRs are present

**Step 3: Clean Up Drafts (MANDATORY)**
 - Move each promoted ADR file from `{REPO_ROOT}/.adlc/drafts/adr/` to `{REPO_ROOT}/.adlc/memory/adr/`
 - If no ADRs remain in drafts → the setup script cleans up empty directories
 - **VERIFY**: Confirm:
   - No duplicate ADRs exist (same ID in both locations)
   - Remaining ADRs (if any) are Proposed/Discovered only
   - `adr.md` and `adr.md` index regenerated for both scopes

**Step 4: Report Lifecycle Changes (MANDATORY)**
Output this summary to the user:
```
📋 ADR Lifecycle Summary:
├── Promoted to memory: [N] Accepted ADRs
├── Remaining in drafts: [M] ADRs (Proposed/Discovered)
├── Duplicates found: [0] ✓
└── Cleanup verified: ✓
```

**If ANY step fails**: STOP and fix before marking Phase 3 complete.

#### Step 3.8: Generate Final Report

```markdown
## Architecture Description Generated

**Output**: AD.md (project root)
**Views Mode**: [core|all|custom]
**Sub-systems Processed**: N

**Views Generated**:
| Sub-system | Views | Status |
|------------|-------|--------|
| Core | Context, Functional, Information, Concurrency, Development, Deployment | ✓ |
| Auth | Context, Functional, Information, Development, Deployment | ✓ |
| Data | Context, Functional, Information, Development, Deployment | ✓ |

**Perspectives Applied**:
- [x] Security
- [x] Performance & Scalability

**Conflicts Resolved**: M
**ADR Coverage**: X/Y ADRs incorporated

**ADR Lifecycle**:
- Promoted to canonical: N ADRs
- Remaining in drafts: M ADRs

**Recommended Next Steps**:
1. Review generated AD.md for accuracy
2. Run `/architect-analyze` for consistency validation
3. Share with stakeholders for review
4. Run `/architect-analyze` to validate the generated architecture
```

### Final Completion Verification (MANDATORY)

**Before marking state.json phase as "completed", verify ALL outputs:**

Run this 10-point verification checklist:

| Check | Expected | Verification Method | Status |
|-------|----------|---------------------|--------|
| 1. View files on disk | N files (one per view per subsystem) | List `{REPO_ROOT}/.adlc/architect/views/` | ☐ |
| 2. AD.md exists | Yes, at project root | Check file existence | ☐ |
| 3. AD.md content size | >200 lines | Count lines in AD.md | ☐ |
| 4. AD.md has all views | N sections (## 3.x headers) | Parse AD.md headers | ☐ |
| 5. Memory ADRs promoted | N Accepted ADRs | Count files in `{REPO_ROOT}/.adlc/memory/adr/` | ☐ |
| 6. Drafts cleaned | No duplicates | Compare drafts vs memory | ☐ |
| 7. state.json consistent | All views "completed" | Verify progress field | ☐ |
| 8. Subsystem links (if applicable) | Links in AD.md (if 2+ subsystems) | Scan AD.md for "Subsystem Details" | ☐ |
| 9. Viewpoint-organized (Constraint 8) | No `## N. Sub-System:` sections | Scan AD.md for per-subsystem top-level headers | ☐ |
| 10. Mermaid diagrams (Constraint 9) | No ASCII box-drawing art | Scan AD.md for `┌`, `└`, `├`, `═` characters | ☐ |

**Gate Rule:**
- If **ALL checks pass** (☑): Mark phase as "completed" in state.json
- If **ANY check fails** (☒): Do NOT mark as completed. Fix the issue and re-verify.

**Output to User:**
```
✅ Architecture Description Generation Complete

Verification Results:
├── View files: [N] generated ✓
├── AD.md: [lines] lines, [sections] views ✓
├── Subsystem links: [N] links (if applicable) ✓
├── Viewpoint-organized: ✓
├── Mermaid diagrams: ✓
├── ADRs promoted: [N] to memory ✓
├── Drafts cleaned: [N] remaining ✓
└── State consistent: ✓

Status: READY FOR USE
```

### State File Schema

**Location**: `{REPO_ROOT}/.adlc/architect/state.json`

```json
{
  "version": "1.1.0",
  "created_at": "ISO8601 timestamp",
  "updated_at": "ISO8601 timestamp",
  "phase": "planning | plan_approved | executing | summarizing | completed",
  "views_mode": "core | all | custom",
  "subsystems": [
    {
      "id": "lowercase-kebab-case",
      "name": "Display Name",
      "adrs": ["ADR-001", "ADR-002"],
      "characteristics": ["microservices", "event-driven"],
      "dag": ["context", "functional", "information", "development", "deployment"],
      "progress": {
        "context": "pending | in_progress | completed | skipped",
        "functional": "pending | in_progress | completed | skipped"
      }
    }
  ],
  "perspectives": ["security", "performance"],
  "conflicts_detected": [],
  "conflicts_resolved": [],
  "output_file": "AD.md"
}
```

### Key Rules

#### ADR Traceability

- **Every view section** must reference source ADRs
- **No content** without ADR backing
- **ADRs are source of truth** for conflict resolution

#### State Persistence

- **Always update** state.json after each operation
- **Resume gracefully** from any interruption
- **Track progress** at view granularity

#### Multi-Agent Compatibility

- State file works with any AI agent (Claude, Copilot, Cursor, etc.)
- No agent-specific dependencies
- Human-readable state for debugging

#### Diagram Quality

- **Validate** Mermaid syntax before writing
- **Consistent styling** across sub-systems
- **Unified diagrams** in final AD.md

### Context

$ARGUMENTS

## Next Steps

After implement completes, run `/architect-analyze` to validate consistency and quality.

## Verification

- **AD.md exists** at `{REPO_ROOT}/AD.md` with more than 200 lines and all viewpoint sections (`## 3.x` headers).
- **Per-subsystem view files** exist at `{REPO_ROOT}/.adlc/architect/views/{subsystem}/{view}.md` for every completed view.
- **state.json is consistent**: all generated views are marked `"completed"` and the phase is `"completed"`.
- **Accepted ADRs promoted**: all ADRs with status `"Accepted"` are copied to `{REPO_ROOT}/.adlc/memory/adr.md`.
- **Drafts cleaned up**: promoted ADR files moved from `{REPO_ROOT}/.adlc/drafts/adr/` to `{REPO_ROOT}/.adlc/memory/adr/`; no duplicates remain; any remaining drafts are Proposed/Discovered only.
- **AD.md is viewpoint-organized**: sections are grouped by viewpoint (`## 3. Architectural Views → ### 3.1 Context View`, etc.), not by subsystem.
- **Mermaid-only diagrams**: no ASCII box-drawing characters (`┌`, `└`, `├`, `│`, `═`, `───`) are used for architectural diagrams.
- **Placeholder validation passed**: no critical placeholders (`[TBD]`, `[STAKEHOLDER_*]`, `[ENTITY_*]`, `[COMPONENT_*]`, `[SUB_SYSTEM_NAME]`) remain unfilled in view files.
- **Subsystem detail links** are present in AD.md when two or more subsystems were processed.