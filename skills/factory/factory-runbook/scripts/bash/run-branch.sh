#!/usr/bin/env bash
# run-branch.sh — check out the intent or mission run branch in the project root
# (ADR-431-amendment §1, adlc-workspace#26; --kind code under ADR-473).
#
# With a factory run context (ADLC_RUN_ID, ADR-444; in a raw lane run the
# lane's WORKFLOW_INPUTS.run_id, adopted through run-context.sh): check out
#   factory/intent/<repo>-<iid>   from ADLC_ISSUE_REF (<group>/<repo>#<iid>), or
#   factory/intent/run-<run_id>   without an issue (intent, the default);
#   factory/mission/<repo>-<iid>  from ADLC_ISSUE_REF, or
#   factory/mission/run-<run_id>  without an issue (with --kind code);
# continuing from origin when it has the branch (a local copy is fast-forwarded;
# a local copy that diverged from origin halts), else creating it — a new
# intent branch from HEAD, a new code branch from origin's default branch
# (never from the checked-out intent branch, SF-SKILL-08). An existing
# intent branch behind origin/<default> is caught up with one merge commit
# (never a rebase or --force; a conflict halts naming the branch). The branch is shared by both intent lanes and by re-dispatches of the
# same issue. Without a run context this is a no-op (interactive sessions never
# switch branches). Prints the branch name on stdout.
set -euo pipefail

die() { echo "run-branch: $*" >&2; exit 2; }

# origin's default branch name, as origin reports it (empty when it does not,
# e.g. origin is unreachable — never an error under pipefail).
origin_default() {
  { git ls-remote --symref origin HEAD 2>/dev/null || true; } | sed -n 's#^ref: refs/heads/\(.*\)[[:space:]]HEAD$#\1#p'
}

usage() {
  echo 'usage: run-branch.sh [--kind <intent|code>]' >&2
  exit 2
}

kind="intent"
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) [ $# -ge 2 ] || usage; kind="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$kind" in
  intent|code) ;;
  *) die "unsupported --kind: $kind (expected 'intent' or 'code')" ;;
esac

# Raw lane runs (reviews, autonomous missions) carry the run id only in
# WORKFLOW_INPUTS; adopt it before deciding there is no run context.
if [ -z "${ADLC_RUN_ID:-}" ]; then . "$(dirname "$0")/run-context.sh"; fi
if [ -z "${ADLC_RUN_ID:-}" ]; then
  echo "run-branch: no run context (ADLC_RUN_ID unset, no run_id in WORKFLOW_INPUTS) — skipped" >&2
  exit 0
fi
[[ "$ADLC_RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid ADLC_RUN_ID"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git work tree"
cd "$root"

if [ -n "${ADLC_ISSUE_REF:-}" ]; then
  # Never build a ref from anything but a plain <path>#<number>
  # (same rule as open-mr.sh).
  case "$ADLC_ISSUE_REF" in *..*) die "invalid ADLC_ISSUE_REF";; esac
  [[ "$ADLC_ISSUE_REF" =~ ^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+([A-Za-z0-9_][A-Za-z0-9._-]*))#([0-9]+)$ ]] || die "invalid ADLC_ISSUE_REF"
  if [ "$kind" = "code" ]; then
    branch="factory/mission/${BASH_REMATCH[3]}-${BASH_REMATCH[4]}"
  else
    branch="factory/intent/${BASH_REMATCH[3]}-${BASH_REMATCH[4]}"
  fi
else
  if [ "$kind" = "code" ]; then
    branch="factory/mission/run-${ADLC_RUN_ID}"
  else
    branch="factory/intent/run-${ADLC_RUN_ID}"
  fi
fi
git check-ref-format "refs/heads/$branch" || die "invalid branch name: $branch"

on_origin=0
if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  git fetch -q origin "+refs/heads/$branch:refs/remotes/origin/$branch"
  on_origin=1
fi

existed="$on_origin"
if git show-ref --verify --quiet "refs/heads/$branch"; then
  existed=1
  if [ "$on_origin" = 1 ]; then
    local_ref="refs/heads/$branch" remote_ref="refs/remotes/origin/$branch"
    git merge-base --is-ancestor "$local_ref" "$remote_ref" \
      || git merge-base --is-ancestor "$remote_ref" "$local_ref" \
      || die "local $branch and origin have diverged — resolve by hand"
  fi
  git switch -q "$branch"
  # Continue from origin: fast-forward when origin is ahead (no-op otherwise).
  [ "$on_origin" = 0 ] || git merge -q --ff-only "origin/$branch"
elif [ "$on_origin" = 1 ]; then
  # No --track: a single-branch clone (the runner's `git clone --branch main
  # --single-branch`) has no fetch refspec covering the run branch, and git
  # refuses to track a ref outside it. Nothing needs the upstream: open-mr
  # pushes with an explicit refspec.
  git switch -q -c "$branch" "refs/remotes/origin/$branch"
elif [ "$kind" = code ]; then
  # A new code branch starts from origin's default branch, never from whatever
  # is checked out: after the intent step HEAD is the intent run branch, and
  # its planning drafts (.adlc/drafts/**, docs/adlc/**) rode into every code MR
  # (SF-SKILL-08; octopus-next !1308, !1312, !1315). Those records stay on the
  # intent MR. Files the mission wrote but has not committed are untracked and
  # move along with the switch.
  start=""
  default="$(origin_default)"
  if [ -n "$default" ] && git check-ref-format "refs/heads/$default" \
    && git fetch -q origin "+refs/heads/$default:refs/remotes/origin/$default" 2>/dev/null; then
    start="refs/remotes/origin/$default"
  else
    # origin did not answer: the default branch this clone already knows
    # (the same order open-mr.sh uses for its base).
    for b in "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)" origin/main origin/master; do
      if [ -n "$b" ] && git rev-parse -q --verify "$b^{commit}" >/dev/null; then start="$b"; break; fi
    done
  fi
  if [ -n "$start" ]; then
    git switch -q -c "$branch" "$start"
  else
    echo "run-branch: no origin default branch found — $branch starts from HEAD" >&2
    git switch -q -c "$branch"
  fi
else
  git switch -q -c "$branch"
fi

# An existing intent branch (e.g. created at capture by /adlc open) may be
# behind the default branch: catch it up with one merge commit — never a
# rebase, never --force (merge-commit rule). Code branches are left alone.
if [ "$existed" = 1 ] && [ "$kind" = intent ]; then
  default="$(origin_default)"
  default="${default:-main}"
  git check-ref-format "refs/heads/$default" || die "invalid default branch name: $default"
  git fetch -q origin "+refs/heads/$default:refs/remotes/origin/$default" || die "fetch of origin/$default failed"
  if ! git merge-base --is-ancestor "refs/remotes/origin/$default" HEAD; then
    if ! git merge -q --no-edit "refs/remotes/origin/$default" >/dev/null 2>&1; then
      git merge --abort >/dev/null 2>&1 || true
      die "$branch is behind origin/$default and merging it conflicts — resolve $branch by hand"
    fi
  fi
fi
echo "$branch"
