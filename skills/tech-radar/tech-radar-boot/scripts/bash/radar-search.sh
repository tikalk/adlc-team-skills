#!/usr/bin/env bash
# radar-search.sh — deterministic search over the Tikal Tech Radar OKF knowledge tree.
# bash + jq only (no Python/Node).
#
# Knowledge source: gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-radar
# `knowledge/technologies/` is the system of record. The helper keeps a shallow
# clone in a cache directory and refreshes it after ADLC_RADAR_TTL seconds
# (default 3 days). When the repository is unreachable it falls back — in order —
# to the stale clone (with a warning) and then to the public radar JSON
# (https://tikalk.com/radar.json), announcing the fallback on stdout + stderr.
#
# Usage:
#   bash radar-search.sh <query1> [query2 ...] [options]
#   bash radar-search.sh --json flask
#
# Options:
#   --json               JSON array output instead of the markdown table
#   --refresh            force a git refresh even inside the TTL
#   --quadrant <Q>       filter: DevOps | Backend | AI/ML | Web/Mobile
#   --ring <R>           filter: Try | Start | Keep | Stop
#   --limit <N>          max rows per category (body-term) match (default 5)
#   --include-excluded   include docs marked `include: no` (excluded from radar.json)
#   -h, --help
#
# Environment:
#   ADLC_RADAR_URL            git remote (default: SSH GitLab adlc-radar)
#   ADLC_RADAR_BRANCH         branch to track (default: main)
#   ADLC_RADAR_CACHE          cache checkout (default: ${XDG_CACHE_HOME:-$HOME/.cache}/adlc/radar)
#   ADLC_RADAR_REPO           use this existing local clone instead (no git network calls)
#   ADLC_RADAR_TTL            refresh interval in seconds (default: 259200 = 3 days)
#   ADLC_RADAR_FALLBACK_URL   public radar JSON used only when no checkout is usable
#   ADLC_RADAR_CONNECT_TIMEOUT  SSH/HTTP connect timeout seconds (default: 10)
set -euo pipefail

DEFAULT_REPO_URL="git@gitlab.tikalk.dev:tikalk/engineering/agentic-sdlc/adlc-radar.git"

REPO_URL="${ADLC_RADAR_URL:-$DEFAULT_REPO_URL}"
REPO_BRANCH="${ADLC_RADAR_BRANCH:-main}"
CACHE_TTL="${ADLC_RADAR_TTL:-259200}"
CACHE_DIR="${ADLC_RADAR_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/adlc/radar}"
LOCAL_REPO="${ADLC_RADAR_REPO:-}"
FALLBACK_URL="${ADLC_RADAR_FALLBACK_URL:-https://tikalk.com/radar.json}"
CONNECT_TIMEOUT="${ADLC_RADAR_CONNECT_TIMEOUT:-10}"

QUERIES=()
OUTPUT_JSON=false
FORCE_REFRESH=false
FILTER_QUADRANT=""
FILTER_RING=""
LIMIT=5
INCLUDE_EXCLUDED=false

MODE=""
REASON=""
SHA=""
SYNCED_AT=""
LOCK_DIR=""

usage() {
  sed -n '9,30p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json) OUTPUT_JSON=true ;;
    --refresh) FORCE_REFRESH=true ;;
    --include-excluded) INCLUDE_EXCLUDED=true ;;
    --quadrant)
      [ $# -ge 2 ] || { echo "Error: --quadrant requires a value" >&2; exit 1; }
      FILTER_QUADRANT="$2"
      shift
      ;;
    --ring)
      [ $# -ge 2 ] || { echo "Error: --ring requires a value" >&2; exit 1; }
      FILTER_RING="$2"
      shift
      ;;
    --limit)
      [ $# -ge 2 ] || { echo "Error: --limit requires a value" >&2; exit 1; }
      LIMIT="$2"
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    --*)
      echo "Error: unknown option $1" >&2
      exit 1
      ;;
    *) QUERIES+=("$1") ;;
  esac
  shift
done

if [ ${#QUERIES[@]} -eq 0 ]; then
  echo "Usage: radar-search.sh <tech1> [tech2 ...] [--json] [--refresh]" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/radar-search.XXXXXX")"
INDEX_FILE="$WORK_DIR/index.tsv"
RESULTS_FILE="$WORK_DIR/results.tsv"
SEEN_FILE="$WORK_DIR/seen.txt"
cleanup() {
  rm -rf "$WORK_DIR"
  if [ -n "$LOCK_DIR" ]; then rmdir "$LOCK_DIR" 2>/dev/null || true; fi
}
trap cleanup EXIT

: > "$SEEN_FILE"
: > "$RESULTS_FILE"

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

notice() {
  # Visible markdown blockquote — the skill re-emits these lines in its answer.
  printf '> ⚠️ %s\n\n' "$1"
}

file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

synced_at() {
  local ref="$CACHE_DIR/.adlc-radar-synced"
  local stamped=""
  if [ -f "$ref" ]; then
    stamped="$(cat "$ref" 2>/dev/null || true)"
    case "$stamped" in
      ''|*[!0-9]*) stamped="" ;;
    esac
  fi
  if [ -n "$stamped" ]; then
    date -r "$stamped" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
      || date -d "@$stamped" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
      || echo unknown
    return 0
  fi
  ref="$CACHE_DIR/.git/FETCH_HEAD"
  [ -f "$ref" ] || { echo "unknown"; return 0; }
  local mtime
  mtime="$(file_mtime "$ref")"
  date -r "$mtime" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -d "@$mtime" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || echo unknown
}

cache_age() {
  local ref="$CACHE_DIR/.adlc-radar-synced"
  if [ -f "$ref" ]; then
    local stamped
    stamped="$(cat "$ref" 2>/dev/null || true)"
    case "$stamped" in
      ''|*[!0-9]*) stamped=0 ;;
    esac
    if [ "$stamped" -gt 0 ]; then
      echo $(( $(date +%s) - stamped ))
      return 0
    fi
  fi
  ref="$CACHE_DIR/.git/FETCH_HEAD"
  [ -f "$ref" ] || { echo 999999999; return 0; }
  local mtime
  mtime="$(file_mtime "$ref")"
  echo $(( $(date +%s) - mtime ))
}

git_ssh_cmd="ssh -o ConnectTimeout=$CONNECT_TIMEOUT -o BatchMode=yes"

clone_cache() {
  mkdir -p "$(dirname "$CACHE_DIR")"
  git -c "core.sshCommand=$git_ssh_cmd" clone --depth 1 --quiet \
    --branch "$REPO_BRANCH" "$REPO_URL" "$CACHE_DIR"
}

refresh_cache() {
  git -C "$CACHE_DIR" -c "core.sshCommand=$git_ssh_cmd" fetch --depth 1 --quiet \
    origin "$REPO_BRANCH" \
    && git -C "$CACHE_DIR" reset --hard --quiet FETCH_HEAD
}

stamp_synced() {
  printf '%s\n' "$(date +%s)" > "$CACHE_DIR/.adlc-radar-synced" 2>/dev/null || true
}

# Resolve the knowledge source. Sets MODE to okf | local | stale, or leaves MODE
# empty (and REASON populated) when no checkout is usable.
ensure_data_source() {
  if [ -n "$LOCAL_REPO" ]; then
    if [ -d "$LOCAL_REPO/knowledge/technologies" ]; then
      MODE="local"
      SHA="$(git -C "$LOCAL_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
      SYNCED_AT="local clone"
      return 0
    fi
    REASON="ADLC_RADAR_REPO=$LOCAL_REPO has no knowledge/technologies"
    return 1
  fi

  local have_lock=0
  if mkdir "${CACHE_DIR}.lock" 2>/dev/null; then
    have_lock=1
    LOCK_DIR="${CACHE_DIR}.lock"
  fi

  if [ ! -d "$CACHE_DIR/knowledge/technologies" ]; then
    if [ "$have_lock" -eq 1 ] && clone_cache 2>/dev/null; then
      stamp_synced
    else
      REASON="clone failed ($REPO_URL)"
      return 1
    fi
  else
    local age
    age="$(cache_age)"
    if [ "$FORCE_REFRESH" = true ] || [ "$age" -ge "$CACHE_TTL" ]; then
      if [ "$have_lock" -eq 1 ] && refresh_cache 2>/dev/null; then
        stamp_synced
      else
        MODE="stale"
        REASON="refresh failed ($REPO_URL)"
        SHA="$(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        SYNCED_AT="$(synced_at)"
        return 0
      fi
    fi
  fi

  MODE="okf"
  SHA="$(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  SYNCED_AT="$(synced_at)"
  return 0
}

# Frontmatter (`title`, `quadrant`, `ring`, `include`) + `## Why` section of every
# technology document, as tab-separated records:
#   title <TAB> quadrant <TAB> ring <TAB> include <TAB> path <TAB> why
build_index() {
  local root="$1"
  DOC_COUNT=0
  : > "$INDEX_FILE"
  local files=("$root"/knowledge/technologies/*/*.md)
  [ -e "${files[0]}" ] || return 0
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function unquote(s) { if (s ~ /^".*"$/) { s = substr(s, 2, length(s) - 2) }; return s }
    function flush() {
      if (title == "") { return }
      gsub(/[ \t]+/, " ", why)
      why = trim(why)
      gsub(/[\t\r\n]+/, " ", title)
      gsub(/[\t\r\n]+/, " ", quadrant)
      gsub(/[\t\r\n]+/, " ", ring)
      gsub(/[\t\r\n]+/, " ", include)
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", title, quadrant, ring, include, curfile, why
    }
    function reset() { title = ""; quadrant = ""; ring = ""; include = ""; why = ""; in_fm = 0; fm_done = 0; in_why = 0 }
    FNR == 1 { if (started) { flush() }; reset(); curfile = FILENAME; started = 1; skip = (FILENAME ~ /\/index\.md$/) }
    {
      if (skip == 1) { next }
      line = $0
      if (fm_done == 0) {
        if (line == "---") { if (in_fm == 1) { fm_done = 1 } else { in_fm = 1 }; next }
        if (in_fm == 1) {
          i = index(line, ":")
          if (i > 1) {
            k = trim(substr(line, 1, i - 1))
            v = unquote(trim(substr(line, i + 1)))
            if (k == "title") { title = v }
            else if (k == "quadrant") { quadrant = v }
            else if (k == "ring") { ring = v }
            else if (k == "include") { include = v }
          }
          next
        }
      }
      if (in_why == 1) {
        if (line ~ /^## /) { in_why = 0 }
        else { why = why " " line; next }
      }
      if (line ~ /^## Why[ \t]*$/) { in_why = 1 }
    }
    END { flush() }
  ' "${files[@]}" > "$INDEX_FILE"
  DOC_COUNT="$(wc -l < "$INDEX_FILE" | tr -d ' ')"
}

# Title matches for one canonical query. Emits records with a rank column.
match_title() {
  local q="$1"
  awk -F'\t' -v q="$q" -v fq="$FILTER_QUADRANT" -v fr="$FILTER_RING" -v inc="$INCLUDE_EXCLUDED" '
    function lc(s) { return tolower(s) }
    function emit(rank) { printf "%s\t%s\t%s\t%s\t%s\t%d\n", $1, $2, $3, $6, $5, rank }
    {
      if (inc == "false" && lc($4) == "no") { next }
      if (fq != "" && lc($2) != lc(fq)) { next }
      if (fr != "" && lc($3) != lc(fr)) { next }
      t = lc($1)
      if (t == q) { emit(3); next }
      if (index(t, q) == 1) { emit(2); next }
      if (index(t, q) > 0) { emit(1) }
    }
  ' "$INDEX_FILE"
}

# Category queries ("we need an event streaming platform") fall back to body-term
# ranking — title hits weigh 3x — mirroring adlc-radar's tools/search.py.
match_body() {
  local q="$1"
  awk -F'\t' -v q="$q" -v fq="$FILTER_QUADRANT" -v fr="$FILTER_RING" -v inc="$INCLUDE_EXCLUDED" '
    function lc(s) { return tolower(s) }
    BEGIN { n = split(q, terms, /[^a-z0-9]+/) }
    {
      if (inc == "false" && lc($4) == "no") { next }
      if (fq != "" && lc($2) != lc(fq)) { next }
      if (fr != "" && lc($3) != lc(fr)) { next }
      title = lc($1)
      body = lc($1 " " $6)
      score = 0
      for (i = 1; i <= n; i++) {
        t = terms[i]
        if (length(t) < 2) { continue }
        if (t ~ /^(no|not|such|the|and|or|for|with|need|want|using|use|of|to|in|on|at|by|is|are|be|we|our|a|an)$/) { continue }
        ts = title
        while ((p = index(ts, t)) > 0) { score += 3; ts = substr(ts, p + length(t)) }
        bs = body
        while ((p = index(bs, t)) > 0) { score += 1; bs = substr(bs, p + length(t)) }
      }
      if (score >= 2) { printf "%d\t%s\t%s\t%s\t%s\t%s\n", score, $1, $2, $3, $6, $5 }
    }
  ' "$INDEX_FILE" | sort -rn | head -n "$LIMIT" \
    | awk -F'\t' 'BEGIN { OFS = "\t" } { print $2, $3, $4, $5, $6, 0 }'
}

# Query -> canonical name (alias map kept from the radar.json era).
normalize_alias() {
  local ql
  ql="$(lc "$1")"
  case "$ql" in
    k8s|kube|kubernetes) echo "Kubernetes" ;;
    postgres|postgresql|pg) echo "PostgreSQL" ;;
    "gh actions"|github-actions|github_actions) echo "GitHub Actions" ;;
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
    *) echo "$1" ;;
  esac
}

append_results() {
  while IFS=$'\t' read -r name quadrant ring why path _rank; do
    [ -n "$name" ] || continue
    if [ ${#why} -gt 160 ]; then
      why="$(printf '%s' "$why" | cut -c1-157 | sed 's/ [^ ]*$//')..."
    fi
    local key="$name|$quadrant|$ring"
    if ! grep -Fxq -- "$key" "$SEEN_FILE"; then
      printf '%s\n' "$key" >> "$SEEN_FILE"
      printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$quadrant" "$ring" "$why" "$path" >> "$RESULTS_FILE"
    fi
  done
}

search_okf() {
  local query canonical q rows
  for query in "${QUERIES[@]}"; do
    [ -n "$query" ] || continue
    canonical="$(normalize_alias "$query")"
    q="$(lc "$canonical")"
    rows="$(match_title "$q")"
    if [ -z "$rows" ]; then
      rows="$(match_body "$(lc "$query")")"
    fi
    append_results <<< "$rows"
  done
}

fetch_fallback() {
  case "$FALLBACK_URL" in
    file://*) cat "${FALLBACK_URL#file://}" ;;
    /*) cat "$FALLBACK_URL" ;;
    *) curl -fsSL --proto '=https' --max-time "$CONNECT_TIMEOUT" "$FALLBACK_URL" ;;
  esac
}

search_fallback_json() {
  local data="$1"
  local rows
  rows="$(printf '%s' "$data" | jq -r --arg fq "$FILTER_QUADRANT" --arg fr "$FILTER_RING" '
    def lc(s): (s | ascii_downcase);
    .blips[]
    | select(($fq == "") or (lc(.quadrant) == lc($fq)))
    | select(($fr == "") or (lc(.ring) == lc($fr)))
    | . as $b
    | ($b.description // "") as $desc
    | (if ($desc | test("<p>Why\\?</p>")) then
         ($desc | sub("<p>Why\\?</p>"; "") | split("<p>Description</p>")[0])
       else $desc end) as $why_raw
    | ($why_raw | gsub("<[^>]*>"; " ") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ")) as $why
    | [$b.name, $b.quadrant, $b.ring, $why] | @tsv
  ' 2>/dev/null)" || rows=""

  local query canonical q
  for query in "${QUERIES[@]}"; do
    [ -n "$query" ] || continue
    canonical="$(normalize_alias "$query")"
    q="$(lc "$canonical")"
    while IFS=$'\t' read -r name quadrant ring why; do
      [ -n "$name" ] || continue
      local nl
      nl="$(lc "$name")"
      case "$nl" in
        "$q"*|*"$q"*)
          local key="$name|$quadrant|$ring"
          if ! grep -Fxq -- "$key" "$SEEN_FILE"; then
            printf '%s\n' "$key" >> "$SEEN_FILE"
            if [ ${#why} -gt 160 ]; then
              why="$(printf '%s' "$why" | cut -c1-157 | sed 's/ [^ ]*$//')..."
            fi
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$quadrant" "$ring" "$why" "public:radar.json" >> "$RESULTS_FILE"
          fi
          ;;
      esac
    done <<< "$rows"
  done
}

print_guidance() {
  local names
  names="$(cut -f1 "$RESULTS_FILE" | awk '!seen[$0]++')"
  local tech rings placements
  while IFS= read -r tech; do
    [ -n "$tech" ] || continue
    rings="$(awk -F'\t' -v t="$tech" '$1 == t { print $3 }' "$RESULTS_FILE" | sort -u | tr '\n' ',' | sed 's/,$//')"
    placements="$(awk -F'\t' -v t="$tech" '$1 == t { print $2 ": " $3 }' "$RESULTS_FILE" | tr '\n' ',' | sed 's/,$//')"
    if printf '%s' "$rings" | grep -q "Stop" && printf '%s' "$rings" | grep -qE "Keep|Start"; then
      printf -- '- ⚡ **Conflicting Placements**: `%s` has multiple placements across categories (%s). Check specific quadrant context.\n' "$tech" "$placements"
    elif printf '%s' "$rings" | grep -q "Stop"; then
      printf -- '- ⚠️ **Stop**: `%s` — Tikal advises against usage; better alternatives exist. Seek Keep/Start alternatives in the same quadrant.\n' "$tech"
    elif printf '%s' "$rings" | grep -qE "Keep|Start"; then
      printf -- '- ✅ **Adopt**: `%s` — Recommended standard (%s).\n' "$tech" "$placements"
    elif printf '%s' "$rings" | grep -q "Try"; then
      printf -- '- 🧪 **Try**: `%s` — Seems promising on the surface; evaluate before broader adoption.\n' "$tech"
    fi
  done <<< "$names"
}

source_label() {
  case "$MODE" in
    local) printf 'adlc-radar OKF tree (local clone at %s%s)' "$LOCAL_REPO" "${SHA:+@$SHA}" ;;
    stale) printf 'adlc-radar OKF tree (%s@%s, synced %s; STALE — %s)' "$REPO_BRANCH" "$SHA" "$SYNCED_AT" "$REASON" ;;
    fallback) printf 'FALLBACK public radar.json (%s)' "$FALLBACK_URL" ;;
    *) printf 'adlc-radar OKF tree (%s@%s, synced %s)' "$REPO_BRANCH" "$SHA" "$SYNCED_AT" ;;
  esac
}

DATA_UNAVAILABLE=false

if ensure_data_source; then
  build_index "${LOCAL_REPO:-$CACHE_DIR}"
  search_okf
  if [ "$MODE" = "stale" ]; then
    notice "Radar knowledge repository unreachable ($REASON) — using the cached OKF tree from $SYNCED_AT. Rings may have moved since then."
  fi
else
  MODE="fallback"
  notice "Radar knowledge repository unavailable ($REASON) — working with the public radar JSON at $FALLBACK_URL. It is generated from the same knowledge tree and may lag it."
  if RADAR_JSON="$(fetch_fallback 2>/dev/null)" && printf '%s' "$RADAR_JSON" | jq -e '.blips' >/dev/null 2>&1; then
    search_fallback_json "$RADAR_JSON"
  else
    DATA_UNAVAILABLE=true
    printf 'radar-search: public radar JSON unavailable at %s\n' "$FALLBACK_URL" >&2
  fi
fi

COUNT=0
[ -f "$RESULTS_FILE" ] && COUNT="$(wc -l < "$RESULTS_FILE" | tr -d ' ')"

if [ "$OUTPUT_JSON" = true ]; then
  jq -R -s 'split("\n") | map(select(length > 0)) | map(split("\t")) | map({name: .[0], quadrant: .[1], ring: .[2], why: .[3], path: .[4]})' "$RESULTS_FILE"
  exit 0
fi

echo "## Tikal Tech Radar Context"
echo ""

if [ "$COUNT" -gt 0 ]; then
  echo "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |"
  echo "|------------|----------|------|------------------------|"
  while IFS=$'\t' read -r name quadrant ring why _path; do
    [ -n "$name" ] || continue
    printf '| %s | %s | %s | %s |\n' "$name" "$quadrant" "$ring" "$why"
  done < "$RESULTS_FILE"
  echo ""
  echo "**Radar Guidance**"
  print_guidance
  echo ""
fi

if [ "$DATA_UNAVAILABLE" = true ]; then
  printf '_Source: Tikal Israeli Tech Radar — radar unavailable (knowledge repository and %s both unreachable) · 0 technologies matched._\n' "$FALLBACK_URL"
elif [ "$COUNT" -eq 0 ]; then
  printf '_Source: Tikal Israeli Tech Radar — %s · 0 technologies matched._\n' "$(source_label)"
elif [ "$MODE" = "fallback" ]; then
  printf '_Source: Tikal Israeli Tech Radar — %s · %s blip placement(s) matched._\n' "$(source_label)" "$COUNT"
else
  printf '_Source: Tikal Israeli Tech Radar — %s · %s documents scanned, %s placement(s) matched._\n' "$(source_label)" "${DOC_COUNT:-0}" "$COUNT"
fi
