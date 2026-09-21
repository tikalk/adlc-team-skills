#!/usr/bin/env bash
# setup-team.sh — Setup script for team-repair skill
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
TEAM_AI_DIRECTIVES=""

INIT_OPTIONS="${PROJECT_ROOT}/.adlc/init-options.json"
if [[ -f "$INIT_OPTIONS" ]]; then
  TEAM_AI_DIRECTIVES=$(grep '"team_ai_directives"' "$INIT_OPTIONS" \
    | sed 's/.*"team_ai_directives"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
    | head -1)
fi

if [[ -z "$TEAM_AI_DIRECTIVES" || "$TEAM_AI_DIRECTIVES" = "null" ]]; then
  TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"
fi

if [[ "${1:-}" == "--json" || "${1:-}" == "-Json" ]]; then
  printf '{"REPO_ROOT": "%s", "TEAM_AI_DIRECTIVES": "%s", "BRANCH": "%s"}\n' \
    "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVES" "$BRANCH"
else
  echo "REPO_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
fi

###############################################################################
# CONFIDENCE UPDATE FUNCTION (--update-confidence)
###############################################################################

update_confidence() {
  local td="$TEAM_AI_DIRECTIVES"
  local adlc_branch="adlc"

  # Check if adlc branch exists
  if ! git -C "$td" show-ref --verify --quiet "refs/heads/$adlc_branch"; then
    echo "adlc branch does not exist — nothing to aggregate"
    return 0
  fi

  local today
  today=$(date +%Y-%m-%d)

  # Temp file for aggregated confidence scores
  local tmp_conf
  tmp_conf=$(mktemp)
  trap 'rm -f "$tmp_conf"' EXIT

  # Write JSON header
  cat > "$tmp_conf" << JSONHEAD
{
  "last_updated": "$today",
  "cdrs": {
JSONHEAD

  local first_entry=1

  # List project files from adlc branch
  local project_files
  project_files=$(git -C "$td" ls-tree --name-only "$adlc_branch" "reports/projects/" 2>/dev/null | grep '\.json$')

  # Associative arrays for aggregation (bash 4+)
  declare -A agg_usage=()
  declare -A agg_apply=()
  declare -A agg_last_used=()
  declare -A agg_projects=()

  for pf in $project_files; do
    local content
    content=$(git -C "$td" show "${adlc_branch}:${pf}" 2>/dev/null || echo "")
    [[ -z "$content" ]] && continue

    # Extract project name
    local project_name
    project_name=$(echo "$content" | grep '"project"' | sed 's/.*"project"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    [[ -z "$project_name" ]] && project_name="unknown"

    # Extract CDR entries — each block like: "CDR-001": { "matched": 8, "applied": 6, "last_used": "2025-09-21" }
    # Parse using sed/awk (no python3)
    local cdr_ids
    cdr_ids=$(echo "$content" | grep -oP '"CDR-[0-9]+"' | tr -d '"' | sort -u)

    for cdr_id in $cdr_ids; do
      # Extract matched, applied, last_used for this CDR from this project file
      local matched applied last_used
      matched=$(echo "$content" | grep -A10 "\"$cdr_id\"" | grep '"matched"' | sed 's/.*"matched"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | head -1)
      applied=$(echo "$content" | grep -A10 "\"$cdr_id\"" | grep '"applied"' | sed 's/.*"applied"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | head -1)
      last_used=$(echo "$content" | grep -A10 "\"$cdr_id\"" | grep '"last_used"' | sed 's/.*"last_used"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)

      [[ -z "$matched" ]] && matched=0
      [[ -z "$applied" ]] && applied=0
      [[ -z "$last_used" ]] && last_used=""

      # Aggregate
      agg_usage[$cdr_id]=$(( ${agg_usage[$cdr_id]:-0} + matched ))
      agg_apply[$cdr_id]=$(( ${agg_apply[$cdr_id]:-0} + applied ))

      if [[ "$last_used" > "${agg_last_used[$cdr_id]:-}" ]]; then
        agg_last_used[$cdr_id]="$last_used"
      fi

      # Track projects (simple: append if not already present)
      local existing="${agg_projects[$cdr_id]:-}"
      if [[ -z "$existing" ]]; then
        agg_projects[$cdr_id]="\"$project_name\""
      elif ! echo "$existing" | grep -q "\"$project_name\""; then
        agg_projects[$cdr_id]="$existing, \"$project_name\""
      fi
    done
  done

  # Output aggregated CDR entries as JSON
  for cdr_id in "${!agg_usage[@]}"; do
    local uc="${agg_usage[$cdr_id]}"
    local ac="${agg_apply[$cdr_id]}"
    local lu="${agg_last_used[$cdr_id]:-}"
    local success_rate="0.0"

    if [[ $uc -gt 0 ]]; then
      success_rate=$(awk "BEGIN { printf \"%.2f\", $ac / $uc }")
    fi

    # Calculate trend
    local trend="unknown"
    if [[ -n "$lu" ]]; then
      local today_epoch lu_epoch
      today_epoch=$(date -d "$today" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$today" +%s 2>/dev/null || echo 0)
      lu_epoch=$(date -d "${lu:0:10}" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "${lu:0:10}" +%s 2>/dev/null || echo 0)
      if [[ $today_epoch -gt 0 && $lu_epoch -gt 0 ]]; then
        local days=$(( (today_epoch - lu_epoch) / 86400 ))
        if [[ $days -le 7 ]]; then
          trend="rising"
        elif [[ $days -le 30 ]]; then
          trend="stable"
        else
          trend="falling"
        fi
      fi
    fi

    local projects_list="[${agg_projects[$cdr_id]}]"

    if [[ $first_entry -eq 0 ]]; then
      echo "," >> "$tmp_conf"
    fi
    first_entry=0

    cat >> "$tmp_conf" << ENTRY
    "$cdr_id": {
      "usage_count": $uc,
      "apply_count": $ac,
      "success_rate": $success_rate,
      "last_used": "$lu",
      "trend": "$trend",
      "projects": $projects_list
    }
ENTRY
  done

  # Write JSON footer
  cat >> "$tmp_conf" << JSONFOOT
  }
}
JSONFOOT

  # Output result
  cat "$tmp_conf"
  rm -f "$tmp_conf"
}

if [[ "${1:-}" == "--update-confidence" ]]; then
  update_confidence
  exit 0
fi
