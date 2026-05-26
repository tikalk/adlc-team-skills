---
description: Validate and auto-correct release readiness
---


<!-- Extension: team-ai-directives -->
<!-- Config: .specify/extensions/team-ai-directives/ -->
## Goal

Ensure all version information is synchronized and ready for release. Auto-corrects inconsistencies by default.

## Validation Checks

### Check 1: Version Synchronization

1. Read `extension.yml` → extract `extension.version`
2. Read `extensions/catalog.json` → extract `extensions.*.version`
3. If mismatch:
   - **Auto-correct**: Update `catalog.json` to match `extension.yml`
   - Report: `[FIXED] Version sync: catalog.json updated to X.X.X`

### Check 2: Repository URL Consistency

1. Read `extension.yml` → extract `extension.repository`
2. Read `extensions/catalog.json` → extract `extensions.*.repository`
3. Get git remote origin URL → extract actual org name
4. Compare repository org with git remote org:
   - **If match**: 
     - Report: `[OK] Repository URL: {org} (consistent with git remote)`
   - **If mismatch**:
     - **Auto-correct**: Update both `extension.yml` and `catalog.json` to match git remote
     - Report: `[FIXED] Repository URL updated to match git remote: {org}`

This approach works for both upstream and fork repositories without hardcoding org names.

### Check 3: Timestamp Freshness

1. Read `extensions/catalog.json` → extract `updated_at`
2. Check if date is today or within last 24 hours
3. If stale:
   - **Auto-correct**: Update `updated_at` to current ISO 8601 timestamp
   - Report: `[FIXED] Timestamp updated to YYYY-MM-DDTHH:MM:SSZ`

### Check 4: Fork Detection

1. Check git remote URL
2. If remote differs from `tikalk/agentic-sdlc-team-ai-directives`:
   - Detect fork name from remote
   - Validate version format: `{upstream}+{fork_name}{number}`
   - Report: `[INFO] Fork detected: {fork_org}`
   - Report: `[INFO] Fork version format: {version}`

### Check 5: Git Tag Status

1. Check if git tag `v{VERSION}` already exists
2. If exists:
   - Report: `[WARN] Tag v{VERSION} already exists`
   - Suggest: Increment version or skip tagging
3. If not exists:
   - Report: `[OK] Tag v{VERSION} does not exist (ready to create)`

## Output Format

```
Release Validation & Auto-Correction
====================================

Version: X.X.X
Repository: tikalk/agentic-sdlc-team-ai-directives

[FIXED] Version sync: catalog.json updated to X.X.X
[OK] Repository URL: tikalk (consistent with git remote)
[FIXED] Timestamp updated to 2026-05-22T00:00:00Z
[OK] Tag vX.X.X does not exist (ready to create)

Release Ready: YES

Changes made:
- extensions/catalog.json: version updated
- extensions/catalog.json: timestamp updated

Next steps:
1. Review changes: git diff
2. Commit: git commit -am "chore: prepare release vX.X.X"
3. Tag: git tag vX.X.X
4. Push: git push origin main --tags
```

## Fork Output Example

```
Release Validation & Auto-Correction
====================================

Version: 1.6.1+acme1
Repository: acme/agentic-sdlc-team-ai-directives
Upstream: tikalk/agentic-sdlc-team-ai-directives

[OK] Fork version format: 1.6.1 + acme1
[OK] Repository URL: acme (consistent with git remote)
[FIXED] Timestamp updated to 2026-05-22T00:00:00Z
[OK] Tag v1.6.1+acme1 does not exist

Release Ready: YES (fork release)
```

## Exit Codes

- 0 - Release ready (all checks passed or auto-corrected)
- 1 - Cannot auto-correct (manual intervention needed)

## Skip Auto-Correction

Set `RELEASE_DRY_RUN=true` to validate without making changes.