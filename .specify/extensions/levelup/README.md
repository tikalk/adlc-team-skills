# LevelUp Extension

Discover and contribute context modules (rules, personas, examples, skills) to team-ai-directives using Context Directive Records (CDRs).

## Overview

The LevelUp extension helps brownfield projects analyze their codebase and contribute reusable context modules back to the team's shared AI directives repository. It introduces **Context Directive Records (CDRs)** - similar to Architecture Decision Records (ADRs) - for tracking what, why, and how context is being contributed.

## Commands

| Command | Purpose |
|---------|---------|
| `/levelup.init` | Scan codebase and discover CDRs (like `/architect.init`) |
| `/levelup.clarify` | Resolve ambiguities in discovered CDRs (like `/architect.clarify`) |
| `/levelup.specify` | Refine CDRs using current feature spec context |
| `/levelup.skills` | Build a single skill from accepted CDRs |
| `/levelup.implement` | Compile accepted CDRs into a PR to team-ai-directives |
| `/levelup.trace` | Generate and validate AI session execution traces |
| `/levelup.validate` | Scan team-ai-directives for rule conflicts |

## Quick Start

### 1. Generate Session Trace (Optional but Recommended)

After implementing a feature, generate a trace to document the session:

```bash
/levelup.trace
```

This creates `specs/{BRANCH}/trace.md` with execution summary.

### 2. Initialize CDR Discovery

Scan your codebase for patterns that could become team-wide directives:

```bash
/levelup.init
```

This creates proposed CDRs in `{PROJECT}/.specify/drafts/cdr.md` with status "Discovered" or "Proposed".

### 2. Clarify and Accept CDRs

Review discovered CDRs and resolve ambiguities:

```bash
/levelup.clarify
```

This validates patterns and updates CDR statuses to "Accepted" or "Rejected".

### 3. Build Skills (Optional)

Build a skill from accepted CDRs:

```bash
/levelup.skills python-error-handling
```

This creates a skill in `.specify/drafts/skills/`.

### 4. Create PR

Compile accepted CDRs into a PR to team-ai-directives:

```bash
/levelup.implement
```

This creates a draft PR with all accepted contributions.

## Context Directive Records (CDRs)

CDRs are stored in markdown format:

- **Local**: `{PROJECT}/.specify/drafts/cdr.md` - Working copy during discovery/clarification
- **Approved**: `{TEAM_DIRECTIVES}/CDR.md` - Approved contributions tracked in team-ai-directives

CDRs define:

- **Target Module**: Where the contribution goes in team-ai-directives
- **Context Type**: Rule, Persona, Example, or Skill
- **Status**: Discovered → Proposed → Accepted | Rejected

### CDR Status Values

| Status | Description |
|--------|-------------|
| **Discovered** | Inferred from codebase during brownfield analysis |
| **Proposed** | Suggested for review, awaiting validation |
| **Accepted** | Approved for implementation |
| **Rejected** | Not approved (reason documented in CDR) |

## Skill Types Taxonomy

When discovering skills, classify them using Anthropic's 9-category taxonomy from "Lessons from Building Claude Code: How We Use Skills". This helps teams build better skills by guiding CDR classification during discovery.

| Type | Purpose | Example Triggers |
|------|---------|------------------|
| **Library & API Reference** | Documentation and API usage guidance | "how do I use X library", "API for Y service" |
| **Product Verification** | Testing and validation of product behavior | "verify product", "check behavior", "validate output" |
| **Data Fetching & Analysis** | Data retrieval and processing | "fetch data", "analyze logs", "query database" |
| **Business Process Automation** | Workflow and business process automation | "automate process", "workflow", "orchestrate" |
| **Code Scaffolding & Templates** | Project and code generation | "create project", "scaffold", "generate boilerplate" |
| **Code Quality & Review** | Code review and quality improvement | "review code", "quality check", "refactor" |
| **CI/CD & Deployment** | Build, test, and deployment pipelines | "deploy", "CI/CD pipeline", "build artifact" |
| **Runbooks** | Operational procedures and troubleshooting | "troubleshoot", "runbook", "incident response" |
| **Infrastructure Operations** | Infrastructure as Code and provisioning | "provision", "infrastructure", "terraform", "kubernetes" |

### When to Use Each Type

- **Library & API Reference**: When the skill provides documentation or guidance for using a specific library or API
- **Product Verification**: When the skill checks or validates product behavior against expected outputs
- **Data Fetching & Analysis**: When the skill retrieves, processes, or analyzes data from external sources
- **Business Process Automation**: When the skill orchestrates multi-step workflows or business processes
- **Code Scaffolding & Templates**: When the skill generates project structure or code templates
- **Code Quality & Review**: When the skill reviews code quality or suggests improvements
- **CI/CD & Deployment**: When the skill handles building, testing, or deploying applications
- **Runbooks**: When the skill provides troubleshooting or operational guidance
- **Infrastructure Operations**: When the skill manages infrastructure provisioning or configuration

## Configuration

### Team AI Directives Path

The extension resolves the team-ai-directives path in this order:

1. `SPECIFY_TEAM_DIRECTIVES` environment variable
2. `.specify/team-ai-directives` (submodule - recommended)
3. `.specify/memory/team-ai-directives` (clone - legacy)

### Extension Config

Optional configuration in `.specify/extensions/levelup/levelup-config.yml`:

```yaml
cdr:
  heuristic: "surprising"  # surprising | all | minimal
  # CDR file location (local project)
  location: ".specify/drafts/cdr.md"

skills:
  drafts_location: ".specify/drafts/skills"

discovery:
  rules: true
  personas: true
  examples: true
  constitution: true
  skills: true

pull_request:
  draft: true
  branch_prefix: "levelup/"
  target_branch: "main"
```

## Command Flow

```
levelup.init          levelup.clarify        levelup.skills        levelup.implement
(Discover CDRs)  ───▶  (Resolve Ambiguities) ───▶ (Build Skills)  ───▶ (Create PR)
      │                      │                      │                      │
      │    [handoff]         │    [handoff]         │                      │
      └──▶ levelup.specify ◀────┘                      │                      │
            (Refine from                             │                      │
             feature context)                        │                      │
                                                      │                      │
                     ┌───────────────────────────────┘                      │
                     │                                                      │
                     ▼                                                      │
              levelup.trace ◀───────────────────────────────────────────────┘
              (Generate Trace)
                     │
                     │ [handoff]
                     ▼
              levelup.specify
              (Extract CDRs with
               trace enrichment)

      ┌──────────────────────────────────────────────────────┐
      │                                                      │
      ▼                                                      │
levelup.validate ◀────────────────────────────────────────────┘
(Scan for Conflicts)
      │
      │ [creates CDRs]
      ▼
levelup.clarify
(Resolve conflicts)
```

## Related Issues

- [#56](https://github.com/tikalk/agentic-sdlc-spec-kit/issues/56) - Feature request for this extension
- [#49](https://github.com/tikalk/agentic-sdlc-spec-kit/issues/49) - Skills discovery (format compatibility)
- [#53](https://github.com/tikalk/agentic-sdlc-spec-kit/issues/53) - Git submodule for team-ai-directives
- [#36](https://github.com/tikalk/agentic-sdlc-spec-kit/issues/36) - Convert architect commands to extension (pattern reference)

## License

MIT
