#!/bin/bash
# product-implement setup script
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
SECTIONS_DIR="$WORKSPACE_REPO_ROOT/.adlc/product/sections"
STATE_FILE="$WORKSPACE_REPO_ROOT/.adlc/product/state.json"

mkdir -p "$PDR_DRAFTS_DIR"
mkdir -p "$PDR_MEMORY_DIR"
mkdir -p "$SECTIONS_DIR"
mkdir -p "$WORKSPACE_REPO_ROOT/.adlc/product"

ACCEPTED_COUNT=0
if [[ -d "$PDR_DRAFTS_DIR" ]]; then
  for f in "$PDR_DRAFTS_DIR"/PDR-*.md; do
    if [[ -f "$f" ]] && grep -q '^\*\*Accepted\*\*' "$f" 2>/dev/null; then
      ((ACCEPTED_COUNT++))
    fi
  done
fi

if $JSON_MODE; then
  cat <<EOF
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PDR_MEMORY_DIR":"$PDR_MEMORY_DIR","PRD_FILE":"$PRD_FILE","SECTIONS_DIR":"$SECTIONS_DIR","STATE_FILE":"$STATE_FILE","WORKSPACE_REPO_ROOT":"$WORKSPACE_REPO_ROOT","accepted_count":$ACCEPTED_COUNT}
EOF
else
  echo "[INFO] product-implement setup"
  echo "  Accepted PDRs: $ACCEPTED_COUNT"
  echo "  PRD_FILE: $PRD_FILE"
  echo "  SECTIONS_DIR: $SECTIONS_DIR"
fi
