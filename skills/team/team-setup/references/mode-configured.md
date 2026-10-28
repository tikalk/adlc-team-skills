# team-setup reference: Mode 4 — Already Configured

Part of the `team-setup` skill. Load this file only when the project is already wired (verify and report status, then run the MCP config install).
Shared context lives in `SKILL.md` (Goal, Input Validation, Mode Selection Flow, Post-Setup checklist).

---

### Mode 4: Already Configured

The team AI directives is already configured. Verify and report status.

**Explore**:
1. Check `.adlc/init-options.json` for `team_ai_directives` field
2. If found, resolve the path and validate the team AI directives structure
3. Check `TEAM_AI_DIRECTIVES` env var as fallback
4. Check default path `team-ai-directives` as final fallback

**Present**:
Show the user the resolved team AI directives path and validation results.

**Write/Execute**:
No writes needed — the team AI directives is already configured. Then:

1. Run the **Gitignore Convention Check** (Post-Setup Configuration step 3 in
   `SKILL.md`): verify `.gitignore` carries the layout allowlist and not a
   wholesale `.adlc/` ignore; add missing rules when absent.
2. Run the **MCP config install** (Post-Setup Configuration step 5): copy the
   team `.mcp.json` into the project only if absent — an existing project file
   wins and is never merged into; report the gap instead.

*On success: complete Post-Setup Configuration — write `team_ai_directives` to `.adlc/init-options.json`, run the health check (`SKILL.md`), check the `.gitignore` convention (Gitignore Convention Check, `SKILL.md`), inject `AGENTS.md` (`references/post-setup-agents.md`), install MCP config (`references/post-setup-mcp.md`).*
