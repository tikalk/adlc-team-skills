#!/usr/bin/env bash
# setup-levelup-init.sh — Setup for levelup-init
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="${SCRIPT_DIR}/../../levelup-helpers.sh"

if [[ ! -f "$HELPERS" ]]; then
  echo '{"error": "levelup-helpers.sh not found"}' >&2
  exit 1
fi

# Resolve paths
PATHS=$("$HELPERS" --json)

PROJECT_ROOT=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["REPO_ROOT"])')
CDR_DRAFTS_DIR=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["CDR_DRAFTS_DIR"])')
SKILLS_DRAFTS_DIR=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["SKILLS_DRAFTS_DIR"])')
LEVELUP_STATE_FILE=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["LEVELUP_STATE_FILE"])')
TEAM_DIRECTIVES=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["TEAM_DIRECTIVES"])')
BRANCH=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["BRANCH"])')

mkdir -p "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$(dirname "$LEVELUP_STATE_FILE")"

NEXT_CDR=$("$HELPERS" --next-cdr "$CDR_DRAFTS_DIR")
EXISTING_CDRS=$(ls -1 "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null | wc -l | tr -d ' ')
TD_CONFIGURED=$([[ -d "$TEAM_DIRECTIVES" ]] && echo "true" || echo "false")

python3 - "$PROJECT_ROOT" "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$LEVELUP_STATE_FILE" "$TEAM_DIRECTIVES" "$BRANCH" "$NEXT_CDR" "$EXISTING_CDRS" "$TD_CONFIGURED" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CDR_DRAFTS_DIR": sys.argv[2],
  "SKILLS_DRAFTS_DIR": sys.argv[3],
  "LEVELUP_STATE_FILE": sys.argv[4],
  "TEAM_DIRECTIVES": sys.argv[5],
  "BRANCH": sys.argv[6],
  "NEXT_CDR": sys.argv[7],
  "EXISTING_CDRS": int(sys.argv[8]),
  "TD_CONFIGURED": sys.argv[9] == "true"
}))
PY
