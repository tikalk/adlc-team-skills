#!/usr/bin/env bash
# levelup-helpers.sh — Shared utilities for levelup-* skills
#
# Flags:
#   --json              Output path/state info as JSON
#   --next-cdr          Print next CDR number (e.g., 001)
#   --index             Regenerate .adlc/drafts/cdr/cdr.md index
#   --signal-gate FILE  Validate single CDR file against signal gate
#   --state FILE        Read/write levelup state JSON
#
# When sourced, provides helper functions. When executed directly,
# acts as a CLI for setup scripts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAM_HELPERS="${SCRIPT_DIR}/../team/team-helpers.sh"

# Source team helpers for path resolution
if [[ -f "$TEAM_HELPERS" ]]; then
  # shellcheck source=../team/team-helpers.sh
  source "$TEAM_HELPERS" >/dev/null 2>&1 || true
fi

###############################################################################
# 1. PATH RESOLUTION
###############################################################################

resolve_levelup_paths() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"

  # Resolve team directives via team-helpers if available
  if declare -f resolve_paths >/dev/null; then
    eval "$(resolve_paths 2>/dev/null | grep -E '^(PROJECT_ROOT|TEAM_DIRECTIVES|BRANCH)=')" || true
  else
    TEAM_DIRECTIVES="${ADLC_TEAM_AI_DIRECTIVES:-}"
    if [[ -z "$TEAM_DIRECTIVES" && -f "${PROJECT_ROOT}/.adlc/init-options.json" ]]; then
      TEAM_DIRECTIVES=$(python3 -c "
import json, sys
try:
    with open('${PROJECT_ROOT}/.adlc/init-options.json') as f:
        print(json.load(f).get('team_ai_directives', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    fi
    [[ -z "$TEAM_DIRECTIVES" ]] && TEAM_DIRECTIVES="${PROJECT_ROOT}/.adlc/team-ai-directives"
  fi

  CDR_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/cdr"
  CDR_INDEX_FILE="${CDR_DRAFTS_DIR}/cdr.md"
  SKILLS_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/skills"
  LEVELUP_STATE_FILE="${PROJECT_ROOT}/.adlc/levelup/state.json"

  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "TEAM_DIRECTIVES=$TEAM_DIRECTIVES"
  echo "BRANCH=$BRANCH"
  echo "CDR_DRAFTS_DIR=$CDR_DRAFTS_DIR"
  echo "CDR_INDEX_FILE=$CDR_INDEX_FILE"
  echo "SKILLS_DRAFTS_DIR=$SKILLS_DRAFTS_DIR"
  echo "LEVELUP_STATE_FILE=$LEVELUP_STATE_FILE"
}

output_levelup_json() {
  resolve_levelup_paths >/dev/null
  python3 - << PY
import json, os
print(json.dumps({
  "REPO_ROOT": os.environ.get("PROJECT_ROOT", ""),
  "TEAM_DIRECTIVES": os.environ.get("TEAM_DIRECTIVES", ""),
  "BRANCH": os.environ.get("BRANCH", ""),
  "CDR_DRAFTS_DIR": os.environ.get("CDR_DRAFTS_DIR", ""),
  "CDR_INDEX_FILE": os.environ.get("CDR_INDEX_FILE", ""),
  "SKILLS_DRAFTS_DIR": os.environ.get("SKILLS_DRAFTS_DIR", ""),
  "LEVELUP_STATE_FILE": os.environ.get("LEVELUP_STATE_FILE", "")
}))
PY
}

###############################################################################
# 2. CDR NUMBERING
###############################################################################

next_cdr_number() {
  local dir="${1:-${CDR_DRAFTS_DIR:-}}"
  if [[ -z "$dir" ]]; then
    resolve_levelup_paths >/dev/null
    dir="$CDR_DRAFTS_DIR"
  fi

  mkdir -p "$dir"
  local max=0
  if [[ -d "$dir" ]]; then
    for f in "$dir"/CDR-*.md; do
      [[ -f "$f" ]] || continue
      local num
      num=$(basename "$f" | sed -E 's/CDR-([0-9]+).*/\1/')
      [[ "$num" =~ ^[0-9]+$ ]] || continue
      ((10#$num > max)) && max=$((10#$num))
    done
  fi
  printf '%03d' $((max + 1))
}

###############################################################################
# 3. CDR INDEX GENERATION
###############################################################################

regenerate_cdr_index() {
  local dir="${1:-${CDR_DRAFTS_DIR:-}}"
  local index_file="${2:-${CDR_INDEX_FILE:-}}"
  if [[ -z "$dir" || -z "$index_file" ]]; then
    resolve_levelup_paths >/dev/null
    dir="$CDR_DRAFTS_DIR"
    index_file="$CDR_INDEX_FILE"
  fi

  mkdir -p "$dir"

  local today
  today=$(date +%Y-%m-%d)

  {
    echo "# Context Directive Records"
    echo ""
    echo "Context Directive Records (CDRs) track proposed and accepted contributions to team-ai-directives."
    echo ""
    echo "## CDR Index"
    echo ""
    echo "| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |"
    echo "|----|---------------|------|--------|---------|----------|-----|------------|"

    if [[ -d "$dir" ]]; then
      for f in $(ls -1 "$dir"/CDR-*.md 2>/dev/null | sort); do
        [[ -f "$f" ]] || continue
        local id target type status created verified age descriptor
        id=$(basename "$f" .md)
        target=$(grep -m1 '^### Target Module' "$f" 2>/dev/null | sed 's/.*`\([^`]*\)`.*/\1/' | head -c 40)
        type=$(grep -m1 '^### Context Type' "$f" 2>/dev/null | sed 's/^### Context Type[[:space:]]*//' | head -c 20)
        status=$(grep -m1 '^### Status' "$f" 2>/dev/null | sed 's/^### Status[[:space:]]*//' | sed 's/\*\*//g' | head -c 12)
        created=$(grep -m1 '^### Date' "$f" 2>/dev/null | sed 's/^### Date[[:space:]]*//' | head -c 10)
        verified=$(grep -m1 '^verified:' "$f" 2>/dev/null | sed 's/verified:[[:space:]]*//' | head -c 10)
        age=$(grep -m1 '^age_days:' "$f" 2>/dev/null | sed 's/age_days:[[:space:]]*//' | head -c 5)
        descriptor=$(grep -m1 '^### Descriptor' "$f" 2>/dev/null | sed 's/^### Descriptor[[:space:]]*//' | head -c 60)

        [[ -z "$created" ]] && created="$today"
        [[ -z "$verified" ]] && verified="-"
        [[ -z "$age" ]] && age="-"

        printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' \
          "$id" "${target:- }" "${type:- }" "${status:-Discovered}" "${created}" "${verified}" "${age}" "${descriptor:- }"
      done
    fi

    echo ""
    echo "**Stats**: $(ls -1 "$dir"/CDR-*.md 2>/dev/null | wc -l | tr -d ' ') entries | Last Updated: $today"
  } > "$index_file"

  echo "$index_file"
}

###############################################################################
# 4. SIGNAL GATE VALIDATION
###############################################################################

signal_gate() {
  local file="$1"
  local strict="${2:-true}"
  local reasons=()

  # Team-wide: must not be project-specific
  if grep -qi 'project-specific\|only applies to this project\|single project' "$file" 2>/dev/null; then
    reasons+=("project-specific")
  fi

  # Unique: must not duplicate existing directives
  if grep -qi 'duplicate of\|overlaps with existing\|already in team-ai-directives' "$file" 2>/dev/null; then
    reasons+=("duplicate")
  fi

  # Evidence: must reference commits/files
  if ! grep -Eq '(src/|lib/|test/|docs/|commit|file)' "$file" 2>/dev/null; then
    reasons+=("no evidence")
  fi

  # High value: heuristic — require explicit low-value marker to skip
  if grep -qi 'low value\|nice-to-have\|minor convenience' "$file" 2>/dev/null; then
    reasons+=("low value")
  fi

  if [[ ${#reasons[@]} -gt 0 ]]; then
    echo "SKIP: ${reasons[*]}"
    return 1
  fi

  echo "PASS"
  return 0
}

###############################################################################
# 5. STATE MANAGEMENT
###############################################################################

read_levelup_state() {
  local file="${1:-${LEVELUP_STATE_FILE:-}}"
  if [[ -z "$file" ]]; then
    resolve_levelup_paths >/dev/null
    file="$LEVELUP_STATE_FILE"
  fi
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo '{}'
  fi
}

write_levelup_state() {
  local file="${1:-${LEVELUP_STATE_FILE:-}}"
  local json="$2"
  if [[ -z "$file" ]]; then
    resolve_levelup_paths >/dev/null
    file="$LEVELUP_STATE_FILE"
  fi
  mkdir -p "$(dirname "$file")"
  echo "$json" > "$file"
}

###############################################################################
# 6. CONFLICT DETECTION HELPERS
###############################################################################

scan_rule_conflicts() {
  local rules_dir="${1:-}"
  if [[ -z "$rules_dir" ]]; then
    resolve_levelup_paths >/dev/null
    rules_dir="${TEAM_DIRECTIVES}/context_modules/rules"
  fi

  if [[ ! -d "$rules_dir" ]]; then
    echo "[]"
    return 0
  fi

  python3 - "$rules_dir" << 'PY'
import sys, os, re, json
rules_dir = sys.argv[1]
rules = []
for root, _, files in os.walk(rules_dir):
    for f in files:
        if not f.endswith('.md'): continue
        path = os.path.join(root, f)
        with open(path) as fh:
            content = fh.read()
        # Extract first heading as statement
        m = re.search(r'^#\s+(.+)$', content, re.M)
        statement = m.group(1).strip() if m else ""
        rules.append({"file": os.path.relpath(path, rules_dir), "statement": statement, "content": content})

conflicts = []
opposites = [("must", "never"), ("always", "never"), ("require", "forbid"), ("allow", "prohibit")]
for i, r1 in enumerate(rules):
    for r2 in rules[i+1:]:
        s1 = r1["statement"].lower()
        s2 = r2["statement"].lower()
        for a, b in opposites:
            if (a in s1 and b in s2) or (b in s1 and a in s2):
                conflicts.append({
                    "type": "direct_contradiction",
                    "rule_a": r1["file"],
                    "rule_b": r2["file"],
                    "hint": f"'{a}' vs '{b}'"
                })
print(json.dumps(conflicts))
PY
}

###############################################################################
# 7. MAIN CLI
###############################################################################

main() {
  if [[ "$#" -eq 0 ]]; then
    resolve_levelup_paths
    return
  fi

  case "$1" in
    --json)
      output_levelup_json
      ;;
    --next-cdr)
      next_cdr_number "${2:-}"
      ;;
    --index)
      regenerate_cdr_index "${2:-}" "${3:-}"
      ;;
    --signal-gate)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --signal-gate requires a file argument" >&2
        exit 1
      fi
      signal_gate "$2"
      ;;
    --conflicts)
      scan_rule_conflicts "${2:-}"
      ;;
    --state)
      if [[ -n "${2:-}" ]]; then
        read_levelup_state "$2"
      else
        read_levelup_state
      fi
      ;;
    --help|-h)
      echo "Usage: levelup-helpers.sh [--json] [--next-cdr [DIR]] [--index [DIR] [FILE]] [--signal-gate FILE] [--conflicts [RULES_DIR]] [--state [FILE]]"
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
}

main "$@"
