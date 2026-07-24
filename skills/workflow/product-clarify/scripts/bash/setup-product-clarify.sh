#!/bin/bash
# product-clarify setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PDR_DRAFTS_DIR="$REPO_ROOT/.adlc/drafts/pdr"
PDR_MEMORY_DIR="$REPO_ROOT/.adlc/memory/pdr"
PRD_FILE="$REPO_ROOT/PRD.md"
mkdir -p "$PDR_DRAFTS_DIR"
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
ACCEPTED_COUNT=0
if [[ "$PDR_COUNT" -gt 0 ]]; then
  ACCEPTED_COUNT=$(grep -l '^### Status' "$PDR_DRAFTS_DIR"/PDR-*.md 2>/dev/null | xargs -I{} grep -l '^\*\*Accepted\*\*' {} 2>/dev/null | wc -l)
fi
if $JSON_MODE; then
  cat <<EOF
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PDR_MEMORY_DIR":"$PDR_MEMORY_DIR","PRD_FILE":"$PRD_FILE","pdr_count":$PDR_COUNT,"accepted_count":$ACCEPTED_COUNT}
EOF
else
  echo "[INFO] product-clarify setup"
  echo "  PDRs found: $PDR_COUNT"
  echo "  Accepted: $ACCEPTED_COUNT"
fi
