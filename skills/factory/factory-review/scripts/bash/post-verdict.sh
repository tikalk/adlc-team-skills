#!/usr/bin/env bash
# post-verdict.sh — post a factory-review verdict, then confirm it landed
# (SF-SKILL-01). PowerShell twin: ../powershell/post-verdict.ps1.
#
# Why: a review that composes a verdict but never posts it looks exactly like
# a finished review — the run ends Succeeded and the Slack status line quotes
# the agent's last message (octopus-next!1298 and !1302, 2026-11-09). Posting
# and the read-back are therefore one deterministic command, not prose.
#
# Usage:
#   post-verdict.sh --mr <ref> --head <sha40> --body-file <file> [--retries <1-9>]
#                   [--pipeline-wait <0-3600 seconds>]
#   post-verdict.sh --mr <ref> --head <sha40> --check-only [--run <run_id>]
#
#   <ref>  GitLab: <group>/<project>!<iid>   (the review lane's mr_ref)
#          GitHub: <owner>/<repo>#<number>
#   The ref picks the provider. GitLab calls go only to GITLAB_HOST (the token
#   is never sent to a guessed host); GitHub calls only to github.com.
#   Credentials are whatever `glab api` / `gh api` already use (GITLAB_TOKEN /
#   GH_TOKEN in the environment) — this script never reads, prints or stores
#   a token. `glab api` works in runner pods even where `glab auth status`
#   reports no login.
#
# Posting mode checks the body before anything is sent: its first non-blank
# line must be the ONE `<!-- factory-review:step=review … -->` marker, the
# marker's head= must equal --head and it must carry a run=, and the whole
# body must pass `verdict-schema.sh lint` (SF-SKILL-02). It then posts
# (GitLab: a threaded MR discussion; GitHub: a COMMENT review bound to --head —
# never an approval), reads the thread back and requires a comment carrying a
# review marker with this head, run= and iter=. A verdict already on the
# thread for the same run=, iter= and head= is not posted twice.
#
# Pipeline at posting (SF-RT-05): before it posts, the script reads the head's
# CI as it is now (GitLab: the head's latest pipeline and its jobs; GitHub:
# the head's check runs) and appends one generated line to the body —
# "**Pipeline at posting (generated):** #<id> <status> — <job> <status> · …".
# It refuses the body (exit 2, nothing posted) when the verdict's own words
# call a job green/passed/success while that job is not `success`, or when the
# marker says outcome=merge-ready while a job that is not allowed to fail is
# unfinished or failed. Jobs named like "verdict" (checks that wait for the
# verdict itself) are ignored. When the pipeline cannot be read, the line says
# so and the verdict is posted as before. --pipeline-wait <s> re-reads the
# pipeline every POST_VERDICT_PIPELINE_POLL seconds (default 30) for up to <s>
# seconds while the only reason to refuse is a job that has not finished.
# (octopus-next!1352, 2026-11-23: "unit-tests green" posted at 23:18:29; the
# job was running and failed at 23:20:50.)
#
# --check-only posts nothing: it only answers "is a verdict for this head (and
# this run, with --run) on the thread?" — the question a lane step asks after
# the agent has exited.
#
# Every read asks for all pages (`--paginate`, both providers): on GitLab the
# newest 100 notes are not the whole thread — system notes and inline diff
# notes count too — and a one-page read made --check-only miss a verdict and
# the already-posted lookup post it twice (SF-FIX-11).
#
# Exit codes:
#   0  the verdict is on the thread (posted now, or already there)
#   1  not on the thread after all retries (posting mode) / not found (check)
#   2  usage error, invalid body (schema, or a claim the pipeline contradicts),
#      or the tracker could not be read
# A tracker error line ends with the CLI's own error line (the HTTP status).
set -uo pipefail

die() { echo "post-verdict: $*" >&2; exit 2; }

MR="" HEAD_SHA="" BODY_FILE="" CHECK_ONLY=0 RETRIES=3 RUN_FILTER="" PIPELINE_WAIT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mr)         [ -n "${2:-}" ] || die "--mr requires a value"; MR="$2"; shift 2 ;;
    --head)       [ -n "${2:-}" ] || die "--head requires a value"; HEAD_SHA="$2"; shift 2 ;;
    --body-file)  [ -n "${2:-}" ] || die "--body-file requires a value"; BODY_FILE="$2"; shift 2 ;;
    --retries)    [[ "${2:-}" =~ ^[1-9]$ ]] || die "--retries takes 1-9"; RETRIES="$2"; shift 2 ;;
    --run)        [ -n "${2:-}" ] || die "--run requires a value"; RUN_FILTER="$2"; shift 2 ;;
    --pipeline-wait) { [[ "${2:-}" =~ ^[0-9]{1,4}$ ]] && [ "$((10#$2))" -le 3600 ]; } || die "--pipeline-wait takes 0-3600 (seconds)"
                  PIPELINE_WAIT=$((10#$2)); shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help)    sed -n '2,62p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown argument '$1'" ;;
  esac
done
[ -n "$MR" ] || die "--mr is required"
[[ "$HEAD_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || die "--head must be the full 40-character SHA"
HEAD_SHA="$(printf '%s' "$HEAD_SHA" | tr '[:upper:]' '[:lower:]')"
[ -z "$RUN_FILTER" ] || [[ "$RUN_FILTER" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "--run is not a valid run id"
command -v node >/dev/null 2>&1 || die "node is required"

if [[ "$MR" =~ ^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)!([0-9]+)$ ]]; then
  provider=gitlab; project="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[3]}"
  case "$project" in *..*) die "invalid --mr" ;; esac
  host="${GITLAB_HOST:-}"; host="${host#https://}"; host="${host%/}"
  [ -n "$host" ] || die "GITLAB_HOST is not set (the token is never sent to a guessed host)"
  command -v glab >/dev/null 2>&1 || die "glab is required for a GitLab --mr"
  p="$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$project")"
elif [[ "$MR" =~ ^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$ ]]; then
  provider=github; project="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[2]}"
  case "$project" in *..*) die "invalid --mr" ;; esac
  command -v gh >/dev/null 2>&1 || die "gh is required for a GitHub --mr"
else
  die "--mr must be <group>/<project>!<iid> (GitLab) or <owner>/<repo>#<number> (GitHub)"
fi

api() {
  if [ "$provider" = gitlab ]; then glab api --hostname "$host" "$@"; else gh api --hostname github.com "$@"; fi
}

# Parses the review marker of a body file (argv[1]). Prints
# "<count>\t<first-line-ok>\t<head>\t<run>\t<iter>" ("-" for an absent field).
# The same script text runs in the PowerShell twin.
MARKER_JS='
const s = require("fs").readFileSync(process.argv[1], "utf8");
const re = /<!--\s*(factory-review:step=review(?=\s|-->)[\s\S]*?)-->/g;
const all = [...s.matchAll(re)];
const first = (s.split(/\r?\n/).find(l => l.trim() !== "") || "").trim();
const firstOk = /^<!--\s*factory-review:step=review(?=\s|-->).*-->$/.test(first) ? "yes" : "no";
const seg = all.length ? all[0][1] : "";
const tok = k => { const m = seg.match(new RegExp("(?:^|\\s)" + k + "=(\\S+)")); return m ? m[1] : "-"; };
console.log([all.length, firstOk, tok("head").toLowerCase(), tok("run"), tok("iter")].join("\t"));
'

# Reads the thread payload file (argv[1]: one or more JSON arrays, as
# `--paginate` concatenates them) and prints the id of the newest comment whose
# review marker names head argv[2] (and run argv[3], iter argv[4] when
# non-empty). Exit 3 = the payload is not JSON (a read failure, never
# "absent"). The same script text runs in the PowerShell twin.
FIND_JS='
const s = require("fs").readFileSync(process.argv[1], "utf8");
const [head, run, iter] = process.argv.slice(2);
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
} catch (e) { process.exit(3); }
const notes = values.flatMap(v => Array.isArray(v) ? v : [v]).filter(n => n && typeof n === "object");
const re = /<!--\s*(factory-review:step=review(?=\s|-->)[\s\S]*?)-->/;
const tok = (seg, k) => { const m = seg.match(new RegExp("(?:^|\\s)" + k + "=(\\S+)")); return m ? m[1] : ""; };
const hits = notes.filter(n => {
  const m = re.exec(typeof n.body === "string" ? n.body : "");
  if (!m) return false;
  if (tok(m[1], "head").toLowerCase() !== head) return false;
  if (run && tok(m[1], "run") !== run) return false;
  if (iter && tok(m[1], "iter") !== iter) return false;
  return true;
});
if (hits.length) console.log(String(hits[0].id));
'

# Reads the head's CI (SF-RT-05). `id <provider> <file>` prints
# "<id>\t<status>" of the newest pipeline in a pipeline list (nothing when
# there is none; exit 3 when it is not JSON). `eval <provider> <body-file>
# <jobs-file|-> <label> <out-file>` prints the generated pipeline line, then
# one line per refusal; exit 0 = post (out-file = body + generated line),
# 4 = refuse, 5 = refuse only because a job has not finished (waiting may
# clear it). The same script text runs in the
# PowerShell twin.
PIPELINE_JS='
const fs = require("fs");
const [mode, provider, a1, a2, a3, a4] = process.argv.slice(1);
const parseAll = s => {
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
  } catch (e) { return null; }
  return values;
};
const read = f => { try { return fs.readFileSync(f, "utf8"); } catch (e) { return null; } };
const objs = v => v.flatMap(x => Array.isArray(x) ? x : [x]).filter(o => o && typeof o === "object");
const clean = s => String(s).replace(/[\x00-\x1f<>`*_|\[\]\\]/g, "").trim().slice(0, 80);
if (mode === "id") {
  // argv: id gitlab <pipelines-file>. Prints "<id>\t<status>" of the newest
  // pipeline, nothing when there is none; exit 3 when the answer is not JSON.
  const v = parseAll(read(a1) || "\u0000");
  if (!v) process.exit(3);
  const list = objs(v).filter(o => Number.isInteger(o.id)).sort((x, y) => y.id - x.id);
  if (list.length) console.log(list[0].id + "\t" + (String(list[0].status || "unknown").replace(/[^a-z_]/g, "") || "unknown"));
  process.exit(0);
}
// argv: eval <gitlab|github> <body-file> <jobs-file or "-"> <label> <out-file>
// Line 1 of stdout: the generated pipeline line. Further lines: one refusal
// each. Exit 0 = post (out-file then holds the body plus the generated line);
// 4 = refuse; 5 = refuse, but only for jobs that have not finished (waiting
// may clear it).
const body = read(a1);
if (body === null) process.exit(3);
let label = clean(a3 || "unavailable");
let jobs = null;
if (a2 && a2 !== "-") {
  const v = parseAll(read(a2) || "\u0000");
  if (!v) label += " — the job list was not JSON";
  else if (provider === "gitlab") {
    jobs = objs(v).filter(j => typeof j.name === "string" && typeof j.status === "string")
      .sort((x, y) => (Number(x.id) || 0) - (Number(y.id) || 0))
      .map(j => ({ name: j.name, status: j.status, allowed: j.allow_failure === true }));
  } else {
    const gh = { success: "success", neutral: "skipped", skipped: "skipped", failure: "failed", timed_out: "failed",
      startup_failure: "failed", cancelled: "canceled", stale: "canceled", action_required: "manual" };
    jobs = objs(v).flatMap(o => Array.isArray(o.check_runs) ? o.check_runs : (typeof o.name === "string" ? [o] : []))
      .filter(c => c && typeof c.name === "string")
      .map(c => ({ name: c.name, allowed: false,
        status: c.status !== "completed" ? (c.status === "in_progress" ? "running" : "pending") : (gh[c.conclusion] || "failed") }));
  }
}
// A job that waits for the verdict itself (the "Verdict names the current
// head" check) is never evidence about the code.
if (jobs) jobs = jobs.filter(j => !/verdict/i.test(j.name));
const done = s => ["success", "skipped", "manual"].includes(s);
const bad = s => ["failed", "canceled"].includes(s);
let line = "**Pipeline at posting (generated):** " + label;
if (jobs) line += " — " + (jobs.length ? jobs.map(j => `${clean(j.name)} ${clean(j.status)}${j.allowed ? " (allowed to fail)" : ""}`).join(" · ") : "no jobs");
const reasons = []; let final = false;
if (jobs && jobs.length) {
  // Only the words the reviewer wrote: fenced blocks and block quotes are quotations.
  let quoted = false;
  const prose = body.split(/\r?\n/).map(l => {
    const t = l.trim();
    if (/^(```|~~~)/.test(t)) { quoted = !quoted; return ""; }
    return quoted || t.startsWith(">") ? "" : l;
  }).join("\n");
  const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const names = [...new Set(jobs.map(j => j.name))].filter(n => n.trim().length >= 2);
  for (const name of names) {
    const re = new RegExp("(?:^|[^A-Za-z0-9_.-])" + esc(name) + "(?![A-Za-z0-9_-])[`*\"\\x27]*\\s*" +
      "(?:(?:[:=]|->|→|—|–|-)\\s*|(?:is|are|was|were)\\s+)*[`*\"\\x27]*\\s*(?:✅|green|passed|passing|succeeded|successful|success)(?![A-Za-z])", "i");
    if (!re.test(prose)) continue;
    for (const j of jobs.filter(x => x.name === name && x.status !== "success")) {
      reasons.push(`the verdict calls "${clean(name)}" green, but at posting its status is ${clean(j.status)}`);
      if (bad(j.status) || done(j.status)) final = true;
    }
  }
  const marker = body.match(/<!--\s*factory-review:step=review(?=\s|-->)([\s\S]*?)-->/);
  const outcome = marker ? ((marker[1].match(/(?:^|\s)outcome=(\S+)/) || [])[1] || "") : "";
  if (outcome === "merge-ready") {
    for (const j of jobs.filter(x => !x.allowed && !done(x.status))) {
      reasons.push(`outcome=merge-ready, but at posting "${clean(j.name)}" is ${clean(j.status)} (a job that is not allowed to fail)`);
      if (bad(j.status)) final = true;
    }
  }
}
console.log(line);
for (const r of reasons) console.log(r);
if (reasons.length) process.exit(final ? 4 : 5);
try { fs.writeFileSync(a4, body + (body.endsWith("\n") ? "" : "\n") + "\n" + line + "\n"); } catch (e) { process.exit(3); }
'

tmp_dir="$(mktemp -d)" || die "cannot create a temporary directory"
trap 'rm -rf "$tmp_dir"' EXIT
err_file="$tmp_dir/api.err"

# Why the tracker CLI failed: the line of its stderr that carries the HTTP
# status (glab and gh print e.g. "glab: 403 Forbidden (HTTP 403)"), else its
# last line — one line, at most 200 characters, token-shaped strings removed.
why() {
  local l
  l="$(grep -E 'HTTP [0-9]{3}' "$err_file" 2>/dev/null | tail -n 1)"
  [ -n "$l" ] || l="$(grep -v '^[[:space:]]*$' "$err_file" 2>/dev/null | tail -n 1)"
  l="$(printf '%s' "$l" | tr -d '\000-\037' | cut -c1-200 \
    | sed -E 's/(glpat-|ghp_|gho_|ghs_|github_pat_)[A-Za-z0-9_-]+/<redacted>/g')"
  printf '%s' "${l:-no error text from the tracker CLI}"
}

# Writes all thread comments (GitLab notes; GitHub reviews + issue comments)
# to $tmp_dir/thread.json as concatenated JSON. Fails closed: an unreadable
# thread is exit 2.
read_thread() {
  local f="$tmp_dir/thread.json"
  if [ "$provider" = gitlab ]; then
    api --paginate "projects/$p/merge_requests/$iid/notes?sort=desc&order_by=created_at&per_page=100" > "$f" 2>"$err_file" \
      || die "cannot read the notes of $MR — $(why)"
  else
    api --paginate "repos/$project/pulls/$iid/reviews?per_page=100" > "$f" 2>"$err_file" || die "cannot read the reviews of $MR — $(why)"
    printf '\n' >> "$f"
    api --paginate "repos/$project/issues/$iid/comments?per_page=100" >> "$f" 2>"$err_file" || die "cannot read the comments of $MR — $(why)"
  fi
}

# Sets $id when a verdict for HEAD_SHA (run $1, iter $2 when given) is on the
# thread; returns 1 when it is not. Exits 2 when the thread cannot be read.
lookup() {
  read_thread
  id="$(node -e "$FIND_JS" "$tmp_dir/thread.json" "$HEAD_SHA" "$1" "$2")" || die "cannot parse the comments of $MR"
  id="${id//[[:space:]]/}"
  [ -n "$id" ]
}

if [ "$CHECK_ONLY" = 1 ]; then
  [ -z "$BODY_FILE" ] || die "--check-only takes no --body-file"
  if lookup "$RUN_FILTER" ""; then
    echo "post-verdict: OK — verdict for head=$HEAD_SHA is on $MR (comment $id)"; exit 0
  fi
  echo "post-verdict: MISSING — no factory-review verdict for head=$HEAD_SHA${RUN_FILTER:+ run=$RUN_FILTER} on $MR"
  exit 1
fi

[ -n "$BODY_FILE" ] && [ -f "$BODY_FILE" ] || die "--body-file <file> is required and must exist"
fields="$(node -e "$MARKER_JS" "$BODY_FILE")" || die "cannot read --body-file"
IFS=$'\t' read -r count first_ok body_head body_run body_iter <<< "$fields"
[ "$count" = 1 ] || die "the body must carry exactly one factory-review:step=review marker (found $count)"
[ "$first_ok" = yes ] || die "the marker must be the first non-blank line of the body"
[ "$body_head" = "$HEAD_SHA" ] || die "the marker names head=$body_head but --head is $HEAD_SHA"
[ "$body_run" != "-" ] || die "the marker carries no run="
[[ "$body_run" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "the marker's run=$body_run is not a valid run id"
[ "$body_iter" != "-" ] || body_iter=""
# The full schema — marker fields, run id, counts, headings, wording
# (SF-SKILL-02). A body that fails it is never sent.
if ! lint_out="$(bash "$(dirname "$0")/verdict-schema.sh" lint "$BODY_FILE")"; then
  printf '%s\n' "$lint_out" >&2
  die "the body does not follow the verdict schema (verdict-schema.sh lint); nothing was posted"
fi

if lookup "$body_run" "$body_iter"; then
  echo "post-verdict: OK — already on $MR (comment $id), not posted twice"; exit 0
fi

# Sets $jobs_arg (a file with the head's jobs, or empty) and $label (what the
# generated line says about the pipeline). Never fails: an unreadable pipeline
# is stated in $label and posting goes on as before.
read_pipeline() {
  local pl="$tmp_dir/pipelines.json" jf="$tmp_dir/jobs.json" idst id st
  jobs_arg=""
  if [ "$provider" = gitlab ]; then
    if ! api "projects/$p/pipelines?sha=$HEAD_SHA&order_by=id&sort=desc&per_page=1" > "$pl" 2>"$err_file"; then
      label="unavailable — $(why)"; return 0
    fi
    if ! idst="$(node -e "$PIPELINE_JS" id gitlab "$pl")"; then
      label="unavailable — the pipeline list was not JSON"; return 0
    fi
    if [ -z "$idst" ]; then label="no pipeline for head ${HEAD_SHA:0:8}"; return 0; fi
    id="${idst%%$'\t'*}"; st="${idst#*$'\t'}"
    label="#$id $st"
    if ! api --paginate "projects/$p/pipelines/$id/jobs?per_page=100" > "$jf" 2>"$err_file"; then
      label="#$id $st — jobs unavailable — $(why)"; return 0
    fi
  else
    if ! api --paginate "repos/$project/commits/$HEAD_SHA/check-runs?per_page=100" > "$jf" 2>"$err_file"; then
      label="unavailable — $(why)"; return 0
    fi
    label="check runs on ${HEAD_SHA:0:8}"
  fi
  jobs_arg="$jf"
}

# The verdict as it is posted: the body plus the generated pipeline line.
# Refuses (exit 2) a body the pipeline contradicts; see the header.
final_body="$tmp_dir/body.md"
waited=0
poll="${POST_VERDICT_PIPELINE_POLL:-30}"
[[ "$poll" =~ ^[0-9]{1,4}$ ]] || poll=30
poll=$((10#$poll))
while :; do
  read_pipeline
  gate_out="$(node -e "$PIPELINE_JS" eval "$provider" "$BODY_FILE" "${jobs_arg:--}" "$label" "$final_body")"; gate_rc=$?
  case "$gate_rc" in
    0) break ;;
    4|5)
      if [ "$gate_rc" = 5 ] && [ "$waited" -lt "$PIPELINE_WAIT" ]; then
        echo "post-verdict: the pipeline has not finished; reading it again in ${poll}s (waited ${waited}s of ${PIPELINE_WAIT}s)" >&2
        sleep "$poll"; waited=$((waited + (poll > 0 ? poll : 1))); continue
      fi
      printf '%s\n' "$gate_out" | sed -n '2,$p' | sed 's/^/post-verdict: /' >&2
      printf 'post-verdict: %s\n' "$(printf '%s\n' "$gate_out" | head -n 1)" >&2
      if [ "$gate_rc" = 5 ]; then
        die "the verdict states a result the pipeline does not have yet; nothing was posted — post when the pipeline has finished (re-run with --pipeline-wait <seconds>), or say the job is still running"
      fi
      die "the verdict contradicts the pipeline at posting; nothing was posted — correct the verdict to match the jobs above" ;;
    *) die "cannot evaluate the pipeline of head=$HEAD_SHA (exit $gate_rc)" ;;
  esac
done

payload_file="$tmp_dir/payload.json"
if [ "$provider" = gitlab ]; then
  node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8")}))' \
    "$final_body" "$payload_file" || die "cannot build the request body"
else
  node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8"), event: "COMMENT", commit_id: process.argv[3]}))' \
    "$final_body" "$payload_file" "$HEAD_SHA" || die "cannot build the request body"
fi

attempt=1
while [ "$attempt" -le "$RETRIES" ]; do
  if [ "$attempt" -gt 1 ] && lookup "$body_run" "$body_iter"; then
    echo "post-verdict: OK — posted and confirmed on $MR (comment $id, head=$HEAD_SHA, run=$body_run)"; exit 0
  fi
  if [ "$provider" = gitlab ]; then
    api -X POST "projects/$p/merge_requests/$iid/discussions" -H 'Content-Type: application/json' --input "$payload_file" >/dev/null 2>"$err_file" \
      || echo "post-verdict: attempt $attempt: the tracker refused the post — $(why)" >&2
  else
    api -X POST "repos/$project/pulls/$iid/reviews" --input "$payload_file" >/dev/null 2>"$err_file" \
      || echo "post-verdict: attempt $attempt: the tracker refused the post — $(why)" >&2
  fi
  if lookup "$body_run" "$body_iter"; then
    echo "post-verdict: OK — posted and confirmed on $MR (comment $id, head=$HEAD_SHA, run=$body_run)"; exit 0
  fi
  [ "$attempt" -lt "$RETRIES" ] && sleep "${POST_VERDICT_BACKOFF:-$((attempt * 5))}"
  attempt=$((attempt + 1))
done
echo "post-verdict: FAIL — the verdict for head=$HEAD_SHA is not on $MR after $RETRIES attempt(s); the review failed" >&2
exit 1
