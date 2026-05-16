---
description: Generate and validate AI session execution traces from implementation
  metadata.
scripts:
  sh: .specify/extensions/levelup/scripts/bash/generate-trace.sh --json
  ps: .specify/extensions/levelup/scripts/powershell/generate-trace.ps1 -Json
validation_script:
  sh: scripts/bash/validate-trace.sh --json
  ps: scripts/powershell/validate-trace.ps1 -Json
---


<!-- Extension: levelup -->
<!-- Config: .specify/extensions/levelup/ -->
## Overview

The `/levelup.trace` command generates comprehensive AI session execution traces from implementation metadata and feature artifacts. Traces include a **human-friendly Summary** (Problem → Key Decisions → Final Solution) followed by detailed technical sections for tool integration and learning.

**Purpose**:

- **Narrative summary** - Quick scan of what happened (Problem/Decisions/Solution)
- Document AI agent session for reusability
- Capture decision-making patterns and problem-solving approaches
- Record execution context (quality gates, reviews, MCP tracking)
- Identify reusable patterns for similar contexts
- Provide evidence trail (commits, issues, files)

**Output**: `specs/{BRANCH}/trace.md` - Stored with feature artifacts, version-controlled

**Structure**: Summary section (3-part narrative) + 5 technical sections (metadata and patterns)

**Note**: This command LevelUp extension. is part of the Run `/levelup.specify` after trace to extract CDRs with enriched context.

## When to Use

Run `/levelup.trace` after completing `/implement` to capture the full execution session:

```text
/implement → tasks_meta.json created
     ↓
/levelup.trace → Generate session trace
     ↓
specs/{BRANCH}/trace.md created
     ↓
/levelup.specify → Consume trace for CDR extraction (optional)
```

**Best Practices**:

- Run after all tasks complete and quality gates pass
- Generate before `/levelup.specify` for richer CDR extraction
- Re-run to update trace as understanding evolves
- Review trace for learning and knowledge transfer

## Execution Flow

### Step 1: Prerequisites Validation

1. **Execute trace generation script**: `{SCRIPT}`
2. **Parse JSON output** for paths and validation results
3. **Prerequisites checked**:
   - `spec.md` exists
   - `plan.md` exists
   - `tasks.md` exists
   - `tasks_meta.json` exists and valid JSON
   - Feature branch is active

If any prerequisite fails, **STOP** with clear error message directing user to run required commands first.

### Step 2: Trace Generation

The generation script automatically extracts:

#### Summary Section (NEW)

Human-friendly 3-part narrative placed at the top:

**Problem**:

- Extracted from spec mission + all user stories
- Synthesized into 1-2 sentence goal statement
- Example: "Implement user authentication with JWT tokens and refresh token rotation"

**Key Decisions** (chronologically):

- Architecture decisions (framework, design choices)
- Technology choices (libraries, tools)
- Testing strategy (TDD, risk-based)
- Process decisions (SYNC/ASYNC breakdown)
- Integration choices (APIs, external services)
- Issue tracking integration
- Dynamic count based on feature complexity
- Example: "1. Chose React with TypeScript 2. Implemented TDD approach 3. Applied dual execution loop..."

**Final Solution**:

- Outcome statement with key metrics
- Quality gate pass rate
- User story completion count
- Commit reference
- Issue tracker count
- Example: "Delivered implementation with 8/8 quality gates passed (100%). All 4 user stories validated. Documented in commit a1b2c3d."

---

#### Section 1: Session Overview

- Feature title and mission
- Key architectural decisions from plan
- Implementation approach summary

#### Section 2: Decision Patterns

- Triage classification (SYNC vs ASYNC breakdown)
- Technology choices and stack
- Problem-solving approaches used

#### Section 3: Execution Context

- Quality gate statistics (passed/failed/total)
- Execution modes distribution (SYNC/ASYNC)
- Review status (micro-reviewed/macro-reviewed)
- MCP job tracking (if applicable)

#### Section 4: Reusable Patterns

- Effective methodologies (ASYNC delegation success, micro-review patterns)
- Testing approaches (TDD, risk-based testing)
- Applicable contexts for pattern reuse

#### Section 5: Evidence Links

- Implementation commits and messages
- Issue tracker references (@issue-tracker links)
- Modified code paths
- Feature artifact locations

**Output**: Trace file at `specs/{BRANCH}/trace.md`

### Step 3: Trace Validation

1. **Execute validation script**: `{VALIDATION_SCRIPT}`
2. **Parse validation results**:
   - Section completeness (all 5 sections populated)
   - Coverage percentage (sections_valid / total_sections)
   - Quality gate pass rate
   - Warnings and recommendations

#### Validation Criteria

**Section Completeness**:

- ✅ Each section exists and has ≥5 lines
- ✅ All 5 sections present (80%+ coverage required)

**Quality Indicators**:

- Quality gate pass rate ≥80% (warning if lower)
- Evidence links include commits and issues
- Reusable patterns identified

**Coverage Thresholds**:

- **100%**: All sections complete - Excellent
- **80-99%**: Most sections complete - Good
- **<80%**: Incomplete trace - Needs improvement

### Step 4: Report Results

Display validation report including:

```text
✅ Trace generation complete
   File: specs/001-feature-name/trace.md
   Sections: Summary + 5 sections (6/6)
   Coverage: 100%

📋 Summary Preview:
   Problem: Implement Factor IX blood coagulation cascade
   Decisions: 6 key decisions documented
   Solution: 8/8 quality gates passed (100% pass rate)

Quality Gates:
  Passed: 8
  Failed: 0
  Total: 8
  Pass Rate: 100%

✅ Trace validation passed
```

If validation fails (coverage <80%), show warnings and recommendations:

```text
⚠️  Warnings:
   - Reusable Patterns section missing or incomplete
   
💡 Recommendations:
   - Identify effective methodologies and applicable contexts
```

## Mode Awareness

### Build Mode

- Trace generation supported
- Lighter context capture
- Focused on core execution data
- Suitable for lightweight learning

### Spec Mode

- Comprehensive trace generation
- Full decision pattern analysis
- Detailed evidence linking
- Rich context for knowledge sharing

**Both modes**: Trace is optional but valuable for learning and `/levelup.specify` enrichment.

## Key Features

**Automatic Extraction**:

- No manual input required
- Parses tasks_meta.json for execution data
- Reads spec, plan, tasks for context
- Extracts git history and issue references

**Idempotent Operation**:

- Re-running `/levelup.trace` overwrites previous trace
- Always reflects latest execution state
- Single trace.md per feature (latest)

**Integration Points**:

- `/levelup.specify` reads trace.md if exists (optional)
- `/analyze` can validate trace completeness
- Version-controlled with feature artifacts
- Natural handoff to other LevelUp commands

## Common Scenarios

### Scenario 1: Post-Implementation Trace

```text
User: /levelup.trace
Agent: [Generates trace from tasks_meta.json]
Result: specs/001-feature/trace.md created with 5 sections
```

### Scenario 2: Trace Before Levelup

```text
User: /levelup.trace
Agent: [Generates comprehensive trace]
User: /levelup.specify
Agent: [Reads trace.md for enriched context packet]
```

### Scenario 3: Update Existing Trace

```text
User: /levelup.trace
Agent: [Overwrites previous trace with latest execution data]
Result: Updated trace reflects current implementation state
```

## Error Handling

**Missing Prerequisites**:

```text
ERROR: tasks_meta.json not found
Please run /implement before generating a trace.
```

**Invalid JSON**:

```text
ERROR: tasks_meta.json is not valid JSON
Check execution metadata for corruption.
```

**Validation Failures**:

- Non-blocking: Trace still generated
- Warnings displayed with recommendations
- User can address gaps and re-run `/levelup.trace`

## Important Notes

- **Storage**: Trace stored in `specs/{BRANCH}/` with other artifacts
- **Overwrite**: Previous trace replaced (single latest trace)
- **Build Mode**: Supported - generates lightweight traces
- **Spec Mode**: Supported - generates comprehensive traces
- **Optional**: Trace not required for workflow but enhances `/levelup.specify`
- **Version Control**: Commit trace.md with feature implementation
- **Extension**: This command is part of LevelUp extension for team learning

## Success Criteria

✅ Trace file generated at `specs/{BRANCH}/trace.md`  
✅ **Summary section present with Problem/Decisions/Solution**  
✅ All 6 sections populated (Summary + 5 technical sections)  
✅ Coverage ≥80% (6/6 sections complete)  
✅ Problem statement is 1-2 sentences  
✅ Key decisions list has 3+ items chronologically  
✅ Final solution includes outcome + metrics  
✅ Quality gate statistics extracted correctly  
✅ Evidence links include commits and issues  
✅ Validation report displays clearly  
✅ Reusable patterns identified  

---

**Next Steps**: After generating trace, optionally run `/levelup.specify` to extract Context Directive Records (CDRs) from your completed feature for team-ai-directives contributions. The trace enriches CDR extraction with detailed execution context.

## Related Commands

- `/levelup.init` - Discover CDRs from codebase
- `/levelup.clarify` - Resolve ambiguities and accept CDRs
- `/levelup.specify` - Extract CDRs from feature context (uses trace if available)
- `/levelup.skills` - Build skills from accepted CDRs
- `/levelup.implement` - Create PR to team-ai-directives