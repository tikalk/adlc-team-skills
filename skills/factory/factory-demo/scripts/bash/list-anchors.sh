#!/usr/bin/env bash
# list-anchors.sh — parse a demo runbook and emit its ### demo/* anchors in file order.
#
# Usage: list-anchors.sh --runbook <path> [--from <anchor>] [--json]
#   --runbook <path>  path to the runbook markdown file (required)
#   --from <anchor>    resume from this anchor (e.g. demo/review); earlier anchors are skipped
#   --json             emit JSON array [{"anchor": "...", "line": N}] instead of plain lines
#
# Exit 0 with the anchor list. Non-zero exit fails CLOSED with the anchor name:
#   1 = runbook unreadable, 2 = no demo/* anchors found, 3 = --from anchor not found.
# Never writes anything; read-only by construction (dry-run safety).
set -euo pipefail

die() { echo "list-anchors: $*" >&2; exit "${2:-2}"; }

runbook=""; from_anchor=""; json_out=0
while [ $# -gt 0 ]; do
  case "$1" in
    --runbook) [ $# -ge 2 ] || { echo "usage: list-anchors.sh --runbook <path> [--from <anchor>] [--json]" >&2; exit 2; }; runbook="$2"; shift 2 ;;
    --from) [ $# -ge 2 ] || { echo "usage: list-anchors.sh --runbook <path> [--from <anchor>] [--json]" >&2; exit 2; }; from_anchor="$2"; shift 2 ;;
    --json) json_out=1; shift ;;
    *) echo "usage: list-anchors.sh --runbook <path> [--from <anchor>] [--json]" >&2; exit 2 ;;
  esac
done

[ -n "$runbook" ] || { echo "usage: list-anchors.sh --runbook <path> [--from <anchor>] [--json]" >&2; exit 2; }
[ -r "$runbook" ] || die "runbook unreadable: $runbook" 1

# Collect "line_number:anchor" for every ### demo/<name> heading, file order.
mapfile -t hits < <(grep -n -E '^### demo/[A-Za-z0-9][A-Za-z0-9_/-]*[[:space:]]*$' "$runbook" | sed -E 's/^([0-9]+):### (demo\/[A-Za-z0-9_/-]+)[[:space:]]*$/\1:\2/' || true)
[ "${#hits[@]}" -gt 0 ] || die "no demo/* anchors in $runbook" 2

# --from slicing: drop everything before the named anchor (fail closed if absent).
if [ -n "$from_anchor" ]; then
  found=0
  kept=()
  for h in "${hits[@]}"; do
    anchor="${h#*:}"
    if [ "$anchor" = "$from_anchor" ]; then found=1; fi
    if [ "$found" -eq 1 ]; then kept+=("$h"); fi
  done
  [ "$found" -eq 1 ] || die "unknown --from anchor: $from_anchor" 3
  hits=("${kept[@]}")
fi

if [ "$json_out" -eq 1 ]; then
  python3 -c 'import json,sys; print(json.dumps([{"anchor": a.split(":",1)[1], "line": int(a.split(":",1)[0])} for a in sys.argv[1:]]))' "${hits[@]}"
else
  for h in "${hits[@]}"; do echo "${h#*:}"; done
fi
