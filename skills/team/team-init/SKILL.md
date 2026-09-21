---
name: team-init
description: Use when bootstrapping team knowledge from a brownfield codebase — reverse-engineers CDRs for contribution to team-ai-directives adlc branch.
disable-model-invocation: true
scripts:
  sh: scripts/team-init.sh
  ps: scripts/team-init.ps1
---

# team-init

## What this skill does

Reverse-engineer **Context Directive Records (CDRs)** from an **existing
codebase** (brownfield) to document reusable patterns for contribution to
`team-ai-directives`.

Replaces the former `team-init` skill. Drafts are written to the `adlc`
orphan branch of `team-ai-directives` (not project-local `.adlc/drafts/`).

## When to use

- **Brownfield projects**: Existing code without team-wide directives
- **Legacy modernization**: Extract reusable patterns before refactoring
- **Team onboarding**: Turn implicit conventions into explicit directives

### When NOT to use

- **Greenfield (session complete)**: Use `/team-learn` to extract from session
- **Mining git history**: Use `/change-init` for past decisions

## Process

### Phase 0: Environment Setup

Run: `scripts/team-init.sh --setup`

Resolves `REPO_ROOT`, `TEAM_AI_DIRECTIVES`, `NEXT_CDR`, `ADLC_BRANCH`.

### Phase 1: Sub-System Detection

Analyze codebase for distinct sub-systems (same detection as former team-init):
- `src/auth/` → Authentication
- `services/payment/` → Payment
- etc.

### Phase 2: Load Team Directives

Read existing `team-ai-directives` main branch for comparison (avoid duplicates).

### Phase 3: Multi-Agent Analysis

1. **Discovery Agent**: Scan each sub-system for raw patterns
2. **Pattern Agent**: Classify and score patterns for reusability
3. **Synthesis Agent**: Cross-sub-system analysis and CDR generation

### Phase 4: Write CDRs

Write to `adlc` branch `drafts/cdr/` using the shared CDR draft template at `skills/team/templates/cdr-draft-template.md`.

### Phase 5: Handoff

Suggest running `/team-learn` to review and publish the discovered CDRs.

## Verification

- [ ] CDRs written to `adlc` branch `drafts/cdr/`
- [ ] No CDRs in `.adlc/drafts/` (old location)
- [ ] `cdr.md` index regenerated in `adlc` branch
