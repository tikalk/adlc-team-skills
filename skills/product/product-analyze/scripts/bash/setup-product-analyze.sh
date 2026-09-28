#!/bin/bash
# product-analyze setup script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done


PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_ROOT="$PROJECT_ROOT"


# Resolve WORKSPACE_REPO_ROOT via shared team-paths (no per-project subfolders)
_TEAM_PATHS=""
for _cand in \
  "${SCRIPT_DIR}/../../../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../team-paths.sh" \
  "${SCRIPT_DIR}/team-paths.sh"; do
  [[ -f "$_cand" ]] && { _TEAM_PATHS="$_cand"; break; }
done
if [[ -n "$_TEAM_PATHS" ]]; then
  # shellcheck source=team-paths.sh
  source "$_TEAM_PATHS"
  resolve_workspace_repo_root "$PROJECT_ROOT" >/dev/null
else
  WORKSPACE_REPO_ROOT="$PROJECT_ROOT"
  WORKSPACE_CONFIGURED="false"
fi


PDR_DRAFTS_DIR="$WORKSPACE_REPO_ROOT/.adlc/drafts/pdr"
PDR_MEMORY_DIR="$WORKSPACE_REPO_ROOT/.adlc/memory/pdr"
PRD_FILE="$WORKSPACE_REPO_ROOT/PRD.md"
PDR_COUNT=$([[ -d "$PDR_DRAFTS_DIR" ]] && find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l || echo 0)
PRD_EXISTS=$([ -f "$PRD_FILE" ] && echo "true" || echo "false")
if $JSON_MODE; then
  cat <<EOF
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PDR_MEMORY_DIR":"$PDR_MEMORY_DIR","PRD_FILE":"$PRD_FILE","WORKSPACE_REPO_ROOT":"$WORKSPACE_REPO_ROOT","pdr_count":$PDR_COUNT,"prd_exists":$PRD_EXISTS}
EOF
else
  echo "[INFO] product-analyze setup"
  echo "  PDRs: $PDR_COUNT"
  echo "  PRD exists: $PRD_EXISTS"
fi
