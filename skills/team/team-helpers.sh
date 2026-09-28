#!/usr/bin/env bash
# team-helpers.sh — Compatibility shim. Prefer team-paths / team-scaffold / team-validate.
# Publishing lives in skills/workspace/workspace-publish/scripts/ — not here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=team-paths.sh
source "${SCRIPT_DIR}/team-paths.sh"
# shellcheck source=team-validate.sh
source "${SCRIPT_DIR}/team-validate.sh"
# shellcheck source=team-scaffold.sh
source "${SCRIPT_DIR}/team-scaffold.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Route CLI: path resolution by default; scaffold flags go to team-scaffold
  for arg in "$@"; do
    case "$arg" in
      --scaffold|--agents-only|--inject-agents|--name)
        exec bash "${SCRIPT_DIR}/team-scaffold.sh" "$@"
        ;;
    esac
  done
  exec bash "${SCRIPT_DIR}/team-paths.sh" "$@"
fi
