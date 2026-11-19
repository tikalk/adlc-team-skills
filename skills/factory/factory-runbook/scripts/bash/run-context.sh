#!/usr/bin/env bash
# run-context.sh — resolve the factory run context in one place (SF-SKILL-03).
#
# Why: adlc-cli exports ADLC_RUN_ID / ADLC_ISSUE_REF only to the steps of a
# workflow run (supervised missions). Review runs and autonomous missions are
# raw agent runs in the same runner pods: adlc-cli never runs there, so
# ADLC_RUN_ID is unset, every helper used to no-op ("no run context —
# skipped") and agents invented run ids of their own. The Argo lane sets
# WORKFLOW_INPUTS on every runner pod:
#   {"issue_ref": <issue or MR ref>, "run_id": <GitLab event UUID>, "dispatch": ...}
#
# Sources, first hit wins:
#   run id    1. ADLC_RUN_ID      2. WORKFLOW_INPUTS.run_id
#   issue ref 1. ADLC_ISSUE_REF   2. WORKFLOW_INPUTS.issue_ref, only when it is
#             an issue ref (<group>/<project>#<iid>); a review's MR ref
#             (<group>/<project>!<iid>) is not an issue ref
# A run id must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ and must not be the chart's
# placeholder "pending"; anything else counts as "no run id".
#
# Usage:
#   . run-context.sh        # sourced (the helpers do this): exports ADLC_RUN_ID
#                           # and ADLC_ISSUE_REF when resolvable, changes nothing else
#   bash run-context.sh     # prints four key=value lines:
#                           #   factory_run=yes|no  run_id=<id|>
#                           #   issue_ref=<ref|>    source=<adlc|lane|none>
# Exit: 0, also when nothing resolves (absence is an answer, not an error);
# 2 on a usage error. PowerShell twin: ../powershell/run-context.ps1.

# One string field of WORKFLOW_INPUTS, or "" when it is absent, not JSON, or
# not a string.
_adlc_rc_field() {
  [ -n "${WORKFLOW_INPUTS:-}" ] || return 0
  command -v node >/dev/null 2>&1 || return 0
  node -e '
    try {
      const o = JSON.parse(process.env.WORKFLOW_INPUTS);
      const v = o && typeof o === "object" && !Array.isArray(o) ? o[process.argv[1]] : undefined;
      process.stdout.write(typeof v === "string" ? v : "");
    } catch (e) { process.stdout.write(""); }
  ' "$1" 2>/dev/null || true
}

# Sets _adlc_rc_run_id, _adlc_rc_issue_ref, _adlc_rc_source.
_adlc_rc_resolve() {
  local safe='^[A-Za-z0-9][A-Za-z0-9._-]*$'
  local issue='^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#[0-9]+$'
  local cand
  _adlc_rc_run_id="" _adlc_rc_issue_ref="" _adlc_rc_source="none"
  if [ -n "${ADLC_RUN_ID:-}" ] && [[ "$ADLC_RUN_ID" =~ $safe ]]; then
    _adlc_rc_run_id="$ADLC_RUN_ID"; _adlc_rc_source="adlc"
  else
    cand="$(_adlc_rc_field run_id)"
    if [ -n "$cand" ] && [ "$cand" != "pending" ] && [[ "$cand" =~ $safe ]]; then
      _adlc_rc_run_id="$cand"; _adlc_rc_source="lane"
    fi
  fi
  if [ -n "${ADLC_ISSUE_REF:-}" ]; then
    _adlc_rc_issue_ref="$ADLC_ISSUE_REF"
  else
    cand="$(_adlc_rc_field issue_ref)"
    case "$cand" in *..*) cand="" ;; esac
    if [ -n "$cand" ] && [[ "$cand" =~ $issue ]]; then _adlc_rc_issue_ref="$cand"; fi
  fi
}

_adlc_rc_resolve

if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  # Sourced: adopt what resolved, leave everything else alone.
  if [ -n "$_adlc_rc_run_id" ]; then export ADLC_RUN_ID="$_adlc_rc_run_id"; fi
  if [ -n "$_adlc_rc_issue_ref" ]; then export ADLC_ISSUE_REF="$_adlc_rc_issue_ref"; fi
  unset -f _adlc_rc_field _adlc_rc_resolve
  unset _adlc_rc_run_id _adlc_rc_issue_ref _adlc_rc_source
  return 0
fi

if [ "$#" -gt 0 ]; then
  echo "usage: run-context.sh   (or source it: . run-context.sh)" >&2
  exit 2
fi
if [ -n "$_adlc_rc_run_id" ]; then echo "factory_run=yes"; else echo "factory_run=no"; fi
echo "run_id=$_adlc_rc_run_id"
echo "issue_ref=$_adlc_rc_issue_ref"
echo "source=$_adlc_rc_source"
exit 0
