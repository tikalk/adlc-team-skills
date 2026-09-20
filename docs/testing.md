# Testing adlc-team-skills

Two questions, two test directories, three tiers:

| Directory | Answers | Runs LLMs? | Runs where |
|---|---|---|---|
| `tests/` | does the repo's non-LLM machinery work? | No | every PR (`test.yml`) |
| `evals/promptfoo/tests/` | do the graders themselves grade correctly? | No | every PR (`test.yml`) |
| `evals/promptfoo/` (live suite) | do agents actually follow the skills? | Yes | PRs **with** `OPENAI_API_KEY` + nightly sweep |

## Static gates (`tests/`, every PR, no LLM)

```bash
python3 -m pip install -r requirements.txt
pytest tests/ evals/promptfoo/tests/ -v
```

- `tests/unit/test_playbook_integrity.py` — the skill schema: frontmatter
  `name` + `description` (presence, ≤1024 chars, "Use when…" trigger form),
  directory/name parity, exact-2-level depth, template YAML, token-budget
  warnings.
- `tests/unit/test_generated_artifacts_sync.py` — the CLI-generated install
  layer (`.agents/skills/` mirror, `.opencode/commands/`) stays in sync with
  `skills/`. Skips when artifacts aren't generated locally.
- `tests/unit/test_setup_scripts.py` — every `setup-*.sh` executes in a
  sandbox and emits valid JSON/KEY=VALUE output.
- `tests/unit/test_team_boot_setup_flow.py`, `test_team_class_boots.py`,
  `test_tech_radar.py`, `test_validate_prd.py` — behavioral contracts of the
  boot scripts, class boots, and validators.
- `tests/e2e/` — workflow state machines (mission-brief loop, factory loop,
  team-repair, universal skill routing) re-implemented as deterministic
  Python. **Known limit:** they test a re-implementation, not the markdown
  — a SKILL.md edit that changes behavior passes unless its Python twin is
  updated. That's what the evals below are for.

## Live skill-behavior evals (`evals/promptfoo/`, LLM)

```bash
npx promptfoo eval --config evals/promptfoo/config.js --no-cache
```

- Requires `OPENAI_API_KEY` (`OPENAI_BASE_URL`/`EVAL_MODEL` to route to a
  proxy or different model).
- Scenarios wired to binary Python graders (`graders/check_*.py`) — pass
  assertions where code can check, never Likert. Each grader is itself
  unit-tested in `evals/promptfoo/tests/`.
- Goldset criteria live in `goldset.md` (EVAL-001…013) and `goldset.json`.

### The tiered model

`test.yml` skips the eval job when `OPENAI_API_KEY` is absent — by design,
so forks and external PRs don't fail CI on a secret they can't have. The
cost: skill-behavior changes from those contributors get zero LLM-eval
coverage before review. The nightly sweep (`evals-nightly.yml`) closes
that gap — every night, main's full suite runs on the canonical repo. If
the nightly goes red, the regression came from something merged since the
previous green night.

### Adding a criterion

Follow the 5-step recipe in CONTRIBUTING ("Adding an eval criterion"):
criterion in `goldset.md` → case in `goldset.json` → binary grader in
`graders/` → grader unit test in `tests/` → scenario in `config.js`.

## Canonical acceptance test

`scripts/acceptance-test.sh` — scratch-installs this repo via adlc-cli
and asserts team-boot's session_start script emits the full directives
index (constitution, CDR index, Class Boots, skills). `--live` adds an
opencode smoke check. See CONTRIBUTING → "Canonical acceptance test".
