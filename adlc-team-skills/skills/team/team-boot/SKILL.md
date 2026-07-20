---
name: team-boot
description: Bootstrap the session with team-ai-directives context before responding to any user task or question. Use when starting a new session, before any task or question, before spec workflow commands, or before making code changes.
---

# team-boot

## Overview

Bootstrap the session with team-ai-directives context before responding to any
user task or question. This skill loads the team constitution and runs
discovery to surface relevant rules, personas, and examples.

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

You do NOT need to re-invoke if:
- You already ran `/team-boot` in the current session AND
- The user's follow-up is a direct continuation of the same task

## Core Process

### Step 1: Locate Knowledge Base

Read the file `.adlc/init-options.json` directly. Do NOT use glob, find,
or any file-search tool to locate it — search tools may silently skip
dotfile-prefixed path segments. Read the file at the exact relative path
`.adlc/init-options.json` from the current working directory.

If that read fails (file not found), walk up parent directories by reading
`../.adlc/init-options.json`, then `../../.adlc/init-options.json`,
and so on — up to 4 levels. Stop at the first successful read.

From the JSON, extract the `team_ai_directives` field.

- If present and the path exists: use it as the knowledge base root.
- If not found or path doesn't exist: output empty results and exit.

In subsequent steps, `{TEAM_DIRECTIVES}` refers to this value, resolved
as a path relative to the current working directory. Read files at this
path directly — do NOT use glob, find, or any file-search tool to locate
them.

### Step 2: Load Team Constitution

Using the `team_ai_directives` value from Step 1, read
`{TEAM_DIRECTIVES}/context_modules/constitution.md` directly. Construct
the path from the value resolved in Step 1 and read the file — do NOT use
glob, find, or any file-search tool to locate it.

Read the constitution in full.

The team constitution is the foundational principles document. It governs
agent behavior and team interactions. Internalize its principles before
proceeding — they apply to every task you will work on in this session.

### Step 3: Run Discovery

Invoke the `team-discover` skill to scan the CDR
index and match personas, rules, examples, and skills against the current
task context.

If the user's message describes a specific feature or task, extract:
- **Domain**: What business area is this?
- **Technology**: What tech stack?
- **Patterns**: What architectural patterns?
- **Actions**: What is the feature doing?

Use these to drive the discovery matching. If the user's message is vague
("I need to add a login modal"), still run discovery — the team knowledge base
may contain relevant rules (e.g., security patterns, testing standards) that
apply broadly.

### Step 4: Acknowledge Context

After loading the constitution and running discovery, briefly acknowledge what
team context was loaded before proceeding to respond to the user's request.
This confirms the bootstrap completed and makes the skill check visible.

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
- Skipping discovery because the request "seems simple" or "obvious."
- Proceeding to answer without acknowledging what team context was loaded.
- Re-invoking on every follow-up that is a direct continuation of the same task.

## Verification

The bootstrap is complete when ALL of the following are true:

1. `.adlc/init-options.json` was read directly (or walked up to, up to 4
   levels) and the `team_ai_directives` field was extracted — or empty
   results were returned and the skill exited.
2. The constitution at `{TEAM_DIRECTIVES}/context_modules/constitution.md`
   was read in full.
3. `team-discover` was invoked with domain, technology, patterns, and actions
   extracted from the user's request.
4. The loaded team context was briefly acknowledged before responding to the
   user's request.
5. The skill exited successfully (best-effort) even if team-ai-directives is
   unconfigured or files cannot be read.

## Configuration

- `ADLC_TEAM_AI_DIRECTIVES` — Path to the team-ai-directives knowledge base (overrides `.adlc/init-options.json`).
- `.adlc/init-options.json` — Project-level config file with `team_ai_directives` field.
- Default fallback: `.adlc/team-ai-directives/` relative to project root.

## 12-Factor Alignment

Factor XI (Directives as Code) — ensures team directives are loaded before any task.
