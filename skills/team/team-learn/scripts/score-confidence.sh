#!/usr/bin/env bash
# score-confidence.sh — Calculate confidence score for a CDR
set -euo pipefail

calculate_confidence() {
  local cdr_file="$1"
  local confidence_file="${2:-}"

  local base_score=0.60
  local bonuses=0
  local usage_multiplier=1.0

  # Determine base score by type
  local type
  type=$(grep -m1 '^### Context Type:' "$cdr_file" 2>/dev/null | sed 's/^### Context Type:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' || echo "rule")
  case "$type" in
    rule) base_score=0.60 ;;
    persona) base_score=0.50 ;;
    example) base_score=0.50 ;;
    constitution) base_score=0.70 ;;
    *) base_score=0.60 ;;
  esac

  # Bonus: paired eval exists
  if grep -q '### Paired Eval' "$cdr_file" 2>/dev/null; then
    bonuses=$(echo "$bonuses + 0.20" | bc)
  fi

  # Bonus: evidence includes file paths/commits
  if grep -Eq '(src/|lib/|test/|docs/|commit|file)' "$cdr_file" 2>/dev/null; then
    bonuses=$(echo "$bonuses + 0.10" | bc)
  fi

  # Bonus: multiple projects
  local project_field
  project_field=$(grep -m1 '^project:' "$cdr_file" 2>/dev/null | sed 's/^project:[[:space:]]*//' || echo "")
  if echo "$project_field" | grep -q ',' 2>/dev/null; then
    bonuses=$(echo "$bonuses + 0.10" | bc)
  fi

  # Usage multiplier from confidence-scores.json
  if [[ -n "$confidence_file" ]]; then
    local cdr_id
    cdr_id=$(basename "$cdr_file" .md)
    local success_rate
    success_rate=$(python3 -c "
import json
try:
    with open('$confidence_file') as f:
        data = json.load(f)
    cdr = data.get('cdrs', {}).get('$cdr_id', {})
    print(cdr.get('success_rate', 1.0))
except Exception:
    print(1.0)
" 2>/dev/null || echo "1.0")
    if (( $(echo "$success_rate > 0.8" | bc -l) )); then
      usage_multiplier=1.2
    elif (( $(echo "$success_rate < 0.5" | bc -l) )); then
      usage_multiplier=0.8
    fi
  fi

  local final_score
  final_score=$(echo "scale=2; ($base_score + $bonuses) * $usage_multiplier" | bc)
  # Cap at 1.0
  (( $(echo "$final_score > 1.0" | bc -l) )) && final_score=1.0

  local tier="LOW"
  (( $(echo "$final_score >= 0.8" | bc -l) )) && tier="HIGH"
  (( $(echo "$final_score >= 0.5" | bc -l) && $(echo "$final_score < 0.8" | bc -l) )) && tier="MEDIUM"

  echo "$final_score $tier"
}

# CLI entry
if [[ "${1:-}" == "--calculate" ]]; then
  calculate_confidence "$2" "${3:-}"
fi
