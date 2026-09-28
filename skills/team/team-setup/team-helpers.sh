#!/usr/bin/env bash
# Compatibility wrapper — delegates to shared team helpers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/../team-helpers.sh" "$@"
