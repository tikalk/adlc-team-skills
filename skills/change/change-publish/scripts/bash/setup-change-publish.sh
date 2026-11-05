#!/usr/bin/env bash
# setup-change-publish.sh — Setup for change-publish (self-contained)
set -euo pipefail

# shared layout constants (single definition in paths.sh).
_ch_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_ch_dir/../../../../team/workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_ch_dir/../../../../team/workspace/scripts/bash/paths.sh"
elif [ -f "$_ch_dir/../../../workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_ch_dir/../../../workspace/scripts/bash/paths.sh"
fi

resolve_project_root() {
  local dir
  dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.adlc" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

PROJECT_ROOT=$(resolve_project_root)
CHDR_DRAFTS_DIR="${PROJECT_ROOT}/${ADLC_DRAFTS:-.adlc/drafts}/chdr"
#  published ChDRs live under docs/adlc/memory — promotion writes the
# new path only; legacy .adlc/memory/chdr stays read-compatible (dual-read).
MEMORY_DIR="${PROJECT_ROOT}/docs/adlc/memory/chdr"
MEMORY_INDEX="${PROJECT_ROOT}/docs/adlc/memory/chdr/chdr.md"
LEGACY_MEMORY_DIR="${PROJECT_ROOT}/.adlc/memory/chdr"

mkdir -p "$MEMORY_DIR" 2>/dev/null || true

# Accepted ChDR ids (filenames) in drafts
ACCEPTED_CHDRS=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | xargs -r -n1 basename 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
ACCEPTED_COUNT=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
PUBLISHED_COUNT=$( { grep -l '^### Status: \*\*Published\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
# Dual-read: count records in both the new and the legacy root.
MEMORY_COUNT=$(( $( { ls -1 "$MEMORY_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ') + $( { ls -1 "$LEGACY_MEMORY_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ') ))
MEMORY_INDEX_EXISTS=$([[ -f "$MEMORY_INDEX" ]] && echo "true" || echo "false")

if [ -n "$ACCEPTED_CHDRS" ]; then
  accepted_json=$(printf '%s\n' $ACCEPTED_CHDRS | jq -R . | jq -s -c .)
else
  accepted_json="[]"
fi
if [[ "$MEMORY_INDEX_EXISTS" == "true" ]]; then mem_json=true; else mem_json=false; fi
jq -n --arg rr "$PROJECT_ROOT" --arg dd "$CHDR_DRAFTS_DIR" --arg md "$MEMORY_DIR" --arg mi "$MEMORY_INDEX" \
  --argjson accepted "$accepted_json" --argjson ac "$ACCEPTED_COUNT" --argjson pc "$PUBLISHED_COUNT" \
  --argjson mc "$MEMORY_COUNT" --argjson mie "$mem_json" \
  '{REPO_ROOT:$rr,CHDR_DRAFTS_DIR:$dd,MEMORY_DIR:$md,MEMORY_INDEX:$mi,ACCEPTED_CHDRS:$accepted,ACCEPTED_COUNT:$ac,PUBLISHED_COUNT:$pc,MEMORY_COUNT:$mc,MEMORY_INDEX_EXISTS:$mie}'
