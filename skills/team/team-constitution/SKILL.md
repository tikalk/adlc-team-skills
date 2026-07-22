---
name: team-constitution
description: Interactively create or amend the team constitution in team-ai-directives. Use when bootstrapping a new team KB, establishing team-wide principles for the first time, or amending existing ones.
disable-model-invocation: true
---

# team-constitution

## What this skill does

Interactively **create or amend** the team constitution at `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md`.

The scaffold written by `team-setup` (Mode 3) contains only a placeholder ("No team-wide principles defined yet"). This skill turns that placeholder into a real constitution through guided elicitation:

- Propose principles informed by team context (existing rules, CDRs, AGENTS.md)
- Review each principle interactively — confirm, edit, or reject
- Write the constitution in the established team format (OKF frontmatter + numbered principles + Governance section)

**What this skill is NOT**:

- Not a port of spec-kit's `spec.constitution` template machinery — no placeholder tokens, no hooks, no `extensions.yml`, no template propagation, no Sync Impact Report
- Not semantic versioning — the team constitution is versioned by **git history** in the KB repo; freshness is tracked by OKF frontmatter (`modified`, `verified`) via `/team-repair`
- Not for **project-level** constitutions (`.adlc/memory/constitution.md`) — those remain `spec.constitution` territory when spec-kit is in play

## When to use

- **After `team-setup` Mode 3**: the scaffold wrote a placeholder constitution — fill it with real principles
- **New team KB (cloned or existing)**: constitution is missing or still a placeholder
- **Amending principles**: the team wants to add, reword, or remove principles

### When NOT to use

- **Project-level constitution**: use spec-kit's `spec.constitution` for `.adlc/memory/constitution.md`
- **Constitution changes via CDR flow**: if a constitution change was proposed as a CDR, let `/levelup-publish` handle it
- **KB not configured**: run `/team-setup` first

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Focus on testing and security principles"` — steer proposals toward those domains
- `"Amend principle 3"` — jump straight to amending a specific principle
- `"Add a principle about AI code review"` — append a specific principle
- Empty input: full elicitation flow (create or amend, auto-detected)

### Role & Context

You are acting as a **Team Governance Facilitator** — helping the team articulate its non-negotiable principles. Your role involves:

- Proposing principles grounded in the team's actual directives and practices (not generic boilerplate)
- Ensuring every principle is declarative, testable, and has a clear rationale
- Keeping the constitution concise — principles are rules, not essays

### Outline

1. **Environment Setup** (Phase 0): Resolve paths, detect constitution state
2. **Load Team Context** (Phase 1): Read existing constitution + team directives to inform proposals
3. **Elicit Principles** (Phase 2): Interactive create/amend loop
4. **Governance Section** (Phase 3): Compose the lightweight governance paragraph
5. **Write Constitution** (Phase 4): Write the file with OKF frontmatter
6. **Commit & Summary** (Phase 5): Offer commit, report results

### Execution Steps

#### Phase 0: Environment Setup

Run the setup script from the skill's base directory:

```bash
scripts/bash/setup-team-constitution.sh
```

Parse JSON for `REPO_ROOT`, `TEAM_AI_DIRECTIVE`, `CONSTITUTION_FILE`, `CONSTITUTION_STATE`, `TD_IS_GIT`, `TD_CLEAN`.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`, or `pwd`.
2. `TEAM_AI_DIRECTIVE` — `TEAM_AI_DIRECTIVE` env var, then `.adlc/init-options.json` → `team_ai_directive`, then `REPO_ROOT/team-ai-directives`.
3. `CONSTITUTION_FILE` — `{TEAM_AI_DIRECTIVE}/context_modules/constitution.md`
4. `CONSTITUTION_STATE`:
   - `missing` — file does not exist
   - `placeholder` — file exists and contains "No team-wide principles defined yet"
   - `populated` — file exists with real content
5. `TD_IS_GIT` — `git -C "$TEAM_AI_DIRECTIVE" rev-parse --is-inside-work-tree` (exit 0 = true)
6. `TD_CLEAN` — `git -C "$TEAM_AI_DIRECTIVE" status --porcelain` (empty = clean)

If `TEAM_AI_DIRECTIVE` is not configured:

```text
Team AI directives repository not configured.
Run: team-setup
Or set: export TEAM_AI_DIRECTIVE=/path/to/team-ai-directives
```

#### Phase 1: Load Team Context

Read the following to inform principle proposals:

1. **Existing constitution** at `{CONSTITUTION_FILE}` (if `populated` — you will amend; if `placeholder`/`missing` — you will create)
2. **Team rules index**: `{TEAM_AI_DIRECTIVE}/CDR.md` — accepted rule/persona/example descriptors reveal what the team already cares about
3. **Existing rules**: skim `{TEAM_AI_DIRECTIVE}/context_modules/rules/` file names and headings
4. **AGENTS.md** at `{TEAM_AI_DIRECTIVE}/AGENTS.md` — loading order and skill usage expectations

Principles must be **grounded in what you find** — e.g., if the rules directory is heavy on security modules, a "Security by Default" principle is evidence-based, not boilerplate. If the KB is nearly empty, fall back to a small starter set and say so explicitly.

#### Phase 2: Elicit Principles

##### Create mode (`missing` or `placeholder`)

1. **Propose a starter set** (3–7 principles) based on Phase 1 findings. For each principle, present:

```markdown
### Proposed Principle N: {Name}

**Statement**: {Declarative, testable rule — one or two sentences}

**Rationale**: {Why this principle exists; what failure it prevents}

**Grounding**: {What team context motivated this — or "starter suggestion, no KB evidence yet"}

Reply: [Y] accept / [e] edit / [n] reject
```

2. For each response:
   - **Y**: add to the accepted list
   - **e**: apply the user's edits, present the revised principle for confirmation
   - **n**: drop it

3. After the starter set, ask: **"Any additional principles?"** Loop until the user is done.

##### Amend mode (`populated`)

1. List the current principles (numbered, one-line each).
2. Ask what to do: **amend N** / **add new** / **remove N** / **full review**.
3. For amendments and additions, use the same propose → confirm/edit/reject loop as create mode.
4. For removals, confirm explicitly — removals are the highest-impact change.

**Principle quality bar** (apply to every accepted principle):

- **Declarative and testable**: an agent can check compliance ("Every X must Y"), not aspirational ("We value X")
- **Non-negotiable framing**: principles are MUSTs; preferences and conventions belong in rules, not the constitution
- **Rationale included**: one sentence on what failure the principle prevents
- **No vague language**: replace "should" with MUST/NEVER, or move the item to rules

#### Phase 3: Governance Section

Compose a short Governance section. Keep it to these three points (do not expand):

```markdown
## Governance

- **Amendments**: proposed as CDRs via `/levelup-init` or `/levelup-specify`, reviewed via `/levelup-clarify`, published via `/levelup-publish`. Direct edits via `/team-constitution` are reserved for bootstrapping and explicit team decisions.
- **Compliance**: this constitution is loaded by `team-boot` at the start of every session. Agents and humans MUST follow it; on conflict, the constitution supersedes ad-hoc practices.
- **Alignment**: `/team-repair` (Check 6) verifies project constitutions inherit these principles. Project constitutions may extend, never contradict.
```

#### Phase 4: Write Constitution

Write `{CONSTITUTION_FILE}` with this exact structure:

```markdown
---
type: Constitution
title: "{TEAM_NAME} Constitution"
description: "Team-wide principles and governance"
resource: ./context_modules/constitution.md
tags: [constitution]
timestamp: {TODAY}T00:00:00Z
---

# {TEAM_NAME} Constitution

1. **{Principle Name}**
   {Statement. Rationale.}

2. **{Principle Name}**
   {Statement. Rationale.}

...

## Governance

{Governance section from Phase 3}
```

Rules for writing:

- Preserve the existing OKF frontmatter fields when amending; update `timestamp` to today. If the file carries custom fields (`created`, `modified`, `verified`, `age_days`, `id`, `cdr_ref`, `evidence`), preserve them and set `modified` to today.
- `title` and H1: keep the existing team name if present; otherwise derive from the KB directory name or ask.
- Numbered flat list (`1. **Name**`) — no `###` subsections per principle, no version/ratified date lines.
- If `CONSTITUTION_STATE` was `missing`, create the parent directory first: `mkdir -p "{TEAM_AI_DIRECTIVE}/context_modules"`.

#### Phase 5: Commit & Summary

If `TD_IS_GIT` is true and `TD_CLEAN` is true, offer a single commit on the current branch (no branch/PR flow — that remains the CDR lifecycle's job):

```text
Commit the constitution update to team-ai-directives?
  git -C "{TEAM_AI_DIRECTIVE}" add context_modules/constitution.md
  git -C "{TEAM_AI_DIRECTIVE}" commit -m "docs: {create|amend} team constitution — {N} principles"
[Y/n]
```

If `TD_CLEAN` is false, skip the commit offer and note the KB has uncommitted changes.

Report:

```markdown
## Team Constitution Summary

**Mode**: {Create | Amend}
**File**: {CONSTITUTION_FILE}
**Principles**: N ({added} added, {amended} amended, {removed} removed)
**Committed**: {yes | no — reason}

### Principles

1. {Name} — {one-line statement}
2. ...

### Next Steps

1. Run `/team-repair` to validate the KB and refresh verification timestamps
2. Review project constitutions for alignment (team-repair Check 6)
```

### Key Rules

#### Grounded, Not Boilerplate

- Proposals must cite team context when available (CDR descriptors, rule headings, AGENTS.md)
- When the KB is empty, say the starter set is generic and keep it small (3–5)

#### Team Format Only

- OKF frontmatter + numbered principles + Governance — no spec-kit template structure
- No `**Version**` / `**Ratified**` lines — git history is the versioning
- No `###` subsections per principle — flat numbered list

#### Interactive, Not Automatic

- Every principle is confirmed by the user before writing
- Never silently rewrite an existing `populated` constitution — amend mode requires explicit per-principle decisions

#### Don't Cross the Streams

- Project constitutions (`.adlc/memory/constitution.md`) are out of scope
- CDR-driven constitution changes go through `/levelup-publish`, not this skill

### Workflow Guidance & Transitions

#### After `/team-constitution`

```text
/team-setup (Mode 3 scaffold — placeholder constitution)
    ↓
/team-constitution (this skill — real principles)
    ↓
/team-repair (validate KB, refresh freshness)
```

Ongoing amendments follow the CDR lifecycle (`/levelup-init` or `/levelup-specify` → `/levelup-clarify` → `/levelup-publish`), with `/team-constitution` available for explicit interactive edits.

## Verification

- `{CONSTITUTION_FILE}` exists with OKF frontmatter (`type: Constitution` present)
- `placeholder` marker text is gone
- Every principle has a bolded name, a declarative statement, and a rationale
- Governance section present with the three points (amendments, compliance, alignment)
- No placeholder tokens (`[ALL_CAPS]`), no version/ratified date lines
- Amended files preserve pre-existing custom frontmatter fields with `modified` updated
- Summary reported with mode, principle counts, and commit status

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team-ai-directives knowledge base (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `team-ai-directives/` relative to project root.

## 12-Factor Alignment

Factor XI (Directives as Code) — the team's foundational governance document is created and maintained as a version-controlled artifact, never embedded ad-hoc in prompts.

## Context

$ARGUMENTS
