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
#   2  usage error, invalid body, or the tracker could not be read
# A tracker error line ends with the CLI's own error line (the HTTP status).
set -uo pipefail

die() { echo "post-verdict: $*" >&2; exit 2; }

MR="" HEAD_SHA="" BODY_FILE="" CHECK_ONLY=0 RETRIES=3 RUN_FILTER=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mr)         [ -n "${2:-}" ] || die "--mr requires a value"; MR="$2"; shift 2 ;;
    --head)       [ -n "${2:-}" ] || die "--head requires a value"; HEAD_SHA="$2"; shift 2 ;;
    --body-file)  [ -n "${2:-}" ] || die "--body-file requires a value"; BODY_FILE="$2"; shift 2 ;;
    --retries)    [[ "${2:-}" =~ ^[1-9]$ ]] || die "--retries takes 1-9"; RETRIES="$2"; shift 2 ;;
    --run)        [ -n "${2:-}" ] || die "--run requires a value"; RUN_FILTER="$2"; shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help)    sed -n '2,39p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

payload_file="$tmp_dir/payload.json"
if [ "$provider" = gitlab ]; then
  node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8")}))' \
    "$BODY_FILE" "$payload_file" || die "cannot build the request body"
else
  node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8"), event: "COMMENT", commit_id: process.argv[3]}))' \
    "$BODY_FILE" "$payload_file" "$HEAD_SHA" || die "cannot build the request body"
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
