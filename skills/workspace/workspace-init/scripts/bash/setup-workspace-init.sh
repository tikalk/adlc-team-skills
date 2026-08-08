#!/usr/bin/env bash
# setup-workspace-init.sh — Setup for workspace-init (self-contained)
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

###############################################################################
# .adlc/ directory structure
###############################################################################

ADLC_SUBDIRS=(
  "product"
  "architecture"
  "context"
  "skills"
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

# Rules that should be in .gitignore for workspace conventions
GITIGNORE_RULES=(
  ".adlc/"
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
  ".mcp.json"
)

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
ADLC_DIR="${PROJECT_ROOT}/.adlc"
GITIGNORE_EXISTS=false
[[ -f "${PROJECT_ROOT}/.gitignore" ]] && GITIGNORE_EXISTS=true

# Create .adlc/ structure
ADLC_DIRS_CREATED=$(create_adlc_structure "$ADLC_DIR")

# Check .gitignore rules
GITIGNORE_RULES_MISSING=$(check_gitignore_rules)

# Discover child repos
CHILD_REPO_NAMES=$(discover_child_repos "$PROJECT_ROOT")

# Build child repo JSON array
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

    esc_remote=${remote//\"/\\\"}
    esc_path=${repo_path//\"/\\\"}

    if [[ "$first" == "true" ]]; then
      first=false
    else
      CHILD_REPOS_JSON+=","
    fi
    CHILD_REPOS_JSON+="{\"name\":\"${repo_name}\",\"path\":\"${esc_path}\",\"remote\":\"${esc_remote}\",\"is_submodule\":${submod},\"is_tracked\":${tracked}}"
    CHILD_COUNT=$((CHILD_COUNT + 1))
  done <<< "$CHILD_REPO_NAMES"
fi
CHILD_REPOS_JSON+="]"

# Build ADLC_DIRS_CREATED JSON array
ADLC_CREATED_JSON="["
first=true
if [[ -n "$ADLC_DIRS_CREATED" ]]; then
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    if [[ "$first" == "true" ]]; then
      first=false
    else
      ADLC_CREATED_JSON+=","
    fi
    ADLC_CREATED_JSON+=$(printf '"%s"' "$dir")
  done <<< "$ADLC_DIRS_CREATED"
fi
ADLC_CREATED_JSON+="]"

# Build GITIGNORE_RULES_MISSING JSON array
GITIGNORE_MISSING_JSON="["
first=true
if [[ -n "$GITIGNORE_RULES_MISSING" ]]; then
  while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    if [[ "$first" == "true" ]]; then
      first=false
    else
      GITIGNORE_MISSING_JSON+=","
    fi
    GITIGNORE_MISSING_JSON+=$(printf '"%s"' "$rule")
  done <<< "$GITIGNORE_RULES_MISSING"
fi
GITIGNORE_MISSING_JSON+="]"

if $JSON_MODE; then
  cat <<EOF
{
  "REPO_ROOT": "${PROJECT_ROOT}",
  "ADLC_DIR": "${ADLC_DIR}",
  "ADLC_DIRS_CREATED": ${ADLC_CREATED_JSON},
  "GITIGNORE_EXISTS": ${GITIGNORE_EXISTS},
  "GITIGNORE_RULES_MISSING": ${GITIGNORE_MISSING_JSON},
  "CHILD_REPOS": ${CHILD_REPOS_JSON},
  "CHILD_COUNT": ${CHILD_COUNT},
  "BRANCH": "${BRANCH}"
}
EOF
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
