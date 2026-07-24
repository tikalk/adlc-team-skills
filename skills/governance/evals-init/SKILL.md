---
name: evals-init
description: Initialize evals/{system}/ directory structure for evaluation system following EDD principles (Standalone). Choose PromptFoo or DeepEval based on tech stack, generate security baseline.
disable-model-invocation: true
---

# evals-init

## What this skill does

Initialize the **project-level evaluation directory structure** following EDD (Eval-Driven Development) principles to prepare for systematic evaluation development. This is completely standalone with zero spec-kit dependencies.

**Output**:
1. **Directory Structure** - `evals/{system}/` with proper organization (promptfoo | deepeval)
2. **Security Baseline** - Auto-created graders for PII leakage, prompt injection, hallucination detection, misinformation detection
3. **Configuration Files** - Standalone config.yml and goldset templates under `.adlc/evals/`
4. **Auto-handoff** to `/evals-specify` to begin error analysis

**Key EDD Principles Applied**:
- **Principle I**: Spec-Driven Contracts - Evals validate spec compliance
- **Principle II**: Binary Pass/Fail - No Likert scales in grader templates
- **Principle IV**: Evaluation Pyramid - Tier 1 (fast) + Tier 2 (goldset) structure
- **Principle IX**: Test Data as Code - Version control setup for datasets

## When to use

- **Starting systematic evaluation**: Set up the initial evaluation harness for your application
- **EDD Adoption**: Converting from traditional testing to evaluation-driven development
- **Security-first evaluation**: Auto-generate baseline security checks from the start

## When NOT to use

- **Evals directory already exists**: Use `/evals-validate` to run tests, or `/evals-specify` to add criteria
- **Evaluating team directives**: This is for project-level application behavior testing, not directives compliance

## Process

### User Input
```text
$ARGUMENTS
```
Parse flags from the arguments first, then treat remaining text as focus areas:
- `--system SYSTEM` — Choose `promptfoo` or `deepeval`. If omitted, choose interactively based on tech stack.
- Remaining text — System description (focus setup)

### Execution Steps

#### Phase 1: Tech Stack Detection
- Scan project manifests (`package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, etc.)
- Recommends PromptFoo for mixed/JS stacks; DeepEval for Python-native stacks

#### Phase 2: Create Directory Structure
Creates:
```
evals/
├── {system}/                    # promptfoo | deepeval
│   ├── goldset.md              # Published goldset
│   ├── goldset.json            # Auto-generated for system consumption
│   ├── config.yml              # System-specific configuration
│   ├── config.{js,py}          # Generated system config (.js for promptfoo, .py for deepeval)
│   └── graders/                # Binary pass/fail graders
│       ├── check_pii_leakage.py           # Security baseline
│       ├── check_prompt_injection.py     # Security baseline
│       ├── check_hallucination.py        # Security baseline
│       └── check_misinformation.py       # Security baseline
├── results/                    # Git-ignored run outputs
└── .adlc/
    └── drafts/evals/           # Draft eval records (Markdown + YAML)
```

#### Phase 3: Configuration Copy
- Create `.adlc/evals/` if missing.
- Copy `skills/governance/evals-templates/evals-config-template.yml` to `.adlc/evals/evals-config.yml`.

#### Phase 4: Auto-Handoff
Trigger `/evals-specify` to begin error analysis.

## Verification
- `evals/{system}/goldset.md` exists (initially empty)
- `.adlc/evals/evals-config.yml` exists
- Graders directory populated with 4 security baseline python scripts
- Results directory contains `.gitignore` to prevent versioning traces
- Handover report generated with recommended framework and next steps