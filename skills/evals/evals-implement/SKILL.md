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
   - PromptFoo: Python grader functions with JSON output in `$SDD_ROOT/evals/{system}/graders/`
   - DeepEval: Custom metric classes inheriting from `BaseMetric`
2. **Evaluator Unit Tests** - Automated tests (`$SDD_ROOT/evals/{system}/tests/test_check_*.py`) that run the goldset pass/fail examples against the generated graders to ensure the evaluator itself is accurate
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

#### Phase 1: Trace-to-Grader Synthesis (Automated Eval Engineering)
- Reads `$SDD_ROOT/evals/{system}/goldset.json`.
- Maps rich evidence fields from the goldset criteria into grader logic (Trace-to-Grader Synthesis):
  - Uses `pass_condition` and `fail_condition` as the grader's core rubric.
  - Extracts pass/fail examples to act as raw data anchors and few-shot classification anchors inside the grader logic.
  - Injects `Root Cause Analysis` and `axial_coding` notes as contextual prompt guidelines or regex patterns to catch exact failure manifestations.
- For PromptFoo: Generates Python grader functions (`$SDD_ROOT/evals/{system}/graders/check_*.py`) containing specialized, dynamic LLM-judge templates or regex checks compiled from these goldset inputs.
- For DeepEval: Generates Custom Metric classes inheriting from `BaseMetric` compiled from these goldset inputs.
- All graders conform strictly to the binary pass/fail standard (returning only `1.0` or `0.0`, with zero Likert scale leakage).

#### Phase 2: Unit Test Generation
- Generates matching unit tests (`$SDD_ROOT/evals/{system}/tests/test_check_*.py`) for each grader.
- Unit tests verify the grader correctly identifies the goldset's training pass and fail examples.

#### Phase 2b: Closed-Loop Grader Self-Tuning
- Executes generated unit tests (`pytest $SDD_ROOT/evals/{system}/tests/`) to verify evaluator accuracy.
- **Grader Calibration Loop**:
  1. Inspects test results to detect any misclassifications (false positives/negatives) on the training cases.
  2. If any test fails, triggers a feedback edit step that parses the failure reasons and automatically adjusts the grader's internal prompt rubric, regex stubs, or score thresholds.
  3. Re-runs pytest to check accuracy.
  4. Repeats for up to **3 iterations** (the hard circuit-breaker limit).
- **Holdout Locking**: Ensure the holdout validation set (`holdout.json`) remains completely isolated and is never loaded or exposed to the self-tuning loop (to prevent overfitting).
- **Failure Escalation**: If the grader does not converge to 100% training accuracy within 3 iterations, the loop halts, surfaces the failing test case details, and raises an error rather than passing silently.

#### Phase 3: Config Generation
- Generates the unified framework configuration file (`config.js` or `config.py`).
- Configures separate Tier 1 (fast checks, <30s, deterministic) and Tier 2 (semantic checks, <5min, LLM-judge) pipelines.

#### Phase 4: Auto-Handoff
Trigger `/evals-validate` to run validation.

## Verification
- `$SDD_ROOT/evals/{system}/graders/` contains Python grader scripts for each criterion compiled dynamically from goldset pass/fail examples and root-cause analyses
- `$SDD_ROOT/evals/{system}/tests/` contains matching unit test files
- Framework config (`config.js` or `config.py`) successfully generated
- Grader calibration self-tuning loop ran and converged to 100% training accuracy within the 3-iteration cap (or raised explicit non-convergence errors)
- Holdout dataset protection confirmed (validation `holdout.json` remained completely isolated and untouched during tuning)
- All grader unit tests pass locally (`pytest $SDD_ROOT/evals/{system}/tests/`)
- Handover summary lists generated graders, self-tuning iterations, and test results