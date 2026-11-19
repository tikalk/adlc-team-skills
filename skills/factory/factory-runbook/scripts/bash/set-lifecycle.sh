#!/usr/bin/env bash
# set-lifecycle.sh — the Set Lifecycle step (tracker-integration Operation 9)
# as one self-checking command (SF-SKILL-04). PowerShell twin:
# ../powershell/set-lifecycle.ps1.
#
# Why: Operation 9 was prose only. A supervised mission that opened its code
# MR left its issue on `executing` (octopus-next#1507, run
# adlc-mission-octopus-next-xlmzw, 2026-11-09, MR !1302 open and reviewed)
# although the skill told it to move the label: nothing ran the transition or
# checked it afterwards. This command adds the target, removes every other
# lifecycle label in the same call, re-reads the labels and fails unless
# exactly the target remains. It never touches `resume` (the gate runtime
# owns that trigger).
#
# Usage:
#   set-lifecycle.sh --to <state> [--issue <group>/<project>#<iid>]
#   states: intent spec-gated executing parked validation done cancelled
#   --issue defaults to the run's issue (ADLC_ISSUE_REF, else the lane's
#   WORKFLOW_INPUTS.issue_ref through run-context.sh).
#   Provider: ISSUE_PROVIDER (gitlab, default | github). GitLab host:
#   GITLAB_HOST (required — the token is never sent to a guessed host).
#   Custom label names (`labels:` in .adlc/issues-provider.yml) are not read
#   here: when that block exists the command refuses (exit 2) rather than
#   guess, and the caller follows the Operation 9 prose path.
#
# Exit codes:
#   0  exactly the target lifecycle label is on the issue (moved now, or already there)
#   1  the re-read shows another lifecycle label next to the target, or no target
#   2  usage error, refused custom names, or the tracker could not be read/written
set -uo pipefail

die()  { echo "set-lifecycle: $*" >&2; exit 2; }
json() { node -e "$1" "${@:2}"; }
STATES="intent spec-gated executing parked validation done cancelled"
here="$(cd "$(dirname "$0")" && pwd)"

ISSUE="" TO=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --issue) [ "$#" -ge 2 ] || die "missing --issue value"; ISSUE="$2"; shift 2 ;;
    --to)    [ "$#" -ge 2 ] || die "missing --to value"; TO="$2"; shift 2 ;;
    *) die "unknown argument '$1'" ;;
  esac
done
[ -n "$TO" ] || die "--to <state> is required"
case " $STATES " in *" $TO "*) ;; *) die "--to must be one of: $STATES" ;; esac
if [ -z "$ISSUE" ]; then
  # shellcheck source=run-context.sh
  if [ -z "${ADLC_ISSUE_REF:-}" ]; then . "$here/run-context.sh"; fi
  ISSUE="${ADLC_ISSUE_REF:-}"
fi
[ -n "$ISSUE" ] || die "--issue <group>/<project>#<iid> is required (no issue in the run context)"
case "$ISSUE" in *..*) die "invalid --issue" ;; esac
[[ "$ISSUE" =~ ^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#([0-9]+)$ ]] || die "--issue must be <group>/<project>#<iid>"
project="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[3]}"
command -v node >/dev/null 2>&1 || die "node is required"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$root/.adlc/issues-provider.yml" ] && grep -Eq '^labels:' "$root/.adlc/issues-provider.yml"; then
  die "custom lifecycle label names (.adlc/issues-provider.yml labels:) are not supported by this command — follow tracker-integration Operation 9"
fi

provider="${ISSUE_PROVIDER:-gitlab}"
case "$provider" in
  gitlab)
    [ -n "${GITLAB_HOST:-}" ] || die "GITLAB_HOST is not set (the token is never sent to a guessed host)"
    host="${GITLAB_HOST#https://}"; host="${host%/}"
    api() { glab api --hostname "$host" "$@"; }
    p="$(json 'console.log(encodeURIComponent(process.argv[1]))' "$project")"
    issue_path="projects/$p/issues/$iid"
    ;;
  github)
    api() { gh api "$@"; }
    issue_path="repos/$project/issues/$iid"
    ;;
  *) die "unsupported ISSUE_PROVIDER: $provider" ;;
esac

# The issue's labels, one per line (GitLab: strings; GitHub: objects with .name).
read_labels() {
  api "$issue_path" 2>/dev/null \
    | json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log((JSON.parse(s).labels||[]).map(l=>typeof l==="string"?l:l.name).join("\n")))'
}
lifecycle_of() { local l; while IFS= read -r l; do case " $STATES " in *" $l "*) [ -n "$l" ] && echo "$l" ;; esac; done; }

current="$(read_labels)" || die "cannot read the labels of $ISSUE"
others="$(printf '%s\n' "$current" | lifecycle_of | grep -vx -- "$TO" | paste -sd, -)"
has_target="$(printf '%s\n' "$current" | grep -cx -- "$TO")"

if [ -z "$others" ] && [ "$has_target" -ge 1 ]; then
  echo "set-lifecycle: OK — $ISSUE is already '$TO'"; exit 0
fi

if [ "$provider" = gitlab ]; then
  # One call: add the target and remove every other lifecycle label.
  json 'const [a, r] = process.argv.slice(1); const o = {add_labels: a}; if (r) o.remove_labels = r; console.log(JSON.stringify(o))' "$TO" "$others" \
    | api -X PUT "$issue_path" -H 'Content-Type: application/json' --input - >/dev/null 2>&1 \
    || die "the tracker refused to update the labels of $ISSUE"
else
  json 'console.log(JSON.stringify({labels: [process.argv[1]]}))' "$TO" \
    | api -X POST "$issue_path/labels" --input - >/dev/null 2>&1 || die "the tracker refused to add '$TO' to $ISSUE"
  IFS=, read -r -a rm_list <<< "$others"
  for l in "${rm_list[@]}"; do
    [ -n "$l" ] || continue
    api -X DELETE "$issue_path/labels/$l" >/dev/null 2>&1 || die "the tracker refused to remove '$l' from $ISSUE"
  done
fi

after="$(read_labels)" || die "cannot re-read the labels of $ISSUE"
left="$(printf '%s\n' "$after" | lifecycle_of | paste -sd, -)"
if [ "$left" = "$TO" ]; then
  echo "set-lifecycle: OK — $ISSUE moved to '$TO'${others:+ (removed: $others)}"; exit 0
fi
echo "set-lifecycle: FAIL — $ISSUE carries lifecycle label(s) '${left:-none}' after moving to '$TO'; report this on the issue, never as done" >&2
exit 1
