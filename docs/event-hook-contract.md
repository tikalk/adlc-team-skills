# Event Hook Contract (`.events.json`)

Two sides, two repos:

- **This repo** declares the event and provides the handler's output
  (`.events.json` + `team-boot`'s boot scripts).
- **[adlc-skills-cli](https://github.com/tikalk/adlc-skills-cli)** implements
  and owns the injection side: the dispatcher, the generated per-agent
  plugins, injection mechanics, caching, and compaction re-injection.
  Requirements and bugs for that side belong there — not here.

## What this repo owns

**`.events.json`** (tracked):

```json
{
  "events": {
    "session_start":   [ { "skill": "team-boot", "timeout": 60 } ],
    "session_compact": [ { "skill": "team-boot", "timeout": 60 } ]
  }
}
```

- Declares which skill handles each event and the handler timeout.
- Repos without it get commands only (no event wiring) on install.
- **`session_compact` is the compaction contract**: harness compaction can
  summarize the injected index away mid-session; declaring the event makes
  re-injection expected behavior rather than an accident. adlc-skills-cli's
  adapters translate canonical event names per agent — an agent whose
  adapter has no `session_compact` mapping skips it (no wiring, no
  failure) until the CLI adds one. The double-injection guard is the
  plugin's job (CLI side).

**`team-boot`'s `scripts/boot.sh` / `boot.ps1`** — the handler:

- **Input**: CWD = project root; reads `.adlc/init-options.json`
  (relative path) and resolves `team_ai_directives`.
- **Output** (stdout): the lean directives index wrapped in
  `<EXTREMELY_IMPORTANT>` tags — constitution titles, CDR index rows, the
  Class Boots catalog, and the skills registry.
- **Degradation**: missing config or a broken directives path → a short
  "run /team-setup" notice, exit 0. Never blocks the session.
- **Dependency**: `jq` for the skills-registry section.

The handler's contract is exercised end-to-end by
`scripts/acceptance-test.sh` (scratch install → configure → assert the
emitted index).

## Diagnosing a broken chain

In order:

1. `.adlc/init-options.json` exists and points at a real directory?
2. `jq` on PATH?
3. `bash .agents/skills/team-boot/scripts/boot.sh` from the project root —
   does it emit the index?
4. If yes but nothing appears in the session: the injection side failed —
   that's adlc-skills-cli's territory (generated plugin not loaded, agent
   event wiring). File it there.
5. `scripts/acceptance-test.sh` verifies the whole loop from scratch.
