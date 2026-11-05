#!/usr/bin/env bash
# setup-change-clarify.sh — Setup for change-clarify (self-contained)
set -euo pipefail

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

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
#  published ChDRs live under docs/adlc/memory (legacy .adlc/memory/chdr
# stays read-compatible — dual-read).
MEMORY_DIR="${PROJECT_ROOT}/docs/adlc/memory/chdr"

mkdir -p "$CHDR_DRAFTS_DIR" 2>/dev/null || true

# A ChDR draft carries its status in YAML frontmatter (the canonical draft
# template) or, in a full record, in a "### Status: **X**" heading. Both
# forms count -- matching only the heading form hid every template-written
# draft, including the ones team-boot's continuous capture produces.
chdr_status() {
    local file="$1" status=""
    # A full record carries a "### Status: **X**" heading, and that heading is
    # what the accept flow updates -- so it is authoritative. The frontmatter
    # of a published record still carries the value its template shipped
    # (skills/change/templates/chdr-template.md ships `status: discovered`),
    # which is why the heading is read first.
    status=$( { grep -m1 -oE '^### Status: \*\*[A-Za-z]+\*\*' "$file" 2>/dev/null || true; } \
        | sed -E 's/^### Status: \*\*//; s/\*\*$//' | tr '[:upper:]' '[:lower:]')
    if [ -z "$status" ]; then
        # Draft form: frontmatter `status: <word>`, in any case, optionally
        # annotated with a trailing `# comment` (the draft template teaches
        # that style on sibling fields). The vocabulary is open here -- the
        # caller's case statement decides which statuses count -- so an
        # unrecognised status is seen and ignored rather than silently
        # missed. Normalise exactly as the heading branch does: an anchored,
        # lowercase-only match hid `status: Proposed` and
        # `status: proposed  # why`, which is the same silence this loader
        # exists to fix.
        status=$( { grep -m1 -E '^status:[[:space:]]*[A-Za-z]+[[:space:]]*(#.*)?$' "$file" 2>/dev/null || true; } \
            | sed -E 's/^status:[[:space:]]*([A-Za-z]+).*$/\1/' | tr '[:upper:]' '[:lower:]')
    fi
    printf '%s' "$status"
}

ACCEPTED_CHDRS=0
PENDING_CHDRS=0
for f in "$CHDR_DRAFTS_DIR"/ChDR-*.md; do
    [ -f "$f" ] || continue
    case "$(chdr_status "$f")" in
        accepted|published) ACCEPTED_CHDRS=$((ACCEPTED_CHDRS + 1)) ;;
        discovered|proposed) PENDING_CHDRS=$((PENDING_CHDRS + 1)) ;;
    esac
done
EXISTING_CHDRS=$( { ls -1 "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')

jq -n --arg rr "$PROJECT_ROOT" --arg dd "$CHDR_DRAFTS_DIR" --arg md "$MEMORY_DIR" \
  --argjson accepted "$ACCEPTED_CHDRS" --argjson pending "$PENDING_CHDRS" --argjson existing "$EXISTING_CHDRS" \
  '{REPO_ROOT:$rr,CHDR_DRAFTS_DIR:$dd,MEMORY_DIR:$md,ACCEPTED_CHDRS:$accepted,PENDING_CHDRS:$pending,EXISTING_CHDRS:$existing}'
