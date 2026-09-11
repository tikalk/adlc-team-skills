# Lane Profiles — Cross-Runtime Dispatch (ADR-336)

## Overview

Lanes allow each step in the executor DAG to run in a different session
context. The default `agent` lane spawns a fresh session of the same CLI,
providing maker/checker separation without needing a different runtime.
The optional `cli:<runtime>` lane spawns a different CLI for cross-vendor
independence.

## Lane kinds

| Lane | What it means | Independence | Works inside container? |
|------|---------------|--------------|------------------------|
| `inline` | Orchestrator follows the skill in this session | None — shared context | Yes |
| `agent` | Spawn a fresh session of same CLI (e.g., `opencode -p`) | Fresh context — no memory of previous steps | Yes |
| `cli:<runtime>` | Spawn a different CLI (e.g., `claude --print`) | Fresh context + different model | Only if CLI on PATH (degrades to `agent`) |

**The `agent` lane is the default for unattended stages.** It provides
the maker/checker separation — the reviewer reads code from the
worktree + findings from the comment bus, not from session memory.

**`cli:<runtime>` is an optional enhancement** for teams that want
cross-vendor independence. If the target CLI is not on PATH, it degrades
to `agent` on the current runtime and discloses the lost independence.

## Profile schema

Lives in `workflow-config.yml` under the `lanes:` key:

```yaml
lanes:
  runtimes:
    <runtime-key>:
      match: ["<case-insensitive substring of the label this runtime exposes>"]
      stages:
        <step-name>: { lane: inline | agent | cli:<runtime>, model: "<id or null>", effort: "<tier or null>" }
    default:
      stages:
        <step-name>: { lane: inline | agent }
  cli:
    <runtime>:
      command: ["<executable>", "<arg>", "{cwd}"]
      runtime_label: "<label that runtime exposes>"
      skills_root: "<absolute path to skills directory>"
```

Without a `lanes` section, every stage runs `inline` (interactive stages)
or `agent` (unattended stages). This is the default — backward compatible.

## Resolution rules

1. Match this runtime's label against `runtimes[].match` (case-insensitive
   substring).
2. Use the matched runtime's `stages` mapping for each step.
3. Fall back to `default` entry if no match.
4. If no `lanes` section: interactive stages → `inline`, unattended
   stages → `agent`.
5. Refuse a profile with a newer `schema_version`, an unknown stage, a
   lane that names an undefined `cli`, or a command that is not a
   non-empty array of strings.
6. Refuse an `invocation` key on any stage — the executor invokes one
   cycle at a time, no watchers.

## Degradation ladder

```
cli:<runtime>  →  agent (this runtime)  →  inline
```

Each degradation step is:
- Disclosed to the user when it happens
- Recorded in the state file
- Named in the audit trail (Phase 6)

A `cli:` lane degrades when:
- The target CLI executable is not on PATH
- The target CLI refuses to launch (quota, auth, error)
- The target CLI exits abnormally twice in a row on a working lane

When degradation happens mid-run, the same stage is spawned again on
the new lane. The run continues — losing a lane is never a reason to
stop.

## Cross-runtime dispatch contract

A `cli:` lane dispatch:

1. Write step instruction + brief path + reads_from inputs to a temp file.
2. Spawn the other runtime's CLI with the temp file as input:
   `<command> <args> {cwd}` where `{cwd}` is substituted with the
   worktree path.
3. Wait for exit.
4. Parse stdout as the step's output.
5. The other runtime reads:
   - `.adlc/workflow/brief.md` from disk (ADR-331)
   - Step markers from the comment bus (ADR-330)
   - The step's `SKILL.md` from `skills_root` (absolute path)
6. The other runtime has no shared session context — it starts fresh.

## `agent` lane dispatch contract

An `agent` lane dispatch:

1. Spawn a fresh session of the same CLI:
   - `opencode -p "<instruction>"` (OpenCode)
   - `claude --print "<instruction>"` (Claude Code)
   - Or the runtime's equivalent non-interactive mode
2. The instruction includes: brief path, reads_from inputs, skill to
   invoke, and "Read `.adlc/workflow/brief.md` for full context."
3. Wait for exit.
4. Parse output.
5. The fresh session has no memory of previous steps — it reads code
   from the worktree and findings from the comment bus.

## Template substitution

| Placeholder | Replaced with |
|-------------|---------------|
| `{cwd}` | The run's worktree path |
| `{model}` | The stage's configured model (or dropped if null) |
| `{effort}` | The stage's configured effort tier (or dropped if null) |

When a placeholder's value is null, the preceding flag is also dropped
(e.g., `--model {model}` with null model → the `--model` flag is omitted
entirely).

## Rules

- Ships no default naming a runtime, model, or vendor.
- `invocation` key on any stage is refused.
- A `cli` stage is given an **absolute** path to its `SKILL.md` —
  never a relative path or bare skill name.
- Command templates are the user's — they carry the runtime's own
  non-interactive and approval flags. The executor neither adds nor
  removes any.
- Exactly one agent is live at a time. Never dispatch a second step
  while one is running.
- A `cli:` lane that fails to launch degrades to `agent` and discloses.
- The profile has no say in how a stage is invoked — only which runtime
  and model.
