import os
import re
from pathlib import Path
import pytest

# Robust workspace root resolution
def get_workspace_root():
    # The submodule lives at <workspace>/adlc-team-skills
    # Path(__file__) is <workspace>/adlc-team-skills/tests/unit/test_slug_migration_map.py
    # .parent.parent.parent.parent is <workspace>
    root = Path(__file__).parent.parent.parent.parent
    # Assert that this dir contains docs/adlc
    if (root / "docs/adlc").is_dir():
        return root
    return None

WORKSPACE_ROOT = get_workspace_root()

@pytest.mark.skipif(WORKSPACE_ROOT is None, reason="Workspace root not found (missing docs/adlc)")
class TestSlugMigrationMap:
    def test_no_numeric_filenames_remain(self):
        """Assert no purely numeric or numeric-prefixed index IDs remain."""
        # Match FAMILY followed by ONLY digits, or digits then -amendment, or digits then -stem where stem is short/numeric
        # Migrated slugs like ADR-30-day... are valid.
        patterns = [
            re.compile(r"^(ADR|PDR|ChDR|CDR)-[0-9]+(-amendment(-[0-9]+)?)?\.md$"),
            re.compile(r"^(ADR|PDR|ChDR|CDR)-[0-9]{3}-.*\.md$"), # Legacy 3-digit prefix
        ]
        
        search_paths = [
            WORKSPACE_ROOT / "docs/adlc/memory",
            WORKSPACE_ROOT / ".adlc/memory",
            WORKSPACE_ROOT / ".adlc/drafts",
        ]
        
        found_numeric_files = []
        for search_path in search_paths:
            if not search_path.exists():
                continue
            for p in search_path.rglob("*.md"):
                if any(pat.match(p.name) for pat in patterns):
                    found_numeric_files.append(str(p.relative_to(WORKSPACE_ROOT)))
        
        assert not found_numeric_files, f"Numeric filenames still present: {found_numeric_files}"

    def test_migration_map_targets_exist(self):
        """Assert every MIGRATION.md map row target exists."""
        migration_md = WORKSPACE_ROOT / "docs/adlc/memory/MIGRATION.md"
        assert migration_md.exists(), "MIGRATION.md not found"
        
        content = migration_md.read_text(encoding="utf-8")
        # Assuming table format: | Family | Old Path | New Path |
        lines = content.splitlines()
        
        rows_checked = 0
        for line in lines:
            if "|" not in line or line.strip().startswith("|-"):
                continue
            parts = [p.strip() for p in line.split("|") if p.strip()]
            if len(parts) < 3:
                continue
            
            # Skip header
            if parts[0].lower() == "family":
                continue
                
            new_path_str = parts[2]
            # Strip backticks if present
            new_path_str = new_path_str.strip("`")
            
            # Check if new_path_str looks like a path
            if "/" not in new_path_str and not new_path_str.endswith(".md"):
                continue
            
            new_path = WORKSPACE_ROOT / new_path_str
            assert new_path.exists(), f"Migration target {new_path_str} does not exist"
            rows_checked += 1
            
        assert rows_checked > 0, "No migration map rows found in MIGRATION.md"
