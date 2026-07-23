---
# MADR 3.0.0 frontmatter (https://adr.github.io/madr/)
# status, date, decision-makers, consulted, informed are MADR-standard.
# sub-system and superseded-by are project extensions.
status: proposed  # proposed | accepted | rejected | deprecated | superseded by ADR-0123 | discovered
date: YYYY-MM-DD
decision-makers: [list everyone involved in the decision]
consulted: [list everyone whose opinions were sought (typically subject-matter experts)]
informed: [list everyone kept up-to-date on progress]
sub-system: System  # System | Auth | Payments | Users | Inventory | (other sub-system) — cross-cutting decisions use "System"
superseded-by: ""  # set to "ADR-0123" only when status is "superseded by ADR-0123"
---

<!-- markdownlint-disable-next-line MD025 -->
# {short title, representative of the solved problem and the found solution}

## Context and Problem Statement

{Describe the context and problem statement, e.g., in free form using two or
three sentences in the form of an illustrative story. You may want to articulate
the problem in the form of a question and add links to collaboration boards or
issue management systems.}

## Decision Drivers

* {decision driver 1, e.g., a force, a facing concern, …}
* {decision driver 2, e.g., a force, a competing concern, …}
* {decision driver 3, e.g., a quality attribute requirement}

## Considered Options

* {title option 1}
* {title option 2}
* {title option 3}

## Decision Outcome

Chosen option: "{title option 1}", because {justification, e.g., only option
which meets a k.o. criterion decision driver | resolves force {force} | … | comes
out best (see below)}.

### Consequences

* Good, because {positive consequence, e.g., improvement of one or more desired qualities}
* Good, because {positive consequence}
* Bad, because {negative consequence, e.g., …}
* Neutral, because {argument that weighs neither good nor bad}
* Bad, because {risk — include mitigation or monitoring approach}

### Confirmation

{Describe how the implementation of / compliance with this ADR can or will be
confirmed. Is the chosen design and implementation in line with the decision?
E.g., a design/code review or a test library like ArchUnit can help validate
this.}

## Pros and Cons of the Options

### {title option 1}

{example | description | pointer to more information | …}

* Good, because {argument a}
* Good, because {argument b}
* Neutral, because {argument c}
* Bad, because {argument d}

### {title option 2}

{example | description | pointer to more information | …}

* Good, because {argument a}
* Bad, because {argument b}

### {title option 3}

{example | description | pointer to more information | …}

* Good, because {argument a}
* Bad, because {argument b}

## Constitution Alignment

| Principle | Alignment | Notes |
|-----------|-----------|-------|
| {Principle Name} | Compliant / Deviation / Override | {Explanation} |

**Override Justification** (if applicable):
{Why this ADR deviates from constitution guidance}

## Related ADRs

* [ADR-XXX: {Related decision}](ADR-XXX.md)

## More Information

{Additional evidence/confidence in the decision outcome, team agreement on the
decision, and/or when/how the decision should be re-visited. Links to other
decisions and resources may appear here.}

---

## MADR Alignment & Project Extensions

This template follows [MADR 3.0.0](https://adr.github.io/madr/) with the
following deliberate extensions and deviations:

**Adopted from MADR**: YAML frontmatter (status, date, decision-makers,
consulted, informed) per MADR-0013; `# {title}` H1 heading (no numbers in
headings, MADR-0002); Context and Problem Statement; Decision Drivers;
Considered Options; Decision Outcome + Consequences (Good/Bad/Neutral,
MADR v3.0.0 merged) + Confirmation; Pros and Cons of the Options (with
neutral arguments, MADR-0014); More Information; links between ADRs
(MADR-0009); asterisk list markers (MADR-0011); `rejected` status (MADR-0008).

**Project extensions** (beyond MADR): `sub-system` frontmatter field (MADR-0010
categories equivalent); `discovered` status (brownfield reverse-engineering via
`/architect-init`); Constitution Alignment section; Related ADRs section.

**Filename convention**: `ADR-{NNN}.md` (zero-padded numeric ID) rather than
MADR's default `NNNN-title-with-dashes.md` (MADR-0005 explicitly permits other
patterns). The stable numeric ID is used by the `adr.md` index, supersession
references, and the architect skills.

**Status values**: `proposed | accepted | rejected | deprecated | superseded by
ADR-0123 | discovered` — MADR's set plus `discovered`.
