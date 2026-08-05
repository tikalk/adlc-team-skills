#!/usr/bin/env bash
# setup-sdd-docs-publish.sh — Setup for sdd-docs-publish (self-contained)
set -euo pipefail

JSON_MODE=false
for arg in "$@"; do
  case "$arg" in --json) JSON_MODE=true ;; esac
done

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

resolve_sdd_docs_location() {
  local project_root="$1"
  local loc="${SDD_DOCS_LOCATION:-}"
  [[ -n "$loc" ]] && { echo "$loc"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    loc=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('sdd_docs_location', ''))
except Exception:
    print('')
" 2>/dev/null || true)
  fi
  echo "$loc"
}

sdd_project_subfolder_name() {
  local project_root="$1"
  local common_dir
  common_dir=$(git -C "$project_root" rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$common_dir" ]]; then
    basename "$(cd "$(dirname "$common_dir")" && pwd)"
  else
    basename "$project_root"
  fi
}

PROJECT_ROOT=$(resolve_project_root)
SDD_DOCS_LOCATION=$(resolve_sdd_docs_location "$PROJECT_ROOT")
PROJECT_SUBFOLDER=$(sdd_project_subfolder_name "$PROJECT_ROOT")

if [[ -n "$SDD_DOCS_LOCATION" ]]; then
  SDD_DOCS_LOCATION="${SDD_DOCS_LOCATION/#\~/$HOME}"
  SDD_ROOT="${SDD_DOCS_LOCATION%/}/${PROJECT_SUBFOLDER}"
  SDD_CONFIGURED="true"
else
  SDD_ROOT="$PROJECT_ROOT"
  SDD_CONFIGURED="false"
fi

SDD_IS_GIT="false"
SDD_CLEAN="false"
if [[ "$SDD_CONFIGURED" == "true" ]]; then
  if git -C "$SDD_DOCS_LOCATION" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    SDD_IS_GIT="true"
    SDD_CLEAN=$([[ -z "$(git -C "$SDD_DOCS_LOCATION" status --porcelain 2>/dev/null)" ]] && echo "true" || echo "false")
  fi
fi

python3 - "$PROJECT_ROOT" "$SDD_DOCS_LOCATION" "$SDD_ROOT" "$PROJECT_SUBFOLDER" "$SDD_CONFIGURED" "$SDD_IS_GIT" "$SDD_CLEAN" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "SDD_DOCS_LOCATION": sys.argv[2],
  "SDD_ROOT": sys.argv[3],
  "PROJECT_SUBFOLDER": sys.argv[4],
  "SDD_CONFIGURED": sys.argv[5] == "true",
  "SDD_IS_GIT": sys.argv[6] == "true",
  "SDD_CLEAN": sys.argv[7] == "true"
}))
PY
