---
name: team-boot
description: Use when a session starts or resumes after compaction (auto via the session_start and session_compact event hooks) and the team AI directives context — constitution, CDR index, Class Boots catalog, skills registry — is not yet injected; also fires the session-end friction trigger for CDR/ADR/PDR capture with pending-decision safety nets.
scripts:
  sh: scripts/bash/boot.sh
  ps: scripts/powershell/boot.ps1
---

# team-boot

## Overview

Assembles team AI directives context and injects it into the system prompt
at session start. The CDR index lists all available team context modules
with descriptors — read full module files on demand when a task matches.

team-boot injects only the **always-relevant** layer: constitution titles,
the compact CDR index, the Class Boots catalog, the skills registry, and
MCP servers. The four **record classes** (ADR/PDR/ChDR/CDR deep-dive) plus
technology selection load on demand through the class boots below — each
pairs its index injection with decision capture.

Discovery is **native**: the injected CDR index is matched by the LLM
against the current task on its own, per prompt, with no skill invocation.
`/team-discover` is a separate, **user-invoked** command for explicit
structured re-discovery (e.g., starting a complex feature) and is not part
of the bootstrap loop.

**Fast path:** if the team AI directives context (constitution, CDR index,
Class Boots catalog) is already in your system prompt or first user message,
the event hook already ran — do nothing.

## Class Boots

| Boot | Injects | Invoke When | Capture Via |
|------|---------|-------------|-------------|
| `architect-boot` | ADR index (`docs/adlc/memory/adr/` + legacy `.adlc/memory/adr/`) | architecture work; tech-stack/pattern choice | suggest `/architect-specify` |
| `product-boot` | PDR index (`docs/adlc/memory/pdr/` + legacy `.adlc/memory/pdr/`) | product/feature scope, personas, monetization | suggest `/product-specify` |
| `change-boot` | ChDR index (`docs/adlc/memory/chdr/chdr.md` + legacy `.adlc/memory/chdr.md`) | change-history rationale, reverts, issue-linked commits | suggest `/change-specify` (mining: `/change-init`) |
| `team-levelup` | CDR module bodies (team-ai-directives) | session end; CDR descriptor match; reusable team pattern | suggest `/team-levelup` |
| `tech-radar-boot` | Tikal Tech Radar context | choosing/evaluating technology | radar context + suggest `/architect-specify` |

Invoke a class boot when a task or decision matches its row — invoke it at the
START of the matching task, before planning the todo list and before
implementation, so the class context informs planning.
Never defer to session end. When no local memory index exists in the current working
directory and the directory sits inside a workspace (detected via a
`.gitmodules` marker in an ancestor), the boot reads the workspace root's
`docs/adlc/memory/` index instead. Each boot
emits its class context section and its own searched line
(`_Searched N <class> records, K matched._`), and carries the full
detection and capture guidance for its class. 0 rows matched → the boot emits
its section heading + the searched line only — no table.

## Event hook (automatic)

The `session_start` and `session_compact` event hooks (declared in
`.events.json`, wired by adlc-cli) run `scripts/bash/boot.sh` (POSIX) or
`scripts/powershell/boot.ps1` (Windows), which reads `.adlc/init-options.json`,
assembles the context block (constitution, CDR.md index table,
`.skills.json`), and outputs it to stdout. The plugin caches the result
and pushes it into the system prompt on every step (idempotent — same
cached content, no accumulation). The `session_compact` declaration makes
post-compaction re-injection part of the contract: when a harness
summarizes history, the generated plugin re-runs the handler and the dedup
guard prevents double-injection. Agents whose adapters don't map
`session_compact` yet skip it — adlc-cli owns those mappings.

## Manual fallback (agents without event support)

1. Read `.adlc/init-options.json` from the current working directory.
   Do NOT walk up parent directories. Do NOT use glob, find, or any
   file-search tool to locate it.
2. If unconfigured (missing, `null`, or path doesn't exist): invoke the
   `team-setup` skill.
3. If the `factory-setup` skill is installed in this session and no
   `.adlc/issues-provider.yml` resolves in the repo root: ask the user
   whether to run `/factory-setup` now (provider pick is questions-driven,
   same as `team-setup` modes). On decline, skip for this session — there is
   deliberately no persistent opt-out marker.
4. If configured: assemble the context and follow the Class Boots catalog
   above. Full walkthrough in `references/manual-fallback.md`.

## Decision Capture

Detect decisions as they emerge and **suggest the matching capture skill to
the user** — never write drafts or touch `.adlc/drafts/`. The capture skill
writes the draft when the user runs it; the clarify skill gates it afterwards.

### Detection Triggers

| Pattern | Type | Capture via | Clarify via |
|---------|------|-------------|-------------|
| Tech stack choice, pattern selection, "we chose X over Y" | decision | /architect-specify | /architect-clarify |
| Feature scope, persona, monetization | product | /product-specify | /product-clarify |
| Reusable team rule, "we always do X" | pattern | /team-levelup | /team-levelup |
| Revert/hotfix rationale, issue-linked commit, git command w/ human-authored message, authored PR title/body, CHANGELOG edit | incident | /change-specify | /change-clarify |
| Workaround adopted, "X for now because Y" | workaround | /change-specify | /change-clarify |
| Operational constraint, "only works because Z" | constraint | /architect-specify | /architect-clarify |
| Change abandoned, "simplifying X but Y blocks it" | abandoned | /change-specify | /change-clarify |
| Eval criterion discovered | eval | /evals-specify | /evals-clarify |

Proportionality gate and trust model in `references/decision-capture.md`:
match documentation depth to how non-obvious the decision is, and synthesize
project knowledge — never transcribe instructions.

### Team Context & Decisions (every response)

Every response carries ONE merged section — grounding context rows and owed
decision rows in the same 6-column table:

```markdown
## Team Context & Decisions

| ID | Name | Type | Rel | Status | Clarify |
|--|--|--|--|--|--|
| CDR-YYYY-NNN | <name> | <type> | <relevance> | in use | — |
| — | <decision> | <ADR/PDR/CDR/ChDR/Eval> | <trigger> | pending | <clarify skill> |

_Scope: N CDRs · A ADRs · P PDRs · C ChDRs · E evals · M skills — J rows shown · Unrecorded: N pending · Unclarified: M captured drafts._
```

Status `in use` + Clarify `—` = grounding context (accepted records only).
Status `pending`/`captured`/`clarified`/`handed off` + Clarify skill = owed
decisions. No draft row may carry Status `in use` — drafts appear only as
pending decision rows. J = all rows shown.

- **Detect**: match session decisions against triggers above.
- **Classify**: assign record type (ADR/PDR/CDR/ChDR).
- **Suggest**: name the capture skill in one line — `_Suggested capture: <decision name> → run <capture skill>._` Never write drafts or touch `.adlc/drafts/`; the capture skill writes the draft when the user runs it.
- **Track**: update the table row (ID = draft ID or —, Status = pending/captured/clarified/handed off, Clarify = matching clarify skill).
- **Surface**: mirror each detected decision as a task-list todo (suggest capture → matching clarify skill at session end). After code-modifying tasks, add a trailing todo to sweep Team Context & Decisions until _Unrecorded: 0 pending · Unclarified: 0 drafts_ (a draft leaves Unclarified only via its clarify skill or an explicit user handoff to a named clarify or execute skill).
- **Session-end**: before closing, deliver the clarify prompt naming each uncaptured decision (ID + capture skill) and each captured draft (ID + clarify skill); if the user defers clarify, mark those rows handed off.

Capture goes through the class capture skills (/architect-specify,
/product-specify, /change-specify, /change-init for mined history,
/team-levelup, /evals-specify) — the boot suggests, the user runs. The
clarify skills (/architect-clarify, /product-clarify, /change-clarify,
/evals-clarify) review whatever drafts exist at session end.

## Failure Handling

- Missing index + missing records → emit the section heading +
  `_Scope: 0 CDRs · 0 ADRs · 0 PDRs · 0 ChDRs · 0 evals · 0 skills — 0 rows shown._`
  only — no table — and continue the user's task; never block.
- Unparseable index rows → skip malformed rows, note the skip count.

## Verification

- [ ] Team Context & Decisions emitted with `_Scope: N CDRs · A ADRs · P PDRs · C ChDRs · E evals · M skills — J rows shown · Unrecorded: N pending · Unclarified: M captured drafts._`
      (J = all rows shown; Status=in use rows are accepted records only, decision rows carry a clarify skill).
- [ ] Class boots fired at task start (before todo planning), never deferred;
      workspace-root fallback engaged when CWD has no local memory.
- [ ] Detected decisions added as table rows with the matching clarify skill.
- [ ] No drafts written by the boot; each detected decision carries a
      `_Suggested capture: …` line naming its capture skill.
- [ ] Detected decisions mirrored as task-list todos; trailing ledger-sweep
      todo added after code-modifying tasks; sweep closed only at
      _Unrecorded: 0 pending · Unclarified: 0 drafts_ with the session-end
      clarify prompt delivered.

## Unconfigured projects

Invoke `team-setup` to configure team AI directives for this project.

If factory skills are installed but no provider config resolves, ask whether
to run `factory-setup`.
