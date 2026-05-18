#!/bin/bash

# Product Extension Setup Script
# Sets up PRD and PDR files for the product extension

set -e

JSON_MODE=false
DECOMPOSE=true
ARGS=()

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

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --no-decompose)
            DECOMPOSE=false
            ;;
        --help|-h)
            echo "Usage: $0 [command] [--json] [--no-decompose]"
            echo ""
            echo "Commands:"
            echo "  specify    Setup for greenfield product specification"
            echo "  init       Setup for brownfield product discovery"
            echo "  implement  Setup for PRD generation"
            echo "  clarify    Setup for PDR refinement"
            echo "  analyze    Setup for consistency analysis"
            echo "  validate   Setup for plan validation"
            echo ""
            echo "DAG Workflow Commands (used internally by implement):"
            echo "  plan-dag     Phase 1: Generate DAG execution plan for user approval"
            echo "  execute-dag  Phase 2: Execute DAG to generate sections per feature-area"
            echo "  summarize    Phase 3: Aggregate sections into unified PRD.md"
            echo ""
            echo "Options:"
            echo "  --json           Output results in JSON format"
            echo "  --no-decompose   Disable automatic sub-system decomposition"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

COMMAND="${ARGS[0]:-help}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default locations
PDR_LOCATION=".specify/drafts/pdr.md"
PRD_LOCATION="PRD.md"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect sub-systems from codebase structure
detect_subsystems() {
    local subsystems=""
    local count=0
    
    echo "Detecting sub-systems from codebase structure..." >&2
    
    local dirs=()
    
    # 1. Top-level feature directories (src/, app/, features/)
    if [[ -d "src" ]]; then
        for d in src/*/; do
            if [[ -d "$d" ]]; then
                local dirname
                dirname=$(basename "$d")
                if [[ "$dirname" != "utils" && "$dirname" != "common" && "$dirname" != "lib" && "$dirname" != "shared" && "$dirname" != "core" ]]; then
                    dirs+=("$dirname")
                fi
            fi
        done
    fi
    
    if [[ -d "features" ]]; then
        for d in features/*/; do
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
    
    # 5. Check for Go modules
    if [[ -f "go.mod" ]]; then
        if [[ -d "cmd" ]]; then
            for d in cmd/*/; do
                if [[ -d "$d" ]]; then
                    local dirname
                    dirname=$(basename "$d")
                    dirs+=("$dirname")
                fi
            done
        fi
    fi
    
    # Output as JSON array if JSON mode
    if $JSON_MODE; then
        printf '{"subsystems":['
        local first=true
        for d in "${dirs[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                printf ','
            fi
            printf '{"id":"%s","name":"%s","detection_method":"directory","evidence":"%s/"}' "$d" "$d" "$d"
        done
        printf '],"decomposition":%s}' "$DECOMPOSE"
    else
        # Human-readable output
        if [[ ${#dirs[@]} -eq 0 ]]; then
            echo "No sub-systems detected." >&2
        else
            echo "Detected ${#dirs[@]} sub-systems:" >&2
            for d in "${dirs[@]}"; do
                echo "  - $d" >&2
            done
        fi
    fi
}

setup_pdr() {
    local pdr_file="$PDR_LOCATION"
    
    if [ -f "$pdr_file" ]; then
        log_info "PDR file already exists at $pdr_file"
    else
        log_info "Creating PDR file at $pdr_file"
        mkdir -p "$(dirname "$pdr_file")"
        cat > "$pdr_file" << 'EOF'
# Product Decision Records

## PDR Index

| ID | Category | Decision | Status | Date | Owner |
|----|----------|----------|--------|------|-------|
| PDR-001 | [Category] | [First decision title] | Proposed | YYYY-MM-DD | [Owner] |

---

## PDR-001: [Decision Title]

### Status

**Proposed** | Accepted | Deprecated | Superseded by PDR-XXX | **Discovered** (Inferred from existing product)

### Date

YYYY-MM-DD

### Owner

[Product Manager / Team / Stakeholder]

### Category

[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR]

### Context

**Problem/Opportunity:**
[Clear description of what needs to be decided]

**Market Forces:**
- [Market factor 1]
- [Customer feedback]
- [Internal business priority]

### Decision

**Decision Statement:**
[Clear statement of what was decided]

### Consequences

#### Positive

- [User benefit]
- [Business benefit]

#### Negative

- [Trade-off]
- [Opportunity cost]

#### Risks

- [Risk with mitigation]

### Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [Method] |

### Alternatives Considered

#### Option A: [Alternative]

**Description:** [Brief description]
**Trade-offs:** [Neutral comparison]

EOF
        log_info "PDR file created at $pdr_file"
    fi
    
    echo "$pdr_file"
}

setup_prd() {
    local prd_file="$PRD_LOCATION"
    
    if [ -f "$prd_file" ]; then
        log_info "PRD file already exists at $prd_file"
    else
        log_info "Creating PRD file at $prd_file"
        cat > "$prd_file" << 'EOF'
# Product Requirements Document: [PRODUCT_NAME]

**Version:** 1.0  
**Date:** YYYY-MM-DD  
**Author:** [Author]  
**Status:** Draft  
**PDR Reference:** [.specify/drafts/pdr.md](.specify/drafts/pdr.md)

---

## 1. Overview

[High-level description of the product]

## 2. The Problem

[Problem statement]

## 3. Goals/Objectives

* **Primary Goal:** [Main objective]
* **Technical Goal:** [Technical outcome]
* **Business Goal:** [Business value]

## 4. Success Metrics

* **Adoption:** [Metric and target]
* **Engagement:** [Metric and target]
* **Revenue/Value:** [Metric and target]

## 5. Personas

* **Primary Persona:** [Persona Name]
  * **Role:** [Job title]
  * **Needs:** [What they need]

## 6. Functional Requirements

| ID | Story | Priority |
|----|-------|----------|
| US-001 | [As a... I want to... So that...] | Must |

## 7. Non-Functional Requirements

* **Performance:** [Requirements]
* **Security:** [Requirements]
* **Reliability:** [Requirements]

## 8. Out of Scope

* [Explicitly excluded feature]

## 9. Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| [Risk] | [Mitigation] |

---

## Appendix

### A. References

### B. Change History
EOF
        log_info "PRD file created at $prd_file"
    fi
    
    echo "$prd_file"
}

# Action: Plan DAG (Phase 1 of implement - generate execution plan)
action_plan_dag() {
    local pdr_file="$REPO_ROOT/.specify/drafts/pdr.md"
    local state_file="$REPO_ROOT/.specify/product/state.json"
    local sections_dir="$REPO_ROOT/.specify/product/sections"
    
    echo "📐 DAG Planning Phase" >&2
    echo "" >&2
    
    # Check if PDR file exists
    if [[ ! -f "$pdr_file" ]]; then
        echo "❌ PDR drafts file does not exist: $pdr_file" >&2
        echo "Run '/product.specify' or '/product.init' first" >&2
        exit 1
    fi
    
    # Ensure directories exist
    mkdir -p "$REPO_ROOT/.specify/product"
    mkdir -p "$sections_dir"
    
    # Count PDRs and extract feature-areas
    local pdr_count
    pdr_count=$(grep -c "^### PDR-" "$pdr_file" 2>/dev/null || grep -c "^## PDR-" "$pdr_file" 2>/dev/null || echo "0")
    
    # Extract unique feature-areas from PDR index table
    local feature_areas=()
    while IFS= read -r line; do
        # Parse PDR index table rows: | PDR-XXX | Category | Feature-Area | ...
        if [[ "$line" =~ ^\|[[:space:]]*PDR-[0-9]+[[:space:]]*\|[[:space:]]*[^|]+[[:space:]]*\|[[:space:]]*([^|]+)[[:space:]]*\| ]]; then
            local feature_area="${BASH_REMATCH[1]}"
            feature_area=$(echo "$feature_area" | xargs)  # Trim whitespace
            if [[ -n "$feature_area" && "$feature_area" != "Feature-Area" && "$feature_area" != "Sub-System" ]]; then
                # Add to array if not already present
                local found=false
                for f in "${feature_areas[@]}"; do
                    if [[ "$f" == "$feature_area" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == "false" ]]; then
                    feature_areas+=("$feature_area")
                fi
            fi
        fi
    done < "$pdr_file"
    
    # Default to "Product" if no feature-areas found
    if [[ ${#feature_areas[@]} -eq 0 ]]; then
        feature_areas=("Product")
    fi
    
    echo "📋 PDR file found: $pdr_file" >&2
    echo "   Found $pdr_count PDR(s)" >&2
    echo "   Feature-areas detected: ${feature_areas[*]}" >&2
    echo "" >&2
    echo "Ready for DAG planning." >&2
    echo "The AI agent will:" >&2
    echo "  1. Analyze PDRs by feature-area" >&2
    echo "  2. Generate customized DAG per feature-area" >&2
    echo "  3. Present execution plan for user approval" >&2
    echo "  4. Save approved plan to state.json" >&2
    
    if $JSON_MODE; then
        # Build feature_areas JSON array
        local feature_areas_json="["
        local first=true
        for f in "${feature_areas[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                feature_areas_json+=","
            fi
            feature_areas_json+="{\"id\":\"$(echo "$f" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')\",\"name\":\"$f\"}"
        done
        feature_areas_json+="]"
        
        echo "{\"status\":\"success\",\"action\":\"plan-dag\",\"pdr_file\":\"$pdr_file\",\"state_file\":\"$state_file\",\"sections_dir\":\"$sections_dir\",\"pdr_count\":$pdr_count,\"feature_areas\":$feature_areas_json,\"context\":\"${ARGS[*]}\"}"
    fi
}

# Action: Execute DAG (Phase 2 of implement - generate sections based on state)
action_execute_dag() {
    local state_file="$REPO_ROOT/.specify/product/state.json"
    local sections_dir="$REPO_ROOT/.specify/product/sections"
    
    echo "🔧 DAG Execution Phase" >&2
    echo "" >&2
    
    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        echo "❌ No execution plan found: $state_file" >&2
        echo "Run '/product.implement' first to generate and approve a DAG plan" >&2
        exit 1
    fi
    
    # Ensure sections directory exists
    mkdir -p "$sections_dir"
    
    echo "📄 State file found: $state_file" >&2
    echo "📁 Sections directory: $sections_dir" >&2
    echo "" >&2
    echo "Ready for DAG execution." >&2
    echo "The AI agent will:" >&2
    echo "  1. Read execution plan from state.json" >&2
    echo "  2. Identify next section(s) to generate" >&2
    echo "  3. Generate section with dependency context" >&2
    echo "  4. Write to .specify/product/sections/{feature-area}/{section}.md" >&2
    echo "  5. Update progress in state.json" >&2
    
    if $JSON_MODE; then
        # Output the state file content for the AI agent
        if [[ -f "$state_file" ]]; then
            local state_content
            state_content=$(cat "$state_file")
            echo "{\"status\":\"success\",\"action\":\"execute-dag\",\"state_file\":\"$state_file\",\"sections_dir\":\"$sections_dir\",\"state\":$state_content}"
        else
            echo "{\"status\":\"error\",\"action\":\"execute-dag\",\"error\":\"state_file_not_found\"}"
        fi
    fi
}

# Action: Summarize (Phase 3 of implement - aggregate sections into PRD.md)
action_summarize() {
    local state_file="$REPO_ROOT/.specify/product/state.json"
    local sections_dir="$REPO_ROOT/.specify/product/sections"
    local prd_file="$PRD_LOCATION"
    local pdr_file="$REPO_ROOT/.specify/drafts/pdr.md"
    
    echo "📝 Summarization Phase" >&2
    echo "" >&2
    
    # Check if sections directory exists and has content
    if [[ ! -d "$sections_dir" ]]; then
        echo "❌ Sections directory not found: $sections_dir" >&2
        echo "Run '/product.implement' to generate sections first" >&2
        exit 1
    fi
    
    # Count section files
    local section_count
    section_count=$(find "$sections_dir" -name "*.md" -type f 2>/dev/null | wc -l)
    
    if [[ "$section_count" -eq 0 ]]; then
        echo "❌ No section files found in $sections_dir" >&2
        echo "Run '/product.implement' to generate sections first" >&2
        exit 1
    fi
    
    # List all section files
    echo "📁 Sections directory: $sections_dir" >&2
    echo "   Found $section_count section file(s):" >&2
    find "$sections_dir" -name "*.md" -type f | while read -r f; do
        echo "   - ${f#$sections_dir/}" >&2
    done
    echo "" >&2
    
    echo "Ready for summarization." >&2
    echo "The AI agent will:" >&2
    echo "  1. Read all section files from .specify/product/sections/" >&2
    echo "  2. Detect cross-feature-area conflicts" >&2
    echo "  3. Resolve conflicts using PDRs as source of truth" >&2
    echo "  4. Aggregate into unified PRD.md" >&2
    echo "  5. Move Accepted PDRs to canonical location" >&2
    
    if $JSON_MODE; then
        # Build list of section files
        local sections_json="["
        local first=true
        while IFS= read -r f; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                sections_json+=","
            fi
            local rel_path="${f#$sections_dir/}"
            sections_json+="{\"path\":\"$f\",\"relative\":\"$rel_path\"}"
        done < <(find "$sections_dir" -name "*.md" -type f 2>/dev/null)
        sections_json+="]"
        
        echo "{\"status\":\"success\",\"action\":\"summarize\",\"state_file\":\"$state_file\",\"sections_dir\":\"$sections_dir\",\"prd_file\":\"$prd_file\",\"pdr_file\":\"$pdr_file\",\"section_count\":$section_count,\"sections\":$sections_json}"
    fi
}

case "$COMMAND" in
    "specify")
        if $JSON_MODE; then
            printf '{"REPO_ROOT":"%s","PDR_FILE":"%s","PRD_FILE":"%s","COMMAND":"%s"}' "$REPO_ROOT" "$PDR_LOCATION" "$PRD_LOCATION" "$COMMAND"
        else
            log_info "Setting up for product specification..."
            pdr_path=$(setup_pdr)
            log_info "Ready for PDR creation in $pdr_path"
        fi
        ;;
    "init")
        if $JSON_MODE; then
            subsystem_data=$(detect_subsystems)
            printf '{"REPO_ROOT":"%s","PDR_FILE":"%s","PRD_FILE":"%s","COMMAND":"%s",%s' "$REPO_ROOT" "$PDR_LOCATION" "$PRD_LOCATION" "$COMMAND" "${subsystem_data:1}"
        else
            log_info "Setting up for brownfield discovery..."
            pdr_path=$(setup_pdr)
            log_info "Ready for PDR discovery in $pdr_path"
            detect_subsystems
        fi
        ;;
    "implement")
        if $JSON_MODE; then
            printf '{"REPO_ROOT":"%s","PDR_FILE":"%s","PRD_FILE":"%s","COMMAND":"%s"}' "$REPO_ROOT" "$PDR_LOCATION" "$PRD_LOCATION" "$COMMAND"
        else
            log_info "Setting up for PRD generation..."
            prd_path=$(setup_prd)
            pdr_path=$(setup_pdr)
            log_info "Ready for PRD generation: $prd_path"
        fi
        ;;
    "clarify"|"analyze"|"validate")
        if $JSON_MODE; then
            printf '{"REPO_ROOT":"%s","PDR_FILE":"%s","PRD_FILE":"%s","COMMAND":"%s"}' "$REPO_ROOT" "$PDR_LOCATION" "$PRD_LOCATION" "$COMMAND"
        else
            log_info "Setting up for $COMMAND..."
            pdr_path=$(setup_pdr)
            prd_path=$(setup_prd)
            log_info "Ready for $COMMAND"
        fi
        ;;
    "plan-dag")
        action_plan_dag
        ;;
    "execute-dag")
        action_execute_dag
        ;;
    "summarize")
        action_summarize
        ;;
    "help"|*)
        echo "Product Extension Setup Script"
        echo ""
        echo "Usage: $0 <command> [--json] [--no-decompose]"
        echo ""
        echo "Commands:"
        echo "  specify    Setup for greenfield product specification"
        echo "  init       Setup for brownfield product discovery"
        echo "  implement  Setup for PRD generation"
        echo "  clarify    Setup for PDR refinement"
        echo "  analyze    Setup for consistency analysis"
        echo "  validate   Setup for plan validation"
        echo ""
        echo "DAG Workflow Commands:"
        echo "  plan-dag     Phase 1: Generate DAG execution plan"
        echo "  execute-dag  Phase 2: Execute DAG to generate sections"
        echo "  summarize    Phase 3: Aggregate sections into PRD.md"
        echo ""
        echo "  help       Show this help message"
        ;;
esac
