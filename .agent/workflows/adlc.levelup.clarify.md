---
description: Resolve ambiguities in discovered/proposed CDRs through clarifying questions
handoffs:
- label: Refine from Feature Context
  agent: adlc.levelup.specify
  prompt: Add context from current feature spec to CDRs
  send: false
- label: Build Skills
  agent: adlc.levelup.skills
  prompt: Build skills from accepted CDRs
  send: false
- label: Create PR
  agent: adlc.levelup.implement
  prompt: Compile accepted CDRs to team-ai-directives PR
  send: false
scripts:
  sh: .specify/extensions/levelup/scripts/bash/setup-levelup.sh --json
  ps: .specify/extensions/levelup/scripts/powershell/setup-levelup.ps1 -Json
---


<!-- Extension: levelup -->
<!-- Config: .specify/extensions/levelup/ -->
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"CDR-001 CDR-003"` - Focus on specific CDRs
- `"rules"` - Clarify only rule-type CDRs
- `"all"` - Clarify all pending CDRs
- Empty input: Clarify all CDRs with status "Discovered" or "Proposed"

## Goal

Resolve ambiguities in discovered or proposed CDRs through **clarifying questions**. Update CDR statuses based on answers.

**Input**: CDRs from `.specify/memory/cdr.md` with status "Discovered" or "Proposed"

**Output**: Updated CDRs with refined content and new statuses

**Key Concept**:

This command is the "Context Validator" - it validates and refines CDR assumptions, similar to how `/architect.clarify` validates ADRs.

## Role & Context

You are acting as a **Context Validator** reviewing discovered patterns. Your role involves:

- **Validating** that discovered patterns are still relevant
- **Clarifying** pattern scope (team-wide vs project-specific)
- **Checking** against existing team-ai-directives for overlap
- **Prioritizing** patterns by value and impact
- **Refining** CDR content based on answers

### Clarification Categories

| Category | Questions to Ask |
|----------|------------------|
| **Validity** | Is this pattern still actively used? Has it been deprecated? |
| **Scope** | Is this team-wide or project-specific? Should other projects use this? |
| **Coverage** | Does team-ai-directives already cover this? Is this an enhancement? |
| **Priority** | Is this high-value or nice-to-have? What's the impact? |
| **Content** | Is the proposed content accurate? What's missing? |

## Execution Steps

### Phase 0: Environment Setup

**Objective**: Initialize CDR infrastructure and resolve paths

Run `{SCRIPT}` from repository root and parse JSON output:

```json
{
  "REPO_ROOT": "/path/to/project",
  "CDR_FILE": "/path/to/project/.specify/memory/cdr.md",
  "TEAM_DIRECTIVES": "/path/to/team-ai-directives",
  "TEAM_DIRECTIVES_EXISTS": true,
  "SKILLS_DRAFTS": "/path/to/project/.specify/drafts/skills",
  "BRANCH": "current-branch"
}
```

**IMPORTANT**: Run this script only ONCE. Use the JSON output to get all paths.

### Phase 1: Load Current State

**Objective**: Load CDRs and team-ai-directives for validation

#### Step 1: Load CDRs

Read CDR_FILE (from script output) and parse all CDRs.

Filter CDRs by status:
- **Primary**: Status = "Discovered" or "Proposed"
- **Skip**: Status = "Accepted", "Rejected", "Implemented"

If user specified specific CDR IDs, filter to those.

#### Step 2: Load Team Directives

If TEAM_DIRECTIVES_EXISTS is true, load existing team-ai-directives for comparison:
- `context_modules/constitution.md`
- `context_modules/rules/**/*.md`
- `context_modules/personas/*.md`
- `context_modules/examples/**/*.md`
- `skills/**/*`

### Phase 2: Clarification Loop

**Objective**: Ask clarifying questions for each CDR

For each CDR to clarify:

#### Question Set 1: Pattern Validity

```markdown
## CDR-{ID}: {Title}

**Context Type**: {type}
**Target Module**: {target}

### Validity Questions

1. **Is this pattern still actively used in the codebase?**
   - [ ] Yes, actively used
   - [ ] Partially used (some areas)
   - [ ] Deprecated/outdated
   - [ ] Unknown - needs investigation

2. **Has this pattern proven effective?**
   - [ ] Yes, with evidence (tests, production success)
   - [ ] Mostly, with some issues
   - [ ] Too new to evaluate
   - [ ] No, has known problems
```

#### Question Set 2: Scope Assessment

```markdown
### Scope Questions

3. **Should this pattern be adopted team-wide?**
   - [ ] Yes, all projects should use this
   - [ ] Yes, for projects with similar tech stack
   - [ ] Maybe, needs more evaluation
   - [ ] No, this is project-specific

4. **What's the learning curve for other teams?**
   - [ ] Low - easy to adopt
   - [ ] Medium - requires some documentation
   - [ ] High - requires training/support
```

#### Question Set 3: Coverage Check

```markdown
### Coverage Questions

5. **Does team-ai-directives already address this?**
   - [ ] No, this is new
   - [ ] Partially - this would enhance existing content
   - [ ] Yes, but from a different angle
   - [ ] Yes, this is a duplicate

6. **If enhancement, what existing content does it build on?**
   - Reference: {existing directive path}
```

#### Question Set 4: Priority Assessment

```markdown
### Priority Questions

7. **What's the impact of adding this to team-ai-directives?**
   - [ ] High - significantly improves team consistency
   - [ ] Medium - useful addition
   - [ ] Low - nice to have

8. **What's the urgency?**
   - [ ] High - needed for upcoming projects
   - [ ] Medium - beneficial soon
   - [ ] Low - can wait
```

#### Question Set 5: Content Review

```markdown
### Content Review

Current proposed content:

\`\`\`markdown
{proposed_content}
\`\`\`

9. **Is this content accurate and complete?**
   - [ ] Yes, ready to use
   - [ ] Needs minor edits
   - [ ] Needs significant revision
   - [ ] Needs complete rewrite

10. **What changes are needed?**
    - {user input for changes}
```

### Phase 3: Process Answers

**Objective**: Update CDRs based on clarification answers

#### Status Determination Logic

Based on answers, determine new status:

| Condition | New Status |
|-----------|------------|
| Valid + Team-wide + High/Medium priority + Content OK | **Accepted** |
| Valid + Team-wide + Needs content revision | **Proposed** (update content) |
| Valid but project-specific | **Rejected** (reason: project-specific) |
| Deprecated/outdated | **Rejected** (reason: outdated) |
| Duplicate of existing | **Rejected** (reason: duplicate) |
| Needs more investigation | **Proposed** (flag for follow-up) |

#### Content Updates

If content needs revision:

1. Incorporate user feedback
2. Update proposed content in CDR
3. Keep status as "Proposed" for another review cycle

### Phase 4: Update CDRs

**Objective**: Write updated CDRs to file

#### Step 1: Update CDR File

Update CDR_FILE (from script output) for each clarified CDR:

1. Update status
2. Update content if revised
3. Add clarification notes:

```markdown
### Clarification Notes

**Clarified**: {date}
**Validation**: {validity answer}
**Scope**: {scope answer}
**Priority**: {priority answer}
**Changes Made**: {list of changes}
```

#### Step 2: Update CDR Index

Update the index table with new statuses.

### Phase 5: Summary

**Objective**: Present clarification results

```markdown
## LevelUp Clarify Summary

**Date**: {date}
**CDRs Reviewed**: {N}

### Status Changes

| CDR | Previous | New | Reason |
|-----|----------|-----|--------|
| CDR-001 | Discovered | Accepted | Valid, team-wide, high priority |
| CDR-002 | Discovered | Rejected | Project-specific |
| CDR-003 | Proposed | Proposed | Content revised, needs re-review |

### Accepted CDRs (Ready for Implementation)

| CDR | Target Module | Type |
|-----|---------------|------|
| CDR-001 | rules/python/error-handling | Rule |

### Rejected CDRs

| CDR | Reason |
|-----|--------|
| CDR-002 | Project-specific, not team-wide |

### Pending CDRs (Need More Work)

| CDR | Issue |
|-----|-------|
| CDR-003 | Content revised, needs re-review |

### Next Steps

1. **Accepted CDRs**: Run `/levelup.implement` to create PR
2. **Pending CDRs**: Run `/levelup.clarify` again after revisions
3. **Build Skills**: Run `/levelup.skills {topic}` for skill-type CDRs
```

### Phase 6: Handoff Options

Present manual handoff options:

```markdown
### Available Handoffs

**Option 1: Refine from Feature Context**
Run `/levelup.specify` to:
- Add evidence from current feature spec
- Link CDRs to implementation

**Option 2: Build Skills**
Run `/levelup.skills {topic}` to:
- Build a skill from accepted CDRs

**Option 3: Create PR**
Run `/levelup.implement` to:
- Compile accepted CDRs into PR
- Submit to team-ai-directives
```

## Output Files

| File | Description |
|------|-------------|
| `.specify/memory/cdr.md` | Updated Context Directive Records |

## Notes

- Only CDRs with status "Discovered" or "Proposed" are clarified
- Accepted CDRs are ready for `/levelup.implement`
- Rejected CDRs remain in the file for historical record
- Content can be revised multiple times before acceptance
- No automatic handoff - user decides next step

## Related Commands

- `/levelup.init` - Discover CDRs from codebase
- `/levelup.specify` - Refine CDRs from feature context
- `/levelup.skills` - Build skills from accepted CDRs
- `/levelup.implement` - Create PR to team-ai-directives
- `/architect.clarify` - Similar pattern for ADR clarification