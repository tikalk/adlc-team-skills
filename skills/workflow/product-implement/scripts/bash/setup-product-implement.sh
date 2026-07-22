#!/bin/bash
# product-implement setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PDR_DRAFTS_DIR="$REPO_ROOT/.adlc/drafts/pdr"
PDR_MEMORY_DIR="$REPO_ROOT/.adlc/memory/pdr"
PRD_FILE="$REPO_ROOT/PRD.md"
SECTIONS_DIR="$REPO_ROOT/.adlc/product/sections"
STATE_FILE="$REPO_ROOT/.adlc/product/state.json"

mkdir -p "$PDR_DRAFTS_DIR"
mkdir -p "$PDR_MEMORY_DIR"
mkdir -p "$SECTIONS_DIR"
mkdir -p "$REPO_ROOT/.adlc/product"

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
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PDR_MEMORY_DIR":"$PDR_MEMORY_DIR","PRD_FILE":"$PRD_FILE","SECTIONS_DIR":"$SECTIONS_DIR","STATE_FILE":"$STATE_FILE","accepted_count":$ACCEPTED_COUNT}
EOF
else
  echo "[INFO] product-implement setup"
  echo "  Accepted PDRs: $ACCEPTED_COUNT"
  echo "  PRD_FILE: $PRD_FILE"
  echo "  SECTIONS_DIR: $SECTIONS_DIR"
fi
