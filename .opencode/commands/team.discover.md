---
description: Discover relevant context from team-ai-directives for current feature
---


<!-- Extension: team-ai-directives -->
<!-- Config: .specify/extensions/team-ai-directives/ -->
## Goal

Discover relevant personas, rules, examples, and skills from team-ai-directives that apply to the current feature being specified or planned.

## Discovery Process

### Step 1: Load Feature Context

Read the feature description from:
- Environment variable: `${SPECIFY_FEATURE_DESCRIPTION}` (if set)
- Context file: `{REPO_ROOT}/specs/${SPECIFY_FEATURE}/context.md`
- Spec file: `{REPO_ROOT}/specs/${SPECIFY_FEATURE}/spec.md` (Mission Brief section)

Extract the feature's:
- **Domain**: What business area is this? (e.g., payments, auth, analytics)
- **Technology**: What tech stack? (e.g., Java, Python, Kubernetes, React)
- **Patterns**: What architectural patterns? (e.g., REST, event-driven, CQRS)
- **Actions**: What is the feature doing? (e.g., create, validate, sync, process)

### Step 2: Scan team-ai-directives

Read all files from `${SPECIFY_TEAM_DIRECTIVES}/context_modules/`:

1. **constitution.md** - Always include this
2. **personas/** - List all persona files
3. **rules/** - List all rule files (organized by category)
4. **examples/** - List all example files

### Step 3: Select Relevant Context

For each file, determine relevance based on:

**Personas** - Match when:
- Persona's domain matches feature domain
- Persona's role aligns with feature users

**Rules** - Match when:
- Rule technology matches feature technology stack
- Rule category aligns with feature type (security, testing, style, etc.)
- Rule applies to the patterns being used

**Examples** - Match when:
- Example domain/technology overlaps with feature
- Similar feature type or pattern demonstrated

### Step 4: Output Discovered Context

Output structured discovery results in this exact format:

```json
{
  "constitution": "/path/to/constitution.md",
  "personas": [
    {"name": "Admin User", "file": "personas/admin.md", "relevance": "high"}
  ],
  "rules": [
    {"name": "API Security", "file": "rules/security/api-security.md", "relevance": "high", "category": "security"}
  ],
  "examples": [
    {"name": "Payment Flow", "file": "examples/payment-flow.md", "relevance": "medium"}
  ],
  "search_metadata": {
    "files_searched": 42,
    "files_with_matches": 8
  }
}
```

### Step 5: Populate Feature Context

The preset commands will use this output to populate the context template with discovered directives.

## Usage

This command is automatically executed via extension hooks:
- **before_specify**: Runs before `/spec.specify` to discover context for specification
- **before_plan**: Runs before `/spec.plan` to discover context for planning

## Failure Handling

If team-ai-directives is not configured or files cannot be read:
1. Output empty results with all arrays empty
2. Include search_metadata showing 0 files searched
3. Exit successfully (code 0) - don't block the preset command