#!/usr/bin/env bash

set -e

JSON_MODE=false
DRY_RUN=false
CHECK_ONLY=false

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
    --check)
      CHECK_ONLY=true
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
    echo '{"error": "Not a git repository."}'
  else
    echo "Error: Not a git repository." >&2
  fi
  exit 1
fi

# Arrays to track rules
IGNORE_RULES=(
  ".specify/extensions/.cache/"
  ".specify/extensions/.backup/"
  ".specify/extensions/*/*.local.yml"
  ".specify/extensions/.registry"
)

NEGATION_RULES=(
  "!.specify/"
  "!.specify/templates/"
  "!.specify/scripts/"
  "!.specify/memory/"
  "!.opencode/"
  "!.claude/"
  "!.cursor/"
  "!.windsurf/"
)

declare -a ADDED_IGNORE=()
declare -a ADDED_NEGATIONS=()
declare -a VERIFIED_IGNORE=()
declare -a VERIFIED_NEGATIONS=()

# Ensure .gitignore exists
ensure_gitignore() {
  if [[ ! -f ".gitignore" ]]; then
    if [[ "$DRY_RUN" == false && "$CHECK_ONLY" == false ]]; then
      touch .gitignore
    fi
    return 0
  fi
}

# Check if rule exists in .gitignore
rule_exists() {
  local rule="$1"
  # Escape special regex characters for grep
  local escaped_rule=$(echo "$rule" | sed 's/[]\/$*.^|[]/\\&/g')
  grep -qx "$escaped_rule" .gitignore 2>/dev/null
}

# Process rules
process_rules() {
  for rule in "${IGNORE_RULES[@]}"; do
    if rule_exists "$rule"; then
      VERIFIED_IGNORE+=("$rule")
    else
      if [[ "$CHECK_ONLY" == false && "$DRY_RUN" == false ]]; then
        echo "$rule" >> .gitignore
        ADDED_IGNORE+=("$rule")
      elif [[ "$DRY_RUN" == true ]]; then
        ADDED_IGNORE+=("$rule")
      fi
    fi
  done

  for rule in "${NEGATION_RULES[@]}"; do
    if rule_exists "$rule"; then
      VERIFIED_NEGATIONS+=("$rule")
    else
      if [[ "$CHECK_ONLY" == false && "$DRY_RUN" == false ]]; then
        echo "$rule" >> .gitignore
        ADDED_NEGATIONS+=("$rule")
      elif [[ "$DRY_RUN" == true ]]; then
        ADDED_NEGATIONS+=("$rule")
      fi
    fi
  done
}

# Main execution
ensure_gitignore
process_rules

# Commit changes if not dry run and rules were added
if [[ "$DRY_RUN" == false && "$CHECK_ONLY" == false ]]; then
  if [[ ${#ADDED_IGNORE[@]} -gt 0 || ${#ADDED_NEGATIONS[@]} -gt 0 ]]; then
    git add .gitignore 2>/dev/null || true
    git commit -m "[Spec Kit] Configure .gitignore for spec-kit directories" 2>/dev/null || true
  fi
fi

# Output results
if $JSON_MODE; then
  # Build JSON arrays
  build_json_array() {
    local arr=($@)
    local json="["
    local first=1
    for item in "${arr[@]}"; do
      [[ $first -eq 0 ]] && json+=","
      json+=$(printf '"%s"' "$item")
      first=0
    done
    json+="]"
    echo "$json"
  }

  cat <<EOF
{
  "ADDED_IGNORE": $(build_json_array "${ADDED_IGNORE[@]}"),
  "ADDED_NEGATIONS": $(build_json_array "${ADDED_NEGATIONS[@]}"),
  "VERIFIED_IGNORE": $(build_json_array "${VERIFIED_IGNORE[@]}"),
  "VERIFIED_NEGATIONS": $(build_json_array "${VERIFIED_NEGATIONS[@]}"),
  "DRY_RUN": $([[ "$DRY_RUN" == true ]] && echo "true" || echo "false"),
  "CHECK_ONLY": $([[ "$CHECK_ONLY" == true ]] && echo "true" || echo "false")
}
EOF
else
  # Text output
  if [[ "$DRY_RUN" == true ]]; then
    echo "=========================================="
    echo "Spec Kit .gitignore Setup (DRY RUN)"
    echo "=========================================="
    echo ""
    
    if [[ ${#ADDED_IGNORE[@]} -gt 0 ]]; then
      echo "Would add ignore rules (${#ADDED_IGNORE[@]}):"
      for rule in "${ADDED_IGNORE[@]}"; do
        echo "  → $rule"
      done
      echo ""
    fi
    
    if [[ ${#ADDED_NEGATIONS[@]} -gt 0 ]]; then
      echo "Would add negation rules (${#ADDED_NEGATIONS[@]}):"
      for rule in "${ADDED_NEGATIONS[@]}"; do
        echo "  → $rule"
      done
      echo ""
    fi
    
    if [[ ${#ADDED_IGNORE[@]} -eq 0 && ${#ADDED_NEGATIONS[@]} -eq 0 ]]; then
      echo "All rules already configured"
      echo ""
    fi
  elif [[ "$CHECK_ONLY" == true ]]; then
    echo "=========================================="
    echo "Spec Kit .gitignore Setup (CHECK ONLY)"
    echo "=========================================="
    echo ""
    
    if [[ ${#VERIFIED_IGNORE[@]} -eq ${#IGNORE_RULES[@]} && ${#VERIFIED_NEGATIONS[@]} -eq ${#NEGATION_RULES[@]} ]]; then
      echo "All rules already configured ✓"
      echo ""
    else
      echo "Missing rules (${#ADDED_IGNORE[@]} ignore, ${#ADDED_NEGATIONS[@]} negations)"
      echo ""
    fi
    
    echo "Verified ignore rules (${#VERIFIED_IGNORE[@]}):"
    for rule in "${VERIFIED_IGNORE[@]}"; do
      echo "  ✓ $rule"
    done
    echo ""
    
    echo "Verified negation rules (${#VERIFIED_NEGATIONS[@]}):"
    for rule in "${VERIFIED_NEGATIONS[@]}"; do
      echo "  ✓ $rule"
    done
    echo ""
  else
    echo "=========================================="
    echo "Spec Kit .gitignore Setup"
    echo "=========================================="
    echo ""
    
    if [[ ${#ADDED_IGNORE[@]} -gt 0 || ${#ADDED_NEGATIONS[@]} -gt 0 ]]; then
      if [[ ${#ADDED_IGNORE[@]} -gt 0 ]]; then
        echo "Rules added (${#ADDED_IGNORE[@]}):"
        for rule in "${ADDED_IGNORE[@]}"; do
          echo "  ✓ $rule"
        done
        echo ""
      fi
      
      if [[ ${#ADDED_NEGATIONS[@]} -gt 0 ]]; then
        echo "Negation rules added (${#ADDED_NEGATIONS[@]}):"
        for rule in "${ADDED_NEGATIONS[@]}"; do
          echo "  ✓ $rule"
        done
        echo ""
      fi
      
      echo "Changes committed:"
      echo "  [Spec Kit] Configure .gitignore for spec-kit directories"
    else
      echo "All rules already configured ✓"
      echo ""
      echo "Verified rules (${#VERIFIED_IGNORE[@]} ignore, ${#VERIFIED_NEGATIONS[@]} negations)"
    fi
    echo ""
  fi
fi

exit 0