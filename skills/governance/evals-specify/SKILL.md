---
name: evals-specify
description: Extract eval criteria from product specs and production failure traces (bottom-up error analysis). Writes proposed criteria to .adlc/drafts/evals/.
disable-model-invocation: true
---

# evals-specify

## What this skill does

Conducts **bottom-up error analysis** following **EDD Principles III & IX** (Error Analysis & Test Data as Code) to discover and document draft evaluation criteria from human observation of system failures.

**Output**:
1. **Draft Eval Records** - Individual `EVAL-*.md` files in `.adlc/drafts/evals/` with open coding notes
2. **Error Pattern Documentation** - Bottom-up failure taxonomy from actual traces
3. **Pass/Fail Examples** - Real examples that should pass/fail each criterion
4. **Auto-handoff** to `/evals-clarify` for axial coding and clustering

**Key EDD Principles Applied**:
- **Principle III**: Error Analysis & Pattern Discovery - Open coding → failure taxonomy
- **Principle IX**: Test Data as Code - Dataset planning and coverage analysis
- **Principle II**: Binary Pass/Fail - Maintain strict binary pass/fail conditions
- **Principle V**: Trajectory Observability - Track full multi-turn conversation traces

## When to use

- **Starting evaluation development**: No existing criteria, need discovery from failure logs
- **Production incident analysis**: Recent failures require systematic analysis
- **Quality assessment**: Discovering and codifying boundary conditions from failures

## When NOT to use

- **No failure traces/specs**: Generate synthetic traces first, or use `/evals-init` to set up security baselines
- **Known criteria already exist**: Use `/evals-clarify` to refine or `/evals-implement` to generate code

## Process

### User Input
```text
$ARGUMENTS
```
Treat user input as specific failure areas or error patterns to analyze (e.g., "authentication bypass", "RAG irrelevant results").
- `--traces N` — Number of traces to analyze (default: 20, min for theoretical saturation)
- `--source SOURCE` — Trace source location (e.g., logs, support tickets)

### Execution Steps

#### Phase 1: Open Coding Analysis
- Reviews the user-provided failure logs or spec requirements.
- Conducts open coding of traces to discover recurring failure patterns (EDD Principle III).
- Identifies: core problem, causal conditions, and consequences.

#### Phase 2: Create Draft Criteria
Group patterns into draft criteria. For each:
- Define strict **Pass Condition** (observable, binary yes/no)
- Define strict **Fail Condition** (observable, binary yes/no)
- Document real pass/fail examples directly from traces

#### Phase 3: Create Draft Files
- Copy `skills/governance/evals-templates/eval-criterion-template.md` to `.adlc/drafts/evals/EVAL-{NNN}.md`.
- Populate metadata and error analysis notes.
- Regenerate index at `.adlc/drafts/evals/evals.md`.

#### Phase 4: Auto-Handoff
Trigger `/evals-clarify` for axial coding and clustering.

## Verification
- Draft files created at `.adlc/drafts/evals/EVAL-*.md`
- Index file `.adlc/drafts/evals/evals.md` updated with draft summaries
- Each draft contains: status "draft", pass/fail conditions, trace sources, and concrete examples
- Auto-handoff context produced with list of created drafts