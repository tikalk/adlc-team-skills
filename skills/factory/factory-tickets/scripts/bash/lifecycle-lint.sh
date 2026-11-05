#!/usr/bin/env bash
# Read-only lifecycle lint (tracker-integration §2 lifecycle state machine).
#
# Every non-interactive issue must carry exactly one lifecycle label, and a
# closed issue must carry `done` or `cancelled`. Each violation gets ONE
# proposed label, which the confirm-gated factory-setup backfill can apply:
#   closed      -> keep the single terminal label it has; otherwise `done` when
#                  a merged MR/PR closed it, `cancelled` when none did
#   open, none  -> `intent` (a missing label reads as intent)
#   open, many  -> the furthest non-terminal state it carries
#   open, only a terminal label -> "-" (a human decides; reopened work)
# `interactive` issues are reported, never counted or proposed.
#
# This script never writes to the tracker.
#
# The names are the canonical lifecycle labels. A repo with an active `labels:`
# mapping in its provider config (--config, default .adlc/issues-provider.yml)
# is refused rather than linted against the wrong names.
#
# Usage:
#   lifecycle-lint.sh --provider <gitlab|github> --project <path|owner/repo> [--json <file>] [--config <file>]
#   lifecycle-lint.sh --issues <file> [--json <file>] [--config <file>]        # offline
#     --issues: JSON array of {iid, state: opened|closed, labels: [..], closed_by_merged}
#
# Exit codes: 0 = no violations, 1 = violations found, 2 = usage or tracker error.
set -euo pipefail

PROVIDER="" PROJECT="" ISSUES="" JSON_OUT="" CONFIG=".adlc/issues-provider.yml"
while [ $# -gt 0 ]; do
  case "$1" in
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --project)  PROJECT="${2:-}"; shift 2 ;;
    --issues)   ISSUES="${2:-}"; shift 2 ;;
    --json)     JSON_OUT="${2:-}"; shift 2 ;;
    --config)   CONFIG="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "lifecycle-lint: unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "lifecycle-lint: jq is required" >&2; exit 2; }
if [ -f "$CONFIG" ] && grep -q '^labels:' "$CONFIG"; then
  echo "lifecycle-lint: $CONFIG has an active labels: mapping; this lint only knows the canonical names. Lint by hand, or remove the mapping." >&2
  exit 2
fi

LIFECYCLE='["intent","spec-gated","executing","parked","validation","done","cancelled"]'

fetch_issues() {
  case "$PROVIDER" in
    gitlab)
      local enc; enc="$(printf '%s' "$PROJECT" | jq -sRr @uri)"
      glab api --paginate "projects/$enc/issues?state=all&per_page=100" \
        | jq -s 'add // [] | map({iid, state, labels, closed_by_merged: null})'
      ;;
    github)
      gh issue list -R "$PROJECT" --state all --limit 5000 --json number,state,labels \
        | jq 'map({iid: .number, state: (if .state == "CLOSED" then "closed" else "opened" end),
                   labels: [.labels[].name], closed_by_merged: null})'
      ;;
    *) echo "lifecycle-lint: --provider must be gitlab or github" >&2; exit 2 ;;
  esac
}

closed_by_merged() {
  case "$PROVIDER" in
    gitlab)
      local enc; enc="$(printf '%s' "$PROJECT" | jq -sRr @uri)"
      glab api "projects/$enc/issues/$1/closed_by" | jq 'map(select(.state == "merged")) | length > 0'
      ;;
    github)
      # A linked PR is not enough: it must be merged.
      gh api graphql -f owner="${PROJECT%%/*}" -f name="${PROJECT#*/}" -F number="$1" -f query='
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) { issue(number: $number) {
            closedByPullRequestsReferences(first: 100, includeClosedPrs: true) { nodes { merged } } } } }' \
        | jq 'if .data.repository.issue == null then error("issue not found")
              else .data.repository.issue.closedByPullRequestsReferences.nodes | map(.merged == true) | any end'
      ;;
  esac
}

if [ -n "$ISSUES" ]; then
  DATA="$(jq '.' "$ISSUES")" || { echo "lifecycle-lint: unreadable --issues file" >&2; exit 2; }
elif [ -n "$PROVIDER" ] && [ -n "$PROJECT" ]; then
  DATA="$(fetch_issues)" || { echo "lifecycle-lint: tracker fetch failed" >&2; exit 2; }
  # Merge evidence only where the proposal depends on it: closed issues with
  # no terminal label, or with both.
  for iid in $(printf '%s' "$DATA" | jq -r --argjson L "$LIFECYCLE" '
      .[] | select(.state == "closed")
      | ([.labels[] | select(. == "done" or . == "cancelled")] | length) as $t
      | select($t != 1) | .iid'); do
    merged="$(closed_by_merged "$iid")" || { echo "lifecycle-lint: closed_by lookup failed for #$iid" >&2; exit 2; }
    DATA="$(printf '%s' "$DATA" | jq --argjson i "$iid" --argjson m "$merged" \
      'map(if .iid == $i then .closed_by_merged = $m else . end)')"
  done
else
  echo "lifecycle-lint: give --issues <file>, or --provider and --project" >&2; exit 2
fi

PLAN="$(printf '%s' "$DATA" | jq --argjson L "$LIFECYCLE" '
  def rank: {"intent":0,"spec-gated":1,"executing":2,"parked":3,"validation":4}[.];
  def classify:
    [.labels[] | select(. as $l | $L | index($l))] as $lc
    | [$lc[] | select(. != "done" and . != "cancelled")] as $nt
    | ($lc | length) as $n
    | if .state == "closed" then
        ($n - ($nt | length)) as $t
        | if $n == 1 and $t == 1 then null
          else
            { lifecycle: $lc,
              violation: (if $n == 0 then "closed, no lifecycle label"
                          elif $t == 0 then "closed, not terminal"
                          else "closed, extra lifecycle labels" end),
              proposed: (if ($lc | index("done")) and ($lc | index("cancelled") | not) then "done"
                         elif ($lc | index("cancelled")) and ($lc | index("done") | not) then "cancelled"
                         elif .closed_by_merged == true then "done"
                         else "cancelled" end) }
          end
      else
        if $n == 1 and ($nt | length) == 1 then null
        elif $n == 0 then {lifecycle: [], violation: "open, no lifecycle label", proposed: "intent"}
        elif ($nt | length) == 0 then {lifecycle: $lc, violation: "open, terminal label only", proposed: "-"}
        else
          { lifecycle: $lc,
            violation: (if ($nt | length) < $n then "open, terminal label on an open issue"
                        else "open, \($n) lifecycle labels" end),
            proposed: ($nt | max_by(rank)) }
        end
      end;
  sort_by(.iid)
  | map(. as $i | (classify) as $c | select($c != null) | {iid, state, labels} + $c
        + {interactive: ($i.labels | index("interactive") != null)})
  | { violations: map(select(.interactive | not) | del(.interactive)),
      interactive: map(select(.interactive) | del(.interactive)) }
')"
TOTAL="$(printf '%s' "$DATA" | jq 'length')"
PLAN="$(printf '%s' "$PLAN" | jq --argjson n "$TOTAL" --arg p "$PROJECT" \
  '{project: (if $p == "" then null else $p end), issues: $n} + .')"

V="$(printf '%s' "$PLAN" | jq '.violations | length')"
I="$(printf '%s' "$PLAN" | jq '.interactive | length')"

if [ "$V" -gt 0 ]; then
  echo "| Issue | State | Lifecycle labels | Violation | Proposed |"
  echo "|--|--|--|--|--|"
  printf '%s' "$PLAN" | jq -r '.violations[]
    | "| #\(.iid) | \(.state) | \(if (.lifecycle | length) == 0 then "none" else (.lifecycle | join(", ")) end) | \(.violation) | \(.proposed) |"'
  echo
fi
if [ "$I" -gt 0 ]; then
  echo "Interactive issues (reported, not counted):"
  printf '%s' "$PLAN" | jq -r '.interactive[] | "- #\(.iid) (\(.state)): \(.violation)"'
  echo
fi
echo "lifecycle-lint: $TOTAL issues, $V violations, $I interactive (reported, not counted)"

[ -n "$JSON_OUT" ] && printf '%s\n' "$PLAN" > "$JSON_OUT"
[ "$V" -eq 0 ]
