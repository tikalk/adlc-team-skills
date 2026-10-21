# Lane Profiles — Cross-Runtime Dispatch

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
| `remote:<provider>` | Provision/attach a remote workspace and hand the session to the developer there | Fresh context + remote runtime + human driver | N/A — the step leaves this machine |

**The `agent` lane is the default for unattended stages.** It provides
the maker/checker separation — the reviewer reads code from the
worktree + findings from the comment bus, not from session memory.

**`cli:<runtime>` is an optional enhancement** for teams that want
cross-vendor independence. If the target CLI is not on PATH, it degrades
to `agent` on the current runtime and discloses the lost independence.

## Profile schema

Lives in the run's `mission.yml` under the `lanes:` key:

```yaml
lanes:
  runtimes:
    <runtime-key>:
      match: ["<case-insensitive substring of the label this runtime exposes>"]
      stages:
        <step-name>: { lane: inline | agent | cli:<runtime> | remote:<provider>, model: "<id or null>", effort: "<tier or null>" }
    default:
      stages:
        <step-name>: { lane: inline | agent }
  cli:
    <runtime>:
      command: ["<executable>", "<arg>", "{cwd}"]
      runtime_label: "<label that runtime exposes>"
      skills_root: "<absolute path to skills directory>"
  remote:
    <provider>:
      workspace: "<workspace name; default <repo>-mission-<issue>>"
      name_var: "<env var carrying the per-mission workspace name; default WORKSPACE_NAME>"
      template: "<template name>"
      workspace_file: "<path or URL to the repo's workspace file; default .adlc/workspace.yml>"
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
   lane that names an undefined `cli` or `remote` provider, an unknown
   `--provider` value (known: `coder`), or a command that is not a
   non-empty array of strings.
6. Refuse an `invocation` key on any stage — the executor invokes one
   cycle at a time, no watchers.
7. `--provider` selects the remote lane provider (`coder` for Coder
   workspaces). Without the flag, no `remote:` lane resolves —
   fully backward compatible.

## Degradation ladder

```
cli:<runtime>  →  agent (this runtime)  →  inline
remote:<provider>  →  HALT (hand back to developer; never agent/inline)
```

Each degradation step is:
- Disclosed to the user when it happens
- Recorded in the state file
- Named in the audit trail (Phase 6)

A `cli:` lane degrades when:
- The target CLI executable is not on PATH
- The target CLI refuses to launch (quota, auth, error)
- The target CLI exits abnormally twice in a row on a working lane

A `remote:` lane NEVER degrades to `agent` or `inline`:

- Workspace creation fails (quota, auth, template missing) → halt,
  keep the failed workspace (never auto-delete), hand back to developer.
- The workspace never reaches Running within the timeout → halt, hand back.
- SSH/herdr attach fails → halt, hand back.

Rationale: this lane is only selected when dispatch is `interactive` or
gating is `human-required`. Falling back to an unattended agent would
violate the halt-and-refuse rule (`tracker-integration.md`): a
human-required issue must never be executed by an unattended agent.
Losing the lane is a stop condition — the developer re-runs or repairs.

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
    - `runs/<run_id>/brief.md` from disk
    - Step markers from the comment bus
   - The step's `SKILL.md` from `skills_root` (absolute path)
6. The other runtime has no shared session context — it starts fresh.

## `agent` lane dispatch contract

An `agent` lane dispatch:

1. Spawn a fresh session of the same CLI:
   - `opencode -p "<instruction>"` (OpenCode)
   - `claude --print "<instruction>"` (Claude Code)
   - Or the runtime's equivalent non-interactive mode
2. The instruction includes: brief path, reads_from inputs, skill to
   invoke, and "Read `runs/<run_id>/brief.md` for full context."
3. Wait for exit.
4. Parse output.
5. The fresh session has no memory of previous steps — it reads code
   from the worktree and findings from the comment bus.

## `remote:` lane dispatch contract (coder provider)

The skill NEVER opens tabs. The developer owns their tab: they open
a terminal tab on their Mac, then run factory-mission with the
mission URL + `--provider coder`.

**The lane performs no env sync of its own.** Provision, workspace
setup, input transfer, and output streaming are owned by the adlc-cli
provider transport (`adlc-cli workspace|agent|workflow … --provider
coder`; ADR-007, PDR-010). There is no skill-side clone, skills-install,
env-report, or brief-pipe script, and no fallback script — the transport
is the single owner of SSH, keys, transfer, and failure modes.

Dispatch matrix:

| Mode | Provider flag | Lane |
|------|---------------|------|
| interactive | `--provider coder` | `remote:coder` (CLI provisions/setups → print attach instructions → wait) |
| interactive | (none) | local CLI session, as today |
| autonomous / supervised | any | unchanged (`agent` lane; provider ignored) |

A `remote:coder` lane dispatch:

1. Verify the transport: `adlc-cli --version` resolves. If the binary is
   missing or predates the `--provider` provider surface, halt with the
   version requirement — never fall back to a script.
2. Provision or reuse the workspace through the CLI:
   `adlc-cli workspace setup [<workspace_file>] --provider coder`
   - The CLI loads the repo's `.adlc/workspace.yml` (or the configured
     path/URL), expands `${VAR}` fail-fast, and provisions or reuses the
     handle persisted at `.adlc/workspaces/<name>.json`.
   - Workspace files are location-free: a `provider:` key inside one is
     rejected — the provider is selected only by the `--provider` flag.
   - Per-mission names: the repo's workspace file declares
     `name: ${WORKSPACE_NAME}`; the lane exports
     `WORKSPACE_NAME=<repo>-mission-<issue>` before invoking the CLI. An
     unset variable fails fast (the CLI names the missing var) — the lane
     never invents a fallback name. The CLI normalizes the resolved name
     to `[a-z0-9-]`, so the handle filename can never escape the
     workspaces directory.
   - Secrets resolve env-only (Docker secret → `secrets.env` → process
     env), only for referenced vars, and are redacted outbound.
3. Run the step through the transport:
   `adlc-cli workflow run <source> --input run_id=<run_id> --provider coder`
   (or `adlc-cli agent run "<instruction>" --provider coder` for a single
   agent step). The CLI streams JSONL back and scrubs secrets from output.
4. If the CLI reports the live transport as unavailable
   (`not implemented: live coder transport`, exit 1), halt and hand back.
   Do not sync manually and do not fall back to a script: a non-zero exit
   is a stop condition.
5. Print attach instructions for the developer's own tab (do NOT
   attach, do NOT open tabs). Primary path is plain SSH, which always works:
   - `coder ssh <workspace>` (primary), then `cd <repo>`.
   - `herdr --remote coder.<workspace>.main` fallback (requires herdr
     client on the developer's Mac; address format `coder.<workspace>.main`).
   Then wait — the developer drives; the lane resumes on `done`.
6. The developer launches the agent CLI in THEIR tab on the brief:
   `opencode --prompt "$(cat .adlc/workflows/runs/<run_id>/brief.md)"`
   (the lane never spawns the CLI).
7. Teardown: developer types `done` → explicit confirm → `coder delete
   <workspace> --yes`. Teardown stays skill-side because the provider
   transport exposes no delete operation; it is the only remaining lane
   script.

| Placeholder | Replaced with |
|-------------|---------------|
| `{workspace}` | The `<repo>-mission-<issue>` workspace name |
| `{workspace_file}` | The repo's workspace file path (default `.adlc/workspace.yml`) |

## Template substitution

| Placeholder | Replaced with |
|-------------|---------------|
| `{cwd}` | The run's worktree path |
| `{workspace}` | The `<repo>-mission-<issue>` workspace name (remote lanes) |
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
- A `remote:` lane NEVER degrades to `agent` or `inline` — it halts and
  hands back to the developer (human-required gate); a failed workspace
  is never auto-deleted.
- A `remote:` lane NEVER carries its own env bootstrap. Provision, setup,
  transfer, and streaming belong to the `adlc-cli` provider transport;
  only teardown (no transport delete op) remains a lane script.
- The profile has no say in how a stage is invoked — only which runtime
  and model.
