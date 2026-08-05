#!/usr/bin/env bash
#
# Minimal common helpers for adlc-skills architect-* skills.
# Bundled with the skill so it works standalone, outside the Spec Kit extension system.

# Locate the project root by walking up from CWD until we find .adlc or .git.
_get_project_root() {
    local dir
    dir="$(pwd)"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.adlc" ] || [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # Fallback: current working directory.
    echo "$(pwd)"
}

# Seed bundled templates into the project's .adlc/templates/ directory.
# Only copies files when the destination does not exist, so user customizations are preserved.
_seed_templates() {
    local repo_root="${1:-$(_get_project_root)}"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local src_dir="$script_dir/../../templates"
    local dest_dir="$repo_root/.adlc/templates"

    [ -d "$src_dir" ] || return 0

    mkdir -p "$dest_dir"

    local f basename
    for f in "$src_dir"/*; do
        [ -e "$f" ] || continue
        basename=$(basename "$f")
        if [ -d "$f" ]; then
            if [ ! -d "$dest_dir/$basename" ]; then
                cp -r "$f" "$dest_dir/$basename"
            fi
        else
            if [ ! -f "$dest_dir/$basename" ]; then
                cp "$f" "$dest_dir/$basename"
            fi
        fi
    done
}

# Resolve external SDD docs location.
# Priority: SDD_DOCS_LOCATION env var > .adlc/init-options.json > empty (use repo root).
resolve_sdd_docs_location() {
  local project_root="$1"
  local loc="${SDD_DOCS_LOCATION:-}"
  [[ -n "$loc" ]] && { echo "$loc"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    loc=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('sdd_docs_location', ''))
except Exception:
    print('')
" 2>/dev/null || true)
  fi
  echo "$loc"
}

# Derive a stable subfolder name for the current project inside SDD_DOCS_LOCATION.
# Uses the worktree root base name when inside a git worktree, otherwise the repo root base name.
sdd_project_subfolder_name() {
  local project_root="$1"
  local common_dir
  common_dir=$(git -C "$project_root" rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$common_dir" ]]; then
    basename "$(cd "$(dirname "$common_dir")" && pwd)"
  else
    basename "$project_root"
  fi
}

# Emulates the get_feature_paths function from the Spec Kit common.sh.
# The architect setup script evals this output to obtain REPO_ROOT.
get_feature_paths() {
    local repo_root
    repo_root="$(_get_project_root)"
    _seed_templates "$repo_root"
    local sdd_docs_location
    sdd_docs_location=$(resolve_sdd_docs_location "$repo_root")
    local sdd_root
    if [[ -n "$sdd_docs_location" ]]; then
        sdd_root="${sdd_docs_location}/$(sdd_project_subfolder_name "$repo_root")"
    else
        sdd_root="$repo_root"
    fi
    echo "REPO_ROOT=\"$repo_root\""
    echo "SDD_DOCS_LOCATION=\"$sdd_docs_location\""
    echo "SDD_ROOT=\"$sdd_root\""
}
