#!/usr/bin/env bash

set -e

JSON_MODE=false
ACTION=""
ARGS=()
VIEWS="core"
ADR_HEURISTIC="surprising"
DECOMPOSE=true

# Get script directory FIRST (needed for common.sh sourcing)
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
else
    echo "Error: Could not find common.sh" >&2
    exit 1
fi

# Get all paths and variables from common functions
eval "$(get_feature_paths)"

# Parse arguments (run after common.sh to have REPO_ROOT defined)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --views)
            shift
            VIEWS="$1"
            shift
            ;;
        --views=*)
            VIEWS="${1#*=}"
            shift
            ;;
        --adr-heuristic)
            shift
            ADR_HEURISTIC="$1"
            shift
            ;;
        --adr-heuristic=*)
            ADR_HEURISTIC="${1#*=}"
            shift
            ;;
        --no-decompose)
            DECOMPOSE=false
            shift
            ;;
        --no-decompose=*)
            DECOMPOSE=false
            shift
            ;;
        init|map|update|review|specify|implement|clarify|analyze|validate|plan-dag|execute-dag|summarize)
            ACTION="$1"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [action] [context] [--json] [--views VIEWS] [--adr-heuristic HEURISTIC]"
            echo ""
            echo "Actions:"
            echo "  specify    Interactive PRD exploration to create system ADRs (greenfield)"
            echo "  clarify    Refine and resolve ambiguities in existing ADRs"
            echo "  init       Reverse-engineer architecture from existing codebase (brownfield)"
            echo "  implement  Generate full Architecture Description (AD.md) from ADRs"
            echo "  analyze    Validate architecture for consistency and quality issues"
            echo "  validate   Validate plan alignment with architecture (READ-ONLY)"
            echo "  map        (alias for init) Reverse-engineer architecture from existing codebase"
            echo "  update     Update architecture based on code/spec changes"
            echo "  review     Validate architecture against constitution"
            echo ""
            echo "DAG Workflow Actions (used internally by implement):"
            echo "  plan-dag   Phase 1: Generate DAG execution plan for user approval"
            echo "  execute-dag Phase 2: Execute DAG to generate views per sub-system"
            echo "  summarize  Phase 3: Aggregate views into unified AD.md"
            echo ""
            echo "Options:"
            echo "  --json             Output results in JSON format"
            echo "  --views VIEWS      Architecture views to generate: core (default), all, or comma-separated"
            echo "  --adr-heuristic H  ADR generation heuristic: surprising (default), all, minimal"
            echo "  --no-decompose     Disable automatic sub-system decomposition (default: auto-detect)"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 specify \"B2B SaaS for supply chain management\""
            echo "  $0 init --views all \"Django monolith with PostgreSQL\""
            echo "  $0 init --views concurrency,operational \"Microservices architecture\""
            echo "  $0 clarify --adr-heuristic all \"Document all decisions\""
            echo "  $0 implement \"Generate full AD.md from ADRs\""
            echo ""
            echo "Pro Tip: Add context/description after the action for better results."
            echo "The AI will use your input to understand system scope and constraints."
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Default action if not specified
if [[ -z "$ACTION" ]]; then
    if [[ -f "$REPO_ROOT/AD.md" ]]; then
        ACTION="update"
    else
        ACTION="init"
    fi
fi

# Ensure directories exist
mkdir -p "$REPO_ROOT/.specify/memory"
mkdir -p "$REPO_ROOT/.specify/drafts"

# Architecture files (ADR Lifecycle)
AD_FILE="$REPO_ROOT/AD.md"
ADR_DRAFTS_FILE="$REPO_ROOT/.specify/drafts/adr.md"
ADR_MEMORY_FILE="$REPO_ROOT/.specify/memory/adr.md"
ADR_FILE="$REPO_ROOT/.specify/drafts/adr.md"  # Default to drafts
TEMPLATE_FILE="$REPO_ROOT/.specify/templates/architecture-template.md"
AD_TEMPLATE_FILE="$REPO_ROOT/.specify/templates/AD-template.md"

# Export for use in functions
export ARCHITECTURE_VIEWS="$VIEWS"
export ADR_HEURISTIC="$ADR_HEURISTIC"
export DECOMPOSE="$DECOMPOSE"

# Function to detect sub-systems from codebase structure
detect_subsystems() {
    local subsystems=""
    local count=0
    
    echo "Detecting sub-systems from codebase structure..." >&2
    
    # Check for common sub-system patterns
    
    # 1. Top-level feature directories (src/, app/, services/)
    local dirs=()
    if [[ -d "src" ]]; then
        for d in src/*/; do
            if [[ -d "$d" ]]; then
                local dirname
                dirname=$(basename "$d")
                # Skip common non-sub-system directories
                if [[ "$dirname" != "utils" && "$dirname" != "common" && "$dirname" != "lib" && "$dirname" != "shared" && "$dirname" != "core" ]]; then
                    dirs+=("$dirname")
                fi
            fi
        done
    fi
    
    if [[ -d "services" ]]; then
        for d in services/*/; do
            if [[ -d "$d" ]]; then
                local dirname
                dirname=$(basename "$d")
                dirs+=("$dirname")
            fi
        done
    fi
    
    if [[ -d "modules" ]]; then
        for d in modules/*/; do
            if [[ -d "$d" ]]; then
                local dirname
                dirname=$(basename "$d")
                dirs+=("$dirname")
            fi
        done
    fi
    
    if [[ -d "apps" ]]; then
        for d in apps/*/; do
            if [[ -d "$d" ]]; then
                local dirname
                dirname=$(basename "$d")
                dirs+=("$dirname")
            fi
        done
    fi
    
    # 2. Check for docker-compose services (microservices indicator)
    if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        local compose_file="docker-compose.yml"
        [[ -f "docker-compose.yaml" ]] && compose_file="docker-compose.yaml"
        
        local services=()
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
                local svc="${BASH_REMATCH[1]}"
                # Skip common non-service entries
                if [[ "$svc" != "version" && "$svc" != "services" && "$svc" != "networks" && "$svc" != "volumes" ]]; then
                    services+=("$svc")
                fi
            fi
        done < "$compose_file"
        
        for svc in "${services[@]}"; do
            local found=false
            for d in "${dirs[@]}"; do
                if [[ "${d,,}" == *"${svc,,}"* ]] || [[ "${svc,,}" == *"${d,,}"* ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                dirs+=("$svc")
            fi
        done
    fi
    
    # 3. Check for Node.js workspaces (monorepo indicator)
    if [[ -f "package.json" ]]; then
        if grep -q '"workspaces"' package.json 2>/dev/null; then
            local pkgs
            pkgs=$(node -e "try { const p = require('./package.json'); console.log(Object.keys(p.workspaces?.packages || {}).join(' ')); } catch(e) { }" 2>/dev/null || true)
            for pkg in $pkgs; do
                local dirname
                dirname=$(basename "$pkg")
                if [[ "$dirname" != "node_modules" ]]; then
                    dirs+=("$dirname")
                fi
            done
        fi
    fi
    
    # 4. Check for Python namespace packages
    if [[ -f "pyproject.toml" ]]; then
        local pkg_dirs=()
        while IFS= read -r -d '' d; do
            pkg_dirs+=("$(basename "$d")")
        done < <(find . -maxdepth 3 -name "__init__.py" -printf '%h\n' 2>/dev/null | grep -v node_modules | grep -v __pycache__ | sort -u || true)
        
        for pdir in "${pkg_dirs[@]}"; do
            if [[ "$pdir" != "." && "$pdir" != "src" ]]; then
                dirs+=("$pdir")
            fi
        done
    fi
    
    # Remove duplicates and build output
    local unique_dirs=($(printf '%s\n' "${dirs[@]}" | sort -u))
    
    if [[ ${#unique_dirs[@]} -gt 0 ]]; then
        echo "Detected potential sub-systems:" >&2
        for d in "${unique_dirs[@]}"; do
            ((count++))
            echo "  - $d" >&2
        done
        echo "Total: $count sub-system(s)" >&2
    else
        echo "No distinct sub-systems detected from directory structure." >&2
    fi
    
    # Return as JSON if JSON mode
    if $JSON_MODE; then
        echo "["
        local first=true
        for d in "${unique_dirs[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            echo -n "  {\"id\": \"$d\", \"name\": \"$d\", \"detection_method\": \"directory\", \"evidence\": \"directory: $d/\"}"
        done
        echo ""
        echo "]"
    fi
}

# Function to detect tech stack from codebase
detect_tech_stack() {
    local tech_stack=""
    
    echo "Scanning codebase for technology stack..." >&2
    
    # Languages
    if [[ -f "package.json" ]]; then
        tech_stack+="**Languages**: JavaScript/TypeScript\n"
        tech_stack+="**Package Manager**: npm/yarn\n"
    fi
    
    if [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        tech_stack+="**Languages**: Python\n"
        if [[ -f "pyproject.toml" ]]; then
            tech_stack+="**Package Manager**: pip/poetry/uv\n"
        fi
    fi
    
    if [[ -f "Cargo.toml" ]]; then
        tech_stack+="**Languages**: Rust\n"
        tech_stack+="**Package Manager**: Cargo\n"
    fi
    
    if [[ -f "go.mod" ]]; then
        tech_stack+="**Languages**: Go\n"
        tech_stack+="**Package Manager**: go modules\n"
    fi
    
    if [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        tech_stack+="**Languages**: Java\n"
        if [[ -f "pom.xml" ]]; then
            tech_stack+="**Build System**: Maven\n"
        else
            tech_stack+="**Build System**: Gradle\n"
        fi
    fi
    
    if [[ -f "*.csproj" ]] || [[ -f "*.sln" ]]; then
        tech_stack+="**Languages**: C#/.NET\n"
        tech_stack+="**Build System**: dotnet\n"
    fi
    
    # Frameworks (basic detection)
    if [[ -f "package.json" ]]; then
        if grep -q "react" package.json 2>/dev/null; then
            tech_stack+="**Frontend Framework**: React\n"
        fi
        if grep -q "vue" package.json 2>/dev/null; then
            tech_stack+="**Frontend Framework**: Vue\n"
        fi
        if grep -q "angular" package.json 2>/dev/null; then
            tech_stack+="**Frontend Framework**: Angular\n"
        fi
        if grep -q "express" package.json 2>/dev/null; then
            tech_stack+="**Backend Framework**: Express\n"
        fi
        if grep -q "fastify" package.json 2>/dev/null; then
            tech_stack+="**Backend Framework**: Fastify\n"
        fi
    fi
    
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        if grep -q "django" requirements.txt 2>/dev/null || grep -q "django" pyproject.toml 2>/dev/null; then
            tech_stack+="**Backend Framework**: Django\n"
        fi
        if grep -q "fastapi" requirements.txt 2>/dev/null || grep -q "fastapi" pyproject.toml 2>/dev/null; then
            tech_stack+="**Backend Framework**: FastAPI\n"
        fi
        if grep -q "flask" requirements.txt 2>/dev/null || grep -q "flask" pyproject.toml 2>/dev/null; then
            tech_stack+="**Backend Framework**: Flask\n"
        fi
    fi
    
    # Databases
    if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        if grep -q "postgres" docker-compose.* 2>/dev/null; then
            tech_stack+="**Database**: PostgreSQL\n"
        fi
        if grep -q "mysql" docker-compose.* 2>/dev/null; then
            tech_stack+="**Database**: MySQL\n"
        fi
        if grep -q "mongodb" docker-compose.* 2>/dev/null; then
            tech_stack+="**Database**: MongoDB\n"
        fi
        if grep -q "redis" docker-compose.* 2>/dev/null; then
            tech_stack+="**Cache**: Redis\n"
        fi
    fi
    
    # Infrastructure
    if [[ -f "Dockerfile" ]]; then
        tech_stack+="**Containerization**: Docker\n"
    fi
    
    local yaml_files=(*.yaml)
    if [[ -d "kubernetes" ]] || [[ -d "k8s" ]] || [[ -f "${yaml_files[0]}" ]] && grep -q "apiVersion:" *.yaml 2>/dev/null; then
        tech_stack+="**Orchestration**: Kubernetes\n"
    fi
    
    if [[ -d "terraform" ]] || [[ -f "*.tf" ]]; then
        tech_stack+="**IaC**: Terraform\n"
    fi
    
    local github_yml_files=(".github/workflows/"*.yml)
    local github_yaml_files=(".github/workflows/"*.yaml)
    if [[ -f "${github_yml_files[0]}" ]] || [[ -f "${github_yaml_files[0]}" ]]; then
        tech_stack+="**CI/CD**: GitHub Actions\n"
    fi
    
    if [[ -f ".gitlab-ci.yml" ]]; then
        tech_stack+="**CI/CD**: GitLab CI\n"
    fi
    
    if [[ -f "Jenkinsfile" ]]; then
        tech_stack+="**CI/CD**: Jenkins\n"
    fi
    
    echo -e "$tech_stack"
}

# Function to map directory structure
map_directory_structure() {
    echo "Scanning directory structure..." >&2
    
    local structure=""
    
    # Common patterns
    if [[ -d "src" ]]; then
        structure+="**Source Code**: src/\n"
        if [[ -d "src/api" ]] || [[ -d "src/routes" ]]; then
            structure+="  - API Layer: src/api/ or src/routes/\n"
        fi
        if [[ -d "src/services" ]]; then
            structure+="  - Business Logic: src/services/\n"
        fi
        if [[ -d "src/models" ]]; then
            structure+="  - Data Models: src/models/\n"
        fi
        if [[ -d "src/utils" ]]; then
            structure+="  - Utilities: src/utils/\n"
        fi
    fi
    
    if [[ -d "tests" ]] || [[ -d "test" ]]; then
        structure+="**Tests**: tests/ or test/\n"
    fi
    
    if [[ -d "docs" ]]; then
        structure+="**Documentation**: docs/\n"
    fi
    
    if [[ -d "scripts" ]]; then
        structure+="**Scripts**: scripts/\n"
    fi
    
    if [[ -d "infra" ]] || [[ -d "infrastructure" ]]; then
        structure+="**Infrastructure**: infra/ or infrastructure/\n"
    fi
    
    echo -e "$structure"
}

# Function to extract API endpoints (basic pattern matching)
extract_api_endpoints() {
    echo "Scanning for API endpoints..." >&2
    
    local endpoints=""
    
    # Look for common API route patterns
    if [[ -d "src" ]]; then
        # Express.js style
        endpoints+=$(grep -r "router\.\(get\|post\|put\|delete\|patch\)" src 2>/dev/null | head -10 || true)
        
        # FastAPI style
        endpoints+=$(grep -r "@app\.\(get\|post\|put\|delete\|patch\)" src 2>/dev/null | head -10 || true)
        
        # Flask style
        endpoints+=$(grep -r "@app\.route" src 2>/dev/null | head -10 || true)
    fi
    
    if [[ -n "$endpoints" ]]; then
        echo "API Endpoints detected (sample):"
        echo "$endpoints" | head -10
    fi
}

# Function to scan existing docs for deduplication
scan_existing_docs() {
    local repo_root="${1:-$REPO_ROOT}"
    local findings=""
    
    echo "Scanning existing documentation for deduplication..." >&2
    
    # Check for existing architecture docs
    if [[ -f "$repo_root/AD.md" ]]; then
        findings+="EXISTING_AD: $repo_root/AD.md\n"
    fi
    
    if [[ -f "$repo_root/docs/architecture.md" ]]; then
        findings+="EXISTING_ARCHITECTURE: $repo_root/docs/architecture.md\n"
    fi
    
    # Scan README for tech stack
    if [[ -f "$repo_root/README.md" ]]; then
        if grep -q "Tech Stack\|Technology\|Built with" "$repo_root/README.md" 2>/dev/null; then
            findings+="TECH_STACK_IN_README: $repo_root/README.md\n"
        fi
        if grep -q "PostgreSQL\|MySQL\|MongoDB\|Redis" "$repo_root/README.md" 2>/dev/null; then
            findings+="DATABASE_IN_README: $repo_root/README.md\n"
        fi
        if grep -q "React\|Vue\|Angular" "$repo_root/README.md" 2>/dev/null; then
            findings+="FRONTEND_IN_README: $repo_root/README.md\n"
        fi
    fi
    
    # Scan AGENTS.md for context
    if [[ -f "$repo_root/AGENTS.md" ]]; then
        findings+="AGENTS_CONTEXT: $repo_root/AGENTS.md\n"
    fi
    
    # Scan CONTRIBUTING.md for dev guidelines
    if [[ -f "$repo_root/CONTRIBUTING.md" ]]; then
        findings+="DEV_GUIDELINES: $repo_root/CONTRIBUTING.md\n"
    fi
    
    echo -e "$findings"
}

# Function to parse views flag
parse_views() {
    local views_arg="$1"
    
    case "$views_arg" in
        "all"|"full")
            echo "context functional information concurrency development deployment operational"
            ;;
        "core"|"minimal"|"")
            echo "context functional information development deployment"
            ;;
        *)
            # Parse comma-separated: "concurrency,operational"
            local valid_views=""
            local all_views="context functional information concurrency development deployment operational"
            
            IFS=',' read -ra VIEWS_ARRAY <<< "$views_arg"
            for view in "${VIEWS_ARRAY[@]}"; do
                view=$(echo "$view" | tr -d ' ')  # Trim whitespace
                # Check if view is valid
                if echo "$all_views" | grep -qw "$view"; then
                    valid_views="$valid_views $view"
                fi
            done
            
            # Always include core views
            for view in context functional information development deployment; do
                if ! echo "$valid_views" | grep -qw "$view"; then
                    valid_views="$valid_views $view"
                fi
            done
            
            echo "$valid_views" | sed 's/^ *//'
            ;;
    esac
}

# Function to generate and insert diagrams into architecture.md
generate_and_insert_diagrams() {
    local arch_file="$1"
    local system_name="${2:-System}"
    local views_list="${3:-$ARCHITECTURE_VIEWS}"
    
    # Parse views
    local parsed_views
    parsed_views=$(parse_views "$views_list")
    
    echo "📊 Generating architecture diagrams..." >&2
    echo "   Views: $parsed_views" >&2
    
    # Get diagram format from config
    local diagram_format
    diagram_format=$(get_architecture_diagram_format)
    
    echo "   Using diagram format: $diagram_format" >&2
    
    # Source diagram generators
    local generator_dir="$SCRIPT_DIR"
    if [[ "$diagram_format" == "mermaid" ]]; then
        source "$generator_dir/mermaid-generator.sh"
    else
        source "$generator_dir/ascii-generator.sh"
    fi
    
    # Generate each diagram and insert into template
    for view in $parsed_views; do
        echo "   Generating ${view} view diagram..." >&2
        
        local diagram_code
        if [[ "$diagram_format" == "mermaid" ]]; then
            diagram_code=$(generate_mermaid_diagram "$view" "$system_name")
            
            # Validate Mermaid syntax
            if ! validate_mermaid_syntax "$diagram_code"; then
                echo "   ⚠️  Mermaid validation failed for ${view} view, using ASCII fallback" >&2
                source "$generator_dir/ascii-generator.sh"
                diagram_code=$(generate_ascii_diagram "$view" "$system_name")
                diagram_format="ascii"
            fi
        else
            diagram_code=$(generate_ascii_diagram "$view" "$system_name")
        fi
        
        # Create the diagram block with appropriate markdown
        local diagram_block
        if [[ "$diagram_format" == "mermaid" ]]; then
            diagram_block="\`\`\`mermaid
$diagram_code
\`\`\`"
        else
            diagram_block="\`\`\`text
$diagram_code
\`\`\`"
        fi
        
        # Insert diagram into the architecture file at appropriate location
        # This is a simplified insertion - AI agent via architect.md template will do the real work
        # We're just providing the diagram generation capability here
    done
    
    echo "✅ Diagram generation complete" >&2
}

# Action: Specify (greenfield - interactive PRD exploration to create ADRs)
action_specify() {
    local adr_file="$REPO_ROOT/.specify/drafts/adr.md"
    local adr_template="$REPO_ROOT/.specify/templates/adr-template.md"
    
    echo "📐 Setting up for interactive ADR creation..." >&2
    
    # Ensure drafts directory exists
    mkdir -p "$REPO_ROOT/.specify/drafts"
    
    # Show decomposition status
    if [[ "$DECOMPOSE" == "true" ]]; then
        echo "" >&2
        echo "🔄 Sub-system decomposition: ENABLED" >&2
        echo "   (AI agent will detect domains from PRD and propose sub-systems)" >&2
    else
        echo "" >&2
        echo "⚠️  Sub-system decomposition: DISABLED (--no-decompose flag)" >&2
        echo "   (AI agent will generate monolithic ADRs)" >&2
    fi
    
    # Initialize ADR file from template if it doesn't exist
    if [[ ! -f "$adr_file" ]]; then
        if [[ -f "$adr_template" ]]; then
            echo "Creating ADR file from template..." >&2
            cp "$adr_template" "$adr_file"
            echo "✅ Created: $adr_file" >&2
        else
            # Create minimal ADR file
            cat > "$adr_file" << 'EOF'
# Architecture Decision Records

## ADR Index

| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|
 
---

EOF
            echo "✅ Created minimal ADR file: $adr_file" >&2
        fi
    else
        echo "✅ ADR file already exists: $adr_file" >&2
    fi
    
    echo "" >&2
    echo "Ready for interactive PRD exploration." >&2
    echo "The AI agent will:" >&2
    if [[ "$DECOMPOSE" == "true" ]]; then
        echo "  0. (Phase 0) Detect domains in PRD and propose sub-systems" >&2
        echo "     → Ask user to confirm sub-system breakdown" >&2
    fi
    echo "  1. Analyze your PRD/requirements input" >&2
    echo "  2. Ask clarifying questions about architecture" >&2
    echo "  3. Create ADRs for each key decision" >&2
    echo "  4. Save decisions to .specify/drafts/adr.md (Proposed status)" >&2
    echo "     (ADRs will be moved to memory/team after /architect.implement)" >&2
    if [[ "$DECOMPOSE" == "true" ]]; then
        echo "  5. Organize ADRs by sub-system" >&2
    fi
    echo "" >&2
    echo "After completion, run '/architect.implement' to generate full AD.md" >&2
    
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"specify\",\"adr_file\":\"$adr_file\",\"context\":\"${ARGS[*]}\",\"decomposition\":\"$DECOMPOSE\"}"
    fi
}

# Action: Clarify (refine existing ADRs)
action_clarify() {
    local adr_file="$REPO_ROOT/.specify/memory/adr.md"
    
    if [[ ! -f "$adr_file" ]]; then
        echo "❌ ADR file does not exist: $adr_file" >&2
        echo "Run '/architect.specify' or '/architect.init' first" >&2
        exit 1
    fi
    
    echo "🔍 Loading existing ADRs for clarification..." >&2
    
    # Count existing ADRs
    local adr_count
    adr_count=$(grep -c "^## ADR-" "$adr_file" 2>/dev/null || echo "0")
    echo "Found $adr_count ADR(s) in $adr_file" >&2
    
    echo "" >&2
    echo "Ready for ADR refinement." >&2
    echo "The AI agent will:" >&2
    echo "  1. Review existing ADRs" >&2
    echo "  2. Ask targeted clarification questions" >&2
    echo "  3. Update ADRs based on your responses" >&2
    echo "  4. Flag any inconsistencies or gaps" >&2
    
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"clarify\",\"adr_file\":\"$adr_file\",\"adr_count\":$adr_count,\"context\":\"${ARGS[*]}\"}"
    fi
}

# Action: Implement (generate full AD.md from ADRs)
action_implement() {
    local adr_file="$REPO_ROOT/.specify/drafts/adr.md"
    local ad_file="$REPO_ROOT/AD.md"
    local ad_template="$REPO_ROOT/.specify/templates/AD-template.md"
    
    if [[ ! -f "$adr_file" ]]; then
        echo "❌ ADR drafts file does not exist: $adr_file" >&2
        echo "Run '/architect.specify' or '/architect.init' first" >&2
        exit 1
    fi
    
    echo "📐 Setting up for Architecture Description generation..." >&2
    
    # Initialize AD.md from template if it doesn't exist
    if [[ ! -f "$ad_file" ]]; then
        if [[ -f "$ad_template" ]]; then
            echo "Creating AD.md from template..." >&2
            cp "$ad_template" "$ad_file"
            echo "✅ Created: $ad_file" >&2
        else
            echo "⚠️  AD template not found: $ad_template" >&2
            echo "The AI agent will create AD.md from scratch" >&2
        fi
    else
        echo "✅ AD.md already exists, will be updated: $ad_file" >&2
    fi
    
    # Count ADRs for context
    local adr_count
    adr_count=$(grep -c "^## ADR-" "$adr_file" 2>/dev/null || echo "0")
    
    echo "" >&2
    echo "Ready for Architecture Description generation." >&2
    echo "The AI agent will:" >&2
    echo "  1. Read all $adr_count ADR(s) from .specify/drafts/adr.md" >&2
    echo "  2. Generate 7 Rozanski & Woods viewpoints" >&2
    echo "  3. Apply Security and Performance perspectives" >&2
    echo "  4. Create Mermaid diagrams for each view" >&2
    echo "  5. Write complete AD.md to project root" >&2
    echo "  6. Move Accepted ADRs to canonical location (.specify/memory/adr.md)" >&2
    echo "  7. Clean up drafts if all ADRs are Accepted" >&2
    
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"implement\",\"adr_file\":\"$adr_file\",\"ad_file\":\"$ad_file\",\"adr_count\":$adr_count,\"context\":\"${ARGS[*]}\"}"
    fi
}

# Action: Initialize (brownfield - reverse-engineer from codebase, ADRs only)
action_init() {
    local adr_file="$REPO_ROOT/.specify/drafts/adr.md"
    local adr_template="$REPO_ROOT/.specify/templates/adr-template.md"
    
    echo "🔍 Initializing brownfield architecture discovery..." >&2
    
    # Ensure drafts directory exists
    mkdir -p "$REPO_ROOT/.specify/drafts"
    
    # Scan existing docs for deduplication
    local existing_docs
    existing_docs=$(scan_existing_docs "$REPO_ROOT")
    if [[ -n "$existing_docs" ]]; then
        echo "📋 Found existing documentation:" >&2
        echo "$existing_docs" | while read -r line; do
            echo "  - $line" >&2
        done
        echo "" >&2
    fi
    
    # Detect tech stack for context
    echo "🔍 Scanning codebase..." >&2
    local tech_stack
    tech_stack=$(detect_tech_stack)
    
    local dir_structure
    dir_structure=$(map_directory_structure)
    
    # Phase 0: Sub-system detection (if decomposition enabled)
    local subsystems_json=""
    local decompose_status="disabled"
    
    if [[ "$DECOMPOSE" == "true" ]]; then
        echo "" >&2
        echo "🔄 Phase 0: Sub-System Detection" >&2
        subsystems_json=$(detect_subsystems)
        decompose_status="enabled"
        
        if [[ -n "$subsystems_json" ]] && [[ "$subsystems_json" != "[]" ]]; then
            echo "" >&2
            echo "📦 Sub-systems will be used to organize ADRs" >&2
            echo "   (AI agent will confirm with user before proceeding)" >&2
        fi
    else
        echo "" >&2
        echo "⚠️  Sub-system decomposition disabled (--no-decompose flag)" >&2
    fi
    
    # Initialize ADR file from template if it doesn't exist
    if [[ ! -f "$adr_file" ]]; then
        if [[ -f "$adr_template" ]]; then
            echo "Creating ADR file from template..." >&2
            cp "$adr_template" "$adr_file"
            echo "✅ Created: $adr_file" >&2
        else
            # Create minimal ADR file
            cat > "$adr_file" << 'EOF'
# Architecture Decision Records

## ADR Index

| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|

---

EOF
            echo "✅ Created minimal ADR file: $adr_file" >&2
        fi
    else
        echo "✅ ADR file already exists: $adr_file" >&2
    fi
    
    echo "" >&2
    echo "📊 Codebase Analysis Summary:" >&2
    echo "$tech_stack" >&2
    echo "" >&2
    echo "$dir_structure" >&2
    
    echo "" >&2
    echo "Ready for brownfield architecture discovery." >&2
    echo "The AI agent will:" >&2
    if [[ "$DECOMPOSE" == "true" ]]; then
        echo "  0. (Phase 0) Propose sub-systems from code structure" >&2
        echo "     → Ask user to confirm sub-system breakdown" >&2
    fi
    echo "  1. Analyze codebase structure and patterns" >&2
    echo "  2. Infer architectural decisions from code" >&2
    echo "  3. Create ADRs marked as 'Discovered (Inferred)'" >&2
    if [[ "$DECOMPOSE" == "true" ]]; then
        echo "  4. Organize ADRs by sub-system" >&2
    fi
    echo "  5. Auto-trigger /architect.clarify to validate findings" >&2
    echo "" >&2
    echo "NOTE: AD.md will NOT be created until ADRs are validated." >&2
    echo "      After clarification, run /architect.implement to generate AD.md" >&2
    
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"init\",\"adr_file\":\"$adr_file\",\"tech_stack\":\"$tech_stack\",\"existing_docs\":\"$existing_docs\",\"source\":\"brownfield\",\"decomposition\":\"$decompose_status\",\"subsystems\":$subsystems_json}"
    fi
}

# Action: Map (brownfield)
action_map() {
    echo "🔍 Mapping existing codebase to architecture..." >&2
    
    # Scan existing docs
    local existing_docs
    existing_docs=$(scan_existing_docs "$REPO_ROOT")
    
    # Detect tech stack
    echo "" >&2
    echo "Tech Stack Detected:" >&2
    tech_stack=$(detect_tech_stack)
    echo "$tech_stack" >&2
    
    # Map directory structure
    echo "" >&2
    echo "Code Organization:" >&2
    dir_structure=$(map_directory_structure)
    echo "$dir_structure" >&2
    
    # Extract API endpoints
    echo "" >&2
    extract_api_endpoints >&2
    
    # Output structured data for AI agent to populate AD.md
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"map\",\"tech_stack\":\"$tech_stack\",\"directory_structure\":\"$dir_structure\",\"existing_docs\":\"$existing_docs\"}"
    else
        echo "" >&2
        echo "📋 Mapping complete. Use this information to populate AD.md:" >&2
        
        if [[ -n "$existing_docs" ]]; then
            echo "" >&2
            echo "Existing Documentation (reference, don't duplicate):" >&2
            echo "$existing_docs" | while read -r line; do
                echo "  - $line" >&2
            done
        fi
        
        echo "" >&2
        echo "Architecture Sections:" >&2
        echo "  - Context View (3.1): Define system boundaries" >&2
        echo "  - Development View (3.5): Use directory structure above" >&2
        echo "  - Deployment View (3.6): Check docker-compose.yml, k8s configs, terraform" >&2
        echo "  - Functional View (3.2): Use API endpoints detected" >&2
        echo "  - Information View (3.3): Check database schemas, ORM models" >&2
    fi
}

# Action: Update
action_update() {
    if [[ ! -f "$AD_FILE" ]]; then
        echo "❌ Architecture does not exist: $AD_FILE" >&2
        echo "Run '/architect.specify' or '/architect.init' first" >&2
        exit 1
    fi
    
    echo "🔄 Updating architecture based on recent changes..." >&2
    
    # Check for recent commits (basic approach)
    if command -v git &> /dev/null && [[ -d "$REPO_ROOT/.git" ]]; then
        echo "" >&2
        echo "Recent changes:" >&2
        git log --oneline --since="7 days ago" 2>/dev/null | head -10 >&2 || true
    fi
    
    # Detect changes in tech stack
    echo "" >&2
    echo "Current Tech Stack:" >&2
    detect_tech_stack >&2
    
    # Regenerate diagrams with current format and views
    generate_and_insert_diagrams "$AD_FILE" "System" "$VIEWS"
    
    echo "" >&2
    echo "✅ Update analysis complete" >&2
    echo "Review the architecture document and update affected sections:" >&2
    echo "  - New tables/models? → Update Information View" >&2
    echo "  - New services/components? → Update Functional View + Deployment View" >&2
    echo "  - New queues/async? → Update Concurrency View (if included)" >&2
    echo "  - New dependencies? → Update Development View" >&2
    echo "  - Add ADR if significant decision was made" >&2
    
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"update\",\"ad_file\":\"$AD_FILE\",\"adr_file\":\"$ADR_FILE\"}"
    fi
}

# Action: Review
action_review() {
    if [[ ! -f "$AD_FILE" ]]; then
        echo "❌ Architecture does not exist: $AD_FILE" >&2
        echo "Run '/architect.specify' or '/architect.init' first" >&2
        exit 1
    fi
    
    echo "🔍 Reviewing architecture..." >&2
    
    # Check for completeness
    local issues=()
    
    # Check for required sections
    if ! grep -q "## 1\. Introduction" "$AD_FILE"; then
        issues+=("Missing: Introduction section")
    fi
    
    if ! grep -q "## 2\. Stakeholders & Concerns" "$AD_FILE"; then
        issues+=("Missing: Stakeholders section")
    fi
    
    if ! grep -q "## 3\. Architectural Views" "$AD_FILE"; then
        issues+=("Missing: Architectural Views section")
    fi
    
    if ! grep -q "### 3.1 Context View" "$AD_FILE"; then
        issues+=("Missing: Context View")
    fi
    
    if ! grep -q "### 3.2 Functional View" "$AD_FILE"; then
        issues+=("Missing: Functional View")
    fi
    
    if ! grep -q "## 4\. Architectural Perspectives" "$AD_FILE"; then
        issues+=("Missing: Perspectives section")
    fi
    
    if ! grep -q "## 5\. Global Constraints & Principles" "$AD_FILE"; then
        issues+=("Missing: Global Constraints section")
    fi
    
    # Check for placeholder content
    if grep -q "\[SYSTEM_NAME\]" "$AD_FILE"; then
        issues+=("Placeholder: System name not filled in")
    fi
    
    if grep -q "\[STAKEHOLDER_" "$AD_FILE"; then
        issues+=("Placeholder: Stakeholders not filled in")
    fi
    
    # Report results
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "✅ Architecture review passed - no major issues found" >&2
    else
        echo "⚠️  Architecture review found issues:" >&2
        for issue in "${issues[@]}"; do
            echo "  - $issue" >&2
        done
    fi
    
    # Check constitution alignment if it exists
    local constitution_file="$REPO_ROOT/.specify/memory/constitution.md"
    if [[ -f "$constitution_file" ]]; then
        echo "" >&2
        echo "📜 Checking constitution alignment..." >&2
        echo "✅ Constitution file found: $constitution_file" >&2
        echo "Manually verify that architecture adheres to constitutional principles" >&2
    fi
    
    # Check for ADRs
    if [[ -f "$ADR_FILE" ]]; then
        echo "" >&2
        echo "📋 ADR file found: $ADR_FILE" >&2
        local adr_count
        adr_count=$(grep -c "^## ADR-" "$ADR_FILE" 2>/dev/null || echo "0")
        echo "   Found $adr_count ADR(s)" >&2
    fi
    
    if $JSON_MODE; then
        if [[ ${#issues[@]} -eq 0 ]]; then
            echo "{\"status\":\"success\",\"action\":\"review\",\"ad_file\":\"$AD_FILE\",\"adr_file\":\"$ADR_FILE\",\"issues\":[]}"
        else
            # Format issues as JSON array
            issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
            echo "{\"status\":\"warning\",\"action\":\"review\",\"ad_file\":\"$AD_FILE\",\"adr_file\":\"$ADR_FILE\",\"issues\":$issues_json}"
        fi
    fi
}

# Action: Analyze (validate architecture consistency)
action_analyze() {
    echo "🔍 Architecture Analysis Mode" >&2
    echo ""
    
    local ad_file="$REPO_ROOT/AD.md"
    local adr_file="$REPO_ROOT/.specify/memory/adr.md"
    local constitution_file="$REPO_ROOT/.specify/memory/constitution.md"
    
    local ad_exists=false
    local adr_exists=false
    local constitution_exists=false
    
    if [[ -f "$ad_file" ]]; then
        ad_exists=true
        echo "📄 AD.md found: $ad_file" >&2
    else
        echo "⚠️  AD.md not found at $ad_file" >&2
    fi
    
    if [[ -f "$adr_file" ]]; then
        adr_exists=true
        local adr_count
        adr_count=$(grep -c "^### ADR-" "$adr_file" 2>/dev/null || echo "0")
        echo "📋 ADR file found: $adr_file ($adr_count ADRs)" >&2
    else
        echo "⚠️  ADR file not found at $adr_file" >&2
    fi
    
    if [[ -f "$constitution_file" ]]; then
        constitution_exists=true
        echo "📜 Constitution found: $constitution_file" >&2
    fi
    
    # Scan for feature-level architecture
    local feature_ads=()
    local feature_adrs=()
    
    if [[ -d "$REPO_ROOT/specs" ]]; then
        while IFS= read -r -d '' f; do
            feature_ads+=("$f")
        done < <(find "$REPO_ROOT/specs" -name "AD.md" -print0 2>/dev/null)
        
        while IFS= read -r -d '' f; do
            feature_adrs+=("$f")
        done < <(find "$REPO_ROOT/specs" -name "adr.md" -print0 2>/dev/null)
        
        if [[ ${#feature_ads[@]} -gt 0 ]]; then
            echo "📁 Feature ADs found: ${#feature_ads[@]}" >&2
        fi
        if [[ ${#feature_adrs[@]} -gt 0 ]]; then
            echo "📁 Feature ADRs found: ${#feature_adrs[@]}" >&2
        fi
    fi
    
    echo "" >&2
    echo "Ready for architecture consistency analysis." >&2
    echo "The AI agent will:" >&2
    echo "  1. Load all architecture artifacts" >&2
    echo "  2. Execute detection passes A-G" >&2
    echo "  3. Assign severity levels to findings" >&2
    echo "  4. Generate structured analysis report" >&2
    echo "  5. Suggest remediation actions" >&2
    
    if $JSON_MODE; then
        local feature_ads_json="[]"
        local feature_adrs_json="[]"
        
        if [[ ${#feature_ads[@]} -gt 0 ]]; then
            feature_ads_json=$(printf '%s\n' "${feature_ads[@]}" | jq -R . | jq -s .)
        fi
        if [[ ${#feature_adrs[@]} -gt 0 ]]; then
            feature_adrs_json=$(printf '%s\n' "${feature_adrs[@]}" | jq -R . | jq -s .)
        fi
        
        echo "{\"status\":\"success\",\"action\":\"analyze\",\"ad_file\":\"$ad_file\",\"ad_exists\":$ad_exists,\"adr_file\":\"$adr_file\",\"adr_exists\":$adr_exists,\"constitution_file\":\"$constitution_file\",\"constitution_exists\":$constitution_exists,\"feature_ads\":$feature_ads_json,\"feature_adrs\":$feature_adrs_json,\"context\":\"${ARGS[*]}\"}"
    fi
}

# Action: Plan DAG (Phase 1 of implement - generate execution plan)
action_plan_dag() {
    local adr_file="$REPO_ROOT/.specify/drafts/adr.md"
    local state_file="$REPO_ROOT/.specify/architect/state.json"
    local views_dir="$REPO_ROOT/.specify/architect/views"
    
    echo "📐 DAG Planning Phase" >&2
    echo "" >&2
    
    # Check if ADR file exists
    if [[ ! -f "$adr_file" ]]; then
        echo "❌ ADR drafts file does not exist: $adr_file" >&2
        echo "Run '/architect.specify' or '/architect.init' first" >&2
        exit 1
    fi
    
    # Ensure directories exist
    mkdir -p "$REPO_ROOT/.specify/architect"
    mkdir -p "$views_dir"
    
    # Count ADRs and extract sub-systems
    local adr_count
    adr_count=$(grep -c "^### ADR-" "$adr_file" 2>/dev/null || grep -c "^## ADR-" "$adr_file" 2>/dev/null || echo "0")
    
    # Extract unique sub-systems from ADR index table
    local subsystems=()
    while IFS= read -r line; do
        # Parse ADR index table rows: | ADR-XXX | SubSystem | ...
        if [[ "$line" =~ ^\|[[:space:]]*ADR-[0-9]+[[:space:]]*\|[[:space:]]*([^|]+)[[:space:]]*\| ]]; then
            local subsystem="${BASH_REMATCH[1]}"
            subsystem=$(echo "$subsystem" | xargs)  # Trim whitespace
            if [[ -n "$subsystem" && "$subsystem" != "Sub-System" ]]; then
                # Add to array if not already present
                local found=false
                for s in "${subsystems[@]}"; do
                    if [[ "$s" == "$subsystem" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == "false" ]]; then
                    subsystems+=("$subsystem")
                fi
            fi
        fi
    done < "$adr_file"
    
    # Default to "System" if no sub-systems found
    if [[ ${#subsystems[@]} -eq 0 ]]; then
        subsystems=("System")
    fi
    
    echo "📋 ADR file found: $adr_file" >&2
    echo "   Found $adr_count ADR(s)" >&2
    echo "   Sub-systems detected: ${subsystems[*]}" >&2
    echo "" >&2
    echo "Ready for DAG planning." >&2
    echo "The AI agent will:" >&2
    echo "  1. Analyze ADRs by sub-system" >&2
    echo "  2. Generate customized DAG per sub-system" >&2
    echo "  3. Present execution plan for user approval" >&2
    echo "  4. Save approved plan to state.json" >&2
    
    if $JSON_MODE; then
        # Build subsystems JSON array
        local subsystems_json="["
        local first=true
        for s in "${subsystems[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                subsystems_json+=","
            fi
            subsystems_json+="{\"id\":\"$(echo "$s" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')\",\"name\":\"$s\"}"
        done
        subsystems_json+="]"
        
        echo "{\"status\":\"success\",\"action\":\"plan-dag\",\"adr_file\":\"$adr_file\",\"state_file\":\"$state_file\",\"views_dir\":\"$views_dir\",\"adr_count\":$adr_count,\"subsystems\":$subsystems_json,\"context\":\"${ARGS[*]}\"}"
    fi
}

# Action: Execute DAG (Phase 2 of implement - generate views based on state)
action_execute_dag() {
    local state_file="$REPO_ROOT/.specify/architect/state.json"
    local views_dir="$REPO_ROOT/.specify/architect/views"
    
    echo "🔧 DAG Execution Phase" >&2
    echo "" >&2
    
    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        echo "❌ No execution plan found: $state_file" >&2
        echo "Run '/architect.implement' first to generate and approve a DAG plan" >&2
        exit 1
    fi
    
    # Ensure views directory exists
    mkdir -p "$views_dir"
    
    echo "📄 State file found: $state_file" >&2
    echo "📁 Views directory: $views_dir" >&2
    echo "" >&2
    echo "Ready for DAG execution." >&2
    echo "The AI agent will:" >&2
    echo "  1. Read execution plan from state.json" >&2
    echo "  2. Identify next view(s) to generate" >&2
    echo "  3. Generate view with dependency context" >&2
    echo "  4. Write to .specify/architect/views/{subsystem}/{view}.md" >&2
    echo "  5. Update progress in state.json" >&2
    
    if $JSON_MODE; then
        # Output the state file content for the AI agent
        if [[ -f "$state_file" ]]; then
            local state_content
            state_content=$(cat "$state_file")
            echo "{\"status\":\"success\",\"action\":\"execute-dag\",\"state_file\":\"$state_file\",\"views_dir\":\"$views_dir\",\"state\":$state_content}"
        else
            echo "{\"status\":\"error\",\"action\":\"execute-dag\",\"error\":\"state_file_not_found\"}"
        fi
    fi
}

# Action: Summarize (Phase 3 of implement - aggregate views into AD.md)
action_summarize() {
    local state_file="$REPO_ROOT/.specify/architect/state.json"
    local views_dir="$REPO_ROOT/.specify/architect/views"
    local ad_file="$REPO_ROOT/AD.md"
    local adr_file="$REPO_ROOT/.specify/drafts/adr.md"
    
    echo "📝 Summarization Phase" >&2
    echo "" >&2
    
    # Check if views directory exists and has content
    if [[ ! -d "$views_dir" ]]; then
        echo "❌ Views directory not found: $views_dir" >&2
        echo "Run '/architect.implement' to generate views first" >&2
        exit 1
    fi
    
    # Count view files
    local view_count
    view_count=$(find "$views_dir" -name "*.md" -type f 2>/dev/null | wc -l)
    
    if [[ "$view_count" -eq 0 ]]; then
        echo "❌ No view files found in $views_dir" >&2
        echo "Run '/architect.implement' to generate views first" >&2
        exit 1
    fi
    
    # List all view files
    echo "📁 Views directory: $views_dir" >&2
    echo "   Found $view_count view file(s):" >&2
    find "$views_dir" -name "*.md" -type f | while read -r f; do
        echo "   - ${f#$views_dir/}" >&2
    done
    echo "" >&2
    
    echo "Ready for summarization." >&2
    echo "The AI agent will:" >&2
    echo "  1. Read all view files from .specify/architect/views/" >&2
    echo "  2. Detect cross-subsystem conflicts" >&2
    echo "  3. Resolve conflicts using ADRs as source of truth" >&2
    echo "  4. Aggregate into unified AD.md" >&2
    echo "  5. Apply Security and Performance perspectives" >&2
    echo "  6. Move Accepted ADRs to canonical location" >&2
    
    if $JSON_MODE; then
        # Build list of view files
        local views_json="["
        local first=true
        while IFS= read -r f; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                views_json+=","
            fi
            local rel_path="${f#$views_dir/}"
            views_json+="{\"path\":\"$f\",\"relative\":\"$rel_path\"}"
        done < <(find "$views_dir" -name "*.md" -type f 2>/dev/null)
        views_json+="]"
        
        echo "{\"status\":\"success\",\"action\":\"summarize\",\"state_file\":\"$state_file\",\"views_dir\":\"$views_dir\",\"ad_file\":\"$ad_file\",\"adr_file\":\"$adr_file\",\"view_count\":$view_count,\"views\":$views_json}"
    fi
}

# Action: Validate (READ-ONLY architecture validation for plan alignment)
action_validate() {
    local adr_file="$REPO_ROOT/.specify/memory/adr.md"
    
    echo "🔍 Architecture Validation Mode (READ-ONLY)" >&2
    echo ""
    
    # Check if architecture exists
    if [[ ! -f "$adr_file" ]]; then
        echo "⏭️  Architecture not found: $adr_file" >&2
        echo "     Skipping validation gracefully" >&2
        if $JSON_MODE; then
            echo "{\"status\":\"skipped\",\"action\":\"validate\",\"reason\":\"architecture_not_found\"}"
        fi
        exit 0
    fi
    
    local adr_count
    adr_count=$(grep -c "^## ADR-" "$adr_file" 2>/dev/null || grep -c "^### ADR-" "$adr_file" 2>/dev/null || echo "0")
    
    echo "📋 ADR file found: $adr_file" >&2
    echo "   Found $adr_count ADR(s)" >&2
    echo "" >&2
    echo "Ready for READ-ONLY architecture validation." >&2
    echo "The AI agent will:" >&2
    echo "  1. Load architecture from ADRs and AD.md" >&2
    echo "  2. Validate plan alignment with architecture" >&2
    echo "  3. Identify blocking/high-severity issues" >&2
    echo "  4. Report findings (READ-ONLY, no modifications)" >&2
    
    if $JSON_MODE; then
        echo "{\"status\":\"success\",\"action\":\"validate\",\"adr_file\":\"$adr_file\",\"adr_count\":$adr_count,\"context\":\"${ARGS[*]}\"}"
    fi
}

# Execute action
case "$ACTION" in
    specify)
        action_specify
        ;;
    clarify)
        action_clarify
        ;;
    init|map)
        action_init
        ;;
    implement)
        action_implement
        ;;
    plan-dag)
        action_plan_dag
        ;;
    execute-dag)
        action_execute_dag
        ;;
    summarize)
        action_summarize
        ;;
    analyze)
        action_analyze
        ;;
    validate)
        action_validate
        ;;
    update)
        action_update
        ;;
    review)
        action_review
        ;;
    *)
        echo "❌ Unknown action: $ACTION" >&2
        echo "Use --help for usage information" >&2
        exit 1
        ;;
esac
