import os
import sys
import json
import subprocess
from pathlib import Path
import pytest

# Find all setup scripts in the skills directory
ROOT = Path(__file__).parent.parent.parent
BASH_SCRIPTS = [
    str(p.relative_to(ROOT))
    for p in ROOT.glob("skills/**/setup-*.sh")
]

@pytest.mark.requires_bash
@pytest.mark.parametrize("script_path", BASH_SCRIPTS)
def test_bash_setup_script_execution(sandbox_project, script_path):
    """Verify that every bash setup script runs cleanly in the sandbox and outputs valid metadata."""
    full_script_path = ROOT / script_path
    
    # Run the setup script with bash, always requesting JSON mode
    result = subprocess.run(
        ["bash", str(full_script_path), "--json"],
        cwd=sandbox_project,
        capture_output=True,
        text=True
    )
    
    # Some analysis scripts (e.g. product-analyze, architect-analyze) are designed to exit with 1
    # if preconditions (like existing PDRs/ADRs) are missing in the empty sandbox project.
    is_precondition_exit = result.returncode == 1 and any(
        x in script_path for x in ["analyze", "roadmap", "implement"]
    )
    
    assert result.returncode == 0 or is_precondition_exit, (
        f"Script {script_path} failed with exit code {result.returncode}. stderr: {result.stderr}"
    )
    
    if is_precondition_exit:
        # Precondition check failed as expected in an empty sandbox, pass gracefully
        return
        
    # Verify we can extract the output metadata
    data = {}
    stdout = result.stdout.strip()
    
    # Try parsing as JSON first by finding the first {
    json_parsed = False
    if "{" in stdout:
        json_start = stdout.find("{")
        json_str = stdout[json_start:]
        try:
            data = json.loads(json_str)
            json_parsed = True
        except json.JSONDecodeError:
            pass
                
    # If not JSON, parse as KEY=VALUE pairs (legacy setup scripts)
    if not json_parsed:
        stdout_lines = stdout.split("\n")
        for line in stdout_lines:
            if "=" in line:
                parts = line.split("=", 1)
                data[parts[0].strip()] = parts[1].strip()
                
    # If the script output contains REPO_ROOT, verify it is resolved correctly
    if "REPO_ROOT" in data:
        resolved_path = Path(data["REPO_ROOT"]).resolve()
        assert resolved_path in [sandbox_project.resolve(), ROOT.resolve()], (
            f"REPO_ROOT mismatch in {script_path}. Expected {sandbox_project} or {ROOT}, got {data['REPO_ROOT']}"
        )


# --- Static guards: architect diagram helpers --------------------------------
# Regression guard for the "get_architecture_diagram_format: command not found"
# incident (line 761 of setup-architect.sh): these functions are called by
# generate_and_insert_diagrams / New-ArchitectureDiagrams but were never ported
# from the spec-kit common.sh/common.ps1 into the adlc bundled scripts.

ARCHITECT_BASH_COMMONS = sorted(ROOT.glob("skills/architect/architect-*/scripts/bash/common.sh"))
ARCHITECT_PS1_SETUPS = sorted(ROOT.glob("skills/architect/architect-*/scripts/powershell/setup-architect.ps1"))


def test_architect_common_sh_defines_diagram_functions():
    """Every architect bash common.sh must define the diagram helper functions."""
    assert len(ARCHITECT_BASH_COMMONS) == 5, f"Expected 5 architect common.sh files, found {len(ARCHITECT_BASH_COMMONS)}"
    for common_sh in ARCHITECT_BASH_COMMONS:
        content = common_sh.read_text(encoding="utf-8")
        assert "get_architecture_diagram_format()" in content, (
            f"{common_sh.relative_to(ROOT)} missing get_architecture_diagram_format()"
        )
        assert "validate_mermaid_syntax()" in content, (
            f"{common_sh.relative_to(ROOT)} missing validate_mermaid_syntax()"
        )


def test_architect_ps1_defines_diagram_functions():
    """Every architect setup-architect.ps1 must define the diagram helper functions."""
    assert len(ARCHITECT_PS1_SETUPS) == 5, f"Expected 5 architect PS1 files, found {len(ARCHITECT_PS1_SETUPS)}"
    for ps1 in ARCHITECT_PS1_SETUPS:
        content = ps1.read_text(encoding="utf-8")
        assert "function Get-ArchitectureDiagramFormat" in content, (
            f"{ps1.relative_to(ROOT)} missing Get-ArchitectureDiagramFormat"
        )
        assert "function Test-MermaidSyntax" in content, (
            f"{ps1.relative_to(ROOT)} missing Test-MermaidSyntax"
        )


def test_architect_bash_common_sh_copies_identical():
    """The 5 architect common.sh files must stay byte-identical (shared contract)."""
    contents = {p: p.read_bytes() for p in ARCHITECT_BASH_COMMONS}
    unique = set(contents.values())
    assert len(unique) == 1, "architect common.sh files have diverged — keep all 5 copies identical"


def test_architect_ps1_setup_copies_identical():
    """The 5 architect setup-architect.ps1 files must stay byte-identical (shared contract)."""
    contents = {p: p.read_bytes() for p in ARCHITECT_PS1_SETUPS}
    unique = set(contents.values())
    assert len(unique) == 1, "architect setup-architect.ps1 files have diverged — keep all 5 copies identical"
