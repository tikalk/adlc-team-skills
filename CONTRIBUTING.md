# Contributing to adlc-team-skills

Hi there! We're glad you'd like to contribute. Contributions to this project
are [released](https://help.github.com/articles/github-terms-of-service/#6-contributions-under-repository-license)
to the public under the [project's open source license](LICENSE).

## What lives here

This repo is a collection of **agent skills** — markdown playbooks
(`SKILL.md`) plus their templates, helper scripts, and the evaluation suite
that tests them. There is no compiled binary; the "runtime" is a coding
agent (Claude Code, Codex, OpenCode, …) reading the skills.

```
skills/<domain>/<skill-name>/SKILL.md     # one directory per skill
skills/<domain>/<skill-name>/scripts/     # optional setup helpers (bash/ps1)
skills/<domain>/<skill-name>/templates/   # optional templates
tests/                                    # pytest (unit + e2e)
evals/promptfoo/                          # goldset, config, graders
evals/promptfoo/graders/check_*.py        # binary Python graders
evals/promptfoo/tests/test_check_*.py     # grader unit tests
```

## What we accept

- **Skill improvements, fixes, tests, and docs** — always welcome as PRs.
- **New skills** — only after an issue is opened and the scope is agreed. We
  intentionally keep the skill count small; every skill must earn its place.
- **Cross-agent compatibility is required.** Skills must follow the
  [Agent Skills standard](https://agentskills.io) and must not depend on a
  single harness (e.g. don't hardcode `.claude/` paths — use the discovered
  paths pattern from `mission-brief`'s `references/agent-integrations.md`).
- **Skill behavior must be testable.** A new skill ships with eval coverage
  (a goldset criterion + grader) or a clear reason it can't be graded.

## Prerequisites

1. Install [Python 3.11+](https://www.python.org/downloads/) and [pytest](https://docs.pytest.org/)
2. Install [Git](https://git-scm.com/downloads)
3. Install [Node.js](https://nodejs.org/) (for `npx skills` / `npx promptfoo`)
4. Have an AI coding agent available (Claude Code, Codex, OpenCode, Cursor, …)

## Submitting a pull request

> [!NOTE]
> If your pull request introduces a new skill, renames or removes an existing
> one, or changes the behavior of `mission-brief`, make sure it was
> **discussed and agreed upon** in an issue first. Large unagreed changes
> will be closed.

1. Fork and clone the repository
2. Create a new branch: `git checkout -b <type>/<number>-<short-slug>` (see [Branch naming](#branch-naming))
3. Make your change, add tests, and make sure everything still passes (see [Automated checks](#automated-checks))
4. If your change affects a skill's behavior, run the manual test flow (see [Manual testing](#manual-testing))
5. Push to your fork and submit a pull request against `main`
6. Wait for review. `main` is protected: PR + approval + green CI are required.

Things that increase the likelihood of acceptance:

- Keep the change as focused as possible — one concern per PR.
- Write tests for new functionality (pytest and/or a grader + grader unit test).
- Update `README.md` and `CHANGELOG.md` if your change is user-facing.
- Follow the existing skill conventions (frontmatter, directory naming, plain markdown).
- Write a [good commit message](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

### Branch naming

`<type>/<number>-<short-slug>`, where `<number>` is the issue or PR number
(whichever comes first) and `<type>` is one of:

| Prefix | When to use | Example |
|---|---|---|
| `feat/` | New skills or features | `feat/12-universal-skill-routing` |
| `fix/` | Bug fixes | `fix/18-converge-independence-hint` |
| `docs/` | Documentation changes | `docs/21-readme-rewrite` |
| `test/` | Tests and graders | `test/9-eval-005-grader` |
| `chore/` | Maintenance, tooling, CI | `chore/7-pytest-config` |

## Skill conventions

These are enforced by `tests/unit/test_playbook_integrity.py`:

- **Directory name == frontmatter `name`.** A skill at
  `skills/team/team-boot/SKILL.md` must declare `name: team-boot`.
- **Frontmatter is valid YAML** with `name` and `description`. Templates may
  use Handlebars placeholders, which the test strips before parsing.
- **Skills are exactly 2 levels deep** (`skills/<domain>/<skill>/`) so the
  `skills` CLI installs everything by default.
- **Descriptions answer two questions**: what the skill does, and when to use
  it. Models pick skills by description — vague descriptions mean the skill
  never fires.

### Writing a new skill

Follow the patterns in existing skills before inventing new ones. A skill
that doesn't match these conventions won't be merged:

- **Structure**: `## Overview` (what + when to use) → `## Core Process`
  (numbered steps) → `## Red Flags` / `## Common Rationalizations` (failure
  modes to refuse) → `## Verification` (checkable outcomes) →
  `## Configuration`.
- **Progressive disclosure**: the skill body should be lean; load full
  context on demand (read an index first, fetch bodies only for matches).
  Don't design prompt walls.
- **Model-invoked vs user-invoked**: model-invoked skills auto-trigger from
  the task (their description is the trigger surface); user-invoked skills
  are explicit commands. Pick one — a skill is not both.
- **Verification over vibes**: every process ends with checkable criteria.
  If a claim can be checked by code (file exists, test passes, grep matches),
  write it as a check, not prose.
- **Graceful degradation**: unreadable files or missing config → skip
  silently or exit 0 with a clear note. Never block the user's task.

## Automated checks

Run the full suite before pushing:

```bash
pytest tests/ evals/promptfoo/tests/ -v
```

| Suite | What it covers |
|---|---|
| `tests/unit/test_playbook_integrity.py` | Skill frontmatter validity, directory/name parity, template YAML |
| `tests/unit/test_setup_scripts.py` | Every `setup-*.sh` runs in a sandbox and emits valid JSON/KEY=VALUE |
| `tests/e2e/` | Workflow state machines (mission-brief, team-repair, universal skill routing) |
| `evals/promptfoo/tests/` | Every grader produces correct pass/fail on goldset examples |

**Skill-behavior tests** use the PromptFoo harness in `evals/promptfoo/` —
goldset criteria with binary Python graders. Run the live evaluation suite
(requires `OPENAI_API_KEY`, or `GITHUB_TOKEN` in CI):

```bash
npx promptfoo eval --config evals/promptfoo/config.js --no-cache
```

### Adding a new eval criterion

1. Add the criterion to `evals/promptfoo/goldset.md` (pass/fail conditions + examples).
2. Add pass **and** fail cases to `evals/promptfoo/goldset.json`.
3. Write `evals/promptfoo/graders/check_<criterion>.py` with the contract:

```python
def get_assert(output: str, context: dict = None) -> dict:
    return {"pass": True, "score": 1.0, "reason": "..."}
```

4. Write `evals/promptfoo/tests/test_check_<criterion>.py` feeding the goldset
   examples through the grader. Graders are binary: `1.0` or `0.0`, never Likert.
5. Wire the test case into `evals/promptfoo/config.js`.

## Manual testing

Any change that alters a skill's behavior needs a manual run in a real agent.

1. **Install your branch into a scratch project:**
   ```bash
   mkdir /tmp/skill-test && cd /tmp/skill-test && git init
   npx skills add /path/to/your/adlc-team-skills -a claude
   ```
2. **Run the affected skill** in your agent (e.g. `mission-brief "add a health endpoint"` or `/team-discover`) and verify it completes and writes the expected artifacts under `.adlc/`.
3. **Run prerequisites first** — e.g. `team-setup` before `team-boot`-dependent flows, `evals-init` before `evals-*`.
4. **Report results** in the PR:

~~~markdown
## Manual test results

**Agent**: [e.g., Claude Code]  |  **OS/Shell**: [e.g., macOS/zsh]

| Skill/command tested | Notes |
|----------------------|-------|
| `mission-brief` | Discovered 2 local skills, routed implement → tdd |
~~~

## Security

- **Never commit editor auto-run configs.** `.vscode/tasks.json` and
  `.claude/settings.json` (hooks, SessionStart) in this repo or in skills are
  reviewed as executable code. See [issue #1](https://github.com/tikalk/adlc-team-skills/issues/1).
- No secrets, tokens, or credentials in skills, templates, tests, or goldset
  examples. Use placeholders.
- Graders and scripts must not make network calls beyond what their docstring
  declares.

## AI contributions

> [!IMPORTANT]
> If you used **any kind of AI assistance** to contribute, disclose it in the
> pull request, along with the extent (e.g., "docs only" vs. "code generation").

We welcome AI-assisted contributions — this project is about AI agents, after
all. But undisclosed AI text wastes reviewer time, and code that no human
understood cannot be maintained.

When submitting AI-assisted work, make sure it includes:

- **Clear disclosure** of AI use and degree
- **Human understanding and testing** — you ran the tests and can explain the diff
- **Clear rationale** — why the change is needed and how it fits the project
- **Your own analysis** — not just generated output pasted into a PR

We reserve the right to close contributions that appear to be untested,
generic, or bulk-generated without human review. Trivial typo and spacing
fixes don't need disclosure.

## Releases

Maintainers only — see [RELEASE.md](./RELEASE.md) for the tag naming
convention (`adlc-team-skills-vX.Y.Z`), changelog requirements, and the
automated release workflow.

## Resources

- [Twelve-Factor Agentic SDLC](https://github.com/tikalk/agentic-sdlc-12-factors)
- [Agent Skills standard](https://agentskills.io)
- [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)
- [Using Pull Requests](https://help.github.com/articles/about-pull-requests/)
