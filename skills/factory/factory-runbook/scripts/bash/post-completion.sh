#!/usr/bin/env bash
# post-completion.sh — leave the one completion record of a mission run on its
# issue (SF-SKILL-05). PowerShell twin: ../powershell/post-completion.ps1.
#
# Why: missions ended with no word on the issue (octopus-next#1507, #1510,
# #1512, #1516: Argo "Succeeded", only a start marker), or with records in
# three marker spellings, one with an invented run id (#1523
# `run=test-1523`), or wrote "completed" for a run that a gate then parked
# (#1530). This command writes exactly one record per run, in one format,
# for every outcome, and reads it back.
#
# Usage:
#   post-completion.sh --outcome <done|no-op|blocked|failed> --conclusion "<one line>"
#                      [--issue <group>/<project>#<iid>] [--mr-url <https url>]
#                      [--details-file <markdown>] [--step <step id>]
#   done    = the code MR/PR is open      no-op  = nothing needed changing (say why)
#   blocked = a gate, dependency, missing input or refused helper stopped the run
#   failed  = the run could not finish
#   The run id comes from the run context (ADLC_RUN_ID, else the lane's
#   WORKFLOW_INPUTS.run_id through run-context.sh) — never from an argument;
#   without one the command refuses. --issue defaults to the run's issue.
#
# The record (one note):
#   <!-- factory-mission:step=complete status=<completed|failed> run=<id> type=decision outcome=<outcome> -->
#   <!-- factory-run:ended reason=step-failed run=<id> step=<step> -->   (blocked / failed only:
#        the state machine's "run ended badly" note, carried by the same note)
#   ### Mission <outcome>
#   **Code MR:** <url | none>
#   **Conclusion:** <one line>
#   **Next:** ...the completion gate...      (only in a workflow run, where a gate follows)
#   <details file, verbatim — e.g. the proof-of-work block of SF-SKILL-07>
#   **Run:** <id>
#
# One record per run: when the issue already has a completion record for this
# run (`factory-mission:step=complete`, the older `factory-mission:status=
# completed:run=`, or a `factory-run:ended` note), nothing is posted.
#
# Exit codes: 0 the record is on the issue (posted now, or already there for
# this run); 1 it never landed; 2 usage error, no run context, or the tracker
# could not be read.
set -uo pipefail

die()  { echo "post-completion: $*" >&2; exit 2; }
json() { node -e "$1" "${@:2}"; }
here="$(cd "$(dirname "$0")" && pwd)"

ISSUE="" OUTCOME="" CONCLUSION="" MR_URL="" DETAILS="" STEP="execute"
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || die "missing value for $1"
  case "$1" in
    --issue) ISSUE="$2" ;;
    --outcome) OUTCOME="$2" ;;
    --conclusion) CONCLUSION="$2" ;;
    --mr-url) MR_URL="$2" ;;
    --details-file) DETAILS="$2" ;;
    --step) STEP="$2" ;;
    *) die "unknown argument '$1'" ;;
  esac
  shift 2
done
case "$OUTCOME" in done|no-op) status=completed ;; blocked|failed) status=failed ;; *) die "--outcome must be done, no-op, blocked or failed" ;; esac
CONCLUSION="$(printf '%s' "$CONCLUSION" | tr '\r\n\t' '   ' | tr -s ' ')"; CONCLUSION="${CONCLUSION:0:300}"
[ -n "${CONCLUSION// /}" ] || die "--conclusion is required"
[ -z "$DETAILS" ] || [ -f "$DETAILS" ] || die "--details-file $DETAILS does not exist"
case "$MR_URL" in ""|https://*) ;; *) die "--mr-url must be an https URL" ;; esac
case "$MR_URL" in *[[:space:]]*) die "--mr-url must be one URL" ;; esac
[[ "$STEP" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid --step"
command -v node >/dev/null 2>&1 || die "node is required"

# shellcheck source=run-context.sh
if [ -z "${ADLC_RUN_ID:-}" ] || [ -z "$ISSUE${ADLC_ISSUE_REF:-}" ]; then . "$here/run-context.sh"; fi
[ -n "${ADLC_RUN_ID:-}" ] || die "no run context (ADLC_RUN_ID unset, no run_id in WORKFLOW_INPUTS) — a completion record names its run"
[[ "$ADLC_RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid ADLC_RUN_ID"
RUN="$ADLC_RUN_ID"
[ -n "$ISSUE" ] || ISSUE="${ADLC_ISSUE_REF:-}"
[ -n "$ISSUE" ] || die "--issue <group>/<project>#<iid> is required (no issue in the run context)"
case "$ISSUE" in *..*) die "invalid --issue" ;; esac
[[ "$ISSUE" =~ ^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#([0-9]+)$ ]] || die "--issue must be <group>/<project>#<iid>"
project="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[3]}"

provider="${ISSUE_PROVIDER:-gitlab}"
case "$provider" in
  gitlab)
    [ -n "${GITLAB_HOST:-}" ] || die "GITLAB_HOST is not set (the token is never sent to a guessed host)"
    host="${GITLAB_HOST#https://}"; host="${host%/}"
    api() { glab api --hostname "$host" "$@"; }
    p="$(json 'console.log(encodeURIComponent(process.argv[1]))' "$project")"
    notes_path="projects/$p/issues/$iid/notes"; list_q="?sort=desc&order_by=created_at&per_page=100"
    ;;
  github)
    # GitHub lists the oldest 100 comments first; a thread longer than that
    # can hide a record (then a second one is posted — never none).
    api() { gh api "$@"; }
    notes_path="repos/$project/issues/$iid/comments"; list_q="?per_page=100"
    ;;
  *) die "unsupported ISSUE_PROVIDER: $provider" ;;
esac

# 0: a completion record for this run is on the issue; 1: none; 2: unreadable.
recorded() {
  local out
  out="$(api "$notes_path$list_q" 2>/dev/null)" || return 2
  printf '%s' "$out" | json '
    let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{
      let notes; try { notes = JSON.parse(s || "[]"); } catch (e) { process.exit(2); }
      const run = process.argv[1].replace(/[.]/g, "\\.");
      const re = new RegExp("<!--\\s*factory-(?:mission:step=complete\\b[^>]*\\brun=" + run + "(?:\\s|-->)|run:ended\\b[^>]*\\brun=" + run + "(?:\\s|-->)|mission:status=completed:run=" + run + "(?:\\s|-->|:))");
      process.exit(Array.isArray(notes) && notes.some(n => re.test(String(n.body || ""))) ? 0 : 1);
    });' "$RUN"
}

recorded; rc=$?
[ "$rc" -ne 2 ] || die "cannot read the notes of $ISSUE"
if [ "$rc" -eq 0 ]; then echo "post-completion: OK — a completion record for run $RUN is already on $ISSUE"; exit 0; fi

body_file="$(mktemp)"; trap 'rm -f "$body_file"' EXIT
{
  printf '<!-- factory-mission:step=complete status=%s run=%s type=decision outcome=%s -->\n' "$status" "$RUN" "$OUTCOME"
  if [ "$status" = failed ]; then printf '<!-- factory-run:ended reason=step-failed run=%s step=%s -->\n' "$RUN" "$STEP"; fi
  printf '\n### Mission %s\n\n' "$OUTCOME"
  printf '**Code MR:** %s\n\n' "${MR_URL:-none}"
  printf '**Conclusion:** %s\n\n' "$CONCLUSION"
  if [ -n "${ADLC_STEP_OUTPUT:-}" ]; then
    printf '**Next:** the completion gate — a person approves or rejects the result in Slack; the gate records its own answer on this issue.\n\n'
  fi
  if [ -n "$DETAILS" ]; then cat "$DETAILS"; printf '\n\n'; fi
  printf '**Run:** %s\n' "$RUN"
} > "$body_file"

for attempt in 1 2 3; do
  json 'console.log(JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8")}))' "$body_file" \
    | api -X POST "$notes_path" -H 'Content-Type: application/json' --input - >/dev/null 2>&1 \
    || echo "post-completion: attempt $attempt: the tracker refused the post" >&2
  recorded; rc=$?
  if [ "$rc" -eq 0 ]; then echo "post-completion: OK — completion record ($OUTCOME) posted on $ISSUE for run $RUN"; exit 0; fi
  [ "$attempt" -lt 3 ] && sleep "${POST_COMPLETION_BACKOFF:-$((attempt * 5))}"
done
echo "post-completion: FAIL — the completion record is not on $ISSUE after 3 attempts" >&2
exit 1
