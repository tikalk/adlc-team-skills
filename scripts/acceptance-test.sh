#!/usr/bin/env bash
# Canonical acceptance test for adlc-team-skills.
#
# Tier 1 (default, deterministic — no LLM): scratch-install this repo via
#   adlc-cli, configure a team-ai-directives checkout, and assert
#   team-boot's session_start script emits the full directives index.
# Tier 2 (--live): plus a live agent smoke check (opencode) verifying the
#   injected team context appears in a real session.
#
# Usage:
#   scripts/acceptance-test.sh [--directives <path>] [--live] [--keep]
#
# Directives resolution order: --directives flag > $TEAM_AI_DIRECTIVES_DIR >
#   this repo's .adlc/init-options.json > shallow clone of the public
#   tikalk/agentic-sdlc-team-ai-directives.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIRECTIVES=""
LIVE=0
KEEP=0
SCRATCH=""
FALLBACK_CLONE=""

log()  { printf '  [accept] %s\n' "$*"; }
fail() { printf '  [accept] FAIL: %s\n' "$*" >&2; exit 1; }

cleanup() {
  if [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] && [ "$KEEP" -eq 0 ]; then
    rm -rf "$SCRATCH"
  elif [ -n "$SCRATCH" ] && [ "$KEEP" -eq 1 ]; then
    log "scratch kept at: $SCRATCH"
  fi
  if [ -n "$FALLBACK_CLONE" ] && [ -d "$FALLBACK_CLONE" ]; then
    rm -rf "$(dirname "$FALLBACK_CLONE")"
  fi
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --directives) [ $# -ge 2 ] || fail "--directives requires a path"; DIRECTIVES="$2"; shift 2 ;;
    --live)       LIVE=1; shift ;;
    --keep)       KEEP=1; shift ;;
    -h|--help)    sed -n '2,15p' "$0"; exit 0 ;;
    *)            fail "unknown flag: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || fail "jq is required (team-boot's skills section uses it)"
command -v git >/dev/null 2>&1 || fail "git is required"

# --- Resolve the team-ai-directives checkout ---------------------------------
resolve_directives() {
  if [ -n "$DIRECTIVES" ]; then
    [ -d "$DIRECTIVES" ] || fail "--directives path not found: $DIRECTIVES"
    echo "$DIRECTIVES"; return
  fi
  if [ -n "${TEAM_AI_DIRECTIVES_DIR:-}" ]; then
    [ -d "$TEAM_AI_DIRECTIVES_DIR" ] || fail "TEAM_AI_DIRECTIVES_DIR not found: $TEAM_AI_DIRECTIVES_DIR"
    echo "$TEAM_AI_DIRECTIVES_DIR"; return
  fi
  if [ -f "$REPO_ROOT/.adlc/init-options.json" ]; then
    local p
    p=$(grep '"team_ai_directives"' "$REPO_ROOT/.adlc/init-options.json" \
        | sed 's/.*"team_ai_directives"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    if [ -n "$p" ] && [ -d "$p" ]; then echo "$p"; return; fi
  fi
  local clone
  clone=$(mktemp -d)/directives
  log "no directives configured — shallow-cloning the public repo"
  git clone --depth 1 --quiet https://github.com/tikalk/agentic-sdlc-team-ai-directives "$clone" \
    || fail "could not clone tikalk/agentic-sdlc-team-ai-directives"
  FALLBACK_CLONE="$clone"
  echo "$clone"
}

DIRECTIVES="$(resolve_directives)"
log "directives: $DIRECTIVES"
[ -f "$DIRECTIVES/CDR.md" ] || [ -d "$DIRECTIVES/context_modules" ] \
  || fail "directives checkout has neither CDR.md nor context_modules/ — not a team-ai-directives repo?"

# --- Scratch install ----------------------------------------------------------
SCRATCH=$(mktemp -d)
log "scratch project: $SCRATCH"
(
  cd "$SCRATCH"
  git init --quiet
  git config user.email "accept@test" && git config user.name "accept"
)

log "installing via adlc-cli (this runs npx — may take a moment)"
(
  cd "$SCRATCH"
  npx -y adlc-cli skill add "$REPO_ROOT" -a opencode -y >/dev/null 2>&1 \
    || fail "adlc-cli install failed"
)

[ -d "$SCRATCH/.agents/skills/team-boot" ] || fail "install did not create .agents/skills/team-boot"
SRC_COUNT=$(find "$REPO_ROOT/skills" -name SKILL.md | wc -l | tr -d ' ')
MIRROR_COUNT=$(find "$SCRATCH/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$SRC_COUNT" = "$MIRROR_COUNT" ] \
  || fail "mirror has $MIRROR_COUNT skills, source has $SRC_COUNT — incomplete install"
log "installed all $SRC_COUNT skills into the scratch mirror"

# --- Configure + run team-boot's session_start script -------------------------
mkdir -p "$SCRATCH/.adlc"
printf '{\n  "team_ai_directives": "%s"\n}\n' "$DIRECTIVES" > "$SCRATCH/.adlc/init-options.json"

BOOT_OUT="$SCRATCH/boot.out"
( cd "$SCRATCH" && bash .agents/skills/team-boot/scripts/boot.sh ) > "$BOOT_OUT" 2>&1 \
  || fail "boot.sh exited non-zero"

assert_contains() {
  # -E for portable extended regex (no GNU/BSD \+ divergence)
  grep -qE "$1" "$BOOT_OUT" || fail "boot output missing: $1"
}

assert_contains "<EXTREMELY_IMPORTANT>"
assert_contains "## Constitution"
assert_contains "^[0-9]+\."           # at least one numbered principle
assert_contains "## CDR Index"
assert_contains "\| CDR-"             # at least one CDR row
assert_contains "_Total: [0-9]+ CDR"
assert_contains "## Class Boots"
assert_contains "architect-boot"
assert_contains "## Available Skills"
assert_contains "</EXTREMELY_IMPORTANT>"
log "boot.sh emits the full directives index (constitution, CDR index, class boots, skills)"

# --- Optional live tier --------------------------------------------------------
if [ "$LIVE" -eq 1 ]; then
  command -v opencode >/dev/null 2>&1 || fail "--live requires opencode on PATH"
  log "live smoke: opencode run (needs auth; watch for the injected context)"
  ( cd "$SCRATCH" && timeout 180 opencode run --print-logs "What team rules do you have?" 2>&1 ) \
    | tee "$SCRATCH/live.log" \
    | grep -i -m1 "Team AI Directives\|team-boot" \
    || fail "live run did not surface the team context — check the event hook wiring (see docs/event-hook-contract.md)"
  log "live session surfaced the team context"
fi

log "PASS — canonical acceptance test green"
