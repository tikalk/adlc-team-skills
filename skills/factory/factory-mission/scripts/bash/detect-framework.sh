#!/usr/bin/env bash
# detect-framework.sh — resolve the active mission-* lane (M11 E6; lane grammar per the governing SDD-wrapper decision).
#
# Precedence: 1. `framework:` override in the run's mission.yml (unknown value
# fails closed, exit 2). 2. Repo usage evidence — framework-native artifact
# fingerprints dated by `git log` per fingerprint (never mtimes: fresh
# --single-branch clones reset them); multi-match → latest wins, conflict
# logged to stderr. 3. Installed packs in .agents/skills/. 4. Embedded default
# (strictly the zero-evidence fallback). Detection only observes — never
# installs, never mutates the repo.
#
# Usage: detect-framework.sh [--mission <mission.yml>] [repo_root]
# Prints `<lane> <evidence>` on stdout; conflict detail goes to stderr as
# `conflict:` lines. evidence is `override | usage:<fp> | installed:<pack> |
# default`. Exit 0 on resolve, 2 on unknown framework, 1 on usage error.
set -euo pipefail

die() { echo "detect-framework: $*" >&2; exit "${2:-1}"; }

MISSION=""
ROOT_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --mission) [ $# -ge 2 ] || die "usage: detect-framework.sh [--mission <file>] [repo_root]" 1; MISSION="$2"; shift 2;;
    --help|-h) echo "usage: detect-framework.sh [--mission <file>] [repo_root]"; exit 0;;
    --*) die "usage: detect-framework.sh [--mission <file>] [repo_root]" 1;;
    *) [ -z "$ROOT_ARG" ] || die "usage: detect-framework.sh [--mission <file>] [repo_root]" 1; ROOT_ARG="$1"; shift;;
  esac
done

LANES="speckit superpowers addy matt embedded"

in_lanes() {
  case " $LANES " in *" $1 "*) return 0;; *) return 1;; esac
}

if [ -n "$MISSION" ]; then
  [ -f "$MISSION" ] || die "mission file not found: $MISSION" 1
  FW="$(sed -n -E 's/^[[:space:]]*framework:[[:space:]]*["'"'"']?([A-Za-z0-9._-]+)["'"'"']?[[:space:]]*(#.*)?$/\1/p' "$MISSION" | tail -n 1)"
  if [ -n "$FW" ]; then
    in_lanes "$FW" || { echo "detect-framework: unknown framework: $FW" >&2; exit 2; }
    echo "$FW override"
    exit 0
  fi
fi

ROOT="${ROOT_ARG:-$(git rev-parse --show-toplevel 2>/dev/null)}" || die "not inside a git work tree" 1
cd "$ROOT"

# ── usage evidence: fingerprint paths per lane ─────────────────────────────
# Each lane matches when ALL its pathspecs exist in HEAD, dated by the latest
# commit touching any of them. `git ls-tree --name-only` lists each matched
# pathspec once (trees and blobs alike), so count lines >= number of pathspecs.

lane_specs() {
  case "$1" in
    speckit) echo "specs .specify 2";;
    superpowers) echo "docs/superpowers/plans 1";;
    addy) echo "CONSTRAINTS.md references 2";;
  esac
}

latest_commit_date_for() {
  git log -1 --format='%cI' -- "$@" 2>/dev/null || true
}

declare -A HIT_DATE=()
declare -A HIT_FP=()

for lane in speckit superpowers addy; do
  # shellcheck disable=SC2086
  set -- $(lane_specs "$lane")
  need="${@: -1}"
  paths="${*:1:$#-1}"
  # shellcheck disable=SC2086
  n="$(git ls-tree HEAD --name-only -- $paths 2>/dev/null | wc -l)"
  if [ "$n" -ge "$need" ]; then
    # shellcheck disable=SC2086
    d="$(latest_commit_date_for $paths)"
    if [ -n "$d" ]; then HIT_DATE["$lane"]="$d"; HIT_FP["$lane"]="$paths"; fi
  fi
done

# matt: spec issues via /to-spec — a docs .md mentioning /to-spec (git-dated)
MATT_FILE="$(git grep -l --cached -e '/to-spec' -- 'docs/*.md' 2>/dev/null | head -n 1 || true)"
if [ -n "$MATT_FILE" ]; then
  d="$(latest_commit_date_for "$MATT_FILE")"
  if [ -n "$d" ]; then
    HIT_DATE["matt"]="$d"
    HIT_FP["matt"]="$MATT_FILE"
  fi
fi

BEST="" BEST_DATE=""
for lane in speckit superpowers addy matt; do
  if [ -n "${HIT_DATE[$lane]:-}" ]; then
    if [ -z "$BEST" ] || [[ "${HIT_DATE[$lane]}" > "$BEST_DATE" ]]; then
      BEST="$lane"; BEST_DATE="${HIT_DATE[$lane]}"
    fi
  fi
done

if [ -n "$BEST" ]; then
  for lane in speckit superpowers addy matt; do
    if [ "$lane" != "$BEST" ] && [ -n "${HIT_DATE[$lane]:-}" ]; then
      echo "conflict: $lane evidence (${HIT_FP[$lane]}) at ${HIT_DATE[$lane]} superseded by $BEST at $BEST_DATE" >&2
    fi
  done
  echo "$BEST usage:${HIT_FP[$BEST]}"
  exit 0
fi

# ── installed packs (distinctive skill names under .agents/skills/) ─────────
PACK_LANE() {
  case "$1" in
    *spec-kit*|*speckit*) echo "speckit";;
    *superpowers*) echo "superpowers";;
    *addy*|*agent-skills*) echo "addy";;
    *matt*|*pocock*) echo "matt";;
    *) echo "";;
  esac
}

if [ -d ".agents/skills" ]; then
  NEWEST_PACK="" NEWEST_DATE=""
  while IFS= read -r pack; do
    lane="$(PACK_LANE "$pack")"
    [ -n "$lane" ] || continue
    d="$(latest_commit_date_for ".agents/skills/$pack")"
    [ -n "$d" ] || continue
    if [ -z "$NEWEST_PACK" ] || [[ "$d" > "$NEWEST_DATE" ]]; then
      NEWEST_PACK="$pack"; NEWEST_DATE="$d"; NEWEST_LANE="$lane"
    fi
  done < <(git ls-tree HEAD --name-only -- .agents/skills/ 2>/dev/null | sed 's#^\.agents/skills/##' || ls .agents/skills/ 2>/dev/null)
  if [ -n "${NEWEST_PACK:-}" ]; then
    echo "$NEWEST_LANE installed:$NEWEST_PACK"
    exit 0
  fi
fi

echo "embedded default"
