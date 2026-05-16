#!/usr/bin/env bash

# Consolidated prerequisite checking script
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --require-tasks     Require tasks.md to exist (for implementation phase)
#   --include-tasks     Include tasks.md in AVAILABLE_DOCS list
#   --paths-only        Only output path variables (no validation)
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}
#   Text mode: FEATURE_DIR:... \n AVAILABLE_DOCS: \n ✓/✗ file.md
#   Paths only: REPO_ROOT: ... \n BRANCH: ... \n FEATURE_DIR: ... etc.

set -e

# Parse command line arguments
JSON_MODE=false
REQUIRE_TASKS=false
INCLUDE_TASKS=false
PATHS_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --require-tasks)
            REQUIRE_TASKS=true
            ;;
        --include-tasks)
            INCLUDE_TASKS=true
            ;;
        --paths-only)
            PATHS_ONLY=true
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

OPTIONS:
  --json              Output in JSON format
  --require-tasks     Require tasks.md to exist (for implementation phase)
  --include-tasks     Include tasks.md in AVAILABLE_DOCS list
  --paths-only        Only output path variables (no prerequisite validation)
  --help, -h          Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  ./check-prerequisites.sh --json
  
  # Check implementation prerequisites (plan.md required, tasks.md always required)
  ./check-prerequisites.sh --json --require-tasks --include-tasks
  
  # Get feature paths only (no validation)
  ./check-prerequisites.sh --paths-only
  
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$arg'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Extract risk entries from a markdown file's Risk Register section
extract_risks() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "[]"
        return
    fi

    python3 - "$file" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
pattern = re.compile(r"^-\s*RISK:\s*(.+)$", re.IGNORECASE)
risks = []

def normalize_severity(value):
    """Normalize severity/impact to standard levels."""
    if not value:
        return "Medium"
    value = value.lower().strip()
    if value in ["critical", "crit", "high", "hi"]:
        return "Critical" if value.startswith("crit") else "High"
    elif value in ["medium", "med"]:
        return "Medium"
    elif value in ["low", "lo"]:
        return "Low"
    else:
        # Try to map numeric or other values
        return "Medium"

for line in path.read_text().splitlines():
    match = pattern.match(line.strip())
    if not match:
        continue

    parts = [p.strip() for p in match.group(1).split("|") if p.strip()]
    data = {}

    if parts and ":" not in parts[0]:
        data["id"] = parts[0]
        parts = parts[1:]

    for part in parts:
        if ":" not in part:
            continue
        key, value = part.split(":", 1)
        key = key.strip()
        value = value.strip()
        normalized = key.lower().replace(" ", "_")
        if normalized == "risk":
            data["id"] = value
        else:
            data[normalized] = value

    if data:
        if "id" not in data:
            data["id"] = f"missing-id-{len(risks)+1}"
        # Normalize severity from impact or severity field
        severity = data.get("severity") or data.get("impact")
        data["severity"] = normalize_severity(severity)
        risks.append(data)

print(json.dumps(risks, ensure_ascii=False))
PY
}

# Get feature paths and validate branch
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1

# If paths-only mode, output paths and exit (support JSON + paths-only combined)
if $PATHS_ONLY; then
    if $JSON_MODE; then
        # Minimal JSON paths payload (no validation performed)
        if has_jq; then
            jq -cn \
                --arg repo_root "$REPO_ROOT" \
                --arg branch "$CURRENT_BRANCH" \
                --arg feature_dir "$FEATURE_DIR" \
                --arg feature_spec "$FEATURE_SPEC" \
                --arg impl_plan "$IMPL_PLAN" \
                --arg tasks "$TASKS" \
                --arg constitution "$CONSTITUTION" \
                --arg ad "$AD" \
                '{REPO_ROOT:$repo_root,BRANCH:$branch,FEATURE_DIR:$feature_dir,FEATURE_SPEC:$feature_spec,IMPL_PLAN:$impl_plan,TASKS:$tasks,CONSTITUTION:$constitution,AD:$ad}'
        else
            printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s","CONSTITUTION":"%s","AD":"%s"}\n' \
                "$(json_escape "$REPO_ROOT")" "$(json_escape "$CURRENT_BRANCH")" "$(json_escape "$FEATURE_DIR")" "$(json_escape "$FEATURE_SPEC")" "$(json_escape "$IMPL_PLAN")" "$(json_escape "$TASKS")" "$(json_escape "$CONSTITUTION")" "$(json_escape "$AD")"
        fi
    else
        echo "REPO_ROOT: $REPO_ROOT"
        echo "BRANCH: $CURRENT_BRANCH"
        echo "FEATURE_DIR: $FEATURE_DIR"
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
        echo "CONSTITUTION: $CONSTITUTION"
        echo "AD: $AD"
    fi
    exit 0
fi

# Validate required directories and files
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    echo "Run /spec.specify first to create the feature structure." >&2
    exit 1
fi

# Check for plan.md (required)
if [[ ! -f "$IMPL_PLAN" ]]; then
    echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
    echo "Run /spec.plan first to create the implementation plan." >&2
    exit 1
fi

# Check for tasks.md if required
if $REQUIRE_TASKS && [[ ! -f "$TASKS" ]]; then
    echo "ERROR: tasks.md not found in $FEATURE_DIR" >&2
    echo "Run /spec.tasks first to create the task list." >&2
    exit 1
fi

# Build list of available documents
docs=()

# Always check these optional docs
[[ -f "$RESEARCH" ]] && docs+=("research.md")
[[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")

# Check contracts directory (only if it exists and has files)
if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
    docs+=("contracts/")
fi

[[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

# Include tasks.md if requested and it exists
if $INCLUDE_TASKS && [[ -f "$TASKS" ]]; then
    docs+=("tasks.md")
fi

# Output results
if $JSON_MODE; then
    # Build JSON array of documents
    if has_jq; then
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(printf '%s\n' "${docs[@]}" | jq -R . | jq -s .)
        fi
        jq -cn \
            --arg feature_dir "$FEATURE_DIR" \
            --argjson docs "$json_docs" \
            '{FEATURE_DIR:$feature_dir,AVAILABLE_DOCS:$docs}'
    else
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(printf '"%s",' "${docs[@]}")
             json_docs="[${json_docs%,}]"
        fi
        printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s}\n' "$(json_escape "$FEATURE_DIR")" "$json_docs"
    fi

    SPEC_RISKS=$(extract_risks "$FEATURE_SPEC")
    PLAN_RISKS=$(extract_risks "$IMPL_PLAN")

    # Check for constitution and architecture (optional governance documents)
    CONSTITUTION_EXISTS="false"
    AD_EXISTS="false"
    CONSTITUTION_RULES="[]"
    AD_VIEWS="{}"
    AD_DIAGRAMS="[]"

    if [[ -f "$CONSTITUTION" ]]; then
        CONSTITUTION_EXISTS="true"
        CONSTITUTION_RULES=$(extract_constitution_rules "$CONSTITUTION")
    fi

    if [[ -f "$AD" ]]; then
        AD_EXISTS="true"
        AD_VIEWS=$(extract_architecture_views "$AD")
        AD_DIAGRAMS=$(extract_architecture_diagrams "$AD")
    fi

    printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s,"SPEC_RISKS":%s,"PLAN_RISKS":%s,"CONSTITUTION":"%s","CONSTITUTION_EXISTS":%s,"CONSTITUTION_RULES":%s,"AD":"%s","AD_EXISTS":%s,"AD_VIEWS":%s,"AD_DIAGRAMS":%s}\n' \
        "$(json_escape "$FEATURE_DIR")" "$json_docs" "$SPEC_RISKS" "$PLAN_RISKS" \
        "$(json_escape "$CONSTITUTION")" "$CONSTITUTION_EXISTS" "$CONSTITUTION_RULES" \
        "$(json_escape "$AD")" "$AD_EXISTS" "$AD_VIEWS" "$AD_DIAGRAMS"
else
    # Text output
    echo "FEATURE_DIR:$FEATURE_DIR"
    echo "AVAILABLE_DOCS:"
    
    # Show status of each potential document
    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"
    
    if $INCLUDE_TASKS; then
        check_file "$TASKS" "tasks.md"
    fi

    spec_risks_count=$(extract_risks "$FEATURE_SPEC" | python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    data = []
print(len(data))
PY
    )
    plan_risks_count=$(extract_risks "$IMPL_PLAN" | python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    data = []
print(len(data))
PY
    )

    echo "SPEC_RISKS: $spec_risks_count"
    echo "PLAN_RISKS: $plan_risks_count"
    
    # Show governance document status
    echo ""
    echo "GOVERNANCE DOCUMENTS:"
    check_file "$CONSTITUTION" "constitution.md (optional)"
fi
