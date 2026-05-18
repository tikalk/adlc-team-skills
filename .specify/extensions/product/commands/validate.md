---
description: Validate feature spec alignment with PRD (READ-ONLY)
scripts:
  sh: .specify/extensions/product/scripts/bash/setup-product.sh "validate {ARGS}"
  ps: .specify/extensions/product/scripts/powershell/setup-product.ps1 "validate {ARGS}"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"specs/auth/spec.md"` - Validate specific feature spec
- `"specs/payments/"` - Validate all specs in directory
- Empty input: Validate all feature specs against PRD

## Goal

Perform **read-only** validation to ensure feature specifications align with the Product Requirements Document (PRD). This ensures technical implementations stay true to product requirements.

**This command validates**:

1. Feature scope aligns with PRD scope
2. User personas match PRD definitions
3. Success metrics are consistent with PRD metrics
4. Requirements are traced to PRD sections
5. No features are implemented that are explicitly out of scope
6. Demo sentences are specific and observable
7. Boundary maps are consistent across specs

**This command does NOT validate**:

- Technical architecture (use `/architect.validate`)
- Code quality or implementation details
- Test coverage

## Operating Constraints

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured validation report. Offer remediation suggestions (user must explicitly approve before any changes).

## Role & Context

You are acting as a **Product Validator** ensuring feature specs align with product requirements. Your role involves:

- **Verifying** feature scope matches PRD scope
- **Checking** persona alignment
- **Validating** metric consistency
- **Ensuring** requirements traceability

### Validation Context

| Document | Purpose | Role |
|----------|---------|------|
| `PRD.md` (root) | Product Requirements | Baseline |
| Feature `SPEC.md` | Feature Specification | Validation Target |
| `{REPO_ROOT}/.specify/drafts/pdr.md` | Product Decisions | Traceability Source |

## Outline

1. **Load PRD Baseline** - Load product PRD and PDRs
2. **Identify Feature Specs** - Find specs to validate
3. **Execute Validation Checks** - Scope, persona, metrics, traceability
4. **Generate Report** - Structured validation report

## Execution Steps

### Phase 1: Load PRD Baseline

**Objective**: Establish product requirements baseline

1. **Load PRD**:
   - Read `PRD.md` from project root
   - Parse all 11 sections (including Roadmap)
   - Extract scope definitions
   - Extract Milestone Roadmap

2. **Load PDRs**:
   - Read `{REPO_ROOT}/.specify/drafts/pdr.md`
   - Build decision index

3. **Build Baseline**:

   | Element | PRD Value | PDR Source |
   |---------|-----------|------------|
   | In-Scope Features | [List] | PDR-XXX (Scope) |
   | Out-of-Scope Features | [List] | PDR-XXX (Scope) |
   | Primary Persona | [Name] | PDR-XXX (Persona) |
   | Success Metrics | [List] | PDR-XXX (Metric) |

### Phase 2: Identify Feature Specs

**Objective**: Find all feature specs to validate

**Validation Targets**:

| Input | Action |
|-------|--------|
| Specific file | Validate single spec |
| Directory | Validate all specs in directory |
| Empty | Validate all `specs/*/spec.md` files |

**Spec Inventory**:

   | Feature | Path | Exists |
   |---------|------|--------|
   | [Feature] | `specs/{feature}/SPEC.md` | Yes/No |

### Phase 3: Execute Validation Checks

#### Check 1: Scope Alignment

**Objective**: Verify feature is within PRD scope

```markdown
## Scope Validation: [Feature Name]

### PRD In-Scope
- [Feature 1]
- [Feature 2]

### PRD Out-of-Scope
- [Excluded Feature 1]
- [Excluded Feature 2]

### Feature Scope
[What the feature implements]

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| In-Scope | ✅ PASS / ❌ FAIL | [Feature is listed in PRD] |
| Not Out-of-Scope | ✅ PASS / ❌ FAIL | [Feature is NOT in excluded list] |
```

#### Check 2: Persona Alignment

**Objective**: Verify feature serves defined personas

```markdown
## Persona Validation: [Feature Name]

### PRD Personas
- Primary: [Persona Name]
- Secondary: [Persona Name]

### Feature Target Users
[Who the feature serves]

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| Primary Persona Served | ✅ PASS / ⚠️ WARNING | [Check if primary is addressed] |
| Persona Needs Met | ✅ PASS / ❌ FAIL | [Check if needs are addressed] |
```

#### Check 3: Metric Consistency

**Objective**: Verify feature metrics align with PRD success metrics

```markdown
## Metric Validation: [Feature Name]

### PRD Success Metrics
- [Metric 1: Target]
- [Metric 2: Target]

### Feature Metrics
[Feature-specific metrics]

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| Aligned with PRD | ✅ PASS / ⚠️ WARNING | [Check metric alignment] |
| Additional Metrics | ℹ️ INFO | [Additional metrics defined] |
```

#### Check 4: Requirements Traceability

**Objective**: Verify feature requirements map to PRD

```markdown
## Traceability Validation: [Feature Name]

### Feature Requirements
| ID | Requirement | PRD Section |
|----|-------------|-------------|
| REQ-001 | [Requirement] | 6. Functional Requirements |

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| Traced to PRD | ✅ PASS / ❌ FAIL | [All requirements have PRD link] |
| Untraced Requirements | ℹ️ INFO | [Requirements without PRD link] |
```

#### Check 5: Out-of-Scope Detection

**Objective**: Detect features being built that are explicitly out of scope

```markdown
## Out-of-Scope Detection: [Feature Name]

### PRD Out-of-Scope
- [Excluded Feature]

### Feature Implementation
[What the feature actually does]

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| No Out-of-Scope | ✅ PASS / ❌ FAIL | [Nothing from exclusion list found] |

#### Check 6: Demo Sentence Validation

**Objective**: Verify demo sentences are specific and observable

The Demo Sentence is a GSD-inspired requirement: "After this feature, the user can: ___"

```markdown
## Demo Sentence Validation: [Feature Name]

### Found Demo Sentence
[Demo sentence from spec or placeholder]

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| Demo sentence exists | ✅ PASS / ❌ FAIL | Not placeholder "[complete this with...]" |
| Demo sentence is observable | ✅ PASS / ⚠️ WARNING | Human can verify the outcome |
| Demo sentence is specific | ✅ PASS / ⚠️ WARNING | Not vague like "have auth" |

**Validation Criteria**:
- ✅ PASS: Valid demo sentence that is observable and specific
- ⚠️ WARNING: Exists but could be more specific/observable
- ❌ FAIL: Placeholder or missing entirely
```

#### Check 7: Boundary Map Consistency

**Objective**: Verify interface contracts are consistent across specs

Boundary Maps ensure features declare what they produce and consume from other features.

```markdown
## Boundary Map Validation: [Feature Name]

### Produces
| Artifact | Type | Exports |
|----------|------|---------|
| [artifact] | [type] | [exports] |

### Consumes
| From Feature | Artifact | Imports |
|--------------|----------|---------|
| [feature] | [artifact] | [imports] |

### Validation Result
| Check | Status | Details |
|-------|--------|---------|
| Produces declared | ✅ PASS / ⚠️ WARNING | Feature declares outputs |
| Consumes satisfied | ✅ PASS / ❌ FAIL | All imports exist in upstream |
| No circular dependencies | ✅ PASS / ❌ FAIL | Dependency graph is acyclic |

**Validation Criteria**:
- **Produces**: Should list what this feature exports (types, endpoints, modules)
- **Consumes**: Should reference other features' produces
- **Circular dependency**: If Feature A consumes from Feature B and Feature B consumes from Feature A
```

### Phase 4: Generate Validation Report

```markdown
## Product Validation Report

### Summary

| Attribute | Value |
|-----------|-------|
| **PRD Baseline** | PRD.md |
| **Features Validated** | N |
| **Validation Date** | [Date] |

### Results

#### Feature: [Feature Name]

| Check | Status | Severity |
|-------|--------|----------|
| Scope Alignment | ✅ PASS | - |
| Persona Alignment | ✅ PASS | - |
| Metric Consistency | ⚠️ WARNING | MEDIUM |
| Traceability | ❌ FAIL | HIGH |
| Out-of-Scope | ✅ PASS | - |
| Demo Sentence | ✅ PASS | - |
| Boundary Map | ✅ PASS / ⚠️ WARNING | LOW |

**Issues**:
| ID | Check | Issue | Severity | Recommendation |
|----|-------|-------|----------|----------------|
| 1 | Traceability | REQ-002 not traced to PRD | HIGH | Add PRD section reference |
| 2 | Metrics | Feature metric conflicts with PRD target | MEDIUM | Review metric definition |
| 3 | Boundary Map | Consumes feature that doesn't exist | HIGH | Verify upstream feature |
| 4 | Demo Sentence | Placeholder not filled | MEDIUM | Add specific demo sentence |

### Coverage Summary

| Metric | Count |
|--------|-------|
| Features Validated | [N] |
| Features Passing All Checks | [N] |
| Features with Warnings | [N] |
| Features with Failures | [N] |

### Recommendations

**If Scope Mismatches:**
- **Align**: Remove features outside PRD scope
- Command: Edit `specs/{feature}/SPEC.md`

**If Persona Misalignment:**
- **Clarify**: Confirm feature serves correct personas
- Command: `/product.clarify` to refine persona PDRs

**If Traceability Gaps:**
- **Document**: Create PDRs for undocumented decisions
- Command: `/product.specify` to add scope decisions

**If Out-of-Scope Detected:**
- **Reassess**: Confirm feature should be built
- **Command**: Remove from spec or update PRD scope

**If Demo Sentence Issues:**
- **Fix**: Add specific observable outcome
- **Template**: "After this feature, the user can: [specific action and observable result]"

**If Boundary Map Issues:**
- **Fix**: Verify upstream features produce required artifacts
- **Check**: Run `/product.analyze` for cross-spec consistency

```

## Key Rules

### Validation Integrity

- **NEVER modify files** - this is read-only validation
- **Check all seven dimensions** - scope, persona, metrics, traceability, out-of-scope, demo sentence, boundary map
- **Use PRD as source of truth** - not PDRs alone
- **Report all issues** - don't suppress warnings

### Severity Assignment

| Severity | Criteria | Examples |
|----------|----------|----------|
| **CRITICAL** | Feature implements out-of-scope item | Building explicitly excluded feature |
| **HIGH** | Requirements not traced to PRD | No PRD section reference |
| **MEDIUM** | Metrics inconsistent with PRD | Target differs from PRD target |
| **LOW** | Minor alignment issues | Additional metrics defined |

### PRD Authority

- PRD scope is **authoritative** - out-of-scope is non-negotiable
- PRD metrics define **targets** - significant deviation should be flagged
- PRD personas are **canonical** - features should serve defined personas

## Workflow Guidance & Transitions

### After `/product.validate`

Based on findings, recommended next steps:

| Finding Type | Recommended Action |
|--------------|---------------------|
| Scope misalignment | Edit feature spec or update PRD |
| Persona issues | Review with product team |
| Metric inconsistency | Align with PRD targets or update PRD |
| Traceability gaps | Add PDR references or create new PDRs |
| Out-of-scope features | Remove feature or expand PRD scope |

### When to Use This Command

- **After `/spec.specify`**: Validate feature before technical planning
- **During spec review**: Ensure product alignment
- **Before development**: Final validation gate
- **Periodic check**: Ensure no scope creep

### When NOT to Use This Command

- **No PRD exists**: Create PRD first with `/product.implement`
- **No feature specs**: Nothing to validate
- **Technical validation**: Use `/architect.validate` instead

### Hook Context

This command is triggered via `after_spec` hook to ensure feature specs align with product requirements before technical planning begins.

## Context

{ARGS}
