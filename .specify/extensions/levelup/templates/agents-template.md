# Agent Instructions

This repository contains team AI directives for context-aware development.

## Structure

- `context_modules/constitution.md` - Core principles (always load first)
- `context_modules/personas/` - Role-specific guidance
- `context_modules/rules/` - Domain-specific patterns organized by functional category:
  - `style-guides/` - Language patterns, conventions, idioms
  - `framework/` - Architecture, DI, DDD, design patterns
  - `security/` - Authentication, authorization, secrets
  - `testing/` - Test frameworks, fixtures, practices
  - `devops/` - CI/CD, deployment, infrastructure
  - `data/` - Data patterns, provenance, ETL
- `context_modules/examples/` - Code examples by technology
- `skills/` - Self-contained capabilities with SKILL.md
- `.skills.json` - Skills registry and policy
- `CDR.md` - Context Directive Records (approved contributions tracker)

## Loading Order

1. **Constitution** (`context_modules/constitution.md`) - Foundational principles
2. **Persona** (`context_modules/personas/*.md`) - Role-specific context
3. **Skill** (`skills/*/SKILL.md`) - Task-specific capabilities (triggered on demand)

## Functional Categories (Rules)

Rules are organized by **functional concern**, not technology:

| Category | Purpose | Example |
|----------|---------|---------|
| `style-guides/` | Language idioms and conventions | `python_pydantic_patterns.md` |
| `framework/` | Architecture and design patterns | `python_di_container.md` |
| `security/` | Security and authentication | `typescript_auth_middleware.md` |
| `testing/` | Testing practices | `python_test_architecture.md` |
| `devops/` | CI/CD and operations | `github_actions.md` |
| `data/` | Data patterns and provenance | `python_provenance_tracking.md` |

**Filename format**: `{technology}_{pattern_name}.md` (use underscores)

## Using Skills

Skills in `skills/{skill-name}/`:

1. Check `.skills.json` for available skills
2. Match user request to skill description
3. Load `SKILL.md` when triggered
4. Check `references/` for supporting content
5. Use `scripts/` for automation if present

## Using Rules

Access rules via:

1. **Persona Rule References** - Personas link to relevant rules
2. **Direct exploration** - Browse `context_modules/rules/{category}/`
3. **CDR.md** - Check for recently approved contributions

## CDR.md

Context Directive Records track approved contributions from various projects. Review to:

- Find patterns added by other teams
- Understand evolution of standards
- Check for recent additions in your domain

## External Skills

`.skills.json` registry section lists external skills. Fetch via URL when referenced.
