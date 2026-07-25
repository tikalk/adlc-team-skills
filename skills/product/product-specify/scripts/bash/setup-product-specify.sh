#!/bin/bash
# product-specify setup script
set -euo pipefail

JSON_MODE=false
for arg in "$@"; do
  case "$arg" in --json) JSON_MODE=true ;; esac
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PDR_DRAFTS_DIR="$REPO_ROOT/.adlc/drafts/pdr"
PRD_FILE="$REPO_ROOT/PRD.md"

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
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PRD_FILE":"$PRD_FILE","next_pdr":"$NEXT_PDR","pdr_count":$PDR_COUNT}
EOF
else
  echo "[INFO] product-specify setup"
  echo "  REPO_ROOT: $REPO_ROOT"
  echo "  PDR_DRAFTS_DIR: $PDR_DRAFTS_DIR"
  echo "  Next PDR: PDR-$NEXT_PDR"
  echo "  Existing PDRs: $PDR_COUNT"
fi
