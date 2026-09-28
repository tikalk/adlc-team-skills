#!/usr/bin/env bash
# setup-evals-analyze.sh — Setup for evals-init (self-contained)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

resolve_team_ai_directives() {
  local project_root="$1"
  local td="${TEAM_AI_DIRECTIVES:-}"
  [[ -n "$td" ]] && { echo "$td"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    td=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('team_ai_directives', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    [[ -n "$td" ]] && { echo "$td"; return; }
  fi
  echo "${project_root}/team-ai-directives"
}


resolve_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVES=$(resolve_team_ai_directives "$PROJECT_ROOT")

# Resolve WORKSPACE_REPO_ROOT via shared team-paths (no per-project subfolders)
_TEAM_PATHS=""
for _cand in \
  "${SCRIPT_DIR}/../../../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../team-paths.sh" \
  "${SCRIPT_DIR}/team-paths.sh"; do
  [[ -f "$_cand" ]] && { _TEAM_PATHS="$_cand"; break; }
done
if [[ -n "$_TEAM_PATHS" ]]; then
  # shellcheck source=team-paths.sh
  source "$_TEAM_PATHS"
  resolve_workspace_repo_root "$PROJECT_ROOT" >/dev/null
else
  WORKSPACE_REPO_ROOT="$PROJECT_ROOT"
  WORKSPACE_CONFIGURED="false"
fi

BRANCH=$(resolve_branch)

python3 - "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVES" "$BRANCH" "$WORKSPACE_REPO_ROOT" "$WORKSPACE_CONFIGURED" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "TEAM_AI_DIRECTIVES": sys.argv[2],
  "BRANCH": sys.argv[3],
  "WORKSPACE_REPO_ROOT": sys.argv[4],
  "WORKSPACE_CONFIGURED": sys.argv[5] == "true"
}))
PY