#!/bin/bash
# Mermaid syntax validator (the mermaid detection pass) — flag + suggest, never write.
#
# Scans a markdown artifact for ```mermaid fenced blocks and reports one
# finding per broken block: location (file + line + fence index), severity,
# the rule violated, the offending line, and a minimal suggested patch.
#
# Read-only by contract (the lifecycle write scope lifecycle write scope): this script never
# writes, moves or reformats an artifact. Remediation stays with
# implement/human.
#
# Severity (the mermaid detection pass):
#   HIGH   = syntax-break — the block cannot render
#   MEDIUM = style         — renderable but non-mandated form, a body that
#                            carries no statement at all, or a type this rule
#                            set cannot vouch for (never a false HIGH)
#
# Comments and directives:
#   `%% …` is a mermaid comment and `%%{ … }%%` is a mermaid directive. Both
#   are legal anywhere inside a block and carry no diagram content — mermaid
#   strips them before it parses the block. This validator therefore skips
#   them wherever it reads a block: they are never the block's type
#   declaration and never one of its statements.
#
# Usage:
#   mermaid-lint.sh [--tsv] <file> [file...]
#
# Output:
#   default — one readable block per finding (severity, rule, location,
#             offending line, suggested patch)
#   --tsv  — one tab-separated line per finding, for machine consumption:
#             severity \t rule \t file \t line \t fence \t message \t
#             offending \t suggestion
#             (no JSON: this script builds no JSON by hand, and pulls in no
#             runtime dependency — runtime independence)
#
# Exit codes:
#   0 = no findings
#   1 = at least one HIGH (syntax-break) finding
#   2 = only MEDIUM (style) findings
#   3 = usage error (missing file)
#
# Rule set is documented once in AD v13.14.0 (the mermaid detection pass) and referenced by
# product-analyze and architect-analyze — not forked per skill.

set -u

TSV=false
FILES=()
for arg in "$@"; do
    case "$arg" in
        --tsv) TSV=true ;;
        --help|-h)
            sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "mermaid-lint: unknown option '$arg'" >&2
            exit 3
            ;;
        *) FILES+=("$arg") ;;
    esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Usage: mermaid-lint.sh [--json] <file> [file...]" >&2
    exit 3
fi

# ── rule tables ──────────────────────────────────────────────────────────────
# Known mermaid diagram keywords. A block whose first content line is not in
# this set is MEDIUM (unknown-but-plausible -> review prompt), never HIGH.
# `flow` and `chart` are NOT keywords: mermaid spells it `flowchart` (one
# word) or the legacy `graph`. A block opening with `chart TD` (or
# `flow chart TD`) therefore falls through to the MEDIUM M002 branch.
KNOWN_TYPES=" flowchart graph gantt journey erDiagram sequenceDiagram classDiagram stateDiagram stateDiagram-v2 pie mindmap timeline quadrantChart gitGraph requirementDiagram C4Context C4Container C4Component C4Dynamic C4Deployment zenuml block-beta sankey-beta packet-beta kanban architecture-beta xychart-beta treemap-beta radar-beta "

# The product mandate (product-implement) requires `flowchart`, not `graph`.
# `graph` still renders, so it is a style finding, not a syntax break.
MANDATED_FLOWCHART_TYPES=" flowchart graph "

# gantt statements that are structurally meaningful.
GANTT_KEYS=" dateFormat axisFormat excludes includes section todayMarker tickInterval weekday weekend title "

# A gantt task line: "<name> : <id>, <start>[, <end|duration>]". The
# `dateFormat` key is optional in mermaid, so a task line is a valid first
# statement — recognised separately from the keys above.
GANTT_TASK_RE='^[^:]+:[^,]+,[[:space:]]*[^,]+'

# A task-line-shaped statement that is not a complete task line ("<name> :"
# with no id/start): ambiguous, so it is reported MEDIUM, never a false HIGH.
GANTT_TASK_LOOSE_RE='^[^:]+:'

# sequenceDiagram statement heads.
#
# The keyword table must track mermaid's own grammar, not an impression of it:
# every head here was checked against `mermaid.parse()` (12.2.0) as a first
# statement. `title`, `autonumber`, `box`, `critical` and `break` are
# documented statements mermaid accepts, so leaving them out turned valid
# blocks into HIGH findings. `done` is deliberately absent — mermaid rejects
# it as a first statement.
SEQ_KEYS=" participant actor boundary control entity database collections queue alt else opt loop par and rect activate deactivate note link links over right left of title autonumber box critical break end "

HIGH=0
MEDIUM=0
FINDINGS=0

# Collapse tabs and newlines so a field can never break the line format.
flatten() {
    printf '%s' "$1" | tr '\t\n\r' '   ' | sed -e 's/[[:space:]]\{2,\}/ /g' -e 's/^ //' -e 's/ $//'
}

# emit <severity> <rule> <file> <line> <fence_index> <message> <offending> <patch>
emit() {
    local sev="$1" rule="$2" file="$3" line="$4" idx="$5" msg="$6" offending="$7" patch="$8"
    FINDINGS=$((FINDINGS + 1))
    if [ "$sev" = "HIGH" ]; then HIGH=$((HIGH + 1)); else MEDIUM=$((MEDIUM + 1)); fi
    if [ "$TSV" = true ]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$sev" "$rule" "$(flatten "$file")" "$line" "$idx" \
            "$(flatten "$msg")" "$(flatten "$offending")" "$(flatten "$patch")"
    else
        printf '%s  %s  %s:%s (fence #%s)\n' "$sev" "$rule" "$file" "$line" "$idx"
        printf '      %s\n' "$msg"
        printf '      offending: %s\n' "$offending"
        printf '      suggestion: %s\n' "$patch"
    fi
}

# A known keyword check: " word " membership in a space-delimited table.
has_word() {
    case "$1" in
        *" $2 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# The first whitespace-delimited token of a line, leading whitespace ignored.
first_word() {
    printf '%s' "$1" | sed -e 's/^[[:space:]]*//' | awk '{print $1}'
}

# Is this line a mermaid comment (`%% …`) or directive (`%%{ … }%%`)?
# The check is on the line's first non-space content: only a line whose own
# first non-space characters are `%%` is a comment. A `%%` *inside* a
# statement (`A --> B %% note`) is not a comment — mermaid rejects that form
# (it is a parse error, not a trailing comment). This rule set does not
# model it: such a line is still read as a statement, and no rule is raised
# for it here.
is_comment() {
    case "$(printf '%s' "$1" | sed -e 's/^[[:space:]]*//')" in
        '%%'*) return 0 ;;
        *) return 1 ;;
    esac
}

lint_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "mermaid-lint: file not found: $file" >&2
        return 1
    fi

    local lineno=0 fence_index=0 in_block=0 block_start=0 block_header="" block_header_line=0
    # content_lines counts only the lines that carry diagram content — the
    # type declaration and its statements; comment_lines counts the stripped
    # comments/directives. A block's verdict is driven by content_lines: a
    # blank line and a comment carry no content, so neither of them changes
    # the count.
    local content_lines=0 comment_lines=0 body_first="" body_first_line=0 decl=""
    local line

    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"

        if [ "$in_block" -eq 0 ]; then
            # Opening fence: a line whose first non-space content is ```mermaid
            case "$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//')" in
                '```mermaid'*)
                    in_block=1
                    fence_index=$((fence_index + 1))
                    block_start=$lineno
                    block_header=""
                    block_header_line=0
                    content_lines=0
                    comment_lines=0
                    body_first=""
                    body_first_line=0
                    decl=""
                    ;;
            esac
            continue
        fi

        # Inside a block: a bare closing fence ends it.
        case "$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//')" in
            '```')
                # ── classify the block that just closed ──────────────────
                if [ "$content_lines" -eq 0 ]; then
                    # The block carries no diagram content — mermaid strips
                    # comments and directives before it parses, so a block
                    # holding only those is, to mermaid, an empty block: its
                    # own parser refuses it with "No diagram type detected".
                    # The block therefore cannot render, and HIGH stays the
                    # honest severity (HIGH = the block cannot render) — this
                    # is a real syntax break, not a false one. A MEDIUM
                    # "nothing verifiable here" would misreport a block that
                    # mermaid is certain about.
                    local empty_msg="mermaid block has no content"
                    if [ "$comment_lines" -gt 0 ]; then
                        empty_msg="mermaid block holds only comments or directives — no diagram content to render"
                    fi
                    emit HIGH M004-empty-block "$file" "$block_start" "$fence_index" \
                        "$empty_msg" \
                        "\`\`\`mermaid" \
                        "add the diagram body, e.g. \`\`\`mermaid / flowchart TD / A[Start] --> B[End] / \`\`\`"
                else
                    local type_kw
                    type_kw=$(printf '%s' "$block_header" | awk '{print $1}')
                    if [ -z "$type_kw" ]; then
                        emit HIGH M003-missing-diagram-type "$file" "$block_header_line" "$fence_index" \
                            "mermaid block declares no diagram type" \
                            "$block_header" \
                            "start the block with a type keyword, e.g. \`flowchart TD\`"
                    elif ! has_word "$KNOWN_TYPES" "$type_kw"; then
                        emit MEDIUM M002-unknown-diagram-type "$file" "$block_header_line" "$fence_index" \
                            "unrecognised diagram type '$type_kw' — not verifiable by this rule set" \
                            "$block_header" \
                            "confirm the type is valid mermaid; this rule set cannot vouch for it"
                    else
                        if has_word "$MANDATED_FLOWCHART_TYPES" "$type_kw" && [ "$type_kw" = "graph" ]; then
                            emit MEDIUM M009-non-mandated-keyword "$file" "$block_header_line" "$fence_index" \
                                "'graph' renders but the product mandate requires 'flowchart'" \
                                "$block_header" \
                                "use \`flowchart${block_header#graph}\` instead"
                        fi
                        if [ "$content_lines" -le 1 ]; then
                            # A declared type and nothing else: the block
                            # carries no statement at all. mermaid renders it
                            # (an empty chart), so it is NOT a syntax break —
                            # MEDIUM, never HIGH. The count is driven by the
                            # *content* lines (the type declaration plus its
                            # statements), so a trailing blank line or a
                            # trailing comment cannot change the verdict: the
                            # block is reported the same whether its body is
                            # empty, blank or comment-only.
                            emit MEDIUM M005-empty-body "$file" "$block_header_line" "$fence_index" \
                                "the block declares the '$type_kw' type but carries no statement" \
                                "$block_header" \
                                "add at least one statement for this type, e.g. \`A[Start] --> B[End]\`, \`Task : a1, 2026-01-01, 3d\`, \`participant A\`, \`CUSTOMER ||--o{ ORDER : places\`"
                        else
                            # A first statement exists: the per-type rules judge
                            # whether it is well-formed. A malformed first
                            # statement is a real syntax break (HIGH).
                            case "$type_kw" in
                                gantt)
                                    local gantt_head
                                    gantt_head=$(first_word "$body_first")
                                    if has_word "$GANTT_KEYS" "$gantt_head"; then
                                        :
                                    elif printf '%s' "$body_first" | grep -qE "$GANTT_TASK_RE"; then
                                        :
                                    elif printf '%s' "$body_first" | grep -qE "$GANTT_TASK_LOOSE_RE"; then
                                        emit MEDIUM M006-malformed-gantt-header "$file" "$body_first_line" "$fence_index" \
                                            "gantt block's first statement looks like a task line but is incomplete" \
                                            "$body_first" \
                                            "write the task as \`<name> : <id>, <start>[, <end|duration>]\`"
                                    else
                                        emit HIGH M006-malformed-gantt-header "$file" "$body_first_line" "$fence_index" \
                                            "gantt block's first statement is neither a gantt key nor a task line" \
                                            "$body_first" \
                                            "start with a gantt key (e.g. \`dateFormat YYYY-MM-DD\`) or a task line (e.g. \`Task : a1, 2024-01-01, 3d\`)"
                                    fi
                                    ;;
                                sequenceDiagram)
                                    local ok=false head
                                    head=$(first_word "$body_first")
                                    if has_word "$SEQ_KEYS" "$head" || printf '%s' "$body_first" | grep -qE '^[A-Za-z0-9_]+[[:space:]]*(->>|-->>|->|-->|-\)|--)'; then
                                        ok=true
                                    fi
                                    if [ "$ok" = false ]; then
                                        emit HIGH M007-malformed-sequence-diagram "$file" "$body_first_line" "$fence_index" \
                                            "sequenceDiagram block has no participant or message statement" \
                                            "$body_first" \
                                            "add a participant or message, e.g. \`participant A\` or \`A->>B: hello\`"
                                    fi
                                    ;;
                                erDiagram)
                                    # A relation, an attribute block, or a bare
                                    # entity list. mermaid parses a bare
                                    # identifier list as isolated entities and
                                    # renders it, so "the first statement is not
                                    # a relation" is NOT a syntax break — that
                                    # false HIGH is what made this rule
                                    # untrustworthy. What genuinely breaks the
                                    # parse is a name carrying characters
                                    # outside mermaid's entity-name grammar.
                                    if printf '%s' "$body_first" | grep -qE '[{}]|\}\||\|o|o\{|\}\|--|\.\.'; then
                                        :
                                    elif printf '%s' "$body_first" | grep -qE '[#@!?%():;,+=~|<>`'"'"']'; then
                                        emit HIGH M008-malformed-entity-diagram "$file" "$body_first_line" "$fence_index" \
                                            "erDiagram entity name carries a character mermaid rejects" \
                                            "$body_first" \
                                            "entity names take letters, digits, \`_\`, \`-\`, \`.\` and spaces — write a relation as \`CUSTOMER ||--o{ ORDER : places\`"
                                    fi
                                    ;;
                            esac
                        fi
                    fi
                fi
                in_block=0
                continue
                ;;
        esac

        # Content line inside the block.
        if is_comment "$line"; then
            # A comment (`%% …`) or a directive (`%%{ … }%%`) is not content:
            # mermaid strips it before it parses, so it is neither the block's
            # type declaration nor one of its statements. It is counted on its
            # own (comment_lines) and never as content, so it can neither
            # pass for a statement nor change the empty-body verdict.
            comment_lines=$((comment_lines + 1))
            continue
        fi
        if [ -n "$(printf '%s' "$line" | tr -d '[:space:]')" ]; then
            content_lines=$((content_lines + 1))
            if [ "$block_header_line" -eq 0 ]; then
                # First content line is the type declaration — a comment
                # ahead of it is skipped, so a leading comment never reads
                # as the diagram's type.
                block_header_line=$lineno
                block_header="$line"
                decl=$(printf '%s' "$line" | awk '{print $1}')
            elif [ -z "$body_first" ]; then
                # First statement after the type declaration — comments in
                # between are skipped, so the first *statement* is read, not
                # the first line that happens to follow the type.
                body_first="$line"
                body_first_line=$lineno
            fi
        fi
    done < "$file"

    # ── unterminated block ───────────────────────────────────────────────────
    if [ "$in_block" -eq 1 ]; then
        emit HIGH M001-fence-not-closed "$file" "$block_start" "$fence_index" \
            "mermaid block opened at line $block_start is never closed" \
            "\`\`\`mermaid" \
            "close the block with a bare \`\`\` fence"
    fi
}

for f in "${FILES[@]}"; do
    lint_file "$f" || exit 3
done

if [ "$TSV" != true ]; then
    if [ "$FINDINGS" -eq 0 ]; then
        echo "mermaid-lint: no findings in ${#FILES[@]} file(s)"
    else
        echo "mermaid-lint: $FINDINGS finding(s) — HIGH=$HIGH MEDIUM=$MEDIUM"
    fi
fi

if [ "$HIGH" -gt 0 ]; then exit 1; fi
if [ "$MEDIUM" -gt 0 ]; then exit 2; fi
exit 0
