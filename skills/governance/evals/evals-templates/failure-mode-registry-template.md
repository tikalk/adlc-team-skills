# Failure Mode Registry

**System**: {{SYSTEM}}
**Generated**: {{TIMESTAMP}}
**Version**: {{VERSION}}

This registry maintains a bottom-up taxonomy of discovered failure modes following EDD Principle III (Error Analysis & Pattern Discovery).

## Registry Structure

Each failure mode is discovered through systematic error analysis and represents a distinct pattern of system failure that requires evaluation coverage.

---

## Failure Mode: {{FAILURE_MODE_ID}}

**Name**: {{FAILURE_MODE_NAME}}
**Category**: {{CATEGORY}} (Security | Quality | Compliance | Performance)
**Discovery Date**: {{DISCOVERY_DATE}}
**Status**: {{STATUS}} (Active | Resolved | Deprecated)

### Pattern Description

**Manifestation**: How this failure mode typically appears in system outputs
{{PATTERN_DESCRIPTION}}

**Frequency**: {{FREQUENCY_DESCRIPTION}}
**Severity**: {{SEVERITY}} (Critical | High | Medium | Low)

### Evidence Base

**Source Traces**: {{TRACE_COUNT}} traces analyzed
**First Observed**: {{FIRST_OBSERVATION_DATE}}
**Last Observed**: {{LAST_OBSERVATION_DATE}}

**Representative Examples**:
1. Trace ID: {{TRACE_ID_1}} - {{BRIEF_DESCRIPTION_1}}
2. Trace ID: {{TRACE_ID_2}} - {{BRIEF_DESCRIPTION_2}}
3. Trace ID: {{TRACE_ID_3}} - {{BRIEF_DESCRIPTION_3}}

### Root Cause Analysis

**Primary Causes**:
- {{ROOT_CAUSE_1}}
- {{ROOT_CAUSE_2}}

**Contributing Factors**:
- {{CONTRIBUTING_FACTOR_1}}
- {{CONTRIBUTING_FACTOR_2}}

**Environmental Conditions**:
- {{CONDITION_1}}
- {{CONDITION_2}}

### Impact Assessment

**User Impact**: {{USER_IMPACT_DESCRIPTION}}
**Business Impact**: {{BUSINESS_IMPACT_DESCRIPTION}}
**Risk Level**: {{RISK_LEVEL}} (Critical | High | Medium | Low)

**Affected User Segments**:
- {{SEGMENT_1}}
- {{SEGMENT_2}}

### Evaluation Coverage

**Criterion**: {{EVALUATION_CRITERION_ID}}
**Evaluator Type**: {{EVALUATOR_TYPE}} (code-based | llm-judge | hybrid)
**Detection Confidence**: {{CONFIDENCE_LEVEL}}%

**Pass Condition**: {{PASS_CONDITION}}
**Fail Condition**: {{FAIL_CONDITION}}

### Failure Type Classification (EDD Principle VIII)

**Classification**: {{FAILURE_TYPE}} (specification_failure | generalization_failure)

**Rationale**: {{CLASSIFICATION_RATIONALE}}

**Routing Action**:
- **Specification Failure** → Fix Directive: {{FIX_DIRECTIVE_PATH}}
- **Generalization Failure** → Build Evaluator: {{EVALUATOR_BACKLOG_ITEM}}

### Related Failure Modes

**Similar Patterns**:
- {{RELATED_MODE_1}}: {{RELATIONSHIP_1}}
- {{RELATED_MODE_2}}: {{RELATIONSHIP_2}}

**Dependencies**:
- **Depends on**: {{DEPENDENCY_1}}
- **Blocks**: {{BLOCKED_MODE_1}}

### Mitigation Status

**Prevention Measures**:
- {{PREVENTION_MEASURE_1}} (Status: {{STATUS_1}})
- {{PREVENTION_MEASURE_2}} (Status: {{STATUS_2}})

**Detection Measures**:
- {{DETECTION_MEASURE_1}} (Coverage: {{COVERAGE_1}}%)
- {{DETECTION_MEASURE_2}} (Coverage: {{COVERAGE_2}}%)

**Response Measures**:
- {{RESPONSE_MEASURE_1}}
- {{RESPONSE_MEASURE_2}}

### Historical Evolution

**Pattern Evolution**:
{{PATTERN_EVOLUTION_DESCRIPTION}}

**Mitigation Evolution**:
{{MITIGATION_EVOLUTION_DESCRIPTION}}

**Version History**:
- v1.0: {{VERSION_1_CHANGES}}
- v1.1: {{VERSION_2_CHANGES}}

---

## Registry Metadata

### Discovery Statistics

**Total Failure Modes**: {{TOTAL_COUNT}}
**Active Modes**: {{ACTIVE_COUNT}}
**Resolved Modes**: {{RESOLVED_COUNT}}

### Category Distribution
- **Security**: {{SECURITY_COUNT}} modes
- **Quality**: {{QUALITY_COUNT}} modes
- **Compliance**: {{COMPLIANCE_COUNT}} modes
- **Performance**: {{PERFORMANCE_COUNT}} modes

### Severity Distribution
- **Critical**: {{CRITICAL_COUNT}} modes
- **High**: {{HIGH_COUNT}} modes
- **Medium**: {{MEDIUM_COUNT}} modes
- **Low**: {{LOW_COUNT}} modes

### EDD Principle VIII: Failure Type Distribution
- **Specification Failures**: {{SPEC_FAILURE_COUNT}} modes → Fix directives
- **Generalization Failures**: {{GEN_FAILURE_COUNT}} modes → Build evaluators

### Coverage Metrics
- **Fully Covered**: {{COVERED_COUNT}} modes ({{COVERAGE_PERCENTAGE}}%)
- **Partially Covered**: {{PARTIAL_COUNT}} modes
- **Uncovered**: {{UNCOVERED_COUNT}} modes

### Theoretical Saturation Status

**Last Analysis Date**: {{LAST_ANALYSIS_DATE}}
**Traces Analyzed Since Last New Mode**: {{TRACES_SINCE_NEW}}
**Saturation Confidence**: {{SATURATION_CONFIDENCE}} (High | Medium | Low)

**Indicators of Saturation**:
- ✅ No new failure modes discovered in last {{TIME_PERIOD}}
- ✅ Pattern variations are minor, not fundamental
- ✅ New traces fit existing mode categories
- ✅ Analyst confidence high for identified patterns

### Data Quality Metrics

**Evidence Strength**:
- **Strong Evidence** (5+ traces): {{STRONG_EVIDENCE_COUNT}} modes
- **Medium Evidence** (2-4 traces): {{MEDIUM_EVIDENCE_COUNT}} modes
- **Weak Evidence** (1 trace): {{WEAK_EVIDENCE_COUNT}} modes

**Trace Quality**:
- **Complete Context**: {{COMPLETE_CONTEXT_PERCENTAGE}}%
- **User Intent Clear**: {{CLEAR_INTENT_PERCENTAGE}}%
- **System Response Complete**: {{COMPLETE_RESPONSE_PERCENTAGE}}%

### Registry Maintenance

**Last Updated**: {{LAST_UPDATED}}
**Next Review Date**: {{NEXT_REVIEW_DATE}}
**Maintenance Frequency**: {{MAINTENANCE_FREQUENCY}}

**Maintenance Actions**:
- [ ] Review resolved modes for deprecation
- [ ] Update active modes with new traces
- [ ] Assess coverage gaps
- [ ] Update severity ratings based on recent incidents

### Integration Status

**Goldset Integration**: {{GOLDSET_INTEGRATION_STATUS}}
**Evaluator Coverage**: {{EVALUATOR_COVERAGE_PERCENTAGE}}%
**CI/CD Integration**: {{CICD_INTEGRATION_STATUS}}

**Outstanding Integration Tasks**:
- [ ] {{INTEGRATION_TASK_1}}
- [ ] {{INTEGRATION_TASK_2}}

---

## Registry Usage Guidelines

### For Error Analysis (EDD Principle III)
1. **Adding New Modes**: Discovered through systematic trace analysis, not theoretical prediction
2. **Evidence Requirements**: Minimum 2 traces with complete context
3. **Pattern Validation**: Confirmed through independent analysis
4. **Theoretical Saturation**: Track when no new modes emerge from additional traces

### For Evaluator Development (EDD Principle VIII)
1. **Specification Failures**: Direct mapping to system behavior fixes
2. **Generalization Failures**: Build continuous evaluation capabilities
3. **Binary Assessment**: All modes must support pass/fail evaluation
4. **Coverage Tracking**: Ensure all active modes have evaluation coverage

### for Production Monitoring (EDD Principle V)
1. **Trajectory Observability**: Full trace context for each failure instance
2. **Pattern Monitoring**: Track mode frequency and evolution over time
3. **Early Warning**: Detect emergence of new failure patterns
4. **Response Coordination**: Connect modes to appropriate response teams

### Quality Assurance
1. **Regular Review**: Monthly assessment of active modes
2. **Evidence Updates**: Continuous addition of supporting traces
3. **Classification Accuracy**: Periodic validation of failure type assignments
4. **Coverage Assessment**: Quarterly evaluation of registry completeness

---

*This registry follows EDD principles for systematic failure mode discovery and management. All modes are discovered bottom-up from actual system failures, not theoretical speculation.*