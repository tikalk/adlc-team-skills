#!/usr/bin/env bash

# Context analysis helper for LevelUp extension
# Scans codebase for patterns that could become team-ai-directives contributions

set -e

JSON_MODE=false
FOCUS=""
HEURISTIC="surprising"

# Get script directory for common.sh sourcing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find project root by walking up from script location
_find_project_root() {
    local dir="$SCRIPT_DIR"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.specify" ] || [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT="$(_find_project_root)" || PROJECT_ROOT="$SCRIPT_DIR"

# Load common functions - use absolute path from project root
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.specify/scripts/bash/common.sh" ]]; then
    source "$PROJECT_ROOT/.specify/scripts/bash/common.sh"
elif [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
fi

# Get repository root using common.sh function (searches upward for .specify first)
REPO_ROOT=$(get_repo_root 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || pwd)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --focus)
            FOCUS="$2"
            shift 2
            ;;
        --heuristic)
            HEURISTIC="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json              Output results in JSON format"
            echo "  --focus TYPE        Focus on specific context type (rules|personas|examples|constitution|skills)"
            echo "  --heuristic TYPE    Discovery heuristic (surprising|all|minimal)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Get repository root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Detect technology stack
detect_technologies() {
    local techs=()
    
    # Python
    [[ -f "$REPO_ROOT/requirements.txt" || -f "$REPO_ROOT/pyproject.toml" || -f "$REPO_ROOT/setup.py" ]] && techs+=("python")
    
    # Node.js/JavaScript
    [[ -f "$REPO_ROOT/package.json" ]] && techs+=("nodejs")
    
    # TypeScript
    [[ -f "$REPO_ROOT/tsconfig.json" ]] && techs+=("typescript")
    
    # Go
    [[ -f "$REPO_ROOT/go.mod" ]] && techs+=("go")
    
    # Java
    [[ -f "$REPO_ROOT/pom.xml" || -f "$REPO_ROOT/build.gradle" ]] && techs+=("java")
    
    # Rust
    [[ -f "$REPO_ROOT/Cargo.toml" ]] && techs+=("rust")
    
    # Docker
    [[ -f "$REPO_ROOT/Dockerfile" || -f "$REPO_ROOT/docker-compose.yml" ]] && techs+=("docker")
    
    # Kubernetes
    [[ -d "$REPO_ROOT/k8s" || -d "$REPO_ROOT/kubernetes" || -d "$REPO_ROOT/charts" ]] && techs+=("kubernetes")
    
    # Terraform
    [[ -d "$REPO_ROOT/terraform" ]] && techs+=("terraform")
    
    # GitHub Actions
    [[ -d "$REPO_ROOT/.github/workflows" ]] && techs+=("github-actions")
    
    echo "${techs[@]}"
}

# Count files matching pattern
count_files() {
    local pattern="$1"
    find "$REPO_ROOT" -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Scan for Python patterns
scan_python_patterns() {
    local patterns=()
    
    # Custom exceptions
    if grep -r "class.*Exception" "$REPO_ROOT" --include="*.py" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("error-handling")
    fi
    
    # Pytest fixtures
    if grep -r "@pytest.fixture" "$REPO_ROOT" --include="*.py" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("testing-fixtures")
    fi
    
    # Pydantic models
    if grep -r "from pydantic" "$REPO_ROOT" --include="*.py" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("validation-models")
    fi
    
    # Logging setup
    if grep -r "logging.getLogger" "$REPO_ROOT" --include="*.py" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("logging-patterns")
    fi
    
    echo "${patterns[@]}"
}

# Scan for JavaScript/TypeScript patterns
scan_js_patterns() {
    local patterns=()
    
    # React hooks
    if grep -r "use[A-Z]" "$REPO_ROOT" --include="*.tsx" --include="*.jsx" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("react-hooks")
    fi
    
    # Error boundaries
    if grep -r "componentDidCatch\|ErrorBoundary" "$REPO_ROOT" --include="*.tsx" --include="*.jsx" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("error-boundaries")
    fi
    
    # Jest tests
    if grep -r "describe\|it\|test" "$REPO_ROOT" --include="*.test.ts" --include="*.spec.ts" -l 2>/dev/null | head -1 > /dev/null; then
        patterns+=("testing-patterns")
    fi
    
    echo "${patterns[@]}"
}

# Scan for infrastructure patterns
scan_infra_patterns() {
    local patterns=()
    
    # CI/CD workflows
    if [[ -d "$REPO_ROOT/.github/workflows" ]]; then
        patterns+=("ci-cd-workflows")
    fi
    
    # Docker multi-stage builds
    if grep -r "FROM.*AS" "$REPO_ROOT" --include="Dockerfile*" 2>/dev/null | head -1 > /dev/null; then
        patterns+=("docker-multistage")
    fi
    
    # Helm charts
    if [[ -d "$REPO_ROOT/charts" ]]; then
        patterns+=("helm-charts")
    fi
    
    # Terraform modules
    if [[ -d "$REPO_ROOT/terraform/modules" ]]; then
        patterns+=("terraform-modules")
    fi
    
    echo "${patterns[@]}"
}

# Main analysis
TECHNOLOGIES=$(detect_technologies)
PYTHON_PATTERNS=""
JS_PATTERNS=""
INFRA_PATTERNS=""

# Scan based on detected technologies
for tech in $TECHNOLOGIES; do
    case "$tech" in
        python)
            PYTHON_PATTERNS=$(scan_python_patterns)
            ;;
        nodejs|typescript)
            JS_PATTERNS=$(scan_js_patterns)
            ;;
        docker|kubernetes|github-actions|terraform)
            INFRA_PATTERNS=$(scan_infra_patterns)
            ;;
    esac
done

# Count files
PYTHON_FILES=$(count_files "*.py")
JS_FILES=$(count_files "*.js")
TS_FILES=$(count_files "*.ts")
TEST_FILES=$(find "$REPO_ROOT" -name "*test*" -o -name "*spec*" -type f 2>/dev/null | wc -l | tr -d ' ')

# Output results
if $JSON_MODE; then
    cat << EOF
{
  "repo_root": "$REPO_ROOT",
  "technologies": "$(echo $TECHNOLOGIES | tr ' ' ',')",
  "heuristic": "$HEURISTIC",
  "focus": "$FOCUS",
  "file_counts": {
    "python": $PYTHON_FILES,
    "javascript": $JS_FILES,
    "typescript": $TS_FILES,
    "tests": $TEST_FILES
  },
  "patterns": {
    "python": "$(echo $PYTHON_PATTERNS | tr ' ' ',')",
    "javascript": "$(echo $JS_PATTERNS | tr ' ' ',')",
    "infrastructure": "$(echo $INFRA_PATTERNS | tr ' ' ',')"
  }
}
EOF
else
    echo "=== LevelUp Context Analysis ==="
    echo ""
    echo "Repository: $REPO_ROOT"
    echo "Heuristic: $HEURISTIC"
    [[ -n "$FOCUS" ]] && echo "Focus: $FOCUS"
    echo ""
    echo "=== Detected Technologies ==="
    for tech in $TECHNOLOGIES; do
        echo "  - $tech"
    done
    echo ""
    echo "=== File Counts ==="
    echo "  Python files: $PYTHON_FILES"
    echo "  JavaScript files: $JS_FILES"
    echo "  TypeScript files: $TS_FILES"
    echo "  Test files: $TEST_FILES"
    echo ""
    echo "=== Detected Patterns ==="
    [[ -n "$PYTHON_PATTERNS" ]] && echo "  Python: $PYTHON_PATTERNS"
    [[ -n "$JS_PATTERNS" ]] && echo "  JavaScript: $JS_PATTERNS"
    [[ -n "$INFRA_PATTERNS" ]] && echo "  Infrastructure: $INFRA_PATTERNS"
    echo ""
    echo "=== Potential CDRs ==="
    echo "  Run /levelup.init to generate CDRs from these patterns"
fi
