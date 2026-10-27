#!/usr/bin/env bash
# paths.sh — shared layout constants (single definition).
#
# Sourced, never executed. Defines the .adlc/ + docs/adlc/ path roots and the
# R7 gitignore allowlist consumed by the setup scripts (workspace, boot,
# architect/product/change families). No side effects beyond variable
# definitions; safe to source multiple times and under `set -euo pipefail`.

# Double-source guard.
[ -n "${_ADLC_PATHS_SH:-}" ] && return 0
_ADLC_PATHS_SH=1

# --- Layout roots -------------------------------------------
# .adlc/ holds the machine pipeline; docs/adlc/ holds published, human-facing
# deliverables (memory records, PRD/AD, views, roadmap).
ADLC_DIR=".adlc"
DOCS_ADLC_DIR="docs/adlc"
DOCS_ADLC_MEMORY="docs/adlc/memory"
DOCS_ADLC_PRODUCT="docs/adlc/product"
DOCS_ADLC_ARCHITECT="docs/adlc/architect"
ADLC_DRAFTS=".adlc/drafts"

# --- Gitignore allowlist (verbatim) ------------------------------
# Replaces the legacy wholesale `.adlc/` ignore. Order matters: negations must
# follow the `.adlc/*` blanket ignore. The report pair
# `.adlc/team-learn-report.md` AND `.adlc/team-levelup-report.md` keeps the
# legacy name ignored during the team-levelup rename transition.
GITIGNORE_RULES_ALLOWLIST=(
  # ADLC — agent-install surface (regenerated)
  ".agents/"
  ".opencode/"
  ".claude/"
  ".cursor/"
  ".codex/"
  ".gemini/"
  ".qwen/"
  ".devin/"
  ".tabnine/"
  "skills-lock.json"
  ".skills.json"
  ".mcp.json"
  ".events.json"
  ".pytest_cache/"
  ".ruff_cache/"
  # ADLC — machine pipeline + runtime state (tracked exceptions follow)
  ".adlc/*"
  "!.adlc/init-options.json"
  "!.adlc/workspace.yml"
  "!.adlc/drafts/"
  "!.adlc/evals/"
  ".adlc/evals/results/"
  "!.adlc/memory/"
  ".adlc/memory/*"
  "!.adlc/memory/evals/"
  "!.adlc/memory/evals/holdout.json"
  # ADLC — generated reports (post team-levelup rename; legacy name kept during transition)
  ".adlc/team-learn-report.md"
  ".adlc/team-levelup-report.md"
  # Knowledge graph (generated)
  "graphify-out/"
)

# --- Ledger base staleness -----------------------------------------------
# A slot number computed from a stale base is still wrong even when the
# helper computes it correctly: the working tree simply does not know about
# the numbers the merge target already uses. Run this BEFORE allocating any
# ledger slot (record ids, PRD section numbers, REQ ids, Feature numbers, AD
# delta versions).
#
# Reports ONE number. `git rev-list --left-right --count A...B` reports "left
# right" and the two columns are trivial to transpose -- that misread is
# exactly how an intent run claimed PRD/ADR slots the merge target had
# already taken.
ledger_base_behind() {
  local target="${1:-origin/main}"
  git rev-list --count "HEAD..${target}" 2>/dev/null || echo -1
}

# require_current_base [TARGET] - refuse to proceed on a stale base.
# Returns 1 and explains, naming the target and how many commits are missing.
# A target that cannot be read at all (-1) is not proof of staleness: warn and
# continue rather than blocking a repo that has no such ref.
require_current_base() {
  local target="${1:-origin/main}"
  local behind
  behind=$(ledger_base_behind "$target")
  if ! [[ "$behind" =~ ^[0-9]+$ ]]; then
    echo "WARN: cannot read $target to check the base; continuing unverified." >&2
    return 0
  fi
  if [ "$behind" -gt 0 ]; then
    echo "ERROR: this checkout is ${behind} commit(s) behind ${target}." >&2
    echo "       A slot number read from this base may already be taken." >&2
    echo "       Rebase or merge ${target} before claiming ledger slots." >&2
    return 1
  fi
  return 0
}
