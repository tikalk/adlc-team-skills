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
                
    # For scripts that don't output TEAM_AI_DIRECTIVES (like product-* and architect-*),
    # we don't require the TEAM_AI_DIRECTIVES key in the JSON output.
    assert "REPO_ROOT" in data, f"Missing REPO_ROOT in {script_path} output. Output was: {result.stdout}"
