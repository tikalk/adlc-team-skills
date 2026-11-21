#!/usr/bin/env bash
# Shared clarify ASCII generator — renders DECISION MAP and STATUS BOX visuals.
# Contract: skills/authoring/references/ste-rules.md §2 (ASCII-first), §3–§4.
# Width budget: every output line stays within 75 columns. Never hand-draw maps
# in skills — invoke render_decision_map / render_status_box from this file
# (or the PowerShell twin Render-DecisionMap.ps1, byte-identical output).
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/render-decision-map.sh"
#   render_status_box "PDR-001" "Missing metric" "PDR-001 lacks a success metric."
#   render_decision_map "ADR-002" "DB choice" "ADR-002 picks the store." \
#       "record,lane" "record=pdr.md index;lane=product lane" \
#       "A|Add metric|+|Measurable.|-|Needs baseline.|*|?" "Halt ADR-002."

_WIDTH=75

_trunc() {
    local s="$1"
    local max="$2"
    local len
    len=$(printf '%s' "$s" | wc -c)
    if [ "$len" -gt "$max" ]; then
        local cut=$((max - 3))
        printf '%s...' "$(printf '%s' "$s" | cut -c1-"$cut")"
    else
        printf '%s' "$s"
    fi
}

_row() {
    local label="$1"
    local value="$2"
    local avail=$((_WIDTH - ${#label} - 6))
    value="$(_trunc "$value" "$avail")"
    printf '| %s: %-*s |\n' "$label" "$avail" "$value"
}

_bar() {
    printf '+'
    printf -- '-%.0s' $(seq 1 $((_WIDTH - 2)))
    printf '+\n'
}

# render_status_box <id> <title> <gap-sentence>
render_status_box() {
    local id="$1" title="$2" gap="$3"
    _bar
    _row "CLARIFICATION" "$id - $title"
    _bar
    _row "Gap" "$gap"
    _row "Ask" "Choose an option for $id."
    _bar
}

# render_decision_map <id> <title> <what_why> <boundaries-csv> <reach-semis>
#     <option-pipe-fields>... <if_undecided>
# Each option: Letter|Title|+|Pro|-|Con|*|Impact (use "?" for unknown slots).
render_decision_map() {
    local id="$1" title="$2" what_why="$3" boundaries="$4" reach="$5"
    shift 5
    local if_undecided="${!#}"
    local -a options=()
    while [ "$#" -gt 1 ]; do
        options+=("$1")
        shift
    done

    _bar
    _row "DECISION MAP" "$id - $title"
    _row "WHAT/WHY" "$what_why"
    _row "BOUNDARIES" "$boundaries"
    _bar
    printf '| %-71s |\n' "REACH FAN-OUT:"
    local pair key val
    IFS=';' read -ra _reach_pairs <<< "$reach"
    for pair in "${_reach_pairs[@]}"; do
        key="${pair%%=*}"
        val="${pair#*=}"
        [ "$key" = "$pair" ] && { key="$pair"; val="?"; }
        printf '|   +-[%-8s] --> %-*s |\n' "$key" "51" "$(_trunc "$val" 51)"
    done
    _bar
    printf '| %-71s |\n' "CANDIDATES & TRADEOFFS:"
    printf '| %-71s |\n' ""
    local opt letter otitle pmark pro cmark con imark impact
    for opt in "${options[@]}"; do
        IFS='|' read -r letter otitle pmark pro cmark con imark impact <<< "$opt"
        printf '| Option %s: %-*s |\n' "$letter" "61" "$(_trunc "$otitle" 61)"
        printf '|   %s %-*s |\n' "$pmark" "67" "$(_trunc "$pro" 67)"
        printf '|   %s %-*s |\n' "$cmark" "67" "$(_trunc "$con" 67)"
        printf '|   %s Cross-boundary:%-*s|\n' "$imark" "53" " $(_trunc "$impact" 52)"
        printf '| %-71s |\n' ""
    done
    _bar
    _row "IF-UNDECIDED" "$if_undecided"
    _bar
}

export -f render_status_box
export -f render_decision_map
