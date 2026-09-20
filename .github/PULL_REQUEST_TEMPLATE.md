## Problem

<!-- What real problem does this solve? Link the issue/PRD/ADR where it was
     agreed. New skills must be agreed in an issue first (CONTRIBUTING). -->

## Changes

<!-- What changed and why this shape? One concern per PR. -->

## Baseline failure (required for skill-content changes)

<!-- Per writing-skills: what did the agent do WRONG without this change?
     Paste the verbatim baseline. If you didn't run a baseline, say so —
     do not invent one. -->

## Verification

<!-- Full suite: pytest tests/ evals/promptfoo/tests/ -v (paste the tail). -->

<!-- Skill-behavior changes: before/after PromptFoo eval evidence
     (npx promptfoo eval --config evals/promptfoo/config.js) or state that
     you couldn't run it (no OPENAI_API_KEY) and the nightly sweep covers it. -->

<!-- Generated-artifact sync: npx adlc-cli skill add <repo> -a <agent> -y
     re-run after adding/renaming skills. -->

## Manual test results

<!-- For changes that alter a skill's behavior — scratch-project run in a
     real agent (CONTRIBUTING → Manual testing). -->

**Agent**: | **OS/Shell**:

| Skill/command tested | Notes |
|----------------------|-------|
|  |  |

<!-- Session-start changes: paste scripts/acceptance-test.sh output. -->

## AI contribution disclosure

<!-- Required: disclose AI assistance, its extent, and the model, harness,
     and plugins used — or state "written by hand". -->
