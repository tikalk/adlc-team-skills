---
id: {{CRITERION_ID}}
status: {{STATUS}}  # draft | accepted | published
name: {{CRITERION_NAME}}
description: {{DESCRIPTION}}

# Binary pass/fail only (EDD Principle II)
pass_condition: {{PASS_CONDITION}}
fail_condition: {{FAIL_CONDITION}}

# Failure type gate (EDD Principle VIII)
failure_type:
  {{FAILURE_TYPE}}: # specification_failure | generalization_failure
    action: {{ACTION}} # fix_directive | build_evaluator
    {{#if_generalization_failure}}evaluator_type: {{EVALUATOR_TYPE}} # code-based | llm-judge{{/if_generalization_failure}}

# Error analysis provenance (EDD Principle III)
error_analysis:
  traces_analyzed: {{TRACES_ANALYZED}}
  theoretical_saturation: {{SATURATION_STATUS}} # true | false
  open_coding_notes: |
    {{OPEN_CODING_NOTES}}

# Test data hygiene (EDD Principle IX)
test_data:
  adversarial_included: {{ADVERSARIAL_STATUS}} # true | false
  holdout_ratio: {{HOLDOUT_RATIO}}

# RAG decomposition (EDD Principle VI, optional)
{{#if_rag_system}}
rag_decomposition:
  retrieval_check: {{RETRIEVAL_CHECK}} # ir-metrics | llm-judge | none
  generation_check: {{GENERATION_CHECK}} # llm-judge | none
{{/if_rag_system}}

# Implementation details
implementation:
  evaluator_type: {{EVALUATOR_TYPE}} # code-based | llm-judge | hybrid
  tier: {{TIER}} # 1 | 2 | hybrid
  complexity: {{COMPLEXITY}} # low | medium | high
  automation_feasible: {{AUTOMATION_FEASIBLE}} # true | false
---

# {{CRITERION_NAME}}

## Error Analysis Notes

### Pattern Discovery
{{PATTERN_DISCOVERY_DESCRIPTION}}

**Discovery Method**: {{DISCOVERY_METHOD}} (Bottom-up trace analysis | User reports | Testing)
**Frequency**: {{FAILURE_FREQUENCY}} ({{FREQUENCY_PERCENTAGE}}% of analyzed traces)
**Severity**: {{SEVERITY_LEVEL}} (Critical | High | Medium | Low)
**Detectability**: {{DETECTABILITY}} (High | Medium | Low)

### Open Coding Observations

{{#each_trace}}
**Trace {{TRACE_ID}} - {{TRACE_SOURCE}}**:
- Input: {{TRACE_INPUT}}
- Output: {{TRACE_OUTPUT}}
- Failure: {{FAILURE_DESCRIPTION}}
- Notes: {{ANALYSIS_NOTES}}

{{/each_trace}}

### Pattern Clustering (Axial Coding)
{{AXIAL_CODING_RESULTS}}

**Central Phenomenon**: {{CENTRAL_PHENOMENON}}
**Causal Conditions**: {{CAUSAL_CONDITIONS}}
**Contextual Factors**: {{CONTEXTUAL_FACTORS}}
**Intervening Conditions**: {{INTERVENING_CONDITIONS}}
**Consequences**: {{CONSEQUENCES}}

## Examples

### Pass Examples

{{#each_pass_example}}
#### Pass Example {{EXAMPLE_NUMBER}}
```
Input: {{PASS_INPUT}}
Context: {{PASS_CONTEXT}}
Expected Output: {{PASS_OUTPUT}}
```
**Why it passes**: {{PASS_REASON}}
**Key compliance factors**: {{COMPLIANCE_FACTORS}}

{{/each_pass_example}}

### Fail Examples

{{#each_fail_example}}
#### Fail Example {{EXAMPLE_NUMBER}}
```
Input: {{FAIL_INPUT}}
Context: {{FAIL_CONTEXT}}
Actual Output: {{FAIL_OUTPUT}}
```
**Why it fails**: {{FAIL_REASON}}
**Violation specifics**: {{VIOLATION_SPECIFICS}}

{{/each_fail_example}}

### Adversarial Examples

{{#each_adversarial_example}}
#### Adversarial Example {{EXAMPLE_NUMBER}}
**Attack Vector**: {{ATTACK_VECTOR}}
```
Input: {{ADVERSARIAL_INPUT}}
Context: {{ADVERSARIAL_CONTEXT}}
Expected: FAIL
```
**Attack Method**: {{ATTACK_METHOD}}
**Detection Strategy**: {{DETECTION_STRATEGY}}

{{/each_adversarial_example}}

## Implementation Notes

### Evaluation Method
- **Primary Type**: {{PRIMARY_EVALUATOR_TYPE}}
- **Fallback Method**: {{FALLBACK_METHOD}}
- **Hybrid Approach**: {{HYBRID_DESCRIPTION}}

### Technical Implementation

{{#if_code_based}}
#### Code-Based Patterns
**Failure Patterns**:
```regex
{{FAILURE_PATTERN_1}}
{{FAILURE_PATTERN_2}}
{{FAILURE_PATTERN_3}}
```

**Success Indicators**:
```regex
{{SUCCESS_PATTERN_1}}
{{SUCCESS_PATTERN_2}}
```

**Implementation Complexity**: {{CODE_COMPLEXITY}}
**Expected Accuracy**: {{CODE_ACCURACY}}%
**Performance**: {{CODE_PERFORMANCE}} (execution time)
{{/if_code_based}}

{{#if_llm_judge}}
#### LLM-Judge Configuration
**Model Requirements**: {{LLM_MODEL_REQUIREMENTS}}
**Prompt Strategy**: {{PROMPT_STRATEGY}}
**Temperature Setting**: {{TEMPERATURE_SETTING}}
**Max Tokens**: {{MAX_TOKENS}}

**Structured Prompt Template**:
```
{{LLM_PROMPT_TEMPLATE}}
```

**Expected Accuracy**: {{LLM_ACCURACY}}%
**Performance**: {{LLM_PERFORMANCE}} (API latency + processing)
**Cost Estimation**: {{COST_ESTIMATION}} per evaluation
{{/if_llm_judge}}

{{#if_hybrid}}
#### Hybrid Approach
**Tier 1 (Fast)**: {{TIER1_METHOD}}
- Patterns: {{TIER1_PATTERNS}}
- Performance: {{TIER1_PERFORMANCE}}
- Coverage: {{TIER1_COVERAGE}}%

**Tier 2 (Semantic)**: {{TIER2_METHOD}}
- Triggers: {{TIER2_TRIGGERS}}
- Performance: {{TIER2_PERFORMANCE}}
- Coverage: {{TIER2_COVERAGE}}%

**Overall Strategy**: {{HYBRID_STRATEGY}}
{{/if_hybrid}}

### Error Handling
**API Failures**: {{API_ERROR_HANDLING}}
**Timeout Strategy**: {{TIMEOUT_STRATEGY}}
**Fallback Behavior**: {{FALLBACK_BEHAVIOR}}
**Fail-Safe Mode**: {{FAILSAFE_MODE}}

### Performance Requirements
- **Tier Assignment**: {{ASSIGNED_TIER}}
- **SLA Requirement**: {{SLA_REQUIREMENT}}
- **Parallel Execution**: {{PARALLEL_CAPABILITY}}
- **Resource Requirements**: {{RESOURCE_REQUIREMENTS}}

## Quality Assurance

### Validation Results
**Goldset Accuracy**: {{GOLDSET_ACCURACY}}% ({{CORRECT_COUNT}}/{{TOTAL_COUNT}})
**Pass Example Success**: {{PASS_SUCCESS}}% ({{PASS_CORRECT}}/{{PASS_TOTAL}})
**Fail Example Success**: {{FAIL_SUCCESS}}% ({{FAIL_CORRECT}}/{{FAIL_TOTAL}})
**Adversarial Robustness**: {{ADVERSARIAL_ROBUSTNESS}}% ({{ADV_CORRECT}}/{{ADV_TOTAL}})

### Edge Case Analysis
{{EDGE_CASE_ANALYSIS}}

### False Positive/Negative Analysis
**False Positives**: {{FALSE_POSITIVE_COUNT}} cases
- {{FALSE_POSITIVE_EXAMPLE_1}}
- {{FALSE_POSITIVE_EXAMPLE_2}}

**False Negatives**: {{FALSE_NEGATIVE_COUNT}} cases
- {{FALSE_NEGATIVE_EXAMPLE_1}}
- {{FALSE_NEGATIVE_EXAMPLE_2}}

**Mitigation Strategies**: {{MITIGATION_STRATEGIES}}

## EDD Principle Compliance

### Principle I: Spec-Driven Contracts ✅
- [ ] Criterion validates specific specification compliance
- [ ] Clear traceability from spec to evaluation logic
- [ ] Pass/fail conditions align with requirements

### Principle II: Binary Pass/Fail ✅
- [ ] No Likert scales or numerical scoring
- [ ] All examples demonstrate clear binary outcomes
- [ ] Grader outputs only 1.0 (pass) or 0.0 (fail)

### Principle III: Error Analysis & Pattern Discovery ✅
- [ ] Bottom-up discovery from actual failure traces
- [ ] Open coding → axial coding methodology applied
- [ ] Theoretical saturation achieved ({{TRACES_ANALYZED}}+ traces)

### Principle VIII: Close Production Loop ✅
- [ ] Failure type correctly classified ({{FAILURE_TYPE}})
- [ ] Appropriate action routing configured
- [ ] Clear path from evaluation to resolution

### Principle IX: Test Data as Code ✅
- [ ] Examples version-controlled and traceable
- [ ] Adversarial scenarios included
- [ ] Holdout data properly segregated

## Integration Status

### Goldset Integration
- [ ] Criterion accepted into published goldset
- [ ] Examples validated and balanced
- [ ] Metadata complete and consistent

### Evaluator Implementation
- [ ] Grader script generated and tested
- [ ] PromptFoo configuration updated
- [ ] Failure routing configured

### CI/CD Integration
- [ ] Tier assignment appropriate for SLA
- [ ] Pipeline integration tested
- [ ] Error handling verified

### Monitoring Setup
- [ ] Metrics collection configured
- [ ] Alerting thresholds set
- [ ] Dashboard integration complete

## Maintenance

### Review Schedule
- **Next Review**: {{NEXT_REVIEW_DATE}}
- **Review Frequency**: {{REVIEW_FREQUENCY}}
- **Maintenance Owner**: {{MAINTENANCE_OWNER}}

### Update Triggers
- [ ] New failure patterns observed
- [ ] Accuracy degradation detected
- [ ] False positive/negative rate increase
- [ ] Performance regression

### Deprecation Criteria
- [ ] Underlying system behavior changed
- [ ] No failures observed for {{DEPRECATION_PERIOD}}
- [ ] Superseded by more comprehensive criterion
- [ ] Cost/benefit analysis suggests removal

---

*This criterion follows EDD principles for systematic evaluation development. All patterns discovered through bottom-up error analysis, not theoretical speculation.*