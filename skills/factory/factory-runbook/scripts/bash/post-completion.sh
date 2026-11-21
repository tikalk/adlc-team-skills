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
#   **Replaces:** this run's earlier record (`<what it said>`) …   (only when it said something else)
#   **Next:** ...the completion gate...      (only in a workflow run, where a gate follows)
#   <details file, verbatim — e.g. the proof-of-work block of SF-SKILL-07>
#   **Run:** <id>
#
# One record per run and outcome: the run's newest record on the issue
# (`factory-mission:step=complete`, the older `factory-mission:status=
# completed:run=`, or a `factory-run:ended` note) decides. When it already
# says this outcome, nothing is posted — a retried pod or a second call never
# repeats a record. When it says something else (the lane retried the pod with
# the same run id, or `workflow resume` continued the run, and this time it
# ended differently), a new record is posted that names the one it replaces:
# "Mission failed" must not stay the last word on an issue whose MR is open
# (SF-FIX-11).
#
# Every read asks for all pages (`--paginate`): GitHub lists comments oldest
# first, so on a long thread a one-page read never sees the record just posted.
#
# Exit codes: 0 the record is on the issue (posted now, or already there for
# this run and outcome); 1 it never landed; 2 usage error, no run context, or
# the tracker could not be read. Error lines end with the tracker CLI's own
# last error line (it carries the HTTP status).
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
    api() { gh api "$@"; }
    notes_path="repos/$project/issues/$iid/comments"; list_q="?per_page=100"
    ;;
  *) die "unsupported ISSUE_PROVIDER: $provider" ;;
esac

err_file="$(mktemp)"; body_file="$(mktemp)"; trap 'rm -f "$body_file" "$err_file"' EXIT

# Why the tracker CLI failed: the last line of its stderr (glab and gh print
# the HTTP status there, e.g. "glab: 403 Forbidden (HTTP 403)") — one line,
# at most 200 characters, token-shaped strings removed.
why() {
  local l
  l="$(grep -v '^[[:space:]]*$' "$err_file" 2>/dev/null | tail -n 1 | tr -d '\000-\037' | cut -c1-200 \
    | sed -E 's/(glpat-|ghp_|gho_|ghs_|github_pat_)[A-Za-z0-9_-]+/<redacted>/g')"
  printf '%s' "${l:-no error text from the tracker CLI}"
}

# Reads the issue's notes on stdin (one or more JSON arrays: `--paginate`
# prints one per page) and finds the completion records of run argv[1].
# Exit 0: the newest one already says outcome argv[2]; 1: the run has none;
# 3: the newest one says something else (printed on stdout); 2: not JSON.
# A `factory-run:ended` note without a completion marker reads as "ended" (it
# equals blocked and failed); the old `status=completed:run=` spelling reads
# as "completed" (it equals done and no-op). The same script text runs in the
# PowerShell twin.
RECORD_JS='
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  const [run, want] = process.argv.slice(1);
  const values = []; let i = 0;
  try {
    while (i < s.length) {
      while (i < s.length && /\s/.test(s[i])) i++;
      if (i >= s.length) break;
      let depth = 0, inStr = false, esc = false, j = i;
      for (; j < s.length; j++) {
        const c = s[j];
        if (inStr) { if (esc) esc = false; else if (c === "\\") esc = true; else if (c === "\"") inStr = false; }
        else if (c === "\"") inStr = true;
        else if (c === "[" || c === "{") depth++;
        else if (c === "]" || c === "}") { depth--; if (depth === 0) { j++; break; } }
      }
      values.push(JSON.parse(s.slice(i, j))); i = j;
    }
  } catch (e) { process.exit(2); }
  const notes = values.flatMap(v => Array.isArray(v) ? v : [v]).filter(n => n && typeof n === "object");
  const tok = (seg, k) => { const m = seg.match(new RegExp("(?:^|\\s)" + k + "=(\\S+)")); return m ? m[1] : ""; };
  const old = new RegExp("<!--\\s*factory-mission:status=completed:run=" + run.replace(/[.]/g, "\\.") + "(?:\\s|-->|:)");
  const said = body => {
    for (const m of body.matchAll(/<!--\s*factory-mission:step=complete(?=\s)([^>]*)-->/g)) {
      if (tok(m[1], "run") !== run) continue;
      const o = tok(m[1], "outcome");
      if (["done", "no-op", "blocked", "failed"].includes(o)) return o;
      return tok(m[1], "status") === "failed" ? "ended" : "completed";
    }
    for (const m of body.matchAll(/<!--\s*factory-run:ended(?=\s)([^>]*)-->/g)) {
      if (tok(m[1], "run") === run) return "ended";
    }
    return old.test(body) ? "completed" : "";
  };
  const when = n => { const t = Date.parse(typeof n.created_at === "string" ? n.created_at : ""); return Number.isNaN(t) ? 0 : t; };
  const num = n => (Number.isFinite(Number(n.id)) ? Number(n.id) : 0);
  const records = notes.map(n => ({ n, said: said(typeof n.body === "string" ? n.body : "") })).filter(r => r.said);
  if (!records.length) process.exit(1);
  records.sort((a, b) => when(a.n) - when(b.n) || num(a.n) - num(b.n));
  const last = records[records.length - 1].said;
  const same = last === want ||
    (last === "completed" && (want === "done" || want === "no-op")) ||
    (last === "ended" && (want === "blocked" || want === "failed"));
  if (same) process.exit(0);
  process.stdout.write(last); process.exit(3);
});
'

# 0: this run's newest completion record says $OUTCOME; 1: the run has none;
# 3: its newest record says something else ($earlier); 2: unreadable (see why).
earlier=""
recorded() {
  local out rc
  out="$(api --paginate "$notes_path$list_q" 2>"$err_file")" || return 2
  earlier="$(printf '%s' "$out" | json "$RECORD_JS" "$RUN" "$OUTCOME")"; rc=$?
  [ "$rc" -ne 2 ] || echo "the tracker's answer is not JSON" > "$err_file"
  return "$rc"
}

recorded; rc=$?
[ "$rc" -ne 2 ] || die "cannot read the notes of $ISSUE — $(why)"
if [ "$rc" -eq 0 ]; then echo "post-completion: OK — a completion record ($OUTCOME) for run $RUN is already on $ISSUE"; exit 0; fi
replaces=""; [ "$rc" -ne 3 ] || replaces="$earlier"

{
  printf '<!-- factory-mission:step=complete status=%s run=%s type=decision outcome=%s -->\n' "$status" "$RUN" "$OUTCOME"
  if [ "$status" = failed ]; then printf '<!-- factory-run:ended reason=step-failed run=%s step=%s -->\n' "$RUN" "$STEP"; fi
  printf '\n### Mission %s\n\n' "$OUTCOME"
  printf '**Code MR:** %s\n\n' "${MR_URL:-none}"
  printf '**Conclusion:** %s\n\n' "$CONCLUSION"
  if [ -n "$replaces" ]; then
    printf '**Replaces:** this run'"'"'s earlier record (`%s`) — the same run was retried or resumed and ended differently; this record is the current one.\n\n' "$replaces"
  fi
  if [ -n "${ADLC_STEP_OUTPUT:-}" ]; then
    printf '**Next:** the completion gate — a person approves or rejects the result in Slack; the gate records its own answer on this issue.\n\n'
  fi
  if [ -n "$DETAILS" ]; then cat "$DETAILS"; printf '\n\n'; fi
  printf '**Run:** %s\n' "$RUN"
} > "$body_file"

# Post only after a read that showed the record is not there: posting again
# without seeing the thread is how duplicate records were made.
post=1
for attempt in 1 2 3; do
  if [ "$post" -eq 1 ]; then
    json 'console.log(JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8")}))' "$body_file" \
      | api -X POST "$notes_path" -H 'Content-Type: application/json' --input - >/dev/null 2>"$err_file" \
      || echo "post-completion: attempt $attempt: the tracker refused the post — $(why)" >&2
  fi
  recorded; rc=$?
  if [ "$rc" -eq 0 ]; then echo "post-completion: OK — completion record ($OUTCOME) posted on $ISSUE for run $RUN"; exit 0; fi
  if [ "$rc" -eq 2 ]; then
    post=0; echo "post-completion: attempt $attempt: cannot read the notes of $ISSUE back — $(why)" >&2
  else
    post=1
  fi
  [ "$attempt" -lt 3 ] && sleep "${POST_COMPLETION_BACKOFF:-$((attempt * 5))}"
done
[ "$rc" -ne 2 ] || die "the notes of $ISSUE cannot be read back, so the record is not confirmed (nothing more was posted) — $(why)"
echo "post-completion: FAIL — the completion record is not on $ISSUE after 3 attempts" >&2
exit 1
