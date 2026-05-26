---
description: Discover and load team constitution principles before project constitution
  update
---


<!-- Extension: team-ai-directives -->
<!-- Config: .specify/extensions/team-ai-directives/ -->
## Goal

Load team constitution from team-ai-directives to inherit principles BEFORE updating the project constitution. Output is auto-populated into agent context.

## Discovery Process

### Step 1: Locate Constitution

Check in order:
1. `{EXTENSION_ROOT}/context_modules/constitution.md`
2. `{EXTENSION_ROOT}/constitution.md` (root level, backward compat)

### Step 2: Read and Parse

Extract:
- **Core Principles** (numbered list with `**Principle Name**` pattern)
- **Governance rules**
- **Version info**

### Step 3: Output (Auto-populate Context)

Output the following Markdown block (prepend to agent prompt):

```markdown
## Team Constitution Principles (Loaded from team-ai-directives)

**Source**: team-ai-directives
**Version**: 1.3.0

### Core Principles

1. **Human Oversight Is Mandatory**
   Every autonomous contribution must receive human review before merge. Agents operate within guardrails; engineers are accountable for final outcomes.

2. **Build for Observability and Reproducibility**
   All features must include logging, metrics, and deterministic workflows so issues can be traced quickly.

3. **Security by Default**
   Follow least privilege for credentials, validate all inputs, and prefer managed secrets. Never ship hard-coded tokens.

4. **Tests Drive Confidence**
   Write automated tests before or alongside new logic. Refuse to ship when critical coverage is missing.

5. **Documentation Matters**
   Capture assumptions, API contracts, and hand-off notes in the repo. Agents and humans rely on clear context to move fast safely.

6. **Stateless Services**
   All services should be designed to be stateless. State should be externalized to databases or caches as needed.

7. **Zero Trust Security Model**
   Adopt a zero trust approach. Always verify and authenticate every request, implement least privilege access, and continuously monitor for threats.

8. **Think Before Coding**
   Don't assume. Don't hide confusion. Surface tradeoffs. State assumptions explicitly—if uncertain, ask rather than guess.

9. **Simplicity First**
   Minimum code that solves the problem. Nothing speculative. If 200 lines could be 50, rewrite it.

10. **Surgical Changes**
    Touch only what you must. Don't "improve" adjacent code. Match existing style, even if you'd do it differently.

11. **Goal-Driven Execution**
    Define success criteria. Loop until verified. Transform imperative tasks into verifiable goals with clear success metrics.

12. **Memory as the Harness Core**
    Every interaction generates traces that should accumulate into knowledge. Without memory, every execution starts from scratch.

---

*These principles should inform the project constitution during updates.*
```

## Usage

Automatically executed via **before_constitution** hook (optional: false).

## Failure Handling

If constitution files cannot be read:
1. Output a warning notice
2. Include `**Warning**: Team constitution not found in team-ai-directives`
3. Exit successfully (code 0) - don't block the preset command