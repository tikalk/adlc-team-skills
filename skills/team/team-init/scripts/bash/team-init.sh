#!/usr/bin/env bash
# team-init.sh — Brownfield CDR discovery entry point
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source team-levelup helpers (shared utilities).
# (The pre-move path was one level short — it resolved inside team-init/ and
# the script died at this very check on main; fixed with the move.)
LEVELUP_HELPERS="${SCRIPT_DIR}/../../../team-levelup/scripts/bash/helpers.sh"
if [[ -f "$LEVELUP_HELPERS" ]]; then
  source "$LEVELUP_HELPERS"
else
  echo "Error: team-levelup helpers not found at $LEVELUP_HELPERS"
  exit 1
fi

if [[ "${1:-}" == "--setup" ]]; then
  output_json
  exit 0
fi

# Resolve paths (function sets PROJECT_ROOT/TEAM_AI_DIRECTIVES/BRANCH globals
# directly; output is informational only — never eval it)
resolve_team_levelup_paths >/dev/null

if [[ -z "$TEAM_AI_DIRECTIVES" ]] || [[ ! -d "$TEAM_AI_DIRECTIVES" ]]; then
  echo "Team AI directives repository not configured."
  echo "Run: /team-setup"
  exit 1
fi

# Ensure adlc orphan branch exists
ensure_adlc_branch "$TEAM_AI_DIRECTIVES"

# Get next CDR number
NEXT_CDR=$(next_cdr_number "$TEAM_AI_DIRECTIVES")

echo "REPO_ROOT=$PROJECT_ROOT"
echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
echo "NEXT_CDR=$NEXT_CDR"
echo "ADLC_BRANCH=$ADLC_BRANCH"
echo ""
echo "Ready for multi-agent brownfield analysis."
echo "CDRs will be written to: $TEAM_AI_DIRECTIVES (adlc branch, drafts/cdr/)"
