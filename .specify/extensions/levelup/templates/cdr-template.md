# Context Directive Records

Context Directive Records (CDRs) track decisions about contributing context modules (rules, personas, examples, skills) to team-ai-directives. Similar to Architecture Decision Records (ADRs), CDRs provide a formal record of what, why, and how context is being contributed.

## CDR Index

| ID | Target Module | Context Type | Instruction Type | Priority | Status | Date | Source |
|----|---------------|--------------|------------------|----------|--------|------|--------|
| CDR-001 | [target path] | [type] | [Generation/Review/Refactor/Security/General] | [Critical/Standard/Preference] | Proposed | YYYY-MM-DD | [source] |

---

## CDR-001: [Decision Title]

### Status

**Discovered** | Proposed | Accepted | Rejected | Implemented

### Date

YYYY-MM-DD

### Source

[How this CDR was discovered: codebase scan, feature spec, manual identification]

### Target Module

`context_modules/rules/{domain}/{file}.md` | `context_modules/personas/{file}.md` | `context_modules/examples/{category}/{file}.md` | `skills/{skill-name}/`

### Context Type

Rule | Persona | Example | Constitution Amendment | Skill

### Skill Type

**Required if Context Type = Skill** (based on Anthropic's Skill Types Taxonomy from "Lessons from Building Claude Code: How We Use Skills")

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

### Instruction Type

**Required if Context Type = Skill** (based on "Encoding Team Standards" article)

| Instruction Type | Purpose | Example Trigger Phrases |
|------------------|---------|-------------------------|
| **Generation** | How team generates new code | "create a new service", "implement feature", "write a function" |
| **Review** | How team reviews code | "review this PR", "check quality", "audit code" |
| **Refactor** | How team improves existing code | "clean up", "simplify", "optimize", "refactor" |
| **Security** | How team checks for vulnerabilities | "check security", "audit", "vulnerability" |
| **General Capability** | Self-contained capability | Any other reusable skill |

### Priority Structure

**Optional - for executable standards** (follows "Encoding Team Standards" article)

| Priority | Meaning | Action |
|----------|---------|--------|
| **Critical** | Must follow | Block merge if violated |
| **Standard** | Should follow | Require in code review |
| **Preference** | Nice to have | Suggest but don't require |

When applying to skills, prioritize:

1. **Critical**: Non-negotiable patterns, security requirements, architectural constraints
2. **Standard**: Conventions most commonly corrected in review
3. **Preference**: Style variations, minor optimizations

### Categorized Standards

> **Note:** Required if Instruction Type = Generation/Review/Refactor/Security

Following the "Encoding Team Standards" article's approach:

```markdown
### Critical (Must Follow)
- {Non-negotiable pattern 1}
- {Security requirement}

### Standard (Should Follow)
- {Convention 1}
- {Convention 2}

### Preference (Nice to Have)
- {Style preference 1}
- {Optimization suggestion}
```

### Context

Describe the problem being solved or the pattern being captured. Why does this context module need to exist?

**Discovery Evidence:**

- [Code path, pattern, or feature that revealed this need]
- [Specific examples from the codebase]

**Problem Statement:**

[Clear description of what gap this fills in team-ai-directives]

**Forces:**

- [Force 1 - technical, business, or team factor]
- [Force 2 - competing concern or constraint]
- [Force 3 - quality attribute requirement]

### Decision

State what context module will be added or modified. Use active voice: "We will add..." or "The team-ai-directives will include..."

**Decision:**

[Clear statement of what will be contributed]

**Proposed Content:**

```markdown
[The actual content to add to team-ai-directives]
[This is what will be placed in the target module]
```

**Rationale:**

[Why this content was chosen, how it benefits other projects]

### Evidence

Links to code, commits, or discussions that support this CDR:

- [Link to code file demonstrating the pattern]
- [Link to commit where pattern was established]
- [Link to discussion or issue that motivated this]

### Constitution Alignment

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| [Principle from team constitution] | Compliant / Deviation / Enhancement | [Explanation] |

**Constitution References:**

- [Link to relevant constitutional principles in team-ai-directives]

### Consequences

#### Positive

- [Benefit 1 - how other projects will benefit]
- [Benefit 2 - consistency improvement]

#### Negative

- [Trade-off 1 - potential maintenance burden]
- [Trade-off 2 - learning curve]

#### Risks

- [Risk 1 with mitigation strategy]
- [Risk 2 with monitoring approach]

### Related CDRs

- [CDR-XXX: Related decision]
- [ADR-XXX: Related architecture decision (if applicable)]

### Implementation Notes

**Target Repository:** team-ai-directives

**Branch:** `levelup/{project-slug}`

**PR Status:** [Not created | Draft | Ready | Merged]

---

## CDR Status Reference

| Status | Description |
|--------|-------------|
| **Discovered** | Inferred from existing codebase during brownfield analysis |
| **Proposed** | Suggested for review, awaiting team validation |
| **Accepted** | Approved for implementation in team-ai-directives |
| **Rejected** | Not accepted (reason documented in CDR) |
| **Implemented** | PR created/merged to team-ai-directives |

## CDR Best Practices

1. **One contribution per CDR** - Keep CDRs focused on a single context module
2. **Include concrete examples** - Show actual code/content, not abstract descriptions
3. **Link to evidence** - Always reference the code/commits that motivated the CDR
4. **Consider reusability** - Ask "Would this help other projects?"
5. **Align with constitution** - Verify the contribution aligns with team principles
6. **Document trade-offs** - Be honest about maintenance burden and learning curve

## Context Type Guidelines

### Rules

- Coding patterns, error handling approaches, testing strategies
- Should be actionable and verifiable
- Include both the rule and examples of compliance

### Personas

- Role-specific guidance for AI agents
- Define expertise areas, communication style, decision-making approach
- Include example prompts and responses

### Examples

- Code snippets, prompt patterns, test cases
- Must be working, tested examples
- Include context for when to use

### Constitution Amendments

- Governance principles, quality standards
- Should be fundamental principles, not specific rules
- Require broader team consensus

### Skills

- Self-contained capabilities with trigger keywords
- Include SKILL.md with clear activation criteria
- Provide references and supporting content
- **Skill Type**: Classify using 9-category taxonomy (see Skill Type section above)

---

*Template Version: 1.0*
*Compatible with team-ai-directives structure*
