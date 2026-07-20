#!/usr/bin/env bash
# setup-levelup-clarify.sh — Setup for levelup-clarify
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="${SCRIPT_DIR}/../../levelup-helpers.sh"

if [[ ! -f "$HELPERS" ]]; then
  echo '{"error": "levelup-helpers.sh not found"}' >&2
  exit 1
fi

PATHS=$("$HELPERS" --json)

PROJECT_ROOT=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["REPO_ROOT"])')
CDR_DRAFTS_DIR=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["CDR_DRAFTS_DIR"])')
TEAM_DIRECTIVES=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["TEAM_DIRECTIVES"])')
BRANCH=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["BRANCH"])')

mkdir -p "$CDR_DRAFTS_DIR"

# Count pending CDRs
PENDING_COUNT=0
if [[ -d "$CDR_DRAFTS_DIR" ]]; then
  PENDING_COUNT=$(grep -l -E '^### Status\s*\*\*(Discovered|Proposed)\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null | wc -l | tr -d ' ')
fi

ACCEPTED_COUNT=0
if [[ -d "$CDR_DRAFTS_DIR" ]]; then
  ACCEPTED_COUNT=$(grep -l -E '^### Status\s*\*\*Accepted\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null | wc -l | tr -d ' ')
fi

TD_CONFIGURED=$([[ -d "$TEAM_DIRECTIVES" ]] && echo "true" || echo "false")

python3 - "$PROJECT_ROOT" "$CDR_DRAFTS_DIR" "$TEAM_DIRECTIVES" "$BRANCH" "$PENDING_COUNT" "$ACCEPTED_COUNT" "$TD_CONFIGURED" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CDR_DRAFTS_DIR": sys.argv[2],
  "TEAM_DIRECTIVES": sys.argv[3],
  "BRANCH": sys.argv[4],
  "PENDING_COUNT": int(sys.argv[5]),
  "ACCEPTED_COUNT": int(sys.argv[6]),
  "TD_CONFIGURED": sys.argv[7] == "true"
}))
PY
