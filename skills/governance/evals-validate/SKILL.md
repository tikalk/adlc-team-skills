---
name: evals-validate
description: Run evaluations and validate evaluator quality (SLA compliance, TPR/TNR, statistical accuracy). Executes PromptFoo or pytest DeepEval.
disable-model-invocation: true
---

# evals-validate

## What this skill does

Conducts **comprehensive validation** of the implemented evaluation system following **EDD principles** to ensure production readiness through statistical analysis, performance verification, and quality assurance.

**Output**:
1. **Statistical Validation** - TPR/TNR analysis, accuracy metrics, confidence intervals
2. **Performance Validation** - SLA compliance verification for evaluation pyramid tiers
3. **Quality Assurance** - Goldset integrity, example balance, coverage analysis
4. **Holdout Dataset Validation** - Unbiased accuracy assessment on reserved test set
5. **Auto-handoff** to `/evals-analyze` for closed loop trajectory analysis

**Key EDD Principles Applied**:
- **Principle IV**: Evaluation Pyramid - Tier performance SLA validation (Tier 1 <30s, Tier 2 <5min)
- **Principle II**: Binary Pass/Fail - Statistical compliance verification
- **Principle IX**: Test Data as Code - Holdout dataset validation integrity
- **Principle III**: Error Analysis - Pattern stability validation

## When to use

- **After `/evals-implement`**: Execute the evaluation suite and measure quality
- **CI/CD Pipeline gate**: Run evaluations before release to ensure no regressions
- **Periodic audit**: Verify evaluator accuracy on holdout data to check for model drift

## When NOT to use

- **Evaluator not generated**: Run `/evals-implement` to build grader files first
- **Analysing failure traces**: Use `/evals-analyze` to extract deep insights from run results

## Process

### User Input
```text
$ARGUMENTS
```
- `--holdout-only` — Validate only on holdout dataset (unbiased validation)
- `--performance-only` — Skip statistical analysis, focus on SLA compliance
- `--metrics METRICS` — Specific metrics to validate (tpr, tnr, accuracy, performance)

### Execution Steps

#### Phase 1: Execute Evaluations
Runs the underlying framework CLI directly:
- PromptFoo: `npx promptfoo eval --config evals/promptfoo/config.js`
- DeepEval: `pytest evals/deepeval/ -v` or `python evals/deepeval/config.py`

#### Phase 2: Compute Statistical Validation
- Parse generated results JSON from `evals/results/`.
- Calculate True Positive Rate (TPR) and True Negative Rate (TNR).
- Calculate overall accuracy with 95% confidence intervals.
- Ensure no Likert scales or numerical scores leak into results.

#### Phase 3: SLA Compliance Check
- Measure execution times for Tier 1 and Tier 2.
- Verify Tier 1 completes under 30 seconds.
- Verify Tier 2 completes under 5 minutes.
- Check headroom analysis (SLA budget consumed).

#### Phase 4: Write Validation Report
- Write validation results to `evals/results/validation_report.md`.
- Include pass/fail counts, TPR/TNR table, SLA timings, and holdout set results.

#### Phase 5: Auto-Handoff
Trigger `/evals-analyze` to close the loop.

## Verification
- Evaluation execution successfully completed with results JSON written to `evals/results/`
- `evals/results/validation_report.md` created with TPR/TNR and SLA metrics
- Statistical metrics calculated with confidence intervals
- Headroom and SLA compliance verified
- Handover summary lists results and validation report path