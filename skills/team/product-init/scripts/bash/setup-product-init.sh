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

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PDR_DRAFTS_DIR="$REPO_ROOT/.adlc/drafts/pdr"
PRD_FILE="$REPO_ROOT/PRD.md"

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

# Find next PDR number
next_pdr_number() {
  local max=0
  if [[ -d "$PDR_DRAFTS_DIR" ]]; then
    for f in "$PDR_DRAFTS_DIR"/PDR-*.md; do
      if [[ -f "$f" ]]; then
        local num
        num=$(basename "$f" | sed 's/PDR-//' | sed 's/\.md//')
        if [[ "$num" =~ ^[0-9]+$ ]]; then
          ((10#$num > max)) && max=$((10#$num))
        fi
      fi
    done
  fi
  printf '%03d' $((max + 1))
}

FEATURE_AREAS=$(detect_feature_areas)
NEXT_PDR=$(next_pdr_number)

# Build feature_areas JSON array
FEATURE_AREAS_JSON="["
first=true
while IFS= read -r area; do
  if [[ "$first" == "true" ]]; then
    first=false
  else
    FEATURE_AREAS_JSON+=","
  fi
  local id
  id=$(echo "$area" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  FEATURE_AREAS_JSON+="{\"id\":\"$id\",\"name\":\"$area\"}"
done <<< "$FEATURE_AREAS"
FEATURE_AREAS_JSON+="]"

if $JSON_MODE; then
  cat <<EOF
{
  "REPO_ROOT": "$REPO_ROOT",
  "PDR_DRAFTS_DIR": "$PDR_DRAFTS_DIR",
  "PRD_FILE": "$PRD_FILE",
  "feature_areas": $FEATURE_AREAS_JSON,
  "next_pdr": "$NEXT_PDR",
  "pdr_count": $(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
}
EOF
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
