---
description: Generate execution traces + analysis reports from evals/results/ → optional
  PR to team-ai-directives
scripts:
  sh: .specify/scripts/bash/setup-evals.sh "trace {ARGS}"
  ps: .specify/scripts/powershell/setup-evals.ps1 "trace {ARGS}"
---


<!-- Extension: evals -->
<!-- Config: .specify/extensions/evals/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"Analyze high-risk trajectories and create team insights PR"`
- `"Process annotation queue with focus on regulatory compliance failures"`
- `"Full trajectory analysis with cross-functional insights for product team"`
- `"Scan for generalization failures and create evaluator backlog"`
- `"Emergency analysis - focus on specification failures requiring immediate fixes"`
- Empty input: Run comprehensive trajectory analysis and create standard team insights PR

When users provide specific focus areas or analysis scope, prioritize those areas in the trajectory analysis and insights generation.

## Goal

**Cross-functional team elevation** through comprehensive trajectory analysis, annotation queue processing, and actionable insights delivery following **EDD principles** for production loop closure and observability.

**Output**:

1. **Trajectory Analysis** - Full multi-turn trace analysis with tool calls and context preservation
2. **Annotation Queue Processing** - High-risk routing and binary human review integration
3. **Pattern Discovery** - Failure mode clustering and trend identification
4. **Actionable Insights** - Specification fixes and generalization improvements
5. **Cross-Functional PR** - Structured insights for PMs, domain experts, and AI engineers
6. **Production Loop Closure** - Route findings to appropriate improvement pathways

**Key EDD Principles Applied**:

- **Principle V**: Trajectory Observability - Full multi-turn traces, not just outputs
- **Principle VII**: Annotation Queues - Route high-risk traces to humans for binary review
- **Principle VIII**: Close Production Loop - Spec failures → fix directives; Gen failures → evaluator backlog
- **Principle X**: Cross-Functional Observability - PMs, domain experts, and AI engineers collaborate

### Flags

- `--results-path PATH`: Custom path to evaluation results (default: evals/results/)
- `--annotation-queue PATH`: Path to annotation queue files
- `--target-branch BRANCH`: Target branch for insights PR (default: main)
- `--focus AREA`: Focus analysis on specific area (security,regulatory,performance,quality)
- `--threshold CONFIDENCE`: Risk threshold for high-priority routing (default: 0.8)
- `--dry-run`: Generate insights without creating PR
- `--json`: Output structured JSON for programmatic integration

## Role & Context

You are acting as a **Production Intelligence Analyst** conducting comprehensive evaluation system analysis for cross-functional team elevation. Your role involves:

- **Trajectory Analysis**: Deep analysis of full conversation traces including tool calls and context
- **Risk Assessment**: Identifying high-risk patterns requiring human annotation and review
- **Pattern Discovery**: Bottom-up failure mode identification and trend analysis
- **Insight Generation**: Translating technical findings into actionable recommendations
- **Cross-Functional Communication**: Creating insights tailored for different stakeholder groups

### Trace vs Validate

| Phase | Focus | Input | Output |
|-------|-------|-------|--------|
| **Validate** (/evals.validate) | Eval system quality | Implemented evaluators | Test results + quality metrics |
| **Trace** (this command) | Production insights | Evaluation results | Execution traces + analysis reports |

## Outline

1. **Results Discovery** (Phase 0): Comprehensive assessment of evaluation results and annotation queues
2. **Trajectory Analysis**: Deep analysis of full conversation traces with tool call tracking
3. **Annotation Queue Processing**: High-risk trace routing and binary review integration
4. **Pattern Discovery**: Bottom-up failure mode clustering and trend identification
5. **Actionable Insights Generation**: Specification fixes and generalization improvements
6. **Cross-Functional Report Creation**: Tailored insights for different stakeholder groups
7. **Production Loop Closure**: Route findings to appropriate improvement pathways
8. **Team Insights PR**: Create structured PR to team-ai-directives/AGENTS.md

## Execution Steps

### Phase 0: Results Discovery and Assessment

**Objective**: Comprehensive assessment of evaluation results and annotation queue state

#### Step 1: Results Inventory

Assess all available evaluation results for analysis readiness:

```bash
# Execute via setup script
.specify/scripts/bash/setup-evals.sh "trace $ARGUMENTS" trace --assess-results
```

**Expected Results Assessment**:
```markdown
## Evaluation Results Inventory

**Analysis Date**: {current_date}
**Results Scope**: {date_range}

### Available Results

| Source | Results Count | Date Range | Trace Quality |
|--------|---------------|------------|---------------|
| **PromptFoo Evaluations** | 156 traces | 2026-03-15 to 2026-03-30 | Full trajectories |
| **Security Baseline** | 89 traces | 2026-03-20 to 2026-03-30 | Complete context |
| **Goldset Judges** | 67 traces | 2026-03-18 to 2026-03-30 | Multi-turn preserved |
| **Annotation Queue** | 23 traces | 2026-03-25 to 2026-03-30 | Pending review |

### Trace Quality Assessment
- **Complete Trajectories**: 98% (304/312 traces)
- **Tool Call Preservation**: 95% (296/312 traces)
- **Context Continuity**: 97% (303/312 traces)
- **Risk Scores Available**: 100% (312/312 traces)

**Analysis Readiness**: ✅ READY FOR COMPREHENSIVE ANALYSIS
```

#### Step 2: Annotation Queue Status

Evaluate annotation queue state and routing effectiveness:

```markdown
## Annotation Queue Analysis

### Queue Status Overview

| Priority | Pending | In Review | Completed | Total |
|----------|---------|-----------|-----------|-------|
| **High Risk** | 8 | 3 | 12 | 23 |
| **Medium Risk** | 15 | 7 | 28 | 50 |
| **Low Risk** | 2 | 1 | 19 | 22 |
| **Total** | 25 | 11 | 59 | 95 |

### Routing Effectiveness
- **High-Risk Detection**: 92% accuracy (risk > 0.8 threshold)
- **False Positive Rate**: 8% (acceptable for safety-critical routing)
- **Human Review Completion**: 74% within SLA (target: 80%)
- **Binary Decision Quality**: 96% reviewer agreement

### Queue Processing Insights
- **Peak Volume**: 15 traces/day (Tuesday-Thursday)
- **Average Review Time**: 12 minutes per trace
- **Escalation Rate**: 3% (regulatory compliance edge cases)

**Queue Status**: ✅ HEALTHY (minor SLA improvement needed)
```

### Phase 1: Trajectory Analysis

**Objective**: Deep analysis of full conversation traces with comprehensive context preservation

#### Step 1: Full Trace Analysis

Analyze complete conversation trajectories including tool calls:

```python
# Trajectory analysis implementation
import json
import pandas as pd
from typing import Dict, List, Any
from pathlib import Path

def analyze_trajectory_patterns(results_path: str) -> Dict[str, Any]:
    """
    Comprehensive trajectory analysis following EDD Principle V.
    Analyzes full multi-turn traces including tool calls and context.
    """

    trajectory_insights = {
        'conversation_patterns': {},
        'tool_usage_analysis': {},
        'context_evolution': {},
        'failure_trajectories': {},
        'success_patterns': {}
    }

    # Load all trace files
    trace_files = Path(results_path).glob("**/*.json")

    for trace_file in trace_files:
        with open(trace_file) as f:
            trace_data = json.load(f)

        # Analyze conversation structure
        conversation_analysis = analyze_conversation_structure(trace_data)
        trajectory_insights['conversation_patterns'].update(conversation_analysis)

        # Analyze tool call sequences
        tool_analysis = analyze_tool_sequences(trace_data)
        trajectory_insights['tool_usage_analysis'].update(tool_analysis)

        # Track context evolution
        context_evolution = analyze_context_changes(trace_data)
        trajectory_insights['context_evolution'].update(context_evolution)

        # Identify failure trajectories
        if trace_data.get('evaluation_result', {}).get('pass', True) == False:
            failure_analysis = analyze_failure_trajectory(trace_data)
            trajectory_insights['failure_trajectories'].update(failure_analysis)
        else:
            success_analysis = analyze_success_patterns(trace_data)
            trajectory_insights['success_patterns'].update(success_analysis)

    return trajectory_insights

def analyze_conversation_structure(trace_data: Dict) -> Dict:
    """Analyze multi-turn conversation patterns."""
    turns = trace_data.get('conversation', {}).get('turns', [])

    return {
        'turn_count': len(turns),
        'avg_turn_length': sum(len(turn.get('content', '')) for turn in turns) / len(turns) if turns else 0,
        'context_switches': count_context_switches(turns),
        'topic_coherence': calculate_topic_coherence(turns),
        'user_intent_evolution': track_intent_changes(turns)
    }

def analyze_tool_sequences(trace_data: Dict) -> Dict:
    """Analyze tool call patterns and sequences."""
    tool_calls = trace_data.get('tool_calls', [])

    return {
        'tool_sequence': [call.get('function', {}).get('name') for call in tool_calls],
        'tool_success_rate': calculate_tool_success_rate(tool_calls),
        'tool_chaining_patterns': identify_tool_chains(tool_calls),
        'error_recovery_patterns': analyze_tool_error_recovery(tool_calls)
    }
```

**Trajectory Analysis Results**:
```markdown
## Comprehensive Trajectory Analysis

### Conversation Pattern Analysis

| Pattern Type | Frequency | Success Rate | Risk Indicators |
|--------------|-----------|--------------|-----------------|
| **Single-Turn Direct** | 124 traces | 94% | Low risk |
| **Multi-Turn Clarification** | 89 traces | 87% | Medium risk - context drift |
| **Complex Problem Solving** | 67 traces | 78% | High risk - tool failures |
| **Context-Heavy Discussions** | 32 traces | 71% | High risk - memory overflow |

### Tool Usage Patterns

| Tool Sequence Pattern | Count | Avg Success | Failure Mode |
|----------------------|-------|-------------|--------------|
| **Read → Edit** | 89 | 96% | File permission errors |
| **Search → Read → Edit** | 67 | 91% | Context loss between steps |
| **Multi-Agent → Integrate** | 34 | 82% | Agent handoff failures |
| **Loop → Validate → Fix** | 23 | 74% | Infinite loop detection |

### Context Evolution Analysis
- **Context Preservation**: 89% successful across multi-turn conversations
- **Context Drift Detection**: 11% of failures attributed to context loss
- **Memory Pressure Points**: Conversations > 15 turns show 23% degradation
- **Tool Call Context**: 94% tool calls maintain proper conversation context

### Critical Failure Trajectories (23 high-risk traces)
- **Regulatory Compliance Edge Cases**: 8 traces (34.8%)
- **Safety Boundary Violations**: 6 traces (26.1%)
- **Context Overflow Failures**: 5 traces (21.7%)
- **Tool Chain Breakdowns**: 4 traces (17.4%)
```

#### Step 2: Risk Pattern Identification

Identify high-risk patterns requiring annotation and human review:

```markdown
## High-Risk Pattern Identification

### Risk Pattern Categories

**Category 1: Specification Boundary Violations**
- **Pattern**: Requests pushing against safety/regulatory boundaries
- **Frequency**: 18 traces (5.8% of total)
- **Risk Score**: 0.85+ average
- **Action Required**: Fix directive - clarify specification boundaries

**Category 2: Context-Dependent Failures**
- **Pattern**: Failures occurring only in specific context combinations
- **Frequency**: 12 traces (3.8% of total)
- **Risk Score**: 0.78+ average
- **Action Required**: Build evaluator - context awareness testing

**Category 3: Tool Chain Reliability**
- **Pattern**: Multi-tool sequences with cascading failures
- **Frequency**: 9 traces (2.9% of total)
- **Risk Score**: 0.82+ average
- **Action Required**: Build evaluator - tool chain resilience

**Category 4: Edge Case Generalization**
- **Pattern**: Novel scenarios not covered in training/goldset
- **Frequency**: 7 traces (2.2% of total)
- **Risk Score**: 0.89+ average
- **Action Required**: Build evaluator - expand goldset coverage

### Annotation Routing Analysis
- **Correctly Routed to Human Review**: 21/23 high-risk traces (91%)
- **False Positives**: 2 traces routed unnecessarily
- **Missed High-Risk**: 1 trace (risk 0.79, just below threshold)
- **Human Review Agreement**: 96% binary pass/fail consensus

**Risk Pattern Status**: ✅ EFFECTIVE DETECTION (91% accuracy)
```

### Phase 2: Annotation Queue Processing

**Objective**: Process annotation queues with binary human review integration

#### Step 1: Queue Processing Analysis

Process pending and completed annotation reviews:

```markdown
## Annotation Queue Processing Results

### Binary Review Outcomes

| Review Category | Pass | Fail | Ambiguous | Total |
|----------------|------|------|-----------|-------|
| **Security Violations** | 2 | 14 | 0 | 16 |
| **Regulatory Compliance** | 8 | 12 | 2 | 22 |
| **Context Handling** | 15 | 8 | 1 | 24 |
| **Safety Boundaries** | 3 | 9 | 0 | 12 |

### Human Reviewer Insights

**Top Failure Patterns Identified**:
1. **Ambiguous Regulatory Boundaries** (22 traces)
   - Reviewers note unclear guidance for edge cases
   - 18% of traces require domain expert escalation
   - Recommendation: Specification clarification needed

2. **Context Window Edge Effects** (15 traces)
   - Failures occur near conversation length limits
   - Pattern: degradation starts around turn 12-15
   - Recommendation: Add context management evaluator

3. **Multi-Modal Safety Gaps** (9 traces)
   - Safety evaluators miss context-dependent violations
   - Pattern: safe individual components, unsafe combinations
   - Recommendation: Build composite safety evaluator

### Review Quality Metrics
- **Inter-Reviewer Agreement**: 96% (kappa = 0.92)
- **Review Completion Time**: 8.2 minutes average
- **Escalation Rate**: 4% to domain experts
- **Binary Decision Quality**: Excellent (only 3 ambiguous cases)

**Queue Processing Status**: ✅ HIGH QUALITY HUMAN REVIEW
```

#### Step 2: High-Risk Trace Deep Dive

Detailed analysis of the highest-risk traces for immediate attention:

```markdown
## Critical High-Risk Trace Analysis

### Trace #2026-0328-001 (Risk Score: 0.94)
**Category**: Regulatory Compliance Boundary
**Failure Mode**: Financial advice in healthcare context
**Tool Sequence**: Read medical context → Generate financial guidance
**Human Review**: FAIL - inappropriate domain crossing
**Action Required**: SPECIFICATION FIX - clarify cross-domain boundaries

**Insight**: Current evaluators check domains separately, miss dangerous intersections
**Recommendation**: Add cross-domain boundary evaluator

### Trace #2026-0329-007 (Risk Score: 0.91)
**Category**: Safety Boundary Evolution
**Failure Mode**: Progressive boundary testing across turns
**Tool Sequence**: Safe request → escalating follow-ups → boundary violation
**Human Review**: FAIL - gradual manipulation not detected
**Action Required**: BUILD EVALUATOR - conversation-level safety tracking

**Insight**: Turn-by-turn evaluators miss conversation-level manipulation patterns
**Recommendation**: Add trajectory-level safety evaluator

### Trace #2026-0330-003 (Risk Score: 0.89)
**Category**: Context Overflow Failure
**Failure Mode**: Critical context lost during long conversation
**Tool Sequence**: 18-turn conversation → context truncation → policy violation
**Human Review**: FAIL - context management inadequate
**Action Required**: BUILD EVALUATOR - context preservation validation

**Insight**: Context management needs proactive evaluation, not reactive detection
**Recommendation**: Add context integrity monitoring

**Critical Insights Summary**: All top failures require NEW EVALUATORS, not spec fixes
```

### Phase 3: Pattern Discovery

**Objective**: Bottom-up failure mode clustering and trend identification

#### Step 1: Failure Mode Clustering

Apply open/axial coding to discover failure patterns:

```markdown
## Bottom-Up Failure Mode Discovery

### Discovered Failure Taxonomies

**Cluster 1: Boundary Evolution Failures (31% of failures)**
- **Open Coding Themes**: "gradual", "progressive", "escalating", "boundary testing"
- **Axial Relationships**: Multi-turn conversations → boundary probing → eventual violation
- **Pattern**: Safe individual requests that become unsafe in sequence
- **Evaluator Gap**: No conversation-level boundary tracking

**Cluster 2: Cross-Domain Interference (24% of failures)**
- **Open Coding Themes**: "domain mixing", "inappropriate context", "role confusion"
- **Axial Relationships**: Domain expertise in Area A → overgeneralization to Area B
- **Pattern**: Correct domain knowledge applied in wrong context
- **Evaluator Gap**: Domain boundary enforcement incomplete

**Cluster 3: Context Window Edge Effects (19% of failures)**
- **Open Coding Themes**: "memory loss", "context truncation", "information gaps"
- **Axial Relationships**: Long conversations → context pressure → critical loss
- **Pattern**: System behavior degradation near context limits
- **Evaluator Gap**: Context integrity not monitored proactively

**Cluster 4: Tool Chain Cascading Failures (15% of failures)**
- **Open Coding Themes**: "cascade", "domino effect", "error propagation"
- **Axial Relationships**: Tool error → inadequate recovery → amplified failure
- **Pattern**: Single tool failure causes disproportionate downstream impact
- **Evaluator Gap**: Tool chain resilience not evaluated

**Cluster 5: Semantic Drift in Context (11% of failures)**
- **Open Coding Themes**: "meaning shift", "context reinterpretation", "semantic confusion"
- **Axial Relationships**: Initial context → gradual reinterpretation → changed meaning
- **Pattern**: Same words, different meaning as conversation evolves
- **Evaluator Gap**: Semantic stability not tracked

### Theoretical Saturation Analysis
- **Total Traces Analyzed**: 312
- **Failure Modes Identified**: 5 major clusters
- **New Patterns (Last 50 traces)**: 0 (saturation achieved)
- **Pattern Stability**: 95% consistency across time periods

**Pattern Discovery Status**: ✅ THEORETICAL SATURATION ACHIEVED
```

#### Step 2: Trend Analysis

Identify temporal trends and emerging patterns:

```markdown
## Trend Analysis and Emerging Patterns

### Temporal Failure Pattern Trends

| Time Period | Top Failure Mode | Frequency Change | Severity Change |
|-------------|------------------|------------------|------------------|
| **Week 1 (Mar 15-21)** | Cross-Domain | 28% of failures | Risk: 0.82 avg |
| **Week 2 (Mar 22-28)** | Boundary Evolution | 35% of failures | Risk: 0.86 avg |
| **Week 3 (Mar 29-30)** | Context Edge Effects | 42% of failures | Risk: 0.91 avg |

### Emerging Risk Patterns
1. **Increasing Context Pressure**: 15% increase in context-related failures
   - **Driver**: More complex, longer conversations
   - **Recommendation**: Prioritize context management evaluators

2. **Sophisticated Boundary Testing**: 23% increase in multi-turn boundary probing
   - **Driver**: Users learning system boundaries through exploration
   - **Recommendation**: Add conversation-level safety tracking

3. **Tool Chain Complexity**: 8% increase in multi-tool workflow failures
   - **Driver**: More sophisticated user requests requiring tool chains
   - **Recommendation**: Build tool chain resilience evaluators

### Predictive Insights
- **Context failures will become dominant** if not addressed within 2 weeks
- **Boundary evolution attacks increasing in sophistication** - need conversation-level detection
- **Tool chain resilience becoming critical** as usage complexity grows

**Trend Analysis Status**: ✅ CLEAR PATTERNS IDENTIFIED WITH PREDICTIONS
```

### Phase 4: Actionable Insights Generation

**Objective**: Generate specification fixes and generalization improvements

#### Step 1: Specification Fix Directives

Generate fix directives for specification failures:

```markdown
## Specification Fix Directives

### Fix Directive #1: Cross-Domain Boundary Clarification
**Issue**: Regulatory compliance evaluators miss dangerous domain intersections
**Traces Affected**: 18 traces (5.8% of total)
**Failure Type**: Specification Failure
**Priority**: HIGH

**Required Specification Changes**:
1. **Add explicit cross-domain restriction section** to compliance specifications
2. **Define domain intersection prohibited combinations**:
   - Financial advice + Medical context = PROHIBITED
   - Legal advice + Personal relationship context = PROHIBITED
   - Professional advice + Emotional manipulation = PROHIBITED
3. **Create domain boundary decision tree** for edge cases

**Implementation Target**: `specs/regulatory-compliance/domain-boundaries.md`
**Deadline**: Within 7 days (high risk exposure)

### Fix Directive #2: Context Management Expectations
**Issue**: System behavior expectations unclear when approaching context limits
**Traces Affected**: 12 traces (3.8% of total)
**Failure Type**: Specification Failure
**Priority**: MEDIUM

**Required Specification Changes**:
1. **Define context degradation graceful failure modes**
2. **Specify context preservation priorities**:
   - Safety context = HIGHEST PRIORITY
   - Task context = HIGH PRIORITY
   - Conversational context = MEDIUM PRIORITY
3. **Add context warning thresholds** (80%, 90%, 95% of limit)

**Implementation Target**: `specs/context-management/degradation-policy.md`
**Deadline**: Within 14 days

### Fix Directive #3: Multi-Turn Safety Evolution
**Issue**: Safety boundaries inadequately defined for conversation evolution
**Traces Affected**: 8 traces (2.6% of total)
**Failure Type**: Specification Failure
**Priority**: HIGH

**Required Specification Changes**:
1. **Add conversation-level safety constraints**
2. **Define progressive boundary testing detection**
3. **Specify cumulative risk assessment across turns**

**Implementation Target**: `specs/safety/conversation-level-boundaries.md`
**Deadline**: Within 7 days

**Specification Fix Status**: 3 directives generated, 2 HIGH priority
```

#### Step 2: Evaluator Enhancement Recommendations

Generate build recommendations for generalization failures:

```markdown
## Evaluator Enhancement Recommendations

### Build Recommendation #1: Conversation-Level Safety Tracker
**Gap**: Current evaluators check individual responses, miss conversation-level manipulation
**Justification**: 24 traces show progressive boundary testing (7.7% of total)
**Type**: Generalization Failure → Build LLM Judge Evaluator

**Evaluator Specification**:
- **Name**: `conversation_safety_trajectory`
- **Type**: LLM Judge (requires conversation context)
- **Input**: Full conversation history + current response
- **Logic**: Detect progressive manipulation patterns across turns
- **Threshold**: Flag conversations with escalating risk scores
- **Integration**: Tier 2 (semantic evaluation, <5min SLA)

**Implementation Priority**: URGENT (highest risk impact)
**Estimated Effort**: 8-12 hours (goldset creation + grader implementation)

### Build Recommendation #2: Cross-Domain Boundary Enforcer
**Gap**: Domain evaluators work in isolation, miss dangerous intersections
**Justification**: 18 traces show cross-domain violations (5.8% of total)
**Type**: Generalization Failure → Build Code-Based Evaluator

**Evaluator Specification**:
- **Name**: `cross_domain_boundary_check`
- **Type**: Code-Based (deterministic rules)
- **Input**: Response content + detected domain tags
- **Logic**: Matrix of prohibited domain combinations
- **Threshold**: Binary fail on any prohibited combination
- **Integration**: Tier 1 (fast check, <30s SLA)

**Implementation Priority**: HIGH (clear rule-based solution)
**Estimated Effort**: 4-6 hours (rule matrix + implementation)

### Build Recommendation #3: Context Integrity Monitor
**Gap**: Context management failures not detected until catastrophic loss
**Justification**: 12 traces show context-related failures (3.8% of total)
**Type**: Generalization Failure → Build Code-Based Evaluator

**Evaluator Specification**:
- **Name**: `context_integrity_validator`
- **Type**: Code-Based (context analysis)
- **Input**: Context window state + critical context markers
- **Logic**: Verify critical context preservation across turns
- **Threshold**: Warn at 80%, fail at 95% critical context loss
- **Integration**: Tier 1 (proactive monitoring, <30s SLA)

**Implementation Priority**: MEDIUM (proactive vs reactive)
**Estimated Effort**: 6-8 hours (context tracking + validation logic)

**Evaluator Enhancement Status**: 3 evaluators recommended, 1 URGENT priority
```

### Phase 5: Cross-Functional Report Creation

**Objective**: Create insights tailored for different stakeholder groups

#### Step 1: Stakeholder-Specific Insights

Generate tailored insights for different teams:

```markdown
## Cross-Functional Stakeholder Insights

### For Product Managers

**Top Business Impact Issues**:
1. **User Experience Degradation**: 11% of long conversations fail due to context management
   - **Impact**: User frustration with "forgetting" important context mid-conversation
   - **Recommendation**: Implement context warning system for users

2. **Regulatory Risk Exposure**: 5.8% of traces show cross-domain boundary violations
   - **Impact**: Potential compliance violations in regulated industries
   - **Recommendation**: URGENT - clarify domain intersection policies

3. **User Boundary Testing**: 35% increase in sophisticated boundary probing
   - **Impact**: Users are actively exploring system limits
   - **Recommendation**: Consider boundary exploration as feature vs bug

**Business Metrics Impact**:
- **Customer Satisfaction Risk**: Context failures likely reducing CSAT by 8-12%
- **Regulatory Compliance**: HIGH RISK - needs immediate attention
- **User Engagement**: Sophisticated users pushing boundaries = higher engagement

### For Domain Experts (Regulatory/Safety/Medical)

**Domain-Specific Risk Patterns**:
1. **Cross-Domain Contamination**: Medical context + Financial advice = 18 failures
   - **Expert Input Needed**: Define prohibited intersection matrix
   - **Timeline**: Review needed within 3 days for specification fix

2. **Progressive Boundary Evolution**: Users learning to manipulate across turns
   - **Expert Input Needed**: Define conversation-level risk accumulation rules
   - **Timeline**: Safety review needed within 5 days

3. **Context-Dependent Safety**: Same content safe/unsafe based on conversation history
   - **Expert Input Needed**: Define context-dependent safety evaluation criteria
   - **Timeline**: Ongoing collaboration needed for implementation

**Domain Expert Actions Required**:
- **Regulatory Team**: Review and approve cross-domain prohibition matrix
- **Safety Team**: Define conversation-level risk accumulation thresholds
- **Medical Team**: Validate healthcare context boundary definitions

### For AI Engineers

**Technical Implementation Priorities**:
1. **URGENT**: Conversation-level safety evaluator (24 traces affected)
   - **Technical Approach**: LLM judge with full conversation context
   - **Integration Point**: Tier 2 pipeline, <5min SLA
   - **Estimated Effort**: 8-12 hours

2. **HIGH**: Cross-domain boundary checker (18 traces affected)
   - **Technical Approach**: Rule-based matrix evaluation
   - **Integration Point**: Tier 1 pipeline, <30s SLA
   - **Estimated Effort**: 4-6 hours

3. **MEDIUM**: Context integrity monitor (12 traces affected)
   - **Technical Approach**: Context state analysis + threshold monitoring
   - **Integration Point**: Tier 1 pipeline, proactive warnings
   - **Estimated Effort**: 6-8 hours

**Technical Architecture Changes**:
- **Conversation State Management**: Need persistent conversation context tracking
- **Multi-Turn Evaluation Pipeline**: Extend evaluators to consider conversation history
- **Context Pressure Monitoring**: Add proactive context limit warnings

**AI Engineering Status**: Clear technical roadmap with effort estimates provided
```

#### Step 2: Executive Summary Creation

Create high-level executive summary for leadership:

```markdown
## Executive Summary: Production Intelligence Analysis

**Analysis Period**: March 15-30, 2026
**Evaluation Volume**: 312 conversation traces analyzed
**Overall System Health**: ✅ GOOD with identified improvement areas

### Key Findings

**System Performance**:
- **Success Rate**: 91% of conversations complete successfully
- **Risk Detection**: 91% accuracy in identifying high-risk traces
- **Human Review Quality**: 96% inter-reviewer agreement

**Critical Issues Identified**:
1. **Regulatory Compliance Gap** (5.8% of traces, HIGH RISK)
   - Cross-domain boundary violations not detected
   - Potential compliance violations in regulated industries
   - **Action Required**: Specification fix within 7 days

2. **Sophisticated User Boundary Testing** (7.7% of traces, MEDIUM RISK)
   - Users learning to manipulate system across conversation turns
   - Progressive boundary probing increasing 35% week-over-week
   - **Action Required**: New evaluator within 14 days

3. **Context Management Degradation** (3.8% of traces, MEDIUM RISK)
   - Long conversations experiencing context loss
   - User experience impact on complex tasks
   - **Action Required**: Context monitoring system

### Business Impact Assessment

**Immediate Risks**:
- **Regulatory Exposure**: HIGH - requires urgent specification clarification
- **User Trust**: MEDIUM - context failures affecting user experience
- **Scaling Challenges**: MEDIUM - increasing complexity of user requests

**Positive Indicators**:
- **Detection Systems Working**: 91% of high-risk cases properly identified
- **Human Review Quality**: 96% accuracy in binary pass/fail decisions
- **System Learning**: Clear patterns identified for systematic improvement

### Recommended Actions

**Week 1 (Urgent)**:
1. Domain expert review of cross-domain boundary policies
2. Specification fixes for regulatory compliance gaps
3. Begin implementation of conversation-level safety evaluator

**Week 2-3 (High Priority)**:
1. Deploy cross-domain boundary checker
2. Implement context integrity monitoring
3. Complete conversation-level safety evaluator

**Month 2 (Medium Priority)**:
1. Monitor effectiveness of new evaluators
2. Expand goldset coverage based on new patterns
3. Review and update based on new data

**Executive Recommendation**: Proceed with implementation plan - risks are manageable and improvement pathways are clear.
```

### Phase 6: Production Loop Closure

**Objective**: Route findings to appropriate improvement pathways

#### Step 1: Failure Type Routing

Route discoveries to appropriate action pathways following EDD Principle VIII:

```markdown
## Production Loop Closure Implementation

### Specification Failures → Fix Directives

**Route to**: `specs/` directory with immediate fix implementation

1. **Cross-Domain Boundary Clarification**
   - **Target**: `specs/regulatory-compliance/domain-boundaries.md`
   - **Owner**: Regulatory domain expert + Product team
   - **Deadline**: 7 days (HIGH RISK)
   - **Status**: ✅ Routed to specification fix pipeline

2. **Context Management Expectations**
   - **Target**: `specs/context-management/degradation-policy.md`
   - **Owner**: AI Engineering + UX team
   - **Deadline**: 14 days (MEDIUM RISK)
   - **Status**: ✅ Routed to specification fix pipeline

3. **Multi-Turn Safety Evolution**
   - **Target**: `specs/safety/conversation-level-boundaries.md`
   - **Owner**: Safety domain expert + AI Engineering
   - **Deadline**: 7 days (HIGH RISK)
   - **Status**: ✅ Routed to specification fix pipeline

### Generalization Failures → Evaluator Backlog

**Route to**: `evals/evaluator-backlog/` for systematic enhancement

1. **Conversation-Level Safety Tracker**
   - **Target**: `evals/evaluator-backlog/conversation-safety-trajectory.md`
   - **Type**: LLM Judge evaluator
   - **Priority**: URGENT (highest impact)
   - **Owner**: AI Engineering team
   - **Status**: ✅ Added to evaluator development backlog

2. **Cross-Domain Boundary Enforcer**
   - **Target**: `evals/evaluator-backlog/cross-domain-boundary-check.md`
   - **Type**: Code-based evaluator
   - **Priority**: HIGH (clear implementation path)
   - **Owner**: AI Engineering team
   - **Status**: ✅ Added to evaluator development backlog

3. **Context Integrity Monitor**
   - **Target**: `evals/evaluator-backlog/context-integrity-validator.md`
   - **Type**: Code-based evaluator
   - **Priority**: MEDIUM (proactive improvement)
   - **Owner**: AI Engineering team
   - **Status**: ✅ Added to evaluator development backlog

### Continuous Improvement Pipeline

**Monthly Review Process**:
1. **Pattern Stability Analysis**: Verify identified patterns remain stable
2. **New Pattern Discovery**: Scan for emerging failure modes
3. **Evaluator Effectiveness**: Measure impact of deployed evaluators
4. **Goldset Evolution**: Expand coverage based on new patterns

**Quarterly Deep Dive**:
1. **Cross-Functional Retrospective**: All stakeholder groups review effectiveness
2. **EDD Compliance Audit**: Verify adherence to all 10 principles
3. **Strategic Priority Alignment**: Adjust focus based on business priorities

**Production Loop Status**: ✅ COMPLETE ROUTING WITH CONTINUOUS IMPROVEMENT
```

### Phase 7: Team Insights PR Creation

**Objective**: Create structured PR to team-ai-directives/AGENTS.md with actionable insights

#### Step 1: PR Content Generation

Generate comprehensive insights PR for team collaboration:

```markdown
## Team Insights PR: Production Intelligence Analysis - March 2026

**PR Title**: `intelligence/mar2026: Production evaluation insights with 3 urgent fixes + 3 evaluator enhancements`

**Target Branch**: `main`
**Target File**: `team-ai-directives/AGENTS.md`
**PR Type**: Intelligence Update + Action Items

### PR Description

This PR contains comprehensive production intelligence analysis from March 15-30, 2026, including urgent fixes and systematic improvements based on 312 conversation traces.

**Key Discoveries**:
- 3 specification gaps requiring urgent fixes (regulatory risk)
- 3 new evaluators needed for generalization failures
- Clear patterns identified with 95% confidence (theoretical saturation achieved)

**Immediate Actions Required**:
- [ ] **URGENT** (7 days): Domain expert review of cross-domain policies
- [ ] **HIGH** (14 days): Implement conversation-level safety evaluator
- [ ] **MEDIUM** (21 days): Deploy context integrity monitoring

### Changes to team-ai-directives/AGENTS.md

**Section: Production Intelligence Insights**

```markdown
## Production Intelligence Analysis - March 2026

**Analysis Summary**: Comprehensive evaluation of 312 conversation traces revealing 3 critical improvement areas and systematic enhancement opportunities.

### Critical Findings Requiring Immediate Action

#### 1. Cross-Domain Boundary Violations (URGENT - 7 days)
- **Issue**: 5.8% of traces show dangerous domain intersections (e.g., financial advice in medical contexts)
- **Risk**: Regulatory compliance exposure
- **Owner**: @regulatory-team @product-team
- **Action**: Review and approve cross-domain prohibition matrix
- **Spec Target**: `specs/regulatory-compliance/domain-boundaries.md`

#### 2. Conversation-Level Boundary Testing (HIGH - 14 days)
- **Issue**: 7.7% of traces show sophisticated multi-turn manipulation
- **Risk**: Safety boundary circumvention via progressive probing
- **Owner**: @ai-engineering @safety-team
- **Action**: Implement conversation-level safety trajectory evaluator
- **Tech Target**: `evals/evaluator-backlog/conversation-safety-trajectory.md`

#### 3. Context Management Degradation (MEDIUM - 21 days)
- **Issue**: 3.8% of traces fail due to context window pressure
- **Risk**: User experience degradation in complex tasks
- **Owner**: @ai-engineering @ux-team
- **Action**: Deploy context integrity monitoring with proactive warnings
- **Tech Target**: `evals/evaluator-backlog/context-integrity-validator.md`

### Systematic Improvements (Month 2)

**Pattern Discovery Results**:
- **Theoretical Saturation**: ✅ Achieved (5 major failure clusters identified)
- **Temporal Trends**: Context pressure increasing 15% week-over-week
- **Risk Evolution**: Users becoming more sophisticated in boundary testing

**New Evaluators in Development**:
1. **Conversation Safety Trajectory** (LLM Judge, Tier 2)
2. **Cross-Domain Boundary Check** (Code-based, Tier 1)
3. **Context Integrity Validator** (Code-based, Tier 1)

### Team Collaboration Framework

**Weekly Sync (Tuesdays 2pm)**:
- Review high-risk traces from annotation queue
- Validate new pattern discoveries
- Coordinate cross-functional responses

**Monthly Deep Dive (First Friday)**:
- Comprehensive pattern analysis
- Evaluator effectiveness review
- Strategic priority alignment

**Quarterly EDD Audit (End of quarter)**:
- Full EDD compliance verification
- Cross-functional retrospective
- Strategic roadmap updates

### Success Metrics and Monitoring

**Key Performance Indicators**:
- Risk detection accuracy: 91% (target: >90%)
- Human review quality: 96% (target: >95%)
- Cross-functional response time: 5.2 days avg (target: <7 days)

**Monitoring Dashboard**: `https://internal.dashboards/evals-intelligence`
**Alert Thresholds**: Risk >0.9 or pattern frequency change >25%
```

### Implementation Checklist

- [ ] **Domain Expert Reviews** (Week 1)
  - [ ] Regulatory team: Cross-domain prohibition matrix
  - [ ] Safety team: Conversation-level risk thresholds
  - [ ] Medical team: Healthcare context boundaries

- [ ] **Specification Updates** (Week 1-2)
  - [ ] Create `specs/regulatory-compliance/domain-boundaries.md`
  - [ ] Create `specs/safety/conversation-level-boundaries.md`
  - [ ] Update `specs/context-management/degradation-policy.md`

- [ ] **Evaluator Development** (Week 2-4)
  - [ ] Implement conversation safety trajectory evaluator
  - [ ] Deploy cross-domain boundary checker
  - [ ] Build context integrity monitor

- [ ] **Integration Testing** (Week 4)
  - [ ] Validate new evaluators against historical traces
  - [ ] Performance testing within SLA constraints
  - [ ] Cross-functional acceptance testing

**PR Status**: ✅ READY FOR TEAM REVIEW AND IMPLEMENTATION
```

## Key Rules

### Trajectory Analysis Standards

- **Complete Trace Coverage**: All conversation turns and tool calls must be analyzed
- **Context Preservation**: Full context evolution tracking across multi-turn conversations
- **Tool Call Integration**: Tool sequences and error patterns must be included in analysis
- **Risk Pattern Detection**: High-risk traces (>0.8) must receive detailed failure analysis

### Annotation Queue Standards

- **Binary Review Enforcement**: All human reviews must result in clear pass/fail decisions
- **High-Risk Routing**: Traces with confidence <0.8 must route to appropriate expert reviewers
- **Review Quality Verification**: Inter-reviewer agreement must exceed 90%
- **Queue SLA Compliance**: Reviews must complete within established timeframes

### Pattern Discovery Requirements

- **Theoretical Saturation**: Pattern analysis must continue until no new patterns emerge
- **Bottom-Up Approach**: Failure modes discovered through open/axial coding, not predetermined categories
- **Statistical Significance**: Pattern frequencies must be statistically significant (p < 0.05)
- **Temporal Stability**: Patterns must show stability across time periods

### Cross-Functional Communication Standards

- **Stakeholder-Specific Insights**: Different insights required for PMs, domain experts, and engineers
- **Actionable Recommendations**: All insights must include specific actions with owners and timelines
- **Risk Prioritization**: Issues must be clearly prioritized by business impact and technical complexity
- **Implementation Roadmap**: Clear technical roadmap with effort estimates and dependencies

## Workflow Guidance & Transitions

### After `/evals.trace`

**Success Path**: Execution traces and analysis reports successfully generated, with optional insights routed to team.

**Follow-up Actions**:
- **Domain Expert Reviews**: Specification fixes require domain expert validation
- **Evaluator Implementation**: Generalization failures route to evaluator development backlog
- **Monitoring Setup**: Continuous monitoring of pattern evolution and evaluator effectiveness

**Complete Trace Flow**:

```
/evals.trace "Comprehensive production intelligence analysis"
    ↓
[Results discovery] → Inventory evaluation results and annotation queues
    ↓
[Trajectory analysis] → Deep multi-turn trace analysis with tool call tracking
    ↓
[Annotation processing] → High-risk routing and binary review integration
    ↓
[Pattern discovery] → Bottom-up failure clustering with theoretical saturation
    ↓
[Actionable insights] → Specification fixes and evaluator recommendations
    ↓
[Cross-functional report] → Stakeholder-specific insights and implementation roadmap
    ↓
[Production loop closure] → Route findings to appropriate improvement pathways
    ↓
[Team insights PR] → Optional: Create collaborative PR to team-ai-directives/AGENTS.md
```

### When to Use This Command

- **After validation**: When `/evals.validate` confirms system is production-ready
- **Monthly intelligence**: Regular production intelligence analysis and team insights
- **Incident response**: Post-incident analysis for systematic improvement
- **Strategic planning**: Quarterly reviews for roadmap and priority planning

### When NOT to Use This Command

- **Development phase**: This is for production intelligence, not development iteration
- **Without results**: Requires substantial evaluation results for meaningful analysis
- **Pre-deployment**: Use `/evals.validate` for pre-production readiness assessment

## Context

$ARGUMENTS