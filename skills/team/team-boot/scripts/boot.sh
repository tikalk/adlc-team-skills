#!/usr/bin/env bash
# team-boot session_start script — lean orientation for first user message injection.
# Pure shell (grep/sed), no runtime dependencies.
set -euo pipefail

INIT_FILE=".adlc/init-options.json"

if [ ! -f "$INIT_FILE" ]; then
  echo "<EXTREMELY_IMPORTANT>"
  echo "Team AI directives not configured for this project."
  echo "Run /team-setup to wire in the team constitution, CDR index, PDR/ADR indexes, and skill registry."
  echo "</EXTREMELY_IMPORTANT>"
  exit 0
fi

# Extract team_ai_directives from JSON (pure shell, no runtime deps).
TEAM_AI_DIRECTIVES=$(grep '"team_ai_directives"' "$INIT_FILE" \
  | sed 's/.*"team_ai_directives"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
  | head -1)

# Handle null marker (user opted out) or empty value.
if [ -z "$TEAM_AI_DIRECTIVES" ] || [ "$TEAM_AI_DIRECTIVES" = "null" ]; then
  exit 0
fi

# Verify path exists.
if [ ! -d "$TEAM_AI_DIRECTIVES" ]; then
  echo "<EXTREMELY_IMPORTANT>"
  echo "Team AI directives path not found: $TEAM_AI_DIRECTIVES"
  echo "Run /team-setup to reconfigure."
  echo "</EXTREMELY_IMPORTANT>"
  exit 0
fi

echo "<EXTREMELY_IMPORTANT>"
echo "# Team AI Directives"
echo ""
echo "Path: $TEAM_AI_DIRECTIVES"
echo ""

# Constitution — principle titles only (lean)
echo "## Constitution"
grep '^[0-9]\+\.' "$TEAM_AI_DIRECTIVES/context_modules/constitution.md" 2>/dev/null | head -20 || echo "(not found)"
echo ""

# CDR Index — compact: ID + Type + Descriptor only
echo "## CDR Index"
awk -F'|' '/^\| CDR|^\| skill|^\| example/ {gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$9); print "| " $2 " | " $4 " | " $9 " |"}' "$TEAM_AI_DIRECTIVES/CDR.md" 2>/dev/null || echo "(not found)"
echo ""

# Skills — names + descriptions only (lean)
echo "## Available Skills"
jq -r '.default[]' "$TEAM_AI_DIRECTIVES/.skills.json" 2>/dev/null | while read -r name; do
  echo "- $name"
done
jq -r '.external | to_entries[] | "- \(.key): \(.value.description)"' "$TEAM_AI_DIRECTIVES/.skills.json" 2>/dev/null || true
echo ""

# MCP Servers — names only (lean)
echo "## MCP Servers"
jq -r '.mcpServers | keys[]' "$TEAM_AI_DIRECTIVES/.mcp.json" 2>/dev/null | while read -r name; do
  echo "- $name"
done || echo "(none)"
echo ""

echo "Read full CDR.md, .skills.json, and context module files on demand when a task matches."
echo ""
echo "**Every response MUST include** a Team Context in Use section before the task answer:"
echo ""
echo "| ID | Type | Relevance |"
echo "|----|------|-----------|"
echo "| CDR-2026-003 | Persona | High |"
echo ""
echo "Plus: _Searched N CDR entries, M skills, J matched._"
echo "</EXTREMELY_IMPORTANT>"
