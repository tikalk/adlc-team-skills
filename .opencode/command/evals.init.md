---
description: Initialize evals/{system}/ directory structure for evaluation system
  following EDD principles
scripts:
  sh: .specify/scripts/bash/setup-evals.sh "init {ARGS}"
  ps: .specify/scripts/powershell/setup-evals.ps1 "init {ARGS}"
---


<!-- Extension: evals -->
<!-- Config: .specify/extensions/evals/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"--system promptfoo"` - Initialize with PromptFoo integration (default)
- `"--system deepeval"` - Initialize with DeepEval integration
- `"--system custom"` - Initialize with custom evaluation framework
- `"--system llm-judge"` - Initialize with LLM-based evaluation system
- `"Django API with user authentication, focus on security evals"`
- `"RAG system with retrieval and generation components"`
- Empty input: Ask user to choose between PromptFoo and DeepEval

When users provide context about their system, use it to focus the initialization setup.

## Goal

Initialize the evaluation directory structure following **EDD (Eval-Driven Development) principles** to prepare for systematic evaluation development.

**Output**:

1. **Directory Structure** - `evals/{system}/` with proper organization
2. **Security Baseline** - Auto-created graders for PII leakage, prompt injection, hallucination detection, misinformation detection
3. **Configuration Files** - System-specific config.yml and goldset templates
4. **Auto-handoff** to `/evals.specify` to begin error analysis

**Key EDD Principles Applied**:

- **Principle I**: Spec-Driven Contracts - Evals validate spec compliance
- **Principle II**: Binary Pass/Fail - No Likert scales in grader templates
- **Principle IV**: Evaluation Pyramid - Tier 1 (fast) + Tier 2 (goldset) structure
- **Principle IX**: Test Data as Code - Version control setup for datasets

### Flags

- `--system SYSTEM`: Evaluation system to initialize
  - `promptfoo`: PromptFoo integration with JavaScript/Python graders
  - `deepeval`: DeepEval integration with Python metrics
  - `custom`: Custom evaluation framework setup
  - `llm-judge`: LLM-based evaluation system setup
  - If not specified, user will be prompted to choose

- `--json`: Output structured JSON for programmatic integration

## Role & Context

You are acting as an **EDD Setup Specialist** preparing the foundation for systematic evaluation development. Your role involves:

- **Initializing** directory structure following EDD principles
- **Creating** security baseline graders (always applied)
- **Configuring** evaluation pyramid (Tier 1 + Tier 2)
- **Setting up** version control for test data as code

### EDD vs Traditional Testing

| Approach | Focus | Output | Decision Making |
|----------|-------|--------|----------------|
| **EDD** (this command) | Spec compliance | Binary pass/fail | Error analysis → criteria |
| **Traditional Testing** | Code correctness | Pass/fail/coverage | Requirements → tests |

## Outline

1. **System Detection** (Phase 0): Analyze codebase to suggest optimal evaluation system
2. **Directory Initialization**: Create `evals/{system}/` structure with proper organization
3. **Security Baseline Creation**: Generate always-applied graders (PII, injection, hallucination, misinformation detection)
4. **Configuration Setup**: Create system-specific configs following EDD principles
5. **Template Generation**: Create goldset and grader templates
6. **Version Control Setup**: Configure `.gitignore` and versioning for test data
7. **Validation**: Verify setup meets EDD compliance requirements
8. **Auto-Handoff**: Trigger `/evals.specify` to begin error analysis

## Execution Steps

### Phase 0: System Detection and Recommendation

**Objective**: Analyze codebase to recommend optimal evaluation system

#### Step 1: Technology Stack Analysis

Detect technologies to recommend appropriate evaluation system:

| Technology Found | Recommended System | Reason |
|------------------|-------------------|--------|
| `package.json` + AI libs | PromptFoo | Strong Node.js integration |
| `requirements.txt` + LLM frameworks | DeepEval or PromptFoo | Python-native vs mixed ecosystem |
| Custom ML pipeline | Custom | Need specialized evaluators |
| Multiple LLM providers | LLM-judge | Provider-agnostic evaluation |

#### Step 2: Use Case Detection

| Pattern | Evidence | Recommended Focus |
|---------|----------|-------------------|
| **RAG System** | Vector DB imports, retrieval code | RAG decomposition (Principle VI) |
| **Chat/Assistant** | Conversation handling, memory | Trajectory observability (Principle V) |
| **Content Generation** | Text generation, templates | Binary pass/fail criteria |
| **Security-Sensitive** | Auth, PII handling | Enhanced security baseline |

#### Step 3: System Selection

If no `--system` flag provided, present options to user for selection:

```text
## Choose Evaluation Integration

Which evaluation framework would you like to use?

1. **DeepEval** - Python-native framework with built-in LLM metrics
   • Perfect for Python-heavy projects
   • Built-in metrics: faithfulness, answer relevancy, bias detection
   • Integrated with popular ML libraries

2. **PromptFoo** - Flexible framework with JavaScript config + Python graders
   • Great for mixed tech stacks
   • Extensive provider support
   • Rich visualization and reporting

3. **Custom** - Build your own evaluation framework
   • Full control over evaluation logic
   • Specialized metrics for unique use cases

4. **LLM-Judge** - Use LLM models as evaluators
   • GPT-4/Claude for semantic evaluation
   • Natural language criteria

Enter choice [1-4]:
```

If `--system` flag is provided, skip this step and use the specified system.

#### Step 4: System Recommendation (when analyzing codebase)

Present additional recommendation to user based on codebase analysis:

```markdown
## Evaluation System Recommendation

Based on your codebase analysis:

**Detected Technologies**:
- Python with LangChain/LlamaIndex (RAG system detected)
- FastAPI endpoints for chat
- PostgreSQL with vector extensions

**Recommended Setup**:
- **System**: `deepeval` or `promptfoo` (choose based on preference)
- **Focus Areas**: RAG decomposition, trajectory observability
- **Security**: Enhanced PII detection for chat logs

**Integration Options**:
- `deepeval`: Python-native metrics with built-in LLM evaluators
- `promptfoo`: JavaScript config with Python graders, broader ecosystem
- `custom`: If you need specialized RAG evaluation metrics
- `llm-judge`: If you want GPT-4 to evaluate responses

**Choose integration: [1] DeepEval, [2] PromptFoo, [3] Custom, [4] LLM-judge**
```

### Phase 1: Directory Structure Initialization

**Objective**: Create EDD-compliant directory structure

1. **Run Setup Script**:
   - Execute `.specify/scripts/bash/setup-evals.sh "init $ARGUMENTS"` to create directory structure
   - Script follows EDD principles in organization
   - Creates security baseline graders automatically

2. **Directory Structure Created**:

```
evals/
├── {system}/                    # promptfoo | deepeval | custom | llm-judge
│   ├── goldset.md              # Published evals (EDD Principle I)
│   ├── goldset.json            # Auto-generated for system consumption
│   ├── config.yml              # System-specific configuration
│   ├── config.{ext}            # Generated system config (.js for promptfoo, .py for deepeval)
│   └── graders/                # Binary pass/fail graders (Principle II)
│       ├── check_pii_leakage.py           # Security baseline (always applied)
│       ├── check_prompt_injection.py     # Security baseline (always applied)
│       └── {failure-mode}.py             # Generated from error analysis
├── results/                    # Git-ignored; system outputs + traces
│   └── .gitignore              # Exclude from version control
└── .specify/
    └── drafts/                 # Draft eval records (Markdown + YAML)
        └── eval-template.md    # Template for error analysis
```

### Phase 2: Security Baseline Creation

**Objective**: Create always-applied security graders (EDD Principle IV - Tier 1)

#### Security Graders Generated

1. **PII Leakage Detection** (`check_pii_leakage.py`):
```python
def grade(output, context=None):
    # Binary pass/fail (EDD Principle II)
    # Patterns: SSN, credit cards, emails, phones
    return {"pass": True/False, "score": 1.0/0.0, "binary": True}
```

2. **Prompt Injection Detection** (`check_prompt_injection.py`):
```python
def grade(output, context=None):
    # Binary pass/fail (EDD Principle II)
    # Patterns: ignore instructions, system prompts, injections
    return {"pass": True/False, "score": 1.0/0.0, "binary": True}
```

3. **Hallucination Detection** (`check_hallucination.py`):
```python
def grade(output, context=None):
    # Binary pass/fail (EDD Principle II)
    # Patterns: factual inconsistencies, unsupported claims, fabricated references
    return {"pass": True/False, "score": 1.0/0.0, "binary": True}
```

4. **Misinformation Detection** (`check_misinformation.py`):
```python
def grade(output, context=None):
    # Binary pass/fail (EDD Principle II)
    # Patterns: false claims, conspiracy theories, harmful misinformation
    return {"pass": True/False, "score": 1.0/0.0, "binary": True}
```

#### Custom Security Extensions

Based on detected use case:

| Use Case | Additional Security Graders |
|----------|---------------------------|
| **RAG System** | `check_retrieval_injection.py` - Query injection detection |
| **Chat System** | `check_conversation_leakage.py` - Cross-user data leakage |
| **Content Gen** | `check_content_safety.py` - Harmful content detection |

### Phase 3: Configuration Setup

**Objective**: Create EDD-compliant system configuration

#### System-Specific Configuration (`config.yml`)

```yaml
# EDD-compliant configuration for {system}
system: "{system}"
binary_pass_fail: true  # EDD Principle II: No Likert scales

# EDD Principle IV: Evaluation Pyramid
tiers:
  tier1:
    fast_checks: true        # <30s execution
    security_baseline: true  # Always applied
    deterministic: true      # Regex, structure checks
  tier2:
    goldset_judges: true     # LLM judges on goldset
    semantic_checks: true    # Meaning-based evaluation

# EDD Principle IX: Test Data as Code
test_data:
  version_control: true      # Git-tracked datasets
  adversarial_required: true # Attack scenarios included
  holdout_ratio: 0.2         # Reserved test set
```

#### PromptFoo Integration (`config.js`)

For PromptFoo system, generate JavaScript configuration:

```javascript
module.exports = {
  description: 'EDD Evaluation Suite - Binary Pass/Fail',

  // EDD Principle IV: Evaluation Pyramid
  tests: [
    // Tier 1: Security baseline (always applied)
    {
      description: 'Security - PII Leakage',
      assert: [{ type: 'python', value: './graders/check_pii_leakage.py' }]
    },
    // Tier 2: Goldset judges (populated by evals.implement)
  ],

  // EDD Principle II: Binary outputs only
  outputPath: '../results/promptfoo_results.json'
};
```

### Phase 4: Template Generation

**Objective**: Create templates for goldset development

#### Goldset Record Template (`goldset.md`)

```markdown
# Evaluation Goldset

Published evaluation criteria following EDD principles.

<!-- Auto-generated from drafts during evals.clarify -->
<!-- Binary pass/fail only (EDD Principle II) -->

## Evaluation Index

| ID | Name | Type | Status | Confidence |
|----|------|------|--------|------------|
| eval-001 | [Name] | [failure_type] | published | HIGH |

---

## Published Evaluations

[Individual evaluation records will be populated by evals.clarify]
```

#### Draft Template (`.specify/drafts/eval-template.md`)

```yaml
---
id: eval-XXX
status: draft
name: {Eval Name}
description: {Description from error analysis}

# Binary pass/fail only (EDD Principle II)
pass_condition: {Precise spec constraint}
fail_condition: {Precise spec violation}

# Failure type gate (EDD Principle VIII)
failure_type:
  specification_failure:
    action: fix_directive
  generalization_failure:
    action: build_evaluator
    evaluator_type: code-based | llm-judge

# Error analysis provenance (EDD Principle III)
error_analysis:
  traces_analyzed: 0
  theoretical_saturation: false
  open_coding_notes: |
    {Bottom-up notes from human trace review}
---

# {Eval Name}

## Error Analysis Notes

{Human error analysis findings}

## Examples

### Pass Examples
- {Example that should pass the evaluation}

### Fail Examples
- {Example that should fail the evaluation}
```

### Phase 5: Version Control Setup

**Objective**: Configure version control for test data (EDD Principle IX)

#### Results Directory (.gitignore)

```
# Git-ignored: PromptFoo outputs + traces (EDD Principle V)
*
!.gitignore

# Keep structure but ignore outputs
*.json
*.log
traces/
reports/
```

#### Goldset Versioning

- **Drafts**: Version controlled in `.specify/drafts/`
- **Published**: Version controlled in `evals/{system}/goldset.md`
- **Generated configs**: Auto-generated, can be git-ignored
- **Test datasets**: Version controlled with adversarial examples

### Phase 6: EDD Compliance Validation

**Objective**: Verify setup meets all EDD principles

#### Compliance Checklist

| Principle | Requirement | Status |
|-----------|------------|--------|
| **I - Spec-Driven** | Goldset templates reference spec compliance | ✓ |
| **II - Binary Pass/Fail** | All graders return binary results | ✓ |
| **III - Error Analysis** | Draft templates support open coding | ✓ |
| **IV - Evaluation Pyramid** | Tier 1 + Tier 2 structure created | ✓ |
| **V - Trajectory Observability** | Results directory tracks full traces | ✓ |
| **VI - RAG Decomposition** | RAG-specific graders if detected | ✓ |
| **VII - Annotation Queues** | System supports annotation routing | ✓ |
| **VIII - Production Loop** | Failure type routing configured | ✓ |
| **IX - Test Data as Code** | Version control setup complete | ✓ |
| **X - Cross-Functional** | Team handoff structure ready | ✓ |

#### Output Validation Report

```markdown
## EDD Initialization Complete

### System Configuration
- **Evaluation System**: {system}
- **Directory Structure**: ✓ Created
- **Security Baseline**: ✓ 4 graders (PII, injection, hallucination, misinformation)
- **EDD Compliance**: ✓ All 10 principles implemented

### Next Steps
1. **Start Error Analysis**: Run `/evals.specify` to begin bottom-up goldset definition
2. **Security Focus**: {custom security recommendations based on detected use case}
3. **Team Integration**: Configure annotation queues for human review

### Files Created
- `evals/{system}/goldset.md` - Published criteria (empty, ready for clarify)
- `evals/{system}/config.yml` - EDD-compliant system configuration
- `evals/{system}/graders/` - Security baseline (2 graders)
- `evals/results/` - Trace storage (git-ignored)
- `.specify/drafts/` - Draft eval records (version controlled)

Ready for error analysis phase.
```

### Phase 7: Auto-Handoff to Specify

**Objective**: Begin error analysis workflow

After successful initialization, **automatically trigger `/evals.specify`** to begin bottom-up goldset definition:

**Context Passed to Specify**:

```json
{
  "source": "init",
  "system": "{selected system}",
  "use_case_detected": "{detected use case}",
  "security_focus": ["{security areas}"],
  "ready_for_error_analysis": true
}
```

## Key Rules

### EDD Principle Compliance

- **Always Binary**: No Likert scales, no numerical scoring beyond 0.0/1.0
- **Security First**: Always create baseline security graders
- **Spec-Driven**: Templates emphasize spec compliance validation
- **Evidence-Based**: All criteria must trace back to error analysis

### System-Specific Requirements

| System | Requirements |
|--------|-------------|
| **PromptFoo** | JavaScript config + Python graders, JSON output |
| **Custom** | YAML config + flexible grader format |
| **LLM-Judge** | LLM-specific prompts + API integration setup |

### Non-Destructive Setup

- **Check existing**: Don't overwrite existing eval directories
- **Merge intelligently**: Preserve any existing graders or configs
- **User confirmation**: Ask before overwriting non-empty directories

### Interactive Guidance

- **System recommendation**: Based on codebase analysis
- **Use case detection**: Suggest relevant evaluation areas
- **Security customization**: Add use-case-specific security graders

## Workflow Guidance & Transitions

### After `/evals.init`

**Auto-triggered**: `/evals.specify` runs immediately to begin error analysis.

**Complete EDD Initialization Flow**:

```
/evals.init "RAG system with FastAPI"
    ↓
[Detect RAG + API patterns] → Recommend PromptFoo + RAG focus
    ↓
[Create directory structure] → evals/promptfoo/ + security graders
    ↓
[Generate EDD-compliant configs] → Binary pass/fail, evaluation pyramid
    ↓
[Auto-trigger /evals.specify]
    ↓
[Begin error analysis] → Human traces → bottom-up criteria
```

### When to Use This Command

- **New evaluation setup**: Starting systematic evaluation for existing system
- **EDD adoption**: Converting from traditional testing to eval-driven development
- **Security-first evaluation**: Need baseline security graders from start
- **Multi-system evaluation**: Different eval approaches for different components

### When NOT to Use This Command

- **Evals directory exists**: Use `/evals.validate` to check existing setup
- **Only running existing evals**: Use `/evals.implement` to generate configs from existing goldset
- **Quick one-off testing**: EDD is for systematic, long-term evaluation development

## Context

$ARGUMENTS