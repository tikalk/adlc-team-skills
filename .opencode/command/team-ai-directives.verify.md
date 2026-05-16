---
description: Verify team-ai-directives installation and health check
---


<!-- Extension: team-ai-directives -->
<!-- Config: .specify/extensions/team-ai-directives/ -->
## Goal

Verify that team-ai-directives is properly installed and healthy.

## Verification Checks

1. **Context Modules exist**:
   - `context_modules/constitution.md`
   - `context_modules/personas/`
   - `context_modules/rules/`
   - `context_modules/examples/`

2. **Skills registry**: `.skills.json` exists and is valid

3. **CDR tracking**: `CDR.md` exists

## Output

Print verification status for each check:
- `[OK]` - Check passed
- `[FAIL]` - Check failed with reason