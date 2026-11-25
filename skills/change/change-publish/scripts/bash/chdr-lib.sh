#!/usr/bin/env bash
#
# chdr-lib.sh — Shared ChDR lifecycle library for adlc-skills change-* skills.
#
# Bash-only: source this file from bash (`bash -c 'source .../chdr-lib.sh'`).
# Under zsh, `BASH_SOURCE[0]` is unset and `_pdr_lib_dir` resolution fails —
# run helpers under bash, or `emulate -L sh`, never `source` from zsh.
#
# Mirrors the PDR-side tooling in pdr-lib.sh so that the ChDR side has the
# same structural robustness: script-driven index generation, atomic move
# promotion, and slug-based ID allocation.
#
# Bundled with each change-* skill so it works standalone.
# Sourced by setup-change-*.sh scripts and callable directly.
#

set -euo pipefail

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

# ============================================================================
# Project root resolution
# ============================================================================

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

if [ -z "${REPO_ROOT:-}" ]; then
    REPO_ROOT="$(_get_project_root)"
fi
export REPO_ROOT

# ============================================================================
# Decision-record store resolution (ADR-514)
# ============================================================================

_memory_root_has_marker() {
    local root="$1" mem fam
    for mem in "docs/adlc/memory" ".adlc/memory"; do
        [[ -d "$root/$mem" ]] || continue
        for fam in adr pdr chdr; do
            if [[ -d "$root/$mem/$fam" || -f "$root/$mem/$fam.md" || -f "$root/$mem/$fam/$fam.md" ]]; then
                return 0
            fi
        done
    done
    return 1
}

_workspace_root_above() {
    local up
    up="$(dirname "$1")"
    while [[ "$up" != "/" ]]; do
        if [[ -f "$up/.gitmodules" || -f "$up/.adlc/workspace.yml" ]]; then
            return 0
        fi
        up="$(dirname "$up")"
    done
    return 1
}

resolve_memory_root() {
    local dir toplevel
    dir="$(pwd -P)"
    toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    while [[ "$dir" != "/" ]]; do
        if _memory_root_has_marker "$dir"; then
            printf '%s\n' "$dir"
            return 0
        fi
        if [[ -f "$dir/.gitmodules" || -f "$dir/.adlc/workspace.yml" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        if [[ -n "$toplevel" && "$dir" == "$toplevel" ]] && ! _workspace_root_above "$dir"; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    if [[ -n "$toplevel" ]]; then
        printf '%s\n' "$toplevel"
    else
        pwd -P
    fi
}

ensure_memory_store() {
    local root="$1" family="$2"
    local store="$root/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/$family"
    if [[ ! -d "$store" ]]; then
        mkdir -p "$store"
        echo "No decision-record store found — initialized $store; commit it to opt $(basename "$root") into repo-scoped memory." >&2
    fi
}

if [ -z "${MEMORY_ROOT:-}" ]; then
    MEMORY_ROOT="$(resolve_memory_root)"
fi
export MEMORY_ROOT

# ============================================================================
# YAML frontmatter parser
# ============================================================================

parse_fm_field() {
    local file="$1"
    local field="$2"
    [ -f "$file" ] || return 0
    awk -v fld="^[[:space:]]*${field}:[[:space:]]*" '
        /^---[[:space:]]*$/ { fm++; next }
        fm == 1 && $0 ~ fld {
            sub(fld, "")
            sub(/[[:space:]]+#.*$/, "")
            gsub(/^["'\'']|["'\'']$/, "")
            gsub(/^\[|\]$/, "")
            sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$file"
}

parse_fm_title() {
    [ -f "$1" ] || return 0
    awk '/^---[[:space:]]*$/ { fm++; next } fm >= 2 && /^#[[:space:]]+/ { sub(/^#[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

# ============================================================================
# Heading-based fallback parser
# ============================================================================

parse_chdr_heading_field() {
    local file="$1"
    local field="$2"
    [ -f "$file" ] || return 0
    awk -v fld="$field" '
        $0 ~ "^#+[[:space:]]*" fld "[[:space:]]*$" { found=1; next }
        found && /^#+/ { exit }
        found && NF > 0 {
            gsub(/\*\*/, "")
            sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$file"
}

parse_chdr_heading_title() {
    [ -f "$1" ] || return 0
    awk '
        $0 ~ "^#+[[:space:]]*ChDR-[0-9A-Za-z-]+:[[:space:]]*" {
            sub(/^#+[[:space:]]*ChDR-[0-9A-Za-z-]+:[[:space:]]*/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$1"
}

# ============================================================================
# Combined parsers
# ============================================================================

parse_chdr_field() {
    local file="$1"
    local field="$2"
    local value=""

    # Try frontmatter (lowercase the field name for YAML key matching)
    local fm_field
    fm_field=$(echo "$field" | tr '[:upper:]' '[:lower:]')
    value=$(parse_fm_field "$file" "$fm_field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi

    # Fallback: heading-based
    value=$(parse_chdr_heading_field "$file" "$field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi

    echo ""
}

parse_chdr_title() {
    [ -f "$1" ] || return 0
    local value
    value=$(parse_fm_field "$1" "title")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi
    # Fallback: strip "ChDR-<id>:" prefix from H1/H2
    value=$(parse_chdr_heading_title "$1")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi
    # Last resort: bare H1 (no ChDR prefix)
    value=$(parse_fm_title "$1")
    echo "$value"
}

# ============================================================================
# Slugification Rules
# ============================================================================

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

mint_chdr_slug() {
    local title="$1"
    local drafts_root="${2:-$REPO_ROOT}"
    local memory_root="${MEMORY_ROOT:-$drafts_root}"
    local slug
    slug=$(slugify "$title") || return 1

    local candidate="$slug"
    local count=1

    while true; do
        local exists=false
        local dir
        for dir in "$drafts_root/${ADLC_DRAFTS:-.adlc/drafts}/chdr" \
                   "$memory_root/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/chdr" \
                   "$memory_root/.adlc/memory/chdr"; do
            if [[ -f "$dir/ChDR-$candidate.md" ]]; then
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

# ============================================================================
# Lookup and Move
# ============================================================================

get_chdr_by_id() {
    local chdr_id="$1"
    chdr_id="${chdr_id#ChDR-}"
    local scope="${2:-drafts}"
    local chdr_dir="$REPO_ROOT/.adlc/$scope/chdr"

    local search_dirs=("$chdr_dir")
    if [[ "$scope" == "memory" ]]; then
        local memory_root="${MEMORY_ROOT:-$REPO_ROOT}"
        search_dirs=("$memory_root/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/chdr" "$memory_root/.adlc/memory/chdr")
    fi

    case "$chdr_id" in *"/"*|.*) return 1;; esac
    local _d hybrid_file
    for _d in "${search_dirs[@]}"; do
        hybrid_file="$_d/ChDR-$chdr_id.md"
        if [[ -f "$hybrid_file" ]]; then
            cat "$hybrid_file"
            return 0
        fi
    done

    return 1
}

move_chdr() {
    local chdr_id="$1"
    chdr_id="${chdr_id#ChDR-}"
    local from_scope="${2:-drafts}"
    local to_scope="${3:-memory}"

    local from_dir="$REPO_ROOT/.adlc/$from_scope/chdr"
    local to_dir="$REPO_ROOT/.adlc/$to_scope/chdr"
    if [ "$to_scope" = "memory" ]; then
        local memory_root="${MEMORY_ROOT:-$REPO_ROOT}"
        to_dir="$memory_root/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/chdr"
        ensure_memory_store "$memory_root" chdr
    fi

    case "$chdr_id" in *"/"*|.*) echo "[ERROR] move_chdr: invalid id: $chdr_id" >&2; return 1;; esac

    mkdir -p "$to_dir"

    local src_file="$from_dir/ChDR-$chdr_id.md"
    if [ -f "$src_file" ]; then
        mv "$src_file" "$to_dir/$(basename "$src_file")"
    else
        echo "[WARN] move_chdr: source file not found: $src_file" >&2
        return 1
    fi

    if [ -f "$src_file" ]; then
        echo "[ERROR] move_chdr: duplicate detected — $(basename "$src_file") still exists in $from_scope after move" >&2
        return 1
    fi

    # Regenerate both scopes' indexes if generate_chdr_index is implemented
    if declare -f generate_chdr_index > /dev/null; then
        generate_chdr_index "$from_scope"
        generate_chdr_index "$to_scope"
    fi
}

# ============================================================================
# Index generation
# ============================================================================

generate_chdr_index() {
    local scope="${1:-drafts}"
    local base="$REPO_ROOT"
    if [ "$scope" = "memory" ]; then
        base="${MEMORY_ROOT:-$REPO_ROOT}"
    fi
    local chdr_dir="$base/.adlc/$scope/chdr"

    local scan_dirs=("$chdr_dir")
    if [ "$scope" = "memory" ]; then
        local docs_chdr_dir="$base/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/chdr"
        if compgen -G "$docs_chdr_dir/ChDR-*.md" >/dev/null 2>&1; then
            scan_dirs=("$docs_chdr_dir" "$chdr_dir")
        fi
    fi

    local index_file="${scan_dirs[0]}/chdr.md"

    if [ ! -d "${scan_dirs[0]}" ]; then
        return 0
    fi

    local index_rel_dir="${scan_dirs[0]#"$base"/}"

    local index_content="# Change Decision Records"
    if [ "$scope" = "memory" ]; then
        index_content="$index_content (Memory)

> Auto-generated by /change-publish. Accepted ChDRs only.
> Source: $index_rel_dir/ChDR-*.md"
    else
        index_content="$index_content (Drafts)

> Auto-generated by /change-clarify. All ChDRs.
> Source: $index_rel_dir/ChDR-*.md"
    fi

    index_content="$index_content

## ChDR Index

| ID | Status | Date | Title |
|----|--------|------|-------|
"

    local f fname id stem title status date padded_id
    local _chdr_index_files=""
    local _d

    for _d in "${scan_dirs[@]}"; do
        [ -d "$_d" ] || continue
        _chdr_index_files+="$(ls -1 "$_d"/ChDR-*.md 2>/dev/null || true)"$'\n'
    done
    for f in $(printf '%s' "$_chdr_index_files" | LC_ALL=C sort); do
        fname=$(basename "$f")
        stem="${fname%.md}"
        id="${stem#ChDR-}"
        padded_id="$id"

        title=$(parse_chdr_title "$f")
        status=$(parse_chdr_field "$f" "status")
        date=$(parse_chdr_field "$f" "date")

        _raw="$status"
        [ -z "$_raw" ] && status="Unknown" || status="$(printf '%s' "${_raw:0:1}" | tr '[:lower:]' '[:upper:]')${_raw:1}"
        [ -z "$date" ] && date="YYYY-MM-DD"
        [ -z "$title" ] && title="ChDR-$padded_id"

        index_content="$index_content| ChDR-$padded_id | $status | $date | $title |
"
    done

    printf '%s\n' "$index_content" > "$index_file"
}
