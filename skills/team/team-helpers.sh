#!/usr/bin/env bash
# team-helpers.sh — Shared utilities for team-* skills
# 
# Flags:
#   --json              Output path info as JSON (default: key=value)
#   --scaffold [DIR]    Create a fresh 11-file team AI directives scaffold at DIR
#   --agents-only DIR   Create only AGENTS.md at DIR (for repair use)
#   --inject-agents [DIR]  Inject team-boot directive into project-level AGENTS.md at DIR
#   --name NAME         Team name for scaffold (default: "My Team")
#
# Library functions (sourced by other skills' setup scripts, not CLI flags):
#   resolve_sdd_docs_location, sdd_project_subfolder_name, git_publish_workflow
set -euo pipefail

###############################################################################
# 1. PATH RESOLUTION
###############################################################################

resolve_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$([[ -d ".adlc" ]] && pwd || git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
  TEAM_AI_DIRECTIVES=""

  # 1. Check TEAM_AI_DIRECTIVES env var (highest priority)
  if [[ -n "${TEAM_AI_DIRECTIVES:-}" ]]; then
    TEAM_AI_DIRECTIVES="$TEAM_AI_DIRECTIVES"
  fi

  # 2. Check .adlc/init-options.json
  if [[ -z "$TEAM_AI_DIRECTIVES" ]]; then
    INIT_OPTIONS="${PROJECT_ROOT}/.adlc/init-options.json"
    if [[ -f "$INIT_OPTIONS" ]]; then
      TEAM_AI_DIRECTIVES=$(python3 -c "
import json, sys
try:
    with open('$INIT_OPTIONS') as f:
        print(json.load(f).get('team_ai_directives', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    fi
  fi

  # 3. Fallback to default path
  if [[ -z "$TEAM_AI_DIRECTIVES" ]]; then
    TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"
  fi

  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
}

output_json() {
  printf '{"REPO_ROOT": "%s", "TEAM_AI_DIRECTIVES": "%s", "BRANCH": "%s", "SDD_DOCS_LOCATION": "%s"}\n' \
    "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVES" "$BRANCH" "$SDD_DOCS_LOCATION"
}

resolve_sdd_docs_location() {
  local project_root="${1:-$PROJECT_ROOT}"
  local sdd_docs_location=""

  # 1. Environment variable (highest priority)
  if [[ -n "${SDD_DOCS_LOCATION:-}" ]]; then
    sdd_docs_location="$SDD_DOCS_LOCATION"
  fi

  # 2. .adlc/init-options.json
  if [[ -z "$sdd_docs_location" ]]; then
    local init_options="${project_root}/.adlc/init-options.json"
    if [[ -f "$init_options" ]]; then
      sdd_docs_location=$(python3 -c "
import json, sys
try:
    with open('$init_options') as f:
        print(json.load(f).get('sdd_docs_location', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    fi
  fi

  # 3. Default empty (project root)
  echo "$sdd_docs_location"
}

sdd_project_subfolder_name() {
  local project_root="${1:-$PROJECT_ROOT}"
  local common_dir
  common_dir=$(git -C "$project_root" rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$common_dir" ]]; then
    basename "$(cd "$(dirname "$common_dir")" && pwd)"
  else
    basename "$project_root"
  fi
}

resolve_sdd_root() {
  local project_root="${1:-$PROJECT_ROOT}"
  local sdd_docs_location
  local project_subfolder

  sdd_docs_location=$(resolve_sdd_docs_location "$project_root")

  if [[ -n "$sdd_docs_location" ]]; then
    # Expand tilde to $HOME
    sdd_docs_location="${sdd_docs_location/#\~/$HOME}"
    project_subfolder=$(sdd_project_subfolder_name "$project_root")
    echo "${sdd_docs_location%/}/${project_subfolder}"
  else
    echo "$project_root"
  fi
}

### DEPRECATED — kept for backward compatibility
# Use resolve_sdd_root() and resolve_sdd_docs_location() for new code.

###############################################################################
# 2. TEAM AI DIRECTIVES STRUCTURE VALIDATION
###############################################################################

validate_team_ai_directives() {
  local dir="$1"
  local missing=0

  for required in \
    "context_modules/constitution.md" \
    "context_modules/rules" \
    "context_modules/personas" \
    "context_modules/examples" \
    "CDR.md" \
    ".skills.json"; do
    if [[ ! -e "${dir}/${required}" ]]; then
      echo "MISSING: ${required}"
      missing=$((missing + 1))
    fi
  done

  return "$missing"
}

###############################################################################
# 3. SCAFFOLD
###############################################################################

scaffold_team_ai_directives() {
  local dest="$1"
  local team_name="${2:-My Team}"
  local today
  today=$(date +%Y-%m-%d)

  if [[ -d "$dest" && -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
    echo "ERROR: Destination '$dest' already exists and is not empty." >&2
    exit 1
  fi

  mkdir -p "${dest}/context_modules/rules"
  mkdir -p "${dest}/context_modules/personas"
  mkdir -p "${dest}/context_modules/examples"
  mkdir -p "${dest}/skills"

  cat > "${dest}/README.md" << README
# ${team_name} Team AI Directives

Team AI directives repository for ${team_name}.

## Getting Started

1. Wire this directives repository into a project:
   \`\`\`
   /team-setup
   \`\`\`
   Choose "Point to existing local path" and select this directory.

2. Add context modules to \`context_modules/\` (rules, personas, examples).

3. Add skills to \`skills/\` and register them in \`.skills.json\`.

4. Update \`CDR.md\` as context modules are approved.

See [ADLC Team Skills](https://github.com/tikalk/adlc-team-skills) for full documentation.
README

  cat > "${dest}/AGENTS.md" << 'AGENTS'
# Agent Instructions

## Structure

- `context_modules/constitution.md` — Team constitution
- `context_modules/rules/` — Team rules and workflows
- `context_modules/personas/` — Team personas
- `context_modules/examples/` — Team examples
- `skills/` — Team skills
- `evals/` — Directive compliance goldensets (pass/fail cases)
- `CDR.md` — Context Directive Records

## Loading Order

1. Load constitution.md first
2. Load relevant rules for the current task
3. Load relevant personas for the current task
4. Load relevant examples for the current task

## Using Skills

Skills are located in the `skills/` directory. Browse available skills using team-skills and install them as needed.

## CDR.md

The CDR.md file tracks approved context contributions. Update it when adding new context modules.
AGENTS

  cat > "${dest}/CDR.md" << CDR
# Context Directive Records

Context Directive Records (CDRs) track decisions about contributing context modules (rules, personas, examples, skills) to team-ai-directives.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|

**Stats**: 0 entries | Last Updated: ${today}
CDR

  cat > "${dest}/.skills.json" << 'SKILLSJSON'
{
  "version": "2.0.0",
  "source": "team-ai-directives",
  "description": "Team skills manifest. The `default` list contains skill names that are auto-installed during project setup. The `external` map contains on-demand skills fetched by URL. The `blocked` list contains skills that must never be installed.",
  "default": [],
  "external": {},
  "blocked": [],
  "policy": {
    "auto_install_default": true,
    "enforce_blocked": true,
    "allow_project_override": true
  }
}
SKILLSJSON

  cat > "${dest}/.mcp.json.example" << 'MCPJSON'
{
  "mcpServers": {}
}
MCPJSON

  cat > "${dest}/context_modules/constitution.md" << CONSTITUTION
---
type: Constitution
title: "${team_name} Constitution"
description: "Team-wide principles and governance"
resource: ./context_modules/constitution.md
tags: [constitution]
timestamp: ${today}T00:00:00Z
---

# ${team_name} Constitution

No team-wide principles defined yet. Add principles as they are established.
CONSTITUTION

  cat > "${dest}/context_modules/index.md" << 'INDEXTOP'
# Context Modules

| Directory | Description |
|-----------|-------------|
| [rules/](rules/index.md) | Team rules and workflows |
| [personas/](personas/index.md) | Team personas |
| [examples/](examples/index.md) | Team examples |
INDEXTOP

  cat > "${dest}/context_modules/rules/index.md" << 'INDEXRULES'
# Rules

No rules defined yet. Use /levelup-specify to create rules via CDRs.
INDEXRULES

  cat > "${dest}/context_modules/personas/index.md" << 'INDEXPERS'
# Personas

No personas defined yet. Use /levelup-specify to create personas via CDRs.
INDEXPERS

  cat > "${dest}/context_modules/examples/index.md" << 'INDEXEX'
# Examples

No examples defined yet. Use /levelup-specify to create examples via CDRs.
INDEXEX

  touch "${dest}/context_modules/rules/.gitkeep"
  touch "${dest}/context_modules/personas/.gitkeep"
  touch "${dest}/context_modules/examples/.gitkeep"
  touch "${dest}/skills/.gitkeep"

  echo "Scaffolded team-ai-directives at ${dest}"
  echo "Team name: ${team_name}"
  echo "Files created: 14"

  validate_team_ai_directives "$dest" || true
}

scaffold_agents_only() {
  local dest="$1"
  mkdir -p "$dest"

  cat > "${dest}/AGENTS.md" << 'AGENTS'
# Agent Instructions

## Structure

- `context_modules/constitution.md` — Team constitution
- `context_modules/rules/` — Team rules and workflows
- `context_modules/personas/` — Team personas
- `context_modules/examples/` — Team examples
- `skills/` — Team skills
- `traces/` — Published session traces (from `/levelup-publish`)
- `CDR.md` — Context Directive Records

## Loading Order

1. Load constitution.md first
2. Load relevant rules for the current task
3. Load relevant personas for the current task
4. Load relevant examples for the current task

## Using Skills

Skills are located in the `skills/` directory. Browse available skills using team-skills and install them as needed.

## CDR.md

The CDR.md file tracks approved context contributions. Update it when adding new context modules.
AGENTS

  echo "Created AGENTS.md at ${dest}"
}

###############################################################################
# 4. INJECT PROJECT-LEVEL AGENTS.md DIRECTIVE
###############################################################################

inject_project_agents() {
  local project_root="${1:-.}"
  local team_directive="${2:-}"

  # Resolve team_ai_directives if not provided
  if [[ -z "$team_directive" ]]; then
    local init_options="${project_root}/.adlc/init-options.json"
    if [[ -f "$init_options" ]]; then
      team_directive=$(python3 -c "
import json, sys
try:
    with open('$init_options') as f:
        print(json.load(f).get('team_ai_directives', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    fi
  fi

  # Fallback to env var
  if [[ -z "$team_directive" ]] && [[ -n "${TEAM_AI_DIRECTIVES:-}" ]]; then
    team_directive="$TEAM_AI_DIRECTIVES"
  fi

  # Fallback to default path
  if [[ -z "$team_directive" ]]; then
    team_directive="${project_root}/team-ai-directives"
  fi

  local agents_file="${project_root}/AGENTS.md"
  local marker_start="<!-- TEAM_AI_DIRECTIVES START -->"
  local marker_end="<!-- TEAM_AI_DIRECTIVES END -->"

  # Build the managed section
  local section
  section=$(cat <<SECTION
${marker_start}
## Team Directives & Constitution

This project is bound by the team AI directives repository at \`${team_directive}\`.
- **Strict Compliance**: You MUST invoke the \`team-boot\` skill BEFORE responding to any task or question. This is not optional and applies to every interaction. If a skill applies, you MUST invoke it immediately.
- **First-Tool-Call Gate**: Your FIRST tool call in any session MUST be \`skill({name: "team-boot"})\`. If your first tool call is \`read\`, \`grep\`, \`glob\`, \`bash\`, or any other tool, you have VIOLATED this directive -- stop and invoke \`team-boot\` before continuing. Mechanically verifiable in any trace.
- **Plan-Mode Compatibility**: Loading a skill is read-only -- it injects instructions, it does NOT modify files. Plan mode / read-only phase NEVER forbids the \`skill\` tool. Do not fabricate a conflict between plan mode and the skill check.
- **Anti-Patterns** (do NOT rationalize skipping the skill check):
  - "Let me explore the codebase first" -> Skills tell you HOW to explore. Check first.
  - "This is a plain message, not a spec command" -> Skill check applies to EVERY interaction.
  - "I will check after understanding the request" -> Check BEFORE understanding -- skills guide your questions.
  - "This is too simple" -> Simple things become complex. Check first.
  - "Plan mode forbids modifications" -> The \`skill\` tool is read-only; plan mode never forbids it.
  - "I need to be efficient / focus on the task" -> The check IS the first step, not overhead to optimize away.
  - "The task matters more than the check" -> The check IS part of the task; skipping it is a violation.
- **Team Constitution**: Read and strictly adhere to the principles in \`${team_directive}/context_modules/constitution.md\`. When creating or updating the project constitution, you MUST inherit and align with these principles.
- **Rules, Personas & Examples**: Use the \`team-discover\` skill to find and load relevant rules, personas, or examples before making changes.
- **Tech Radar Guidance**: Use the \`tech-radar-context\` skill whenever evaluating or choosing technologies, frameworks, databases, libraries, or cloud infrastructure.
${marker_end}
SECTION
)

  # Create AGENTS.md if it doesn't exist, or update the managed section
  python3 - "$agents_file" "$marker_start" "$marker_end" "$section" <<'PY'
import os, sys

agents_path, start, end, section_content = sys.argv[1:5]

if os.path.exists(agents_path):
    with open(agents_path, "r", encoding="utf-8") as f:
        content = f.read()
else:
    content = ""

# Check if markers already exist
s_idx = content.find(start)
e_idx = content.find(end)

if s_idx != -1 and e_idx != -1 and s_idx < e_idx:
    # Replace existing managed section
    new_content = content[:s_idx] + section_content + content[e_idx + len(end):]
    if new_content.endswith("\n"):
        new_content += "\n"
    elif not new_content.endswith("\n\n"):
        new_content += "\n"
    with open(agents_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"Updated team AI directives section in {agents_path}")
else:
    # Append managed section
    if content and not content.endswith("\n"):
        content += "\n"
    if content and not content.endswith("\n\n"):
        content += "\n"
    content += section_content + "\n"
    with open(agents_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Injected team AI directives section into {agents_path}")
PY
}

###############################################################################
# 5. SHARED GIT PUBLISH WORKFLOW
###############################################################################

# Reusable branch/commit/push/PR decision tree extracted from levelup-publish.
# Usage: git_publish_workflow <target_dir> <branch_prefix> <commit_msg> [<ready_flag>]
# Emits PUBLISH_OUTCOME=<draft_pr|ready_pr|push_only|local_only|git_init_offered>
# and PR_URL=<url> when applicable.
git_publish_workflow() {
  local target_dir="$1"
  local branch_prefix="$2"
  local commit_msg="$3"
  local ready="${4:-}"
  local project_name
  project_name=$(basename "${PROJECT_ROOT:-$(pwd)}")
  local branch_name="${branch_prefix}/${project_name}"

  # Case D: target is not a git repository — offer git init or write-only/no-op.
  if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "PUBLISH_OUTCOME=git_init_offered"
    echo "TARGET_DIR=$target_dir"
    cat <<MSG
Target directory is not a git repository. Options:

1. Initialize git and commit:
   cd "$target_dir"
   git init
   git add -A
   git commit -m "Initial commit"
   git checkout -b "$branch_name"

2. Write files only (skip git operations).
MSG
    return 0
  fi

  # Create branch (use main if it exists, otherwise HEAD).
  git -C "$target_dir" checkout -b "$branch_name" main 2>/dev/null || \
    git -C "$target_dir" checkout -b "$branch_name"

  # Commit changes if there is anything to commit.
  if [[ -n "$(git -C "$target_dir" status --porcelain 2>/dev/null)" ]]; then
    git -C "$target_dir" add -A
    git -C "$target_dir" commit -m "$commit_msg"
  fi

  # Check for remote "origin".
  if git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$target_dir" push -u origin "$branch_name"

    # Case A: remote + gh CLI available.
    if command -v gh >/dev/null 2>&1; then
      local pr_title
      pr_title=$(echo "$commit_msg" | head -n 1)
      local pr_body="$commit_msg"
      local draft_flag="--draft"
      [[ "$ready" == "--ready" ]] && draft_flag=""
      local pr_url
      pr_url=$(cd "$target_dir" && gh pr create $draft_flag --title "$pr_title" --body "$pr_body" 2>/dev/null || true)
      if [[ -n "$pr_url" ]]; then
        if [[ "$ready" == "--ready" ]]; then
          echo "PUBLISH_OUTCOME=ready_pr PR_URL=$pr_url"
        else
          echo "PUBLISH_OUTCOME=draft_pr PR_URL=$pr_url"
        fi
      else
        echo "PUBLISH_OUTCOME=push_only"
        echo "MESSAGE=Pushed to origin/$branch_name. Open a PR manually at your Git host."
      fi
    else
      # Case B: remote exists but gh is not available.
      echo "PUBLISH_OUTCOME=push_only"
      echo "MESSAGE=Pushed to origin/$branch_name. Open a PR manually at your Git host."
    fi
  else
    # Case C: no remote exists.
    echo "PUBLISH_OUTCOME=local_only"
    echo "MESSAGE=Committed to local branch $branch_name. Add a remote (git remote add origin <url>) and push when ready."
  fi
}

###############################################################################
# MAIN
###############################################################################

main() {
  local has_json=false
  local has_scaffold=false
  local has_agents_only=false
  local has_inject_agents=false
  local scaffold_dest=""
  local agents_only_dest=""
  local inject_dest=""
  local team_name="My Team"
  local parsing_scaffold=false
  local parsing_agents=false
  local parsing_name=false
  local parsing_inject=false

  for arg in "$@"; do
    if [[ "$arg" == "--json" || "$arg" == "-Json" ]]; then
      has_json=true
      continue
    fi
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
      echo "Usage: team-helpers.sh [--json] [--scaffold DIR] [--agents-only DIR] [--inject-agents [DIR]] [--name NAME]"
      exit 0
    fi
    if [[ "$arg" == "--scaffold" ]]; then
      has_scaffold=true
      parsing_scaffold=true
      parsing_agents=false
      parsing_name=false
      parsing_inject=false
      continue
    fi
    if [[ "$arg" == "--agents-only" ]]; then
      has_agents_only=true
      parsing_agents=true
      parsing_scaffold=false
      parsing_name=false
      parsing_inject=false
      continue
    fi
    if [[ "$arg" == "--inject-agents" ]]; then
      has_inject_agents=true
      parsing_inject=true
      parsing_scaffold=false
      parsing_agents=false
      parsing_name=false
      continue
    fi
    if [[ "$arg" == "--name" ]]; then
      parsing_name=true
      parsing_scaffold=false
      parsing_agents=false
      parsing_inject=false
      continue
    fi
    if $parsing_scaffold && [[ -n "$arg" ]]; then
      scaffold_dest="$arg"
      parsing_scaffold=false
      continue
    fi
    if $parsing_agents && [[ -n "$arg" ]]; then
      agents_only_dest="$arg"
      parsing_agents=false
      continue
    fi
    if $parsing_inject && [[ -n "$arg" ]]; then
      inject_dest="$arg"
      parsing_inject=false
      continue
    fi
    if $parsing_name && [[ -n "$arg" ]]; then
      team_name="$arg"
      parsing_name=false
      continue
    fi
  done

  if $has_scaffold; then
    if [[ -z "$scaffold_dest" ]]; then
      echo "ERROR: --scaffold requires a destination directory argument" >&2
      exit 1
    fi
    scaffold_team_ai_directives "$scaffold_dest" "$team_name"
    return
  fi

  if $has_agents_only; then
    if [[ -z "$agents_only_dest" ]]; then
      echo "ERROR: --agents-only requires a destination directory argument" >&2
      exit 1
    fi
    scaffold_agents_only "$agents_only_dest"
    return
  fi

  if $has_inject_agents; then
    local project_root="${inject_dest:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    inject_project_agents "$project_root"
    return
  fi

  # Default: resolve paths
  resolve_paths > /dev/null
  SDD_DOCS_LOCATION=$(resolve_sdd_docs_location "$PROJECT_ROOT")
  if $has_json; then
    output_json
  else
    resolve_paths
    echo "SDD_DOCS_LOCATION=$SDD_DOCS_LOCATION"
  fi
}

main "$@"
