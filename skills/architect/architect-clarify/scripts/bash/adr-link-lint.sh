#!/bin/bash
# ADR Related-ADRs link checker — flag dangling local links, never write.
#
# Scans ADR files for markdown links of the form ](ADR-*.md) and reports
# targets that do not resolve on disk next to the linking file. Catches the
# two failure shapes seen on adlc-workspace MR !158 (ChDR-007):
#   1. non-resolving relative prefix  [x](../memory/adr/ADR-000.md)
#      (resolves to memory/memory/adr/ from docs/adlc/memory/adr/)
#   2. short filename with no target  [x](ADR-000.md)
#      (real file carries a suffixed stem)
#
# Read-only by contract: this script never writes, moves or reformats an
# artifact. Remediation stays with implement/human (fix the link, keep
# sibling form per adr-template.md).
#
# Usage:
#   adr-link-lint.sh [--tsv] <file> [file...]
#
# Output:
#   default — one readable block per finding (location, target, shape,
#             suggested patch)
#   --tsv — file<TAB>line<TAB>target<TAB>shape for CI parsing
#
# Exit: 0 = all links resolve (or no links found), 1 = dangling links found.

set -u

TSV=0
if [[ "${1:-}" == "--tsv" ]]; then
    TSV=1
    shift
fi

failures=0
for file in "$@"; do
    [[ -f "$file" ]] || continue
    dir="$(cd "$(dirname "$file")" && pwd)"
    lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        # extract ](TARGET) tokens whose target starts with ADR- or contains /ADR-
        rest="$line"
        while [[ "$rest" == *"]("*")"* ]]; do
            token="${rest#*](}"
            target="${token%%)*}"
            rest="${token#*)}"
            case "$target" in
                http*|mailto:*|\#*) continue ;;
                "") continue ;;
            esac
            # strip any #anchor for the existence check
            check="${target%%#*}"
            case "$check" in
                *ADR-*.md) ;;
                *) continue ;;
            esac
            if [[ ! -e "$dir/$check" ]]; then
                failures=$((failures + 1))
                shape="short-or-moved"
                case "$check" in
                    ../*|./*|/*) shape="non-resolving-prefix" ;;
                esac
                # Suggest a suffixed sibling only on an exactly-one match: escape
                # glob metacharacters in the stem and count nullglob array
                # elements (no ls/wc parsing); on zero full-stem matches retry
                # with the numeric prefix (ADR-<digits>*.md) for wrong-suffix
                # targets. Zero or 2+ matches -> generic fallback.
                stem="${check##*/}"
                stem="${stem%.md}"
                suggestion=""
                esc_stem="$(printf '%s' "$stem" | sed 's/[][\\*?]/\\&/g')"
                shopt -s nullglob
                # shellcheck disable=SC2086,SC2206
                matches=("$dir"/${esc_stem}*.md)
                shopt -u nullglob
                if [[ "${#matches[@]}" -eq 1 ]]; then
                    suggestion="$(basename "${matches[0]}")"
                fi
                if [[ "$TSV" == "1" ]]; then
                    printf '%s\t%s\t%s\t%s\n' "$file" "$lineno" "$target" "$shape"
                else
                    echo "DANGLING-LINK $file:$lineno"
                    echo "  target: $target ($shape)"
                    if [[ -n "$suggestion" ]]; then
                        echo "  suggest: ($suggestion)"
                    else
                        echo "  suggest: sibling-form (ADR-<stem>.md) must exist next to the linking file"
                    fi
                fi
            fi
        done
    done < "$file"
done

if [[ "$failures" -gt 0 ]]; then
    [[ "$TSV" == "1" ]] || echo "adr-link-lint: $failures dangling link(s)"
    exit 1
fi
[[ "$TSV" == "1" ]] || echo "adr-link-lint: all Related-ADRs targets resolve"
exit 0
