#!/bin/bash
# implement.sh - Execute the implementation plan with dual execution loop support
# Handles SYNC/ASYNC task classification, LLM delegation, and review enforcement

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/tasks-meta-utils.sh"

# Global variables
FEATURE_DIR=""
AVAILABLE_DOCS=""
TASKS_FILE=""
TASKS_META_FILE=""
CHECKLISTS_DIR=""
IMPLEMENTATION_LOG=""

# Logging functions
log_info() {
    echo "[INFO] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warning() {
    echo "[WARNING] $*" >&2
}

# Initialize implementation environment
init_implementation() {
    local json_output="$1"

    # Parse JSON output from check-prerequisites.sh
    FEATURE_DIR=$(echo "$json_output" | jq -r '.FEATURE_DIR // empty')
    AVAILABLE_DOCS=$(echo "$json_output" | jq -r '.AVAILABLE_DOCS // empty')

    if [[ -z "$FEATURE_DIR" ]]; then
        log_error "FEATURE_DIR not found in prerequisites check"
        exit 1
    fi

    TASKS_FILE="$FEATURE_DIR/tasks.md"
    TASKS_META_FILE="$FEATURE_DIR/tasks_meta.json"
    CHECKLISTS_DIR="$FEATURE_DIR/checklists"

    # Create implementation log
    IMPLEMENTATION_LOG="$FEATURE_DIR/implementation.log"
    echo "# Implementation Log - $(date)" > "$IMPLEMENTATION_LOG"
    echo "" >> "$IMPLEMENTATION_LOG"

    log_info "Initialized implementation for feature: $(basename "$FEATURE_DIR")"
}

# Check checklists status
check_checklists_status() {
    if [[ ! -d "$CHECKLISTS_DIR" ]]; then
        log_info "No checklists directory found - proceeding without checklist validation"
        return 0
    fi

    log_info "Checking checklist status..."

    local total_checklists=0
    local passed_checklists=0
    local failed_checklists=0

    echo "## Checklist Status Report" >> "$IMPLEMENTATION_LOG"
    echo "" >> "$IMPLEMENTATION_LOG"
    echo "| Checklist | Total | Completed | Incomplete | Status |" >> "$IMPLEMENTATION_LOG"
    echo "|-----------|-------|-----------|------------|--------|" >> "$IMPLEMENTATION_LOG"

    for checklist_file in "$CHECKLISTS_DIR"/*.md; do
        if [[ ! -f "$checklist_file" ]]; then
            continue
        fi

        local filename=$(basename "$checklist_file" .md)
        local total_items=$(grep -c "^- \[" "$checklist_file" || echo "0")
        local completed_items=$(grep -c "^- \[X\]\|^- \[x\]" "$checklist_file" || echo "0")
        local incomplete_items=$((total_items - completed_items))

        local status="PASS"
        if [[ $incomplete_items -gt 0 ]]; then
            status="FAIL"
            failed_checklists=$((failed_checklists + 1))
        else
            passed_checklists=$((passed_checklists + 1))
        fi

        total_checklists=$((total_checklists + 1))

        echo "| $filename | $total_items | $completed_items | $incomplete_items | $status |" >> "$IMPLEMENTATION_LOG"
    done

    echo "" >> "$IMPLEMENTATION_LOG"

    if [[ $failed_checklists -gt 0 ]]; then
        log_warning "Found $failed_checklists checklist(s) with incomplete items"
        echo "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no): "
        read -r response
        if [[ ! "$response" =~ ^(yes|y)$ ]]; then
            log_info "Implementation cancelled by user"
            exit 0
        fi
    else
        log_success "All $total_checklists checklists passed"
    fi
}

# Load implementation context
load_implementation_context() {
    log_info "Loading implementation context..."

    # Require all artifacts
    local required_files=("tasks.md" "spec.md" "plan.md")

    for file in "${required_files[@]}"; do
        if [[ ! -f "$FEATURE_DIR/$file" ]]; then
            log_error "Required file missing: $FEATURE_DIR/$file"
            exit 1
        fi
    done

    # Optional files
    local optional_files=("data-model.md" "contracts/" "research.md" "quickstart.md")

    for file in "${optional_files[@]}"; do
        if [[ -f "$FEATURE_DIR/$file" ]] || [[ -d "$FEATURE_DIR/$file" ]]; then
            log_info "Found optional context: $file"
        fi
    done
}

# Parse tasks from tasks.md
parse_tasks() {
    log_info "Parsing tasks from $TASKS_FILE..."

    # Extract tasks with their metadata
    # This is a simplified parser - in practice, you'd want more robust parsing
    local task_lines
    task_lines=$(grep -n "^- \[ \] T[0-9]\+" "$TASKS_FILE" || true)

    if [[ -z "$task_lines" ]]; then
        log_warning "No uncompleted tasks found in $TASKS_FILE"
        return 0
    fi

    echo "$task_lines" | while IFS=: read -r line_num task_line; do
        # Extract task ID, description, and markers
        local task_id
        task_id=$(echo "$task_line" | sed -n 's/.*\(T[0-9]\+\).*/\1/p')

        local description
        description=$(echo "$task_line" | sed 's/^- \[ \] T[0-9]\+ //' | sed 's/\[.*\]//g' | xargs)

        local execution_mode="SYNC"  # Default
        if echo "$task_line" | grep -q "\[ASYNC\]"; then
            execution_mode="ASYNC"
        fi

        local parallel_marker=""
        if echo "$task_line" | grep -q "\[P\]"; then
            parallel_marker="P"
        fi

        # Extract file paths (simplified - look for file extensions in the task)
        local task_files=""
        task_files=$(echo "$task_line" | grep -oE '\b\w+\.(js|ts|py|java|cpp|md|json|yml|yaml)\b' | tr '\n' ' ' | xargs || echo "")

        log_info "Found task $task_id: $description [$execution_mode] ${parallel_marker:+$parallel_marker }($task_files)"

        # Classify and add to tasks_meta.json
        local classified_mode
        classified_mode=$(classify_task_execution_mode "$description" "$task_files")

        # Override with explicit marker if present
        if [[ "$execution_mode" == "ASYNC" ]]; then
            classified_mode="ASYNC"
        fi

        add_task "$TASKS_META_FILE" "$task_id" "$description" "$task_files" "$classified_mode"
    done
}

# Execute task with dual execution loop
execute_task() {
    local task_id="$1"
    local execution_mode
    execution_mode=$(jq -r ".tasks[\"$task_id\"].execution_mode" "$TASKS_META_FILE")

    log_info "Executing task $task_id in $execution_mode mode"

    if [[ "$execution_mode" == "ASYNC" ]]; then
        # Generate delegation prompt for LLM
        local task_description
        task_description=$(jq -r ".tasks[\"$task_id\"].description" "$TASKS_META_FILE")
        local task_files
        task_files=$(jq -r ".tasks[\"$task_id\"].files // empty" "$TASKS_META_FILE")
        local agent_type
        agent_type=$(jq -r ".tasks[\"$task_id\"].agent_type // \"general\"" "$TASKS_META_FILE")

        # Check if using local orchestrator (agentic-sdlc-agent-runner)
        if [[ "$agent_type" == "agentic-sdlc-agent-runner" ]]; then
            # Use local K8s runner
            log_info "Spawning K8s pod via agentic-sdlc-agent-runner for task $task_id"
            
            # Get repository info
            local repo_url
            repo_url=$(git remote get-url origin 2>/dev/null || echo "")
            local branch_name
            branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
            
            # Find the orchestrator spawn-pod.sh script
            local orchestrator_script=""
            if [[ -f "$FEATURE_DIR/scripts/spawn-pod.sh" ]]; then
                orchestrator_script="$FEATURE_DIR/scripts/spawn-pod.sh"
            elif [[ -f "./scripts/spawn-pod.sh" ]]; then
                orchestrator_script="./scripts/spawn-pod.sh"
            elif command -v agentic-sdlc-agent-runner &>/dev/null; then
                # Try to find spawn-pod.sh relative to the installed CLI
                local cli_path
                cli_path=$(which agentic-sdlc-agent-runner)
                local cli_dir
                cli_dir=$(dirname "$cli_path")
                if [[ -f "$cli_dir/../scripts/spawn-pod.sh" ]]; then
                    orchestrator_script="$cli_dir/../scripts/spawn-pod.sh"
                fi
            fi
            
            if [[ -n "$orchestrator_script" && -f "$orchestrator_script" ]]; then
                log_info "Using orchestrator script: $orchestrator_script"
                "$orchestrator_script" \
                    --task-id "$task_id" \
                    --branch "specs/$(basename "$FEATURE_DIR")/${task_id}-async" \
                    --repo "$repo_url" \
                    --context-dir "$FEATURE_DIR"
                
                if [[ $? -eq 0 ]]; then
                    log_success "K8s pod spawned for task $task_id"
                    safe_json_update "$TASKS_META_FILE" --arg task_id "$task_id" '.tasks[$task_id].status = "running"'
                else
                    handle_task_failure "$task_id" "Failed to spawn K8s pod"
                fi
            else
                log_warn "agentic-sdlc-agent-runner script not found. Expected at: ./scripts/spawn-pod.sh"
                log_info "Please ensure the agentic-sdlc-agent-runner repository is cloned and scripts are available"
                log_info "Falling back to standard async delegation"
                # Fall back to standard dispatch_async_task
                local task_context="Files: $task_files"
                local task_requirements="Complete the task according to specifications"
                local execution_instructions="Execute the task and provide detailed results"

                if dispatch_async_task "$task_id" "$agent_type" "$task_description" "$task_context" "$task_requirements" "$execution_instructions" "$FEATURE_DIR"; then
                    log_success "ASYNC task $task_id dispatched successfully"
                else
                    handle_task_failure "$task_id" "Failed to dispatch ASYNC task"
                fi
            fi
        else
            # Standard async delegation (MCP agents like jules, async-copilot, async-codex)
            local task_context="Files: $task_files"
            local task_requirements="Complete the task according to specifications"
            local execution_instructions="Execute the task and provide detailed results"

            if dispatch_async_task "$task_id" "$agent_type" "$task_description" "$task_context" "$task_requirements" "$execution_instructions" "$FEATURE_DIR"; then
                log_success "ASYNC task $task_id dispatched successfully"
            else
                handle_task_failure "$task_id" "Failed to dispatch ASYNC task"
            fi
        fi
    else
        # Execute SYNC task (would normally involve AI agent execution)
        log_info "SYNC task $task_id would be executed here (simulated)"

        # Simulate execution success/failure (in real implementation, check actual execution result)
        local execution_success=true

        if [[ "$execution_success" == "true" ]]; then
            # Mark as completed (in real implementation, this would happen after successful execution)
            safe_json_update "$TASKS_META_FILE" --arg task_id "$task_id" '.tasks[$task_id].status = "completed"'

            # Spec mode: Always perform blocking micro-review gate
            perform_micro_review "$TASKS_META_FILE" "$task_id"
        else
            handle_task_failure "$task_id" "SYNC task execution failed"
        fi
    fi

    # Apply quality gates
    apply_quality_gates "$TASKS_META_FILE" "$task_id"
}

# Monitor ASYNC tasks
monitor_async_tasks() {
    log_info "Monitoring ASYNC tasks..."

    local async_tasks
    async_tasks=$(jq -r '.tasks | to_entries[] | select(.value.execution_mode == "ASYNC" and .value.status != "completed") | .key' "$TASKS_META_FILE")

    if [[ -z "$async_tasks" ]]; then
        log_info "No ASYNC tasks to monitor"
        return 0
    fi

    echo "$async_tasks" | while read -r task_id; do
        if [[ -z "$task_id" ]]; then
            continue
        fi

        local status
        status=$(check_delegation_status "$task_id")

        case "$status" in
            "completed")
                log_success "ASYNC task $task_id completed"
                # Mark as completed in tasks_meta.json
                safe_json_update "$TASKS_META_FILE" --arg task_id "$task_id" '.tasks[$task_id].status = "completed"'
                # Perform macro-review for completed ASYNC tasks
                perform_macro_review "$TASKS_META_FILE"
                ;;
            "running")
                log_info "ASYNC task $task_id still running"
                ;;
            "failed")
                log_error "ASYNC task $task_id failed"
                # Handle failure with rollback options
                handle_task_failure "$task_id" "ASYNC task execution failed"
                ;;
            "no_job")
                log_warning "ASYNC task $task_id has no delegation response"
                ;;
        esac
    done
}

# Main implementation workflow
main() {
    local json_output="$1"

    init_implementation "$json_output"
    check_checklists_status
    load_implementation_context

    # Initialize tasks_meta.json if needed
    if [[ ! -f "$TASKS_META_FILE" ]]; then
        init_tasks_meta "$FEATURE_DIR"
    fi

    parse_tasks

    # Execute tasks (simplified - in practice would handle phases and dependencies)
    local pending_tasks
    pending_tasks=$(jq -r '.tasks | to_entries[] | select(.value.status == "pending") | .key' "$TASKS_META_FILE")

    if [[ -n "$pending_tasks" ]]; then
        echo "$pending_tasks" | while read -r task_id; do
            if [[ -z "$task_id" ]]; then
                continue
            fi
            execute_task "$task_id"
        done
    fi

    # Monitor ASYNC tasks
    monitor_async_tasks

    # Check if all tasks are completed for macro-review
    local all_completed
    all_completed=$(jq '.tasks | all(.status == "completed")' "$TASKS_META_FILE")

    if [[ "$all_completed" == "true" ]]; then
        log_info "All tasks completed - performing macro-review"
        perform_macro_review "$TASKS_META_FILE"

        # Offer documentation evolution after successful implementation
        log_info "Offering documentation evolution based on implementation learnings"
        offer_documentation_evolution "$FEATURE_DIR"
    else
        log_info "Some tasks still pending - macro-review deferred until completion"
    fi

    # Generate summary
    get_execution_summary "$TASKS_META_FILE"

    log_success "Implementation phase completed"
}

# Offer documentation evolution after implementation
offer_documentation_evolution() {
    local feature_dir="$1"

    log_info "Analyzing implementation for documentation evolution opportunities..."

    # Analyze implementation changes
    local analysis_results
    analysis_results=$(analyze_implementation_changes "$feature_dir")

    # Check if there are significant changes worth documenting
    if echo "$analysis_results" | grep -q "new features\|architecture\|refinements\|additional tasks"; then
        log_info "Implementation changes detected - offering documentation evolution"

        # Propose documentation updates
        local proposals
        proposals=$(propose_documentation_updates "$feature_dir" "$analysis_results")

        echo "## Documentation Evolution Available
$proposals

Would you like to apply these documentation updates? (yes/no): "
        read -r response
        if [[ "$response" =~ ^(yes|y)$ ]]; then
            apply_recommended_updates "$feature_dir" "$analysis_results"
        else
            log_info "Documentation evolution skipped by user"
        fi
    else
        log_info "No significant documentation evolution needed"
    fi
}

# Apply recommended documentation updates
apply_recommended_updates() {
    local feature_dir="$1"
    local analysis_results="$2"

    # Apply spec updates if new features detected
    if echo "$analysis_results" | grep -q "new features\|new API\|new components"; then
        echo "What new features should be added to spec.md? (describe or 'skip'): "
        read -r spec_updates
        if [[ "$spec_updates" != "skip" ]]; then
            apply_documentation_updates "$feature_dir" "spec" "$spec_updates"
        fi
    fi

    # Apply plan updates if architecture changes detected
    if echo "$analysis_results" | grep -q "architecture\|performance\|security"; then
        echo "What architecture changes should be documented in plan.md? (describe or 'skip'): "
        read -r plan_updates
        if [[ "$plan_updates" != "skip" ]]; then
            apply_documentation_updates "$feature_dir" "plan" "$plan_updates"
        fi
    fi

    # Apply task updates if refinements detected
    if echo "$analysis_results" | grep -q "additional tasks\|refinements"; then
        echo "What refinement tasks should be added to tasks.md? (describe or 'skip'): "
        read -r task_updates
        if [[ "$task_updates" != "skip" ]]; then
            apply_documentation_updates "$feature_dir" "tasks" "$task_updates"
        fi
    fi

    log_success "Documentation evolution completed"
}

# Handle task failure with enhanced rollback options
handle_task_failure() {
    local task_id="$1"
    local failure_reason="$2"

    log_warning "Task $task_id failed: $failure_reason"

    # Use standard mode for rollback
    local mode="spec"

    echo "Task $task_id failed. Options:
1. Retry task
2. Rollback task and continue
3. Rollback entire feature and regenerate tasks
4. Regenerate plan and tasks
5. Skip and continue
Choose (1-5): "
    read -r choice

    case "$choice" in
        1)
            log_info "Retrying task $task_id"
            # Reset task status to pending
            safe_json_update "$TASKS_META_FILE" --arg task_id "$task_id" '.tasks[$task_id].status = "pending"'
            ;;
        2)
            log_info "Rolling back task $task_id"
            execute_rollback "$FEATURE_DIR" "task" "$task_id"
            ensure_documentation_consistency "$FEATURE_DIR"
            ;;
        3)
            log_info "Rolling back entire feature and regenerating tasks"
            execute_rollback "$FEATURE_DIR" "feature"
            regenerate_tasks_after_rollback "$FEATURE_DIR" "$failure_reason"
            ensure_documentation_consistency "$FEATURE_DIR"
            ;;
        4)
            log_info "Regenerating plan and tasks after failure analysis"
            regenerate_plan "$FEATURE_DIR" "Task failure: $failure_reason"
            regenerate_tasks_after_rollback "$FEATURE_DIR" "$failure_reason"
            ;;
        5)
            log_info "Skipping failed task $task_id"
            safe_json_update "$TASKS_META_FILE" --arg task_id "$task_id" '.tasks[$task_id].status = "skipped"'
            ;;
        *)
            log_warning "Invalid choice, skipping task"
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <json_output_from_check_prerequisites>"
        exit 1
    fi
    main "$1"
fi