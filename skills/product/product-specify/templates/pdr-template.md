---
# PDR frontmatter (project extension of MADR 3.0.0 conventions)
# status, date, owner, category, feature-area, title are PDR-standard fields.
# Keep frontmatter as the SINGLE SOURCE OF TRUTH for index generation.
# Heading-based metadata (## or ###) is a legacy fallback only.
status: proposed  # proposed | accepted | completed | rejected | deprecated | superseded by PDR-0123 | discovered
date: YYYY-MM-DD
owner: [list everyone involved in the decision]
category: Feature  # Feature | NFR | GTM | Milestone | Governance | Metric | Prioritization
feature-area: System  # system | control-plane | execution-harness | spec-harness | knowledge-plane | observability-plane | factory-dashboard | learning-loop | great-filter | evals-taste | (other feature area)
title: short title, representative of the solved problem and the found solution
---

<!-- markdownlint-disable-next-line MD025 -->
# PDR-NNN: {short title, representative of the solved problem and the found solution}

## Context

**Problem/Opportunity:**
{Describe the problem or opportunity in free form using two or three sentences
in the form of an illustrative story. Articulate the problem as a question if
helpful, and add links to collaboration boards or issue management systems.}

**Market Forces:**
* {market force 1, e.g., a buyer demand, a competitive pressure, …}
* {market force 2, e.g., a regulatory constraint, a technology shift, …}

## Decision

**Decision Statement:**
{State the decision concisely, in a single sentence that a reader can evaluate
against the context and consequences.}

**Rationale:**
* {rationale point 1}
* {rationale point 2}

## Consequences

**Positive:**
* {positive consequence 1}
* {positive consequence 2}

**Negative:**
* {negative consequence 1}
* {negative consequence 2}

**Neutral / Acceptance:**
* {neutral consequence 1}

## Alternatives Considered

* **{alternative 1}**: {why not chosen}
* **{alternative 2}**: {why not chosen}

## Links

* {links to related PDRs, ADRs, issues, or external references — use relative paths for in-repo links}
