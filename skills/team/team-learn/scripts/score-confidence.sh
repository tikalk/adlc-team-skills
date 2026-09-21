#!/usr/bin/env bash
# score-confidence.sh — Calculate confidence score for a CDR
set -euo pipefail

# Simple integer math with awk for floating point
# Usage: calc "0.60 + 0.20" → 0.80
calc() {
  awk "BEGIN { printf \"%.2f\", $1 }"
}

# Compare two floats: returns 0 if $1 > $2
gt() {
  awk "BEGIN { exit !($1 > $2) }"
}

# Compare two floats: returns 0 if $1 >= $2
ge() {
  awk "BEGIN { exit !($1 >= $2) }"
}

# Compare two floats: returns 0 if $1 < $2
lt() {
  awk "BEGIN { exit !($1 < $2) }"
}

calculate_confidence() {
  local cdr_file="$1"
  local confidence_file="${2:-}"

  local base_score="0.60"
  local bonuses="0.00"
  local usage_multiplier="1.0"

  # Determine base score by type
  local type
  type=$(grep -m1 '^### Context Type:' "$cdr_file" 2>/dev/null | sed 's/^### Context Type:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' || echo "rule")
  case "$type" in
    rule) base_score="0.60" ;;
    persona) base_score="0.50" ;;
    example) base_score="0.50" ;;
    constitution) base_score="0.70" ;;
    *) base_score="0.60" ;;
  esac

  # Bonus: paired eval exists
  if grep -q '### Paired Eval' "$cdr_file" 2>/dev/null; then
    bonuses=$(calc "$bonuses + 0.20")
  fi

  # Bonus: evidence includes file paths/commits
  if grep -Eq '(src/|lib/|test/|docs/|commit|file)' "$cdr_file" 2>/dev/null; then
    bonuses=$(calc "$bonuses + 0.10")
  fi

  # Bonus: multiple projects
  local project_field
  project_field=$(grep -m1 '^project:' "$cdr_file" 2>/dev/null | sed 's/^project:[[:space:]]*//' || echo "")
  if echo "$project_field" | grep -q ',' 2>/dev/null; then
    bonuses=$(calc "$bonuses + 0.10")
  fi

  # Usage multiplier from confidence-scores.json
  if [[ -n "$confidence_file" && -f "$confidence_file" ]]; then
    local cdr_id
    cdr_id=$(basename "$cdr_file" .md)
    # Parse success_rate from JSON using grep/sed (no python3)
    # Expected format: "CDR-001": { "success_rate": 0.75, ... }
    local success_rate
    success_rate=$(grep -A5 "\"$cdr_id\"" "$confidence_file" 2>/dev/null \
      | grep 'success_rate' \
      | sed 's/.*"success_rate"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/' \
      | head -1)
    [[ -z "$success_rate" ]] && success_rate="1.0"

    if gt "$success_rate" "0.8"; then
      usage_multiplier="1.2"
    elif lt "$success_rate" "0.5"; then
      usage_multiplier="0.8"
    fi
  fi

  local final_score
  final_score=$(calc "($base_score + $bonuses) * $usage_multiplier")
  # Cap at 1.0
  if gt "$final_score" "1.0"; then
    final_score="1.00"
  fi

  local tier="LOW"
  if ge "$final_score" "0.8"; then
    tier="HIGH"
  elif ge "$final_score" "0.5" && lt "$final_score" "0.8"; then
    tier="MEDIUM"
  fi

  echo "$final_score $tier"
}

# CLI entry
if [[ "${1:-}" == "--calculate" ]]; then
  calculate_confidence "$2" "${3:-}"
fi
