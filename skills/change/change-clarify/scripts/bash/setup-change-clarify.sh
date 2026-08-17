#!/usr/bin/env bash
# setup-change-clarify.sh — Setup for change-clarify (self-contained)
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

mkdir -p "$CHDR_DRAFTS_DIR" 2>/dev/null || true

ACCEPTED_CHDRS=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
PENDING_CHDRS=$( { grep -lE '^### Status: \*\*(Discovered|Proposed)\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
EXISTING_CHDRS=$( { ls -1 "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')

python3 - "$PROJECT_ROOT" "$CHDR_DRAFTS_DIR" "$MEMORY_DIR" "$ACCEPTED_CHDRS" "$PENDING_CHDRS" "$EXISTING_CHDRS" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CHDR_DRAFTS_DIR": sys.argv[2],
  "MEMORY_DIR": sys.argv[3],
  "ACCEPTED_CHDRS": int(sys.argv[4]),
  "PENDING_CHDRS": int(sys.argv[5]),
  "EXISTING_CHDRS": int(sys.argv[6])
}))
PY
