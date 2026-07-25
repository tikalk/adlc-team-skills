---
name: team-boot
description: Bootstrap the session with team-ai-directives context and project decision records (PDR/ADR indexes) before responding to any user task or question. Use when starting a new session, before any task or question, before spec workflow commands, or before making code changes.
---

# team-boot

## Overview

Bootstrap the session with team-ai-directives context before responding to any
user task or question. This skill loads the team constitution, reads the
project's decision-record indexes (PDR/ADR) for product and architecture
awareness, and runs discovery to surface relevant rules, personas, and examples.

Discovery runs on **every prompt**: `team-discover` re-matches team context to
the current message and persists it; repeats for the same feature produce a
delta so the agent can see what moved without re-reading the whole file.

You MUST invoke this skill BEFORE responding to any user task or question.
This is not optional and applies to EVERY interaction — not just spec workflow
commands. If you think this does not apply to your current task, read the
Common Rationalizations table below before deciding to skip it.

## When to Use

Invoke this skill:

- At the start of any new session or conversation
- Before responding to any user task or question
- Before any spec workflow command
- Before making code changes
- Before answering questions about the project

Re-invocation per prompt:
- **First prompt in a session**: run the full bootstrap (Steps 1–5).
- **Every subsequent prompt**: skip re-reading the constitution and
  PDR/ADR indexes (Steps 1–3) if already loaded this session, but ALWAYS
  perform Step 4 (Run Discovery) so the agent works with context matched to
  the current prompt, then briefly acknowledge (Step 5).

## Core Process

### Step 1: Locate Team AI Directives

Read the file `.adlc/init-options.json` directly. Do NOT use glob, find,
or any file-search tool to locate it — search tools may silently skip
dotfile-prefixed path segments. Read the file at the exact relative path
`.adlc/init-options.json` from the current working directory.

If that read fails (file not found), walk up parent directories by reading
`../.adlc/init-options.json`, then `../../.adlc/init-options.json`,
and so on — up to 4 levels. Stop at the first successful read.

From the JSON, extract the `team_ai_directives` field.

- If present and the path exists: use it as the team AI directives root.
- If not found or path doesn't exist: output the following guidance message and exit:
  ```text
  Team AI directives not configured.
  Run team-setup to:
    1. Clone, point to, or scaffold a team AI directives repository
    2. Write .adlc/init-options.json
    3. Inject the AGENTS.md team-boot directive
    4. Install domain skills from .skills.json
    5. Install MCP servers from .mcp.json
  ```

In subsequent steps, `{TEAM_AI_DIRECTIVES}` refers to this value, resolved
as a path relative to the current working directory. Read files at this
path directly — do NOT use glob, find, or any file-search tool to locate
them.

### Step 2: Load Team Constitution

Using the `team_ai_directives` value from Step 1, read
`{TEAM_AI_DIRECTIVES}/context_modules/constitution.md` directly. Construct
the path from the value resolved in Step 1 and read the file — do NOT use
glob, find, or any file-search tool to locate it.

Read the constitution in full.

The team constitution is the foundational principles document. It governs
agent behavior and team interactions. Internalize its principles before
proceeding — they apply to every task you will work on in this session.

### Step 3: Load Product & Architecture Context

Load the project's decision-record **indexes** for awareness-level product and
architecture context. Indexes are small tables — read them in full. Do NOT read
full `PRD.md`, `AD.md`, or individual PDR/ADR bodies during boot; those are
pulled on demand by `team-discover` and the product/architect skills.

`{REPO_ROOT}` is the project root (where `.adlc/` lives).

**PDR index** (product decisions):

1. Read `{REPO_ROOT}/.adlc/memory/pdr/pdr.md` (accepted PDRs) directly.
2. If missing but `{REPO_ROOT}/PRD.md` exists (legacy/monolithic
   project without PDRs), skim `PRD.md` at heading level: read the headings
   plus overview/mission/requirements sections only. Skip mermaid blocks,
   diagrams, and appendices.

**ADR index** (architecture decisions):

1. Read `{REPO_ROOT}/.adlc/memory/adr/adr.md` (accepted ADRs) directly.
2. If missing, skip — ADR index is absent.

**Presence notes**: If `{REPO_ROOT}/PRD.md` or `{REPO_ROOT}/AD.md` exist, note
their paths as deep-read pointers for architecture- or product-heavy tasks —
without loading them.

Skip silently for any artifact that does not exist. Projects without the PDR
or ADR lifecycle in place simply produce less context here — that is fine.

### Step 4: Run Discovery

Invoke the `team-discover` skill on **every prompt** — specify, plan,
implement, question, debugging, or chat. Discovery re-matches team context to
the current message. In build mode it persists results to
`.adlc/drafts/team-context.md` (same feature → delta-aware overwrite; different
feature → reset); in plan mode / read-only phases it outputs the table inline
only (no file writes).

Do **not** decide the prompt is a "continuation" and skip discovery. The
follow-up "fix the help message" is a different task surface than "add help
modal" and may surface different rules (accessibility, testing). There is no
prompt-type gate and no continuation exemption — every prompt re-runs
discovery. When the prompt is a pure acknowledgment with no task content
("ok", "thanks"), the run is still cheap: the delta will show "no changes".

Extract domain, technology, patterns, and actions from the user's request to
drive discovery matching, then invoke `team-discover`.

`team-discover` returns a **Discovered Team Context** table and a
`search_metadata` line. These are Step 4's output — Step 5 surfaces them.

### Step 5: Acknowledge Context (Output Contract)

After loading the constitution and the decision-record indexes and running
discovery (Step 4), surface the bootstrap result in the **visible response**
(not only in reasoning/thinking). This confirms the bootstrap completed and
makes the skill check verifiable.

**Output contract** — the visible response MUST contain, before the task
response:

- Constitution: loaded (or skipped)
- PDR index: N entries (memory | legacy PRD skim | none)
- ADR index: N entries (memory | drafts | none)
- **The `team-discover` table** (Discovered Team Context: ID / Module / Type /
  Descriptor / Relevance) **and the `search_metadata` line**, produced this
  prompt. If discovery found no matches, the table is empty but the
  `search_metadata` line still appears (e.g. `_Searched 0 CDR entries …_`).

If the discovery table or `search_metadata` is absent from the visible
response, discovery did not actually run — go back and execute `team-discover`
before proceeding. Loading a SKILL.md without producing its output table is a
failed Step 4, not a completed one.

### Failure Handling

If team-ai-directives is not configured or files cannot be read:
1. Skip silently — do not block the user's request
2. Proceed with the task using only AGENTS.md and project-level context
3. Exit successfully (the bootstrap is best-effort)

## Common Rationalizations

Do NOT rationalize skipping the skill check. Every thought below is wrong:

| Rationalization | Reality |
|---|---|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |

## Red Flags

- Responding to a user task without having read the team constitution first.
- Using glob/find or any file-search tool to locate `.adlc/init-options.json`
  instead of reading the exact relative path directly.
- Reading full `PRD.md`, `AD.md`, or individual PDR/ADR bodies during boot
  when the `pdr.md`/`adr.md` indexes exist — indexes are the awareness layer;
  bodies load on demand.
- Skipping discovery because the request "seems simple" or "obvious."
- Proceeding to answer without acknowledging what team context was loaded.
- Skipping discovery on any prompt — there is no continuation exemption and no spec/plan gate; every prompt re-runs `team-discover` so context matches the current message.
- Treating a follow-up like "fix the help message" as a continuation and skipping discovery — it is a new task surface and may surface different rules.
- Re-reading the constitution and PDR/ADR indexes on every follow-up prompt — once loaded in the session, skip Steps 1–3 and go straight to Step 4.
- Producing a Step 5 acknowledgment that references no discovery table / `search_metadata` — that means `team-discover` was loaded but not executed.
- Persisting `team-context.md` in plan mode / read-only phase — `team-discover` must run inline (no-write) there.

## Verification

The bootstrap is complete when ALL of the following are true:

1. `.adlc/init-options.json` was read directly (or walked up to, up to 4
   levels) and the `team_ai_directives` field was extracted — or empty
   results were returned and the skill exited.
2. The constitution at `{TEAM_AI_DIRECTIVES}/context_modules/constitution.md`
   was read in full.
3. The PDR index was read if present (memory or legacy `PRD.md` heading
   skim), and the ADR index was read if present (memory only). Full PDR/ADR
   bodies and full `PRD.md`/`AD.md` were NOT loaded.
4. Step 4 was performed on every prompt: `team-discover` was invoked **and
   executed** (Discovered Team Context table + `search_metadata` produced) with
   domain, technology, patterns, and actions extracted from the user's request.
   On follow-up prompts in the same session, Steps 1–3 re-reads were skipped
   but Step 4 still ran — no continuation exemption.
5. The loaded team context (constitution, indexes, discovery matches) was
   surfaced in the **visible response** before the task response — including
   the `team-discover` table and `search_metadata` line (the output contract).
6. The skill exited successfully (best-effort) even if team-ai-directives is
   unconfigured or files cannot be read.

## Configuration

- `TEAM_AI_DIRECTIVES` — Path to the team AI directives (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directives` field.
- Default fallback: `team-ai-directives/` relative to project root.

## 12-Factor Alignment

Factor XI (Directives as Code) — ensures team directives are loaded before any task.
