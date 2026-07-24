# Goldset Record Lifecycle Template

This template supports the **Draft → Accept → Published** lifecycle for goldset records following EDD principles.

---

## Draft Phase (evals-specify)

**Status**: `draft`
**Location**: `.adlc/drafts/evals/EVAL-{{ID}}.md`
**Purpose**: Bottom-up pattern discovery from error analysis

```yaml
---
id: eval-{{ID}}
status: draft
name: {{DRAFT_NAME}}
description: {{DRAFT_DESCRIPTION}}

# Binary pass/fail only (EDD Principle II)
pass_condition: {{DRAFT_PASS_CONDITION}}
fail_condition: {{DRAFT_FAIL_CONDITION}}

# Failure type gate (EDD Principle VIII) - Initial assessment
failure_type:
  {{INITIAL_FAILURE_TYPE}}:
    action: {{INITIAL_ACTION}}
    confidence: {{INITIAL_CONFIDENCE}} # low | medium | high

# Error analysis provenance (EDD Principle III)
error_analysis:
  traces_analyzed: {{DRAFT_TRACES_COUNT}}
  theoretical_saturation: false  # Always false in draft phase
  open_coding_notes: |
    {{OPEN_CODING_NOTES}}

    Pattern observations:
    - {{PATTERN_1}}
    - {{PATTERN_2}}
    - {{PATTERN_3}}

# Test data hygiene (EDD Principle IX) - Preliminary
test_data:
  adversarial_included: false  # Added in analyze phase
  holdout_ratio: 0.2

# Draft quality indicators
draft_quality:
  evidence_strength: {{EVIDENCE_STRENGTH}} # weak | medium | strong
  pattern_clarity: {{PATTERN_CLARITY}} # unclear | emerging | clear
  implementation_feasible: {{IMPLEMENTATION_FEASIBLE}} # unknown | maybe | yes
---

# Draft Evaluation Criterion: {{DRAFT_NAME}}

## Error Analysis Notes (Open Coding)

### Pattern Discovery Process
**Analysis Date**: {{ANALYSIS_DATE}}
**Analyst**: {{ANALYST_NAME}}
**Traces Source**: {{TRACES_SOURCE}}
**Analysis Method**: {{ANALYSIS_METHOD}}

### Raw Observations
{{RAW_OBSERVATIONS}}

### Emerging Patterns
{{EMERGING_PATTERNS}}

### Questions for Clarification
- {{QUESTION_1}}
- {{QUESTION_2}}
- {{QUESTION_3}}

### Implementation Uncertainties
- {{UNCERTAINTY_1}}
- {{UNCERTAINTY_2}}
```

---

## Accepted Phase (evals-clarify)

**Status**: `accepted`
**Location**: `.adlc/drafts/evals/EVAL-{{ID}}.md` (updated)
**Purpose**: Axial coding and refinement through clustering

```yaml
---
id: eval-{{ID}}
status: accepted
name: {{REFINED_NAME}}
description: {{REFINED_DESCRIPTION}}

# Binary pass/fail only (EDD Principle II) - Refined
pass_condition: {{REFINED_PASS_CONDITION}}
fail_condition: {{REFINED_FAIL_CONDITION}}

# Failure type gate (EDD Principle VIII) - Confirmed
failure_type:
  {{CONFIRMED_FAILURE_TYPE}}:
    action: {{CONFIRMED_ACTION}}
    confidence: high
    rationale: {{FAILURE_TYPE_RATIONALE}}

# Error analysis provenance (EDD Principle III)
error_analysis:
  traces_analyzed: {{ACCEPTED_TRACES_COUNT}}
  theoretical_saturation: {{SATURATION_STATUS}} # true if sufficient
  axial_coding_complete: true
  pattern_relationships: |
    {{AXIAL_CODING_RESULTS}}

# Test data hygiene (EDD Principle IX) - Enhanced
test_data:
  adversarial_included: false  # Still pending analyze phase
  holdout_ratio: 0.2
  example_balance: balanced  # pass/fail ratio ~50/50

# Acceptance criteria met
acceptance_criteria:
  evidence_sufficient: true
  pattern_clear: true
  implementation_feasible: true
  binary_evaluable: true
  no_overlapping_criteria: true

# Clustering information (from axial coding)
clustering:
  related_patterns: [{{RELATED_PATTERN_1}}, {{RELATED_PATTERN_2}}]
  cluster_assignment: {{CLUSTER_NAME}}
  cluster_rationale: {{CLUSTER_RATIONALE}}
---

# Accepted Evaluation Criterion: {{REFINED_NAME}}

## Axial Coding Results

### Pattern Relationships
{{PATTERN_RELATIONSHIPS}}

### Central Phenomenon
{{CENTRAL_PHENOMENON}}

### Causal Conditions
{{CAUSAL_CONDITIONS}}

### Clustering Decision
**Cluster**: {{CLUSTER_ASSIGNMENT}}
**Rationale**: {{CLUSTERING_RATIONALE}}
**Related Criteria**: {{RELATED_CRITERIA}}

## Refined Examples

### Pass Examples (Validated)
{{VALIDATED_PASS_EXAMPLES}}

### Fail Examples (Validated)
{{VALIDATED_FAIL_EXAMPLES}}

## Implementation Plan
{{IMPLEMENTATION_PLAN}}

## Acceptance Review
- [ ] Pattern clarity: Clear and distinct
- [ ] Implementation feasibility: Confirmed
- [ ] Binary evaluability: Pass/fail determinable
- [ ] No criterion overlap: Validated
- [ ] Evidence sufficiency: Met threshold
```

---

## Published Phase (evals-analyze → goldset.md)

**Status**: `published`
**Location**: `evals/{{system}}/goldset.md`
**Purpose**: Production-ready evaluation criterion with full analysis

```yaml
---
id: eval-{{ID}}
status: published
name: {{FINAL_NAME}}
description: {{FINAL_DESCRIPTION}}

# Binary pass/fail only (EDD Principle II) - Final
pass_condition: {{FINAL_PASS_CONDITION}}
fail_condition: {{FINAL_FAIL_CONDITION}}

# Failure type gate (EDD Principle VIII) - Production ready
failure_type:
  {{FINAL_FAILURE_TYPE}}:
    action: {{FINAL_ACTION}}
    confidence: high
    implementation_priority: {{PRIORITY}}

# Error analysis provenance (EDD Principle III) - Complete
error_analysis:
  traces_analyzed: {{FINAL_TRACES_COUNT}}
  theoretical_saturation: true
  analysis_complete: true
  confidence_level: {{FINAL_CONFIDENCE}}

# Test data hygiene (EDD Principle IX) - Production ready
test_data:
  adversarial_included: true
  adversarial_count: {{ADVERSARIAL_COUNT}}
  holdout_ratio: 0.2
  holdout_count: {{HOLDOUT_COUNT}}
  version_controlled: true

# Implementation details
implementation:
  evaluator_type: {{EVALUATOR_TYPE}}
  tier: {{TIER}}
  grader_file: {{GRADER_FILENAME}}
  performance_sla: {{PERFORMANCE_SLA}}

# Quality metrics
quality_metrics:
  goldset_accuracy: {{GOLDSET_ACCURACY}}
  adversarial_robustness: {{ADVERSARIAL_ROBUSTNESS}}
  false_positive_rate: {{FALSE_POSITIVE_RATE}}
  false_negative_rate: {{FALSE_NEGATIVE_RATE}}

# Production metadata
production:
  published_date: {{PUBLISHED_DATE}}
  version: {{VERSION}}
  last_updated: {{LAST_UPDATED}}
  maintenance_owner: {{MAINTENANCE_OWNER}}
---

# {{FINAL_NAME}}

## Production Summary

**Criterion ID**: eval-{{ID}}
**Implementation**: {{EVALUATOR_TYPE}} ({{TIER}})
**Performance**: {{PERFORMANCE_SUMMARY}}
**Accuracy**: {{ACCURACY_SUMMARY}}

## Complete Analysis

### Error Analysis Provenance (EDD Principle III)
- **Total Traces Analyzed**: {{FINAL_TRACES_COUNT}}
- **Analysis Methods**: Open coding → Axial coding → Theoretical saturation
- **Confidence Level**: {{FINAL_CONFIDENCE}}
- **Pattern Stability**: {{PATTERN_STABILITY}}

### Examples (Version {{EXAMPLES_VERSION}})

#### Training Examples ({{TRAINING_COUNT}})
{{TRAINING_EXAMPLES}}

#### Holdout Examples ({{HOLDOUT_COUNT}} - Reserved)
*Held out for unbiased validation*

#### Adversarial Examples ({{ADVERSARIAL_COUNT}})
{{ADVERSARIAL_EXAMPLES}}

## Implementation Details

### Evaluator Configuration
- **Type**: {{EVALUATOR_TYPE}}
- **Tier**: {{TIER}} (SLA: {{SLA_REQUIREMENT}})
- **Grader**: `{{GRADER_FILENAME}}`
- **Dependencies**: {{DEPENDENCIES}}

### Performance Characteristics
- **Execution Time**: {{EXECUTION_TIME}}
- **Accuracy**: {{ACCURACY_METRICS}}
- **Resource Usage**: {{RESOURCE_USAGE}}
- **Cost**: {{COST_ESTIMATE}}

### Integration Status
- **PromptFoo**: ✅ Integrated
- **CI/CD Pipeline**: ✅ {{PIPELINE_STATUS}}
- **Monitoring**: ✅ {{MONITORING_STATUS}}
- **Failure Routing**: ✅ {{ROUTING_STATUS}}

## Quality Assurance

### Validation Results
- **Goldset Validation**: {{GOLDSET_RESULTS}}
- **Holdout Validation**: {{HOLDOUT_RESULTS}}
- **Adversarial Robustness**: {{ADVERSARIAL_RESULTS}}
- **Cross-Validation**: {{CROSS_VALIDATION_RESULTS}}

### Error Analysis
- **False Positives**: {{FP_ANALYSIS}}
- **False Negatives**: {{FN_ANALYSIS}}
- **Edge Cases**: {{EDGE_CASE_ANALYSIS}}
- **Mitigation Strategies**: {{MITIGATION_STRATEGIES}}

## Maintenance Record

### Version History
- **v1.0**: {{VERSION_1_CHANGES}}
- **v1.1**: {{VERSION_2_CHANGES}}
- **v1.2**: {{VERSION_3_CHANGES}}

### Update History
- {{UPDATE_1_DATE}}: {{UPDATE_1_DESCRIPTION}}
- {{UPDATE_2_DATE}}: {{UPDATE_2_DESCRIPTION}}

### Review Schedule
- **Last Review**: {{LAST_REVIEW_DATE}}
- **Next Review**: {{NEXT_REVIEW_DATE}}
- **Review Frequency**: {{REVIEW_FREQUENCY}}

## EDD Compliance Verification

### All Principles Met ✅
- **I - Spec-Driven**: ✅ {{SPEC_COMPLIANCE}}
- **II - Binary Pass/Fail**: ✅ {{BINARY_COMPLIANCE}}
- **III - Error Analysis**: ✅ {{ANALYSIS_COMPLIANCE}}
- **VIII - Production Loop**: ✅ {{LOOP_COMPLIANCE}}
- **IX - Test Data as Code**: ✅ {{DATA_COMPLIANCE}}
```

---

## Lifecycle State Transitions

### Draft → Accepted Criteria
- [ ] **Evidence Sufficiency**: Minimum {{MIN_TRACES}} traces analyzed
- [ ] **Pattern Clarity**: Failure mode clearly defined and distinct
- [ ] **Binary Evaluability**: Pass/fail conditions are deterministic
- [ ] **Implementation Feasibility**: Technical approach identified
- [ ] **No Overlap**: Does not duplicate existing criteria

### Accepted → Published Criteria
- [ ] **Theoretical Saturation**: Confirmed with additional trace analysis
- [ ] **Adversarial Coverage**: Attack scenarios identified and included
- [ ] **Holdout Preparation**: Reserved test set created and protected
- [ ] **Implementation Complete**: Grader developed and tested
- [ ] **Quality Validation**: Accuracy thresholds met on goldset
- [ ] **Integration Ready**: Pipeline and monitoring configured

### Quality Gates

#### Draft Quality Gate
**Minimum Requirements**:
- Evidence from ≥3 failure traces
- Clear failure pattern description
- Initial pass/fail conditions defined
- Feasibility assessment complete

#### Acceptance Quality Gate
**Validation Requirements**:
- Axial coding relationships documented
- Examples balanced (pass/fail ~50/50)
- Implementation approach confirmed
- No overlap with existing criteria
- Cluster assignment justified

#### Publication Quality Gate
**Production Readiness**:
- Theoretical saturation verified
- Adversarial examples included
- Holdout set properly segregated
- Grader accuracy >90% on goldset
- Performance meets tier SLA requirements
- Integration testing complete
- Failure routing configured

---

*This lifecycle template ensures systematic progression from pattern discovery to production-ready evaluation following all EDD principles.*