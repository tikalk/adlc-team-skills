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
  jq -n -c \
    --arg repo_root "$PROJECT_ROOT" \
    --arg team_ai_directives "$TEAM_AI_DIRECTIVES" \
    --arg branch "$BRANCH" \
    --arg adlc_branch "$ADLC_BRANCH" \
    --arg adlc_worktree "$ADLC_WORKTREE" \
    '{"REPO_ROOT":$repo_root,"TEAM_AI_DIRECTIVES":$team_ai_directives,"BRANCH":$branch,"ADLC_BRANCH":$adlc_branch,"ADLC_WORKTREE":$adlc_worktree}'
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

# Get next CDR (slug-only ID allocation)
# Note: team-init now just prepares the adlc branch; 
# slug IDs are minted by the agent during capture via team-levelup.
echo "REPO_ROOT=$PROJECT_ROOT"
echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
echo "ADLC_BRANCH=$ADLC_BRANCH"
echo ""
echo "Ready for multi-agent brownfield analysis."
echo "CDRs will be written to: $TEAM_AI_DIRECTIVES (adlc branch, drafts/cdr/)"
