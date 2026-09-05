#!/usr/bin/env bash
#
# pdr-lib.sh — Shared PDR lifecycle library for adlc-skills product-* skills.
#
# Mirrors the ADR-side tooling in setup-architect.sh (generate_adr_index, move_adr,
# parse_fm_field, parse_fm_title) so that the PDR side has the same structural
# robustness: script-driven index generation, atomic move promotion, and a
# frontmatter-primary + heading-fallback parser that handles both legacy H2
# (## Status) and current H3 (### Status) metadata.
#
# Bundled with each product-* skill so it works standalone.
# Sourced by setup-product-*.sh scripts and callable directly.
#
# Usage:
#   source pdr-lib.sh                          # load functions
#   generate_pdr_index memory                  # regenerate .adlc/memory/pdr/pdr.md
#   generate_pdr_index drafts                  # regenerate .adlc/drafts/pdr/pdr.md
#   move_pdr 020 drafts memory                # atomically move PDR-020 drafts→memory
#   migrate_pdr_to_frontmatter .adlc/memory/pdr/PDR-001.md   # one-time legacy migration
#

set -euo pipefail

# ============================================================================
# Project root resolution (mirror of common.sh _get_project_root)
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

# Resolve REPO_ROOT if not already set by the caller.
if [ -z "${REPO_ROOT:-}" ]; then
    REPO_ROOT="$(_get_project_root)"
fi
export REPO_ROOT

# ============================================================================
# YAML frontmatter parser (copied from setup-architect.sh parse_fm_field)
# ============================================================================

# Parse a YAML frontmatter field from a markdown file.
# Usage: parse_fm_field "file" "fieldname"
# Returns the field value with quotes, inline comments, and surrounding whitespace stripped.
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

# Extract the H1 title (first "# " line after frontmatter) from a markdown file.
# Usage: parse_fm_title "file"
parse_fm_title() {
    [ -f "$1" ] || return 0
    awk '/^---[[:space:]]*$/ { fm++; next } fm >= 2 && /^#[[:space:]]+/ { sub(/^#[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

# ============================================================================
# Heading-based fallback parser (handles legacy H2 and current H3 PDR files)
# ============================================================================

# Parse a metadata field from Markdown headings (## or ###).
# Looks for a heading line matching "^###+ <field>$", returns the next non-empty
# non-heading line with ** bold markers stripped.
# Usage: parse_pdr_heading_field "file" "Status"  (case-sensitive field name)
parse_pdr_heading_field() {
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

# Extract the title from a "# PDR-NNN: <title>" or "## PDR-NNN: <title>" heading.
# Strips the heading marker and "PDR-NNN:" prefix.
# Usage: parse_pdr_heading_title "file"
parse_pdr_heading_title() {
    [ -f "$1" ] || return 0
    awk '
        $0 ~ "^#+[[:space:]]*PDR-[0-9]+:[[:space:]]*" {
            sub(/^#+[[:space:]]*PDR-[0-9]+:[[:space:]]*/, "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$1"
}

# ============================================================================
# Combined parsers (frontmatter primary, heading fallback)
# ============================================================================

# Parse a PDR metadata field: tries YAML frontmatter first, falls back to headings.
# Usage: parse_pdr_field "file" "status"  (frontmatter field name, lowercase hyphenated)
#        parse_pdr_field "file" "Status"  (heading field name, Title Case)
# Note: frontmatter uses lowercase hyphenated keys (status, feature-area);
#       headings use Title Case (Status, Feature-Area). This function tries both.
parse_pdr_field() {
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

    # Fallback: heading-based (Title Case the field name for heading matching)
    # Accept both "Feature-Area" and "feature-area" heading styles
    local title_field
    title_field=$(echo "$field" | awk -F'-' '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' OFS='-')
    value=$(parse_pdr_heading_field "$file" "$title_field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi
    # Try the raw field name (handles "Feature-Area" where only first letter caps)
    value=$(parse_pdr_heading_field "$file" "$field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi

    # Empty string — caller should apply defaults
    echo ""
}

# Extract the PDR title: tries frontmatter "title" field, falls back to H1 parsing.
# Usage: parse_pdr_title "file"
parse_pdr_title() {
    [ -f "$1" ] || return 0
    local value
    value=$(parse_fm_field "$1" "title")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi
    # Fallback: strip "PDR-NNN:" prefix from H1/H2
    value=$(parse_pdr_heading_title "$1")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi
    # Last resort: bare H1 (no PDR-NNN prefix)
    value=$(parse_fm_title "$1")
    echo "$value"
}

# ============================================================================
# Index generation (mirrors generate_adr_index from setup-architect.sh)
# ============================================================================

# Generate pdr.md index from individual PDR files.
# Usage: generate_pdr_index [scope]   (scope = drafts | memory; default: drafts)
# Writes to: $REPO_ROOT/.adlc/{scope}/pdr/pdr.md  (INSIDE the pdr/ directory)
# Schema: 7 columns — ID | Feature-Area | Category | Status | Date | Owner | Title
# Fails loudly on blank cells (warns to stderr; applies defaults so no row is blank).
generate_pdr_index() {
    local scope="${1:-drafts}"
    local pdr_dir="$REPO_ROOT/.adlc/$scope/pdr"
    local index_file="$pdr_dir/pdr.md"

    if [ ! -d "$pdr_dir" ]; then
        return 0
    fi

    local index_content="# Product Decision Records"
    if [ "$scope" = "memory" ]; then
        index_content="$index_content (Memory)

> Auto-generated by /product-implement. Accepted PDRs only.
> Source: .adlc/$scope/pdr/PDR-*.md"
    else
        index_content="$index_content (Drafts)

> Auto-generated by /product-clarify. Proposed PDRs only.
> Source: .adlc/$scope/pdr/PDR-*.md"
    fi

    index_content="$index_content

## PDR Index

| ID | Feature-Area | Category | Status | Date | Owner | Title |
|----|--------------|----------|--------|------|-------|-------|
"

    # Sort PDR files numerically
    local f fname id title status date owner category feature_area padded_id
    local blank_warnings=""

    for f in $(ls -1 "$pdr_dir"/PDR-*.md 2>/dev/null | sort -t'-' -k2 -n); do
        fname=$(basename "$f")
        id=$(echo "$fname" | sed -E 's/PDR-([0-9]+)\.md/\1/')
        padded_id=$(printf "%03d" "$((10#$id))")

        title=$(parse_pdr_title "$f")
        status=$(parse_pdr_field "$f" "status")
        date=$(parse_pdr_field "$f" "date")
        owner=$(parse_pdr_field "$f" "owner")
        category=$(parse_pdr_field "$f" "category")
        feature_area=$(parse_pdr_field "$f" "feature-area")

        # Defaults — no silent blank cells
        [ -z "$status" ] && { status="Unknown"; blank_warnings="$blank_warnings\n  - PDR-$padded_id: Status"; }
        [ -z "$date" ] && { date="YYYY-MM-DD"; blank_warnings="$blank_warnings\n  - PDR-$padded_id: Date"; }
        [ -z "$owner" ] && { owner="Unknown"; blank_warnings="$blank_warnings\n  - PDR-$padded_id: Owner"; }
        [ -z "$category" ] && { category="Unknown"; blank_warnings="$blank_warnings\n  - PDR-$padded_id: Category"; }
        [ -z "$feature_area" ] && { feature_area="system"; blank_warnings="$blank_warnings\n  - PDR-$padded_id: Feature-Area"; }
        [ -z "$title" ] && { title="PDR-$padded_id"; blank_warnings="$blank_warnings\n  - PDR-$padded_id: Title"; }

        index_content="$index_content| PDR-$padded_id | $feature_area | $category | $status | $date | $owner | $title |
"
    done

    # Write the index
    printf '%s\n' "$index_content" > "$index_file"

    # Warn on any blank cells that needed defaults
    if [ -n "$blank_warnings" ]; then
        echo "[WARN] generate_pdr_index ($scope): the following PDRs had blank metadata cells;" >&2
        echo "       defaults were applied. Run /product-clarify to fix the source files." >&2
        printf '%b\n' "$blank_warnings" >&2
    fi
}

# ============================================================================
# Atomic move (mirrors move_adr from setup-architect.sh)
# ============================================================================

# Move a PDR from one scope to another (e.g., drafts -> memory).
# Usage: move_pdr <pdr_id> [from_scope] [to_scope]
# Performs an atomic mv, then regenerates both scopes' indexes.
# Fails if the source file does not exist. Verifies no duplicates remain.
move_pdr() {
    local pdr_id="$1"
    local from_scope="${2:-drafts}"
    local to_scope="${3:-memory}"

    local from_dir="$REPO_ROOT/.adlc/$from_scope/pdr"
    local to_dir="$REPO_ROOT/.adlc/$to_scope/pdr"

    local numeric_id
    numeric_id=$(echo "$pdr_id" | sed -E 's/[^0-9]//g')
    local padded_id
    padded_id=$(printf "%03d" "$((10#$numeric_id))")

    mkdir -p "$to_dir"

    if [ -f "$from_dir/PDR-$padded_id.md" ]; then
        mv "$from_dir/PDR-$padded_id.md" "$to_dir/PDR-$padded_id.md"
    else
        echo "[WARN] move_pdr: source file not found: $from_dir/PDR-$padded_id.md" >&2
        return 1
    fi

    # Duplicate check — the source must be gone
    if [ -f "$from_dir/PDR-$padded_id.md" ]; then
        echo "[ERROR] move_pdr: duplicate detected — PDR-$padded_id still exists in $from_scope after move" >&2
        return 1
    fi

    # Regenerate both scopes
    generate_pdr_index "$from_scope"
    generate_pdr_index "$to_scope"
}

# ============================================================================
# One-time migration: heading-based metadata → YAML frontmatter
# ============================================================================

# Migrate a legacy PDR file (heading-based metadata) to YAML frontmatter.
# Reads Status/Date/Owner/Category/Feature-Area/Title from headings, prepends
# frontmatter, and preserves the body unchanged. Skips files that already have
# frontmatter. Strips ** bold markers from Status.
# Usage: migrate_pdr_to_frontmatter <file>
migrate_pdr_to_frontmatter() {
    local file="$1"
    [ -f "$file" ] || { echo "[WARN] migrate: file not found: $file" >&2; return 1; }

    # Skip if already has frontmatter
    if head -1 "$file" | grep -q '^---[[:space:]]*$'; then
        return 0
    fi

    local title status date owner category feature_area

    title=$(parse_pdr_heading_title "$file")
    status=$(parse_pdr_heading_field "$file" "Status")
    date=$(parse_pdr_heading_field "$file" "Date")
    owner=$(parse_pdr_heading_field "$file" "Owner")
    category=$(parse_pdr_heading_field "$file" "Category")
    feature_area=$(parse_pdr_heading_field "$file" "Feature-Area")

    # Strip ** bold markers from status
    status="${status//\*\*/}"

    # Build frontmatter
    local fm="---
status: ${status:-Unknown}
date: ${date:-YYYY-MM-DD}
owner: ${owner:-Unknown}
category: ${category:-Unknown}
feature-area: ${feature_area:-system}
title: ${title:-Untitled}
---
"

    # Prepend frontmatter to the original body
    printf '%s\n%s\n' "$fm" "$(cat "$file")" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Migrate all PDR files in a directory.
# Usage: migrate_pdr_dir <dir>
migrate_pdr_dir() {
    local dir="$1"
    [ -d "$dir" ] || { echo "[WARN] migrate_pdr_dir: dir not found: $dir" >&2; return 1; }
    local f count=0 skipped=0
    for f in "$dir"/PDR-*.md; do
        [ -f "$f" ] || continue
        if head -1 "$f" | grep -q '^---[[:space:]]*$'; then
            skipped=$((skipped + 1))
        else
            migrate_pdr_to_frontmatter "$f" && count=$((count + 1))
        fi
    done
    echo "[INFO] migrate_pdr_dir: migrated $count file(s), skipped $skipped (already had frontmatter)"
}

# ============================================================================
# Fix frontmatter: re-extract metadata from body headings and update frontmatter
# ============================================================================

# Fix PDR frontmatter by re-reading heading-based metadata from the body.
# For files that were migrated with incorrect/blank frontmatter (e.g., due to
# a parser bug), this function re-extracts Status/Date/Owner/Category/Feature-Area/Title
# from the body headings and rewrites the frontmatter block.
# Usage: fix_pdr_frontmatter <file>
fix_pdr_frontmatter() {
    local file="$1"
    [ -f "$file" ] || { echo "[WARN] fix_pdr_frontmatter: file not found: $file" >&2; return 1; }

    # Must have frontmatter to fix
    if ! head -1 "$file" | grep -q '^---[[:space:]]*$'; then
        return 0  # Not migrated yet — skip
    fi

    # Extract metadata from body headings (these are always present, even after migration)
    local title status date owner category feature_area
    title=$(parse_pdr_heading_title "$file")
    status=$(parse_pdr_heading_field "$file" "Status")
    date=$(parse_pdr_heading_field "$file" "Date")
    owner=$(parse_pdr_heading_field "$file" "Owner")
    category=$(parse_pdr_heading_field "$file" "Category")
    feature_area=$(parse_pdr_heading_field "$file" "Feature-Area")

    # Strip ** bold markers
    status="${status//\*\*/}"

    # Skip if all fields are empty (can't fix)
    if [ -z "$status" ] && [ -z "$date" ] && [ -z "$owner" ] && [ -z "$category" ] && [ -z "$feature_area" ] && [ -z "$title" ]; then
        return 0
    fi

    # Read current frontmatter values to preserve any non-empty ones
    local fm_status fm_date fm_owner fm_category fm_feature_area fm_title
    fm_status=$(parse_fm_field "$file" "status")
    fm_date=$(parse_fm_field "$file" "date")
    fm_owner=$(parse_fm_field "$file" "owner")
    fm_category=$(parse_fm_field "$file" "category")
    fm_feature_area=$(parse_fm_field "$file" "feature-area")
    fm_title=$(parse_fm_field "$file" "title")

    # Use heading value if non-empty, else keep frontmatter value, else default
    [ -n "$status" ] && fm_status="$status"
    [ -n "$date" ] && fm_date="$date"
    [ -n "$owner" ] && fm_owner="$owner"
    [ -n "$category" ] && fm_category="$category"
    [ -n "$feature_area" ] && fm_feature_area="$feature_area"
    [ -n "$title" ] && fm_title="$title"

    # Defaults for any remaining blanks
    [ -z "$fm_status" ] && fm_status="Unknown"
    [ -z "$fm_date" ] && fm_date="YYYY-MM-DD"
    [ -z "$fm_owner" ] && fm_owner="Unknown"
    [ -z "$fm_category" ] && fm_category="Unknown"
    [ -z "$fm_feature_area" ] && fm_feature_area="system"
    [ -z "$fm_title" ] && fm_title="Untitled"

    # Build new frontmatter
    local new_fm="---
status: $fm_status
date: $fm_date
owner: $fm_owner
category: $fm_category
feature-area: $fm_feature_area
title: $fm_title
---"

    # Replace the old frontmatter block (everything between the first and second `---`)
    # with the new frontmatter, keeping the body unchanged.
    local body
    body=$(awk '
        BEGIN { fm_count = 0; printing = 0 }
        /^---[[:space:]]*$/ { fm_count++; if (fm_count == 2) { printing = 1; next } else { next } }
        fm_count >= 2 && printing { print }
    ' "$file")

    printf '%s\n\n%s\n' "$new_fm" "$body" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Fix all PDR files in a directory.
# Usage: fix_pdr_dir <dir>
fix_pdr_dir() {
    local dir="$1"
    [ -d "$dir" ] || { echo "[WARN] fix_pdr_dir: dir not found: $dir" >&2; return 1; }
    local f count=0
    for f in "$dir"/PDR-*.md; do
        [ -f "$f" ] || continue
        fix_pdr_frontmatter "$f" && count=$((count + 1))
    done
    echo "[INFO] fix_pdr_dir: fixed $count file(s)"
}

# ============================================================================
# Level-agnostic Accepted counter (replaces the H3-hardcoded grep)
# ============================================================================

# Count PDRs with Accepted status in a directory, handling both YAML frontmatter
# and heading-based metadata (H2 or H3). Replaces setup-product-clarify.sh:14
# which hardcoded '^### Status'.
# Usage: count_pdr_accepted <dir>
count_pdr_accepted() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    local count=0 f status
    for f in "$dir"/PDR-*.md; do
        [ -f "$f" ] || continue
        status=$(parse_pdr_field "$f" "status")
        # Normalize: strip ** bold, lowercase, trim
        status=$(echo "$status" | sed 's/\*\*//g' | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ "$status" = "accepted" ] || [ "$status" = "completed" ]; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}
