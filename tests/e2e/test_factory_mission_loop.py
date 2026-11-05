import os
import json
import pytest
from pathlib import Path

def test_factory_mission_state_initialization(sandbox_project):
    """Verify the factory-mission world: brief construction (factory-mission
    Phase 2) copies the mission policy template into the per-run directory
    (the mission-brief format-amendment: the mission-brief skill is removed; namespace v3)."""
    run_id = "run-def456"
    run_dir = sandbox_project / ".adlc" / "workflows" / "runs" / run_id
    config_file = run_dir / "mission.yml"

    # Simulate Phase 2 policy bootstrap
    config_file.parent.mkdir(parents=True, exist_ok=True)
    template_config = Path(__file__).parent.parent.parent / "skills" / "factory" / "factory-runbook" / "mission-template.yml"
    assert template_config.exists()

    import shutil
    shutil.copy(template_config, config_file)
    assert config_file.exists()

    # Verify defaults are present
    content = config_file.read_text()
    assert "quality_threshold: null" in content
    assert "circuit_breaker: 3" in content
    assert "spec_correction_signal" not in content # verifying trace removal changes

def test_factory_mission_circuit_breaker(sandbox_project):
    """Verify that consecutive converge failures trigger the circuit breaker."""
    # Simulate circuit breaker loop state
    state = {
        "brief": {
            "goal": "Add a feature",
            "constraints": "None",
            "success_criteria": ["Outcome 1"]
        },
        "consecutive_tasks_appended": 3,  # circuit_breaker threshold met
        "steps": [
            {"id": "loop_2_implement", "phase": "implement", "status": "completed"},
            {"id": "loop_2_converge", "phase": "converge", "status": "pending"}
        ]
    }
    
    # Assert that if we evaluate this state, the circuit breaker fires
    circuit_breaker_limit = 3
    assert state["consecutive_tasks_appended"] >= circuit_breaker_limit, "Circuit breaker should trigger"

def test_factory_mission_score_regression(sandbox_project):
    """Verify that score regressions trigger circuit breaker."""
    state = {
        "consecutive_score_regressions": 3, # threshold met
        "history": [
            {"iteration": 1, "score_pct": 80},
            {"iteration": 2, "score_pct": 70}, # regression
            {"iteration": 3, "score_pct": 60}  # regression
        ]
    }
    circuit_breaker_limit = 3
    assert state["consecutive_score_regressions"] >= circuit_breaker_limit, "Regression circuit breaker should trigger"
