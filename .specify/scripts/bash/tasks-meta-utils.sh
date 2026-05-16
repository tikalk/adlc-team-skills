#!/bin/bash

# Task Meta Utilities for Agentic SDLC
# Handles task classification, delegation, and status tracking

# Get the global config path using XDG Base Directory spec
get_global_config_path() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    echo "$config_home/specify/config.json"
}

# Get project-level config path (.specify/config.json)
get_project_config_path() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        local repo_root=$(git rev-parse --show-toplevel)
        echo "$repo_root/.specify/config.json"
    else
        echo ".specify/config.json"
    fi
}

# Get config path with hierarchical resolution
get_config_path() {
    local project_config=$(get_project_config_path)
    local user_config=$(get_global_config_path)
    
    if [[ -f "$project_config" ]]; then
        echo "$project_config"
    elif [[ -f "$user_config" ]]; then
        echo "$user_config"
    else
        echo "$project_config"
    fi
}

# Initialize tasks_meta.json for a feature
init_tasks_meta() {
    local feature_dir="$1"
    local tasks_meta_file="$feature_dir/tasks_meta.json"

    # Create basic structure
    cat > "$tasks_meta_file" << EOF
{
    "feature": "$(basename "$feature_dir")",
    "created": "$(date -Iseconds)",
    "tasks": {}
}
EOF

    echo "Initialized tasks_meta.json at $tasks_meta_file"
}

# Classify task execution mode (SYNC/ASYNC)
classify_task_execution_mode() {
    local description="$1"
    local files="$2"

    # Simple classification logic
    # ASYNC if description contains certain keywords or involves multiple files
    if echo "$description" | grep -qi "research\|analyze\|design\|plan\|review\|test"; then
        echo "ASYNC"
    elif [[ $(echo "$files" | wc -w) -gt 2 ]]; then
        echo "ASYNC"
    else
        echo "SYNC"
    fi
}

# Add task to tasks_meta.json
add_task() {
    local tasks_meta_file="$1"
    local task_id="$2"
    local description="$3"
    local files="$4"
    local execution_mode="$5"

    # Use jq if available, otherwise create manually
    if command -v jq >/dev/null 2>&1; then
        jq --arg task_id "$task_id" \
           --arg desc "$description" \
           --arg files "$files" \
           --arg mode "$execution_mode" \
           '.tasks[$task_id] = {
               "description": $desc,
               "files": $files,
               "execution_mode": $mode,
               "status": "pending",
               "agent_type": "general"
           }' "$tasks_meta_file" > "${tasks_meta_file}.tmp" && mv "${tasks_meta_file}.tmp" "$tasks_meta_file"
    else
        # Fallback without jq - just log for now
        echo "Added task $task_id ($execution_mode) to $tasks_meta_file"
    fi
}

# Generate comprehensive agent context
generate_agent_context() {
    local feature_dir="$1"

    local context="## Project Context

"

    # Add spec.md content
    if [[ -f "$feature_dir/spec.md" ]]; then
        context="${context}### Feature Specification
$(cat "$feature_dir/spec.md")

"
    fi

    # Add plan.md content
    if [[ -f "$feature_dir/plan.md" ]]; then
        context="${context}### Technical Plan
$(cat "$feature_dir/plan.md")

"
    fi

    # Add data-model.md if exists
    if [[ -f "$feature_dir/data-model.md" ]]; then
        context="${context}### Data Model
$(cat "$feature_dir/data-model.md")

"
    fi

    # Add research.md if exists
    if [[ -f "$feature_dir/research.md" ]]; then
        context="${context}### Research & Decisions
$(cat "$feature_dir/research.md")

"
    fi

    # Add contracts if exists
    if [[ -d "$feature_dir/contracts" ]]; then
        context="${context}### API Contracts
"
        for contract_file in "$feature_dir/contracts"/*.md; do
            if [[ -f "$contract_file" ]]; then
                context="${context}#### $(basename "$contract_file" .md)
$(cat "$contract_file")

"
            fi
        done
    fi

    # Add team context if available
    if [[ -f "constitution.md" ]]; then
        context="${context}### Team Constitution
$(head -50 constitution.md)

"
    fi

    echo "$context"
}

# Generate delegation prompt from task metadata with rich context
generate_delegation_prompt() {
    local task_id="$1"
    local agent_type="$2"
    local task_description="$3"
    local task_context="$4"
    local task_requirements="$5"
    local execution_instructions="$6"
    local feature_dir="$7"

    # Read template
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_file="$script_dir/../../templates/delegation-template.md"
    if [[ ! -f "$template_file" ]]; then
        echo "Error: Delegation template not found at $template_file" >&2
        return 1
    fi

    local template_content
    template_content=$(cat "$template_file")

    # Generate comprehensive context
    local agent_context
    agent_context=$(generate_agent_context "$feature_dir")

    # Combine task context with agent context
    local full_context="${task_context}

${agent_context}"

    # Substitute variables using awk to handle multiline content safely
    local prompt
    prompt=$(awk -v agent_type="$agent_type" \
                 -v task_description="$task_description" \
                 -v full_context="$full_context" \
                 -v task_requirements="$task_requirements" \
                 -v execution_instructions="$execution_instructions" \
                 -v task_id="$task_id" \
                 -v timestamp="$(date)" '
    {
        gsub(/{AGENT_TYPE}/, agent_type);
        gsub(/{TASK_DESCRIPTION}/, task_description);
        gsub(/{TASK_CONTEXT}/, full_context);
        gsub(/{TASK_REQUIREMENTS}/, task_requirements);
        gsub(/{EXECUTION_INSTRUCTIONS}/, execution_instructions);
        gsub(/{TASK_ID}/, task_id);
        gsub(/{TIMESTAMP}/, timestamp);
        print;
    }' <<< "$template_content")

    echo "$prompt"
}

# Check delegation status
check_delegation_status() {
    local task_id="$1"

    # Check if prompt exists (task was delegated)
    local prompt_file="delegation_prompts/${task_id}.md"
    if [[ ! -f "$prompt_file" ]]; then
        echo "no_job"
        return 0
    fi

    # Check for completion marker (AI assistant would create this)
    local completion_file="delegation_completed/${task_id}.txt"
    if [[ -f "$completion_file" ]]; then
        echo "completed"
        return 0
    fi

    # Check for error marker
    local error_file="delegation_errors/${task_id}.txt"
    if [[ -f "$error_file" ]]; then
        echo "failed"
        return 0
    fi

    # Otherwise, assume still running
    echo "running"
}

# Dispatch async task using natural language delegation with rich context
dispatch_async_task() {
    local task_id="$1"
    local agent_type="$2"
    local task_description="$3"
    local task_context="$4"
    local task_requirements="$5"
    local execution_instructions="$6"
    local feature_dir="$7"

    # Generate natural language delegation prompt with comprehensive context
    local prompt
    prompt=$(generate_delegation_prompt "$task_id" "$agent_type" "$task_description" "$task_context" "$task_requirements" "$execution_instructions" "$feature_dir")

    if [[ $? -ne 0 ]]; then
        echo "Failed to generate delegation prompt" >&2
        return 1
    fi

    # Save prompt for AI assistant consumption
    # The AI assistant with MCP tool access will process this prompt
    local prompt_file="delegation_prompts/${task_id}.md"
    mkdir -p delegation_prompts
    echo "$prompt" > "$prompt_file"

    echo "Task $task_id delegated successfully - comprehensive prompt saved for AI assistant"
}

# Analyze implementation changes vs documentation for evolution
analyze_implementation_changes() {
    local feature_dir="$1"
    local spec_file="$feature_dir/spec.md"
    local plan_file="$feature_dir/plan.md"
    local tasks_file="$feature_dir/tasks.md"

    local changes="## Implementation vs Documentation Analysis
"

    # Check for new features in code not in spec
    if [[ -d "src" ]] || [[ -d "lib" ]] || find . -name "*.js" -o -name "*.ts" -o -name "*.py" | grep -q .; then
        changes="${changes}### Potential New Features
- Scan codebase for implemented functionality not documented in spec.md
- Check for new API endpoints, UI components, or business logic
- Identify user flows that may have evolved during implementation

"
    fi

    # Check for architecture changes
    if [[ -f "$plan_file" ]]; then
        changes="${changes}### Architecture Evolution
- Compare implemented architecture against plan.md
- Identify performance optimizations or security enhancements
- Note technology stack changes or library updates

"
    fi

    # Check for completed tasks that might indicate refinements
    if [[ -f "$tasks_file" ]]; then
        local completed_tasks
        completed_tasks=$(grep -c "^- \[X\]" "$tasks_file" || echo "0")
        local total_tasks
        total_tasks=$(grep -c "^- \[.\]" "$tasks_file" || echo "0")

        changes="${changes}### Task Completion Status
- Completed: $completed_tasks / $total_tasks tasks
- Check for additional tasks added during implementation
- Identify refinements or bug fixes that emerged

"
    fi

    echo "$changes"
}

# Propose documentation updates based on implementation analysis
propose_documentation_updates() {
    local feature_dir="$1"
    local analysis_results="$2"

    local proposals="## Documentation Evolution Proposals

Based on implementation analysis, here are recommended documentation updates:

"

    # Check if there are undocumented features
    if echo "$analysis_results" | grep -q "new features\|new API\|new components"; then
        proposals="${proposals}### Spec.md Updates
- Add newly implemented features to functional requirements
- Document discovered edge cases and user experience insights
- Update acceptance criteria based on actual implementation

"
    fi

    # Check for architecture changes
    if echo "$analysis_results" | grep -q "architecture\|performance\|security"; then
        proposals="${proposals}### Plan.md Updates
- Document architecture changes made during implementation
- Add performance optimizations and their rationale
- Update technology decisions based on implementation experience

"
    fi

    # Check for task additions
    if echo "$analysis_results" | grep -q "additional tasks\|refinements"; then
        proposals="${proposals}### Tasks.md Updates
- Add follow-up tasks for refinements discovered during implementation
- Document bug fixes and improvements made
- Update task status and add completion notes

"
    fi

    proposals="${proposals}### Evolution Guidelines
- Preserve original requirements while incorporating implementation learnings
- Maintain traceability between documentation and code
- Version documentation changes with clear rationale
- Ensure constitution compliance for any new requirements

"

    echo "$proposals"
}

# Apply documentation updates with user confirmation
apply_documentation_updates() {
    local feature_dir="$1"
    local update_type="$2"  # spec, plan, tasks
    local update_content="$3"

    case "$update_type" in
        "spec")
            local spec_file="$feature_dir/spec.md"
            echo "## Implementation Learnings - $(date)" >> "$spec_file"
            echo "" >> "$spec_file"
            echo "$update_content" >> "$spec_file"
            echo "Updated spec.md with implementation insights"
            ;;
        "plan")
            local plan_file="$feature_dir/plan.md"
            echo "## Architecture Evolution - $(date)" >> "$plan_file"
            echo "" >> "$plan_file"
            echo "$update_content" >> "$plan_file"
            echo "Updated plan.md with architecture changes"
            ;;
        "tasks")
            local tasks_file="$feature_dir/tasks.md"
            echo "" >> "$tasks_file"
            echo "## Refinement Tasks - $(date)" >> "$tasks_file"
            echo "$update_content" >> "$tasks_file"
            echo "Added refinement tasks to tasks.md"
            ;;
        *)
            echo "Unknown update type: $update_type" >&2
            return 1
            ;;
    esac
}

# Rollback individual task while preserving documentation
rollback_task() {
    local tasks_meta_file="$1"
    local task_id="$2"
    local preserve_docs="${3:-true}"

    echo "Rolling back task: $task_id"

    # Get task information before rollback
    local task_description=""
    local task_files=""
    if command -v jq >/dev/null 2>&1; then
        task_description=$(jq -r ".tasks[\"$task_id\"].description // empty" "$tasks_meta_file")
        task_files=$(jq -r ".tasks[\"$task_id\"].files // empty" "$tasks_meta_file")
    fi

    # Mark task as rolled back in metadata
    if command -v jq >/dev/null 2>&1; then
        jq --arg task_id "$task_id" '.tasks[$task_id].status = "rolled_back"' "$tasks_meta_file" > "${tasks_meta_file}.tmp" && \
        mv "${tasks_meta_file}.tmp" "$tasks_meta_file"
    fi

    # Attempt to revert code changes (simplified - would need proper git integration)
    if [[ -n "$task_files" ]]; then
        echo "Attempting to revert changes to files: $task_files"
        # In a real implementation, this would use git checkout or similar
        echo "Note: Manual code reversion may be required for files: $task_files"
    fi

    # Log rollback details
    local feature_dir
    feature_dir=$(dirname "$tasks_meta_file")
    echo "## Task Rollback - $(date)" >> "$feature_dir/rollback.log"
    echo "Task ID: $task_id" >> "$feature_dir/rollback.log"
    echo "Description: $task_description" >> "$feature_dir/rollback.log"
    echo "Files: $task_files" >> "$feature_dir/rollback.log"
    echo "Documentation Preserved: $preserve_docs" >> "$feature_dir/rollback.log"
    echo "" >> "$feature_dir/rollback.log"

    echo "Task $task_id rolled back successfully"

    if [[ "$preserve_docs" == "true" ]]; then
        echo "Documentation preserved for rolled back task $task_id"
    fi
}

# Rollback entire feature implementation
rollback_feature() {
    local feature_dir="$1"
    local preserve_docs="${2:-true}"

    echo "Rolling back entire feature: $(basename "$feature_dir")"

    local tasks_meta_file="$feature_dir/tasks_meta.json"

    if [[ -f "$tasks_meta_file" ]]; then
        # Mark all tasks as rolled back
        if command -v jq >/dev/null 2>&1; then
            jq '.tasks |= map_values(.status = "rolled_back")' "$tasks_meta_file" > "${tasks_meta_file}.tmp" && \
            mv "${tasks_meta_file}.tmp" "$tasks_meta_file"
        fi
    fi

    # Remove implementation artifacts
    rm -f "$feature_dir/implementation.log"
    rm -rf "$feature_dir/checklists"

    # Log comprehensive rollback
    echo "## Feature Rollback - $(date)" >> "$feature_dir/rollback.log"
    echo "Feature: $(basename "$feature_dir")" >> "$feature_dir/rollback.log"
    echo "All tasks marked as rolled back" >> "$feature_dir/rollback.log"
    echo "Implementation artifacts removed" >> "$feature_dir/rollback.log"
    echo "Documentation Preserved: $preserve_docs" >> "$feature_dir/rollback.log"
    echo "" >> "$feature_dir/rollback.log"

    echo "Feature $(basename "$feature_dir") implementation rolled back"

    if [[ "$preserve_docs" == "true" ]]; then
        echo "Documentation preserved during feature rollback"
    fi
}

# Regenerate tasks after rollback with corrected approach
regenerate_tasks_after_rollback() {
    local feature_dir="$1"
    local rollback_reason="$2"

    local tasks_file="$feature_dir/tasks.md"
    local tasks_meta_file="$feature_dir/tasks_meta.json"

    # Add new tasks for corrected implementation
    echo "" >> "$tasks_file"
    echo "## Corrected Implementation Tasks - $(date)" >> "$tasks_file"
    echo "" >> "$tasks_file"
    echo "- [ ] T_CORRECT_001 Apply corrected implementation approach based on: $rollback_reason" >> "$tasks_file"
    echo "- [ ] T_CORRECT_002 Verify fixes address root cause of rollback" >> "$tasks_file"
    echo "- [ ] T_CORRECT_003 Test corrected implementation thoroughly" >> "$tasks_file"

    # Reinitialize tasks metadata
    if [[ -f "$tasks_meta_file" ]]; then
        # Reset rolled back tasks to pending for retry
        if command -v jq >/dev/null 2>&1; then
            jq '.tasks |= map_values(if .status == "rolled_back" then .status = "pending" else . end)' "$tasks_meta_file" > "${tasks_meta_file}.tmp" && \
            mv "${tasks_meta_file}.tmp" "$tasks_meta_file"
        fi
    fi

    echo "Regenerated tasks for corrected implementation approach"
}





# Regenerate plan based on current specifications and implementation learnings
regenerate_plan() {
    local feature_dir="$1"
    local reason="$2"

    local spec_file="$feature_dir/spec.md"
    local plan_file="$feature_dir/plan.md"

    echo "Regenerating plan for feature: $(basename "$feature_dir")"
    echo "Reason: $reason"

    if [[ ! -f "$spec_file" ]]; then
        echo "Error: Cannot regenerate plan without spec.md"
        return 1
    fi

    # Backup original plan
    if [[ -f "$plan_file" ]]; then
        cp "$plan_file" "${plan_file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Original plan backed up"
    fi

    # Create regeneration template
    cat > "$plan_file" << EOF
# Implementation Plan - Regenerated $(date)
## Reason for Regeneration
$reason

## Original Specification Context
$(head -20 "$spec_file")

## Architecture Decisions
<!-- Regenerate based on current spec and implementation learnings -->

## Technical Stack
<!-- Update based on implementation experience -->

## Component Design
<!-- Refine based on actual implementation needs -->

## Data Model
<!-- Adjust based on real-world usage patterns -->

## Implementation Phases
<!-- Reorganize based on lessons learned -->

## Risk Mitigation
<!-- Update based on encountered issues -->

## Success Metrics
<!-- Refine based on implementation insights -->
EOF

    # Log regeneration
    echo "## Plan Regeneration - $(date)" >> "$feature_dir/rollback.log"
    echo "Reason: $reason" >> "$feature_dir/rollback.log"
    echo "Original plan backed up" >> "$feature_dir/rollback.log"
    echo "New plan template created for regeneration" >> "$feature_dir/rollback.log"
    echo "" >> "$feature_dir/rollback.log"

    echo "Plan regeneration template created. Manual editing required to complete regeneration."
    echo "Original plan backed up for reference."
}

# Ensure documentation consistency after rollback
ensure_documentation_consistency() {
    local feature_dir="$1"

    echo "Ensuring documentation consistency after rollback..."

    local spec_file="$feature_dir/spec.md"
    local plan_file="$feature_dir/plan.md"
    local tasks_file="$feature_dir/tasks.md"

    # Check for consistency issues
    local issues_found=false

    # Check if plan references tasks that no longer exist
    if [[ -f "$plan_file" ]] && [[ -f "$tasks_file" ]]; then
        # This is a simplified check - in practice would need more sophisticated analysis
        if grep -q "T[0-9]" "$plan_file" && ! grep -q "T[0-9]" "$tasks_file"; then
            echo "⚠️  Plan references tasks that may no longer exist"
            issues_found=true
        fi
    fi

    # Check for implementation references in docs after rollback
    if [[ -f "$spec_file" ]] && grep -q "implementation\|code\|deploy" "$spec_file"; then
        echo "⚠️  Spec contains implementation details that should be reviewed"
        issues_found=true
    fi

    if [[ "$issues_found" == "false" ]]; then
        echo "✅ Documentation consistency verified"
    else
        echo "⚠️  Some documentation consistency issues detected"
        echo "Consider running '/analyze' to identify specific issues"
    fi
}

# Execute rollback
execute_rollback() {
    local feature_dir="$1"
    local rollback_type="$2"
    local task_id="${3:-}"  # Optional task_id for task rollback

    echo "Executing rollback for $rollback_type"

    case "$rollback_type" in
        "task")
            if [[ -z "$task_id" ]]; then
                echo "ERROR: task_id required for task rollback" >&2
                return 1
            fi
            rollback_task "$feature_dir/tasks_meta.json" "$task_id" "true"
            ;;
        "feature")
            rollback_feature "$feature_dir" "true"
            ;;
        *)
            echo "ERROR: Unknown rollback type: $rollback_type" >&2
            return 1
            ;;
    esac
}

# Generate tasks with configurable opinions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        generate_delegation_prompt)
            shift
            generate_delegation_prompt "$@"
            ;;
        check_delegation_status)
            shift
            check_delegation_status "$@"
            ;;
        dispatch_async_task)
            shift
            dispatch_async_task "$@"
            ;;
        analyze_implementation_changes)
            shift
            analyze_implementation_changes "$@"
            ;;
        propose_documentation_updates)
            shift
            propose_documentation_updates "$@"
            ;;
        apply_documentation_updates)
            shift
            apply_documentation_updates "$@"
            ;;
        rollback_task)
            shift
            rollback_task "$@"
            ;;
        rollback_feature)
            shift
            rollback_feature "$@"
            ;;
        regenerate_tasks_after_rollback)
            shift
            regenerate_tasks_after_rollback "$@"
            ;;
        execute_rollback)
            shift
            execute_rollback "$@"
            ;;
        *)
            echo "Usage: $0 {generate_delegation_prompt|check_delegation_status|dispatch_async_task|analyze_implementation_changes|propose_documentation_updates|apply_documentation_updates|rollback_task|rollback_feature|regenerate_tasks_after_rollback|regenerate_plan|ensure_documentation_consistency|execute_rollback} [args...]"
            exit 1
            ;;
    esac
fi