---
name: team-boot
description: Bootstrap the session with team AI directives context (constitution, CDR index, PDR/ADR indexes, skill registry). Runs automatically at session start via the event hook.
scripts:
  sh: scripts/boot.sh
  ps: scripts/boot.ps1
---

# team-boot

## Overview

Assembles team AI directives context and injects it into the system prompt
at session start. The CDR index lists all available team context modules
with descriptors — read full module files on demand when a task matches.

Discovery is **native**: the injected CDR index is matched by the LLM
against the current task on its own, per prompt, with no skill invocation.
`/team-discover` is a separate, **user-invoked** command for explicit
structured re-discovery (e.g., starting a complex feature) and is not part
of the bootstrap loop.

## Event hook (automatic)

The `session_start` event hook runs `scripts/boot.sh` (POSIX) or
`scripts/boot.ps1` (Windows), which reads `.adlc/init-options.json`,
assembles the context block (constitution, CDR index, PDR/ADR indexes,
skill registry), and outputs it to stdout. The plugin caches the result
and pushes it into the system prompt on every step (idempotent — same
cached content, no accumulation).

## Manual fallback (agents without event support)

1. Read `.adlc/init-options.json` from the current working directory.
   Do NOT walk up parent directories. Do NOT use glob, find, or any
   file-search tool to locate it.
2. If unconfigured (missing, `null`, or path doesn't exist): invoke the
   `team-setup` skill.
3. If configured: read and assemble the constitution, CDR.md index table,
   PDR/ADR indexes, and `.skills.json` into your context.
4. The CDR index is your catalog — read full module bodies on demand
   when a task matches a CDR descriptor.

## Unconfigured projects

Invoke `team-setup` to configure team AI directives for this project.
