#!/usr/bin/env bash
# setup-levelup-implement.sh — Setup for levelup-implement
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
SKILLS_DRAFTS_DIR=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["SKILLS_DRAFTS_DIR"])')
TEAM_DIRECTIVES=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["TEAM_DIRECTIVES"])')
BRANCH=$(echo "$PATHS" | python3 -c 'import json,sys; print(json.load(sys.stdin)["BRANCH"])')

mkdir -p "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR"

ACCEPTED_CDRS=()
if [[ -d "$CDR_DRAFTS_DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && ACCEPTED_CDRS+=("$(basename "$f" .md)")
  done < <(grep -l -E '^### Status\s*\*\*Accepted\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null | sort)
fi

ACCEPTED_JSON=$(printf '%s\n' "${ACCEPTED_CDRS[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
TD_CONFIGURED=$([[ -d "$TEAM_DIRECTIVES" ]] && echo "true" || echo "false")
TD_CLEAN="unknown"
if [[ "$TD_CONFIGURED" == "true" ]]; then
  TD_CLEAN=$([[ -z "$(git -C "$TEAM_DIRECTIVES" status --porcelain 2>/dev/null)" ]] && echo "true" || echo "false")
fi

python3 - "$PROJECT_ROOT" "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$TEAM_DIRECTIVES" "$BRANCH" "$ACCEPTED_JSON" "$TD_CONFIGURED" "$TD_CLEAN" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CDR_DRAFTS_DIR": sys.argv[2],
  "SKILLS_DRAFTS_DIR": sys.argv[3],
  "TEAM_DIRECTIVES": sys.argv[4],
  "BRANCH": sys.argv[5],
  "ACCEPTED_CDRS": json.loads(sys.argv[6]),
  "TD_CONFIGURED": sys.argv[7] == "true",
  "TD_CLEAN": sys.argv[8] == "true"
}))
PY
