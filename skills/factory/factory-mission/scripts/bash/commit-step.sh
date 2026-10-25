#!/usr/bin/env bash
# commit-step.sh — one commit per lifecycle step (ADR-431 §2, ADR-431-amendment
# §1a–2, adlc-workspace#26).
#
# Usage: commit-step.sh [--commit] --orchestrator <name> --step <id>
#          --output-type draft|decision|artifact-ref|findings
#          --summary <one line> [--records ADR-1,PDR-2] -- <path>...
#
# Acts only with a factory run context (ADLC_RUN_ID), `adlc.commit_steps: true`
# in .adlc/init-options.json, or --commit (ADR-431 §6); otherwise prints
# `sha: none` and changes nothing. Stages ONLY the given paths, and only when
# they are inside the ADR-433 lifecycle write allowlist; run state
# (.adlc/workflows/**, ADR-393) is never staged. Deletions inside the
# allowlist (a promoted draft's old path) are committed with the step. Requires an explicit committer
# identity (ADR-339). Prints `sha: <sha>`, or `sha: none` when nothing changed.
set -euo pipefail

die() { echo "commit-step: $*" >&2; exit 2; }

orchestrator="" step="" output_type="" summary="" records="" force=0
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --orchestrator) orchestrator="${2-}"; shift 2 ;;
    --step) step="${2-}"; shift 2 ;;
    --output-type) output_type="${2-}"; shift 2 ;;
    --summary) summary="${2-}"; shift 2 ;;
    --records) records="${2-}"; shift 2 ;;
    --commit) force=1; shift ;;
    --) shift; paths=("$@"); break ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$orchestrator" =~ ^[a-z][a-z0-9-]*$ ]] || die "invalid --orchestrator"
[[ "$step" =~ ^[a-z][a-z0-9-]*$ ]] || die "invalid --step"
case "$output_type" in draft|decision|artifact-ref|findings) ;; *) die "invalid --output-type: $output_type" ;; esac
[[ "$records" =~ ^[A-Za-z0-9._,-]*$ ]] || die "invalid --records"
# One line, no trailer smuggling: newlines become spaces, length is capped.
summary="$(printf '%s' "$summary" | tr '\r\n\t' '   ' | tr -s ' ')"
summary="${summary# }"; summary="${summary% }"; summary="${summary:0:100}"
[ -n "$summary" ] || die "missing --summary"
[ "${#paths[@]}" -gt 0 ] || die "no paths given"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git work tree"
prefix="$(git rev-parse --show-prefix)"
cd "$root"

active=0
if [ -n "${ADLC_RUN_ID:-}" ] || [ "$force" = 1 ]; then
  active=1
elif [ -f .adlc/init-options.json ] && grep -Eq '"commit_steps"[[:space:]]*:[[:space:]]*true' .adlc/init-options.json; then
  active=1
fi
if [ "$active" != 1 ]; then
  echo "commit-step: commits disabled (no run context or opt-in)" >&2
  echo "sha: none"
  exit 0
fi

rel=()
for p in "${paths[@]}"; do
  case "$p" in
    /*|*\\*) die "path $p is outside the repository (outside the allowlist)" ;;
  esac
  p="${prefix}${p}"
  case "/$p/" in */../*|*/./*) die "path $p is outside the repository (outside the allowlist)" ;; esac
  case "$p" in
    .adlc/workflows/*) die "refusing run state $p (outside the allowlist; run state stays on refs/factory-runs)" ;;
    .adlc/drafts/pdr/*|.adlc/drafts/adr/*|docs/adlc/memory/pdr/*|docs/adlc/memory/adr/*) ;;
    docs/adlc/product/PRD.md|docs/adlc/architect/AD.md|docs/adlc/architect/views/*) ;;
    .adlc/product/sections/*|.adlc/product/state.json) ;;
    *) die "path $p is outside the ADR-433 lifecycle write allowlist" ;;
  esac
  rel+=("$p")
done

# Deletions inside the allowlist belong to the step too: a promotion moves a
# draft into memory, and the agent passes the new path only. Without this the
# old draft stays an uncommitted deletion and the engine's gate refuses it.
allow=(.adlc/drafts/pdr .adlc/drafts/adr docs/adlc/memory/pdr docs/adlc/memory/adr
  docs/adlc/product/PRD.md docs/adlc/architect/AD.md docs/adlc/architect/views
  .adlc/product/sections .adlc/product/state.json)
while IFS= read -r -d '' d; do
  rel+=("$d")
done < <(git ls-files -z --deleted -- "${allow[@]}"; git diff --cached -z --name-only --diff-filter=D -- "${allow[@]}")

name="${GIT_COMMITTER_NAME:-$(git config user.name || true)}"
email="${GIT_COMMITTER_EMAIL:-$(git config user.email || true)}"
[ -n "$name" ] && [ -n "$email" ] || die "no committer identity (set user.name/user.email, ADR-339)"

git add -A -- "${rel[@]}"
if git diff --cached --quiet -- "${rel[@]}"; then
  echo "sha: none"
  exit 0
fi

msg="$(mktemp)"
trap 'rm -f "$msg"' EXIT
{
  printf 'docs(adlc): %s %s — %s\n\n' "$orchestrator" "$step" "$summary"
  printf 'Run-Id: %s\n' "${ADLC_RUN_ID:-interactive}"
  printf 'Step: %s\n' "$step"
  printf 'Output-Type: %s\n' "$output_type"
  [ -z "$records" ] || printf 'Records: %s\n' "$records"
} >"$msg"
# --only: commit exactly these paths, whatever else is staged.
git commit -q --only -F "$msg" -- "${rel[@]}"
echo "sha: $(git rev-parse HEAD)"
