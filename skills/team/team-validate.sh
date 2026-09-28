#!/usr/bin/env bash
# team-validate.sh — Structure checks for team AI directives.
# Safe to source.
set -euo pipefail

validate_team_ai_directives() {
  local dir="$1"
  local missing=0

  for required in \
    "context_modules/constitution.md" \
    "context_modules/rules" \
    "context_modules/personas" \
    "context_modules/examples" \
    "CDR.md" \
    ".skills.json"; do
    if [[ ! -e "${dir}/${required}" ]]; then
      echo "MISSING: ${required}"
      missing=$((missing + 1))
    fi
  done

  return "$missing"
}


_team_validate_main() {
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then
    echo "Usage: team-validate.sh <team-ai-directives-dir>" >&2
    exit 1
  fi
  validate_team_ai_directives "$dir"
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "OK: team AI directives structure valid at $dir"
  else
    echo "INVALID: $rc required path(s) missing under $dir" >&2
  fi
  exit "$rc"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _team_validate_main "$@"
fi
