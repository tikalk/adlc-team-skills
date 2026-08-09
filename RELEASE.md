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
3. **Merge the PR** — the **Auto-Tag Release** workflow creates the annotated
   tag at the merge commit automatically (see below). Manual tagging is only
   needed for pre-existing untagged versions (e.g. old gaps like `0.1.0`).
4. **Verify**: `gh release list` shows the new release as Latest, notes render correctly

## Automated tagging (after PR merge)

The **Auto-Tag Release** GitHub Actions workflow runs on every push to `main`:

1. Parses all `## [X.Y.Z]` headers from `CHANGELOG.md`.
2. Compares them against existing `adlc-team-skills-v*` tags.
3. Creates annotated tags for every **new** untagged version **newer than the
   latest existing tag**, pointing at the merge commit.
4. Each pushed tag triggers the **Release** workflow, which validates the
   CHANGELOG entry, confirms the commit is on `main`, extracts the notes, and
   creates the release with `--latest` — automatically.

Multi-version commits are handled: if one merge commit adds several new
CHANGELOG versions, each version gets its own tag at that commit.

## Manual release

If you prefer to tag explicitly (or are tagging a pre-existing untagged
version that the workflow deliberately skips):

1. Update `CHANGELOG.md` with the new version entry and commit/push to `main`.
2. Tag and push:
   ```bash
   git tag adlc-team-skills-vX.Y.Z -m "vX.Y.Z"
   git push origin adlc-team-skills-vX.Y.Z
   ```
3. The **Release** GitHub Actions workflow validates the CHANGELOG entry,
   confirms the commit is on `main`, extracts the notes, and creates the
   release with `--latest` — automatically.

If validation fails (e.g., missing CHANGELOG entry), the tag exists but no
release is created. Fix the issue, delete the tag, and re-tag:

```bash
git push origin :refs/tags/adlc-team-skills-vX.Y.Z
# fix CHANGELOG.md, commit, push to main
git tag adlc-team-skills-vX.Y.Z -m "vX.Y.Z"
git push origin adlc-team-skills-vX.Y.Z
```

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

The Auto-Tag Release workflow deliberately only tags versions **newer than the
latest existing tag**, so it will never auto-tag a historical gap (it would
point at the wrong commit). If an old version has a CHANGELOG entry but no
tag, tag its original release commit manually:

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
- The Auto-Tag Release workflow tags every new version in CHANGELOG.md on each push to `main`; it is a no-op when nothing is untagged
- Always mark the latest release with `--latest`
- Release notes come from the CHANGELOG section, not the commit message
