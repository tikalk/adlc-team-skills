#!/usr/bin/env bash
# Confirm-gated lifecycle backfill (factory-setup Mode 3).
#
# Reads the JSON plan written by factory-tickets `lifecycle-lint --json`.
# Without --apply it only prints the dry-run table (issue, current labels,
# proposed label) and makes NO tracker call. Run --apply only after the human
# has approved that table, and never in a headless run.
#
# With --apply, each row gets one Set Lifecycle call (tracker-integration
# Operation 9): re-read the live labels, add the proposed label and remove every
# other lifecycle label in the same call, then re-read to verify exactly one is
# left. Rows proposed as "-" need a human decision and are skipped. `resume` is
# never touched.
#
# The plan is bound to what the human approved: a plan written for another
# project is refused, and a row whose live state, lifecycle labels or
# `interactive` flag changed since the lint is skipped as stale (re-run the
# lint). An active `labels:` mapping in the provider config (--config, default
# .adlc/issues-provider.yml) is refused: the names here are canonical.
#
# Usage:
#   lifecycle-backfill.sh --plan <lint.json> --provider <gitlab|github> --project <path|owner/repo> [--apply] [--config <file>]
#
# Exit codes: 0 = done (or dry run), 1 = a row failed verification, 2 = usage or tracker error.
set -euo pipefail

PLAN="" PROVIDER="" PROJECT="" APPLY=0 CONFIG=".adlc/issues-provider.yml"
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)     PLAN="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --project)  PROJECT="${2:-}"; shift 2 ;;
    --apply)    APPLY=1; shift ;;
    --config)   CONFIG="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "lifecycle-backfill: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$PLAN" ] && [ -r "$PLAN" ] || { echo "lifecycle-backfill: --plan <file> is required" >&2; exit 2; }
case "$PROVIDER" in gitlab|github) ;; *) echo "lifecycle-backfill: --provider must be gitlab or github" >&2; exit 2 ;; esac
[ -n "$PROJECT" ] || { echo "lifecycle-backfill: --project is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "lifecycle-backfill: jq is required" >&2; exit 2; }
if [ -f "$CONFIG" ] && grep -q '^labels:' "$CONFIG"; then
  echo "lifecycle-backfill: $CONFIG has an active labels: mapping; this backfill only knows the canonical names. Relabel by hand, or remove the mapping." >&2
  exit 2
fi
PLAN_PROJECT="$(jq -r '.project // empty' "$PLAN")"
if [ -n "$PLAN_PROJECT" ] && [ "$PLAN_PROJECT" != "$PROJECT" ]; then
  echo "lifecycle-backfill: the plan was written for project $PLAN_PROJECT, not $PROJECT" >&2
  exit 2
fi

LIFECYCLE='["intent","spec-gated","executing","parked","validation","done","cancelled"]'
ROWS="$(jq -c '.violations // [] | .[]' "$PLAN")"

echo "## Lifecycle backfill ($([ "$APPLY" -eq 1 ] && echo apply || echo "dry run"))"
echo
echo "| Issue | Current labels | Proposed |"
echo "|--|--|--|"
jq -r '.violations // [] | .[] | "| #\(.iid) | \(.labels | join(", ")) | \(.proposed) |"' "$PLAN"
echo

if [ "$APPLY" -ne 1 ]; then
  echo "Dry run: no tracker writes. Re-run with --apply only after the human approves this table."
  exit 0
fi

ENC="$(printf '%s' "$PROJECT" | jq -sRr @uri)"
# Live issue as {state: opened|closed, labels: [..]}.
live_issue() {
  case "$PROVIDER" in
    gitlab) glab api "projects/$ENC/issues/$1" | jq -ce '{state, labels}' ;;
    github) gh issue view "$1" -R "$PROJECT" --json state,labels \
              | jq -ce '{state: (if .state == "CLOSED" then "closed" else "opened" end), labels: [.labels[].name]}' ;;
  esac
}

FAILED=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  iid="$(printf '%s' "$row" | jq -r '.iid')"
  target="$(printf '%s' "$row" | jq -r '.proposed')"
  if [ "$target" = "-" ]; then
    echo "skipped #$iid (needs a human decision)"
    continue
  fi
  live="$(live_issue "$iid")" || { echo "lifecycle-backfill: cannot read #$iid" >&2; exit 2; }
  # Approval covers the state the lint saw. Anything else is stale.
  if ! printf '%s' "$live" | jq -e --argjson L "$LIFECYCLE" --argjson row "$row" '
      ([.labels[] | select(. as $l | $L | index($l))] | sort) == ($row.lifecycle | sort)
      and .state == $row.state
      and (.labels | index("interactive") | not)' >/dev/null; then
    echo "stale #$iid (changed since the lint; re-run the lint)"
    continue
  fi
  others="$(printf '%s' "$live" | jq -r --argjson L "$LIFECYCLE" --arg t "$target" \
    '[.labels[] | select(. as $l | ($L | index($l)) and $l != $t)] | join(",")')"
  case "$PROVIDER" in
    gitlab)
      if [ -n "$others" ]; then
        glab api -X PUT "projects/$ENC/issues/$iid" -f "add_labels=$target" -f "remove_labels=$others" >/dev/null
      else
        glab api -X PUT "projects/$ENC/issues/$iid" -f "add_labels=$target" >/dev/null
      fi ;;
    github)
      if [ -n "$others" ]; then
        gh issue edit "$iid" -R "$PROJECT" --add-label "$target" --remove-label "$others" >/dev/null
      else
        gh issue edit "$iid" -R "$PROJECT" --add-label "$target" >/dev/null
      fi ;;
  esac
  left="$(live_issue "$iid" | jq -r --argjson L "$LIFECYCLE" '[.labels[] | select(. as $l | $L | index($l))] | join(",")')"
  if [ "$left" = "$target" ]; then
    echo "set #$iid -> $target${others:+ (removed: $others)}"
  else
    echo "FAILED #$iid: expected exactly $target, found: ${left:-none}"
    FAILED=1
  fi
done <<< "$ROWS"

exit "$FAILED"
