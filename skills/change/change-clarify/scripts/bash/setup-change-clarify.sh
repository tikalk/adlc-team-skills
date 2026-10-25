#!/usr/bin/env bash
# setup-change-clarify.sh — Setup for change-clarify (self-contained)
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

python3 - "$PROJECT_ROOT" "$CHDR_DRAFTS_DIR" "$MEMORY_DIR" "$ACCEPTED_CHDRS" "$PENDING_CHDRS" "$EXISTING_CHDRS" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CHDR_DRAFTS_DIR": sys.argv[2],
  "MEMORY_DIR": sys.argv[3],
  "ACCEPTED_CHDRS": int(sys.argv[4]),
  "PENDING_CHDRS": int(sys.argv[5]),
  "EXISTING_CHDRS": int(sys.argv[6])
}))
PY
