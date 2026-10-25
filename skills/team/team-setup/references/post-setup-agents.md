# team-setup reference: Post-Setup — Project AGENTS.md Injection

Part of the `team-setup` skill. Load this file only after any setup mode completes, to inject the project-level `AGENTS.md` directive.
Shared context lives in `SKILL.md` (Goal, Input Validation, Mode Selection Flow, Post-Setup checklist).

---

3. Inject the project-level `AGENTS.md` directive so agents auto-invoke `team-boot` at session start:

```bash
# Bash
bash "$(dirname "$0")/scripts/bash/team-helpers.sh" --inject-agents "{PROJECT_ROOT}"

# PowerShell
pwsh "$(Split-Path $PSCommandPath -Parent)/scripts/powershell/team-helpers.ps1" -InjectAgents "{PROJECT_ROOT}"
```

This creates or updates the project's `AGENTS.md` with a managed section (between `<!-- TEAM_AI_DIRECTIVES START -->` and `<!-- TEAM_AI_DIRECTIVES END -->` markers) containing:

- **Event-hook awareness**: notes that `team-boot` runs automatically at session start via the event hook (for agents with event support), injecting a lean orientation into the first user message.
- **Fallback invocation**: "If the team AI directives context is NOT in your system prompt or first user message (agent without event support), invoke the `team-boot` skill before responding to any task or question."
- **Unconfigured handling**: "If team AI directives are unconfigured, invoke the `team-setup` skill."
- **Class-boot invocation**: invoke the matching class boot at the START of a matching task — before planning the todo list and before implementation — so the class context informs planning (never deferred); workspace-root fallback when the CWD has no local memory (`.gitmodules` marker → workspace root `docs/adlc/memory/`).
- **Team Context & Decisions contract**: "Every response MUST include a Team Context & Decisions section before the task answer" — one merged 6-column table (`ID | Name | Type | Rel | Status | Clarify`): Status `in use` + Clarify `—` rows list genuinely matched accepted records; Status `pending`/`captured`/`clarified`/`handed off` + Clarify skill rows track emerging decisions (no draft row may carry `in use`), followed by `_Scope: N CDRs · A ADRs · P PDRs · C ChDRs · E evals · M skills — J rows shown · Unrecorded: P pending · Unclarified: D drafts._` (J = all rows shown). 0 rows matched → heading + counts line only, no table.
- **Render rule**: heading, table (when rows exist), and counts line each on their own lines, never collapsed
- **Todo surfacing**: each detected decision is mirrored as a task-list todo (draft written to `.adlc/drafts/{type}/`, then the matching clarify skill at session end); after code-modifying tasks, a trailing todo sweeps Team Context & Decisions until _Unrecorded: 0 pending · Unclarified: 0 drafts_ (a draft leaves Unclarified only via its clarify skill or an explicit user handoff to a named clarify or execute skill); before closing, deliver the clarify prompt naming each captured draft (ID + skill); if the user defers clarify, mark those rows handed off

Without this section, an agent without event support has no session-start instruction to load team context, and the team AI directives repository remains invisible until manually loaded. The section is idempotent: re-running `team-setup` or `team-repair` updates the section in place without duplicating content.
