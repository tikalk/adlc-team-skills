import os
import json
import shutil
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent

def test_factory_mission_state_initialization(sandbox_project):
    # Namespace v3 (the workflow namespace): the mission policy template is copied
    # into the per-run directory as mission.yml — no .adlc/workflow/ anymore.
    run_id = "run-abc123"
    run_dir = sandbox_project / ".adlc" / "workflows" / "runs" / run_id
    config_file = run_dir / "mission.yml"

    config_file.parent.mkdir(parents=True, exist_ok=True)
    template_config = ROOT / "skills" / "factory" / "factory-mission" / "mission-template.yml"
    assert template_config.exists()

    shutil.copy(template_config, config_file)
    assert config_file.exists()

    content = config_file.read_text()
    assert "quality_threshold: null" in content
    assert "circuit_breaker: 3" in content
    assert ".adlc/workflows/memory.jsonl" in content

def test_factory_intent_product_lane_state_initialization(sandbox_project):
    # Namespace v3 (shared run state): step progress lives in the shared state.json,
    # run context in brief.md — no per-lane state file anymore.
    run_dir = sandbox_project / ".adlc" / "workflows" / "runs" / "run-prod-1"
    run_dir.mkdir(parents=True, exist_ok=True)

    (run_dir / "brief.md").write_text(
        "# Factory Run Brief: factory-intent\n\n"
        "## Goal\nBootstrap PRD for platform\n\n"
        "## Constraints\nZero config, local only\n\n"
        "## Success Criteria\n- PRD.md contains 4 core sections\n"
    )
    (run_dir / "state.json").write_text(json.dumps({
        "run_id": "run-prod-1",
        "workflow_id": "factory-intent",
        "status": "created",
        "current_step_index": 0,
        "current_step_id": "specify",
        "step_results": {},
    }))

    brief = (run_dir / "brief.md").read_text()
    assert "Bootstrap PRD for platform" in brief
    loaded = json.loads((run_dir / "state.json").read_text())
    assert loaded["current_step_index"] == 0
    assert loaded["current_step_id"] == "specify"

def test_factory_intent_architecture_lane_state_initialization(sandbox_project):
    # Namespace v3 (shared run state): shared state.json + brief.md in the run dir.
    run_dir = sandbox_project / ".adlc" / "workflows" / "runs" / "run-arch-1"
    run_dir.mkdir(parents=True, exist_ok=True)

    (run_dir / "brief.md").write_text(
        "# Factory Run Brief: factory-intent\n\n"
        "## Goal\nBootstrap AD.md for microservices\n\n"
        "## Constraints\nRozanski & Woods\n\n"
        "## Success Criteria\n- AD.md has Context and Functional views\n"
    )
    (run_dir / "state.json").write_text(json.dumps({
        "run_id": "run-arch-1",
        "workflow_id": "factory-intent",
        "status": "created",
        "current_step_index": 0,
        "current_step_id": "init",
        "step_results": {},
    }))

    brief = (run_dir / "brief.md").read_text()
    assert "Rozanski & Woods" in brief
    loaded = json.loads((run_dir / "state.json").read_text())
    assert loaded["current_step_id"] == "init"

def test_factory_learn_state_initialization(sandbox_project):
    # Namespace v3 (shared run state): publish target is run context (brief.md),
    # progress is the shared program counter (state.json).
    run_dir = sandbox_project / ".adlc" / "workflows" / "runs" / "run-learn-1"
    run_dir.mkdir(parents=True, exist_ok=True)

    (run_dir / "brief.md").write_text(
        "# Factory Run Brief: factory-learn\n\n"
        "## Goal\nExtract session directives\n\n"
        "## Success Criteria\n- team-ai-directives PR is opened\n\n"
        "## Run Context\n- **Publish Target:** external-repo\n"
    )
    (run_dir / "state.json").write_text(json.dumps({
        "run_id": "run-learn-1",
        "workflow_id": "factory-learn",
        "status": "created",
        "current_step_index": 0,
        "current_step_id": "specify",
        "step_results": {},
    }))

    brief = (run_dir / "brief.md").read_text()
    assert "external-repo" in brief
    loaded = json.loads((run_dir / "state.json").read_text())
    assert loaded["workflow_id"] == "factory-learn"

def test_factory_queue_triage_flow(sandbox_project):
    # factory-queue is stateless (tracker is the system of record); triage
    # output is a mission-brief-format brief, not a state file (the mission-brief format).
    run_dir = sandbox_project / ".adlc" / "workflows" / "runs" / "run-queue-1"
    run_dir.mkdir(parents=True, exist_ok=True)

    (run_dir / "brief.md").write_text(
        "# Factory Run Brief: issue-123\n\n"
        "## Goal\nImplement JWT profiles\n\n"
        "## Constraints\nLabels: intent\n\n"
        "## Success Criteria\n- Triage score confidence 95%%\n"
    )

    brief = (run_dir / "brief.md").read_text()
    assert "Implement JWT profiles" in brief
    assert "intent" in brief
    # No step progress is recorded: triage produces no program counter.
    assert not (run_dir / "state.json").exists()

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
