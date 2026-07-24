---
name: evals-implement
description: Generate executable graders and configs from goldset. Generates Python graders / metrics and auto-runs unit tests to verify grader correctness.
disable-model-invocation: true
---

# evals-implement

## What this skill does

Generates the **complete executable evaluation implementation** following **EDD Principle VIII** (Close Production Loop) from the published goldset, with automated unit testing to verify evaluator correctness.

**Output**:
1. **Grader/Metric Implementation** - Python evaluators for each goldset criterion with binary pass/fail
   - PromptFoo: Python grader functions with JSON output in `evals/{system}/graders/`
   - DeepEval: Custom metric classes inheriting from `BaseMetric`
2. **Evaluator Unit Tests** - Automated tests (`evals/{system}/tests/test_check_*.py`) that run the goldset pass/fail examples against the generated graders to ensure the evaluator itself is accurate
3. **Evaluation Configuration** - Complete config file (`config.js` or `config.py`) with Tier 1 + Tier 2 evaluation structure
4. **Auto-handoff** to `/evals-validate` to run validation

**Key EDD Principles Applied**:
- **Principle VIII**: Close Production Loop - Failure type gates route to appropriate actions
- **Principle II**: Binary Pass/Fail - Ensure graders return strictly 1.0 (pass) or 0.0 (fail)
- **Principle IX**: Test Data as Code - Unit test generated code against dataset examples

## When to use

- **After `/evals-clarify`**: Convert accepted goldset criteria into executable code
- **Regenerating configs**: Re-build evaluator suite after adding new goldset criteria
- **Adding unit tests**: Hardening the evaluator itself against regression or bugs

## When NOT to use

- **Goldset not published**: Run `/evals-clarify` to generate `goldset.json` first
- **Running evaluations**: Use `/evals-validate` to run the suite against application outputs

## Process

### User Input
```text
$ARGUMENTS
```
- `--system SYSTEM` — Override active evaluation framework (`promptfoo` or `deepeval`)
- `--no-tests` — Skip automated unit test generation for graders (not recommended)

### Execution Steps

#### Phase 1: Grader Generation
- Reads `evals/{system}/goldset.json`.
- For PromptFoo: Generates Python grader functions with regex, deterministic checks, and LLM-judge templates in `evals/{system}/graders/`.
- For DeepEval: Generates Custom Metric classes inheriting from `BaseMetric` in `evals/{system}/graders/`.
- All graders are strictly binary (return only 1.0/0.0, no confidence scores).

#### Phase 2: Unit Test Generation
- Generates matching unit tests (`evals/{system}/tests/test_check_*.py`) for each grader.
- Unit tests verify the grader correctly identifies the goldset's pass and fail examples.
- Runs the generated tests via `pytest` to ensure all graders are functional and accurate before proceeding.

#### Phase 3: Config Generation
- Generates the unified framework configuration file (`config.js` or `config.py`).
- Configures separate Tier 1 (fast checks, <30s, deterministic) and Tier 2 (semantic checks, <5min, LLM-judge) pipelines.

#### Phase 4: Auto-Handoff
Trigger `/evals-validate` to run validation.

## Verification
- `evals/{system}/graders/` contains Python grader scripts for each criterion
- `evals/{system}/tests/` contains matching unit test files
- Framework config (`config.js` or `config.py`) successfully generated
- All grader unit tests pass locally (`pytest evals/{system}/tests/`)
- Handover summary lists generated graders and test results