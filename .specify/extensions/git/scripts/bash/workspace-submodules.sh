#!/usr/bin/env bash

set -e

JSON_MODE=false
DRY_RUN=false
FORCE=false
IGNORE_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_MODE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --ignore-only)
      IGNORE_ONLY=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/git-common.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Check if this is a git repo
if ! has_git; then
  if $JSON_MODE; then
    echo '{"error": "Not a git repository. Workspace must be initialized with git."}'
  else
    echo "Error: Not a git repository. Workspace must be initialized with git." >&2
  fi
  exit 1
fi

# Setup spec-kit .gitignore rules first
if [[ "$DRY_RUN" == false ]]; then
  setup_spec_kit_gitignore >/dev/null 2>&1 || true
fi

# Arrays to track results
declare -a REGISTERED_REPOS=()
declare -a SKIPPED_REPOS=()
declare -a ERROR_REPOS=()
declare -a IGNORED_REPOS=()

# Function to check if a path is already a submodule
is_submodule() {
  local path="$1"
  git config --file .gitmodules --get-regexp "^submodule\\..*\\.path$" 2>/dev/null | grep -q "^[^ ]* $path$"
}

# Function to check if a path is tracked in parent index
is_tracked_in_parent() {
  git ls-files --error-unmatch "$1" >/dev/null 2>&1
}

# Function to ensure .gitignore exists
ensure_gitignore() {
  [[ -f ".gitignore" ]] || touch .gitignore
}

# Function to setup spec-kit .gitignore rules
setup_spec_kit_gitignore() {
  local rules_added=0
  
  # Spec Kit ignore rules
  local ignore_rules=(
    ".specify/extensions/.cache/"
    ".specify/extensions/.backup/"
    ".specify/extensions/*/*.local.yml"
    ".specify/extensions/.registry"
  )
  
  # Spec Kit negation rules
  local negation_rules=(
    "!.specify/"
    "!.specify/templates/"
    "!.specify/scripts/"
    "!.specify/memory/"
    "!.opencode/"
    "!.claude/"
    "!.cursor/"
    "!.windsurf/"
  )
  
  # Ensure .gitignore exists
  [[ -f ".gitignore" ]] || touch .gitignore
  
  # Add ignore rules if missing
  for rule in "${ignore_rules[@]}"; do
    if ! grep -qx "$rule" .gitignore 2>/dev/null; then
      if [[ "$DRY_RUN" == false ]]; then
        echo "$rule" >> .gitignore
        ((rules_added++))
      fi
    fi
  done
  
  # Add negation rules if missing
  for rule in "${negation_rules[@]}"; do
    if ! grep -qx "$rule" .gitignore 2>/dev/null; then
      if [[ "$DRY_RUN" == false ]]; then
        echo "$rule" >> .gitignore
        ((rules_added++))
      fi
    fi
  done
  
  # Commit changes if rules were added
  if [[ "$DRY_RUN" == false && $rules_added -gt 0 ]]; then
    git add .gitignore 2>/dev/null || true
    git commit -m "[Spec Kit] Configure .gitignore for spec-kit directories" 2>/dev/null || true
  fi
}

# Function to get remote URL from a child repo
get_remote_url() {
  local repo_path="$1"
  git -C "$repo_path" remote get-url origin 2>/dev/null || echo ""
}

# Discover child repos at depth 1
discover_child_repos() {
  local discovered=()
  
  for dir in "$REPO_ROOT"/*/; do
    # Skip if not a directory
    [[ -d "$dir" ]] || continue
    
    local basename=$(basename "$dir")
    
    # Skip common non-project directories
    case "$basename" in
      .specify|.git|node_modules|__pycache__|.venv|venv|dist|build|target|.idea|.vscode)
        continue
        ;;
    esac
    
    # Check if it has a .git directory
    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
      discovered+=("$basename")
    fi
  done
  
  echo "${discovered[@]}"
}

# Discover child repos early (needed for safety check)
CHILD_REPOS=$(discover_child_repos)

# Build a pattern of child repo names for exclusion
# Match both with and without trailing slash (git diff returns just the name for directories)
CHILD_PATTERN=""
for repo in $CHILD_REPOS; do
  if [[ -z "$CHILD_PATTERN" ]]; then
    CHILD_PATTERN="^$repo(/|$)"
  else
    CHILD_PATTERN="$CHILD_PATTERN|^$repo(/|$)"
  fi
done

# Safety check: Check for uncommitted changes
# If --force is used, allow child repos to be "dirty" (they'll be converted)
has_uncommitted=false
non_child_changes=""

# Check for staged changes
if ! git diff --quiet --cached 2>/dev/null; then
  # Check if staged changes are only child repos
  if [[ "$FORCE" == true ]]; then
    non_child_changes=$(git diff --cached --name-only 2>/dev/null | grep -Ev "($CHILD_PATTERN)" || true)
  else
    non_child_changes=$(git diff --cached --name-only 2>/dev/null)
  fi
  if [[ -n "$non_child_changes" ]]; then
    has_uncommitted=true
  fi
fi

# Check for unstaged changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  # Check if unstaged changes are only child repos
  if [[ "$FORCE" == true ]]; then
    non_child_changes_unstaged=$(git diff --name-only 2>/dev/null | grep -Ev "($CHILD_PATTERN)" || true)
  else
    non_child_changes_unstaged=$(git diff --name-only 2>/dev/null)
  fi
  if [[ -n "$non_child_changes_unstaged" ]]; then
    has_uncommitted=true
    if [[ -z "$non_child_changes" ]]; then
      non_child_changes="$non_child_changes_unstaged"
    else
      non_child_changes="$non_child_changes
$non_child_changes_unstaged"
    fi
  fi
fi

# If there are non-child changes, abort
if [[ "$has_uncommitted" == true ]]; then
  if $JSON_MODE; then
    echo '{"error": "Parent repository has uncommitted changes outside child repos. Commit or stash before running workspace setup."}'
  else
    echo "ERROR: Parent repository has uncommitted changes outside child repos." >&2
    echo "Commit or stash these changes before running workspace setup:" >&2
    echo "" >&2
    echo "$non_child_changes" | head -20 >&2
    if [[ $(echo "$non_child_changes" | wc -l) -gt 20 ]]; then
      echo "... (and more)" >&2
    fi
  fi
  exit 1
fi

# Main processing
if [[ "$IGNORE_ONLY" == true ]]; then
  # Ignore-only mode: Add to .gitignore and remove from index
  ensure_gitignore
  
  for repo_name in $CHILD_REPOS; do
    # Remove from parent index if tracked
    if is_tracked_in_parent "$repo_name"; then
      if [[ "$DRY_RUN" == false ]]; then
        git rm --cached "$repo_name" >/dev/null 2>&1 || true
      fi
    fi
    
    # Add to .gitignore if not already there
    if ! grep -qx "$repo_name/" .gitignore 2>/dev/null; then
      if [[ "$DRY_RUN" == false ]]; then
        echo "$repo_name/" >> .gitignore
      fi
      IGNORED_REPOS+=("$repo_name")
    else
      SKIPPED_REPOS+=("$repo_name: already in .gitignore")
    fi
  done
  
  # Commit .gitignore changes
  if [[ "$DRY_RUN" == false ]] && [[ ${#IGNORED_REPOS[@]} -gt 0 ]]; then
    git add .gitignore 2>/dev/null || true
    git commit -m "[Spec Kit] Add child repos to .gitignore" 2>/dev/null || true
  fi
else
  # Submodule mode: Register as submodules
  for repo_name in $CHILD_REPOS; do
    repo_path="$REPO_ROOT/$repo_name"
    
    # Check if already a submodule
    if is_submodule "$repo_name"; then
      SKIPPED_REPOS+=("$repo_name: already a submodule")
      continue
    fi
    
    # Check if tracked in parent index
    if is_tracked_in_parent "$repo_name"; then
      # Get remote URL first
      remote_url=$(get_remote_url "$repo_path")
      
      if [[ -z "$remote_url" ]]; then
        ERROR_REPOS+=("$repo_name: no remote URL configured")
        continue
      fi
      
      # Remove from parent index
      if [[ "$DRY_RUN" == false ]]; then
        git rm --cached "$repo_name" >/dev/null 2>&1 || true
      fi
      
      # Register as submodule
      if [[ "$DRY_RUN" == true ]]; then
        REGISTERED_REPOS+=("$repo_name → $remote_url [DRY RUN]")
      else
        if git submodule add "$remote_url" "$repo_name" 2>/dev/null; then
          REGISTERED_REPOS+=("$repo_name → $remote_url")
        else
          ERROR_REPOS+=("$repo_name: failed to add submodule")
        fi
      fi
      continue
    fi
    
    # Get remote URL
    remote_url=$(get_remote_url "$repo_path")
    
    if [[ -z "$remote_url" ]]; then
      ERROR_REPOS+=("$repo_name: no remote URL configured")
      continue
    fi
    
    # Register as submodule
    if [[ "$DRY_RUN" == true ]]; then
      REGISTERED_REPOS+=("$repo_name → $remote_url [DRY RUN]")
    else
      if git submodule add "$remote_url" "$repo_name" 2>/dev/null; then
        REGISTERED_REPOS+=("$repo_name → $remote_url")
      else
        ERROR_REPOS+=("$repo_name: failed to add submodule")
      fi
    fi
  done
  
  # Commit changes if not dry run and we registered repos
  if [[ "$DRY_RUN" == false ]] && [[ ${#REGISTERED_REPOS[@]} -gt 0 ]]; then
    if [[ -f ".gitmodules" ]]; then
      git add .gitmodules 2>/dev/null || true
      # Try to commit, but don't fail if nothing to commit
      git commit -m "[Spec Kit] Register workspace submodules" 2>/dev/null || true
    fi
  fi
fi

# Output results
if $JSON_MODE; then
  # Build JSON arrays
  registered_json="["
  first=1
  for repo in "${REGISTERED_REPOS[@]}"; do
    [[ $first -eq 0 ]] && registered_json+=","
    registered_json+=$(printf '"%s"' "$repo")
    first=0
  done
  registered_json+="]"
  
  skipped_json="["
  first=1
  for repo in "${SKIPPED_REPOS[@]}"; do
    [[ $first -eq 0 ]] && skipped_json+=","
    skipped_json+=$(printf '"%s"' "$repo")
    first=0
  done
  skipped_json+="]"
  
  errors_json="["
  first=1
  for repo in "${ERROR_REPOS[@]}"; do
    [[ $first -eq 0 ]] && errors_json+=","
    errors_json+=$(printf '"%s"' "$repo")
    first=0
  done
  errors_json+="]"
  
  ignored_json="["
  first=1
  for repo in "${IGNORED_REPOS[@]}"; do
    [[ $first -eq 0 ]] && ignored_json+=","
    ignored_json+=$(printf '"%s"' "$repo")
    first=0
  done
  ignored_json+="]"
  
  cat <<EOF
{
  "DISCOVERED_COUNT": $(($(echo "$CHILD_REPOS" | wc -w))),
  "REGISTERED_COUNT": ${#REGISTERED_REPOS[@]},
  "SKIPPED_COUNT": ${#SKIPPED_REPOS[@]},
  "ERROR_COUNT": ${#ERROR_REPOS[@]},
  "IGNORED_COUNT": ${#IGNORED_REPOS[@]},
  "REGISTERED_REPOS": $registered_json,
  "SKIPPED_REPOS": $skipped_json,
  "ERROR_REPOS": $errors_json,
  "IGNORED_REPOS": $ignored_json,
  "MODE": "$([[ "$IGNORE_ONLY" == true ]] && echo "ignore" || echo "submodule")",
  "DRY_RUN": $([[ "$DRY_RUN" == true ]] && echo "true" || echo "false")
}
EOF
else
  # Text output
  echo "=========================================="
  if [[ "$IGNORE_ONLY" == true ]]; then
    echo "Workspace Ignore Setup"
  else
    echo "Workspace Submodule Setup"
  fi
  echo "=========================================="
  echo ""
  
  if [[ ${#REGISTERED_REPOS[@]} -gt 0 ]]; then
    echo "Registered (${#REGISTERED_REPOS[@]}):"
    for repo in "${REGISTERED_REPOS[@]}"; do
      echo "  ✓ $repo"
    done
    echo ""
  fi
  
  if [[ ${#IGNORED_REPOS[@]} -gt 0 ]]; then
    echo "Added to .gitignore (${#IGNORED_REPOS[@]}):"
    for repo in "${IGNORED_REPOS[@]}"; do
      echo "  ✓ $repo"
    done
    echo ""
  fi
  
  if [[ ${#SKIPPED_REPOS[@]} -gt 0 ]]; then
    echo "Skipped (${#SKIPPED_REPOS[@]}):"
    for repo in "${SKIPPED_REPOS[@]}"; do
      echo "  - $repo"
    done
    echo ""
  fi
  
  if [[ ${#ERROR_REPOS[@]} -gt 0 ]]; then
    echo "Errors (${#ERROR_REPOS[@]}):"
    for repo in "${ERROR_REPOS[@]}"; do
      echo "  ⚠ $repo"
    done
    echo ""
  fi
  
  if [[ ${#REGISTERED_REPOS[@]} -eq 0 ]] && [[ ${#IGNORED_REPOS[@]} -eq 0 ]] && [[ ${#SKIPPED_REPOS[@]} -eq 0 ]] && [[ ${#ERROR_REPOS[@]} -eq 0 ]]; then
    echo "No child repositories found at depth 1."
    echo ""
  fi
  
  if [[ "$DRY_RUN" == false ]]; then
    if [[ "$IGNORE_ONLY" == true ]] && [[ ${#IGNORED_REPOS[@]} -gt 0 ]]; then
      echo "Next steps:"
      echo "  - Child repos are now ignored by the parent"
      echo "  - Each child remains an independent git repository"
    elif [[ ${#REGISTERED_REPOS[@]} -gt 0 ]]; then
      echo "Next steps:"
      echo "  - Team members can clone with: git clone --recursive <workspace-url>"
      echo "  - Or initialize submodules: git submodule update --init"
    fi
  fi
fi
