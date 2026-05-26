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
   - `context_modules_examples/`

2. **Skills registry**: `.skills.json` exists and is valid

3. **CDR tracking**: `CDR.md` exists

4. **Constitution alignment**: Project constitution inherits from team principles

## Verification Details

### Check 1-3: Standard Infrastructure

Run these checks as before:
- `[OK]` - Check passed
- `[FAIL]` - Check failed with reason

### Check 4: Constitution Alignment

1. Locate project constitution: `{REPO_ROOT}/.specify/memory/constitution.md`
2. If file exists, check for team source reference (e.g., "Based on team-ai-directives", "Inherits from")
3. Parse principles - team constitution has 12 core principles
4. Output:
   - `[OK]` - Project constitution exists and references team source
   - `[WARN]` - Project constitution exists but no team source reference (missing inheritance)
   - `[OK]` - Project constitution doesn't exist yet (not required, first-time setup)

### Check 5: Version Consistency (Warning Only)

Lightweight check to catch sync issues early:

1. Read `extension.yml` → extract `extension.version`
2. Read `extensions/catalog.json` → extract `extensions.*.version`
3. Compare versions
4. Output:
   - `[OK]` - Versions match
   - `[WARN]` - Version mismatch: extension.yml=X, catalog.json=Y
   - `[INFO]` - Run 'adlc.team-ai-directives.release' to fix

This check does NOT fail the verification, only warns.

## Output

Print verification status for each check:
- `[OK]` - Check passed
- `[FAIL]` - Check failed with reason
- `[WARN]` - Check passed with warnings (non-blocking)

**Exit codes:**
- 0 - All checks passed (including warnings)
- 1 - One or more checks failed