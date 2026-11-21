#!/usr/bin/env bash
# confirm-validation-label.sh — set the PR/MR `validation` label, then confirm
# it landed (SF-REVIEW-CONTRACT-01, adlc-team-skills#185).
#
# Why: a factory-review verdict has post-verdict.sh's post-then-confirm loop
# (read back, retry, fail closed), but §2 step 6's label had no confirm — an
# agent that skipped the set, or a set the tracker silently dropped, looked
# exactly like a completed review. This command makes the label deterministic
# too: one invocation, one read-back, exit non-zero unless exactly the target
# lifecycle label remains. PowerShell twin: ../powershell/confirm-validation-label.ps1.
#
# Usage:
#   confirm-validation-label.sh --mr <ref> [--to <label>] [--check-only]
#
#   <ref>  GitLab: <group>/<project>!<iid>   (the review lane's mr_ref)
#          GitHub: <owner>/<repo>#<number>
#   --to   lifecycle label to set (default: validation)
#   --check-only  answer only: exit 0 when the label is on the PR/MR, 1 when
#          it is not (nothing is written).
# The ref picks the provider. GitLab calls go only to GITLAB_HOST (the token
# is never sent to a guessed host); GitHub calls only to github.com.
# Credentials are whatever `glab api` / `gh api` already use (GITLAB_TOKEN /
# GH_TOKEN in the environment) — this script never reads, prints or stores
# a token.
#
# Exit codes:
#   0  the label is on the PR/MR (set now, or already there)
#   1  the label is not on the PR/MR after the set (or --check-only found it
#      absent) — report this on the thread, never as done
#   2  usage error, unknown labels, or the tracker could not be read
# A tracker error line ends with the CLI's own error line (the HTTP status).
set -uo pipefail

die() { echo "confirm-validation-label: $*" >&2; exit 2; }

MR="" TO="validation" CHECK_ONLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mr)         [ -n "${2:-}" ] || die "--mr is required"; MR="$2"; shift 2 ;;
    --to)         [ -n "${2:-}" ] || die "--to requires a value"; TO="$2"; shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help)    sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown argument '$1'" ;;
  esac
done
[ -n "$MR" ] || die "--mr is required"
[[ "$TO" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || die "--to is not a valid label name"
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

tmp_dir="$(mktemp -d)" || die "cannot create a temporary directory"
trap 'rm -rf "$tmp_dir"' EXIT
err_file="$tmp_dir/api.err"

# Why the tracker CLI failed: the line of its stderr that carries the HTTP
# status, else its last line — one line, at most 200 characters, token-shaped
# strings removed (same rule as the other script twins).
why() {
  local l
  l="$(grep -E 'HTTP [0-9]{3}' "$err_file" 2>/dev/null | tail -n 1)"
  [ -n "$l" ] || l="$(grep -v '^[[:space:]]*$' "$err_file" 2>/dev/null | tail -n 1)"
  l="$(printf '%s' "$l" | tr -d '\000-\037' | cut -c1-200 \
    | sed -E 's/(glpat-|ghp_|gho_|ghs_|github_pat_)[A-Za-z0-9_-]+/<redacted>/g')"
  printf '%s' "${l:-no error text from the tracker CLI}"
}

# The PR/MR's labels, one per line (GitLab: strings; GitHub: objects with
# .name). The same script text runs in the PowerShell twin.
READ_JS='
const raw = require("fs").readFileSync(process.argv[1], "utf8");
const labels = (JSON.parse(raw).labels || []).map(l => typeof l === "string" ? l : l.name);
console.log(labels.join("\n"));
'

read_labels() {
  if [ "$provider" = gitlab ]; then
    api "projects/$p/merge_requests/$iid" > "$tmp_dir/mr.json" 2>"$err_file" \
      || die "cannot read the labels of $MR — $(why)"
    node -e "$READ_JS" "$tmp_dir/mr.json"
  else
    api "repos/$project/pulls/$iid" > "$tmp_dir/pr.json" 2>"$err_file" \
      || die "cannot read the labels of $MR — $(why)"
    node -e "$READ_JS" "$tmp_dir/pr.json"
  fi
}

current="$(read_labels)" || exit 2
if printf '%s\n' "$current" | grep -qx -- "$TO"; then
  echo "confirm-validation-label: OK — $MR already carries '$TO'"; exit 0
fi

if [ "$CHECK_ONLY" = 1 ]; then
  echo "confirm-validation-label: MISSING — $MR does not carry '$TO'" >&2; exit 1
fi

# Only the stage-name label is set here; the command never moves the issue's
# lifecycle label (that stays the Set Lifecycle step, Operation 9).
if [ "$provider" = gitlab ]; then
  api -X PUT "projects/$p/merge_requests/$iid" -H 'Content-Type: application/json' --input - >/dev/null 2>"$err_file" <<< "{\"add_labels\": \"$TO\"}" \
    || die "the tracker refused to label $MR — $(why)"
else
  api -X POST "repos/$project/issues/$iid/labels" -H 'Content-Type: application/json' --input - >/dev/null 2>"$err_file" <<< "{\"labels\": [\"$TO\"]}" \
    || die "the tracker refused to label $MR — $(why)"
fi

after="$(read_labels)" || exit 2
if printf '%s\n' "$after" | grep -qx -- "$TO"; then
  echo "confirm-validation-label: OK — $MR now carries '$TO'"; exit 0
fi
echo "confirm-validation-label: FAIL — '$TO' is not on $MR after the set; report this on the thread, never as done" >&2
exit 1
