#!/bin/bash
# product-specify setup script
set -euo pipefail

JSON_MODE=false
for arg in "$@"; do
  case "$arg" in --json) JSON_MODE=true ;; esac
done

_get_project_root() {
  local dir
  dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.adlc" ] || [ -d "$dir/.git" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  pwd
}

# JSON output is built with jq -n -c (jq is required; no fallbacks).

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

REPO_ROOT="${REPO_ROOT:-$(_get_project_root)}"
PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
PRD_FILE="$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}/PRD.md"

mkdir -p "$PDR_DRAFTS_DIR"

# ID allocation: slugify(title) + collision check.
# Rules: lowercase, ASCII-fold, non-alnum -> -, collapse -, trim -, max 60 chars.
slugify() {
    local title="$1"
    local slug
    # 1. Lowercase, 2. ASCII-fold, 3. Sanitize, 4. Collapse, 5. Trim, 6. Truncate
    slug=$(echo "$title" | iconv -t ascii//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//; s/-$//' | cut -c 1-60)
    if [[ -z "$slug" ]]; then
        echo "Error: slugified title is empty" >&2
        return 1
    fi
    echo "$slug"
}

# mint_pdr_slug TITLE [REPO_ROOT] - the next free PDR slug.
# Slugify title and append -2, -3 on collision across drafts AND memory.
mint_pdr_slug() {
    local title="$1"
    local root="${2:-$REPO_ROOT}"
    local slug
    slug=$(slugify "$title") || return 1

    local candidate="$slug"
    local count=1

    while true; do
        local exists=false
        local dir
        for dir in "$root/.adlc/drafts/pdr" \
                   "$root/docs/adlc/memory/pdr" \
                   "$root/.adlc/memory/pdr"; do
            if [[ -f "$dir/PDR-$candidate.md" ]]; then
                exists=true
                break
            fi
        done

        if [[ "$exists" == "false" ]]; then
            echo "$candidate"
            return 0
        fi

        ((count++))
        candidate="$slug-$count"
    done
}

ID_ALLOCATION="slug"
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)

if $JSON_MODE; then
  jq -n -c --arg rr "$REPO_ROOT" --arg pdd "$PDR_DRAFTS_DIR" --arg pf "$PRD_FILE" \
    --arg ia "$ID_ALLOCATION" --argjson n "$PDR_COUNT" \
    '{REPO_ROOT:$rr,PDR_DRAFTS_DIR:$pdd,PRD_FILE:$pf,id_allocation:$ia,pdr_count:$n}'
else
  echo "[INFO] product-specify setup"
  echo "  REPO_ROOT: $REPO_ROOT"
  echo "  PDR_DRAFTS_DIR: $PDR_DRAFTS_DIR"
  echo "  ID allocation: PDR-{slug}"
  echo "  Existing PDRs: $PDR_COUNT"
fi
