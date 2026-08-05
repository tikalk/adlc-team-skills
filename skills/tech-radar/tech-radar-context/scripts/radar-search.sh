#!/usr/bin/env bash
# radar-search.sh — Deterministic search and alias normalization for Tikal Tech Radar.
# Requires jq. Pure bash, no Python/Node dependency.
#
# Usage:
#   bash radar-search.sh <query1> [query2 ...] [--json]
#
# Examples:
#   bash radar-search.sh postgresql redis
#   bash radar-search.sh k8s "gh actions"
#   bash radar-search.sh --json flask
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RADAR_JSON="${SCRIPT_DIR}/../resources/radar.json"

if [ ! -f "$RADAR_JSON" ]; then
  RADAR_JSON="${PWD}/skills/tech-radar/tech-radar-context/resources/radar.json"
fi

if [ ! -f "$RADAR_JSON" ]; then
  echo "Error: radar.json not found" >&2
  exit 1
fi

OUTPUT_JSON=false
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--json" ]; then
    OUTPUT_JSON=true
  else
    ARGS+=("$arg")
  fi
done

if [ ${#ARGS[@]} -eq 0 ]; then
  echo "Usage: radar-search.sh <tech1> [tech2 ...] [--json]"
  exit 1
fi

# Alias map (query -> canonical name)
normalize_alias() {
  local q="$1"
  local ql="${q,,}"
  case "$ql" in
    k8s|kube) echo "Kubernetes" ;;
    postgres|postgresql|pg) echo "PostgreSQL" ;;
    "gh actions"|github-actions) echo "GitHub Actions" ;;
    cra|create-react-app) echo "Create React App" ;;
    next|nextjs) echo "Next.js" ;;
    vue|vuejs) echo "Vue.js" ;;
    node|nodejs) echo "Node.js" ;;
    ts|typescript) echo "TypeScript" ;;
    iac) echo "Infrastructure as Code (IaC)" ;;
    mcp) echo "Model Context Protocol (MCP)" ;;
    rsc) echo "React Server Components" ;;
    rtk) echo "Redux Toolkit" ;;
    idp) echo "Internal Developer Portals (IDPs) (e.g., Port.io. Backstage)" ;;
    eso) echo "External Secrets Operator" ;;
    gke) echo "GKE Workload Identity" ;;
    *) echo "$q" ;;
  esac
}

# Search blips for a single query, output as TSV: name\tquadrant\tring\twhy
search_blips() {
  local query="$1"
  local canonical
  canonical=$(normalize_alias "$query")
  local ql="${query,,}"
  local cl="${canonical,,}"

  # Use jq to extract matching blips + extract Why? text + strip HTML.
  # Match by canonical alias only (no raw-query contains) to avoid short-query
  # false positives (e.g. "ts" matching "A2A Agents", "Argo Rollouts").
  jq -r --arg c "$cl" '
    .blips[] |
    select(
      (.name | ascii_downcase) == $c or
      (.name | ascii_downcase | startswith($c)) or
      ((.name | ascii_downcase) | contains($c))
    ) |
    .description as $desc |
    (
      if ($desc | test("<p>Why\\?</p>")) then
        ($desc | sub("<p>Why\\?</p>"; "") | split("<p>Description</p>")[0])
      else
        $desc
      end
    ) as $why_raw |
    ($why_raw | gsub("<[^>]*>"; " ") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ")) as $why |
    (if ($why | length) > 160 then
       ($why | .[0:157] | sub(" [^ ]*$"; "") + "...")
     else
       $why
     end) as $why_trunc |
    "\(.name)\t\(.quadrant)\t\(.ring)\t\($why_trunc)"
  ' "$RADAR_JSON" 2>/dev/null
}

# Collect all results
ALL_RESULTS=""
declare -A SEEN
for query in "${ARGS[@]}"; do
  while IFS=$'\t' read -r name quadrant ring why; do
    [ -z "$name" ] && continue
    key="${name}|${quadrant}|${ring}"
    if [ -z "${SEEN[$key]:-}" ]; then
      SEEN[$key]=1
      ALL_RESULTS+="${name}|${quadrant}|${ring}|${why}"$'\n'
    fi
  done < <(search_blips "$query")
done

# Remove trailing newline
ALL_RESULTS="${ALL_RESULTS%$'\n'}"

if [ "$OUTPUT_JSON" = true ]; then
  # Output as JSON array — convert pipe-separated lines via jq
  echo "$ALL_RESULTS" | jq -R -s '
    split("\n") | map(select(length > 0)) |
    map(split("|")) |
    map({name: .[0], quadrant: .[1], ring: .[2], why: .[3]})
  '
  exit 0
fi

# Format as markdown table
if [ -z "$ALL_RESULTS" ]; then
  echo "## Tikal Tech Radar Context"
  echo ""
  echo "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |"
  echo "|------------|----------|------|------------------------|"
  echo ""
  echo "_Source: Tikal Israeli Tech Radar (local snapshot) · 0 technologies matched._"
  exit 0
fi

echo "## Tikal Tech Radar Context"
echo ""
echo "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |"
echo "|------------|----------|------|------------------------|"

echo "$ALL_RESULTS" | while IFS='|' read -r name quadrant ring why; do
  [ -z "$name" ] && continue
  echo "| $name | $quadrant | $ring | $why |"
done

echo ""
echo "**Radar Guidance**"

# Build guidance per unique tech name (deduplicated).
# Use awk for exact first-field match (robust against regex-special blip names
# like "JCasC (Jenkins Configuration as Code)" or "Node.js").
echo "$ALL_RESULTS" | cut -d'|' -f1 | sort -u | while IFS= read -r tech; do
  [ -z "$tech" ] && continue
  rings=$(echo "$ALL_RESULTS" | awk -F'|' -v t="$tech" '$1==t {print $3}' | sort -u | tr '\n' ',')
  rings="${rings%,}"
  placements=$(echo "$ALL_RESULTS" | awk -F'|' -v t="$tech" '$1==t {print $2": "$3}' | tr '\n' ',' | sed 's/,$//')
  if echo "$rings" | grep -q "Stop" && echo "$rings" | grep -qE "Keep|Start"; then
    echo "- ⚡ **Conflicting Placements**: \`$tech\` has multiple placements across categories ($placements). Check specific quadrant context."
  elif echo "$rings" | grep -q "Stop"; then
    echo "- ⚠️ **Stop**: \`$tech\` — Tikal advises against usage; better alternatives exist. Seek Keep/Start alternatives in the same quadrant."
  elif echo "$rings" | grep -qE "Keep|Start"; then
    echo "- ✅ **Adopt**: \`$tech\` — Recommended standard ($placements)."
  elif echo "$rings" | grep -q "Try"; then
    echo "- 🧪 **Try**: \`$tech\` — Seems promising on the surface; evaluate before broader adoption."
  fi
done

RESULT_COUNT=$(echo "$ALL_RESULTS" | grep -c '|' || true)
echo ""
echo "_Source: Tikal Israeli Tech Radar (local snapshot) · ${RESULT_COUNT} blip placement(s) matched._"
