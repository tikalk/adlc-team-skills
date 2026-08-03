#!/usr/bin/env bash
# team-boot session_start script — assembles team AI directives context.
# Pure shell (grep/sed), no runtime dependencies.
set -euo pipefail

INIT_FILE=".adlc/init-options.json"

if [ ! -f "$INIT_FILE" ]; then
  echo "Team AI directives not configured for this project."
  echo ""
  echo "Invoke the team-setup skill to configure it: skill({name: \"team-setup\"})"
  echo "This wires in the team constitution, CDR index, PDR/ADR indexes, and skill registry."
  echo "This applies to ALL repos — skills repos, consumer projects, and dev repos alike."
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
  echo "Team AI directives path not found: $TEAM_AI_DIRECTIVES"
  exit 0
fi

echo "# Team AI Directives Context"
echo ""
echo "## Constitution"
cat "$TEAM_AI_DIRECTIVES/context_modules/constitution.md" 2>/dev/null || echo "(not found)"
echo ""
echo "## CDR Index"
# Extract only the index table (up to first --- separator).
awk '/^---/{exit} {print}' "$TEAM_AI_DIRECTIVES/CDR.md" 2>/dev/null || echo "(not found)"
echo ""
echo "## PDR Index"
cat ".adlc/memory/pdr/pdr.md" 2>/dev/null || echo "(none)"
echo ""
echo "## ADR Index"
cat ".adlc/memory/adr/adr.md" 2>/dev/null || echo "(none)"
echo ""
echo "## Available Skills"
cat "$TEAM_AI_DIRECTIVES/.skills.json" 2>/dev/null || echo "(none)"
echo ""
echo "---"
echo "The CDR index lists all available team context modules. When a task"
echo "matches a CDR descriptor, read the full module file at the Target"
echo "Module path for the complete directive text. Apply relevant directives."
