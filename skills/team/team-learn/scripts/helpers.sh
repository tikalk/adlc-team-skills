#!/usr/bin/env bash
# helpers.sh — Shared utilities for team-learn skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# 1. PATH RESOLUTION
###############################################################################

resolve_team_learn_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"

  TEAM_AI_DIRECTIVES="${TEAM_AI_DIRECTIVES:-}"
  if [[ -z "$TEAM_AI_DIRECTIVES" && -f "${PROJECT_ROOT}/.adlc/init-options.json" ]]; then
    TEAM_AI_DIRECTIVES=$(grep '"team_ai_directives"' "${PROJECT_ROOT}/.adlc/init-options.json" \
      | sed 's/.*"team_ai_directives"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
      | head -1)
  fi
  [[ -z "$TEAM_AI_DIRECTIVES" || "$TEAM_AI_DIRECTIVES" = "null" ]] && TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"

  ADLC_BRANCH="adlc"
  ADLC_WORKTREE="/tmp/adlc-worktree-$$"
  CDR_DRAFTS_DIR="drafts/cdr"
  CDR_INDEX_FILE="drafts/cdr/cdr.md"
  REPORTS_DIR="reports"
  SESSIONS_DIR="reports/sessions"
  PROJECTS_DIR="reports/projects"
  CONFIDENCE_FILE="reports/confidence-scores.json"

  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
  echo "ADLC_BRANCH=$ADLC_BRANCH"
  echo "ADLC_WORKTREE=$ADLC_WORKTREE"
  echo "CDR_DRAFTS_DIR=$CDR_DRAFTS_DIR"
  echo "CDR_INDEX_FILE=$CDR_INDEX_FILE"
  echo "REPORTS_DIR=$REPORTS_DIR"
  echo "SESSIONS_DIR=$SESSIONS_DIR"
  echo "PROJECTS_DIR=$PROJECTS_DIR"
  echo "CONFIDENCE_FILE=$CONFIDENCE_FILE"
}

output_json() {
  resolve_team_learn_paths >/dev/null
  cat << JSON
{"REPO_ROOT":"$PROJECT_ROOT","TEAM_AI_DIRECTIVES":"$TEAM_AI_DIRECTIVES","BRANCH":"$BRANCH","ADLC_BRANCH":"$ADLC_BRANCH","ADLC_WORKTREE":"$ADLC_WORKTREE"}
JSON
}

###############################################################################
# 2. ADLC ORPHAN BRANCH MANAGEMENT
###############################################################################

ensure_adlc_branch() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  if ! git -C "$td" show-ref --verify --quiet "refs/heads/$ADLC_BRANCH"; then
    git -C "$td" branch --orphan "$ADLC_BRANCH"
    git -C "$td" worktree add "$ADLC_WORKTREE" "$ADLC_BRANCH" 2>/dev/null
    mkdir -p "$ADLC_WORKTREE/drafts/cdr" "$ADLC_WORKTREE/reports/sessions" "$ADLC_WORKTREE/reports/projects"
    git -C "$ADLC_WORKTREE" add -A
    git -C "$ADLC_WORKTREE" commit --allow-empty -m "Initialize adlc orphan branch"
    git -C "$ADLC_WORKTREE" push origin "$ADLC_BRANCH" 2>/dev/null || true
    git -C "$td" worktree remove "$ADLC_WORKTREE" 2>/dev/null || true
  fi
}

###############################################################################
# 3. CDR NUMBERING
###############################################################################

next_cdr_number() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  local max=0
  for f in $(git -C "$td" ls-tree --name-only "$ADLC_BRANCH" "drafts/cdr/" 2>/dev/null | sort); do
    local num
    num=$(echo "$f" | sed -n 's|.*/CDR-\([0-9]\+\)\.md|\1|p')
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    ((10#$num > max)) && max=$((10#$num))
  done
  printf '%03d' $((max + 1))
}

###############################################################################
# 4. ADLC BRANCH READ/WRITE
###############################################################################

read_adlc_file() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  local path="$2"
  git -C "$td" show "${ADLC_BRANCH}:${path}" 2>/dev/null || echo ""
}

write_adlc_file() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  local path="$2"
  local content="$3"
  git -C "$td" worktree add "$ADLC_WORKTREE" "$ADLC_BRANCH" 2>/dev/null || git -C "$td" worktree add --force "$ADLC_WORKTREE" "$ADLC_BRANCH"
  mkdir -p "$(dirname "$ADLC_WORKTREE/$path")"
  echo "$content" > "$ADLC_WORKTREE/$path"
  git -C "$ADLC_WORKTREE" add "$path"
  git -C "$ADLC_WORKTREE" commit -m "team-learn: update $path"
  git -C "$ADLC_WORKTREE" push origin "$ADLC_BRANCH" 2>/dev/null || true
  git -C "$td" worktree remove "$ADLC_WORKTREE" 2>/dev/null || true
}

###############################################################################
# 5. CDR INDEX GENERATION
###############################################################################

regenerate_cdr_index() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  local index_path="drafts/cdr/cdr.md"

  local today
  today=$(date +%Y-%m-%d)

  local entries=""
  local count=0

  for f in $(git -C "$td" ls-tree --name-only "$ADLC_BRANCH" "drafts/cdr/" 2>/dev/null | sort); do
    [[ "$f" =~ CDR-[0-9]+\.md$ ]] || continue
    local id target type status created verified age descriptor
    id=$(basename "$f" .md)
    local content
    content=$(read_adlc_file "$td" "$f")
    target=$(echo "$content" | grep -m1 '^### Target Module:' | sed 's/^### Target Module:[[:space:]]*//' | sed 's/`//g' | head -c 40 || true)
    type=$(echo "$content" | grep -m1 '^### Context Type:' | sed 's/^### Context Type:[[:space:]]*//' | head -c 20 || true)
    status=$(echo "$content" | grep -m1 '^### Status:' | sed 's/^### Status:[[:space:]]*//' | sed 's/\*\*//g' | head -c 12 || true)
    created=$(echo "$content" | grep -m1 '^### Date:' | sed 's/^### Date:[[:space:]]*//' | head -c 10 || true)
    verified=$(echo "$content" | grep -m1 '^verified:' | sed 's/verified:[[:space:]]*//' | head -c 10 || true)
    age=$(echo "$content" | grep -m1 '^age_days:' | sed 's/age_days:[[:space:]]*//' | head -c 5 || true)
    descriptor=$(echo "$content" | grep -m1 '^### Descriptor:' | sed 's/^### Descriptor:[[:space:]]*//' | head -c 60 || true)

    [[ -z "$created" ]] && created="$today"
    [[ -z "$verified" ]] && verified="-"
    [[ -z "$age" ]] && age="-"

    entries="${entries}| ${id} | ${target:- } | ${type:- } | ${status:-Discovered} | ${created} | ${verified} | ${age} | ${descriptor:- } |
"
    count=$((count + 1))
  done

  local index_content
  index_content=$(cat << EOF
# Context Directive Records

Context Directive Records (CDRs) track proposed and accepted contributions to team-ai-directives.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|
${entries}
**Stats**: ${count} entries | Last Updated: ${today}
EOF
)

  write_adlc_file "$td" "$index_path" "$index_content"
  echo "$index_path"
}

###############################################################################
# 6. SIGNAL GATE VALIDATION
###############################################################################

signal_gate() {
  local file="$1"
  local reasons=()

  if grep -qi 'project-specific\|only applies to this project\|single project' "$file" 2>/dev/null; then
    reasons+=("project-specific")
  fi
  if grep -qi 'duplicate of\|overlaps with existing\|already in team-ai-directives' "$file" 2>/dev/null; then
    reasons+=("duplicate")
  fi
  if ! grep -Eq '(src/|lib/|test/|docs/|commit|file)' "$file" 2>/dev/null; then
    reasons+=("no evidence")
  fi
  if grep -qi 'low value\|nice-to-have\|minor convenience' "$file" 2>/dev/null; then
    reasons+=("low value")
  fi

  if [[ ${#reasons[@]} -gt 0 ]]; then
    echo "SKIP: ${reasons[*]}"
    return 1
  fi

  echo "PASS"
  return 0
}

###############################################################################
# CLI ENTRY
###############################################################################

if [[ "${1:-}" == "--json" ]]; then
  output_json
elif [[ "${1:-}" == "--next-cdr" ]]; then
  next_cdr_number "${2:-}"
elif [[ "${1:-}" == "--index" ]]; then
  regenerate_cdr_index "${2:-}"
elif [[ "${1:-}" == "--signal-gate" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "ERROR: --signal-gate requires a file path" >&2
    exit 1
  fi
  signal_gate "$2"
fi
