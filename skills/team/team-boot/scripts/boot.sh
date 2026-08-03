#!/usr/bin/env bash
# team-boot session_start script — assembles team AI directives context.
# Pure shell (grep/sed), no runtime dependencies.
set -euo pipefail

INIT_FILE=".adlc/init-options.json"

if [ ! -f "$INIT_FILE" ]; then
  echo "Team AI directives not configured."
  echo ""
  echo "MANDATORY: Invoke the team-setup skill now (skill({name: \"team-setup\"}))."
  echo "Do not proceed with any task until team-setup has been invoked."
  echo ""
  echo "This is not optional and applies to EVERY task — questions, code changes,"
  echo "skill improvements, consultations. Do NOT rationalize skipping team-setup:"
  echo "- 'This is just a simple question' → Questions are tasks. Setup first."
  echo "- 'I need to be efficient' → Setup IS part of the task."
  echo "- 'This is a skills/meta repo' → team-setup applies to ALL repos."
  echo "- 'The user didn't ask for setup' → Unconfigured = setup needed."
  echo "- 'I can help without it' → No. Invoke team-setup first, then help."
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
