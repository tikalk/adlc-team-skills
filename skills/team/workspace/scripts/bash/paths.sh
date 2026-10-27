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
  # .mcp.json is deliberately ABSENT: it is committed project source (human-edited,
  # never generated), so it must not be gitignored. Only the agent dirs above are derived.
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
