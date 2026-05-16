---
description: TPR/TNR + goldset quality + PromptFoo pass rate thresholds validation
  following EDD compliance verification
scripts:
  sh: .specify/scripts/bash/setup-evals.sh "validate {ARGS}"
  ps: .specify/scripts/powershell/setup-evals.ps1 "validate {ARGS}"
---


<!-- Extension: evals -->
<!-- Config: .specify/extensions/evals/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Check TPR/TNR thresholds and performance SLA compliance"`
- `"Validate holdout dataset accuracy and goldset quality"`
- `"Run full EDD compliance verification with statistical analysis"`
- `"Performance validation only - skip statistical analysis"`
- `"Validate tier 1 SLA compliance (<30s) and tier 2 accuracy (>90%)"`
- Empty input: Run comprehensive validation across all metrics and compliance checks

When users provide specific validation focus areas or thresholds, prioritize those validation criteria.

## Goal

**Comprehensive validation** of the implemented evaluation system following **EDD principles** to ensure production readiness through statistical analysis, performance verification, and quality assurance.

**Output**:

1. **Statistical Validation** - TPR/TNR analysis, accuracy metrics, confidence intervals
2. **Performance Validation** - SLA compliance verification for evaluation pyramid tiers
3. **Quality Assurance** - Goldset integrity, example balance, coverage analysis
4. **EDD Compliance Verification** - All 10 principles implementation validation
5. **Integration Testing** - End-to-end pipeline validation and error handling
6. **Production Readiness Report** - Comprehensive assessment with recommendations

**Key EDD Principles Applied**:

- **Principle IV**: Evaluation Pyramid - Tier performance SLA validation
- **Principle II**: Binary Pass/Fail - Statistical compliance verification
- **Principle IX**: Test Data as Code - Holdout dataset validation integrity
- **Principle III**: Error Analysis & Pattern Discovery - Pattern stability validation

### Flags

- `--metrics METRICS`: Specific metrics to validate (tpr,tnr,accuracy,performance)
- `--thresholds CONFIG`: Custom threshold configuration file
- `--holdout-only`: Validate only on holdout dataset (unbiased validation)
- `--performance-only`: Skip statistical analysis, focus on SLA compliance
- `--compliance-check`: Run EDD principles compliance verification only
- `--json`: Output structured JSON for programmatic integration

## Role & Context

You are acting as an **Evaluation System Validator** conducting comprehensive quality assurance and compliance verification. Your role involves:

- **Statistical Analysis**: TPR/TNR calculation, accuracy validation, confidence interval estimation
- **Performance Testing**: SLA compliance verification across evaluation pyramid tiers
- **Quality Assurance**: Goldset integrity verification, bias detection, coverage analysis
- **Compliance Verification**: EDD principles implementation validation across all components

### Validation vs Implementation

| Phase | Focus | Input | Output |
|-------|-------|-------|--------|
| **Implementation** (implement) | Evaluator creation | Goldset criteria | Executable graders + configs |
| **Validation** (this command) | Quality assurance | Implemented system | Production readiness assessment |

## Outline

1. **System Inventory** (Phase 0): Comprehensive assessment of implemented components
2. **Statistical Validation**: TPR/TNR analysis, accuracy metrics, statistical significance
3. **Performance Validation**: SLA compliance verification across evaluation tiers
4. **Goldset Quality Assurance**: Integrity verification, bias detection, coverage analysis
5. **Holdout Dataset Validation**: Unbiased accuracy assessment on reserved test set
6. **EDD Compliance Verification**: All 10 principles implementation validation
7. **Integration Testing**: End-to-end pipeline validation and error handling verification
8. **Production Readiness Assessment**: Comprehensive report with recommendations

## Execution Steps

### Phase 0: System Inventory and Readiness Assessment

**Objective**: Comprehensive assessment of implemented evaluation system components

#### Step 1: Implementation Inventory

Assess all implemented components for validation readiness:

```bash
# Execute via setup script
.specify/scripts/bash/setup-evals.sh "validate $ARGUMENTS" validate --assess-system
```

**Expected System Assessment**:
```markdown
## Evaluation System Implementation Inventory

**Assessment Date**: {current_date}
**Implementation Version**: {implementation_version}

### Component Status

| Component | Status | Location | Quality |
|-----------|--------|----------|---------|
| **Security Baseline Graders** | ✅ Implemented | `evals/{system}/graders/` | 4/4 graders |
| **Goldset Criteria Graders** | ✅ Implemented | `evals/{system}/graders/` | 2/2 graders |
| **PromptFoo Configuration** | ✅ Generated | `evals/{system}/config.js` | Complete |
| **Tier Configurations** | ✅ Generated | `config-tier1.js`, `config-tier2.js` | 2/2 tiers |
| **Goldset Documentation** | ✅ Published | `evals/{system}/goldset.md` | Version 1.0.0 |
| **Holdout Dataset** | ⚠ Needs Verification | `evals/{system}/holdout.md` | Protected |
| **Failure Routing** | ✅ Configured | `results/` directories | 3 routes |

### Implementation Completeness
- **Total Graders**: 6 (4 security + 2 goldset)
- **Binary Compliance**: ✅ All graders return 1.0/0.0 only
- **Evaluation Pyramid**: ✅ Tier 1 (5 graders) + Tier 2 (1 grader)
- **Failure Routing**: ✅ Specification + Generalization routing implemented
- **Version Control**: ✅ All components tracked and versioned

**Validation Readiness**: ✅ READY FOR COMPREHENSIVE VALIDATION
```

#### Step 2: Validation Prerequisites Check

Verify all prerequisites for comprehensive validation:

```markdown
## Validation Prerequisites Checklist

### Data Requirements ✅
- [ ] **Goldset Examples**: Minimum 20 examples per criterion
- [ ] **Holdout Dataset**: 20% reserved, properly protected
- [ ] **Adversarial Examples**: Attack scenarios included
- [ ] **Example Balance**: Pass/fail ratio within 40-60% range

### Technical Requirements ✅
- [ ] **Grader Executability**: All graders are executable and testable
- [ ] **PromptFoo Integration**: Configurations are syntactically valid
- [ ] **Dependencies**: Python, PromptFoo, LLM APIs accessible
- [ ] **Results Directories**: Proper permissions and structure

### Baseline Requirements ✅
- [ ] **EDD Implementation**: All 10 principles implemented
- [ ] **Binary Compliance**: No non-binary outputs detected
- [ ] **Performance Baseline**: Initial performance metrics available
- [ ] **Documentation**: Complete implementation documentation

**Prerequisites Status**: ✅ ALL REQUIREMENTS MET
```

#### Step 3: Execute Evaluators and Generate Results

**CRITICAL**: Before validation can proceed, evaluators must be executed to generate results files.

Detect evaluation system type and execute appropriately:

```bash
# Detect system type
if [ -f "evals/promptfoo/config.js" ] || [ -f "evals/config.js" ]; then
    EVAL_SYSTEM="promptfoo"
elif [ -f "evals/deepeval/goldset.json" ] || [ -f "evals/goldset.json" ]; then
    EVAL_SYSTEM="deepeval-custom"
else
    echo "❌ Cannot detect evaluation system type"
    exit 1
fi

echo "🔍 Detected evaluation system: $EVAL_SYSTEM"
```

**For PromptFoo:**
```bash
# Run PromptFoo evaluation
cd evals/promptfoo 2>/dev/null || cd evals
promptfoo eval --config config.js --no-cache --output ../results/promptfoo_results.json
```

**For DeepEval/Custom:**
```bash
# Run custom evaluator execution framework
if [ ! -f "./run_evaluators.py" ]; then
    echo "❌ run_evaluators.py not found"
    echo "   This script is required to execute custom/DeepEval evaluators"
    exit 1
fi

# Execute evaluators against goldset
./run_evaluators.py \
    --goldset evals/deepeval/goldset.json \
    --graders evals/deepeval/graders \
    --results evals/results \
    --mapping evals/grader_mapping.json \
    --pass-threshold 0.8

if [ $? -ne 0 ]; then
    echo "⚠️  Evaluator execution completed with failures"
    echo "   Results generated but accuracy below threshold"
fi
```

**Expected Output:**
```markdown
## Evaluator Execution Results

**System**: DeepEval/Custom
**Goldset**: evals/deepeval/goldset.json (version 1.0)
**Graders Discovered**: 6

### Execution Summary
- Total Examples: 42
- Passed: 38/42 (90.5%)
- Failed: 4/42
- Errors: 0

### Per-Criterion Results
| Criterion | Examples | Passed | Accuracy |
|-----------|----------|--------|----------|
| eval-001 (PII Leakage) | 8 | 8/8 | 100% |
| eval-002 (Misinformation) | 7 | 6/7 | 85.7% |
| eval-003 (Hallucination) | 6 | 5/6 | 83.3% |
| eval-004 (HTTPS Validation) | 8 | 8/8 | 100% |
| eval-005 (Prompt Injection) | 7 | 6/7 | 85.7% |
| eval-006 (Unit Conversion) | 6 | 5/6 | 83.3% |

**Results Location**: 
- Latest: `evals/results/evaluation_results_latest.json`
- Timestamped: `evals/results/evaluation_results_20260420_153042.json`

✅ Results ready for statistical validation
```

**Verification:**
```bash
# Verify results files exist
if [ ! -f "evals/results/evaluation_results_latest.json" ]; then
    echo "❌ No results found in evals/results/"
    echo "   Evaluators validated but never executed"
    echo "   Run evaluators first to generate results"
    exit 1
fi

echo "✅ Results files found, proceeding to validation"
```

### Phase 1: Statistical Validation

**Objective**: Comprehensive statistical analysis of evaluation system accuracy and reliability

**Input**: Generated results from Phase 0 Step 3 execution

#### Step 1: True Positive Rate (TPR) / True Negative Rate (TNR) Analysis

Calculate and validate classification performance metrics from execution results:

```python
# Statistical validation from execution results
import json
import numpy as np
from scipy import stats
from typing import Dict, List, Tuple
from pathlib import Path

def load_execution_results(results_path: str = "evals/results/evaluation_results_latest.json") -> Dict:
    """Load results from evaluator execution."""
    with open(results_path) as f:
        return json.load(f)

def calculate_tpr_tnr_from_results(criterion_results: Dict) -> Dict:
    """
    Calculate TPR/TNR from execution results.

    TPR (Sensitivity) = True Positives / (True Positives + False Negatives)
    TNR (Specificity) = True Negatives / (True Negatives + False Positives)
    """

    true_positives = 0
    false_positives = 0
    true_negatives = 0
    false_negatives = 0

    for example_result in criterion_results.get("example_results", []):
        if "error" in example_result.get("grader_output", {}):
            continue  # Skip errors in TPR/TNR calculation

        expected_pass = example_result["expected_pass"]
        grader_pass = example_result["grader_pass"]

        # Build confusion matrix
        if expected_pass and grader_pass:
            true_positives += 1
        elif expected_pass and not grader_pass:
            false_negatives += 1
        elif not expected_pass and not grader_pass:
            true_negatives += 1
        elif not expected_pass and grader_pass:
            false_positives += 1

    # Calculate metrics
    total_positive = true_positives + false_negatives
    total_negative = true_negatives + false_positives

    tpr = true_positives / total_positive if total_positive > 0 else 0
    tnr = true_negatives / total_negative if total_negative > 0 else 0

    # Calculate confidence intervals (95%)
    tpr_ci = stats.binom.interval(0.95, total_positive, tpr) if total_positive > 0 else (0, 0)
    tnr_ci = stats.binom.interval(0.95, total_negative, tnr) if total_negative > 0 else (0, 0)

    accuracy = (true_positives + true_negatives) / (total_positive + total_negative) if (total_positive + total_negative) > 0 else 0

    return {
        'tpr': tpr,
        'tnr': tnr,
        'tpr_ci': (tpr_ci[0]/total_positive if total_positive > 0 else 0, 
                   tpr_ci[1]/total_positive if total_positive > 0 else 0),
        'tnr_ci': (tnr_ci[0]/total_negative if total_negative > 0 else 0,
                   tnr_ci[1]/total_negative if total_negative > 0 else 0),
        'confusion_matrix': {
            'tp': true_positives,
            'fp': false_positives,
            'tn': true_negatives,
            'fn': false_negatives
        },
        'total_examples': total_positive + total_negative,
        'accuracy': accuracy
    }

def validate_all_criteria():
    """Validate TPR/TNR for all criteria from execution results."""
    results = load_execution_results()
    
    validation_results = {}
    for criterion_id, criterion_data in results.get("criteria_results", {}).items():
        metrics = calculate_tpr_tnr_from_results(criterion_data)
        validation_results[criterion_id] = {
            "criterion_name": criterion_data.get("criterion_name", criterion_id),
            **metrics
        }
    
    return validation_results
```

#### Step 2: Goldset Accuracy Validation

Validate accuracy against goldset examples with statistical significance:

```markdown
## Goldset Accuracy Validation Results

### Per-Grader Performance

| Grader | TPR | TNR | Accuracy | 95% CI | Status |
|--------|-----|-----|----------|--------|--------|
| **PII Leakage** | 0.95 | 0.98 | 0.965 | (0.92-0.99) | ✅ PASS |
| **Prompt Injection** | 0.92 | 0.96 | 0.940 | (0.88-0.97) | ✅ PASS |
| **Hallucination** | 0.88 | 0.93 | 0.905 | (0.84-0.95) | ✅ PASS |
| **Misinformation** | 0.90 | 0.94 | 0.920 | (0.86-0.96) | ✅ PASS |
| **Regulatory Compliance** | 0.93 | 0.97 | 0.950 | (0.90-0.98) | ✅ PASS |
| **Context Adherence** | 0.89 | 0.91 | 0.900 | (0.85-0.94) | ✅ PASS |

### Statistical Summary
- **Mean Accuracy**: 0.930 (93.0%)
- **Minimum Accuracy**: 0.900 (90.0%)
- **All graders meet 90% threshold**: ✅ PASS
- **Statistical Significance**: All results significant at p < 0.05

### Threshold Compliance
- **TPR Threshold**: ≥0.90 → ✅ All graders compliant
- **TNR Threshold**: ≥0.90 → ✅ All graders compliant
- **Accuracy Threshold**: ≥0.90 → ✅ All graders compliant
- **Confidence Interval**: 95% CI above threshold for all graders
```

#### Step 3: Holdout Dataset Validation (Unbiased Assessment)

Validate performance on reserved holdout dataset:

```markdown
## Holdout Dataset Validation (Unbiased)

**Holdout Set**: 20% of examples (6 examples) reserved during analyze phase
**Validation Method**: Single-pass evaluation (no training or tuning allowed)
**Statistical Approach**: Exact binomial tests for small sample sizes

### Holdout Results

| Grader | Holdout Accuracy | Expected Accuracy | Statistical Test | Status |
|--------|------------------|-------------------|------------------|--------|
| **PII Leakage** | 6/6 (100%) | 96.5% | p=0.12 (n.s.) | ✅ CONSISTENT |
| **Prompt Injection** | 5/6 (83%) | 94.0% | p=0.08 (n.s.) | ✅ CONSISTENT |
| **Hallucination** | 5/6 (83%) | 90.5% | p=0.15 (n.s.) | ✅ CONSISTENT |
| **Misinformation** | 6/6 (100%) | 92.0% | p=0.18 (n.s.) | ✅ CONSISTENT |
| **Regulatory Compliance** | 6/6 (100%) | 95.0% | p=0.25 (n.s.) | ✅ CONSISTENT |
| **Context Adherence** | 5/6 (83%) | 90.0% | p=0.20 (n.s.) | ✅ CONSISTENT |

### Statistical Analysis
- **Mean Holdout Accuracy**: 92.8%
- **Goldset vs Holdout Difference**: -0.2% (not significant)
- **No Significant Overfitting**: All p-values > 0.05
- **Small Sample Caveat**: Limited holdout size (n=6) reduces statistical power

**Holdout Validation Status**: ✅ NO OVERFITTING DETECTED
```

### Phase 2: Performance Validation

**Objective**: Verify SLA compliance across evaluation pyramid tiers

#### Step 1: Tier 1 Performance Validation (Fast Checks <30s)

Validate Tier 1 SLA compliance:

```bash
# Performance testing script
time_tier1_execution() {
    local config_file="evals/{system}/config-tier1.js"
    local start_time=$(date +%s.%N)

    # Run Tier 1 evaluation
    promptfoo eval --config "$config_file" --no-cache

    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc)

    echo "{\"tier\": 1, \"execution_time\": $execution_time, \"sla_seconds\": 30}"
}
```

**Tier 1 Performance Results**:
```markdown
## Tier 1 Performance Validation (<30 seconds SLA)

### Execution Time Analysis

| Grader | Avg Time (s) | Max Time (s) | SLA (s) | Status |
|--------|--------------|--------------|---------|--------|
| **PII Leakage** | 0.12 | 0.18 | 30 | ✅ PASS |
| **Prompt Injection** | 0.15 | 0.22 | 30 | ✅ PASS |
| **Hallucination** | 0.18 | 0.25 | 30 | ✅ PASS |
| **Misinformation** | 0.16 | 0.23 | 30 | ✅ PASS |
| **Regulatory Compliance** | 0.14 | 0.21 | 30 | ✅ PASS |

### Overall Tier 1 Performance
- **Total Execution Time**: 0.95 seconds (average)
- **Maximum Execution Time**: 1.23 seconds
- **SLA Compliance**: ✅ PASS (4% of 30s SLA)
- **Performance Headroom**: 96% available for scaling

**Tier 1 SLA Status**: ✅ EXCELLENT PERFORMANCE
```

#### Step 2: Tier 2 Performance Validation (Semantic <5min)

Validate Tier 2 SLA compliance:

```markdown
## Tier 2 Performance Validation (<5 minutes SLA)

### LLM-Judge Performance Analysis

| Grader | Avg Time (s) | Max Time (s) | API Calls | SLA (s) | Status |
|--------|--------------|--------------|-----------|---------|--------|
| **Context Adherence** | 3.2 | 4.8 | 1 | 300 | ✅ PASS |

### LLM API Performance Metrics
- **Average Latency**: 3.2 seconds
- **95th Percentile**: 4.8 seconds
- **API Success Rate**: 100%
- **Retry Rate**: 0%
- **Timeout Rate**: 0%

### Overall Tier 2 Performance
- **Total Execution Time**: 3.2 seconds (average)
- **Maximum Execution Time**: 4.8 seconds
- **SLA Compliance**: ✅ PASS (1.6% of 300s SLA)
- **Performance Headroom**: 98% available

**Tier 2 SLA Status**: ✅ EXCELLENT PERFORMANCE
```

#### Step 3: Evaluation Pyramid Integration Performance

Test complete evaluation pipeline performance:

```markdown
## Complete Evaluation Pipeline Performance

### End-to-End Execution
- **Tier 1 + Tier 2 Total**: 4.15 seconds average
- **Pipeline Overhead**: 0.05 seconds
- **Total SLA Budget**: 330 seconds (30s + 300s)
- **Actual Usage**: 1.25% of total budget

### Scalability Analysis
- **Current Load**: 6 graders across 2 tiers
- **Theoretical Maximum**: ~1,600 Tier 1 graders or ~80 Tier 2 graders
- **Recommended Maximum**: ~160 Tier 1 graders + ~8 Tier 2 graders
- **Scaling Headroom**: 98.75% available

**Pipeline Performance Status**: ✅ EXCELLENT SCALABILITY
```

### Phase 3: Goldset Quality Assurance

**Objective**: Comprehensive goldset integrity and quality verification

#### Step 1: Data Quality and Balance Analysis

Verify goldset data quality and balance:

```markdown
## Goldset Quality Analysis

### Data Balance Assessment

| Criterion | Total Examples | Pass Examples | Fail Examples | Balance Ratio | Status |
|-----------|---------------|---------------|---------------|---------------|--------|
| **eval-001 (Regulatory)** | 6 | 3 | 3 | 50:50 | ✅ BALANCED |
| **eval-002 (Context)** | 8 | 4 | 4 | 50:50 | ✅ BALANCED |
| **eval-003 (Safety)** | 4 | 2 | 2 | 50:50 | ✅ BALANCED |
| **eval-006 (Auth)** | 6 | 3 | 3 | 50:50 | ✅ BALANCED |

### Quality Metrics
- **Total Examples**: 24
- **Balance Range**: 40-60% target → All criteria 50:50 ✅
- **Example Sufficiency**: Minimum 4 examples per criterion ✅
- **Coverage Completeness**: All published criteria have examples ✅

### Example Quality Assessment
- **Realistic Inputs**: ✅ All examples reflect real-world usage
- **Clear Pass/Fail**: ✅ All examples unambiguously pass or fail criteria
- **Context Completeness**: ✅ Sufficient context for evaluation
- **Edge Case Coverage**: ✅ Boundary conditions included
```

#### Step 2: Bias Detection and Fairness Analysis

Analyze potential biases in goldset and evaluation:

```markdown
## Bias Detection Analysis

### Input Diversity Analysis
- **Domain Coverage**: Financial, medical, legal, technical, general
- **Language Complexity**: Simple, medium, complex sentence structures
- **Context Types**: No context, brief context, detailed context
- **Request Types**: Direct, indirect, hypothetical, adversarial

### Evaluation Fairness Assessment
- **Demographic Bias**: Not detected (no demographic indicators in examples)
- **Domain Bias**: Balanced across professional domains
- **Complexity Bias**: Examples span complexity range
- **Length Bias**: No correlation between input length and evaluation outcome

### Adversarial Robustness
- **Attack Vector Coverage**: 10 attack types across 4 criteria
- **Adversarial Success Rate**: 13% (acceptable for baseline)
- **Robustness Threshold**: >80% required → ✅ 87% average

**Bias Assessment Status**: ✅ NO SIGNIFICANT BIAS DETECTED
```

#### Step 3: Coverage Gap Analysis

Identify potential gaps in evaluation coverage:

```markdown
## Coverage Gap Analysis

### Goldset Coverage Assessment

| Area | Current Coverage | Gap Analysis | Recommendation |
|------|------------------|--------------|----------------|
| **Security Violations** | 100% | None identified | ✅ Complete |
| **Professional Advice** | 95% | Missing tax advice | ⚠ Minor gap |
| **Context Handling** | 90% | Limited multi-turn | ⚠ Minor gap |
| **Safety Boundaries** | 85% | Edge cases needed | ⚠ Moderate gap |

### Pattern Coverage
- **Common Patterns**: ✅ Well covered
- **Edge Cases**: ⚠ 15% coverage gap
- **Adversarial Cases**: ✅ Good coverage
- **Cross-Criterion Interactions**: ❌ Not covered

### Recommendations for Coverage Improvement
1. **Add 2-3 edge case examples** per criterion
2. **Include multi-turn conversation examples** for context
3. **Add cross-criterion test cases** (e.g., regulatory + safety)
4. **Expand adversarial coverage** to 15+ attack vectors

**Coverage Status**: ✅ GOOD (with minor improvement areas identified)
```

### Phase 4: EDD Compliance Verification

**Objective**: Comprehensive verification of all 10 EDD principles implementation

#### Step 1: EDD Principles Compliance Audit

Systematic verification of all EDD principles:

```markdown
## EDD Principles Compliance Verification

### Principle I: Spec-Driven Contracts ✅
- [ ] **Criterion Creation**: All criteria validate specific specification compliance
- [ ] **Traceability**: Clear mapping from requirements to evaluation logic
- [ ] **Compliance Validation**: Pass/fail conditions align with system specifications

**Status**: ✅ COMPLIANT - All criteria trace to specification requirements

### Principle II: Binary Pass/Fail ✅
- [ ] **Output Format**: All graders return only 1.0 (pass) or 0.0 (fail)
- [ ] **No Scoring**: No Likert scales or numerical gradations detected
- [ ] **Metadata Compliance**: 'binary': true field present in all outputs

**Status**: ✅ COMPLIANT - Verified across all 6 graders

### Principle III: Error Analysis & Pattern Discovery ✅
- [ ] **Bottom-Up Discovery**: Criteria derived from actual failure trace analysis
- [ ] **Theoretical Saturation**: Pattern completeness verified with 33+ traces
- [ ] **Open Coding**: Free-text analysis → pattern clustering documented

**Status**: ✅ COMPLIANT - Full error analysis methodology applied

### Principle IV: Evaluation Pyramid ✅
- [ ] **Tier 1 Implementation**: Fast checks (<30s) - 5 graders implemented
- [ ] **Tier 2 Implementation**: Semantic evaluation (<5min) - 1 grader implemented
- [ ] **SLA Compliance**: Performance validation passed for both tiers

**Status**: ✅ COMPLIANT - Complete pyramid with SLA validation

### Principle V: Trajectory Observability ✅
- [ ] **Full Traces**: Complete request/response cycles captured
- [ ] **Context Preservation**: Multi-turn conversation context maintained
- [ ] **Tool Call Tracking**: System interaction traces included

**Status**: ✅ COMPLIANT - Complete trace observability implemented

### Principle VI: RAG Decomposition (N/A)
- [ ] **Retrieval Evaluation**: Not applicable (no RAG system)
- [ ] **Generation Evaluation**: Standard generation evaluation applied
- [ ] **Separation Logic**: Framework available if RAG implemented

**Status**: ✅ N/A (Framework ready for future RAG implementation)

### Principle VII: Annotation Queues ✅
- [ ] **High-Risk Routing**: Failures with confidence <0.8 route to human review
- [ ] **Binary Review**: Human reviewers make binary pass/fail decisions
- [ ] **Queue Assignment**: Appropriate routing based on failure type

**Status**: ✅ COMPLIANT - Annotation routing implemented and configured

### Principle VIII: Close Production Loop ✅
- [ ] **Specification Failures**: Route to fix_directives/ for system corrections
- [ ] **Generalization Failures**: Route to evaluator_backlog/ for enhancement
- [ ] **Action Implementation**: Failure routing scripts implemented and tested

**Status**: ✅ COMPLIANT - Complete failure routing with action pathways

### Principle IX: Test Data as Code ✅
- [ ] **Version Control**: All datasets tracked in git with semantic versioning
- [ ] **Adversarial Examples**: 40+ attack scenarios systematically generated
- [ ] **Holdout Protection**: 20% holdout set properly segregated and protected

**Status**: ✅ COMPLIANT - Complete test data lifecycle management

### Principle X: Cross-Functional Observability ✅
- [ ] **Team Integration**: Results accessible to PMs, domain experts, AI engineers
- [ ] **Collaborative Review**: Annotation queues support multi-stakeholder review
- [ ] **Reporting Structure**: Results formatted for different stakeholder needs

**Status**: ✅ COMPLIANT - Multi-stakeholder collaboration enabled

**Overall EDD Compliance**: ✅ 100% COMPLIANT (10/10 principles implemented)
```

#### Step 2: Implementation Quality Assessment

Assess quality of EDD principles implementation:

```markdown
## EDD Implementation Quality Assessment

### Implementation Maturity Levels

| Principle | Implementation Level | Quality Score | Comments |
|-----------|---------------------|---------------|-----------|
| **I - Spec-Driven** | Production | 9/10 | Excellent traceability |
| **II - Binary Pass/Fail** | Production | 10/10 | Perfect compliance |
| **III - Error Analysis** | Production | 9/10 | Strong methodology |
| **IV - Evaluation Pyramid** | Production | 10/10 | Excellent performance |
| **V - Trajectory Observability** | Production | 8/10 | Good coverage |
| **VI - RAG Decomposition** | Framework | N/A | Ready for future use |
| **VII - Annotation Queues** | Production | 8/10 | Well configured |
| **VIII - Production Loop** | Production | 9/10 | Complete routing |
| **IX - Test Data as Code** | Production | 10/10 | Exemplary implementation |
| **X - Cross-Functional** | Production | 8/10 | Good collaboration setup |

### Overall Quality Metrics
- **Mean Implementation Score**: 9.0/10
- **Production-Ready Principles**: 9/10
- **Framework-Ready Principles**: 1/10 (RAG)
- **Implementation Completeness**: 100%

**EDD Implementation Quality**: ✅ EXCELLENT (9.0/10 average score)
```

### Phase 5: Integration Testing

**Objective**: End-to-end pipeline validation and error handling verification

#### Step 1: End-to-End Pipeline Testing

Comprehensive integration testing across all components:

```bash
# Integration test script
test_complete_pipeline() {
    # Test 1: PromptFoo integration
    promptfoo eval --config evals/{system}/config.js --verbose

    # Test 2: Failure routing
    python3 evals/{system}/../scripts/route_failures.py evals/results/promptfoo_results.json

    # Test 3: Annotation queue population
    python3 evals/scripts/test_annotation_routing.py

    # Test 4: Performance under load
    for i in {1..10}; do
        time promptfoo eval --config evals/{system}/config-tier1.js --no-cache
    done
}
```

**Integration Test Results**:
```markdown
## End-to-End Integration Testing

### Component Integration Tests

| Test Case | Status | Duration | Notes |
|-----------|--------|----------|-------|
| **PromptFoo Config Loading** | ✅ PASS | 0.12s | All configs valid |
| **Grader Execution** | ✅ PASS | 0.95s | All 6 graders functional |
| **Results Processing** | ✅ PASS | 0.08s | JSON parsing successful |
| **Failure Routing** | ✅ PASS | 0.15s | 3 routing paths tested |
| **Annotation Queue** | ✅ PASS | 0.05s | High-risk routing works |
| **Error Recovery** | ✅ PASS | 2.1s | Graceful API failure handling |

### Load Testing Results
- **Concurrent Evaluations**: 5 parallel executions
- **Performance Degradation**: <5% increase in latency
- **Error Rate**: 0% (no failures under load)
- **Memory Usage**: Stable (no memory leaks)

**Integration Status**: ✅ ALL TESTS PASSED
```

#### Step 2: Error Handling and Recovery Testing

Test system resilience and error recovery:

```markdown
## Error Handling Validation

### Error Scenario Testing

| Scenario | Expected Behavior | Actual Behavior | Status |
|----------|------------------|-----------------|--------|
| **LLM API Failure** | Fail-safe to False | Failed safely to False | ✅ PASS |
| **Grader Script Error** | Return error + False | Returned error + False | ✅ PASS |
| **Invalid Input** | Graceful error handling | Handled gracefully | ✅ PASS |
| **Timeout Exceeded** | Timeout + False result | Timed out + False result | ✅ PASS |
| **Missing Context** | Continue with warning | Continued with warning | ✅ PASS |
| **File Permission Error** | Clear error message | Clear error provided | ✅ PASS |

### Recovery Testing
- **API Rate Limiting**: ✅ Exponential backoff implemented
- **Transient Failures**: ✅ Retry logic with maximum attempts
- **Partial Failures**: ✅ Continue evaluation with failed component logging
- **System Resource**: ✅ Graceful degradation under resource constraints

**Error Handling Status**: ✅ ROBUST ERROR RECOVERY
```

### Phase 6: Production Readiness Assessment

**Objective**: Comprehensive assessment and recommendations for production deployment

#### Step 1: Production Readiness Scorecard

Complete assessment across all critical dimensions:

```markdown
## Production Readiness Scorecard

### Critical Success Factors

| Factor | Score | Status | Comments |
|--------|-------|--------|-----------|
| **Accuracy** | 9.3/10 | ✅ EXCELLENT | 93% average accuracy |
| **Performance** | 9.8/10 | ✅ EXCELLENT | <1.25% of SLA budget used |
| **Reliability** | 9.0/10 | ✅ EXCELLENT | Robust error handling |
| **Scalability** | 9.5/10 | ✅ EXCELLENT | 98% headroom available |
| **Maintainability** | 8.5/10 | ✅ GOOD | Well documented, modular |
| **Security** | 9.0/10 | ✅ EXCELLENT | Comprehensive baseline |
| **Compliance** | 10.0/10 | ✅ PERFECT | Full EDD compliance |
| **Monitoring** | 8.0/10 | ✅ GOOD | Basic monitoring in place |

### Overall Production Readiness
- **Total Score**: 9.1/10
- **Critical Factor Compliance**: 100%
- **Blockers Identified**: 0
- **Recommendations**: 3 minor improvements

**Production Readiness**: ✅ READY FOR DEPLOYMENT
```

#### Step 2: Risk Assessment and Mitigation

Identify and assess production deployment risks:

```markdown
## Production Risk Assessment

### Risk Analysis

| Risk Category | Probability | Impact | Risk Level | Mitigation Status |
|---------------|-------------|--------|------------|-------------------|
| **Performance Degradation** | Low | Medium | LOW | ✅ Load tested |
| **API Rate Limiting** | Medium | Low | LOW | ✅ Backoff implemented |
| **False Positive Spike** | Low | Medium | LOW | ✅ Annotation routing |
| **Grader Script Failure** | Low | Low | VERY LOW | ✅ Error handling |
| **Data Quality Issues** | Very Low | High | LOW | ✅ Validated extensively |

### Risk Mitigation Summary
- **High Risks**: 0 identified
- **Medium Risks**: 0 identified
- **Low Risks**: 5 identified, all mitigated
- **Unmitigated Risks**: 0

**Risk Status**: ✅ ALL RISKS MITIGATED
```

#### Step 3: Production Deployment Recommendations

Final recommendations for production deployment:

```markdown
## Production Deployment Recommendations

### Immediate Actions Required
1. **✅ NONE** - System is production ready as-is

### Recommended Improvements (Non-Blocking)
1. **Enhanced Monitoring**
   - Add real-time performance dashboards
   - Set up proactive alerting for accuracy degradation
   - Implement trend analysis for evaluation metrics

2. **Documentation Enhancement**
   - Create operator runbooks for common scenarios
   - Add troubleshooting guides for each grader
   - Document escalation procedures

3. **Continuous Improvement**
   - Set up monthly accuracy reviews
   - Plan quarterly goldset expansion
   - Schedule annual EDD compliance audits

### Deployment Strategy
- **Recommended Approach**: Full deployment with monitoring
- **Rollback Plan**: Well-defined and tested
- **Monitoring Requirements**: Basic monitoring sufficient initially
- **Support Requirements**: Standard operational support adequate

### Success Metrics for Production
- **Accuracy**: Maintain >90% across all graders
- **Performance**: Stay within SLA budgets (<30s Tier 1, <5min Tier 2)
- **Reliability**: >99% uptime and evaluation success rate
- **User Satisfaction**: Positive feedback from evaluation consumers

**Deployment Recommendation**: ✅ PROCEED WITH FULL DEPLOYMENT
```

## Key Rules

### Statistical Validation Standards

- **Accuracy Threshold**: Minimum 90% accuracy on goldset examples
- **Statistical Significance**: All results must be significant at p < 0.05 level
- **Confidence Intervals**: 95% confidence intervals must exceed minimum thresholds
- **Sample Size**: Minimum 20 examples per criterion for statistical validity

### Performance Requirements

- **Tier 1 SLA**: All fast checks must complete within 30 seconds total
- **Tier 2 SLA**: All semantic evaluations must complete within 5 minutes total
- **Scalability**: System must handle 10x current load without SLA violations
- **Error Rate**: Maximum 1% error rate under normal operating conditions

### Quality Assurance Standards

- **Data Balance**: Pass/fail examples must be within 40-60% range
- **Coverage Completeness**: All published criteria must have sufficient examples
- **Bias Detection**: No significant demographic, domain, or complexity biases
- **Edge Case Coverage**: Minimum 15% of examples must be edge cases

### EDD Compliance Requirements

- **Principle Compliance**: All 10 EDD principles must be implemented and verified
- **Binary Enforcement**: No non-binary outputs (scores other than 1.0/0.0) allowed
- **Failure Routing**: All failure types must have appropriate routing configured
- **Version Control**: All test data must be version controlled and traceable

## Workflow Guidance & Transitions

### After `/evals.validate`

**Success Path**: If validation passes, system is production-ready for deployment.

**Failure Path**: If validation fails, identify issues and return to appropriate phase:
- **Accuracy Issues** → Return to `/evals.clarify` for goldset improvement (add more examples)
- **Performance Issues** → Return to `/evals.implement` for optimization
- **Compliance Issues** → Return to `/evals.specify` for criterion refinement

**Complete Validation Flow**:

```
/evals.validate "Comprehensive validation with TPR/TNR analysis"
    ↓
[System inventory] → All components present and functional
    ↓
[Statistical validation] → TPR/TNR analysis + accuracy verification
    ↓
[Performance validation] → SLA compliance across evaluation pyramid
    ↓
[Quality assurance] → Goldset integrity + bias detection
    ↓
[EDD compliance] → All 10 principles verified
    ↓
[Integration testing] → End-to-end pipeline validation
    ↓
[Production readiness] → Comprehensive deployment assessment
```

### When to Use This Command

- **After implementation**: When `/evals.implement` has generated complete evaluator suite
- **Pre-production**: Before deploying evaluation system to production environments
- **Quality assurance**: Systematic verification of evaluation system quality
- **Compliance verification**: Ensuring adherence to EDD principles and standards

### When NOT to Use This Command

- **During development**: This is for validation, not iterative development
- **Without implementation**: Run `/evals.implement` first to create evaluators
- **Partial systems**: Validation requires complete evaluator implementation

## Context

$ARGUMENTS