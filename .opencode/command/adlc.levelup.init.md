---
description: Scan codebase and discover Context Directive Records (CDRs) for team-ai-directives
  contributions
handoffs:
- label: Resolve Ambiguities
  agent: adlc.levelup.clarify
  prompt: 'Review CDRs discovered from brownfield codebase analysis.

    Ask questions about:

    - Pattern validity (are inferred patterns still relevant?)

    - Team scope (is this pattern team-wide or project-specific?)

    - Existing coverage (does team-ai-directives already have this?)

    - Priority (high-value vs nice-to-have patterns)

    Focus on validating assumptions, not suggesting new patterns.

    '
  send: true
- label: Refine from Feature Context
  agent: adlc.levelup.specify
  prompt: Refine CDRs using current feature spec context
  send: false
scripts:
  sh: .specify/extensions/levelup/scripts/bash/setup-levelup.sh --json
  ps: .specify/extensions/levelup/scripts/powershell/setup-levelup.ps1 -Json
---


<!-- Extension: levelup -->
<!-- Config: .specify/extensions/levelup/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Python FastAPI backend with PostgreSQL"` - Focus on Python patterns
- `"Focus on testing patterns"` - Narrow to testing-related CDRs
- `"--cdr-heuristic all"` - Document all patterns, not just surprising ones
- `"--focus rules"` - Only discover rule-type patterns
- Empty input: Scan entire codebase for all context types

When users provide context, use it to focus the discovery effort.

## Goal

Scan an **existing codebase** (brownfield) and discover patterns that could become contributions to team-ai-directives. Create **Context Directive Records (CDRs)** documenting discovered patterns.

**Output**:

1. **Proposed modules** added to `{REPO_ROOT}/.specify/drafts/cdr.md` with status "Discovered" or "Proposed"
2. **Summary** of discovered patterns by context type
3. **Manual handoff options** to `/levelup.clarify` or `/levelup.specify`

**Key Concept**:

This command is the "Context Archaeologist" - it uncovers implicit team AI directive patterns from code, similar to how `/architect.init` discovers architecture decisions.

### Flags

- `--cdr-heuristic HEURISTIC`: CDR generation strategy
  - `surprising` (default): Only document patterns not already in team-ai-directives
  - `all`: Document all discovered patterns
  - `minimal`: Only high-value/novel patterns

- `--focus AREA`: Focus on specific context type
  - `rules`: Only scan for coding rules
  - `personas`: Only scan for role patterns
  - `examples`: Only scan for example-worthy code
  - `constitution`: Only scan for governance patterns
  - `skills`: Only scan for skill-worthy capabilities

- `--no-decompose`: Disable automatic context type categorization

## Role & Context

You are acting as a **Context Archaeologist** uncovering implicit team AI directive patterns from code. Your role involves:

- **Scanning** codebase for coding patterns and best practices
- **Inferring** context modules that would benefit other projects
- **Documenting** discovered patterns as CDRs
- **Comparing** against existing team-ai-directives to avoid duplicates

### Brownfield Context Discovery

| Context Type | What to Look For | Example Patterns |
|--------------|------------------|------------------|
| **Rules** | Coding patterns, error handling, testing | Custom error classes, test fixtures, logging patterns |
| **Personas** | Domain expertise, specialized logic | Domain-specific validation, business rule implementations |
| **Examples** | Reusable code, prompt patterns | API implementations, test patterns, configuration |
| **Constitution** | Governance, quality standards | Code review patterns, documentation standards |
| **Skills** | Self-contained capabilities | Deployment scripts, data processing pipelines |

## Outline

1. **Validate Environment** (Phase 1): Ensure team-ai-directives is configured
2. **Sub-System Detection** (Phase 2): Identify sub-systems from code structure (auto-detect)
3. **Environment Setup** (Phase 3): Resolve paths and setup directories
4. **Load Existing Directives** (Phase 4): Read team-ai-directives to compare against
5. **Codebase Scan** (Phase 5): Analyze project for context patterns (per sub-system if decomposed)
6. **Pattern Detection** (Phase 6): Identify patterns by context type
7. **Deduplication** (Phase 7): Filter out patterns already in team-ai-directives
8. **CDR Generation** (Phase 8): Create CDRs for discovered patterns (status: "proposed")
9. **Gap Analysis** (Phase 9): Identify areas where patterns are unclear
10. **Output** (Phase 10): Write CDRs to `{REPO_ROOT}/.specify/drafts/cdr.md`
11. **Handoff Options** (Phase 11): Present next step options

## Execution Steps

### Phase 1: Validate Environment

**Objective**: Ensure team-ai-directives is configured

#### Step 1: Verify Team Directives

Check if TEAM_DIRECTIVES has a value from script output.

If empty, **STOP**:
```
Team AI directives repository not configured.
Run: specify init --team-ai-directives <path-or-url>
Or set: export SPECIFY_TEAM_DIRECTIVES=/path/to/team-ai-directives
```

### Phase 2: Sub-System Detection (Brownfield)

**Objective**: Identify sub-systems from existing code structure automatically

**When**: This phase runs automatically when the codebase is detected as having multiple distinct modules/packages. Use `--no-decompose` to skip.

#### Step 1: Directory Structure Analysis

Analyze the codebase for distinct sub-systems based on directory structure:

| Pattern | Likely Sub-System |
|---------|------------------|
| `src/auth/` | Authentication sub-system |
| `src/users/` | User management sub-system |
| `services/payment/` | Payment sub-system |
| `modules/inventory/` | Inventory sub-system |
| `apps/api/`, `apps/web/` | Monorepo with separate apps |
| `lib/core/`, `lib/shared/` | Shared libraries (not a sub-system) |

#### Step 2: Package/Module Detection

Detect sub-systems from package/module structures:

| Pattern | Detection Method | Sub-System Evidence |
|---------|------------------|-------------------|
| **Node.js workspaces** | package.json workspaces | Multiple packages = multiple sub-systems |
| **Python namespaces** | `__init__.py` hierarchy | Multiple top-level packages |
| **Go modules** | go.mod + directories | Multiple directories under cmd/ |
| **Maven/Gradle** | pom.xml modules | Multiple modules in multi-module project |
| **Docker services** | docker-compose services | Each service = sub-system |

#### Step 3: Sub-System Proposal (Interactive)

Present detected sub-systems to user for confirmation:

```markdown
## Detected Sub-Systems

I've identified the following sub-systems from your codebase:

| # | Sub-System | Detection Method | Evidence |
|---|------------|-----------------|----------|
| 1 | **auth** | Directory + Module | src/auth/, auth/ package |
| 2 | **users** | Directory | src/users/, services/user/ |
| 3 | **payments** | Directory + Docker | services/payment/, payment service in docker-compose |
| 4 | **inventory** | Directory | src/inventory/, modules/stock/ |

### Questions for Confirmation:

1. **Are these sub-systems correct?** [Y/n]
2. **Should any sub-systems be merged?** (e.g., auth + users → identity)
3. **Should any sub-systems be split?** (e.g., payments → billing + subscriptions)
4. **Any missing sub-systems?** (e.g., analytics, reporting)

**Reply** with:
- `Y` to confirm and proceed
- `n` to disable decomposition (generate monolithic CDRs)
- Specific changes (e.g., "merge 1+2", "split 3", "add Notifications")
```

#### Step 4: Decomposition Decision

Based on user response:

| Response | Action |
|----------|--------|
| `Y` / Enter | Proceed with detected sub-systems |
| `n` | Skip decomposition, generate monolithic CDRs |
| Modifications | Adjust sub-systems, then proceed |
| Empty/Default | Auto-proceed if ≤3 sub-systems, ask if >3 |

**Threshold Logic**:
- **≤3 sub-systems**: Auto-approve, show summary
- **4-6 sub-systems**: Show summary, ask to confirm
- **>6 sub-systems**: Show summary, suggest grouping, ask to confirm

#### Step 5: Output

After confirmation, output structured sub-system data:

```json
{
  "decomposition": "enabled",
  "subsystems": [
    {"id": "auth", "name": "Auth", "detection_method": "directory", "evidence": "src/auth/"},
    {"id": "users", "name": "Users", "detection_method": "directory", "evidence": "src/users/"},
    {"id": "payments", "name": "Payments", "detection_method": "docker", "evidence": "payment service in docker-compose"}
  ],
  "next_phase": "Codebase Analysis (per sub-system)"
}
```

**If decomposition disabled**:
```json
{
  "decomposition": "disabled",
  "reason": "user_requested",
  "next_phase": "Codebase Analysis (monolithic)"
}
```

---

### Phase 3: Environment Setup

**Objective**: Resolve paths and validate infrastructure

#### Step 1: Setup Directories

Run `.specify/extensions/levelup/scripts/bash/setup-levelup.sh --json` to set up the infrastructure:

- Creates skills drafts directory at `{REPO_ROOT}/.specify/drafts/skills/`
- Returns JSON with `TEAM_DIRECTIVES`, `REPO_ROOT`

The `{REPO_ROOT}/.specify/drafts/cdr.md` file will be created in the project directory.

#### Step 2: Setup Directories

Run `.specify/extensions/levelup/scripts/bash/setup-levelup.sh --json` to set up the infrastructure:

- Creates skills drafts directory at `{REPO_ROOT}/.specify/drafts/skills/`
- Returns JSON with `TEAM_DIRECTIVES`, `REPO_ROOT`

The `{REPO_ROOT}/.specify/drafts/cdr.md` file will be created in the project directory.

### Phase 4: Load Existing Directives

**Objective**: Load team-ai-directives to compare against and avoid duplicates

#### Step 1: Load Constitution

Read `{TEAM_DIRECTIVES}/context_modules/constitution.md` for team principles.

#### Step 2: Load Existing Rules

Scan `{TEAM_DIRECTIVES}/context_modules/rules/` directory:

```bash
find "$TEAM_DIRECTIVES/context_modules/rules" -name "*.md" -type f
```

Build a list of existing rule topics/patterns.

#### Step 3: Load Existing Personas

Scan `{TEAM_DIRECTIVES}/context_modules/personas/` directory.

#### Step 4: Load Existing Examples

Scan `{TEAM_DIRECTIVES}/context_modules/examples/` directory.

#### Step 5: Load Existing Skills

Scan `{TEAM_DIRECTIVES}/skills/` directory and read `.skills.json` if exists.

### Phase 5: Codebase Scan

**Objective**: Analyze the codebase for context patterns

#### Step 1: Technology Detection

Identify the project's technology stack:

| File/Pattern | Technology |
|--------------|------------|
| `package.json` | Node.js/JavaScript |
| `requirements.txt`, `pyproject.toml` | Python |
| `go.mod` | Go |
| `pom.xml`, `build.gradle` | Java |
| `Cargo.toml` | Rust |
| `Dockerfile`, `docker-compose.yml` | Containerization |
| `.github/workflows/` | GitHub Actions |
| `terraform/`, `*.tf` | Infrastructure as Code |

#### Step 2: Code Pattern Scan

For each detected technology, scan for patterns:

**Python Patterns**:
- Custom exception classes → Potential rule: error handling
- Pytest fixtures → Potential example: testing patterns
- Pydantic models → Potential rule: validation patterns
- Logging configuration → Potential rule: observability

**JavaScript/TypeScript Patterns**:
- Custom hooks → Potential example: React patterns
- Error boundaries → Potential rule: error handling
- Test utilities → Potential example: testing
- API clients → Potential example: integration patterns

**Infrastructure Patterns**:
- Deployment scripts → Potential skill
- CI/CD workflows → Potential rule: automation
- Docker configurations → Potential example: containerization

#### Step 3: Documentation Scan

Scan for documented patterns:

- `README.md` - Project conventions
- `CONTRIBUTING.md` - Contribution guidelines
- `docs/` - Architecture decisions, patterns
- Code comments with `TODO`, `FIXME`, `NOTE` - Potential improvements

### Phase 6: Pattern Detection

**Objective**: Categorize discovered patterns by context type

#### Context Type Classification

For each discovered pattern, classify:

| Pattern Characteristic | Likely Context Type |
|------------------------|---------------------|
| Coding convention, "always do X" | **Rule** |
| Role-specific expertise, "as a X" | **Persona** |
| Working code snippet, reusable | **Example** |
| Fundamental principle, governance | **Constitution** |
| Self-contained capability, workflow | **Skill** |

#### Skill Type Classification

For skill-type CDRs, classify using Anthropic's 9-category taxonomy:

| Type | Purpose | Example Triggers |
|------|---------|------------------|
| **Library & API Reference** | Documentation and API usage | "how do I use X", "API for Y" |
| **Product Verification** | Testing and validation | "verify product", "check behavior" |
| **Data Fetching & Analysis** | Data retrieval and processing | "fetch data", "analyze logs" |
| **Business Process Automation** | Workflow automation | "automate process", "workflow" |
| **Code Scaffolding & Templates** | Project generation | "create project", "scaffold" |
| **Code Quality & Review** | Review and quality checks | "review code", "quality check" |
| **CI/CD & Deployment** | Build and deployment | "deploy", "CI/CD pipeline" |
| **Runbooks** | Operational procedures | "troubleshoot", "runbook" |
| **Infrastructure Operations** | IaC and infrastructure | "provision", "infrastructure" |

**Classification Process**:

1. Analyze the skill's primary purpose
2. Match to the most appropriate taxonomy category
3. Present recommendation to user for confirmation
4. Include the selected type in the CDR

#### Heuristic Application

Apply the `--cdr-heuristic` setting:

**`surprising` (default)**:
- Only patterns NOT found in existing team-ai-directives
- Skip obvious/common patterns for the technology
- Focus on project-specific innovations

**`all`**:
- Document every pattern found
- Useful for comprehensive audit

**`minimal`**:
- Only high-value patterns
- Patterns with clear evidence of success
- Skip uncertain or minor patterns

### Phase 7: Deduplication

**Objective**: Filter out patterns already covered in team-ai-directives

For each discovered pattern:

1. Compare against loaded rules, personas, examples, skills
2. Use keyword matching and semantic similarity
3. If >80% overlap with existing directive, skip
4. If partial overlap, note for potential enhancement (not new CDR)

### Phase 8: CDR Generation

**Objective**: Create CDRs for discovered patterns

For each unique pattern, generate a CDR with:

```markdown
## CDR-{NNN}: {Pattern Title}

### Status
**Discovered**

### Date
{TODAY}

### Source
Brownfield codebase scan via /levelup.init

### Target Module
{context_modules/rules|personas|examples|skills}/{path}

### Context Type
{Rule|Persona|Example|Constitution Amendment|Skill}

### Skill Type
{Required if Context Type = Skill: Library & API Reference | Product Verification | Data Fetching & Analysis | Business Process Automation | Code Scaffolding & Templates | Code Quality & Review | CI/CD & Deployment | Runbooks | Infrastructure Operations}

### Context
{Description of the pattern and why it was discovered}

**Discovery Evidence:**
- {File path where pattern was found}
- {Code snippet or reference}

### Decision
{What context module to add to team-ai-directives}

**Proposed Content:**
```markdown
{Actual content to add}
```

### Evidence
- {Link to code file}
- {Link to test demonstrating pattern}

### Constitution Alignment
| Principle | Alignment | Notes |
|-----------|-----------|-------|
| {Principle} | Compliant | {How it aligns} |
```

Assign sequential CDR IDs starting from the highest existing ID + 1.

### Phase 9: Gap Analysis

**Objective**: Identify areas where patterns are unclear

Document gaps for `/levelup.clarify`:

- Patterns with conflicting implementations
- Patterns without clear evidence
- Potential patterns needing team input
- Areas where multiple approaches exist

### Phase 10: Output

**Objective**: Write CDRs to file and present summary

#### Step 1: Write CDRs

Add proposed CDRs to `{REPO_ROOT}/.specify/drafts/cdr.md`:

- Create `{REPO_ROOT}/.specify/memory/` directory if it doesn't exist
- Use the CDR template format (markdown with CDR index table)
- Add new CDRs with unique IDs (CDR-001, CDR-002, etc.)
- Do not overwrite existing accepted/active CDRs

#### Step 2: Create Summary

Present discovery summary:

```markdown
## LevelUp Init Summary

**Project**: {project-name}
**Scan Date**: {date}
**Team Directives**: {path}

### Discovered CDRs

| ID | Target Module | Context Type | Confidence |
|----|---------------|--------------|------------|
| CDR-001 | rules/python/error-handling | Rule | High |
| CDR-002 | examples/testing/fixtures | Example | Medium |

### Statistics

- **Total Patterns Scanned**: {N}
- **Patterns Already in Team Directives**: {N}
- **New CDRs Generated**: {N}
- **Gaps Identified**: {N}

### By Context Type

| Type | Count |
|------|-------|
| Rules | {N} |
| Personas | {N} |
| Examples | {N} |
| Constitution | {N} |
| Skills | {N} |

### Next Steps

1. Review proposed CDRs in `{REPO_ROOT}/.specify/drafts/cdr.md`
2. Run `/levelup.clarify` to resolve ambiguities
3. Mark CDRs as "Accepted" or "Rejected"
4. Run `/levelup.implement` to create PR
```

### Phase 11: Handoff Options

Present manual handoff options (no auto-trigger):

```markdown
### Available Handoffs

**Option 1: Resolve Ambiguities**
Run `/levelup.clarify` to:
- Validate discovered patterns
- Ask clarifying questions
- Refine CDR content

**Option 2: Refine from Feature Context**
Run `/levelup.specify` to:
- Add context from current feature spec
- Link CDRs to implementation evidence

**Option 3: Build Skills**
Run `/levelup.skills {topic}` to:
- Build a skill from accepted CDRs

**Option 4: Create PR**
Run `/levelup.implement` to:
- Compile accepted CDRs into PR
- Submit to team-ai-directives
```

## Output Files

| File | Description |
|------|-------------|
| `{REPO_ROOT}/.specify/drafts/cdr.md` | Context Directive Records (markdown) |

## Notes

- Modules start with status "proposed" - they need review before implementation
- Existing CDRs are preserved; new discoveries are appended
- The `--cdr-heuristic` flag significantly affects output volume
- Gaps are documented for follow-up with `/levelup.clarify`
- No automatic handoff - user decides next step

## Related Commands

- `/levelup.clarify` - Resolve ambiguities in discovered CDRs
- `/levelup.specify` - Refine CDRs from feature context
- `/levelup.skills` - Build skills from accepted CDRs
- `/levelup.implement` - Create PR to team-ai-directives
- `/architect.init` - Similar pattern for ADR discovery