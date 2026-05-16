#!/usr/bin/env bash

set -e

# Parse command line arguments
JSON_MODE=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --json) 
            JSON_MODE=true 
            ;;
        --help|-h) 
            echo "Usage: $0 [--json]"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            exit 0 
            ;;
        *) 
            ARGS+=("$arg") 
            ;;
    esac
done

# Get script directory and load common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get all paths and variables from common functions
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output

# If feature.json pins an existing feature directory, branch naming is not required.
if ! feature_json_matches_feature_dir "$REPO_ROOT" "$FEATURE_DIR"; then
    check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1
fi

# Ensure the feature directory exists
mkdir -p "$FEATURE_DIR"

# Select plan template
TEMPLATE=$(resolve_template "plan-template" "$REPO_ROOT")

if [[ -n "$TEMPLATE" && -f "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$IMPL_PLAN"
    echo "Copied plan template to $IMPL_PLAN"
else
    echo "Warning: Plan template not found at $TEMPLATE"
    # Create a basic plan file if template doesn't exist
    touch "$IMPL_PLAN"
fi

# Resolve constitution path
CONSTITUTION_FILE="${SPECIFY_CONSTITUTION:-}"
if [[ -z "$CONSTITUTION_FILE" ]]; then
    CONSTITUTION_FILE="$REPO_ROOT/.specify/memory/constitution.md"
fi
if [[ -f "$CONSTITUTION_FILE" ]]; then
    export SPECIFY_CONSTITUTION="$CONSTITUTION_FILE"
else
    CONSTITUTION_FILE=""
fi

# Output results
if $JSON_MODE; then
    if has_jq; then
        jq -cn \
            --arg feature_spec "$FEATURE_SPEC" \
            --arg impl_plan "$IMPL_PLAN" \
            --arg specs_dir "$FEATURE_DIR" \
            --arg branch "$CURRENT_BRANCH" \
            --arg has_git "$HAS_GIT" \
            --arg constitution "$CONSTITUTION_FILE" \
            '{FEATURE_SPEC:$feature_spec,IMPL_PLAN:$impl_plan,SPECS_DIR:$specs_dir,BRANCH:$branch,HAS_GIT:$has_git,CONSTITUTION:$constitution}'
    else
        printf '{"FEATURE_SPEC":"%s","IMPL_PLAN":"%s","SPECS_DIR":"%s","BRANCH":"%s","HAS_GIT":"%s","CONSTITUTION":"%s"}\n' \
            "$(json_escape "$FEATURE_SPEC")" "$(json_escape "$IMPL_PLAN")" "$(json_escape "$FEATURE_DIR")" "$(json_escape "$CURRENT_BRANCH")" "$(json_escape "$HAS_GIT")" "$(json_escape "$CONSTITUTION_FILE")"
    fi
else
    echo "FEATURE_SPEC: $FEATURE_SPEC"
    echo "IMPL_PLAN: $IMPL_PLAN"
    echo "SPECS_DIR: $FEATURE_DIR"
    echo "BRANCH: $CURRENT_BRANCH"
    echo "HAS_GIT: $HAS_GIT"
    if [[ -n "$CONSTITUTION_FILE" ]]; then
        echo "CONSTITUTION: $CONSTITUTION_FILE"
    else
        echo "CONSTITUTION: (missing)"
    fi
fi



