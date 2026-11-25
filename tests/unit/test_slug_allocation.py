import os
import subprocess
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent
ARCH_SETUP = ROOT / "skills/architect/architect-clarify/scripts/bash/setup-architect.sh"
PDR_LIB = ROOT / "skills/product/product-clarify/scripts/bash/pdr-lib.sh"

def _run_bash(command, cwd=None, env_extra=None, source_pdr=False):
    env = {**os.environ}
    if env_extra:
        env.update(env_extra)
    # Ensure we use the function from the script, not a system command
    if source_pdr:
        full_command = f"source {PDR_LIB}; {command}"
    else:
        full_command = f"source {ARCH_SETUP}; {command}"
    return subprocess.run(["bash", "-e", "-c", full_command], cwd=cwd, capture_output=True, text=True, env=env)

def _write_fm(path: Path, title: str = "T"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"---\nstatus: accepted\ndate: 2026-11-24\n---\n\n# {title}\n",
        encoding="utf-8",
    )

@pytest.fixture()
def tree(tmp_path):
    """Base directory for testing slug allocation."""
    return tmp_path

def test_slugify_is_defined_as_function():
    r = _run_bash("declare -f slugify")
    assert r.returncode == 0, f"slugify function not found in {ARCH_SETUP}"

def test_slugify_canonical_rules():
    """Test the slugify rule implemented in bash.
    
    Rules: lowercase, non-alnum -> -, collapse -, trim -, max 60, ascii-fold.
    """
    r = _run_bash('slugify "Agent-Agnostic Process Engine!"')
    
    assert r.returncode == 0, f"Expected success but got {r.returncode}. Stderr: {r.stderr}"
    assert r.stdout.strip() == "agent-agnostic-process-engine"

def test_slugify_unicode_folding():
    r = _run_bash('slugify "Café"')
    assert r.stdout.strip() == "cafe"

def test_slugify_truncation():
    long_title = "a" * 70
    r = _run_bash(f'slugify "{long_title}"')
    assert len(r.stdout.strip()) == 60

def test_slugify_empty_rejected():
    r = _run_bash('slugify "!!!"')
    assert r.returncode != 0

def test_mint_adr_slug_collision(tree):
    """Test that mint_adr_slug handles collisions by appending -2, -3."""
    # This is expected to fail because mint_adr_slug is not yet implemented.
    _write_fm(tree / "docs/adlc/memory/adr/ADR-my-decision.md", "My Decision")

    r = _run_bash(f'mint_adr_slug "My Decision" "{tree}"', cwd=tree)

    assert r.returncode == 0
    assert r.stdout.strip() == "my-decision-2"

def test_no_numeric_fallback(tree):
    """Test that numeric fallback is removed from get_adr_by_id."""
    # Create a record with a numeric prefix (legacy)
    legacy_path = tree / "docs/adlc/memory/adr/ADR-008.md"
    _write_fm(legacy_path, "Legacy Decision")

    # Try to lookup by bare number '8' - should FAIL now (no 008 padding)
    r = _run_bash(f'get_adr_by_id "8" "memory"', cwd=tree)
    assert r.returncode != 0

def test_mint_adr_slug_collision_suffix(tree):
    """Test that mint_adr_slug handles existing -2 by appending -3."""
    _write_fm(tree / "docs/adlc/memory/adr/ADR-my-decision.md", "My Decision")
    _write_fm(tree / "docs/adlc/memory/adr/ADR-my-decision-2.md", "My Decision 2")

    r = _run_bash(f'mint_adr_slug "My Decision" "{tree}"', cwd=tree)
    assert r.returncode == 0
    assert r.stdout.strip() == "my-decision-3"

def test_mint_pdr_slug_collision(tree):
    """Test that mint_pdr_slug handles collisions by appending -2, -3."""
    _write_fm(tree / "docs/adlc/memory/pdr/PDR-my-feature.md", "My Feature")

    r = _run_bash(f'mint_pdr_slug "My Feature" "{tree}"', cwd=tree, source_pdr=True)

    assert r.returncode == 0
    assert r.stdout.strip() == "my-feature-2"

def test_product_setup_no_local_numbering(tree):
    """Test that setup-product-specify.sh uses mint_pdr_slug and has no local next_record_number."""
    setup_script = ROOT / "skills/product/product-specify/scripts/bash/setup-product-specify.sh"
    content = setup_script.read_text()
    
    # Assert local next_record_number is gone
    assert "next_record_number() {" not in content
    
    # Assert it calls mint_pdr_slug (or uses a variable that implies it was called, 
    # but the task says "call new helper")
    # Actually, the task says "delete next_pdr_number locals" and "call new helper".
    # We'll check for 'mint_pdr_slug' in the script if it's supposed to be called there.
    # Looking at setup-architect.sh, it doesn't call mint_adr_slug directly in the setup, 
    # but the task says "call new helper".
    assert "mint_pdr_slug" in content
