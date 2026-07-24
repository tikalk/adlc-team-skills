---
name: evals-clarify
description: Refine, cluster, and accept draft criteria into the published goldset. Isolates 20% holdout split and publishes goldset.md + goldset.json.
disable-model-invocation: true
---

# evals-clarify

## What this skill does

Conducts **axial coding** following **EDD Principles III & IX** to cluster related failure patterns, refine evaluation criteria, generate adversarial examples, and accept validated drafts into the published goldset.

**Output**:
1. **Clustered Criteria** - Related patterns grouped into coherent evaluation themes
2. **Adversarial Examples** - Generated attack scenarios and edge cases for robustness
3. **Published Goldset** - Accepted criteria in `evals/{system}/goldset.md` with full documentation
4. **Holdout Dataset** - Reserved test set (20%) for unbiased evaluation validation
5. **JSON Configuration** - Auto-generated `goldset.json` for system consumption
6. **Auto-handoff** to `/evals-implement` for grader generation

**Key EDD Principles Applied**:
- **Principle III**: Error Analysis & Pattern Discovery - Axial coding → theoretical relationships
- **Principle IX**: Test Data as Code - Adversarial generation, holdout splits, version control
- **Principle II**: Binary Pass/Fail - Maintain strict binary evaluation throughout
- **Principle I**: Spec-Driven Contracts - Criteria validate spec compliance

## When to use

- **After `/evals-specify`**: Refine and accept draft criteria into goldset
- **Dataset maintenance**: Balance pass/fail examples or add adversarial cases
- **Adding holdout split**: Isolate validation data from training data

## When NOT to use

- **No draft criteria exist**: Run `/evals-specify` to discover patterns first
- **Grader generation**: Use `/evals-implement` to convert accepted goldset into code

## Process

### User Input
```text
$ARGUMENTS
```
- `--accept IDS` — Accept specific draft IDs (e.g., "EVAL-001,EVAL-003")
- `--merge IDS` — Merge related criteria (e.g., "EVAL-001+EVAL-002")
- `--split ID` — Split complex criterion into multiple focused criteria
- `--holdout-ratio RATIO` — Holdout percentage (default: 0.2, range: 0.1-0.3)

### Execution Steps

#### Phase 1: Axial Coding & Clustering
- Group related draft patterns into coherent themes.
- Resolve any overlaps or duplicate criteria.

#### Phase 2: Refinement & Adversarial Generation
- Generate 3-5 adversarial (attack) examples per criterion to test robustness.
- Balance pass/fail examples (~50/50 ratio).

#### Phase 3: Holdout Isolation
- Isolate exactly 20% of examples as a reserved holdout set (saved to `.adlc/memory/evals/holdout.json`).
- Ensure holdout set is never used in implementation or training.

#### Phase 4: Publish Goldset
- Copy accepted drafts to `.adlc/memory/evals/` and update status to `accepted`.
- Compile published goldset to `evals/{system}/goldset.md` (human-readable) and `evals/{system}/goldset.json` (machine-readable).

#### Phase 5: Auto-Handoff
Trigger `/evals-implement` to generate code.

## Verification
- Accepted drafts stored in `.adlc/memory/evals/EVAL-*.md`
- `evals/{system}/goldset.md` and `goldset.json` exist
- Holdout set `.adlc/memory/evals/holdout.json` isolated and populated
- All criteria are strictly binary (no confidence scores or Likert scales)
- Handover summary lists accepted criteria and adversarial counts