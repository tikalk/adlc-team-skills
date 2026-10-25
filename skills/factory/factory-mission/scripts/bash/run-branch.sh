#!/usr/bin/env bash
# run-branch.sh — check out the intent run branch in the project root
# (ADR-431-amendment §1, adlc-workspace#26).
#
# With a factory run context (ADLC_RUN_ID, ADR-444): check out
#   factory/intent/<repo>-<iid>   from ADLC_ISSUE_REF (<group>/<repo>#<iid>), or
#   factory/intent/run-<run_id>   without an issue,
# continuing from origin when it has the branch (a local copy is fast-forwarded;
# a local copy that diverged from origin halts), else creating it. The branch is shared by both intent lanes and by re-dispatches of the
# same issue. Without ADLC_RUN_ID this is a no-op (interactive sessions never
# switch branches). Prints the branch name on stdout.
set -euo pipefail

die() { echo "run-branch: $*" >&2; exit 2; }

if [ -z "${ADLC_RUN_ID:-}" ]; then
  echo "run-branch: no run context (ADLC_RUN_ID unset) — skipped" >&2
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
  branch="factory/intent/${BASH_REMATCH[3]}-${BASH_REMATCH[4]}"
else
  branch="factory/intent/run-${ADLC_RUN_ID}"
fi
git check-ref-format "refs/heads/$branch" || die "invalid branch name: $branch"

on_origin=0
if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  git fetch -q origin "+refs/heads/$branch:refs/remotes/origin/$branch"
  on_origin=1
fi

if git show-ref --verify --quiet "refs/heads/$branch"; then
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
else
  git switch -q -c "$branch"
fi
echo "$branch"
