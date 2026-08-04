#!/usr/bin/env bash
set -euo pipefail

# workspace.sh — Multi-repo workspace coordinator for shared team context.
#
# Modes:
#   (default)  Discover child repos at depth 1, show summary.
#   --link     Register child repos as Git submodules.
#   --status   Detailed audit: branch, dirty, unpushed, SHA drift, .adlc presence.
#   --dry-run  Preview (combine with --link).
#   --force    Convert repos already tracked in parent index (combine with --link).
#   --json     Emit JSON on stdout.

JSON_MODE=false
LINK_MODE=false
STATUS_MODE=false
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       JSON_MODE=true;  shift ;;
    --link)       LINK_MODE=true;  shift ;;
    --status)     STATUS_MODE=true; shift ;;
    --dry-run)    DRY_RUN=true;    shift ;;
    --force)      FORCE=true;      shift ;;
    *)            shift ;;
  esac
done

# --- helpers -----------------------------------------------------------------

get_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

has_git() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

is_submodule() {
  local path="$1"
  git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | grep -q "^[^ ]* $path$"
}

is_tracked_in_parent() {
  git ls-files --error-unmatch "$1" >/dev/null 2>&1
}

get_remote_url() {
  git -C "$1" remote get-url origin 2>/dev/null || echo ""
}

# Directories that are never considered child repos.
# NOTE: .specify is intentionally NOT excluded — it may be a legit child repo.
EXCLUDE_DIRS=(node_modules .venv vvenv dist build target .idea .vscode .git .cache)

is_excluded() {
  local name="$1"
  for ex in "${EXCLUDE_DIRS[@]}"; do
    [[ "$name" == "$ex" ]] && return 0
  done
  return 1
}

discover_child_repos() {
  local root="$1"
  local discovered=()
  for dir in "$root"/*/; do
    [[ -d "$dir" ]] || continue
    local base
    base=$(basename "$dir")
    is_excluded "$base" && continue
    if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
      discovered+=("$base")
    fi
  done
  printf '%s\n' "${discovered[@]}"
}

count_unpushed() {
  local repo_path="$1"
  local branch
  branch=$(git -C "$repo_path" branch --show-current 2>/dev/null || echo "")
  if [[ -z "$branch" ]]; then
    echo 0
    return
  fi
  local count
  count=$(git -C "$repo_path" log --oneline "origin/${branch}..HEAD" 2>/dev/null | wc -l)
  echo "$count"
}

parent_sha_for() {
  local name="$1"
  git ls-tree HEAD "$name" 2>/dev/null | awk '{print $3}'
}

child_head_sha() {
  git -C "$1" rev-parse HEAD 2>/dev/null || echo ""
}

# --- pre-flight --------------------------------------------------------------

if ! has_git; then
  if $JSON_MODE; then
    echo '{"error": "Not a git repository. Workspace must be initialized with git."}'
  else
    echo "Error: Not a git repository. Workspace must be initialized with git." >&2
  fi
  exit 1
fi

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

PARENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
PARENT_HAS_ADLC=false
[[ -d "$REPO_ROOT/.adlc" ]] && PARENT_HAS_ADLC=true

# Determine mode
if   $STATUS_MODE; then MODE="status"
elif $LINK_MODE;   then MODE="link"
else                    MODE="discover"
fi

# Discover children early (needed for safety check on --link)
CHILD_REPOS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && CHILD_REPOS+=("$line")
done < <(discover_child_repos "$REPO_ROOT")

# --- safety check for --link -------------------------------------------------

if $LINK_MODE; then
  CHILD_PATTERN=""
  for repo in "${CHILD_REPOS[@]:-}"; do
    if [[ -z "$CHILD_PATTERN" ]]; then
      CHILD_PATTERN="^${repo}(/|$)"
    else
      CHILD_PATTERN="${CHILD_PATTERN}|^${repo}(/|$)"
    fi
  done

  has_uncommitted=false
  non_child_changes=""

  if ! git diff --quiet --cached 2>/dev/null; then
    if $FORCE; then
      non_child_changes=$(git diff --cached --name-only 2>/dev/null | grep -Ev "($CHILD_PATTERN)" || true)
    else
      non_child_changes=$(git diff --cached --name-only 2>/dev/null)
    fi
    [[ -n "$non_child_changes" ]] && has_uncommitted=true
  fi

  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    if $FORCE; then
      non_child_unstaged=$(git diff --name-only 2>/dev/null | grep -Ev "($CHILD_PATTERN)" || true)
    else
      non_child_unstaged=$(git diff --name-only 2>/dev/null)
    fi
    if [[ -n "$non_child_unstaged" ]]; then
      has_uncommitted=true
      if [[ -z "$non_child_changes" ]]; then
        non_child_changes="$non_child_unstaged"
      else
        non_child_changes="${non_child_changes}
${non_child_unstaged}"
      fi
    fi
  fi

  if [[ "$has_uncommitted" == true ]]; then
    if $JSON_MODE; then
      echo '{"error": "Parent repository has uncommitted changes outside child repos. Commit or stash before running --link."}'
    else
      echo "ERROR: Parent repository has uncommitted changes outside child repos." >&2
      echo "Commit or stash these changes before running --link:" >&2
      echo "" >&2
      echo "$non_child_changes" | head -20 >&2
    fi
    exit 1
  fi
fi

# --- build repo records ------------------------------------------------------

declare -a REPO_RECORDS=()
declare -a DISPLAY_NAME=()
declare -a DISPLAY_BRANCH=()
declare -a DISPLAY_DIRTY=()
declare -a DISPLAY_SUBMOD=()
declare -a DISPLAY_DRIFT=()
declare -a REGISTERED=()
declare -a SKIPPED=()
declare -a ERRORS=()

for repo_name in "${CHILD_REPOS[@]:-}"; do
  [[ -z "$repo_name" ]] && continue
  repo_path="$REPO_ROOT/$repo_name"

  remote=$(get_remote_url "$repo_path")
  branch=$(git -C "$repo_path" branch --show-current 2>/dev/null || echo "")
  dirty=false
  git -C "$repo_path" diff --quiet HEAD -- >/dev/null 2>&1 || dirty=true
  unpushed=$(count_unpushed "$repo_path")
  if is_submodule "$repo_name"; then submod=true; else submod=false; fi
  p_sha=$(parent_sha_for "$repo_name")
  c_sha=$(child_head_sha "$repo_path")
  drift=false
  if [[ -n "$p_sha" && -n "$c_sha" && "$p_sha" != "$c_sha" ]]; then
    drift=true
  fi
  has_adlc=false
  [[ -d "$repo_path/.adlc" ]] && has_adlc=true

  # Escape for JSON
  esc_remote=${remote//\"/\\\"}
  esc_path=${repo_path//\"/\\\"}

  record=$(cat <<EOF
{"name":"${repo_name}","path":"${esc_path}","remote":"${esc_remote}","branch":"${branch}","dirty":${dirty},"unpushed":${unpushed},"is_submodule":${submod},"parent_sha":"${p_sha}","child_sha":"${c_sha}","sha_drift":${drift},"has_adlc":${has_adlc}}
EOF
)
  REPO_RECORDS+=("$record")
  DISPLAY_NAME+=("$repo_name")
  DISPLAY_BRANCH+=("$branch")
  DISPLAY_DIRTY+=("$dirty")
  DISPLAY_SUBMOD+=("$submod")
  DISPLAY_DRIFT+=("$drift")

  # link-mode actions
  if $LINK_MODE; then
    if [[ "$submod" == true ]]; then
      SKIPPED+=("${repo_name}: already a submodule")
      continue
    fi
    if [[ -z "$remote" ]]; then
      ERRORS+=("${repo_name}: no remote URL configured")
      continue
    fi
    if is_tracked_in_parent "$repo_name"; then
      if ! $FORCE; then
        ERRORS+=("${repo_name}: tracked in parent index (use --force)")
        continue
      fi
      if [[ "$DRY_RUN" == false ]]; then
        git rm --cached "$repo_name" >/dev/null 2>&1 || true
      fi
    fi
    if $DRY_RUN; then
      REGISTERED+=("${repo_name} -> ${remote} [DRY RUN]")
    else
      if git submodule add "$remote" "$repo_name" 2>/dev/null; then
        REGISTERED+=("${repo_name} -> ${remote}")
      else
        ERRORS+=("${repo_name}: failed to add submodule")
      fi
    fi
  fi
done

# commit after link
if $LINK_MODE && [[ "$DRY_RUN" == false ]] && [[ ${#REGISTERED[@]} -gt 0 ]]; then
  if [[ -f ".gitmodules" ]]; then
    git add .gitmodules 2>/dev/null || true
    git commit -m "[workspace] Register child repos as submodules" 2>/dev/null || true
  fi
fi

# --- output ------------------------------------------------------------------

if $JSON_MODE; then
  repos_json="["
  first=1
  for rec in "${REPO_RECORDS[@]:-}"; do
    [[ -z "$rec" ]] && continue
    [[ $first -eq 0 ]] && repos_json+=","
    repos_json+="$rec"
    first=0
  done
  repos_json+="]"

  errors_json="["
  first=1
  for e in "${ERRORS[@]:-}"; do
    [[ -z "$e" ]] && continue
    [[ $first -eq 0 ]] && errors_json+=","
    errors_json+=$(printf '"%s"' "${e//\"/\\\"}")
    first=0
  done
  errors_json+="]"

  cat <<EOF
{
  "PARENT_REPO": "${REPO_ROOT//\"/\\\"}",
  "PARENT_BRANCH": "${PARENT_BRANCH}",
  "PARENT_HAS_ADLC": ${PARENT_HAS_ADLC},
  "MODE": "${MODE}",
  "DRY_RUN": ${DRY_RUN},
  "DISCOVERED_COUNT": ${#CHILD_REPOS[@]},
  "REGISTERED_COUNT": ${#REGISTERED[@]},
  "SKIPPED_COUNT": ${#SKIPPED[@]},
  "ERROR_COUNT": ${#ERRORS[@]},
  "REPOS": ${repos_json},
  "ERRORS": ${errors_json}
}
EOF
else
  echo "=========================================="
  case "$MODE" in
    link)    echo "Workspace Link (Submodule Setup)" ;;
    status)  echo "Workspace Status" ;;
    *)       echo "Workspace Discovery" ;;
  esac
  echo "=========================================="
  echo "Parent: $REPO_ROOT"
  echo "Branch: $PARENT_BRANCH"
  echo "Has .adlc: $PARENT_HAS_ADLC"
  echo ""

  if [[ ${#CHILD_REPOS[@]} -eq 0 ]]; then
    echo "No child repositories found at depth 1."
    exit 0
  fi

  echo "Discovered (${#CHILD_REPOS[@]}):"
  for i in "${!DISPLAY_NAME[@]}"; do
    marker=" "
    [[ "${DISPLAY_SUBMOD[$i]}" == "true" ]] && marker="*"
    status="clean"
    [[ "${DISPLAY_DIRTY[$i]}" == "true" ]] && status="dirty"
    [[ "${DISPLAY_DRIFT[$i]}" == "true" ]] && status="${status}+drift"
    echo "  ${marker} ${DISPLAY_NAME[$i]} [${DISPLAY_BRANCH[$i]}] ${status}"
  done
  echo ""
  echo "Legend:  * = submodule registered,  +drift = parent SHA != child HEAD"

  if $LINK_MODE; then
    echo ""
    if [[ ${#REGISTERED[@]} -gt 0 ]]; then
      echo "Registered (${#REGISTERED[@]}):"
      for r in "${REGISTERED[@]}"; do echo "  + $r"; done
    fi
    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
      echo "Skipped (${#SKIPPED[@]}):"
      for r in "${SKIPPED[@]}"; do echo "  - $r"; done
    fi
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
      echo "Errors (${#ERRORS[@]}):"
      for r in "${ERRORS[@]}"; do echo "  ! $r"; done
    fi
    if [[ "$DRY_RUN" == false ]] && [[ ${#REGISTERED[@]} -gt 0 ]]; then
      echo ""
      echo "Next steps:"
      echo "  - Team members can clone with: git clone --recursive <workspace-url>"
      echo "  - Or initialize submodules: git submodule update --init"
    fi
  fi
fi
