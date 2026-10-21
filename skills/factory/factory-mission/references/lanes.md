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
      branch_var: "<env var carrying the branch to clone; default BRANCH>"
      template: "<template name>"
      workspace_file: "<path or URL to the repo's workspace file; default .adlc/workspace.yml>"
```

The `remote:` keys are read by the remote dispatch contract below:
`workspace` / `name_var` decide the provisioned workspace name,
`branch_var` is the branch the workspace clones, `workspace_file` is the
file the CLI reads, `template` is the Coder template requested for the
workspace. (The keys are the lane's
*declarative* form: the contract's commands below show the resolved
values — `<workspace>`, `<workspace_file>` — so a profile that sets them
changes what the lane passes to the transport.)

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
   fully backward compatible. A stage that declares
   `lane: remote:<provider>` while `--provider` is absent is REFUSED:
   the profile does not silently resolve to another lane, it halts and
   hands back to the developer. The remote lane requires the `interactive`
   dispatch label — in `autonomous`/`supervised` modes `--provider` is
   refused.

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
the new lane. The run continues — losing a `cli:` lane is never a reason
to stop. A `remote:` lane is exempt from this rule: losing it is a stop
condition (see above).

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
coder`; the decision lives in the workspace's decision memory: ADR-437 (the
lane's delegation contract) + ADR-443 (the transport) + PDR-128). There is no skill-side clone, skills-install,
env-report, or brief-pipe script, and no fallback script — the transport
is the single owner of SSH, keys, transfer, and failure modes.

Dispatch matrix (one truth, read with SKILL.md §Phase 0):

| Dispatch label | Provider flag | Lane |
|----------------|---------------|------|
| `interactive` | `--provider coder` | `remote:coder` (CLI provisions/setups → print attach instructions → wait) |
| `interactive` | (none) | **HALT execution** (hand back to the interactive session) |
| `autonomous` / `supervised` | any | the `agent` lane — `--provider` is **refused** in these modes (a remote lane would hand an unattended run to a human) |

**The DISPATCH dimension alone picks the lane.** `interactive` is the
dispatch label the remote lane requires: the lane is developer-driven (the
human drives in their own tab), so it is an interactive-session lane. The
automation-gating label (`human-required` vs `agent-can-execute`) is a
*different* dimension and stays orthogonal here: it decides whether the
agent may auto-execute at all (`tracker-integration.md` §2 — dispatch
`interactive` **or** gating `human-required` → the agent halts and refuses
auto-execution). A `human-required` + `supervised` issue therefore does
NOT take the remote lane: `--provider` is refused, because the dispatch
dimension says the run is supervised, not interactive.

**One owner per step.** On the `remote:coder` lane the DEVELOPER drives the
agent in their own tab; the lane never spawns the **agent** CLI (it does
invoke the adlc-cli transport to provision — that is the transport, not an
agent). The transport's remote-execution commands (`workflow run` /
`agent run … --provider coder`) belong to the executor when it owns a
remote step — not to this developer-driven lane.

A `remote:coder` lane dispatch:

1. Verify the transport: `adlc-cli version` resolves. The setup call in
   step 2 must print the provider-path marker on stderr —
   `provider path: coder workspace` — because an adlc-cli older than the
   transport ignores `--provider`, runs the LOCAL setup, exits 0 and prints
   no marker. A missing marker means the transport is not there: halt, name
   the requirement, and never fall back to a script.
2. Provision or reuse the workspace through the CLI:
   `WORKSPACE_NAME=<repo>-mission-<issue> BRANCH=<mission branch> adlc-cli workspace setup [<workspace_file>] --provider coder`
   - The repo's workspace file declares the per-run values it needs; the
     lane supplies every `${VAR}` it references — `WORKSPACE_NAME` (the
     workspace name) and `BRANCH` (the branch to clone). A variable the
     file references and the lane does not supply fails the setup with its
     name — the lane never invents a value for it.
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
     env) and are forwarded to the remote for referenced vars only. A
     secret-sourced value is never inlined into the workspace config; it
     travels only in the transport's vars channel, and the CLI scrubs it
     from every output path.
3. If the CLI exits non-zero — including
   `not implemented: live coder transport` (exit 1) — halt and hand back.
   Do not sync manually and do not fall back to a script: a non-zero exit
   is a stop condition.
4. **Hand the session to the developer.** The lane owns the WORKSPACE; the
   developer owns the SESSION. Print the re-entry sequence, verbatim:

   ```
   Connect:  coder ssh <workspace>
   Then:     cd <project root>          # where .agents/, AGENTS.md and .adlc/init-options.json live
             opencode                  # the interactive TUI (opencode run … for a headless step)
   Then in opencode:  /factory-mission --url <issue-url>
   ```

   The developer's command is the SAME mission, **without `--provider
   coder`** — the workspace is already provisioned and set up, so the
   mission runs locally in that session, in the cloned repository, with the
   skills and the team context already bound. (The `herdr --remote
   coder.<workspace>.main` path is the fallback for reaching that session
   when `coder ssh` is unavailable; it requires the herdr client on the
   developer's Mac.)

   Two consequences worth stating:

   - **The brief never crosses the transport.** The remote session compiles
     its own brief from the issue URL — there is no brief file to place on
     the remote and no transfer channel is needed.
   - **The session runs in the workspace's project root**, not inside the
     cloned repository: the event hook, the installed skills and
     `AGENTS.md` are bound at the project root, and the hook resolves them
     relative to the project. A session started inside the clone fails the
     hook (`Cannot find module '<clone>/.agents/dispatcher.mjs'`).
5. Wait — the developer drives from here. The lane does not run the
   mission's steps itself, and it never spawns the agent CLI.
6. Teardown: developer types `done` → the lane runs the teardown gate:
   `bash skills/factory/factory-mission/scripts/bash/remote-coder-teardown.sh <workspace> --yes`
   Teardown stays skill-side because the provider transport exposes no
   delete operation; it is the only remaining lane script. The gate
   refuses a name that is not lane-shaped (`<repo>-mission-<id>`), lists
   **all** workspaces (not just the caller's own) so an owned-elsewhere
   workspace is not mistaken for "not found", and exits non-zero unless the
   workspace was deleted or there was nothing to delete (`6` = waiting for
   the `done`, `4` = lookup failed, `5` = delete failed).

### Remote execution by the executor (not this lane)

When the executor itself owns a remote step, the step runs through the
transport against the workspace the lane provisioned:

```
adlc-cli workflow run <source> --input run_id=<run_id> \
    --provider coder --workspace <repo>-mission-<issue>
```

`<source>` is the workflow to run remotely: a YAML path, an installed
workflow id, or a built-in id such as `factory`. `--workspace` targets the
handle created in step 2 (the same name), so the step runs on the mission
workspace and never provisions a second one.

| Placeholder | Replaced with |
|-------------|---------------|
| `{workspace}` | The `<repo>-mission-<issue>` workspace name (written `<workspace>` in the commands below) |
| `{workspace_file}` | The repo's workspace file path (default `.adlc/workspace.yml`) (written `<workspace_file>` in the commands below) |

## Template substitution

| Placeholder | Replaced with |
|-------------|---------------|
| `{cwd}` | The run's worktree path |
| `{model}` | The stage's configured model (or dropped if null) |
| `{effort}` | The stage's configured effort tier (or dropped if null) |

(`{workspace}` and `{workspace_file}` are remote-lane placeholders — see the
remote dispatch contract above.)

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
