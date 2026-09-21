#!/usr/bin/env bash
# team-init.sh — Brownfield CDR discovery entry point
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source team-learn helpers (shared utilities)
LEARN_HELPERS="${SCRIPT_DIR}/../team-learn/scripts/helpers.sh"
if [[ -f "$LEARN_HELPERS" ]]; then
  source "$LEARN_HELPERS"
else
  echo "Error: team-learn helpers not found at $LEARN_HELPERS"
  exit 1
fi

if [[ "${1:-}" == "--setup" ]]; then
  output_json
  exit 0
fi

# Resolve paths
eval "$(resolve_team_learn_paths)"

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
