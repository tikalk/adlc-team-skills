#!/usr/bin/env bash
# team-paths.sh — Path / workspace resolution for team-* and SDD skills.
#
# Safe to source: no side effects unless invoked as a CLI.
# CLI flags:
#   --json   Emit path info as JSON
#
# Library functions:
#   expand_tilde, resolve_project_root, resolve_team_ai_directives,
#   resolve_workspace_repo_root, emit_workspace_paths
set -euo pipefail

###############################################################################
# Canonical tilde expansion (single place)
###############################################################################
expand_tilde() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    echo ""
    return
  fi
  if [[ "$path" == "~" ]]; then
    echo "$HOME"
  elif [[ "$path" == "~/"* ]]; then
    echo "${HOME}/${path:2}"
  else
    echo "$path"
  fi
}

###############################################################################
# Project root: walk up for .adlc, else git toplevel, else cwd
###############################################################################
resolve_project_root() {
  local dir
  dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.adlc" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

###############################################################################
# Team AI directives — fix env-var clobbering (read env BEFORE clearing)
###############################################################################
resolve_team_ai_directives() {
  local project_root="${1:-}"
  [[ -z "$project_root" ]] && project_root="$(resolve_project_root)"

  local result=""

  # 1. Environment variable (highest priority) — printenv ignores shell locals
  result="$(printenv TEAM_AI_DIRECTIVES 2>/dev/null || true)"

  # 2. .adlc/init-options.json
  if [[ -z "$result" ]]; then
    local init_options="${project_root}/.adlc/init-options.json"
    if [[ -f "$init_options" ]]; then
      result=$(INIT_OPTIONS="$init_options" python3 -c "
import json, os
try:
    with open(os.environ['INIT_OPTIONS']) as f:
        print(json.load(f).get('team_ai_directives', '') or '')
except Exception:
    print('')
" 2>/dev/null || true)
    fi
  fi

  # 3. Fallback
  if [[ -z "$result" ]]; then
    result="${project_root}/team-ai-directives"
  fi

  expand_tilde "$result"
}

###############################################################################
# WORKSPACE_REPO_ROOT resolution order:
# 1. WORKSPACE_REPO_ROOT env
# 2. workspace_repo_root in project-local .adlc/init-options.json
# 3. Auto-discovery: parent of git toplevel contains .adlc/ → that parent
# 4. Project root (in-project default)
#
# Sets globals: PROJECT_ROOT, WORKSPACE_REPO_ROOT, WORKSPACE_CONFIGURED, BRANCH
# WORKSPACE_CONFIGURED=true when resolved via 1/2/3 (not the step-4 default).
###############################################################################
resolve_workspace_repo_root() {
  local project_root="${1:-}"
  [[ -z "$project_root" ]] && project_root="$(resolve_project_root)"

  local configured="false"
  local result=""

  # 1. Environment variable (printenv ignores shell locals set by prior calls)
  local from_env
  from_env="$(printenv WORKSPACE_REPO_ROOT 2>/dev/null || true)"
  if [[ -n "$from_env" ]]; then
    result="$(expand_tilde "$from_env")"
    configured="true"
  fi

  # 2. .adlc/init-options.json
  if [[ -z "$result" ]]; then
    local init_options="${project_root}/.adlc/init-options.json"
    if [[ -f "$init_options" ]]; then
      local from_json
      from_json=$(INIT_OPTIONS="$init_options" python3 -c "
import json, os
try:
    with open(os.environ['INIT_OPTIONS']) as f:
        print(json.load(f).get('workspace_repo_root', '') or '')
except Exception:
    print('')
" 2>/dev/null || true)
      if [[ -n "$from_json" ]]; then
        result="$(expand_tilde "$from_json")"
        configured="true"
      fi
    fi
  fi

  # 3. Auto-discovery: parent of git rev-parse --show-toplevel contains .adlc/
  if [[ -z "$result" ]]; then
    local git_toplevel parent
    git_toplevel=$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$git_toplevel" ]]; then
      parent="$(dirname "$git_toplevel")"
      if [[ "$parent" != "/" && "$parent" != "$git_toplevel" && -d "${parent}/.adlc" ]]; then
        result="$parent"
        configured="true"
      fi
    fi
  fi

  # 4. Project root (in-project default)
  if [[ -z "$result" ]]; then
    result="$project_root"
    configured="false"
  fi

  # Normalize to absolute path when possible
  if [[ -d "$result" ]]; then
    result="$(cd "$result" && pwd)"
  fi

  PROJECT_ROOT="$project_root"
  WORKSPACE_REPO_ROOT="$result"
  WORKSPACE_CONFIGURED="$configured"
  BRANCH="${BRANCH:-$(git -C "$project_root" branch --show-current 2>/dev/null || echo 'unknown')}"

  echo "$result"
}

###############################################################################
# Emit key=value or JSON for setup scripts / CLI
###############################################################################
emit_workspace_paths() {
  local as_json="${1:-false}"
  local project_root
  project_root="$(resolve_project_root)"
  resolve_workspace_repo_root "$project_root" >/dev/null
  local team_dirs
  team_dirs="$(resolve_team_ai_directives "$PROJECT_ROOT")"

  if [[ "$as_json" == "true" ]]; then
    python3 - "$PROJECT_ROOT" "$WORKSPACE_REPO_ROOT" "$WORKSPACE_CONFIGURED" "$team_dirs" "$BRANCH" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "PROJECT_ROOT": sys.argv[1],
  "WORKSPACE_REPO_ROOT": sys.argv[2],
  "WORKSPACE_CONFIGURED": sys.argv[3] == "true",
  "TEAM_AI_DIRECTIVES": sys.argv[4],
  "BRANCH": sys.argv[5],
}))
PY
  else
    echo "PROJECT_ROOT=$PROJECT_ROOT"
    echo "REPO_ROOT=$PROJECT_ROOT"
    echo "WORKSPACE_REPO_ROOT=$WORKSPACE_REPO_ROOT"
    echo "WORKSPACE_CONFIGURED=$WORKSPACE_CONFIGURED"
    echo "TEAM_AI_DIRECTIVES=$team_dirs"
    echo "BRANCH=$BRANCH"
  fi
}

# Back-compat alias used by older callers that expected resolve_paths
resolve_paths() {
  local project_root
  project_root="$(resolve_project_root)"
  resolve_workspace_repo_root "$project_root" >/dev/null
  TEAM_AI_DIRECTIVES="$(resolve_team_ai_directives "$PROJECT_ROOT")"
  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
  echo "WORKSPACE_REPO_ROOT=$WORKSPACE_REPO_ROOT"
  echo "WORKSPACE_CONFIGURED=$WORKSPACE_CONFIGURED"
}

###############################################################################
# Side-effect guard: only run CLI when executed, not when sourced
###############################################################################
_team_paths_main() {
  local has_json=false
  for arg in "$@"; do
    case "$arg" in
      --json|-Json) has_json=true ;;
      --help|-h)
        echo "Usage: team-paths.sh [--json]"
        return 0
        ;;
    esac
  done
  if $has_json; then
    emit_workspace_paths true
  else
    emit_workspace_paths false
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _team_paths_main "$@"
fi
