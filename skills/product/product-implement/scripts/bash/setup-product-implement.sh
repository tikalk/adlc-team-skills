#!/bin/bash
# product-implement setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done
source "$(dirname "${BASH_SOURCE[0]}")/../../../product-clarify/scripts/bash/pdr-lib.sh" 2>/dev/null || true
# Fail fast when the canonical helper is absent (selective install without
# product-clarify) instead of dying later on a missing function.
command -v generate_pdr_index >/dev/null 2>&1 || { echo "ERROR: pdr-lib.sh not loaded — install the product-clarify skill: adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify" >&2; return 1 2>/dev/null || exit 1; }

# JSON output is built with jq -n (jq is required; no fallbacks).

# shared layout constants (single definition in paths.sh; pdr-lib.sh
# sources it too — this block keeps the script correct standalone).
_pd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_pd_dir/../../../../team/workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_pd_dir/../../../../team/workspace/scripts/bash/paths.sh"
elif [ -f "$_pd_dir/../../../workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_pd_dir/../../../workspace/scripts/bash/paths.sh"
fi
REPO_ROOT="${REPO_ROOT:-$(_get_project_root)}"
PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
#  canonical PDR memory root (legacy .adlc/memory stays read-compatible).
PDR_MEMORY_DIR="$REPO_ROOT/docs/adlc/memory/pdr"
PRD_FILE="$REPO_ROOT/docs/adlc/product/PRD.md"
SECTIONS_DIR="$REPO_ROOT/.adlc/product/sections"
STATE_FILE="$REPO_ROOT/.adlc/product/state.json"

mkdir -p "$PDR_DRAFTS_DIR"
mkdir -p "$PDR_MEMORY_DIR"
mkdir -p "$SECTIONS_DIR"
mkdir -p "$REPO_ROOT/.adlc/product"
#  compiled PRD lives under docs/adlc/product/ — ensure the parent exists.
mkdir -p "$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}"

ACCEPTED_COUNT=0
if [[ -d "$PDR_DRAFTS_DIR" ]]; then
  for f in "$PDR_DRAFTS_DIR"/PDR-*.md; do
    if [[ -f "$f" ]] && grep -q '^\*\*Accepted\*\*' "$f" 2>/dev/null; then
      ((ACCEPTED_COUNT++))
    fi
  done
fi

if $JSON_MODE; then
  jq -n --arg rr "$REPO_ROOT" --arg pdd "$PDR_DRAFTS_DIR" --arg pmd "$PDR_MEMORY_DIR" \
    --arg pf "$PRD_FILE" --arg sd "$SECTIONS_DIR" --arg sf "$STATE_FILE" \
    --argjson a "$ACCEPTED_COUNT" \
    '{REPO_ROOT:$rr,PDR_DRAFTS_DIR:$pdd,PDR_MEMORY_DIR:$pmd,PRD_FILE:$pf,SECTIONS_DIR:$sd,STATE_FILE:$sf,accepted_count:$a}' 
else
  echo "[INFO] product-implement setup"
  echo "  Accepted PDRs: $ACCEPTED_COUNT"
  echo "  PRD_FILE: $PRD_FILE"
  echo "  SECTIONS_DIR: $SECTIONS_DIR"
fi
