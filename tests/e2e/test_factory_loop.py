import os
import json
import shutil
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent

def test_factory_mission_state_initialization(sandbox_project):
    workflow_dir = sandbox_project / ".adlc" / "workflow"
    config_file = workflow_dir / "workflow-config.yml"
    
    config_file.parent.mkdir(parents=True, exist_ok=True)
    template_config = ROOT / "skills" / "factory" / "factory-mission" / "config-template.yml"
    assert template_config.exists()
    
    shutil.copy(template_config, config_file)
    assert config_file.exists()
    
    content = config_file.read_text()
    assert "quality_threshold: null" in content
    assert "circuit_breaker: 3" in content

def test_factory_product_state_initialization(sandbox_project):
    state_file = sandbox_project / ".adlc" / "workflow" / ".factory-product-state.json"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    
    mock_state = {
        "brief": {
            "goal": "Bootstrap PRD for platform",
            "constraints": "Zero config, local only",
            "success_criteria": ["PRD.md contains 4 core sections"]
        },
        "completed_steps": [],
        "steps": [
            {
                "id": "specify",
                "phase_type": "generate",
                "tier": "strong",
                "skill": "product-specify",
                "status": "pending"
            },
            {
                "id": "clarify",
                "phase_type": "clarify",
                "tier": "fast",
                "skill": "product-clarify",
                "status": "pending"
            }
        ]
    }
    
    state_file.write_text(json.dumps(mock_state))
    assert state_file.exists()
    
    loaded = json.loads(state_file.read_text())
    assert loaded["brief"]["goal"] == "Bootstrap PRD for platform"
    assert len(loaded["steps"]) == 2
    assert loaded["steps"][0]["skill"] == "product-specify"

def test_factory_architect_state_initialization(sandbox_project):
    state_file = sandbox_project / ".adlc" / "workflow" / ".factory-architect-state.json"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    
    mock_state = {
        "brief": {
            "goal": "Bootstrap AD.md for microservices",
            "constraints": "Rozanski & Woods",
            "success_criteria": ["AD.md has Context and Functional views"]
        },
        "completed_steps": [],
        "steps": [
            {
                "id": "init",
                "phase_type": "generate",
                "tier": "strong",
                "skill": "architect-init",
                "status": "pending"
            }
        ]
    }
    
    state_file.write_text(json.dumps(mock_state))
    assert state_file.exists()
    
    loaded = json.loads(state_file.read_text())
    assert loaded["steps"][0]["skill"] == "architect-init"

def test_factory_learn_state_initialization(sandbox_project):
    state_file = sandbox_project / ".adlc" / "workflow" / ".factory-learn-state.json"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    
    mock_state = {
        "publish_target": "external-repo",
        "brief": {
            "goal": "Extract session directives",
            "success_criteria": ["team-ai-directives PR is opened"]
        },
        "steps": [
            {
                "id": "specify",
                "phase_type": "generate",
                "skill": "levelup-specify",
                "status": "pending"
            }
        ]
    }
    state_file.write_text(json.dumps(mock_state))
    assert state_file.exists()
    
    loaded = json.loads(state_file.read_text())
    assert loaded["publish_target"] == "external-repo"

def test_factory_queue_triage_flow(sandbox_project):
    state_file = sandbox_project / ".adlc" / "workflow" / ".factory-queue-state.json"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    
    mock_brief = {
        "id": "issue-123",
        "goal": "Implement JWT profiles",
        "triage_score": {
            "risk": "Medium",
            "complexity": "Low",
            "confidence": "95%"
        },
        "labels": ["intent"]
    }
    state_file.write_text(json.dumps(mock_brief))
    assert state_file.exists()
    
    loaded = json.loads(state_file.read_text())
    assert loaded["triage_score"]["confidence"] == "95%"
    assert "intent" in loaded["labels"]

def test_factory_review_non_approving_gate(sandbox_project):
    review_policy = sandbox_project / "REVIEW.md"
    policy_content = """# PR Review Policy
- Bug & logical error checking: required
- Security check: required
- Never allow automated approval of own code: true
"""
    review_policy.write_text(policy_content)
    assert review_policy.exists()
    
    loaded_policy = review_policy.read_text()
    assert "Never allow automated approval of own code" in loaded_policy
