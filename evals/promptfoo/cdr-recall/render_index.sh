#!/usr/bin/env bash
# Render the CDR index exactly as team-boot ships it (the "shipped" shape of
# the recall eval). Runs the real boot.sh against fixture/directives — a
# snapshot of tikal-team-ai-directives' CDR.md — in a throwaway project whose
# AGENTS.md carries the lean-v1 sentinel, then prints only the "## CDR Index"
# block. A change to boot.sh's index shape is therefore measured by the eval
# instead of a hand-maintained snapshot.
#
# Usage: render_index.sh [directives-dir]   (default: fixture/directives)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
directives="$(cd "${1:-$here/fixture/directives}" && pwd)"
project="$(mktemp -d)"
trap 'rm -rf "$project"' EXIT

mkdir -p "$project/.adlc"
printf '{"team_ai_directives": "%s"}\n' "$directives" > "$project/.adlc/init-options.json"
cat > "$project/AGENTS.md" <<'EOF'
<!-- TEAM_AI_DIRECTIVES START -->
<!-- team-boot-contract: lean-v1 -->
# Team AI Directives
### Proportionality Gate
### Trust Model
<!-- TEAM_AI_DIRECTIVES END -->
EOF

out="$(cd "$project" && env -u ADLC_EVENT bash "$root/skills/team/team-boot/scripts/bash/boot.sh")"
block="$(printf '%s\n' "$out" | awk '/^## CDR Index/ { on = 1; print; next } on && /^#/ { exit } on { print }')"
if [ -z "$block" ] || ! printf '%s\n' "$block" | grep -q 'CDRs available'; then
  echo "render_index.sh: boot.sh emitted no CDR index" >&2
  exit 1
fi
printf '%s\n' "$block"
