---
description: |
  Build a reusable skill from accepted CDRs for team AI directives.
  Use when user requests "build skill", "create skill from CDR", 
  "package as skill", "skill for {topic}", or mentions creating
  reusable AI capabilities from accepted design records. Input:
  skill name, CDR ID, or topic string. Only works with CDRs
  having status "Accepted".
scripts:
  sh: .specify/extensions/levelup/scripts/bash/setup-levelup.sh --json
  ps: .specify/extensions/levelup/scripts/powershell/setup-levelup.ps1 -Json
---

## User Input

```text
$ARGUMENTS
```

**REQUIRED**: Require user input before proceeding. STOP if missing.

**Examples**:

| Input | Type | Action |
|-------|------|--------|
| `"python-error-handling"` | Skill name | Build skill with this name |
| `"CDR-005"` | CDR ID | Build from specific CDR |
| `"testing patterns"` | Topic | Match CDRs by topic |

STOP and request skill name, CDR ID, or topic if input is empty.

## Goal

Build exactly ONE skill per invocation from accepted CDRs. Skills are self-contained capabilities for AI agents.

**Input**:
- User-specified skill name, CDR ID, or topic
- Accepted CDRs from `{REPO_ROOT}/.specify/drafts/cdr.md` (status "Accepted")

**Output**:
- Skill directory in `{REPO_ROOT}/.specify/drafts/skills/{skill-name}/`
- Entry in `{REPO_ROOT}/.specify/drafts/skills/{skill-name}/.skills-entry.json`

## Output Format

Present results in this exact structure:

```markdown
## LevelUp Skills Summary

**Skill**: {kebab-case-name}
**Source**: CDR-XXX, CDR-YYY
**Location**: `{REPO_ROOT}/.specify/drafts/skills/{name}/`

### Files Created
| File | Purpose | Status |
|------|---------|--------|
| SKILL.md | Main skill definition | Created |
| .skills-entry.json | Manifest entry | Created |
| references/ | Supporting content | Created |

### SKILL.md Preview (Lines 1-30)
```markdown
{First 30 lines}
```

### Next Steps
1. Review generated skill
2. Edit SKILL.md if needed  
3. Run `/levelup.implement` to activate
```

## Role & Context

Act as **Skill Builder** - package accepted CDRs into reusable skills.

**Responsibilities**:
- Identify relevant CDRs for the skill
- Structure skill content per team-ai-directives format
- Write SKILL.md with trigger keywords
- Organize references and supporting content

### Skill Structure

```
.specify/drafts/skills/{skill-name}/
├── SKILL.md           # Main skill definition (REQUIRED)
└── references/        # Supporting content (OPTIONAL)
    ├── examples/
    └── patterns/
```

## Out of Scope

This command does NOT:

- Build multiple skills at once (run `/levelup.skills` repeatedly for each)
- Push skills to team-ai-directives (use `/levelup.implement` for that)
- Create pull requests (handled by implement phase)
- Modify existing skills (manual edit required, then re-implement)
- Accept or propose CDRs (use `/levelup.clarify` first)
- Work with CDRs not having status "Accepted"

**Routing**: If user asks for these, redirect to the appropriate command.

## Execution Steps

### Phase -1: Read Existing Skills (Read First)

**Objective**: Analyze existing skill patterns for consistency

Before building any new skill:

1. List existing skills in `.specify/drafts/skills/`
2. If any exist, read 2-3 SKILL.md files
3. Note patterns in:
   - Description style and length
   - Section ordering (When to Use vs Capabilities)
   - Verb tense (imperative vs descriptive)
   - Trigger keyword density
4. Match existing style in generated skill

If no existing skills, use standard format in templates below.

### Phase 0: Environment Setup

**Objective**: Initialize CDR infrastructure and resolve paths

Run `{SCRIPT}` from repository root and parse JSON output:

```json
{
  "REPO_ROOT": "/path/to/project",
  "TEAM_DIRECTIVES": "/path/to/team-ai-directives",
  "SKILLS_DRAFTS": "/path/to/project/.specify/drafts/skills",
  "BRANCH": "current-branch"
}
```

Run script exactly ONCE. Cache JSON output for reuse.

Skills will be created in SKILLS_DRAFTS directory.

### Phase 1: Validate Environment

**Objective**: Ensure team-ai-directives is configured

Check if TEAM_DIRECTIVES has a value from script output.

If empty, **STOP**:
```
Team AI directives repository not configured.
Run: specify init --team-ai-directives <path-or-url>
Or set: export SPECIFY_TEAM_DIRECTIVES=/path/to/team-ai-directives
```

### Phase 2: Parse User Input

**Objective**: Determine which skill to build and detect instruction type

Parse user input to identify:

| Input Type | Detection | Action |
|------------|-----------|--------|
| CDR ID | Matches `CDR-\d+` | Build skill from that CDR |
| Skill name | kebab-case string | Use as skill name, find matching CDRs |
| Topic | Multi-word phrase | Search CDRs by topic |

#### Instruction Type Detection

After parsing input, detect the instruction type:

1. Check user input for trigger phrases:
   - Contains "generate", "create", "implement", "write new" → **Generation**
   - Contains "review", "check quality", "audit" → **Review**
   - Contains "refactor", "clean up", "simplify", "optimize" → **Refactor**
   - Contains "security", "vulnerability", "audit" → **Security**
   - Otherwise → **General Capability**

2. If matched, set instruction type accordingly
3. If no match, default to "General Capability"

**Prompt user**:
```markdown
**Instruction Type Detected**: {type}

Apply four-part anatomy for executable standards? (Y/n)

- Y: Use the four-part structure (Role → Context → Categorized Standards → Output Format)
- n: Use standard skill format
```

If user confirms Y, apply four-part anatomy template in Phase 4.

If input is ambiguous, ask for clarification.

### Phase 3: Load and Filter Modules

**Objective**: Find relevant accepted modules

#### Step 1: Load Modules

Read `{REPO_ROOT}/.specify/drafts/cdr.md` and filter CDRs:
- Status = "Accepted"
- Type = "skill" (primary) or related types

#### Step 2: Match Modules to Input

If module ID provided:
- Use that specific module
- Optionally include related modules

If skill name/topic provided:
- Search module paths and content
- Match by keywords
- Present matches for confirmation

```markdown
### Matching Modules for "{input}"

| Module | Path | Type | Relevance |
|--------|------|------|-----------|
| k8s_deployment | context_modules/rules/devops/k8s_deployment.md | rule | High |
| container_patterns | context_modules/rules/devops/container_patterns.md | rule | Medium |

**Selected**: CDR-005, CDR-007

Proceed with these CDRs? (Y/N or specify different CDRs)
```

### Phase 4: Generate Skill Structure

**Objective**: Create skill directory and files

#### Step 1: Create Directory

Use SKILLS_DRAFTS from script output:

```bash
mkdir -p {SKILLS_DRAFTS}/{skill-name}/references
```

#### Step 2: Detect Instruction Type from CDR

If not already detected in Phase 2, check the CDR's instruction type:

1. Read the CDR's Context Type and any instruction_type field
2. If instruction type is Generation/Review/Refactor/Security, apply four-part anatomy

#### Step 3: Generate SKILL.md

Build SKILL.md from CDR content using merged template:

```markdown
# {Skill Name}

{Description from CDR with trigger keywords}

**Instruction Type**: {Generation | Review | Refactor | Security | General Capability}

Use this skill when: {trigger conditions}

{% if instruction_type in ["Generation", "Review", "Refactor", "Security"] %}
## Part 1: Role Definition

Role: {senior engineer | reviewer | security expert} following team patterns for {instruction type}

## Part 2: Context Requirements

- **Required**: {code context, project architecture, team conventions}
- **Optional**: {additional constraints}

## Part 3: Categorized Standards

### Critical (Must Follow)
- {Non-negotiable patterns, security requirements, architectural constraints}
- {Add from CDR proposed content}

### Standard (Should Follow)
- {Conventions that are most commonly corrected}
- {Add from CDR proposed content}

### Preference (Nice to Have)
- {Style variations, minor optimizations}
- {Add from CDR proposed content}

## Part 4: Output Format

- **Summary**: {Brief overview of what was done}
- **Categorized Findings**: {Critical/Standard/Preference structure}
- **Next Steps**: {Action items for the developer}
{% else %}
## When to Use

- {Condition 1 from CDR context}
- {Condition 2}
- {Condition 3}

## Capabilities

This skill enables AI agents to:

- {Capability 1 from CDR decision}
- {Capability 2}
- {Capability 3}

## Instructions

### Step 1: {First Step}

{Instructions from CDR proposed content}

### Step 2: {Second Step}

{More instructions}
{% endif %}

## Trigger Keywords

{keywords for skill discovery}

## Examples

### Example 1: {Example Name}

{Code or usage example from CDR evidence}

### Example 2: {Another Example}

{Additional example}

## References

- [Pattern Details](references/pattern.md)
- [Examples](references/examples/)

## Source

Built from CDRs:
- CDR-{N}: {title}

---

*Skill Version: 1.0.0*
*Compatible with team-ai-directives*
```

#### Step 4: Create Reference Files

If CDRs contain substantial content, create reference files:

```
references/
├── pattern.md       # Detailed pattern description
├── examples/
│   ├── basic.md     # Basic usage example
│   └── advanced.md  # Advanced usage example
└── checklists/
    └── validation.md # Validation checklist
```

### Phase 5: Prepare Skills Manifest Entry

**Objective**: Prepare entry for `.skills.json`

Generate the entry for team-ai-directives `.skills.json`:

```json
{
  "local:./skills/{skill-name}": {
    "version": "1.0.0",
    "description": "{description with trigger keywords}",
    "categories": ["{category1}", "{category2}"],
    "instruction_type": "{Generation|Review|Refactor|Security|General Capability}"
  }
}
```

**Note**: The `instruction_type` field encodes how the skill should be used by AI agents.

Save to `{REPO_ROOT}/.specify/drafts/skills/{skill-name}/.skills-entry.json` for `/levelup.implement`.

### Phase 6: Validation

**Objective**: Validate skill structure

Check skill completeness:

- [ ] SKILL.md exists with required sections
- [ ] Description includes trigger keywords
- [ ] At least one example provided
- [ ] `.skills-entry.json` generated
- [ ] Instruction type specified

### Phase 7: Summary

**Objective**: Present skill for review

Use the **Output Format** section defined at the top of this command.

## Output Files

| File | Description |
|------|-------------|
| `.specify/drafts/skills/{skill-name}/SKILL.md` | Main skill definition |
| `.specify/drafts/skills/{skill-name}/references/` | Supporting content |
| `.specify/drafts/skills/{skill-name}/.skills-entry.json` | Entry for `.skills.json` (applied during implement) |

## Notes

- Builds ONE skill at a time - user specifies which
- Only uses CDRs with status "Accepted" from `.specify/drafts/cdr.md`
- Skills follow team-ai-directives format for compatibility
- Review generated skill before running `/levelup.implement`
- Skill can be edited manually before implementation

## Related Commands

- `/levelup.init` - Discover modules from codebase
- `/levelup.clarify` - Accept modules for skill building
- `/levelup.specify` - Enrich modules with feature context
- `/levelup.implement` - Move skill to team-ai-directives and set status to "active"
