#!/usr/bin/env bash
# workspace-publish.sh — Full publish workflow for WORKSPACE_REPO_ROOT metadata.
# Owns: helper loading, arg validation, git readiness, branch/commit/push/PR,
# structured JSON output. Never stages the entire working tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load team-paths (path resolution only — publishing does not live in helpers)
TEAM_PATHS=""
for candidate in \
  "${SCRIPT_DIR}/../../../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../../../team/team-paths.sh" \
  "${SCRIPT_DIR}/../../team/team-paths.sh" \
  "${SCRIPT_DIR}/team-paths.sh"; do
  if [[ -f "$candidate" ]]; then TEAM_PATHS="$candidate"; break; fi
done
if [[ -z "$TEAM_PATHS" ]]; then
  echo '{"PUBLISH_OUTCOME":"error","MESSAGE":"team-paths.sh not found"}' >&2
  exit 1
fi
# shellcheck source=team-paths.sh
source "$TEAM_PATHS"

READY=false
JSON_MODE=false
for arg in "$@"; do
  case "$arg" in
    --ready) READY=true ;;
    --json)  JSON_MODE=true ;;
    --help|-h)
      echo "Usage: workspace-publish.sh [--ready] [--json]"
      exit 0
      ;;
  esac
done

# Explicit pathspec — used for status, staging, AND commit. Never stage the entire tree.
PATHSPEC=(.adlc PRD.md AD.md specs evals)

PROJECT_ROOT="$(resolve_project_root)"
resolve_workspace_repo_root "$PROJECT_ROOT" >/dev/null

emit_json() {
  local outcome="$1"
  local pr_url="${2:-}"
  local message="${3:-}"
  python3 - "$outcome" "$pr_url" "$message" "$PROJECT_ROOT" "$WORKSPACE_REPO_ROOT" "$WORKSPACE_CONFIGURED" <<'PY'
import json, sys
print(json.dumps({
  "PUBLISH_OUTCOME": sys.argv[1],
  "PR_URL": sys.argv[2] or None,
  "MESSAGE": sys.argv[3] or None,
  "REPO_ROOT": sys.argv[4],
  "WORKSPACE_REPO_ROOT": sys.argv[5],
  "WORKSPACE_CONFIGURED": sys.argv[6] == "true",
}))
PY
}

# Not configured → in-project default; nothing external to publish
if [[ "$WORKSPACE_CONFIGURED" != "true" ]]; then
  msg="workspace_repo_root is not configured. Nothing to publish — SDD artifacts are stored in-project. Set WORKSPACE_REPO_ROOT or workspace_repo_root in .adlc/init-options.json to enable external storage and publishing."
  if $JSON_MODE; then emit_json "not_configured" "" "$msg"; else echo "$msg"; fi
  exit 0
fi

TARGET="$WORKSPACE_REPO_ROOT"

# Git readiness
if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  msg="Target directory is not a git repository. Offer: git init + commit, or write-only/no-op."
  if $JSON_MODE; then emit_json "git_init_offered" "" "$msg"; else
    echo "PUBLISH_OUTCOME=git_init_offered"
    echo "TARGET_DIR=$TARGET"
    echo "$msg"
  fi
  exit 0
fi

# Status scoped to pathspec only
STATUS=$(git -C "$TARGET" status --porcelain -- "${PATHSPEC[@]}" 2>/dev/null || true)

ws_name=$(basename "$TARGET")
branch_name="workspace-publish/${ws_name}"

# Create branch
git -C "$TARGET" checkout -b "$branch_name" main 2>/dev/null || \
  git -C "$TARGET" checkout -b "$branch_name" 2>/dev/null || \
  git -C "$TARGET" checkout "$branch_name" 2>/dev/null || true

# Stage + commit with explicit pathspec (explicit pathspec only)
if [[ -n "$STATUS" ]]; then
  # Only add paths that exist
  to_add=()
  for p in "${PATHSPEC[@]}"; do
    if [[ -e "$TARGET/$p" ]]; then
      to_add+=("$p")
    fi
  done
  if [[ ${#to_add[@]} -gt 0 ]]; then
    git -C "$TARGET" add -- "${to_add[@]}"
    commit_msg="Publish workspace metadata

$(git -C "$TARGET" status --porcelain -- "${PATHSPEC[@]}")
"
    git -C "$TARGET" commit -m "$commit_msg"
  fi
fi

# Remote / PR
if git -C "$TARGET" remote get-url origin >/dev/null 2>&1; then
  git -C "$TARGET" push -u origin "$branch_name"
  if command -v gh >/dev/null 2>&1; then
    pr_title="Publish workspace metadata from ${ws_name}"
    pr_body="Automated publish of workspace SDD metadata (.adlc, PRD.md, AD.md, specs, evals)."
    draft_flag=(--draft)
    $READY && draft_flag=()
    pr_url=$(cd "$TARGET" && gh pr create "${draft_flag[@]}" --title "$pr_title" --body "$pr_body" 2>/dev/null || true)
    if [[ -n "$pr_url" ]]; then
      outcome=$($READY && echo ready_pr || echo draft_pr)
      if $JSON_MODE; then emit_json "$outcome" "$pr_url" ""; else
        echo "PUBLISH_OUTCOME=$outcome"
        echo "PR_URL=$pr_url"
      fi
      exit 0
    fi
  fi
  msg="Pushed to origin/$branch_name. Open a PR manually at your Git host."
  if $JSON_MODE; then emit_json "push_only" "" "$msg"; else
    echo "PUBLISH_OUTCOME=push_only"
    echo "MESSAGE=$msg"
  fi
else
  msg="Committed to local branch $branch_name. Add a remote and push when ready."
  if $JSON_MODE; then emit_json "local_only" "" "$msg"; else
    echo "PUBLISH_OUTCOME=local_only"
    echo "MESSAGE=$msg"
  fi
fi
