#!/usr/bin/env bash
# setup-change-publish.sh — Setup for change-publish (self-contained)
set -euo pipefail

resolve_project_root() {
  local dir
  dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.adlc" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

PROJECT_ROOT=$(resolve_project_root)
CHDR_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/chdr"
MEMORY_DIR="${PROJECT_ROOT}/.adlc/memory/chdr"
MEMORY_INDEX="${PROJECT_ROOT}/.adlc/memory/chdr.md"

mkdir -p "$MEMORY_DIR" 2>/dev/null || true

# Accepted ChDR ids (filenames) in drafts
ACCEPTED_CHDRS=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | xargs -r -n1 basename 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
ACCEPTED_COUNT=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
PUBLISHED_COUNT=$( { grep -l '^### Status: \*\*Published\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
MEMORY_COUNT=$( { ls -1 "$MEMORY_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
MEMORY_INDEX_EXISTS=$([[ -f "$MEMORY_INDEX" ]] && echo "true" || echo "false")

python3 - "$PROJECT_ROOT" "$CHDR_DRAFTS_DIR" "$MEMORY_DIR" "$MEMORY_INDEX" "$ACCEPTED_CHDRS" "$ACCEPTED_COUNT" "$PUBLISHED_COUNT" "$MEMORY_COUNT" "$MEMORY_INDEX_EXISTS" << 'PY'
import json, sys
accepted = sys.argv[5].split() if sys.argv[5].strip() else []
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CHDR_DRAFTS_DIR": sys.argv[2],
  "MEMORY_DIR": sys.argv[3],
  "MEMORY_INDEX": sys.argv[4],
  "ACCEPTED_CHDRS": accepted,
  "ACCEPTED_COUNT": int(sys.argv[6]),
  "PUBLISHED_COUNT": int(sys.argv[7]),
  "MEMORY_COUNT": int(sys.argv[8]),
  "MEMORY_INDEX_EXISTS": sys.argv[9] == "true"
}))
PY
