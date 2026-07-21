#!/usr/bin/env bash
# setup-levelup-clarify.sh — Setup for levelup-clarify (self-contained)
set -euo pipefail

###############################################################################
# Inline path resolution (no external helper dependency)
###############################################################################

resolve_project_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.adlc" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

resolve_team_ai_directive() {
  local project_root="$1"
  local td="${TEAM_AI_DIRECTIVE:-}"
  [[ -n "$td" ]] && { echo "$td"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    td=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('team_ai_directive', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    [[ -n "$td" ]] && { echo "$td"; return; }
  fi
  echo "${project_root}/team-ai-directives"
}

resolve_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVE=$(resolve_team_ai_directive "$PROJECT_ROOT")
BRANCH=$(resolve_branch)
CDR_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/cdr"

mkdir -p "$CDR_DRAFTS_DIR"

# Count pending and accepted CDRs using single-line format:
#   ### Status: **Proposed** / **Discovered** / **Accepted** / **Rejected**
PENDING_COUNT=0
ACCEPTED_COUNT=0
if [[ -d "$CDR_DRAFTS_DIR" ]]; then
  PENDING_COUNT=$( { grep -l -E '^### Status: \*\*(Discovered|Proposed)\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
  ACCEPTED_COUNT=$( { grep -l -E '^### Status: \*\*Accepted\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
fi

TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVE" ]] && echo "true" || echo "false")

python3 - "$PROJECT_ROOT" "$CDR_DRAFTS_DIR" "$TEAM_AI_DIRECTIVE" "$BRANCH" "$PENDING_COUNT" "$ACCEPTED_COUNT" "$TD_CONFIGURED" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CDR_DRAFTS_DIR": sys.argv[2],
  "TEAM_AI_DIRECTIVE": sys.argv[3],
  "BRANCH": sys.argv[4],
  "PENDING_COUNT": int(sys.argv[5]),
  "ACCEPTED_COUNT": int(sys.argv[6]),
  "TD_CONFIGURED": sys.argv[7] == "true"
}))
PY
