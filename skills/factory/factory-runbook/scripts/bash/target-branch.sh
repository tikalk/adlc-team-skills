#!/usr/bin/env bash
# target-branch.sh — resolve the run's target branch in one place (SF-FIX-23).
#
# Why: a factory mission normally cuts its work branch from origin's default
# branch and opens its merge request into it. To test the factory end to end
# without touching the default branch, the Argo lane can dispatch a mission
# against another branch: an issue labelled `target-branch::<branch>` makes the
# runner pod clone that branch and sets
#   ADLC_TARGET_BRANCH=<branch>           (every mission pod; empty = none)
#   WORKFLOW_INPUTS.target_branch=<branch> (only when a branch was accepted)
# run-branch and open-mr read the answer from here, so "which branch does this
# run work against" has one definition.
#
# Sources, first hit wins:
#   1. ADLC_TARGET_BRANCH   2. WORKFLOW_INPUTS.target_branch
# Neither set (or both empty) = no target: the helpers use the default branch,
# exactly as before this script existed.
#
# A target that IS set must be a plain branch name:
#   ^[A-Za-z0-9][A-Za-z0-9._/-]{0,200}$, no "..", not ending in "/" or ".lock",
#   and accepted by `git check-ref-format`.
# Anything else is an ERROR, never "no target": a run that was dispatched
# against a branch must not quietly fall back to the default branch. The same
# holds when the two sources name different branches, and when
# WORKFLOW_INPUTS carries a target that cannot be read (no node, not a string,
# or not valid JSON while its text names "target_branch").
# Whether the branch exists on origin is checked by the helper that uses it.
#
# Usage:
#   . target-branch.sh      # sourced (the helpers do this): exports
#                           # ADLC_TARGET_BRANCH when a target resolved, and
#                           # sets the shell variable ADLC_TARGET_BRANCH_ERROR
#                           # (not exported; empty when all is well). The
#                           # sourcing script must stop on a non-empty error.
#   bash target-branch.sh   # prints two key=value lines:
#                           #   target_branch=<branch|>   source=<env|lane|none>
# Exit (when executed): 0 with or without a target; 2 on an invalid target or a
# usage error, with the reason on stderr.
# PowerShell twin: ../powershell/target-branch.ps1.

# "<state> <value>" for WORKFLOW_INPUTS.target_branch:
#   none          absent, or WORKFLOW_INPUTS is unset / not a JSON object
#                 (unparseable text that does not name the key is "none" too)
#   corrupt       WORKFLOW_INPUTS is not valid JSON and the text names the key
#   str <value>   a string (may be empty)
#   bad           present but not a string
#   nonode        cannot tell: node is missing and the text names the key
_adlc_tb_lane() {
  if [ -z "${WORKFLOW_INPUTS:-}" ]; then echo none; return 0; fi
  if ! command -v node >/dev/null 2>&1; then
    case "$WORKFLOW_INPUTS" in *'"target_branch"'*) echo nonode ;; *) echo none ;; esac
    return 0
  fi
  node -e '
    let o;
    try { o = JSON.parse(process.env.WORKFLOW_INPUTS); } catch (e) {
      if (process.env.WORKFLOW_INPUTS.includes("\"target_branch\"")) { process.stdout.write("corrupt"); process.exit(0); }
      o = null;
    }
    if (!o || typeof o !== "object" || Array.isArray(o) || !Object.prototype.hasOwnProperty.call(o, "target_branch")) {
      process.stdout.write("none");
    } else if (typeof o.target_branch === "string") {
      process.stdout.write("str " + o.target_branch);
    } else {
      process.stdout.write("bad");
    }
  ' 2>/dev/null || echo nonode
}

# Sets _adlc_tb_branch, _adlc_tb_source (env | lane | none) and _adlc_tb_error.
_adlc_tb_resolve() {
  local plain='^[A-Za-z0-9][A-Za-z0-9._/-]{0,200}$'
  local lane lane_branch="" nl='
'
  _adlc_tb_branch="" _adlc_tb_source="none" _adlc_tb_error=""
  lane="$(_adlc_tb_lane)"
  case "$lane" in
    none) ;;
    "str "*) lane_branch="${lane#str }" ;;
    corrupt) _adlc_tb_error="WORKFLOW_INPUTS names target_branch but is not valid JSON — refusing to fall back to the default branch"; return 0 ;;
    bad) _adlc_tb_error="WORKFLOW_INPUTS.target_branch is not a string — refusing to fall back to the default branch"; return 0 ;;
    *) _adlc_tb_error="cannot read WORKFLOW_INPUTS.target_branch (node is needed) — refusing to fall back to the default branch"; return 0 ;;
  esac
  if [ -n "${ADLC_TARGET_BRANCH:-}" ]; then
    _adlc_tb_branch="$ADLC_TARGET_BRANCH"; _adlc_tb_source="env"
    if [ -n "$lane_branch" ] && [ "$lane_branch" != "$ADLC_TARGET_BRANCH" ]; then
      _adlc_tb_branch=""
      _adlc_tb_error="ADLC_TARGET_BRANCH and WORKFLOW_INPUTS.target_branch name different branches — refusing to guess"
      return 0
    fi
  elif [ -n "$lane_branch" ]; then
    _adlc_tb_branch="$lane_branch"; _adlc_tb_source="lane"
  else
    return 0
  fi
  # A set target is validated; a bad one is an error, not "no target".
  local b="$_adlc_tb_branch" ok=1
  case "$b" in *"$nl"*|*..*|*/|*.lock) ok=0 ;; esac
  [[ "$b" =~ $plain ]] || ok=0
  if [ "$ok" = 1 ] && ! git check-ref-format "refs/heads/$b" >/dev/null 2>&1; then ok=0; fi
  if [ "$ok" != 1 ]; then
    _adlc_tb_branch=""
    _adlc_tb_error="invalid target branch (from ${_adlc_tb_source}): not a plain branch name — refusing to fall back to the default branch"
  fi
}

_adlc_tb_resolve

if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  # Sourced: hand the answer to the sourcing script, leave everything else alone.
  ADLC_TARGET_BRANCH_ERROR="$_adlc_tb_error"
  if [ -n "$_adlc_tb_branch" ]; then export ADLC_TARGET_BRANCH="$_adlc_tb_branch"; fi
  unset -f _adlc_tb_lane _adlc_tb_resolve
  unset _adlc_tb_branch _adlc_tb_source _adlc_tb_error
  return 0
fi

if [ "$#" -gt 0 ]; then
  echo "usage: target-branch.sh   (or source it: . target-branch.sh)" >&2
  exit 2
fi
if [ -n "$_adlc_tb_error" ]; then
  echo "target-branch: $_adlc_tb_error" >&2
  exit 2
fi
echo "target_branch=$_adlc_tb_branch"
echo "source=$_adlc_tb_source"
exit 0
