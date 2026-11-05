---
name: mission-brief
description: Use when a mission brief must become verified work end to end — brief, then specify, clarify, plan, implement, verify, converge in one lane-carrying DAG with Default plus Speckit, Superpowers, Matt, and Addy lanes.
---

# mission-brief


> **Scope rule**: scripts stay skill-local — never source a script from another skill. For another skill's operations, invoke that skill (e.g. `architect-clarify`, `product-clarify`, `team-boot`) via the Skill tool; for its documents, follow the `Requires` line. `scripts/` and `references/` below are relative to this skill. `{REPO_ROOT}` denotes the project root (where `.adlc/` lives).

**Requires:** the `factory-runbook` skill (provides the publish procedure and run contracts): `adlc-cli skills add tikalk/adlc-team-skills --skill factory-runbook`.

## In a local session — you answer the gates

When `ADLC_RUN_ID` is not set, a person is in this session, and nothing else will answer a gate. The agentic-container runtime that relays gates to Slack exists only in a runner pod.

1. **A paused run is your turn, not the end of the mission.** When `adlc-cli workflow run` or `resume` exits with the run paused at a gate (`run_paused`, `status: paused` in `adlc-cli workflow state show <run_id>`), ask the person the gate's question and options. Then run `adlc-cli workflow resume <run_id> --input <verdict_input>=<answer>` and keep going. Never end your turn on a paused run that nobody was asked about.
2. **Every gate that approves MRs is followed by a step that opens them.** A `gate` whose message promises MRs/PRs is followed by a `publish` step: `run-branch.sh` and `open-mr.sh` for each repository the change touches, writing `mr_url` (`mr_urls` for more than one). Only then comes the write-back step, so the completion comment links real MRs. A gate with nothing after it to act on its answer is a plan defect; fix the plan before you start the run.
3. Before ending your turn, the run is `completed`, `failed` or aborted, or it is paused at a gate the person has been asked about.

## What this skill does

`mission-brief` owns the mission lifecycle end to end as one DAG: it turns the mission's brief into a spec whose acceptance criteria each answer yes or no, into an ordered plan, into tested code, into a converge verdict — judged against the brief, never against the implementer's claims. It works under the shared executor contract (invoke the `factory-runbook` skill; contract at `references/executor.md` in that skill): the `brief` step emits the Mission Brief draft per `references/mission-brief-template.md`; `specify` reads `brief.md` and emits a draft; `clarify` reads `spec.md` and emits a decision; `plan` reads `spec.md` plus the clarify decision and emits `plan.md`; `test` reads `spec.md` and emits an `artifact-ref`; `code` reads that `test` artifact plus `spec.md` and `plan.md`; `verify` reads the `test` and `code` artifacts and emits severity-ranked findings; `converge` reads `brief.md` and emits one verdict of `DONE`, `CONTINUE`, or `SPEC_CORRECTION_NEEDED`. A `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate, never to code.

The lane-carrying sections below keep one pointer per framework lane; the lane prose lives in its own home and is linked, never duplicated here. Lane resolution is a session instruction (Phase 0), never a script or table lookup.

## Lane routing

The single lane table is `references/lane-routing.yml` (data, not prose): the five resolvable lanes (`embedded`, `speckit`, `superpowers`, `matt`, `addy`) and the seven lifecycle steps with their `output_type`/`reads_from` contract. Every resolvable lane has a section below; a lane without a section here can never be resolved.

## Framework lane detection (Phase 0 — session-LLM instruction)

There is no detector script and no precedence table to run. In the brief step, inspect the well-known install paths yourself and disclose what you found in the brief:

1. Inspect the installed skill packs via the Skill tool (distinctive names: `*speckit*`, `*superpowers*`, `*addy*`, `*matt*`, `*pocock*`).
2. Inspect the plugin entries (the agent registry's plugin list — superpowers-style plugin installs live outside the skills dirs).
3. Check `specify` CLI availability (`specify --help` on PATH).
4. Look at repo usage hints (framework-native artifacts: specs dirs, plans dirs, spec-linked issues) — but a hint is never selection evidence on its own.

Resolution: the installed framework wins; usage hints among installed frameworks break ties only. Usage hints with no installed framework disclose and fall back to Default. Write the outcome into the brief exactly as:

`Framework lane: <lane> (<evidence>)`

where `<lane>` is one of `embedded`, `speckit`, `superpowers`, `matt`, `addy`, and `<evidence>` names what was inspected (`installed:<pack>`, `plugin:<entry>`, `specify-cli`, `usage hints <paths>, not installed`, or `default`).

## Default lane (embedded)

Default lane built into this skill.

1. Read the intake: in a factory run the issue ref, otherwise the spec description from arguments. Write the Mission Brief per `references/mission-brief-template.md`: Goal, Constraints, Non-Goals, Success Criteria with a measurement method each, plus the `Framework lane` disclosure.
2. Restate every success criterion as a binary, measurable outcome — each one answers a yes/no question through a command that exits, an artifact that exists, or a diff that shows the change.
3. Write `spec.md`: outcome, constraints, non-goals, acceptance criteria, and out of scope. Each acceptance criterion stays traceable to the success criterion it restates.
4. Surface any criterion that cannot be measured and any constraint that conflicts with another; do not paper over either in prose.
5. Resolve each surfaced item at the clarify phase — ask the person in a gated run, or in autonomous mode record the decision with its basis. The resulting decision is the `clarify` output.
6. List every file to create or modify, each with a one-line purpose. Order the work so each step leaves the tree valid — no step relies on a later step to make it correct or runnable.
7. Name the exact test command that will prove the change, and put the test-first order ahead of the implementation steps.
8. Write `plan.md`: the files table, the test-first order, and the risk notes for anything that could invalidate that order.
9. Write the failing suite first, based on `spec.md`, with `tests/` as the only writable surface and source mounted read-only.
10. Run it — the **RED gate** requires that **at least one test fails** before any implementation exists. A suite that passes immediately means the behavior exists or the assertions are empty: stop and route to the owning clarify gate for spec correction. Record the failing count in the run log.
11. Write the minimum code with source as the only writable surface and `tests/`, `spec.md` and `plan.md` mounted read-only.
12. Run the suite — the **GREEN gate** requires the **full suite passes** before converge. A failure loops back to the code step with the failure list attached; the loop is bounded by the mission's code-step retry cap and does not consume the converge circuit breaker.
13. Skip the split only when the run declares no test surface: `tdd: false`, docs/config-only work, or interactive mode. A code-bearing step in autonomous or supervised mode never skips it.
14. Judge the built work against `brief.md`, not the implementer's claims — re-run the suite, inspect the diff, confirm non-goals untouched.
15. Emit severity-ranked findings: Critical, Important, Minor, each tied to evidence in the diff, suite output, or an untouched non-goal.
16. Return one converge verdict: `DONE` when criteria are met and the quality threshold is reached, `CONTINUE` when in-scope gaps remain, `SPEC_CORRECTION_NEEDED` when a criterion is unmeasurable or scope conflicts. Route `SPEC_CORRECTION_NEEDED` to the owning clarify gate, never to code; return `CONTINUE` to the implementation phase with findings attached. Never approve or merge; approval and merge stay human in the deploy phase.

## Speckit lane

This section translates the shared lifecycle DAG into the speckit framework workflow; speckit keeps its own loop internals and the step contract below remains authoritative. All artifacts are committed directly to the repository under the `specs/` tree, giving developers reviewing the pull request the native speckit audit trail.

- The `specify` step maps to the spec creation preset at `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.specify.md`, run through the `specify` CLI (`specify bundle install adlc-spec-kit`). It reads the brief and writes the `specs/` intake (`spec.md`) scaffolded via `.specify/` templates. Shared contract: `output_type` `draft` with `reads_from` `brief.md`.
- The `clarify` step maps to `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.clarify.md` via the `specify` CLI, resolving open questions and encoding decisions back into `spec.md`. Shared contract: `output_type` `decision` with `reads_from` `spec.md`.
- The `plan` step maps to the plan preset at `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.plan.md` run through the `specify` CLI, generating `specs/` architecture design (`plan.md`) alongside the dependency-ordered task breakdown from `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.tasks.md` into `tasks.md`. It reads `.specify/` templates and the clarified spec. Shared contract: `output_type` `draft` with `reads_from` `spec.md, clarify`.
- The `test` step maps to the TDD tasks command at `github.com/tikalk/adlc-spec-kit-bundle/extensions/adlc-tdd/commands/tasks.md`, which detects language and generates risk-plus-increment tests. It reads `spec.md` and stages the failing suite in `tests/` under the RED gate. Shared contract: `output_type` `artifact-ref` with `reads_from` `spec.md`.
- The `code` step maps to the implementation preset at `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.implement.md`, executed through the RED-GREEN-REFACTOR cycle of `github.com/tikalk/adlc-spec-kit-bundle/extensions/adlc-tdd/commands/implement.md`. It writes code to `src/` until the full suite passes under the GREEN gate. Shared contract: `output_type` `artifact-ref` with `reads_from` `test, spec.md, plan.md`.
- The `verify` step maps to the evaluation-driven verification command at `github.com/tikalk/adlc-spec-kit-bundle/extensions/edd/commands/verify.md`, running deterministic checks and quality assessments against `specs/` and `.specify/` grammar. Shared contract: `output_type` `findings` with `reads_from` `test, code`.
- The `converge` step maps to `github.com/tikalk/adlc-spec-kit-bundle/presets/agentic-sdlc/commands/adlc.spec.converge.md` via the `specify` CLI, judging the built work against `brief.md` and returning the loop verdict (`DONE`, `CONTINUE`, or `SPEC_CORRECTION_NEEDED`). Shared contract: `output_type` `decision` with `reads_from` `brief.md`.

Canonical home: speckit framework integration.

## Superpowers lane

This section translates the shared lifecycle DAG into the superpowers framework workflow across coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini, etc.); superpowers keeps its own inner loop discipline and the step contract below remains authoritative. All design and planning artifacts are stored directly in the repository under `docs/superpowers/` (`specs/` and `plans/`), matching the native superpowers convention.

- The `specify` step maps to the design workflow of `github.com/obra/superpowers/skills/brainstorming`, activated when the superpowers plugin or skill pack is installed (in the coding agent's configuration or at `github.com/obra/superpowers/skills/brainstorming`). It reads `brief.md` and writes the design specification under `docs/superpowers/specs/` (`spec.md`). Shared contract: `output_type` `draft` with `reads_from` `brief.md`.
- The `clarify` step maps to the builder-check validation and targeted clarifying questions of `github.com/obra/superpowers/skills/brainstorming`, resolving requirements and encoding confirmed decisions into `spec.md`. Shared contract: `output_type` `decision` with `reads_from` `spec.md`.
- The `plan` step maps to `github.com/obra/superpowers/skills/writing-plans`, producing an implementation plan with bite-sized tasks under `docs/superpowers/plans/` (`plan.md`). It reads `spec.md` and clarified decisions. Shared contract: `output_type` `draft` with `reads_from` `spec.md, clarify`.
- The `test` step maps to `github.com/obra/superpowers/skills/test-driven-development` (Iron Law: no production code without a failing test first), authoring tests in `tests/` and staging them under the RED gate before code is touched. Shared contract: `output_type` `artifact-ref` with `reads_from` `spec.md`.
- The `code` step maps to `github.com/obra/superpowers/skills/subagent-driven-development` (or `github.com/obra/superpowers/skills/executing-plans`), executing the tasks until the full test suite passes under the GREEN gate. Shared contract: `output_type` `artifact-ref` with `reads_from` `test, spec.md, plan.md`.
- The `verify` step maps to `github.com/obra/superpowers/skills/verification-before-completion` and `github.com/obra/superpowers/skills/requesting-code-review`, gathering fresh execution evidence and code review findings. Shared contract: `output_type` `findings` with `reads_from` `test, code`.
- The `converge` step maps to `github.com/obra/superpowers/skills/finishing-a-development-branch`, judging the built work against `brief.md` and returning the loop verdict (`DONE`, `CONTINUE`, or `SPEC_CORRECTION_NEEDED`). Shared contract: `output_type` `decision` with `reads_from` `brief.md`.

Canonical home: superpowers framework integration.

## Matt lane

This section translates the shared lifecycle DAG into the mattpocock/skills framework workflow across coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini, etc.); matt keeps its modular discipline while the step contract below remains authoritative. Design, task, and review artifacts are stored in linked tracker spec issues and run-local drafts (`spec.md`, `plan.md`).

- The `specify` step maps to the design workflow of `github.com/mattpocock/skills/skills/engineering/to-spec`, activated when the skill pack is installed (in its checkout or installed via the Skill tool). It reads `brief.md` and conversation, publishing a linked tracker spec issue or writing `spec.md`. Shared contract: `output_type` `draft` with `reads_from` `brief.md`.
- The `clarify` step maps to the alignment and boundary analysis of `github.com/mattpocock/skills/skills/engineering/grill-with-docs` (and `grilling`), resolving requirements and domain models into `spec.md`. Shared contract: `output_type` `decision` with `reads_from` `spec.md`.
- The `plan` step maps to `github.com/mattpocock/skills/skills/engineering/to-tickets`, decomposing the spec into tracer-bullet tickets or task plans (`plan.md`). It reads `spec.md` and clarified decisions. Shared contract: `output_type` `draft` with `reads_from` `spec.md, clarify`.
- The `test` step maps to `github.com/mattpocock/skills/skills/engineering/tdd` (red-green-refactor loop), authoring failing tests staged under the RED gate before code is touched. Shared contract: `output_type` `artifact-ref` with `reads_from` `spec.md`.
- The `code` step maps to `github.com/mattpocock/skills/skills/engineering/implement` (and `codebase-design`), implementing deep modules until the full suite passes under the GREEN gate. Shared contract: `output_type` `artifact-ref` with `reads_from` `test, spec.md, plan.md`.
- The `verify` step maps to `github.com/mattpocock/skills/skills/engineering/code-review` (two-axis review: standards and spec fidelity), gathering fresh execution evidence and review findings. Shared contract: `output_type` `findings` with `reads_from` `test, code`.
- The `converge` step maps to `github.com/mattpocock/skills/skills/engineering/pr` gates, judging built work against `brief.md` and returning the loop verdict (`DONE`, `CONTINUE`, or `SPEC_CORRECTION_NEEDED`). Shared contract: `output_type` `decision` with `reads_from` `brief.md`.

Canonical home: matt framework integration.

## Addy lane

This section translates the shared lifecycle DAG into the addyosmani/agent-skills framework workflow across coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini, etc.); addy keeps its own checklist and constraint discipline while the step contract below remains authoritative. Design, task, and quality artifacts are stored under repository constraints files, `tasks/` (`plan.md`, `todo.md`, `spec.md`), and `references/` checklists (`definition-of-done.md`, `testing-patterns.md`, `security-checklist.md`).

- The `specify` step maps to the design workflow of `github.com/addyosmani/agent-skills/skills/spec-driven-development` and `github.com/addyosmani/agent-skills/skills/constraint-driven-development`, activated when the agent-skills pack is installed (in its checkout or installed via the Skill tool). It reads `brief.md` and repo quality standards, writing the specification to `tasks/spec.md` (or `spec.md`) and recording non-negotiables into the repository constraints log. Shared contract: `output_type` `draft` with `reads_from` `brief.md`.
- The `clarify` step maps to the ambiguity and boundary analysis of `github.com/addyosmani/agent-skills/skills/doubt-driven-development` (and `interview-me`), resolving requirements, checking edge cases, and recording confirmed decisions into `spec.md` and quality constraints. Shared contract: `output_type` `decision` with `reads_from` `spec.md`.
- The `plan` step maps to `github.com/addyosmani/agent-skills/skills/planning-and-task-breakdown`, sizing tasks and checking acceptance criteria against `references/definition-of-done.md`, outputting structured task plans to `tasks/plan.md` (or `tasks/todo.md`). It reads `spec.md` and clarified decisions. Shared contract: `output_type` `draft` with `reads_from` `spec.md, clarify`.
- The `test` step maps to `github.com/addyosmani/agent-skills/skills/test-driven-development` (aligned with `references/testing-patterns.md`), authoring tests in `tests/` and staging them under the RED gate before code is touched. Shared contract: `output_type` `artifact-ref` with `reads_from` `spec.md`.
- The `code` step maps to `github.com/addyosmani/agent-skills/skills/incremental-implementation` (and `github.com/addyosmani/agent-skills/skills/code-simplification`), implementing thin vertical slices in `src/` until the full test suite passes under the GREEN gate. Shared contract: `output_type` `artifact-ref` with `reads_from` `test, spec.md, plan.md`.
- The `verify` step maps to `github.com/addyosmani/agent-skills/skills/code-review-and-quality` (evaluated against `references/security-checklist.md`, `references/performance-checklist.md`, and `references/accessibility-checklist.md`) and `github.com/addyosmani/agent-skills/skills/browser-testing-with-devtools`, gathering fresh execution evidence and code review findings. Shared contract: `output_type` `findings` with `reads_from` `test, code`.
- The `converge` step maps to `github.com/addyosmani/agent-skills/skills/shipping-and-launch` verification gates, evaluating acceptance criteria and constraints against `brief.md` and returning the loop verdict (`DONE`, `CONTINUE`, or `SPEC_CORRECTION_NEEDED`). Shared contract: `output_type` `decision` with `reads_from` `brief.md`.

Canonical home: addy framework integration.

## Step contract

| Step | phase_type | output_type | reads_from | artifact |
|---|---|---|---|---|
| `brief` | generate | draft | intake | `brief.md` |
| `specify` | generate | draft | `brief.md` | `spec.md` |
| `clarify` | clarify | decision | `spec.md` | — |
| `plan` | generate | draft | `spec.md`, `clarify` | `plan.md` |
| `test` | build | artifact-ref | `spec.md` | `tests/` |
| `code` | build | artifact-ref | `test`, `spec.md`, `plan.md` | `src/` |
| `verify` | verify | findings | `test`, `code` | — |
| `converge` | verify | decision | `brief.md` | — |

## Gates

- **RED gate — after `test`.** The suite is run before any implementation exists, with source mounted read-only. RED passes only when **at least one test fails**, and the failing count is recorded in the run log. A suite that passes immediately means the behavior already exists or the assertions are empty: the gate fails and the run routes to the owning clarify gate for spec correction instead of advancing to `code`.
- **GREEN gate — after `code`.** The suite is run again with `tests/`, `spec.md` and `plan.md` mounted read-only. GREEN passes only when the **full suite passes**. Any failure returns the failure list to the `code` step, bounded by the mission's code-step retry cap, and that loop-back does not consume the converge circuit breaker — only broken iterations do.
- **`converge` verdict — DONE, CONTINUE, SPEC_CORRECTION_NEEDED.** `DONE` — acceptance criteria met and quality threshold reached. `CONTINUE` — in-scope gaps remain; findings return to implementation and the circuit breaker applies. `SPEC_CORRECTION_NEEDED` — a criterion is unmeasurable or scope conflicts; the verdict routes to the owning clarify gate, never to code.
- `converge` is never reached with a red suite: GREEN is the last mechanical check before verification, and a red run stops at the gate.
- The split is skipped only when the run declares no test surface: `tdd: false`, docs/config-only work, or interactive mode.

## Boundaries

- No worktree: isolation belongs to the orchestrator; this skill works in the tree it is handed.
- No lease: never acquire, renew or release a run lease.
- No tracker writes: no comments, labels, status transitions, or MR/PR creation.
- No merge or approval: this skill never approves, merges or ships.
- Routes back: an unmeasurable criterion or a conflicting constraint stays at clarify until resolved; a spec later proven wrong is corrected through the owning clarify phase, never by quietly editing acceptance criteria downstream; an ambiguous or contradictory spec routes to its owning clarify phase; an implementation discovery that invalidates the order revises the plan; a `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate, never to code.
- The comment bus is the durable inter-agent memory: every step publishes its terminal output (decisions, findings, artifact references — never drafts) as a structured marker comment on the PR/MR/issue. The next step reads previous markers before starting. Local files carry the same outputs for same-session runs.
