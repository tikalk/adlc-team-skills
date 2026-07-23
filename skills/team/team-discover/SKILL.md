---
name: team-discover
description: Discover relevant personas, rules, examples, and skills from the team AI directives, plus project-level Product Decision Records (PDRs) and Architecture Decision Records (ADRs), for the current prompt. Auto-invoked by team-boot on every user prompt, or manually, to load team directives and project decisions matched to the current task before proceeding.
---

# team-discover

## Overview

Discover relevant personas, rules, examples, and skills from team-ai-directives that apply to the current feature being specified or planned. Also surfaces relevant **project-level decision records** — PDRs (`.adlc/**/pdr/pdr.md` index) and ADRs (`.adlc/**/adr/adr.md` index) — so the agent works with full knowledge of the product and architecture decisions already made.

### CDR Index as Search Surface

`CDR.md` in the team AI directives serves as the authoritative, LLM-readable catalog of all available context modules — analogous to how `.skills.json` is the index for skills. Each Accepted CDR row in the index table provides:

- **Target Module path**: the file to load if relevant
- **Type**: rule, persona, example
- **Descriptor**: a short "when to use" summary

The discovery process reads the index first, matches against it (using descriptor + path + type keywords), and loads full file content only for the modules selected as relevant. This progressive-disclosure approach keeps context lean and avoids scanning every file on every invocation.

If `CDR.md` is missing or cannot be parsed, the command falls back to scanning `context_modules/` directly.

### Lifecycle Contract

`team-context.md` follows a regenerate-per-prompt lifecycle:

- **Generated on every prompt** — `team-boot` invokes this skill for each user
  message (specify, plan, implement, question, debugging, or chat) and the
  skill re-matches context to the current prompt.
- **Persisted each run** to a single canonical location:
  `.adlc/drafts/team-context.md`. No per-feature directory variant.
- **Cleanup between prompts** is driven by a metadata header on the file (see
  Step 6): same feature → delta-aware overwrite (so the agent sees only what
  moved since the last prompt); different feature → reset.

## When to Use

`team-discover` runs on **every user prompt** — it is auto-invoked by
`team-boot` Step 4 for each message (specify, plan, implement, question,
debugging, or chat). It is also available for manual invocation.

There is no spec/plan gate and no continuation exemption: the follow-up "fix the
help message" is a different task surface than "add help modal" and re-runs
discovery so newly-relevant rules (accessibility, testing) surface. See the
lifecycle contract above.

Manual invocation:
```
/team-discover               # Persist mode (writes .adlc/drafts/team-context.md)
/team-discover --no-write    # Inline only, no file persistence
```

## Core Process

### Step 1: Locate Team AI Directives

Read the file `.adlc/init-options.json` directly. Do NOT use glob, find,
or any file-search tool to locate it — search tools may silently skip
dotfile-prefixed path segments. Read the file at the exact relative path
`.adlc/init-options.json` from the current working directory.

If that read fails (file not found), walk up parent directories by reading
`../.adlc/init-options.json`, then `../../.adlc/init-options.json`,
and so on — up to 4 levels. Stop at the first successful read.

From the JSON, extract the `team_ai_directive` field.

- If present and the path exists: use it as the team AI directives root.
- If not found or path doesn't exist: output empty results and exit.

In subsequent steps, `{TEAM_AI_DIRECTIVE}` refers to this value, resolved
as a path relative to the current working directory. Read files at this
path directly — do NOT use glob, find, or any file-search tool to locate
them.

### Step 2: Load Feature Context

`{REPO_ROOT}` is the project root (where `.adlc/` lives).

The feature description comes from the user's current message — or the feature
description provided by the invoking skill (e.g. a specify/plan workflow skill
or `team-boot` when it invokes this skill on every prompt). The user's message
is a valid feature description; use it directly.

Extract the feature's:
- **Domain**: What business area is this? (e.g., payments, auth, analytics)
- **Technology**: What tech stack? (e.g., Java, Python, Kubernetes, React)
- **Patterns**: What architectural patterns? (e.g., REST, event-driven, CQRS)
- **Actions**: What is the feature doing? (e.g., create, validate, sync, process)

### Step 3: Load CDR Index (Primary Path)

Read `{TEAM_AI_DIRECTIVE}/CDR.md` and parse the CDR Index table into candidate records.

Extract each table row where `Status` is `Accepted`:
```json
{
  "id": "CDR-2026-001",
  "target_module": "context_modules/rules/security/sql_injection_prevention.md",
  "type": "Rule",
  "descriptor": "SQL injection prevention patterns for all languages"
}
```

Also read `{TEAM_AI_DIRECTIVE}/.skills.json` for the skill registry.

**Fallback**: If `CDR.md` is missing, unparseable, or contains no Accepted rows, read all files from `{TEAM_AI_DIRECTIVE}/context_modules/` directly (constitution.md, personas/, rules/, examples/) and use each file's name and path as the matching surface. This ensures the command works with any valid team AI directives regardless of CDR maturity.

### Step 3b: Load Project Decision Indexes

Read the project's PDR and ADR **indexes** from `{REPO_ROOT}` (the project root where `.adlc/` lives) as additional matching surfaces. These are project-level decisions, independent of the team AI directives — load them even when the team AI directives is unconfigured or yields no matches.

**PDR index**:

1. Read `{REPO_ROOT}/.adlc/memory/pdr/pdr.md` (accepted PDRs).
2. If missing, fall back to `{REPO_ROOT}/.adlc/drafts/pdr/pdr.md` (all PDRs including Discovered/Proposed).
3. Parse each table row into a candidate:

```json
{
  "id": "PDR-001",
  "feature_area": "business",
  "category": "Business Model",
  "status": "Accepted",
  "file": ".adlc/memory/pdr/PDR-001.md"
}
```

**ADR index**:

1. Read `{REPO_ROOT}/.adlc/memory/adr/adr.md` (accepted ADRs).
2. If missing, fall back to `{REPO_ROOT}/.adlc/drafts/adr/adr.md`.
3. Parse each table row into a candidate:

```json
{
  "id": "ADR-003",
  "sub_system": "auth",
  "decision": "Use JWT for session tokens",
  "status": "Accepted",
  "file": ".adlc/memory/adr/ADR-003.md"
}
```

Skip silently for any index that does not exist — projects without the PDR/ADR lifecycle simply contribute no candidates here.

### Step 4: Match Against Index

For each candidate in the parsed CDR index, determine relevance based on:

**Personas** — Match when:
- Persona's domain (from descriptor or path) matches feature domain
- Persona's role aligns with feature users

**Rules** — Match when:
- Rule descriptor mentions matching technology
- Rule path category aligns with feature type (security, testing, style, etc.)
- Rule descriptor or path matches the patterns being used

**Examples** — Match when:
- Example descriptor/domain/technology overlaps with feature
- Similar feature type or pattern demonstrated

**PDRs** (from Step 3b) — Match when:
- PDR `feature_area` matches the feature domain
- PDR `category` aligns with the work (e.g., `NFR` for performance/reliability work, `Persona` for user-facing features, `Metric` for analytics, `Business Model` for pricing/billing)
- PDR id/title keywords overlap with the feature description

**ADRs** (from Step 3b) — Match when:
- ADR `sub_system` matches the feature's technical area
- ADR `decision` text mentions matching technology or patterns
- The feature would modify code governed by the ADR (when evident from the sub-system mapping)

The **descriptor** column is the primary matching surface — it carries the condensed "when to use" summary authored during CDR publication. The **target module path** and **type** provide secondary matching signals. For PDRs, `feature_area` + `category` are the primary surface; for ADRs, `sub_system` + `decision`.

**Skills**: Match from `.skills.json` against the feature context:
- **Default skills** (the `default` list): Check each skill's description
  against the feature's domain, technology, and patterns.
- **External skills** (the `external` map): Check each entry's `description`
  and `categories` fields against the feature's technology stack. Surface
  any external skill whose categories overlap with the feature's technology
  or patterns. For example, a React frontend feature should surface skills
  with `frontend`, `react`, or `ui` categories.

Include matched skills in the discovery output table with Type "Skill".

### Step 4b: Load Selected Module Bodies

For every module selected as relevant in Step 4, read the full file content from:
`{TEAM_AI_DIRECTIVE}/{target_module}`

For every **PDR/ADR** selected as relevant, read the full record content from its project-relative path:
`{REPO_ROOT}/{file}` (e.g., `{REPO_ROOT}/.adlc/memory/pdr/PDR-001.md`)

Include the full content in the output so the AI agent has the complete directive text without needing a second file read.

### Modes

The command supports two modes:

- **Persist mode** (default): Writes the discovered context to
  `.adlc/drafts/team-context.md` for reuse and delta comparison on subsequent
  prompts.
- **No-write mode** (`--no-write` in `$ARGUMENTS`): Outputs the discovery table
  inline only. No files are created or modified.

Mode is detected in this order:
1. If `$ARGUMENTS` contains `--no-write`: no-write mode.
2. Otherwise: persist mode — write `.adlc/drafts/team-context.md`.

Every invocation (auto-invoked by `team-boot` on a prompt, or manual) is
persist mode unless `--no-write` is passed.

### Step 5: Output Discovered Context

Output structured discovery results as a markdown table:

```markdown
## Discovered Team Context

| ID | Module | Type | Descriptor | Relevance |
|----|--------|------|------------|-----------|
| CDR-2026-003 | context_modules/personas/admin.md | Persona | Admin user persona for backend features | High |
| CDR-2026-020 | context_modules/rules/security/api-security.md | Rule | API security patterns for web services | High |
```

- **ID**: The CDR identifier from `CDR.md` (omitted in legacy fallback mode), or the `PDR-NNN` / `ADR-NNN` identifier from the project indexes.
- **Module**: Path to the full context module file relative to team AI directives root — or, for PDRs/ADRs, the record path relative to the project root (e.g., `.adlc/memory/pdr/PDR-001.md`).
- **Type**: Rule, Persona, Example, PDR, or ADR.
- **Descriptor**: The "when to use" summary from the CDR index; for PDRs, the `feature_area` + `category`; for ADRs, the `sub_system` + short decision.
- **Relevance**: High / Medium / Low based on keyword overlap.

For personas and rules with **High** relevance, load the full module file content and
include it directly under the table so the agent has the complete directive text
without a second file read. The same applies to High-relevance PDRs and ADRs.

Include a `search_metadata` section after the table:

```markdown
_Searched 42 CDR entries, 6 PDR entries, 9 ADR entries, 8 matches found._
```

### Step 6: Persist Team Context

**Canonical artifact**: `.adlc/drafts/team-context.md` (single location).

**Persistence rules (in order of priority)**:

1. **If `--no-write` detected**: Skip all file persistence. Output inline only.
2. **Otherwise**: Write to `.adlc/drafts/team-context.md`.

**Metadata header**: Every written file begins with a frontmatter header so
stale context can be detected and reset between features:

```markdown
---
feature: {feature identifier — derived from the current task, or "unknown"}
phase: specify | plan | implement | chat | manual   # informational only
generated: {ISO-8601 timestamp}
---
```

**Cleanup between phases (reset vs. delta)**: Before writing, read the existing
`.adlc/drafts/team-context.md` and inspect its metadata header:

- **Same `feature`** as the current task → delta-aware overwrite. Include a
  `### Changes from Previous Discovery` section (New / Dropped / Changed) so the
  agent sees what moved since the last phase without re-reading the whole file.
- **Different `feature`**, or missing/unparseable header → **reset**. Write a
  fresh file with no delta section, and include one line at the top of the body:
  `_Previous team-context for {old feature or "unknown"} discarded._`

```markdown
### Changes from Previous Discovery

- **New**: CDR-2026-042 — Python logging patterns (Rule)
- **Dropped**: CDR-2026-015 — Deprecated ORM rules (Rule)
- **Changed**: CDR-2026-003 — relevance Medium → High
```

`feature: unknown` (e.g. a manual run with no clear feature) is treated as its
own feature — the next run for a named feature resets it.

### Failure Handling

If team-ai-directives is not configured or files cannot be read:
1. Output empty results with all arrays empty
2. Include search_metadata showing 0 files searched
3. Exit successfully (code 0) - don't block the preset command

## Common Rationalizations

| Rationalization | Why It's Wrong |
|---|---|
| "I already know the tech stack, no need to check directives." | Tacit knowledge drifts from codified rules; a matching CDR may enforce constraints you've forgotten. |
| "This is a small change, discovery is overkill." | Small changes still touch rules (security, style); skipping risks silent violations. Use `--no-write` for lightweight runs. |
| "The CDR index is probably empty or outdated." | The fallback scans `context_modules/` directly, so an immature CDR still yields results. |
| "I'll just read the constitution directly and skip the index." | The constitution is one module; the index surfaces personas, rules, and examples you'd otherwise miss. |
| "No-write mode produces no real value." | Inline High-relevance module bodies give the agent complete directive text without a second read. |

## Red Flags

- Using `glob`, `find`, or any file-search tool to locate `.adlc/init-options.json` or team AI directives files — these silently skip dotfile path segments. Read exact paths directly.
- Loading every file under `context_modules/` by default instead of matching against the CDR index first (only the fallback path does full scans).
- Treating the skill load as the discovery itself — loading this SKILL.md is step 0; the Core Process below must actually run. The invocation is incomplete until the Discovered Team Context table and `search_metadata` exist. Never report discovery results that were not produced by actually reading the index.
- Writing `team-context.md` (or any file) when `$ARGUMENTS` contains `--no-write`.
- Dropping the metadata header (`feature`/`phase`/`generated`) — without it, stale-context reset between features is impossible.
- Computing a delta against a different feature's file — reset instead of diffing across features.
- Hardcoding the team AI directives path instead of resolving `team_ai_directive` from `.adlc/init-options.json`.
- Blocking on discovery failure — the process must exit 0 with empty results.

## Verification

- A **Discovered Team Context** table is produced with columns: `ID`, `Module`, `Type`, `Descriptor`, `Relevance`.
- Project PDR and ADR indexes (memory preferred, drafts fallback) were read when present, and matching rows appear with Type `PDR` / `ADR`.
- Full module file content is included inline for every entry marked **High** relevance — including PDR/ADR record bodies.
- A `search_metadata` line is present showing entries searched per source and matches found (e.g., `_Searched N CDR entries, M PDR entries, K ADR entries, J matches found._`).
- In persist mode, `team-context.md` is written to `.adlc/drafts/team-context.md` with a metadata header (`feature`/`phase`/`generated`).
- Same-feature re-runs include a delta section; different-feature (or missing/unknown header) re-runs reset with a discard line and no delta.
- In no-write mode (`--no-write`), **no files are created or modified** — output is inline only.
- Discovery runs on every prompt (auto-invoked by `team-boot`) and persists each run; there is no spec/plan gate and no continuation exemption.
- On misconfiguration or unreadable files, results are empty, `search_metadata` shows `0 files searched`, and the process exits successfully (code 0).

## Configuration

- `TEAM_AI_DIRECTIVE` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directive` field.
- Default fallback: `team-ai-directives/` relative to project root.

## 12-Factor Alignment

Factor XI (Directives as Code) — discovers relevant team directives for the current task.
