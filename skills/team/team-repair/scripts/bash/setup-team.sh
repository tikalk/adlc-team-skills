#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
TEAM_AI_DIRECTIVES=""

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

if [[ -z "$TEAM_AI_DIRECTIVES" ]]; then
  TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"
fi

if [[ "${1:-}" == "--json" || "${1:-}" == "-Json" ]]; then
  printf '{"REPO_ROOT": "%s", "TEAM_AI_DIRECTIVES": "%s", "BRANCH": "%s"}\n' \
    "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVES" "$BRANCH"
else
  echo "REPO_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
fi

# Confidence update function
update_confidence() {
  local td="$TEAM_AI_DIRECTIVES"
  local adlc_branch="adlc"

  # Check if adlc branch exists
  if ! git -C "$td" show-ref --verify --quiet "refs/heads/$adlc_branch"; then
    echo "adlc branch does not exist — nothing to aggregate"
    return 0
  fi

  # Read all project JSONs and aggregate
  python3 - "$td" "$adlc_branch" << 'PY'
import json, sys, subprocess, os
from datetime import datetime, timedelta

td = sys.argv[1]
adlc_branch = sys.argv[2]

# List project files
result = subprocess.run(
    ["git", "-C", td, "ls-tree", "--name-only", f"{adlc_branch}", "reports/projects/"],
    capture_output=True, text=True
)
project_files = [f for f in result.stdout.strip().split('\n') if f.endswith('.json')]

aggregated = {"last_updated": datetime.now().strftime("%Y-%m-%d"), "cdrs": {}}

for pf in project_files:
    content = subprocess.run(
        ["git", "-C", td, "show", f"{adlc_branch}:{pf}"],
        capture_output=True, text=True
    ).stdout
    try:
        data = json.loads(content)
        project_name = data.get("project", "unknown")
        for cdr_id, stats in data.get("cdrs", {}).items():
            if cdr_id not in aggregated["cdrs"]:
                aggregated["cdrs"][cdr_id] = {
                    "usage_count": 0,
                    "apply_count": 0,
                    "last_used": "",
                    "projects": []
                }
            agg = aggregated["cdrs"][cdr_id]
            agg["usage_count"] += stats.get("matched", 0)
            agg["apply_count"] += stats.get("applied", 0)
            lu = stats.get("last_used", "")
            if lu > agg["last_used"]:
                agg["last_used"] = lu
            if project_name not in agg["projects"]:
                agg["projects"].append(project_name)
    except (json.JSONDecodeError, KeyError):
        continue

# Calculate success_rate and trend
now = datetime.now()
for cdr_id, agg in aggregated["cdrs"].items():
    uc = agg["usage_count"]
    ac = agg["apply_count"]
    agg["success_rate"] = round(ac / uc, 2) if uc > 0 else 0.0
    # Trend
    if agg["last_used"]:
        last = datetime.strptime(agg["last_used"][:10], "%Y-%m-%d")
        days = (now - last).days
        if days <= 7:
            agg["trend"] = "rising"
        elif days <= 30:
            agg["trend"] = "stable"
        else:
            agg["trend"] = "falling"
    else:
        agg["trend"] = "unknown"

print(json.dumps(aggregated, indent=2))
PY
}

if [[ "${1:-}" == "--update-confidence" ]]; then
  update_confidence
  exit 0
fi
