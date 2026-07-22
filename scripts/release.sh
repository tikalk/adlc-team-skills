#!/usr/bin/env bash
set -euo pipefail

# release.sh - Automated tag + GitHub release creator for adlc-team-skills
#
# Usage:
#   ./scripts/release.sh 0.9.1          # Tag HEAD and create GitHub release
#   ./scripts/release.sh 0.9.1 <sha>    # Tag specific commit
#
# Prerequisites:
#   - CHANGELOG.md entry exists for the version
#   - Working tree is clean (or GIT_ALLOW_DIRTY=1 is set)
#   - HEAD is pushed to origin
#   - gh CLI is authenticated

VERSION="$1"
COMMIT="${2:-HEAD}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [commit-sha]" >&2
  echo "  version: semver like 0.9.1" >&2
  echo "  commit-sha: optional, defaults to HEAD" >&2
  exit 1
fi

TAG="adlc-team-skills-v${VERSION}"

# Validate CHANGELOG entry exists
if ! grep -q "^## \\[${VERSION}\\]" CHANGELOG.md; then
  echo "ERROR: No CHANGELOG entry found for [${VERSION}]" >&2
  exit 1
fi

# Check working tree (unless bypassed)
if [[ "${GIT_ALLOW_DIRTY:-}" != "1" ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: Working tree is dirty. Commit or stash first, or set GIT_ALLOW_DIRTY=1" >&2
    exit 1
  fi
fi

# Check tag doesn't already exist
if git tag -l "$TAG" | grep -q .; then
  echo "ERROR: Tag $TAG already exists locally. Delete or bump version." >&2
  exit 1
fi

# Check remote tag doesn't already exist
if git ls-remote --tags origin "$TAG" 2>/dev/null | grep -q .; then
  echo "ERROR: Tag $TAG already exists on remote. Delete or bump version." >&2
  exit 1
fi

TAG_COMMIT=$(git rev-parse "$COMMIT")
echo "Creating tag $TAG at $TAG_COMMIT"

# Create annotated tag
git tag "$TAG" "$TAG_COMMIT" -m "v${VERSION}"

# Push tag
git push origin "$TAG"

# Extract CHANGELOG notes for this version
NOTES_FILE=$(mktemp)
trap 'rm -f "$NOTES_FILE"' EXIT
awk "/^## \\[${VERSION}\\]/{flag=1; next} /^## \\[/{flag=0} flag" CHANGELOG.md > "$NOTES_FILE"

if [[ ! -s "$NOTES_FILE" ]]; then
  echo "WARNING: No notes extracted from CHANGELOG for v${VERSION}. Creating empty release." >&2
fi

# Create GitHub release
gh release create "$TAG" \
  --title "adlc-team-skills v${VERSION}" \
  --notes-file "$NOTES_FILE" \
  --latest

echo "Done: https://github.com/tikalk/adlc-team-skills/releases/tag/${TAG}"
