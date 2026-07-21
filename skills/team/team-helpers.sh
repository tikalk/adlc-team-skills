#!/usr/bin/env bash
# team-helpers.sh — Shared utilities for team-* skills
# 
# Flags:
#   --json              Output path info as JSON (default: key=value)
#   --scaffold [DIR]    Create a fresh 11-file KB scaffold at DIR
#   --agents-only DIR   Create only AGENTS.md at DIR (for repair use)
#   --name NAME         Team name for scaffold (default: "My Team")
set -euo pipefail

###############################################################################
# 1. PATH RESOLUTION
###############################################################################

resolve_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
  TEAM_AI_DIRECTIVE=""

  # 1. Check TEAM_AI_DIRECTIVE env var (highest priority)
  if [[ -n "${TEAM_AI_DIRECTIVE:-}" ]]; then
    TEAM_AI_DIRECTIVE="$TEAM_AI_DIRECTIVE"
  fi

  # 2. Check .adlc/init-options.json
  if [[ -z "$TEAM_AI_DIRECTIVE" ]]; then
    INIT_OPTIONS="${PROJECT_ROOT}/.adlc/init-options.json"
    if [[ -f "$INIT_OPTIONS" ]]; then
      TEAM_AI_DIRECTIVE=$(python3 -c "
import json, sys
try:
    with open('$INIT_OPTIONS') as f:
        print(json.load(f).get('team_ai_directive', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    fi
  fi

  # 3. Fallback to default path
  if [[ -z "$TEAM_AI_DIRECTIVE" ]]; then
    TEAM_AI_DIRECTIVE="${PROJECT_ROOT}/team-ai-directives"
  fi

  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVE=$TEAM_AI_DIRECTIVE"
  echo "BRANCH=$BRANCH"
}

output_json() {
  printf '{"REPO_ROOT": "%s", "TEAM_AI_DIRECTIVE": "%s", "BRANCH": "%s"}\n' \
    "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVE" "$BRANCH"
}

###############################################################################
# 2. KB STRUCTURE VALIDATION
###############################################################################

validate_kb() {
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

scaffold_kb() {
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

Team AI directives knowledge base for ${team_name}.

## Getting Started

1. Initialize a project with this directives repository:
   \`\`\`
   specify init my-project --team-ai-directives ./path/to/this/dir
   \`\`\`

2. Add context modules to \`context_modules/\` (rules, personas, examples).

3. Add skills to \`skills/\`.

4. Update \`CDR.md\` as context modules are approved.

See [Agentic SDLC Spec Kit](https://github.com/tikalk/agentic-sdlc-spec-kit) for full documentation.
README

  cat > "${dest}/AGENTS.md" << 'AGENTS'
# Agent Instructions

## Structure

- `context_modules/constitution.md` — Team constitution
- `context_modules/rules/` — Team rules and workflows
- `context_modules/personas/` — Team personas
- `context_modules/examples/` — Team examples
- `skills/` — Team skills
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
  "schema_version": "2.0.0",
  "default": [],
  "skills": {},
  "external": {}
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

  validate_kb "$dest" || true
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
# MAIN
###############################################################################

main() {
  if [[ "$#" -eq 0 ]]; then
    resolve_paths
    return
  fi

  local has_json=false
  local has_scaffold=false
  local has_agents_only=false
  local scaffold_dest=""
  local agents_only_dest=""
  local team_name="My Team"
  local parsing_scaffold=false
  local parsing_agents=false
  local parsing_name=false

  for arg in "$@"; do
    if [[ "$arg" == "--json" || "$arg" == "-Json" ]]; then
      has_json=true
      continue
    fi
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
      echo "Usage: team-helpers.sh [--json] [--scaffold DIR] [--agents-only DIR] [--name NAME]"
      exit 0
    fi
    if [[ "$arg" == "--scaffold" ]]; then
      has_scaffold=true
      parsing_scaffold=true
      parsing_agents=false
      parsing_name=false
      continue
    fi
    if [[ "$arg" == "--agents-only" ]]; then
      has_agents_only=true
      parsing_agents=true
      parsing_scaffold=false
      parsing_name=false
      continue
    fi
    if [[ "$arg" == "--name" ]]; then
      parsing_name=true
      parsing_scaffold=false
      parsing_agents=false
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
    scaffold_kb "$scaffold_dest" "$team_name"
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

  # Default: resolve paths
  resolve_paths > /dev/null
  if $has_json; then
    output_json
  else
    resolve_paths
  fi
}

main "$@"
