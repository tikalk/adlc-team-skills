# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.23.0] - 2026-08-04

### Added

- **New `workspace` skill** (`skills/workspace/SKILL.md`, `skills/workspace/scripts/bash/workspace.sh`): multi-repo workspace coordinator for shared team context. Discovers child repos at depth 1, links them as Git submodules, and audits workspace health (branch, dirty state, unpushed commits, SHA drift, `.adlc` presence). Designed for the VS Code `.code-workspace` analogy: a parent coordination repo holds shared PDRs, ADRs, and CDRs under `.adlc/` (created by `product-specify`, `architect-specify`, `levelup-specify`), while child implementation repos are linked as submodules for unified context. No `workspace.yml` — pure auto-discovery by convention.

  Commands: `/workspace` (discover), `/workspace --link` (register submodules), `/workspace --status` (audit), `--dry-run`, `--force`, `--json`.

  Safety: read-only by default; `--link` requires clean parent tree; idempotent (skips already-registered submodules); `.specify` is intentionally NOT excluded from discovery (may be a legit child repo).

### Changed

- **`.gitignore` now excludes `.mcp.json`**: local MCP server config may contain tokens or absolute paths; each contributor runs `team-setup` to merge MCP servers. Matches the existing pattern for `AGENTS.md` and `.adlc/`.

## [0.22.4] - 2026-08-04

### Fixed

- **Team Context in Use counts-line integrity** (`skills/team/team-boot/scripts/boot.sh`, `boot.ps1`, `team-helpers.sh`, `team-helpers.ps1` across `team-setup`/`team-repair`/`team-skills`): the output contract now explicitly states "J MUST equal the number of rows in your table; if no CDRs/skills genuinely match, show an empty table with 0 matched." A session review caught the model rendering a 2-row table while the metadata line still read "1 matched" — the model was copy-pasting the count from a prior turn instead of counting its own rows. v0.22.3 anchored the row content; this fixes the count.

- **Canonical "Team Context in Use" heading** (same files): the template now shows `## Team Context in Use` as the exact heading. Previously the section had no specified heading, so different models (gemini-3.6-flash vs kimi-k3) improvised — some used `## Team Context in Use`, some omitted it — producing inconsistent traces.

### Added

- **Context-efficiency guidance in boot orientation** (`boot.sh`, `boot.ps1`): one line — "Prefer targeted file searches over broad directory listings to conserve context." A session review found three 100+ entry directory globs (including `__pycache__` noise) for a task that needed only four targeted file reads.

- **Regression tests for the contract integrity** (`tests/unit/test_team_boot_setup_flow.py`): `test_boot_{sh,ps1}_context_contract_integrity` assert the J-must-equal instruction, canonical heading, and exploration guidance are present; extended `test_agents_md_simplified` with the heading and J instruction assertions.

## [0.22.3] - 2026-08-04

### Fixed

- **De-anchored the Team Context in Use example row** (`skills/team/team-boot/scripts/boot.sh`, `boot.ps1`, `team-helpers.sh`, `team-helpers.ps1` across `team-setup`/`team-repair`/`team-skills`): the template's example table row was a real CDR (`CDR-2026-003 | Cloud-Native Platform Architect | Persona | High`), which anchored models to cargo-cult that specific CDR into every response instead of searching for a genuine match. Replaced with a placeholder `| CDR-YYYY-NNN | <name> | <type> | <relevance> |` that signals "fill me in." A session review caught the model emitting CDR-2026-003 for unrelated tasks (team-setup, git-skill design) where it was not genuinely relevant.

- **Resolved doc drift between team-setup/team-repair SKILL.md and the injected AGENTS.md template** (`skills/team/team-setup/SKILL.md`, `skills/team/team-repair/SKILL.md`): the skills still documented the pre-v0.19 hard-mandate AGENTS.md template ("Strict Compliance," "First-Tool-Call Gate," "Plan-Mode Compatibility," "Anti-pattern counter-rationalizations"), contradicting the actual v0.22.x lean template (event-hook awareness, fallback invocation, unconfigured handling, Team Context in Use contract) and the regression test at `test_team_boot_setup_flow.py:223` which asserts the gate is absent. Rewrote the managed-section description, Red Flags bullet, and verification checklist items to match the shipped template.

- **Replaced stale EVAL-004 criterion** (`evals/promptfoo/goldset.md`, `goldset.json`, `config.js`, `graders/`): the old "team-boot First-Tool-Call Gate" criterion graded for a behavior v0.19 deliberately removed (manual `team-boot` invocation on every session), contradicting the unit test that asserts the gate is absent. Replaced with "Team Context in Use Table Compliance" — a criterion that tests the actual current behavior and specifically catches the anchoring bug (fails when the model copies the placeholder example row or a hard-coded CDR instead of reporting a genuine match). Deleted `graders/check_team_boot_first_call.py`; added `graders/check_team_context_table.py`.

### Added

- **Regression tests for the placeholder example row** (`tests/unit/test_team_boot_setup_flow.py`): `test_boot_{sh,ps1}_example_row_is_placeholder` assert the real CDR row is absent and the placeholder is present; extended `test_agents_md_simplified` with the same assertions for the generated AGENTS.md.

## [0.22.2] - 2026-08-04

### Fixed

- **Team Context in Use table now includes Name column** (`skills/team/team-boot/scripts/boot.sh`, `boot.ps1`, `team-helpers.sh`, `team-helpers.ps1`): the output contract table changed from `| ID | Type | Relevance |` to `| ID | Name | Type | Relevance |` so the LLM displays a human-readable name (from the CDR descriptor or skill name) alongside the ID. Makes the table more useful for the user.

## [0.22.1] - 2026-08-04

### Fixed

- **boot.sh/boot.ps1 now output actual CDR and skill counts** (`skills/team/team-boot/scripts/`): the lean orientation now computes and displays `_Total: N CDR entries available._` and `_Total: M skills available._` so the LLM doesn't have to guess counts for the Team Context in Use metadata line. The output contract template now shows `Plus: _Searched $CDR_COUNT CDR entries, $SKILL_TOTAL skills, J matched._` with actual counts filled in. Also added "Match CDR entries and skills from the lists above to the current task." to guide the LLM's matching.

## [0.22.0] - 2026-08-04

### Changed

- **Switched from system.prompt to first user message injection** (`adlc-skills-cli/src/registry.mjs`, `src/events.mjs`): opencode `session_start` now maps to `experimental.chat.messages.transform` instead of `experimental.chat.system.transform`. LLMs treat first user message content as active instructions (like superpowers), not passive system prompt context. Guard checks for `EXTREMELY_IMPORTANT` marker to prevent double-injection on step re-fires.

- **boot.sh/boot.ps1 output lean orientation wrapped in EXTREMELY_IMPORTANT** (`skills/team/team-boot/scripts/`): replaced full context injection (~200 lines) with lean orientation (~90 lines): constitution principle titles, compact CDR index table (ID + Type + Descriptor), skill names + descriptions, MCP server names. Full content read on demand. Wrapped in `<EXTREMELY_IMPORTANT>` tags.

- **AGENTS.md simplified to fallback for non-event agents** (`skills/team/team-{setup,repair,skills}/team-helpers.sh`, `team-helpers.ps1`): AGENTS.md now serves as fallback for agents without event support. For agents WITH event support, the event hook injects the lean orientation into the first user message automatically.

### Added

- **`.events.json` installed to target project** (`adlc-skills-cli/src/cli.mjs`): `add` now copies `.events.json` from source to target project. `upgrade` re-reads it to regenerate events. `remove` cleans it up. This enables `upgrade` to re-generate event configs without re-running `add`.

### Fixed

- **Boot cache invalidation on config change** (carried from v0.21.0): `_sessionStartCache` tracks `.adlc/init-options.json` mtime via `statSync`. Cache invalidates when team-setup creates/modifies/deletes the config.

## [0.21.3] - 2026-08-04

### Added

- **Team Context in Use table in every response** (`skills/team/team-{setup,repair,skills}/team-helpers.sh`, `team-helpers.ps1`): AGENTS.md now requires the LLM to display a simplified CDR usage table before every task answer. The table shows matched CDR entries and skills from the registry (ID, Type, Relevance), plus a `_Searched N CDR entries, M skills, J matched._` metadata line. This makes the invisible system-prompt context visible and verifiable — the user can see which team context the LLM is using. Works on every prompt, with both event-hook (passive context) and manual fallback (team-boot skill invocation) paths.

## [0.21.2] - 2026-08-04

### Fixed

- **AGENTS.md now directs LLM to read injected context before exploring** (`skills/team/team-{setup,repair,skills}/team-helpers.sh`, `team-helpers.ps1`): session review showed the LLM ignores the injected CDR index and skills registry in the system prompt, exploring the workspace manually instead. Added explicit directive: "BEFORE exploring the codebase, read the CDR index and skills registry in your system prompt." This tells the LLM to use the injected context first, not explore blindly.

## [0.21.1] - 2026-08-04

### Fixed

- **Simplify injected AGENTS.md template** (`skills/team/team-helpers.sh`, `skills/team/team-helpers.ps1`): Updated the `team-helpers` `--inject-agents` task to inject the simplified, non-bloated, and event-compatible `AGENTS.md` managed section. Removes legacy v0.17.x "First-Tool-Call Gate" and "Strict Compliance" text which erroneously instructed models to always invoke `team-boot` manually on every session, even though in v0.18+ / v0.21.0 `team-boot` runs automatically via the session-start event hook.

## [0.21.0] - 2026-08-03

### Changed

- **boot.sh/boot.ps1 assemble .skills.json + .mcp.json into system prompt** (`skills/team/team-boot/scripts/`): the session-start context now includes both the skills catalog (`.skills.json`) and MCP server config (`.mcp.json`) from team-ai-directives, giving the LLM full visibility into available team skills and MCP servers.

- **team-setup no longer installs team skills** (`skills/team/team-setup/SKILL.md`): removed the "Offer team skills installation" step (step 4 in Post-Setup Configuration). The `.skills.json` catalog is injected into the system prompt by boot.sh, and the LLM reads SKILL.md files directly from the team-ai-directives path. MCP config install (`.mcp.json` → project config) is kept — it has user preferences per project. Replaced `python3` calls with `jq` for JSON manipulation.

- **team-repair removed extension phase + OKF index.md/log.md generation** (`skills/team/team-repair/SKILL.md`): removed Check 1 (Extension Installed) referencing the obsolete `.adlc/extensions/.registry` system (7 checks now, down from 8). Removed Step 5 (Generate OKF index.md/log.md) — CDR.md is the sole authoritative index. Removed OKF index.md/log.md from repair targets, output list, and summary report.

- **README.md updated** (`README.md`): added links to [`tikalk/agentic-sdlc-team-ai-directives`](https://github.com/tikalk/agentic-sdlc-team-ai-directives), updated team-boot/team-discover descriptions to match the v0.18+ architecture (session-start event hook, system prompt injection, manual-only team-discover), removed `user_prompt_submit` references.

### Added

- **radar-search.sh** (`skills/tech-radar/tech-radar-context/scripts/`): bash + jq replacement for radar-search.py. Deterministic search, alias normalization, Why? extraction, markdown table output. No Python dependency.
- **radar-search.ps1** (`skills/tech-radar/tech-radar-context/scripts/`): PowerShell variant using native ConvertFrom-Json.

### Removed

- **radar-search.py** (`skills/tech-radar/tech-radar-context/scripts/`): replaced by radar-search.sh (bash + jq) and radar-search.ps1 (PowerShell). Eliminates Python dependency from skill scripts.
- **Skills installation step in team-setup**: team skills are now read directly from team-ai-directives via the .skills.json catalog in the system prompt.
- **OKF index.md/log.md generation in team-repair**: CDR.md is the sole authoritative index.

### Fixed

- **Boot cache invalidation on config change** (`adlc-skills-cli/src/events.mjs`): the opencode plugin's `_sessionStartCache` now tracks `.adlc/init-options.json` state (existence + mtime) via `statSync`. When team-setup creates/modifies/deletes the config, the cache is invalidated and boot.sh re-runs with the new state. Fixes "after team-setup, session still thinks team-ai-directives isn't configured."

## [0.20.1] - 2026-08-03

### Changed

- **Unconfigured boot.sh output changed to user-facing warning** (`skills/team/team-boot/scripts/boot.sh`, `scripts/boot.ps1`): v0.20.0 tried imperative instructions to the LLM ("Invoke the team-setup skill"), but session reviews showed the LLM ignores system prompt instructions — it's passive context, not an active skill load. Changed to a simple user-facing warning: "⚠️ Team AI directives not configured. Run /team-setup to wire in team context modules." No LLM enforcement, no rationalization cycle. The user sees the warning and decides whether to run `/team-setup`.

## [0.20.0] - 2026-08-03

### Changed

- **team-boot unconfigured output changed from informational to imperative** (`skills/team/team-boot/scripts/boot.sh`, `scripts/boot.ps1`): v0.19.0 made the unconfigured output informational ("Run /team-setup to wire in team context modules"), but session review showed the LLM ignored it entirely and proceeded without invoking team-setup. The output is now imperative: "Invoke the team-setup skill to configure it: skill({name: \"team-setup\"})". This is imperative (direct command) without being adversarial (no MANDATORY, no anti-rationalization table). Includes the one rationalization that kept appearing across 4 sessions ("this is a dev repo") blocked inline: "This applies to ALL repos — skills repos, consumer projects, and dev repos alike."

## [0.19.0] - 2026-08-03

### Changed

- **team-setup mandate replaced with informational note** (`skills/team/team-boot/scripts/boot.sh`, `scripts/boot.ps1`): v0.18.x tried to enforce team-setup via MANDATORY language + anti-rationalization table in the boot script output. Four consecutive session reviews showed the LLM finds a new rationalization every time — the adversarial dynamic (mandate → evaluate whether it applies → rationalize skip) is unwinnable via text hardening. The unconfigured output is now informational: "Team AI directives not configured for this project. Run /team-setup to wire in team context modules." No MANDATORY, no rationalization table, no adversarial trigger.

### Removed

- Anti-rationalization table from boot.sh/boot.ps1 unconfigured output (6 blocked rationalizations — all obsolete)

## [0.18.2] - 2026-08-03

### Fixed

- **Block "I invoked the skill, that's enough" rationalization** (`skills/team/team-boot/scripts/boot.sh`, `scripts/boot.ps1`): v0.18.1 blocked 5 rationalizations but the LLM found a 6th — it invoked `skill({name: "team-setup"})` (which only loads the skill content), then rationalized skipping the actual setup flow ("I invoked team-setup as required... full interactive setup isn't applicable here"). Added a 6th blocked rationalization: "Loading is not executing. Run the setup flow to completion."

## [0.18.1] - 2026-08-03

### Fixed

- **Anti-rationalization hardening restored in boot.sh/boot.ps1** (`skills/team/team-boot/scripts/boot.sh`, `scripts/boot.ps1`): v0.18.0 removed the anti-rationalization table from team-boot's SKILL.md on the assumption that the event hook makes LLM compliance enforcement obsolete. But the event hook only automates **boot** — it does NOT automate **setup**. When unconfigured, boot.sh outputs a mandate to invoke team-setup, but the LLM can still rationalize skipping it (confirmed in session review: LLM spent 31.5s thinking, then skipped team-setup to "be helpful"). The fix adds condensed anti-rationalization language to boot.sh's unconfigured output — the same 5 rationalizations v0.17.1 blocked, now in the script output that lands in the system prompt.

## [0.18.0] - 2026-08-03

### Changed

- **team-boot rewritten to script-path session-start injection** (`skills/team/team-boot/SKILL.md`, `scripts/boot.sh`, `scripts/boot.ps1`): team-boot now uses a shell script (POSIX + PowerShell variants) that assembles team AI directives context (constitution, CDR index table, PDR/ADR indexes, skill registry) and injects it into the system prompt at session start. The CDR index lists all available context modules with descriptors — the LLM natively matches descriptors against the current task and reads full module bodies on demand via the `read` tool. This replaces the previous body-path injection (279-line SKILL.md interpreted by the LLM every session) with deterministic script execution (~50 lines). The opencode plugin caches the script output at module level so `system.transform` re-fires are free.

- **team-discover no longer auto-invoked per prompt** (`skills/team/team-discover/SKILL.md`): with the CDR index in the system prompt, the LLM natively matches descriptors — no per-prompt discovery scan needed. team-discover is now a manual re-scan tool available via `/team-discover` for explicit structured discovery tables. Body reduced from 341 to ~35 lines. The `user_prompt_submit` event is removed from `.events.json`. The `team-context.md` persistence artifact, delta computation, and dedup logic are all eliminated.

- **AGENTS.md simplified** (`AGENTS.md`): the anti-rationalization table, first-tool-call gate, and per-prompt discovery directive are removed — the event hook makes bootstrap automatic, so LLM compliance enforcement is obsolete. Reduced from 35 to ~12 lines.

### Added

- **boot.sh** (`skills/team/team-boot/scripts/boot.sh`): POSIX shell script (pure grep/sed, no node/python) that reads `.adlc/init-options.json`, extracts the CDR index table via `awk`, and assembles the full context block. Handles unconfigured, null opt-out, and missing-path cases.
- **boot.ps1** (`skills/team/team-boot/scripts/boot.ps1`): PowerShell variant using native `ConvertFrom-Json`.

### Removed

- Per-prompt `team-discover` invocation and `user_prompt_submit` event (`.events.json`)
- `team-context.md` persistence and delta computation
- Anti-rationalization table and Red Flags (obsolete with event hook)
- v0.17.1 anti-second-guessing hardening (event hook = automatic, no LLM choice)
- Empty `scripts/bash/` and `scripts/powershell/` placeholder directories

## [0.17.2] - 2026-08-02

### Fixed

- **PromptFoo evals no longer target retired GitHub Models** (`evals/promptfoo/config.js`, `.github/workflows/test.yml`): GitHub Models (`models.inference.ai.azure.com`) was retired on 2026-07-30, so CI eval runs returned `HTTP 404` / `410` on every test case. The provider now uses the standard OpenAI API keyed by `OPENAI_API_KEY` (with an optional `OPENAI_BASE_URL` override for OpenAI-compatible proxies). The `evaluate-skills` workflow job passes `OPENAI_API_KEY` instead of `GITHUB_TOKEN` and is skipped when the secret is unset (e.g. forks/PRs) so the rest of CI still passes.

### Added

- **`EVAL_MODEL` environment variable** (`evals/promptfoo/config.js`): the eval provider model can now be selected at runtime via `EVAL_MODEL` (defaults to `gpt-4o-mini`). This enables running the suite through any OpenAI-compatible provider, e.g. OpenCode Zen (`OPENAI_BASE_URL=https://opencode.ai/zen/v1`, `EVAL_MODEL=deepseek-v4-flash-free`).

### Changed

- **Eval results path** (`evals/promptfoo/config.js`): `outputPath` now resolves inside the repository at `evals/results/run_results.json` instead of escaping one directory level up via a CWD-relative `../results/run_results.json`.

## [0.17.1] - 2026-08-02

### Fixed

- **Strict Enforcement of  Self-Install in **: Added explicit anti-second-guessing directives to  Step 1, Common Rationalizations, and Red Flags. Forbids LLMs from talking themselves out of invoking  in build mode when the user's prompt is a question/consultation or when the working directory is perceived as a "skills repo" or "meta repo".

## [0.17.0] - 2026-08-02

### Changed

- **`team-boot` Self-Installs via `team-setup`**: Reverses the v0.16.5 handover-only design. When `.adlc/init-options.json` or `team_ai_directives` is unconfigured, `team-boot` Step 1 now invokes the `team-setup` skill so the project wires itself (build mode). In plan/read-only mode it defers instead — printing the `/team-setup` guidance and remembering the deferral for the session.
- **Persistent Opt-Out Marker**: A user decline during model-invoked setup may write `team_ai_directives: null` (or `"team_setup": "declined"`) to `.adlc/init-options.json` (build mode only). `team-boot` treats this as a silent skip on every prompt — no setup offer, no guidance. Session declines are remembered for the session; plan-mode declines cannot be persisted.
- **`team-setup` Is Now Model-Invoked**: Removed `disable-model-invocation: true` from the `team-setup` frontmatter — it becomes the sole model-invocable interactive skill. Added a Decline Handling section (session-scoped skip + persistent opt-out). Still available on demand via `/team-setup`.
- **`team-discover` Handover Aligned**: Wording updated to reflect that `team-boot` invokes `team-setup` (build) or defers with the handover note (plan) when unconfigured. The Step 4 guard (never invoke `team-discover` when unconfigured) is unchanged.

### Added

- Unit tests `tests/unit/test_team_boot_setup_flow.py` (renamed from `test_team_boot_handover.py`) asserting the 3-state Step 1, plan-mode deferral, opt-out marker, `team-setup` model-invocation frontmatter, and decline handling.

## [0.16.5] - 2026-08-02

### Fixed

- **`team-boot` Hands Over to `/team-setup` When Unconfigured**: When `.adlc/init-options.json` or `team_ai_directives` is missing, `team-boot` Step 1 now outputs the `/team-setup` guidance and exits the bootstrap early — skipping Steps 2-5. Step 4 (Run Discovery) is now guarded on configuration so `team-discover` is never invoked when team AI directives are unconfigured (previously it ran and returned empty results, producing a confusing trace). `team-discover` mirrors the handover: empty CDR results + `/team-setup` note, while still surfacing project PDR/ADR indexes (Step 3b) which are independent of team-ai-directives. Removed the stale "Default fallback: `team-ai-directives/`" configuration line from both skills.

## [0.16.4] - 2026-08-01

### Added

- **Deterministic Search Script (`radar-search.py`)**: Added `skills/tech-radar/tech-radar-context/scripts/radar-search.py` for alias normalization (`k8s`→`Kubernetes`, `postgres`→`PostgreSQL`, `gh actions`→`GitHub Actions`, etc.), relevance-scored matching, and structured Markdown/JSON table output.
- **Data Quality Fixes**: Corrected corrupted description blocks in `radar.json` for `Chaos Toolkit`, `k6`, `kube-score`, and `Swarm`.
- **Unit Testing**: Added `tests/unit/test_tech_radar.py` validating dataset integrity, `<p>Why?</p>` extraction, fixed description accuracy, and `radar-search.py` CLI output.

## [0.16.3] - 2026-08-01

### Fixed

- **Current Working Directory Strictness for `team-boot` & `team-discover`**: Restricted `.adlc/init-options.json` lookup in `team-boot` and `team-discover` to the current working directory, removing the 4-level parent walk-up. Setup scripts now resolve `PROJECT_ROOT` starting from `pwd`.

## [0.16.2] - 2026-08-01

### Fixed

- **PromptFoo GitHub Models API Base URL (`evals/promptfoo/config.js`)**: Updated `apiBaseUrl` for GitHub Models in CI from `https://models.inference.ai.azure.com` to `https://models.inference.ai.azure.com/v1`. Appending `/chat/completions` without the `/v1` prefix resulted in `HTTP 404 Not Found` errors during promptfoo evaluation runs.

## [0.16.1] - 2026-08-01

### Fixed

- **`team-boot` & `team-discover` Unconfigured Guidance**: Updated failure handling in `team-boot` and `team-discover` to explicitly instruct the user to run `/team-setup` when `.adlc/init-options.json` or `team_ai_directives` is unconfigured.

## [0.16.0] - 2026-08-01

### Added

- **Tikal Tech Radar Skill (`tech-radar-context`)**: New model-invoked skill (alias `trc`/`ttr`) that discovers candidate technologies from prompt context, queries Tikal's Israeli Tech Radar dataset (`radar.json`), parses Tikal's opinion from the `<p>Why?</p>` blip block, and injects a Tech Radar Context table (`Keep`/`Start`/`Try`/`Stop` rings) plus Tikal-aligned alternatives for `Stop` items.
- **Tikal Tech Radar Dataset Snapshot**: Bundled full 424-blip radar dataset at `skills/tech-radar/tech-radar-context/resources/radar.json`.
- **Project Directive Injection**: Updated `AGENTS.md` and `skills/team/team-helpers.{sh,ps1}` so `team-setup` and `team-repair` auto-inject Tech Radar Guidance into project instructions.

## [0.15.0] - 2026-07-27

### Added

- **Universal Skill Orchestration in `mission-brief`**: `mission-brief` now performs a vendor-agnostic local skills inventory during Phase 4a discovery. It scans all skills directories, reads each `SKILL.md` frontmatter, and builds a `discovered.local_skills` array (name + path + description). This inventory is injected into every subagent's delegation prompt, letting the LLM decide which installed skill fits the current pipeline step — no hard-coded phase-to-skill mapping. Works with skills from any source: mattpocock/skills, addy osmani/agent-skills, superpowers, custom team skills, or any Agent-Skills-standard repo.
- **README: Universal Skill Orchestration section (#7)**: New narrative section highlighting zero-lock-in orchestration, the discovery→routing→fallback flow, and a compatibility table of community skill sources.
- **E2E tests for universal skill orchestration**: 7 new pytest tests in `tests/e2e/test_universal_skill_orchestration.py` covering local skills inventory discovery, empty fallback, missing frontmatter, vendor-agnostic multi-dir scanning, delegation prompt wiring, and `.mission-state.json` shape.
- **EVAL-005: Universal Skill Orchestration eval criterion**: New goldset criterion + grader (`check_universal_skill_routing.py`) verifying the delegation prompt includes an "Available Skills" section, instructs subagent to invoke matching skills, and rejects hard-coded phase-to-skill mappings. Includes pass + fail goldset cases.
- **Grader unit tests**: New `evals/promptfoo/tests/test_check_universal_skill_routing.py` with 6 test cases (3 pass, 3 fail) verifying grader correctness — fills the `evals-implement` Phase 2 gap (no grader unit tests existed before).
- **CI: evals grader tests now collected**: Updated `test.yml` to run `pytest tests/ evals/promptfoo/tests/ -v`.

## [0.14.4] - 2026-07-26

### Fixed

- **README: Add #3 "Agent Behavior Can't Be Verified" section for Evals skills**: The evals skills (`evals-*`) had no narrative `#N` section explaining their need (unlike team, levelup, product, architect, mission). Added a new `#3` section with the Factor VII/VIII/XII mapping, problem statement, and 6-skill overview. Renumbered the subsequent sections (#3→#4 Product, #4→#5 Architecture, #5→#6 End-to-End).
- **README: 12-Factor Alignment table under-mapped Evals skills**: Factors VII, VIII, and XII listed only `LevelUp skills` or `team-repair` but omitted the `Evals` skills, which are the primary implementation of Factor VII (verification) and the ratchet mechanism (VIII). Updated three rows to include `Evals skills` / `evals-analyze` with expanded descriptions.

## [0.14.3] - 2026-07-26

### Fixed

- **EVAL-004 grader and instruction**: Made the EVAL-004 instruction in `config.js` explicit ("Emit EXACTLY this text: `skill({name: \"team-boot\"})`") and extended the grader to also accept the bare word `team-boot` as a valid pass (testing intent, not exact syntax). The rationalization check still runs, so `team-boot` + a skip rationalization → FAIL. Resolves a false-fail where gpt-4o-mini emitted the bare skill name instead of full tool-call syntax.

## [0.14.2] - 2026-07-26

### Added

- **EVAL-004: team-boot first-tool-call gate regression test**: New goldset criterion and Python grader (`check_team_boot_first_call.py`) that asserts the agent's first tool call in a session is `skill({name: "team-boot"})` and fails on rationalization patterns (plan-mode conflict, efficiency, task-matters). Catches the failure mode where an agent in plan mode skips `team-boot` by fabricating a plan-mode/skill conflict.

### Fixed

- **team-boot directive strengthening**: Added First-Tool-Call Gate and Plan-Mode Compatibility bullets to the `AGENTS.md` managed section, plus three anti-pattern rows covering rationalizations observed in a real session trace (plan-mode conflict, efficiency, task-matters-more-than-check). Updated `team-boot/SKILL.md` with matching rationalization rows and red flags. Propagated to `team-helpers.sh`/`team-helpers.ps1` heredocs (source of truth) so `team-repair` picks up the stronger directive on any project.

## [0.14.1] - 2026-07-25

### Fixed

- **Skills Directory Flattening**: Removed 3-pillar folders (`capability`, `governance`, `workflow`) and flattened family subfolders directly under `skills/` (e.g., `skills/team/`, `skills/evals/`, `skills/architect/`, `skills/levelup/`, `skills/product/`, `skills/mission-brief/`). This places every single skill exactly 2 levels deep, fully resolving the default depth limit of the `skills` CLI and ensuring all skills install out of the box without requiring the `--full-depth` flag.
- **Path and test references**: Updated all internal and template path references in `evals-specify`, `evals-init`, `team-repair`, and `tests/` to align with the new 2-level structure. All 33 unit and integration tests pass perfectly.

## [0.14.0] - 2026-07-25

### Added

- **Automated Eval Engineering Synthesis & Calibration**:
  - Implemented **Trace-to-Grader Synthesis** in `evals-implement` to automatically compile highly specialized, isolated LLM-judge rubrics and regex checks directly from goldset evidence fields (such as pass/fail anchor cases, root-cause analyses, and axial-coding observations), eliminating manual evaluator writing.
  - Implemented **Closed-Loop Grader Self-Tuning** in `evals-implement` to automatically run generated unit tests against the training goldset, parse failure cases, and tune the grader's prompts/regex patterns up to a hard **3-iteration cap** to achieve 100% calibration before validation.
  - Added strict **Holdout Locked Safeguards** to prevent validation/holdout dataset leakage into the self-tuning calibration loop.
  - Added explicit **Failure Escalation** so any non-converged grader is surfaced as an error rather than silently succeeding.
  - Added `grader_tuning` parameters to `evals-config-template.yml` for configurable calibration bounds.
  - Added `synthesis_inputs` and `synthesis_tuning` metadata schemas to `eval-criterion-template.md` and `goldset-record-template.md`.

## [0.13.0] - 2026-07-24

### Changed

- **Skill family nesting**: Grouped individual skills into family directories under each pillar to keep the top-level pillar folders clean. `skills/workflow/architect-*` → `skills/workflow/architect/`, `skills/workflow/product-*` (+ `product-templates/`) → `skills/workflow/product/`, `skills/workflow/levelup-*` (+ `levelup-helpers.*`) → `skills/workflow/levelup/`, and `skills/governance/evals-*` (+ `evals-templates/`) → `skills/governance/evals/`. `mission-brief` remains flat as the core orchestrator.
- **Team Capability pillar rename**: Renamed the top-level `skills/team/` pillar to `skills/capability/` (the "Team Capability" pillar from the 12-factor speaker notes), with the skill family nested as `skills/capability/team/`. This eliminates the redundant `team/team/` nesting while keeping naming parity with the other full-word pillars (`strategy`, `workflow`, `governance`).
- **Path references updated**: `team-repair` levelup-helpers reference, `evals-init`/`evals-specify` template references, and `tests/unit/test_playbook_integrity.py` template globs all updated to the new nested paths.

### Notes

- **Install path unaffected**: `npx skills add tikalk/adlc-team-skills` recursively discovers `**/SKILL.md`, so nested families install identically. No `.skills.json` or manifest changes required.
- **Tests**: recursive `**/setup-*.sh` and `**/SKILL.md` globs auto-discover the relocated skills; all 33 tests pass unchanged.

## [0.12.4] - 2026-07-24

### Fixed

- **PromptFoo grader function contract**: Renamed the grader entrypoint from `evaluate(output, context)` to `get_assert(output, context)` across all 7 python graders in `evals/promptfoo/graders/`. PromptFoo's python assertion runner invokes `get_assert` by convention; the old name raised `AttributeError: module has no attribute 'get_assert'`.
- **Eval prompt contract**: Rewrote the evaluation prompt in `evals/promptfoo/config.js` so the model role-plays as the ADLC agent harness and emits the *literal compliance output* (matching what the graders check), instead of producing free-form analysis prose. Added a per-test `instruction` variable defining the exact output contract for each scenario, resolving the 100% false-fail rate.

## [0.12.3] - 2026-07-24

### Fixed

- **PromptFoo Custom Python Grader File Parsing**: Fixed a critical configuration bug in `evals/promptfoo/config.js` where custom python grader scripts were passed as raw paths rather than using the required `file://` loader prefix. Adding `file://` prevents PromptFoo from trying to parse the file path as an inline python expression, eliminating syntax errors and enabling full execution of the evaluation suite.

## [0.12.2] - 2026-07-24

### Changed

- **GitHub Models integration for CI evaluations**: Switched PromptFoo configuration `config.js` to point to the OpenAI-compatible GitHub Models inference endpoint in CI environments (when `GITHUB_TOKEN` is present). Keeps local development backward-compatible: standard `OPENAI_API_KEY` works seamlessly locally.
- **Workflow authentication hardening**: Updated the `.github/workflows/test.yml` pipeline to authenticate PromptFoo evaluations using the automatic, built-in `GITHUB_TOKEN` secret. This guarantees **zero-credential setup** for forks and Pull Requests — the CI evaluation loop now runs successfully out of the box on every repository clone without failing on missing OpenAI keys.

## [0.12.1] - 2026-07-24

### Added

- **Advanced Skill Testing Upgrades**: Borrowed high-performance testing concepts from `agentic-sdlc-spec-kit` to significantly harden the repository's verification suite:
  - **Environment Isolation (Clean Room)**: Added an autouse fixture in `tests/conftest.py` that strips any inherited `TEAM_AI_DIRECTIVES` variables from the test environment, guaranteeing 100% deterministic local/CI test runs.
  - **Cross-Platform Bash Probing**: Added robust bash-detection and WSL-skipping logic to `tests/conftest.py` with a custom `@pytest.mark.requires_bash` register, dynamically bypassing shell scripts on systems lacking native MSYS/MINGW Bash to prevent path translation crashes.
  - **Playbook & Manifest Static Integrity Validation**: Created `tests/unit/test_playbook_integrity.py` to statically parse every single skill playbook (`SKILL.md`), verifying valid YAML frontmatter, strict directory name/skill name parity, template structure correctness, and config template key parity.
- **Automated Workflow Tests**: `test_setup_scripts.py` now supports multiline JSON outputs and legacy `KEY=VALUE` diagnostic lines, and handles expected precondition failures gracefully.

### Fixed

- **`setup-product-init.sh` top-level variable declaration**: Fixed bash syntax error on line 103 where a `local` variable declaration was used at the script's top-level (replaced with standard `id` variable).
- **`setup-product-clarify.sh` pip-fail robustness**: Fixed command substitution pipe bug where `set -o pipefail` caused the script to exit with code `2` on empty directories due to empty grep results. Added a guard check on `PDR_COUNT > 0` to prevent the crash and keep it 100% robust.

## [0.12.0] - 2026-07-24

### Added

- **Confidence-Based Escalation (C1)** in `mission-brief`: Subagents now estimate their confidence (HIGH/MEDIUM/LOW) in the correctness of their work and report unresolved details. If confidence is `LOW` and active supervision is `autonomous` or `hybrid`, the orchestrator overrides the supervision level to `gated` review (SYNC mode) — halting execution and prompting for human confirmation.
- **Non-Goals Enforcement (C2)** in `mission-brief`: Added a `Non-Goals` section to the Mission Brief template. Inferred boundaries are defined upfront, passed to every subagent's prompt context, and explicitly verified by the converge step as an independent grader. Violations report CONTINUE with the non-goals violation details.
- **Eval CDR type**: New `Eval` context type for CDRs, paired with any directive type (rule, persona, example, constitution). Eval CDRs contain self-contained binary pass/fail cases extracted from session evidence (levelup-specify) or codebase patterns (levelup-init). Each case includes scenario, input context, agent output, and why it passes/fails — no external trace file dependency.
- **`levelup-specify`**: Now extracts paired eval CDRs alongside directive CDRs from the current session. Pass cases = moments the agent followed the pattern; fail cases = moments the agent violated it.
- **`levelup-init`**: Now extracts paired eval CDRs from codebase patterns. Pass cases = code examples demonstrating the pattern; fail cases = inconsistent implementations from cross-sub-system analysis.
- **`levelup-clarify`**: New evals regression gate (Phase 2a, default ON). Runs existing goldensets from `team-ai-directives/evals/` via LLM calls before accepting CDRs. If accepting a CDR would break existing eval cases → marks as `Blocked (Evals)`. Use `--no-evals-gate` to disable.
- **`levelup-publish`**: New Phase 6 (Eval Goldenset Generation). For eval-type CDRs, writes `evals/{directive-id}/goldset.md` (human-readable) and `goldset.json` (machine-readable) to team-ai-directives. Goldensets are self-contained with inline evidence.
- **`team-repair`**: New `--build-to-delete` mode (Phase 10). Reads all goldensets from `team-ai-directives/evals/`, temporarily removes paired directives, runs goldenset cases against the agent via LLM calls. If model passes 100% without the directive → creates deletion CDR (Harness Decay). Produces a report classifying directives as Delete candidates (100%), Review candidates (80-99%), or Keep (<80%). Implements Factor XII (Build to Delete).
- **12-Factor alignment**: README now documents Factors VII (Verification-First Evals), VIII (Ratchet Effect), and XII (Build to Delete) in the alignment table.

### Removed

- **`levelup-trace` skill**: Removed entirely (directory, scripts, SKILL.md). The skill generated a session trace file (`.adlc/drafts/trace.md`) for levelup-specify to consume. Since levelup-specify now reviews the current session directly (the agent observes what it did), the trace file is unnecessary. Eval CDRs are built from session memory, not from trace files.
- **Trace publication from `levelup-publish`**: Phase 6 (Session Trace Publication) removed. Traces are no longer copied to `team-ai-directives/traces/`. The goldenset is self-contained — it carries extracted evidence inline. `--skip-trace` flag removed.
- **`traces/` directory from team-ai-directives output layout**: No longer populated. Replaced by `evals/` directory for directive compliance goldensets.

### Changed

- **`levelup-specify`**: No longer depends on a trace file. Reviews the current session directly. Description and workflow updated. Setup scripts no longer output `TRACE_FILE`.
- **`levelup-publish`**: Setup scripts no longer output `TRACE_FILE` or `TRACE_EXISTS`. Outline updated: Phase 6 is now Eval Goldenset Generation (was Session Trace Publication). Summary table includes Evals instead of Traces.
- **`team-helpers.sh` / `team-helpers.ps1`**: AGENTS.md template updated — `traces/` directory listing replaced with `evals/` (directive compliance goldensets).
- **README.md**: LevelUp workflow diagrams updated (removed levelup-trace step). Skill listings updated. Output file layout updated. 12-Factor alignment table updated.

### Breaking Changes

- **`levelup-trace` removed**: Any automation or scripts referencing `/levelup-trace` will fail. The CDR lifecycle is now: `levelup-specify → levelup-clarify → levelup-publish → team-repair`.
- **`--skip-trace` flag removed from `levelup-publish`**: Scripts passing this flag will get an unknown-flag warning.
- **`traces/` directory no longer populated in team-ai-directives**: Existing `traces/` directories can be deleted; goldensets are self-contained.

## [0.11.1] - 2026-07-23

### Fixed

- **`team-discover` (plan-mode regression)**: v0.11.0 made every invocation persist `.adlc/drafts/team-context.md`, which broke read-only / plan-mode sessions (the skill would attempt a forbidden file write). Restored a no-write fallback: if `$ARGUMENTS` contains `--no-write` **or** the session is in plan mode / any read-only phase (a system reminder bars file writes), discovery runs inline — the table and `search_metadata` are still produced, only persistence is skipped. Build-mode sessions still persist per prompt (delta-aware). Updated Modes, Step 6, Red Flags, and Verification.
- **`team-boot` (hollow-trigger hardening)**: strengthened Step 5 into an **output contract** — the visible response MUST contain the `team-discover` table and `search_metadata` line before the task response; if either is absent, discovery did not run and must be executed. Addresses a session-trace defect where `team-discover` was invoked but its Core Process never executed (no table produced), yet the agent proceeded. Added a matching Red Flag and updated Verification item 5. Step 4 now notes that plan mode runs discovery inline (no file writes).

## [0.11.0] - 2026-07-23

### Changed

- **`team-boot`**: Step 4 retitled "Run Discovery" — `team-discover` is now invoked on **every prompt** (specify, plan, implement, question, debugging, chat) with no spec/plan gate and no continuation exemption. Reverses the 0.10.0 phase-gated design, where discovery ran only on spec/plan prompts and other prompts referenced the persisted `team-context.md`. A session trace showed follow-up implementation prompts like "fix the help message" skipping discovery entirely (the model treated them as "direct continuation" and skipped `team-boot`, and `team-discover` has no standalone trigger for plain follow-ups). The acknowledgment (Step 5) must now appear in the **visible response**, not only in reasoning. Full bootstrap (constitution + PDR/ADR indexes) still happens once per session; subsequent prompts skip Steps 1–3 but always run Steps 4–5.
- **`team-discover`**: lifecycle switched from generate-then-reference (0.10.0) to **regenerate-per-prompt**. Runs on every user prompt (auto-invoked by `team-boot`) and persists `.adlc/drafts/team-context.md` each run; same-feature repeats are delta-aware, different features reset. Frontmatter description updated to reflect every-prompt invocation. The `phase` metadata field extended to `specify | plan | implement | chat | manual` (informational).

### Fixed

- **`team-discover`**: added an execution-contract red flag — loading this SKILL.md is not discovery; the run is incomplete until the Discovered Team Context table and `search_metadata` exist, and matches must never be fabricated. Addresses a session-trace defect where `team-discover` was invoked but its Core Process was never executed (no index read, no table produced), yet "discovery matches" were reported in reasoning.

## [0.10.0] - 2026-07-23

### Added

- **New skill: `mission-brief`** — mission-driven SDD orchestrator, detached from spec-kit. Takes a feature description, structures it into a Mission Brief (goal, constraints, success criteria), generates an ordered step list with prompts that trigger installed SDD skills via model invocation or command-file discovery, and walks those steps to converged implementation. No YAML workflow files, no per-framework profiles — step prompts use canonical SDD terminology (specify, plan, implement, converge) that works with any installed skill set (addyosmani/agent-skills, mattpocock/skills, superpowers, openspec, agentic-* presets, or custom). Supports 30+ agents via externalized command discovery (`references/agent-integrations.md`). Sync (default, gated inline) / `--async` (forces ungated, checkpoint across sessions via `.adlc/workflow/.mission-state.json`) / `mission-brief --resume` (explicit resume; fresh `mission-brief` asks before clobbering an interrupted state). Keeps supervision modes, do-while converge loop, circuit breaker, converge-independence hint, spec-correction routing (config-gated), per-step model tiers (optional `models: {strong, fast}`), and `iterations.md` + `mission-log.json` audit trail. Replaces the earlier `mission` skill (removed).

### Changed

- **`team-discover`**: persists `.adlc/drafts/team-context.md` on every run (skill, model-triggered, or manual) instead of no-write inline-only for skill invocations. New lifecycle contract: discovery runs only during spec/plan phases; all other prompts reference the persisted file. `team-context.md` carries a metadata header (`feature`/`phase`/`generated`); same-feature re-runs are delta-aware, different-feature re-runs reset. Removed spec-kit hook machinery (`before_specify`/`before_plan`/`before_implement`, `SPECIFY_*` env vars, `specs/` feature dirs) — single canonical location `.adlc/drafts/team-context.md`.
- **`team-boot`**: Step 4 renamed to "Reference or Run Team Context" — the model assesses each prompt: spec/plan/design requests invoke `team-discover` (persist), everything else references the existing `team-context.md`. Full bootstrap (constitution + PDR/ADR indexes) happens once per session; subsequent prompts skip Steps 1–3 but always run Step 4.
- **`team-skills`**: new `--all` mode installs every `default` and `external` skill (skipping `blocked` and already-installed). Dropped the `team-` prefix convention — skills install under their original names with unchanged frontmatter. Fixed stale category table to match schema v2.0.0 (`default`/`external`/`blocked`).
- **`team-setup`**: Post-Setup step 4 offers to install team skills from `.skills.json` via `/team-skills --all` (skip on empty manifest or `auto_install_default: false`). Mode 4 reports installed-vs-missing and offers the same. Mode 3 scaffold `.skills.json` now uses the real schema v2.0.0 shape (`version`/`source`/`description`/`default`/`external`/`blocked`/`policy`). Scrubbed spec-kit references (`specify init`, `update-agent-context.sh`, `agent-context` extension).

### Security

- **`team-setup` (Mode 2)**: fixed command-injection vulnerability — `team_ai_directive` path is now passed to Python via the environment (`os.environ`), not interpolated into Python source. Added an Input Validation section covering all modes: paths, team names, and clone URLs are validated before interpolation into shell commands.
- **`team-setup` (Mode 1)**: clone URLs must use `https://`; `file://`/`ssh://`/other schemes are rejected unless explicitly confirmed.
- **`team-setup` (all modes)**: user-supplied paths and team names are validated for shell metacharacters before use in `mkdir`/`git clone`/`git commit`/heredocs.

### Fixed

- Scrubbed spec-kit operational references from `team-skills`, `team-repair`, `team-helpers.sh`/`.ps1`, and `architect-implement` (`specify init` → `/team-setup`; `before_plan` hook mention removed). Explanatory spec-kit comparisons in `team-constitution`, `levelup-*`, and `workflow/mission-brief` left intact.

### Changed (MADR Alignment)

- **Architect ADRs aligned to [MADR 3.0.0](https://adr.github.io/madr/)**: `adr-template.md` rewritten across all 5 architect skills (specify/init/clarify/implement/analyze). Added YAML frontmatter (status, date, decision-makers, consulted, informed, sub-system, superseded-by — MADR-0013); H1 title (no numbers in headings — MADR-0002); explicit Considered Options list; Decision Outcome + Consequences (Good/Bad/Neutral, MADR v3.0.0 merged) + Confirmation; Pros and Cons of the Options with per-option Good/Bad/Neutral arguments (MADR-0014); More Information; links between ADRs (MADR-0009); asterisk list markers (MADR-0011); `rejected` status (MADR-0008).
- **Project extensions retained**: `sub-system` frontmatter field (MADR-0010 categories equivalent); `discovered` status (brownfield reverse-engineering via `/architect-init`); Constitution Alignment + Related ADRs sections.
- **Filename convention**: `ADR-{NNN}.md` kept (MADR-0005 explicitly permits other patterns); stable numeric ID used by `adr.md` index, supersession refs, and architect skills.
- **`setup-architect.sh`** (all 5 copies): `generate_adr_index` now parses MADR frontmatter + H1 title via new `parse_fm_field`/`parse_fm_title` helpers instead of prose `### Status`/`### Date`/`### Owner`/`### Sub-System` sections. Index column renamed `Owner` → `Decision Makers` (populated from `decision-makers` frontmatter). Sub-system extraction in view generation also reads frontmatter.
- **`setup-architect.ps1`** (all 5 copies): fixed stale monolith `adr.md` path assumptions — ADR count now uses `Get-ChildItem -Filter "ADR-*.md"` (was `Get-Content $adrDir -Raw` on a directory + `^## ADR-` regex that no longer matches the H1 title format). Sub-system extraction reads the generated `adr.md` index file.
- **`architect-specify/SKILL.md` + `architect-init/SKILL.md`**: ADR Format examples updated to MADR frontmatter + sections.

## [0.9.1] - 2026-07-22

### Changed

- **Moved `product-*` and `architect-*` skills** from `skills/team/` to `skills/workflow/` — product and architecture skills now live in their own top-level directory parallel to `team/`. Skill names, frontmatter, and command references unchanged. Re-install required: `npx skills add tikalk/adlc-team-skills`.
- **README.md** rewritten to mattpocock/skills style: problem-first quickstart, 12-factor-oriented rationale sections, reference with user-invoked/model-invoked split, collapsible details for output layout, OKF compliance, workflows, and 12-factor alignment.
- **`team-boot`** no longer falls back to `.adlc/drafts/` for PDR/ADR indexes — accepted (memory) decisions only. PDR: memory → legacy PRD.md heading skim → none. ADR: memory → none.

## [0.9.0] - 2026-07-22

### Added

- **New skill: `team-constitution`** — interactively create or amend the team constitution in team-ai-directives. Detects the scaffold placeholder ("No team-wide principles defined yet") for create mode, or reviews existing principles in amend mode. Ports the interactive elicitation flow from spec-kit's `spec.constitution` without the SDD machinery (no hooks, no template tokens, no template propagation). Output uses the established team format: OKF frontmatter + numbered principles + lightweight Governance section; versioning is git history, not semantic version stamps.
- **PDR/ADR index loading in `team-boot`**: new Step 3 (Load Product & Architecture Context) reads `.adlc/memory/pdr/pdr.md` and `.adlc/memory/adr/adr.md` (drafts fallback) for awareness-level product/architecture context. Legacy fallback: heading-level skim of monolithic `PRD.md` when no PDR index exists. Full PRD/AD bodies and individual PDR/ADR records are never loaded during boot.
- **PDR/ADR matching in `team-discover`**: new Step 3b (Load Project Decision Indexes) matches project PDRs and ADRs against the feature context alongside team CDR matching. Output table gains `Type: PDR` / `Type: ADR` rows; High-relevance records load inline bodies; `search_metadata` reports per-source counts.
- Setup scripts for `team-constitution` (bash + PowerShell) outputting `CONSTITUTION_STATE` (`missing`|`placeholder`|`populated`), `TD_IS_GIT`, `TD_CLEAN`.
- **Four-layer milestone model** in `product-roadmap`: tracks Decision (PDR status) + Execution (live issue states via MCP) + Evidence (code-vs-PDR verification) + Gates (milestone acceptance criteria). A milestone is "live" only when all four layers are green.
- **Issue-driven progress**: PDRs can carry `### Issues` sections with full URLs. Roadmap queries live issue states via MCP tools (GitHub / GitLab / Jira / Linear) with CLI fallback and graceful degradation. Optional `### Tracker Milestone` link pulls native tracker progress directly.
- **Code-vs-PDR verification** (init concept): PDRs can carry `### Evidence` sections with code paths/symbols. Roadmap verifies paths exist (Mode A: explicit). Fallback to heuristic directory detection (Mode B: init-style). Missing evidence on "Completed" items triggers done-means warnings with hand-off suggestion to `/product.init`.
- **Gate model**: Milestone PDRs can declare `### Gates` tables (type: engineering/sign-off/time, owner, criterion, status, evidence). Roadmap rolls up gate states; `--update` blocks milestone completion when gates are pending.
- **Done-means warnings**: Milestone PDRs carry a `### Done Means` field defining what "live" means explicitly. Roadmap warns when layers disagree with the claimed completion state.
- PDR template updated: `### Issues`, `### Evidence`, `### Gates`, `### Done Means`, `### Tracker Milestone` fields added to `pdr-file-template.md`.
- `product-implement` PRD §11 gains `### 11.2 Milestone Gates & Progress` subsection.

### Changed

- `team-boot`: steps renumbered (Run Discovery → Step 4, Acknowledge → Step 5); acknowledgment now reports index entry counts; description, verification, and red flags updated for decision-record loading.
- `team-discover`: description, output table docs, and verification updated for PDR/ADR matching.
- `team-setup` Mode 3: scaffold follow-up now directs the user to run `/team-constitution` to fill the placeholder constitution; file table notes the placeholder's purpose.
- `team-helpers.sh` / `.ps1`: team AI directives AGENTS.md templates (scaffold + agents-only) now list the `traces/` directory.
- README: Team Directives table (5 → 6 skills), `team-boot`/`team-discover` row updates, skill count fix (22 skills), Output section gains memory-scope PDR/ADR index entries.
- `product-roadmap` description updated to reflect four-layer tracking model.
- `product-roadmap` `--update` semantics: blocks on pending issues, missing evidence, or pending gates unless explicit override.
- Backward compatible: PDRs without gates/issues/evidence work as before (reported with hints to adopt the new fields).

### Fixed

- CHANGELOG duplicate `## [0.8.0]` section — the Product skills entry is now correctly numbered `## [0.8.1]`.

## [0.8.1] - 2026-07-22

### Added

- `levelup-publish` now publishes the session trace to the team AI directives alongside context modules and skills. The trace is copied from `.adlc/drafts/trace.md` to `traces/{BRANCH}.md` in the team AI directives, following the `spec.trace` branch-based naming convention.
- `--skip-trace` flag on `levelup-publish` to opt out of trace publication (useful for the brownfield `levelup-init` path where no implementation session exists).
- If no trace exists when `levelup-publish` runs, it invokes `/levelup-trace` to generate one before publishing.
- New Phase 6 (Session Trace Publication) in `levelup-publish` — phases renumbered (6→7→8→9→10→11).
- `traces/` directory in the team AI directives output.
- `TRACE_FILE` and `TRACE_EXISTS` fields in `setup-levelup-publish.sh` / `.ps1` JSON output.

### Changed

- `levelup-publish` description updated to mention session trace publication.
- `levelup-publish` commit message template now includes the trace path.
- `levelup-publish` summary report includes a Traces row in the Artifacts Created table.
- `levelup-publish` verification checklist includes trace publication check.
- README LevelUp skills table and team AI directives output section updated to reflect trace publication.

## [0.8.0] - 2026-07-22

### Added

- **6 new Product skills** under `skills/workflow/product-*`: `product-init`, `product-specify`, `product-clarify`, `product-implement`, `product-analyze`, `product-roadmap`. Ported from `agentic-sdlc-spec-kit/extensions/product/` with all spec-kit dependencies removed.
- **PDR individual-file format**: PDRs are now stored as individual `PDR-{NNN}.md` files in `.adlc/drafts/pdr/` (mirroring architect ADR and levelup CDR patterns), with an auto-generated `pdr.md` index. Accepted PDRs are promoted to `.adlc/memory/pdr/` on implement.
- Product templates: `pdr-file-template.md`, `prd-template.md`, 15 section templates, 3 subagent prompt templates — all under `skills/workflow/product-templates/` and `skills/workflow/product-implement/templates/`.
- Validation scripts: `validate-pdr.sh` and `validate-prd.sh` under `product-implement/scripts/bash/`.
- README: new Product / PDR Lifecycle section, updated 12-Factor table (Factor III added), updated Output section with PDR/PRD paths, full lifecycle diagram.

### Changed

- **Moved `architect-*` skills** from `skills/architect/` to `skills/team/` — all guardrails and directive lifecycles now live in one group. Skill names unchanged; no user action required.
- `product-implement` PDR lifecycle: Accepted PDRs are **moved** from `.adlc/drafts/pdr/` to `.adlc/memory/pdr/` (was: copied to monolithic `.specify/memory/pdr.md`).
- `product-roadmap`: milestone tracking derived from PDR status fields only (feature-spec reading from `specs/*/` removed).

### Removed

- `product-validate` (feature-spec validation against PRD) — purpose disappears when stripping feature-spec reading; PDR↔PRD consistency covered by `product-analyze`.
- `product-link` (PDR linker for spec-kit hooks) — existed only to feed the `before_specify` hook.
- `extension.yml` — spec-kit extension manifest; not needed in Agent Skills format.
- All `.specify/` paths → `.adlc/`, all `/spec.specify` references removed, all hook references removed.

## [0.7.0] - 2026-07-22

### Added

- **OKF compliance**: Generated context modules now include OKF v0.1 fields (`resource`, `tags`, `timestamp`) alongside custom fields in YAML frontmatter.
- `team-repair` now generates OKF-compliant `index.md` (progressive disclosure) and `log.md` (chronological change history) per context module directory (`rules/`, `personas/`, `examples/`).
- `team-setup` scaffold now includes OKF `index.md` files for each context module directory (14 files instead of 10).
- `team-helpers.sh` and `team-helpers.ps1` scaffold templates updated with OKF frontmatter and index.md files.
- OKF compliance section in README.

### Changed

- `levelup-publish` frontmatter template now generates OKF fields: `resource` (relative path), `tags` (context type), `timestamp` (ISO 8601 datetime).
- `team-repair` output section updated to include index.md/log.md generation (was 9 phases, now 10).
- `team-repair` summary report includes OKF index/log generation counts.
- `team-repair` repair targets table includes OKF index.md and log.md targets.
- `team-repair` freshness phase now updates `timestamp` field alongside `verified`.
- Scaffold file count: 10 → 14 (4 new index.md files).

## [0.6.0] - 2026-07-21

### Added

- New skill: `levelup-trace` — generates a session execution trace from the current agent session (not from spec-kit artifacts). Captures what the agent did, decisions made, files changed, and reusable patterns. Output: `.adlc/drafts/trace.md`.

### Changed

- **Renamed** `levelup-implement` → `levelup-publish` to clarify its purpose (publishing CDRs to the team AI directives, not implementing features).
- **Decoupled `levelup-specify` from spec-kit**: primary source is now the session trace (from `levelup-trace`) or direct session review. Removed all spec-kit artifact reading (`spec.md`, `plan.md`, `tasks.md`, `specs/` directory search). No spec-kit dependency.
- `levelup-specify` setup scripts no longer search for feature directories or spec-kit artifacts.
- `levelup-specify` setup scripts now output `TRACE_FILE` path (`.adlc/drafts/trace.md`).
- CDR lifecycle updated: `levelup-trace → levelup-specify → levelup-clarify → levelup-publish`.
- README updated: 5 LevelUp skills (was 4), session-based workflow, renamed references.

### Removed

- `levelup-specify` no longer reads `specs/{feature}/spec.md`, `plan.md`, `tasks.md`, or `tasks_meta.json`.
- `levelup-specify` setup scripts no longer detect feature directories or search `specs/` subdirectories.
- `--feature NAME` flag removed from `levelup-specify` (no longer needed — session-based, not feature-artifact-based).

## [0.5.1] - 2026-07-21

### Changed

- Default team-ai-directive path changed from `.adlc/team-ai-directives` to `team-ai-directives` (repo root) across all scripts, helpers, and SKILL.md files.
- `team-setup` Mode 1 clone default destination: `./.adlc/team-ai-directives` → `./team-ai-directives`.
- `team-setup` Mode 3 scaffold default: "current directory" → `./team-ai-directives`.

### Added

- `levelup-specify` Phase 6 Summary now includes a prominent **Handover** section with handoff JSON context, directing the agent to run `/levelup-clarify` next.

## [0.5.0] - 2026-07-21

### Fixed

- **Critical**: All 4 levelup setup scripts (`setup-levelup-{specify,clarify,implement,init}.sh`) are now self-contained — no dependency on the missing `levelup-helpers.sh`. Inline path resolution, CDR numbering, and grep logic.
- **Critical**: CDR format changed from two-line fields (`### Status\n**Accepted**`) to single-line (`### Status: **Accepted**`). All grep patterns updated to match.
- **Critical**: Fixed `regenerate_cdr_index` in `levelup-helpers.sh` to extract fields from single-line format; added `|| true` to prevent `set -e` exit on missing optional fields.
- `team-setup` Mode 3 now runs `git init` + initial commit, enabling `/levelup-implement` branch/commit/PR flow.
- `levelup-helpers.sh` team-helpers path now tries multiple candidate paths (source repo + installed flat layout).
- Fixed `set -euo pipefail` crash when no CDR files exist (ls/grep return non-zero on no matches).
- Fixed wrong script paths in SKILL.md files (`skills/levelup/...` → `scripts/bash/...` relative to skill base dir).

### Changed

- Standardized all parameter naming to `TEAM_AI_DIRECTIVE` (env var), `team_ai_directive` (JSON field), `$TeamAiDirective` (PowerShell variable), `resolve_team_ai_directive` (bash function). Removed `ADLC_` prefix, made singular. 0 old-pattern refs remain.
- Replaced `levelup-helpers.sh --index` references in SKILL.md with inline index generation instructions.
- Replaced `levelup-helpers.sh --signal-gate` reference with inline 4-criteria semantic evaluation.
- `levelup-implement` Phase 9: added git decision tree (Case A: git repo with remote/`gh`/no-remote fallbacks; Case B: not git repo with `git init` or write-only options).
- `levelup-clarify`: added option D ("Accept all remaining") for bulk accept.
- `levelup-specify`: feature detection now searches `{REPO_ROOT}/specs/` and `{REPO_ROOT}/*/specs/` for monorepo layouts.
- Removed unused `{tags}` from `levelup-implement` frontmatter template.
- All PowerShell variables standardized to PascalCase convention.

### Added

- PowerShell setup scripts for all 4 levelup skills (`setup-levelup-{specify,clarify,implement,init}.ps1`).
- Rewritten `team-repair` and `team-skills` PowerShell setup scripts with `TEAM_AI_DIRECTIVE` env var support.
- "12-Factor Alignment" section in README: Factor XI (Directives as Code), Factor XII (Team Capability), Factor IV, IX, X.
- Setup script fallback instructions in all 4 levelup SKILL.md files.
- `git init` verification checkbox and red flag in `team-setup` SKILL.md.
- `TD_IS_GIT` field in `setup-levelup-implement.sh` output.

### Removed

- All `hermes-project` references replaced with generic monorepo language.
- `levelup-helpers.sh` / `team-helpers.sh` dependency removed from all 4 levelup setup scripts.

## [0.4.1] - 2026-07-21

### Changed

- README reorganized: team skills now appear first (Team Directives → LevelUp → Architecture) across intro, Available Skills, Output, and former Usage/Workflows sections.
- Workflow blocks attached under each skill group; standalone `### Workflows` section removed.
- Added "Say" trigger column to each skills table; standalone `### Usage` section removed.
- Removed `## Scripts & Templates` section.

## [0.4.0] - 2026-07-21

### Added

- Four new LevelUp skills under `skills/team/` aligned with the architect-* workflow:
  - `levelup-init` — brownfield CDR discovery from codebase.
  - `levelup-specify` — greenfield CDR extraction from feature implementation context.
  - `levelup-clarify` — interactive review/accept/reject/defer of CDRs.
  - `levelup-implement` — compile accepted CDRs into team-ai-directives artifacts and create a draft PR.
- Shared `levelup-helpers.sh` / `levelup-helpers.ps1` under `skills/team/` — CDR numbering, index generation, signal gate, and rule-conflict scanning.
- CDRs stored as individual files `.adlc/drafts/cdr/CDR-{NNN}.md` with auto-generated `.adlc/drafts/cdr/cdr.md` index.
- `team-repair` conflict scanning and freshness verification (from former `/levelup.validate`).
- `team-repair` flags: `--validate`, `--conflicts`, `--freshness`.

### Changed

- `team-repair` description updated to include conflict scanning and freshness verification.
- `README.md` reorganized with separate LevelUp / CDR Lifecycle section.

## [0.3.0] - 2026-07-20

### Added

- New skill: `team-setup` — interactive team AI directives setup with 4 modes (clone, local path, scaffold, check).
- Shared `team-helpers.sh` / `team-helpers.ps1` — merged path resolution, team AI directives validation, and 11-file scaffold.
- `team-repair` Phase 0: Health Check (7 verification checks) merged from `team-verify`.
- `--health-only` flag on `team-repair`.
- `Configuration` sections documenting `TEAM_AI_DIRECTIVE` env var on all 5 team skills.

### Changed

- `team-skills` → user-invoked (`disable-model-invocation: true`).
- `team-repair` references `team-helpers.sh` instead of `scripts/bash/setup-team.sh`.
- Env var renamed from `SPECIFY_TEAM_DIRECTIVES` → `TEAM_AI_DIRECTIVE`.
- Team skill phases renumbered (Phase 0: Health Check, phases 1-8 for existing repair steps).
- Mode 3 default path changed from `./.adlc/team-ai-directives` to current directory.

### Removed

- `team-curate` — not production ready.
- `team-evolve` — not production ready.
- `team-verify` — merged into `team-repair` as Phase 0.
- `manifest.yml` from scaffold — orphaned metadata from abandoned draft PR #104.

## [0.2.0] - 2026-07-18

### Added

- Seven team-ai-directives skills: `team-boot`, `team-discover`, `team-curate`, `team-evolve`, `team-repair`, `team-skills`, `team-verify`.
- Model-invoked skills (`team-boot`, `team-discover`, `team-skills`) for automatic session bootstrap and context discovery.
- User-invoked skills (`team-curate`, `team-evolve`, `team-repair`, `team-verify`) for CDR lifecycle management.
- Bundled `setup-team.sh` and `setup-team.ps1` scripts in `team-repair` and `team-skills`.
- Unified `{TEAM_DIRECTIVES}` variable naming across all team skills.
- 12-Factor Alignment notes on each skill (Factor XI: Directives as Code, Factor XII: Team Capability).
- Common Rationalizations and Red Flags sections on all team skills.

### Changed

- `.specify/` → `.adlc/` across all team skills and scripts.

## [0.1.0] - 2026-07-17

### Added

- Initial externalization of architect extension capabilities into standalone Agent Skills.
- Five user-invoked architecture skills: `architect-init`, `architect-specify`, `architect-clarify`, `architect-implement`, `architect-analyze`.
- Bundled bash and PowerShell setup scripts and ADR/AD view templates.
- `npx skills add tikalk/adlc-team-skills` installation support.
