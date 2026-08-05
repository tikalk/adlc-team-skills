#!/bin/bash
# product-roadmap setup script
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

mkdir -p "$PDR_DRAFTS_DIR" "$PDR_MEMORY_DIR"
DRAFT_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
MEM_COUNT=$(find "$PDR_MEMORY_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
if $JSON_MODE; then
  cat <<EOF
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PDR_MEMORY_DIR":"$PDR_MEMORY_DIR","PRD_FILE":"$PRD_FILE","SDD_DOCS_LOCATION":"$SDD_DOCS_LOCATION","SDD_ROOT":"$SDD_ROOT","draft_count":$DRAFT_COUNT,"memory_count":$MEM_COUNT}
EOF
else
  echo "[INFO] product-roadmap setup"
  echo "  Draft PDRs: $DRAFT_COUNT"
  echo "  Memory PDRs: $MEM_COUNT"
fi
