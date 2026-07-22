# Release Process

This repo uses [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Tag naming convention

```
adlc-team-skills-v{MAJOR.MINOR.PATCH}
```

Examples: `adlc-team-skills-v0.9.0`, `adlc-team-skills-v1.0.0`

## Release checklist

1. **Update `CHANGELOG.md`** — add the new version entry at the top with a date and Added/Changed/Fixed/Removed sections
2. **Commit and push** — all changes committed and pushed to `main`
3. **Create annotated tag** at the release commit:
   ```bash
   git tag adlc-team-skills-vX.Y.Z -m "vX.Y.Z"
   ```
4. **Push the tag**:
   ```bash
   git push origin adlc-team-skills-vX.Y.Z
   ```
5. **Create GitHub release** with the CHANGELOG section as notes:
   ```bash
   awk '/^## \[X.Y.Z\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md \
     | gh release create adlc-team-skills-vX.Y.Z --title "adlc-team-skills vX.Y.Z" --notes-file - --latest
   ```
6. **Verify**: `gh release list` shows the new release as Latest, notes render correctly

## Automated release

Use the helper script to automate steps 3-5:

```bash
./scripts/release.sh 0.9.1
```

The script validates: CHANGELOG entry exists, working tree clean, HEAD pushed to origin, tag doesn't already exist — then tags, pushes, extracts notes, and creates the GitHub release with `--latest`.

## Recovery procedures

### Tag at wrong commit

If a tag was created at the wrong commit and needs to move:

```bash
# Delete local tag
git tag -d adlc-team-skills-vX.Y.Z

# Delete remote tag
git push origin :refs/tags/adlc-team-skills-vX.Y.Z

# Re-tag at correct commit
git tag adlc-team-skills-vX.Y.Z <commit-sha> -m "vX.Y.Z"

# Push new tag
git push origin adlc-team-skills-vX.Y.Z

# If a GitHub release already exists, delete and recreate
gh release delete adlc-team-skills-vX.Y.Z --yes
gh release create adlc-team-skills-vX.Y.Z --title "adlc-team-skills vX.Y.Z" --notes-file - --latest
```

### Missing tag for old version

If a version has a CHANGELOG entry but no tag:

```bash
# Tag the release commit retroactively
git tag adlc-team-skills-vX.Y.Z <commit-sha> -m "vX.Y.Z"
git push origin adlc-team-skills-vX.Y.Z

# Create release with notes from CHANGELOG at HEAD
awk '/^## \[X.Y.Z\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md \
  | gh release create adlc-team-skills-vX.Y.Z --title "adlc-team-skills vX.Y.Z" --notes-file -
```

### Tag exists but no GitHub release

```bash
awk '/^## \[X.Y.Z\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md \
  | gh release create adlc-team-skills-vX.Y.Z --title "adlc-team-skills vX.Y.Z" --notes-file -
```

## Version numbering

- **MAJOR** (1.0.0): Breaking changes — skill names renamed/removed, frontmatter format changes
- **MINOR** (0.X.0): New skills added, new features in existing skills, non-breaking changes
- **PATCH** (0.0.X): Bug fixes, documentation updates, path corrections

## Notes

- One tag per CHANGELOG version entry
- If multiple CHANGELOG versions are bundled into a single commit, tag the same commit for each version
- Always mark the latest release with `--latest`
- Release notes come from the CHANGELOG section, not the commit message
