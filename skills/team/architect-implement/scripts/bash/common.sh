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

# Emulates the get_feature_paths function from the Spec Kit common.sh.
# The architect setup script evals this output to obtain REPO_ROOT.
get_feature_paths() {
    local repo_root
    repo_root="$(_get_project_root)"
    _seed_templates "$repo_root"
    echo "REPO_ROOT=\"$repo_root\""
}
