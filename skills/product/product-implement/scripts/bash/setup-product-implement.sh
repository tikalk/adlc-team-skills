#!/bin/bash
# product-implement setup script
set -euo pipefail

JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done

resolve_sdd_docs_location() {
  local project_root="$1"
  local loc="${SDD_DOCS_LOCATION:-}"
  [[ -n "$loc" ]] && { echo "$loc"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    loc=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('sdd_docs_location', ''))
except Exception:
    print('')
" 2>/dev/null || true)
  fi
  echo "$loc"
}

sdd_project_subfolder_name() {
  local project_root="$1"
  local common_dir
  common_dir=$(git -C "$project_root" rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$common_dir" ]]; then
    basename "$(cd "$(dirname "$common_dir")" && pwd)"
  else
    basename "$project_root"
  fi
}

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_ROOT="$PROJECT_ROOT"

SDD_DOCS_LOCATION=$(resolve_sdd_docs_location "$PROJECT_ROOT")
if [[ -n "$SDD_DOCS_LOCATION" ]]; then
  SDD_DOCS_LOCATION="${SDD_DOCS_LOCATION/#\~/$HOME}"
  SDD_ROOT="${SDD_DOCS_LOCATION%/}/$(sdd_project_subfolder_name "$PROJECT_ROOT")"
else
  SDD_ROOT="$PROJECT_ROOT"
fi

PDR_DRAFTS_DIR="$SDD_ROOT/.adlc/drafts/pdr"
PDR_MEMORY_DIR="$SDD_ROOT/.adlc/memory/pdr"
PRD_FILE="$SDD_ROOT/PRD.md"
SECTIONS_DIR="$SDD_ROOT/.adlc/product/sections"
STATE_FILE="$SDD_ROOT/.adlc/product/state.json"

mkdir -p "$PDR_DRAFTS_DIR"
mkdir -p "$PDR_MEMORY_DIR"
mkdir -p "$SECTIONS_DIR"
mkdir -p "$SDD_ROOT/.adlc/product"

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
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PDR_MEMORY_DIR":"$PDR_MEMORY_DIR","PRD_FILE":"$PRD_FILE","SECTIONS_DIR":"$SECTIONS_DIR","STATE_FILE":"$STATE_FILE","SDD_DOCS_LOCATION":"$SDD_DOCS_LOCATION","SDD_ROOT":"$SDD_ROOT","accepted_count":$ACCEPTED_COUNT}
EOF
else
  echo "[INFO] product-implement setup"
  echo "  Accepted PDRs: $ACCEPTED_COUNT"
  echo "  PRD_FILE: $PRD_FILE"
  echo "  SECTIONS_DIR: $SECTIONS_DIR"
fi
