#!/usr/bin/env bash
# validate-runbook.sh — fail-closed validation of a demo runbook's anchor contract.
#
# Usage: validate-runbook.sh --runbook <path>
#
# Checks (runbook anchor contract):
#   1. runbook is readable
#   2. at least one ### demo/* anchor exists
#   3. anchor names are unique (a duplicated anchor fails with its name)
#   4. every anchor section carries Say (bold **Say:** line) and Do (**Do** ...)
#      — a section missing either fails with its anchor name
#
# Exit 0: "valid: N anchors (...)". Non-zero: "invalid: <anchor>: <reason>".
# Read-only by construction; never writes.
set -euo pipefail

runbook=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runbook) [ $# -ge 2 ] || { echo "usage: validate-runbook.sh --runbook <path>" >&2; exit 2; }; runbook="$2"; shift 2 ;;
    *) echo "usage: validate-runbook.sh --runbook <path>" >&2; exit 2 ;;
  esac
done
[ -n "$runbook" ] || { echo "usage: validate-runbook.sh --runbook <path>" >&2; exit 2; }
[ -r "$runbook" ] || { echo "invalid: runbook unreadable: $runbook" >&2; exit 1; }

mapfile -t hits < <(grep -n -E '^### demo/' "$runbook" | sed -E 's/^([0-9]+):### ([^[:space:]]+)[[:space:]]*$/\1:\2/' || true)
[ "${#hits[@]}" -gt 0 ] || { echo "invalid: no demo/* anchors in $runbook" >&2; exit 2; }

# Uniqueness.
seen=""
for h in "${hits[@]}"; do
  anchor="${h#*:}"
  case "$seen" in
    *"|$anchor|"*) echo "invalid: $anchor: duplicated anchor" >&2; exit 3 ;;
  esac
  seen="$seen|$anchor|"
done

total_lines=$(wc -l < "$runbook")
idx=0
count="${#hits[@]}"
for h in "${hits[@]}"; do
  idx=$((idx + 1))
  anchor="${h#*:}"
  start="${h%%:*}"
  if [ "$idx" -lt "$count" ]; then
    next="${hits[$idx]}"; end=$(( ${next%%:*} - 1 ))
  else
    end="$total_lines"
  fi
  section=$(sed -n "${start},${end}p" "$runbook")
  echo "$section" | grep -q -E '^\*\*Say:\*\*' || { echo "invalid: $anchor: section missing Say line" >&2; exit 4; }
  echo "$section" | grep -q -E '^\*\*Do' || { echo "invalid: $anchor: section missing Do line" >&2; exit 4; }
done

names=$(printf '%s\n' "${hits[@]}" | cut -d: -f2 | paste -sd' ' -)
echo "valid: $count anchors ($names)"
