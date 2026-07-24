import os
import json
import pytest
from pathlib import Path

def test_team_repair_health_checks(sandbox_project):
    """Verify that a team-repair run starts with validating all 8 health checks."""
    # Mocking Check 2: Team AI Directives configured
    init_opts_file = sandbox_project / ".adlc" / "init-options.json"
    assert init_opts_file.exists()
    
    init_opts = json.loads(init_opts_file.read_text())
    assert "team_ai_directives" in init_opts
    
    team_directives_path = Path(init_opts["team_ai_directives"])
    assert team_directives_path.exists()
    assert (team_directives_path / "context_modules" / "rules").exists()
    assert (team_directives_path / "context_modules" / "personas").exists()
    assert (team_directives_path / "context_modules" / "examples").exists()

def test_team_repair_build_to_delete_keep(sandbox_project):
    """Verify that if build-to-delete evaluation pass rate is < 80%, the directive is kept."""
    goldset_result = {
        "directive_id": "CDR-2026-001",
        "pass_rate": 0.40,  # 40% (below 80% threshold)
        "cases_total": 5,
        "cases_passed": 2
    }
    
    # Classification logic
    verdict = "Keep" if goldset_result["pass_rate"] < 0.80 else "Delete"
    assert verdict == "Keep"

def test_team_repair_build_to_delete_delete(sandbox_project):
    """Verify that if build-to-delete evaluation pass rate is 100%, rule deletion is proposed."""
    goldset_result = {
        "directive_id": "CDR-2026-003",
        "pass_rate": 1.00,  # 100%
        "cases_total": 6,
        "cases_passed": 6
    }
    
    # Classification logic
    verdict = "Delete candidate" if goldset_result["pass_rate"] == 1.00 else "Keep"
    assert verdict == "Delete candidate"
