#!/bin/bash
# product-specify setup script
set -euo pipefail

JSON_MODE=false
for arg in "$@"; do
  case "$arg" in --json) JSON_MODE=true ;; esac
done

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
PRD_FILE="$SDD_ROOT/PRD.md"

mkdir -p "$PDR_DRAFTS_DIR"

next_pdr_number() {
  local max=0
  if [[ -d "$PDR_DRAFTS_DIR" ]]; then
    for f in "$PDR_DRAFTS_DIR"/PDR-*.md; do
      if [[ -f "$f" ]]; then
        local num; num=$(basename "$f" | sed 's/PDR-//' | sed 's/\.md//')
        if [[ "$num" =~ ^[0-9]+$ ]]; then ((10#$num > max)) && max=$((10#$num)); fi
      fi
    done
  fi
  printf '%03d' $((max + 1))
}

NEXT_PDR=$(next_pdr_number)
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)

if $JSON_MODE; then
  cat <<EOF
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PRD_FILE":"$PRD_FILE","SDD_DOCS_LOCATION":"$SDD_DOCS_LOCATION","SDD_ROOT":"$SDD_ROOT","next_pdr":"$NEXT_PDR","pdr_count":$PDR_COUNT}
EOF
else
  echo "[INFO] product-specify setup"
  echo "  REPO_ROOT: $REPO_ROOT"
  echo "  PDR_DRAFTS_DIR: $PDR_DRAFTS_DIR"
  echo "  Next PDR: PDR-$NEXT_PDR"
  echo "  Existing PDRs: $PDR_COUNT"
fi
