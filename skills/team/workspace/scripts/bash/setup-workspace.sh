#!/usr/bin/env bash
# setup-workspace.sh — Setup for workspace --init mode (self-contained)
#
# Creates .adlc/ directory structure, checks .gitignore conventions,
# discovers child repos at depth 1, and outputs JSON metadata.
set -euo pipefail

JSON_MODE=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
  esac
done

###############################################################################
# shared layout constants (single definition in paths.sh)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/paths.sh"
fi

###############################################################################
# Path resolution (inline — no external helper dependency)
###############################################################################

resolve_project_root() {
  local dir
  dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.adlc" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

resolve_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

# JSON output always goes through jq -n (no manual string building).

###############################################################################
# .adlc/ directory structure
###############################################################################

ADLC_SUBDIRS=(
  "product"
  "drafts"
  "drafts/pdr"
  "drafts/adr"
  "drafts/cdr"
  "drafts/skills"
  "drafts/evals"
)

create_adlc_structure() {
  local adlc_dir="$1"
  local created=()
  for subdir in "${ADLC_SUBDIRS[@]}"; do
    local full_path="${adlc_dir}/${subdir}"
    if [[ ! -d "$full_path" ]]; then
      mkdir -p "$full_path"
      created+=(".adlc/${subdir}")
    fi
  done
  printf '%s\n' "${created[@]}"
}

###############################################################################
# .gitignore convention check (read-only — reports missing rules)
###############################################################################

# Rules that should be in .gitignore for workspace conventions.
#
# layout allowlist: the wholesale `.adlc/` ignore is replaced by an allowlist —
# `.adlc/*` ignored EXCEPT the tracked exceptions (`init-options.json`,
# `workspace.yml`, `drafts/`, `evals/` config, `memory/evals/holdout.json`)
# plus the generated-report and graphify rules. The allowlist has a single
# definition in paths.sh (sourced at the top of this script); the fallback
# below keeps the agent-install surface checked when paths.sh is unavailable
# (selective install) — it never reintroduces a wholesale `.adlc/` ignore.
if [ -n "${GITIGNORE_RULES_ALLOWLIST:-}" ]; then
  GITIGNORE_RULES=("${GITIGNORE_RULES_ALLOWLIST[@]}")
else
  GITIGNORE_RULES=(
    ".agents/"
    ".opencode/"
    ".claude/"
    ".cursor/"
    ".codex/"
    ".gemini/"
    ".qwen/"
    ".devin/"
    ".tabnine/"
    "skills-lock.json"
    ".skills.json"
    # .mcp.json is deliberately ABSENT: it is committed project source,
    # never generated. Only the agent dirs above are derived.
    ".events.json"
    ".pytest_cache/"
    ".ruff_cache/"
  )
fi

check_gitignore_rules() {
  local missing=()
  if [[ ! -f ".gitignore" ]]; then
    printf '%s\n' "${GITIGNORE_RULES[@]}"
    return
  fi
  for rule in "${GITIGNORE_RULES[@]}"; do
    if ! grep -qxF "$rule" .gitignore 2>/dev/null; then
      missing+=("$rule")
    fi
  done
  printf '%s\n' "${missing[@]}"
}

###############################################################################
# Child repo discovery (same logic as workspace.sh)
###############################################################################

EXCLUDE_DIRS=(node_modules .venv vvenv venv dist build target .idea .vscode .git .cache .specify)

is_excluded() {
  local name="$1"
  for ex in "${EXCLUDE_DIRS[@]}"; do
    [[ "$name" == "$ex" ]] && return 0
  done
  return 1
}

is_submodule() {
  local path="$1"
  git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | grep -q "^[^ ]* ${path}$"
}

is_tracked_in_parent() {
  git ls-files --error-unmatch "$1" >/dev/null 2>&1
}

get_remote_url() {
  git -C "$1" remote get-url origin 2>/dev/null || echo ""
}

discover_child_repos() {
  local root="$1"
  for dir in "$root"/*/; do
    [[ -d "$dir" ]] || continue
    local base
    base=$(basename "$dir")
    is_excluded "$base" && continue
    if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
      echo "$base"
    fi
  done
}

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
BRANCH=$(resolve_branch)
# Absolute form derived from the sourced ADLC_DIR constant (paths.sh),
# never redefined as a competing literal.
ADLC_DIR="${PROJECT_ROOT}/${ADLC_DIR:-.adlc}"
GITIGNORE_EXISTS=false
[[ -f "${PROJECT_ROOT}/.gitignore" ]] && GITIGNORE_EXISTS=true

# Create .adlc/ structure
ADLC_DIRS_CREATED=$(create_adlc_structure "$ADLC_DIR")

# Check .gitignore rules
GITIGNORE_RULES_MISSING=$(check_gitignore_rules)

# Discover child repos
CHILD_REPO_NAMES=$(discover_child_repos "$PROJECT_ROOT")

# Build child repo JSON array (records built with jq -n so quotes,
# backslashes, and newlines in paths/remotes cannot break output)
CHILD_REPOS_JSON="["
first=true
CHILD_COUNT=0
if [[ -n "$CHILD_REPO_NAMES" ]]; then
  while IFS= read -r repo_name; do
    [[ -z "$repo_name" ]] && continue
    repo_path="${PROJECT_ROOT}/${repo_name}"
    remote=$(get_remote_url "$repo_path")
    if is_submodule "$repo_name"; then submod="true"; else submod="false"; fi
    if is_tracked_in_parent "$repo_name"; then tracked="true"; else tracked="false"; fi

    rec=$(jq -n -c \
      --arg name "$repo_name" \
      --arg path "$repo_path" \
      --arg remote "$remote" \
      --argjson is_submodule "$submod" \
      --argjson is_tracked "$tracked" \
      '{name:$name,path:$path,remote:$remote,is_submodule:$is_submodule,is_tracked:$is_tracked}')

    if [[ "$first" == "true" ]]; then
      first=false
    else
      CHILD_REPOS_JSON+=","
    fi
    CHILD_REPOS_JSON+="$rec"
    CHILD_COUNT=$((CHILD_COUNT + 1))
  done <<< "$CHILD_REPO_NAMES"
fi
CHILD_REPOS_JSON+="]"

# Build ADLC_DIRS_CREATED JSON array
if [[ -n "${ADLC_DIRS_CREATED:-}" ]]; then
  ADLC_CREATED_JSON=$(printf '%s\n' "$ADLC_DIRS_CREATED" | jq -R . | jq -s -c .)
else
  ADLC_CREATED_JSON="[]"
fi

# Build GITIGNORE_RULES_MISSING JSON array
if [[ -n "${GITIGNORE_RULES_MISSING:-}" ]]; then
  GITIGNORE_MISSING_JSON=$(printf '%s\n' "$GITIGNORE_RULES_MISSING" | jq -R . | jq -s -c .)
else
  GITIGNORE_MISSING_JSON="[]"
fi

if $JSON_MODE; then
  jq -n \
    --arg repo_root "$PROJECT_ROOT" \
    --arg adlc_dir "$ADLC_DIR" \
    --argjson adlc_dirs_created "$ADLC_CREATED_JSON" \
    --argjson gitignore_exists "$GITIGNORE_EXISTS" \
    --argjson gitignore_rules_missing "$GITIGNORE_MISSING_JSON" \
    --argjson child_repos "$CHILD_REPOS_JSON" \
    --argjson child_count "$CHILD_COUNT" \
    --arg branch "$BRANCH" \
    '{REPO_ROOT:$repo_root,ADLC_DIR:$adlc_dir,ADLC_DIRS_CREATED:$adlc_dirs_created,GITIGNORE_EXISTS:$gitignore_exists,GITIGNORE_RULES_MISSING:$gitignore_rules_missing,CHILD_REPOS:$child_repos,CHILD_COUNT:$child_count,BRANCH:$branch}'
else
  echo "[INFO] workspace-init setup"
  echo "  REPO_ROOT: $PROJECT_ROOT"
  echo "  ADLC_DIR: $ADLC_DIR"
  echo "  BRANCH: $BRANCH"
  echo ""
  if [[ -n "$ADLC_DIRS_CREATED" ]]; then
    echo "  .adlc/ directories created:"
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      echo "    + $dir"
    done <<< "$ADLC_DIRS_CREATED"
  else
    echo "  .adlc/ structure already exists"
  fi
  echo ""
  if [[ -n "$GITIGNORE_RULES_MISSING" ]]; then
    echo "  .gitignore rules missing:"
    while IFS= read -r rule; do
      [[ -z "$rule" ]] && continue
      echo "    - $rule"
    done <<< "$GITIGNORE_RULES_MISSING"
  else
    echo "  .gitignore: all rules present"
  fi
  echo ""
  echo "  Child repos discovered: ${CHILD_COUNT}"
  if [[ -n "$CHILD_REPO_NAMES" ]]; then
    while IFS= read -r repo_name; do
      [[ -z "$repo_name" ]] && continue
      echo "    - $repo_name"
    done <<< "$CHILD_REPO_NAMES"
  fi
fi
