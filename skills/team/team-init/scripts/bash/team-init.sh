#!/usr/bin/env bash
# team-init.sh — Brownfield CDR discovery entry point
set -euo pipefail

# team-init delegates CDR lifecycle operations to the team-levelup skill.
# Invoke the team-levelup skill for CDR work; the path/numbering helpers
# below are vendored self-contained (no cross-skill sourcing per scope rule).
resolve_team_levelup_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
  TEAM_AI_DIRECTIVES="${TEAM_AI_DIRECTIVES:-}"
  if [[ -z "$TEAM_AI_DIRECTIVES" && -f "${PROJECT_ROOT}/.adlc/init-options.json" ]]; then
    TEAM_AI_DIRECTIVES=$(grep '"team_ai_directives"' "${PROJECT_ROOT}/.adlc/init-options.json" \
      | sed -n 's/.*"team_ai_directives"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -1)
  fi
  [[ -z "$TEAM_AI_DIRECTIVES" || "$TEAM_AI_DIRECTIVES" = "null" ]] && TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"
  ADLC_BRANCH="adlc"
  ADLC_WORKTREE="/tmp/adlc-worktree-$$"
  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
  echo "ADLC_BRANCH=$ADLC_BRANCH"
  echo "ADLC_WORKTREE=$ADLC_WORKTREE"
}

output_json() {
  resolve_team_levelup_paths >/dev/null
  python3 - "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVES" "$BRANCH" "$ADLC_BRANCH" "$ADLC_WORKTREE" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "TEAM_AI_DIRECTIVES": sys.argv[2],
  "BRANCH": sys.argv[3],
  "ADLC_BRANCH": sys.argv[4],
  "ADLC_WORKTREE": sys.argv[5]
}))
PY
}

ensure_adlc_branch() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  if ! git -C "$td" show-ref --verify --quiet "refs/heads/$ADLC_BRANCH"; then
    git -C "$td" branch --orphan "$ADLC_BRANCH"
    git -C "$td" worktree add "$ADLC_WORKTREE" "$ADLC_BRANCH" 2>/dev/null
    mkdir -p "$ADLC_WORKTREE/drafts/cdr" "$ADLC_WORKTREE/reports/sessions" "$ADLC_WORKTREE/reports/projects"
    git -C "$ADLC_WORKTREE" add -A
    git -C "$ADLC_WORKTREE" commit --allow-empty -m "Initialize adlc orphan branch"
    git -C "$ADLC_WORKTREE" push origin "$ADLC_BRANCH" 2>/dev/null || true
    git -C "$td" worktree remove "$ADLC_WORKTREE" 2>/dev/null || true
  fi
}

next_cdr_number() {
  local td="${1:-$TEAM_AI_DIRECTIVES}"
  local max=0
  for f in $(git -C "$td" ls-tree --name-only "$ADLC_BRANCH" "drafts/cdr/" 2>/dev/null | sort); do
    local base num
    base=$(basename "$f")
    [[ "$base" == *.md ]] || continue
    num=$(printf '%s' "${base%.md}" | sed -n 's/^CDR-\([0-9]\{1,\}\).*/\1/p')
    [[ -n "$num" ]] || continue
    ((10#$num > max)) && max=$((10#$num))
  done
  printf '%03d' $((max + 1))
}

if [[ "${1:-}" == "--setup" ]]; then
  output_json
  exit 0
fi

# Resolve paths (function sets PROJECT_ROOT/TEAM_AI_DIRECTIVES/BRANCH globals
# directly; output is informational only — never eval it)
resolve_team_levelup_paths >/dev/null

if [[ -z "$TEAM_AI_DIRECTIVES" ]] || [[ ! -d "$TEAM_AI_DIRECTIVES" ]]; then
  echo "Team AI directives repository not configured."
  echo "Run: /team-setup"
  exit 1
fi

# Ensure adlc orphan branch exists
ensure_adlc_branch "$TEAM_AI_DIRECTIVES"

# Get next CDR number
NEXT_CDR=$(next_cdr_number "$TEAM_AI_DIRECTIVES")

echo "REPO_ROOT=$PROJECT_ROOT"
echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
echo "NEXT_CDR=$NEXT_CDR"
echo "ADLC_BRANCH=$ADLC_BRANCH"
echo ""
echo "Ready for multi-agent brownfield analysis."
echo "CDRs will be written to: $TEAM_AI_DIRECTIVES (adlc branch, drafts/cdr/)"
