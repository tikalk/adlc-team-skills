#!/usr/bin/env bash
# scrub-session.sh — Privacy-scrub a session summary
set -euo pipefail

scrub_session() {
  local input="$1"
  # Remove common secret patterns
  echo "$input" | \
    sed -E 's/(api[_-]?key[=: ]+)[^ ]+/\1REDACTED/gi' | \
    sed -E 's/(token[=: ]+)[^ ]+/\1REDACTED/gi' | \
    sed -E 's/(password[=: ]+)[^ ]+/\1REDACTED/gi' | \
    sed -E 's/(secret[=: ]+)[^ ]+/\1REDACTED/gi' | \
    sed -E 's/(AKIA[A-Z0-9]{16})/REDACTED/g' | \
    sed -E 's/(ghp_[A-Za-z0-9]{36})/REDACTED/g' | \
    sed -E 's/(glpat-[A-Za-z0-9_-]{20})/REDACTED/g'
}

if [[ "${1:-}" == "--scrub" ]]; then
  scrub_session "$2"
fi
