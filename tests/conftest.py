import os
import sys
import json
import shutil
import subprocess
from pathlib import Path
import pytest

def _has_working_bash() -> bool:
    """Check whether a functional native MSYS/MINGW Bash (or Linux bash) is available.
    On Windows, skips WSL bash since it cannot handle native paths used by fixtures."""
    if shutil.which("bash") is None:
        return False
    try:
        r = subprocess.run(
            ["bash", "-c", "echo ok"],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode != 0 or "ok" not in r.stdout:
            return False
    except (OSError, subprocess.TimeoutExpired):
        return False
    if sys.platform == "win32":
        try:
            u = subprocess.run(
                ["bash", "-c", "uname -s"],
                capture_output=True, text=True, timeout=5,
            )
            kernel = u.stdout.strip().upper()
            if not any(k in kernel for k in ("MSYS", "MINGW", "CYGWIN")):
                return False
        except (OSError, subprocess.TimeoutExpired):
            return False
    return True

def pytest_configure(config):
    config.addinivalue_line("markers", "requires_bash: skip if native bash not available")

def pytest_runtest_setup(item):
    if "requires_bash" in item.keywords and not _has_working_bash():
        pytest.skip("working native bash not available")

@pytest.fixture(autouse=True)
def _strip_team_directives_env(monkeypatch):
    """Ensure no test reads inherited local or CI TEAM_AI_DIRECTIVES environment variables."""
    monkeypatch.delenv("TEAM_AI_DIRECTIVES", raising=False)

@pytest.fixture
def sandbox_project(tmp_path):
    """Sets up a mock sandbox project directory mimicking the ADLC environment."""
    project_root = tmp_path / "target-project"
    project_root.mkdir()
    
    # Create .adlc and drafts directories
    adlc_dir = project_root / ".adlc"
    adlc_dir.mkdir()
    (adlc_dir / "drafts" / "cdr").mkdir(parents=True)
    (adlc_dir / "drafts" / "skills").mkdir(parents=True)
    (adlc_dir / "workflow" / "runs").mkdir(parents=True)
    
    # Initialize Git repository
    subprocess.run(["git", "init"], cwd=project_root, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=project_root, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=project_root, capture_output=True, check=True)
    
    # Create initial commit to establish HEAD and main branch
    (project_root / "README.md").write_text("# Sandbox Project\n")
    subprocess.run(["git", "add", "README.md"], cwd=project_root, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-m", "Initial commit"], cwd=project_root, capture_output=True, check=True)
    
    # Create mock team-ai-directives
    team_directives = tmp_path / "team-ai-directives"
    team_directives.mkdir()
    (team_directives / "context_modules" / "rules").mkdir(parents=True)
    (team_directives / "context_modules" / "personas").mkdir(parents=True)
    (team_directives / "context_modules" / "examples").mkdir(parents=True)
    (team_directives / "skills").mkdir(parents=True)
    (team_directives / "evals").mkdir(parents=True)
    
    # Write default indexes
    (team_directives / "CDR.md").write_text("# Context Directive Records\n\n## CDR Index\n")
    (team_directives / ".skills.json").write_text(json.dumps({"skills": {}}))
    (team_directives / "AGENTS.md").write_text("# Agent Instructions\n")
    
    # Write init-options.json
    init_options = adlc_dir / "init-options.json"
    init_options.write_text(json.dumps({
        "team_ai_directives": str(team_directives)
    }))
    
    # Mock environment variables
    os.environ["TEAM_AI_DIRECTIVES"] = str(team_directives)
    
    yield project_root
    
    # Clean up environment variable
    if "TEAM_AI_DIRECTIVES" in os.environ:
        del os.environ["TEAM_AI_DIRECTIVES"]
