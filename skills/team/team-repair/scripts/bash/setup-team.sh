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
# ENSURE ADLC ORPHAN BRANCH
###############################################################################

ensure_adlc_branch() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  local adlc_branch="adlc"

  if [[ -z "$td" || ! -d "$td/.git" ]]; then
    echo "Skipping adlc branch creation — not a git repo: $td"
    return 0
  fi

  if git -C "$td" show-ref --verify --quiet "refs/heads/$adlc_branch"; then
    echo "adlc branch already exists"
    return 0
  fi

  echo "Creating adlc orphan branch..."
  local worktree="/tmp/adlc-init-$$"

  # Create orphan branch via worktree (doesn't touch main working tree)
  git -C "$td" worktree add --detach "$worktree" 2>/dev/null || {
    echo "Failed to create worktree — trying direct orphan branch creation"
    # Fallback: create orphan branch directly (requires clean working tree)
    local current_branch
    current_branch=$(git -C "$td" branch --show-current)
    git -C "$td" checkout --orphan "$adlc_branch"
    git -C "$td" rm -rf . 2>/dev/null || true
    mkdir -p "$td/drafts/cdr" "$td/reports/sessions" "$td/reports/projects"
    echo '{}' > "$td/reports/confidence-scores.json"
    touch "$td/drafts/cdr/.gitkeep" "$td/reports/sessions/.gitkeep" "$td/reports/projects/.gitkeep"
    git -C "$td" add -A
    git -C "$td" commit -m "Initialize adlc orphan branch (drafts + reports)"
    git -C "$td" checkout "$current_branch" 2>/dev/null || git -C "$td" checkout main 2>/dev/null || true
    git -C "$td" push origin "$adlc_branch" 2>/dev/null || true
    echo "adlc orphan branch created (direct)"
    return 0
  }

  # In the detached worktree, create the orphan branch
  git -C "$worktree" checkout --orphan "$adlc_branch"
  # Remove all files from the orphan branch (start clean)
  git -C "$worktree" rm -rf . 2>/dev/null || true
  mkdir -p "$worktree/drafts/cdr" "$worktree/reports/sessions" "$worktree/reports/projects"
  echo '{}' > "$worktree/reports/confidence-scores.json"
  touch "$worktree/drafts/cdr/.gitkeep" "$worktree/reports/sessions/.gitkeep" "$worktree/reports/projects/.gitkeep"
  git -C "$worktree" add -A
  git -C "$worktree" commit -m "Initialize adlc orphan branch (drafts + reports)"
  git -C "$worktree" push origin "$adlc_branch" 2>/dev/null || true
  git -C "$td" worktree remove "$worktree" --force 2>/dev/null || true
  echo "adlc orphan branch created"
}

###############################################################################
# CONFIDENCE UPDATE FUNCTION (--update-confidence)
###############################################################################

update_confidence() {
  local td="$TEAM_AI_DIRECTIVES"
  local adlc_branch="adlc"

  # Ensure adlc branch exists
  ensure_adlc_branch "$td"

  if ! git -C "$td" show-ref --verify --quiet "refs/heads/$adlc_branch"; then
    echo "adlc branch does not exist — cannot aggregate"
    return 0
  fi

  local today
  today=$(date +%Y-%m-%d)

  _TMP_CONF=$(mktemp)
  trap 'rm -f "$_TMP_CONF" 2>/dev/null' EXIT

  cat > "$_TMP_CONF" << JSONHEAD
{
  "last_updated": "$today",
  "cdrs": {
JSONHEAD

  local first_entry=1

  local project_files
  project_files=$(git -C "$td" ls-tree --name-only "$adlc_branch" "reports/projects/" 2>/dev/null | grep '\.json$')

  declare -A agg_usage=()
  declare -A agg_apply=()
  declare -A agg_last_used=()
  declare -A agg_projects=()

  for pf in $project_files; do
    local content
    content=$(git -C "$td" show "${adlc_branch}:${pf}" 2>/dev/null || echo "")
    [[ -z "$content" ]] && continue

    local project_name
    project_name=$(echo "$content" | grep '"project"' | sed 's/.*"project"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    [[ -z "$project_name" ]] && project_name="unknown"

    local cdr_ids
    cdr_ids=$(echo "$content" | grep -oP '"CDR-[0-9]+"' | tr -d '"' | sort -u)

    for cdr_id in $cdr_ids; do
      local matched applied last_used
      matched=$(echo "$content" | grep -A10 "\"$cdr_id\"" | grep '"matched"' | sed 's/.*"matched"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | head -1)
      applied=$(echo "$content" | grep -A10 "\"$cdr_id\"" | grep '"applied"' | sed 's/.*"applied"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | head -1)
      last_used=$(echo "$content" | grep -A10 "\"$cdr_id\"" | grep '"last_used"' | sed 's/.*"last_used"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)

      [[ -z "$matched" ]] && matched=0
      [[ -z "$applied" ]] && applied=0
      [[ -z "$last_used" ]] && last_used=""

      agg_usage[$cdr_id]=$(( ${agg_usage[$cdr_id]:-0} + matched ))
      agg_apply[$cdr_id]=$(( ${agg_apply[$cdr_id]:-0} + applied ))

      if [[ "$last_used" > "${agg_last_used[$cdr_id]:-}" ]]; then
        agg_last_used[$cdr_id]="$last_used"
      fi

      local existing="${agg_projects[$cdr_id]:-}"
      if [[ -z "$existing" ]]; then
        agg_projects[$cdr_id]="\"$project_name\""
      elif ! echo "$existing" | grep -q "\"$project_name\""; then
        agg_projects[$cdr_id]="$existing, \"$project_name\""
      fi
    done
  done

  for cdr_id in "${!agg_usage[@]}"; do
    local uc="${agg_usage[$cdr_id]}"
    local ac="${agg_apply[$cdr_id]}"
    local lu="${agg_last_used[$cdr_id]:-}"
    local success_rate="0.0"

    if [[ $uc -gt 0 ]]; then
      success_rate=$(awk "BEGIN { printf \"%.2f\", $ac / $uc }")
    fi

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
      echo "," >> "$_TMP_CONF"
    fi
    first_entry=0

    cat >> "$_TMP_CONF" << ENTRY
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

  cat >> "$_TMP_CONF" << JSONFOOT
  }
}
JSONFOOT

  cat "$_TMP_CONF"
  rm -f "$_TMP_CONF"
}

###############################################################################
# CLI ENTRY
###############################################################################

if [[ "${1:-}" == "--ensure-adlc" ]]; then
  ensure_adlc_branch
  exit 0
fi

if [[ "${1:-}" == "--update-confidence" ]]; then
  update_confidence
  exit 0
fi
