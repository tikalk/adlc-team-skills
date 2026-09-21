#!/usr/bin/env bash
# team-learn.sh — Session-end CDR lifecycle entry point
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

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

# Output setup info
echo "NEXT_CDR=$NEXT_CDR"
echo "ADLC_BRANCH=$ADLC_BRANCH"
echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
