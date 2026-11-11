# team-setup reference: Post-Setup — MCP Config Install

Part of the `team-setup` skill. Load this file only after any setup mode completes, to seed the project's MCP config from the team declaration — copy-once, never a merge.
Shared context lives in `SKILL.md` (Goal, Input Validation, Mode Selection Flow, Post-Setup checklist).

---

4. **Install MCP config**: Read `{TEAM_AI_DIRECTIVES}/.mcp.json` if it exists, then follow the copy-once contract — the project's `.mcp.json` is project source (human-edited, never rewritten):
   - **The project has no `.mcp.json`** — copy the team file in as-is (a one-time seed, not a generation) and report which servers were seeded.
   - **The project already has a `.mcp.json`** — it wins and is **never merged into or rewritten**. Diff it against the team's and report the gap — *"your `.mcp.json` lacks N servers the team declares: X, Y"* — without writing a byte. A missing or unreadable team `.mcp.json` is itself reported; never degrade silently to "no gap".
   - Per-agent configs (`.opencode/mcp.json`, `.cursor/`, `.codex/`, `.claude/`) are the derived side of the asymmetry: they are materialized *from* the project's `.mcp.json`, never the other way round. Writing them is fine; writing the project's `.mcp.json` is not.
   - No secret values in `.mcp.json` — variable *names* only, never literal secrets; `env` indirection is the guard, not `.gitignore`.
   - In every case, highlight any unresolved environment variables needed by the servers.
