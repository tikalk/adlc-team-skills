#!/usr/bin/env bash
# run-helpers.sh — run factory-runbook helpers in order, for the shell steps of
# the factory workflow (../../workflow.yml).
#
# Usage: run-helpers.sh <label> <helper.sh> [<helper.sh> ...]
#
# Each helper is resolved next to this script. A helper that is missing FAILS
# the step (exit 1, reason on stderr): a skipped helper used to leave the step
# "completed", so a factory run could push nothing, open no MR and still
# report success. A helper's own non-zero exit is the step's exit code (e.g.
# open-mr refusing a non-intent branch). Helpers inherit the environment, so
# they see the run context (ADLC_RUN_ID, ADLC_ISSUE_REF, ADLC_STEP_OUTPUT).
set -euo pipefail

[ $# -ge 2 ] || { echo 'usage: run-helpers.sh <label> <helper.sh> [...]' >&2; exit 2; }
label="$1"
shift
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for name in "$@"; do
  case "$name" in
    */* | .* | "") echo "$label: invalid helper name '$name'" >&2; exit 2 ;;
  esac
  helper="$here/$name"
  if [ ! -f "$helper" ]; then
    echo "$label: $name not found in $here (factory-runbook skill incomplete)" >&2
    exit 1
  fi
  status=0
  bash "$helper" || status=$?
  if [ "$status" -ne 0 ]; then
    exit "$status"
  fi
done
