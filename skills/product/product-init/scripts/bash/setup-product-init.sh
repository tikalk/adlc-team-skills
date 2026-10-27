#!/bin/bash
# product-init setup script
# Self-contained — resolves paths, detects feature areas, finds next PDR number

set -euo pipefail

JSON_MODE=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/../../../product-clarify/scripts/bash/pdr-lib.sh" 2>/dev/null || true
# Fail fast when the canonical helper is absent (selective install without
# product-clarify) instead of dying later on a missing function.
command -v generate_pdr_index >/dev/null 2>&1 || { echo "ERROR: pdr-lib.sh not loaded — install the product-clarify skill: adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify" >&2; return 1 2>/dev/null || exit 1; }

# shared layout constants (single definition in paths.sh; pdr-lib.sh
# sources it too — this block keeps the script correct standalone).
_pd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_pd_dir/../../../../team/workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_pd_dir/../../../../team/workspace/scripts/bash/paths.sh"
elif [ -f "$_pd_dir/../../../workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_pd_dir/../../../workspace/scripts/bash/paths.sh"
fi
REPO_ROOT="${REPO_ROOT:-$(_get_project_root)}"
PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
PRD_FILE="$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}/PRD.md"

mkdir -p "$PDR_DRAFTS_DIR"
mkdir -p "$REPO_ROOT/.adlc/product"

# Detect feature areas from codebase structure
detect_feature_areas() {
  local areas=()
  local dir="$REPO_ROOT"

  # Check common directory patterns
  for pattern in src features modules apps packages; do
    if [[ -d "$dir/$pattern" ]]; then
      for sub in "$dir/$pattern"/*/; do
        if [[ -d "$sub" ]]; then
          local name
          name=$(basename "$sub")
          # Skip utility dirs
          if [[ "$name" != "utils" && "$name" != "common" && "$name" != "lib" && "$name" != "shared" && "$name" != "core" && "$name" != "test" && "$name" != "tests" && "$name" != "__tests__" ]]; then
            areas+=("$name")
          fi
        fi
      done
    fi
  done

  # Docker compose services
  for compose in "$dir/docker-compose.yml" "$dir/docker-compose.yaml"; do
    if [[ -f "$compose" ]]; then
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
          local svc="${BASH_REMATCH[1]}"
          if [[ "$svc" != "version" && "$svc" != "services" && "$svc" != "networks" && "$svc" != "volumes" ]]; then
            areas+=("$svc")
          fi
        fi
      done < "$compose"
    fi
  done

  # Deduplicate
  local unique=()
  for a in "${areas[@]}"; do
    local found=false
    for u in "${unique[@]}"; do
      if [[ "$u" == "$a" ]]; then found=true; break; fi
    done
    if [[ "$found" == "false" ]]; then unique+=("$a"); fi
  done

  if [[ ${#unique[@]} -eq 0 ]]; then
    echo "Product"
  else
    printf '%s\n' "${unique[@]}"
  fi
}

# Ledger slot allocation lives in pdr-lib.sh (next_record_number): leading
# digits of the filename stem, max across drafts AND published memory. This
# script previously carried its own copy, which silently skipped stemmed
# records (PDR-002-amendment-2.md) and scanned drafts alone.
FEATURE_AREAS=$(detect_feature_areas)
NEXT_PDR=$(next_record_number PDR "$PDR_DRAFTS_DIR" \
  "$REPO_ROOT/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/pdr")

# Build feature_areas in Python (bash string-concat cannot escape quotes safely).
# Pass the newline-separated area list; Python builds id/name pairs with json.dumps.
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)

if $JSON_MODE; then
  python3 - "$REPO_ROOT" "$PDR_DRAFTS_DIR" "$PRD_FILE" "$NEXT_PDR" "$PDR_COUNT" "$FEATURE_AREAS" <<'PY'
import json, sys, re
repo_root, drafts_dir, prd_file, next_pdr, pdr_count, areas_raw = sys.argv[1:7]
areas = []
for area in areas_raw.splitlines():
    area = area.strip()
    if not area:
        continue
    slug = re.sub(r'\s+', '-', area.strip().lower())
    areas.append({"id": slug, "name": area})
print(json.dumps({
  "REPO_ROOT": repo_root,
  "PDR_DRAFTS_DIR": drafts_dir,
  "PRD_FILE": prd_file,
  "feature_areas": areas,
  "next_pdr": next_pdr,
  "pdr_count": int(pdr_count)
}))
PY
else
  echo "[INFO] product-init setup"
  echo "  REPO_ROOT: $REPO_ROOT"
  echo "  PDR_DRAFTS_DIR: $PDR_DRAFTS_DIR"
  echo "  Next PDR: PDR-$NEXT_PDR"
  echo "  Feature areas:"
  while IFS= read -r area; do
    echo "    - $area"
  done <<< "$FEATURE_AREAS"
fi
