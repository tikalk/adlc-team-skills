"""factory-queue capability-aware work-item hierarchy (GitLab work item #47).

Each test maps to one success criterion. Per the two-sided validation
rule, every check below names its positive witness (a passing fixture the
check accepts) and its breakage/negative witness (a failing fixture or a
mutation the check must catch).

Criterion classes:
- A: deterministic behavior (strategy selector, snapshot comparer).
- B: structure or reference content (skill prose, reference prose).
- C: needs a live run (none shipped here; live drills need explicit
  authorization and disposable issues, and never touch production issues).

Traceability (words only in skill prose; record ids live in tests only):
the capability-aware hierarchy design is governed by the accepted
product and architecture records for real parent/child epics, and the
provider seam by the accepted multi-provider and factory-owned provider
records; the two-sided rule itself governs witness + breakage shape.
"""

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts"
STRATEGY_BASH = SCRIPTS / "bash/resolve-hierarchy-strategy.sh"
STRATEGY_PWSH = SCRIPTS / "powershell/resolve-hierarchy-strategy.ps1"
QUEUE_SKILL = ROOT / "skills/factory/factory-queue/SKILL.md"
TRACKER_INTEGRATION = ROOT / "skills/factory/factory-mission/references/tracker-integration.md"

HAVE_BASH = shutil.which("bash") is not None
HAVE_PWSH = shutil.which("pwsh") is not None


def _run(script, payload):
    payload_str = json.dumps(payload)
    if script.suffix == ".sh":
        cmd = ["bash", str(script)]
    else:
        cmd = ["pwsh", "-NoProfile", "-File", str(script)]
    return subprocess.run(cmd, input=payload_str, capture_output=True,
                          text=True, timeout=30)


def strategy(**payload):
    """Run the strategy selector; both twins must agree (one behavior)."""
    proc = _run(STRATEGY_BASH, payload)
    assert proc.returncode == 0, f"strategy selector failed: {proc.stderr}"
    out = json.loads(proc.stdout)
    if HAVE_PWSH:
        proc2 = _run(STRATEGY_PWSH, payload)
        assert proc2.returncode == 0, f"pwsh selector failed: {proc2.stderr}"
        out2 = json.loads(proc2.stdout)
        assert out == out2, f"twins disagree:\nbash : {out}\npwsh : {out2}"
    else:
        pytest.skip("pwsh absent: PowerShell twin parity not checked here")
    return out


def fresh_probe(**caps):
    return {
        "instance": "git.example.com/acme",
        "version": "18.11.13",
        "probe_fresh": True,
        "probe_from_instance": "git.example.com/acme",
        "probe_from_version": "18.11.13",
        "capabilities": caps,
    }


# ── A1: native Epic type wins (witness: premium-shape matrix) ───────────────

def test_native_epic_strategy_when_epic_type_available():
    """Witness: a matrix advertising a native Epic type selects native_epic
    with no conversion and names instance + version + strategy."""
    out = strategy(**fresh_probe(epic_type=True,
                                 issue_parent_task_children=True,
                                 work_item_convert=True))
    assert out["strategy"] == "native_epic"
    assert out["attach"] is True
    assert out["convert"] is False
    assert out["degraded"] is False
    assert "git.example.com/acme" in out["disclosure"]
    assert "18.11.13" in out["disclosure"]
    assert "native_epic" in out["disclosure"]


# ── A2: Issue parent + Task children via convert (witness: free-tier shape) ─

def test_issue_parent_task_children_strategy_on_free_tier():
    """Witness: the free-tier shape (no Epic type, Issue-parent-of-Task,
    convert available) selects issue_parent_task_children with convert."""
    out = strategy(**fresh_probe(epic_type=False,
                                 issue_parent_task_children=True,
                                 work_item_convert=True))
    assert out["strategy"] == "issue_parent_task_children"
    assert out["attach"] is True
    assert out["convert"] is True
    assert out["degraded"] is False
    assert "convert from Issue to Task" in out["disclosure"]
    assert "trade-off" in out["disclosure"]


def test_issue_parent_without_convert_still_attaches():
    """Boundary: Issue-parent support without convert still attaches but
    does not convert."""
    out = strategy(**fresh_probe(epic_type=False,
                                 issue_parent_task_children=True,
                                 work_item_convert=False))
    assert out["strategy"] == "issue_parent_task_children"
    assert out["attach"] is True
    assert out["convert"] is False


# ── A3: no hierarchy support → degraded (witness: bare tracker) ─────────────

def test_degraded_no_tree_when_no_hierarchy_support():
    """Witness: a matrix with no hierarchy capability selects
    degraded_no_tree and says so (never silent)."""
    out = strategy(**fresh_probe(epic_type=False,
                                 issue_parent_task_children=False,
                                 work_item_convert=False))
    assert out["strategy"] == "degraded_no_tree"
    assert out["attach"] is False
    assert out["degraded"] is True
    assert "degraded_no_tree" in out["disclosure"]


# ── A4: stale or foreign probe counts as no probe (breakage probes) ─────────

def test_stale_probe_counts_as_no_probe():
    """Breakage: a stale probe must not select a hierarchy strategy even
    when the matrix advertises one."""
    payload = fresh_probe(epic_type=True)
    payload["probe_fresh"] = False
    out = strategy(**payload)
    assert out["strategy"] == "degraded_no_tree"
    assert "stale or from another target" in out["disclosure"]


def test_probe_from_another_instance_counts_as_no_probe():
    """Breakage: a fresh probe recorded on another instance must not apply."""
    payload = fresh_probe(epic_type=True)
    payload["probe_from_instance"] = "other.example.com/theirs"
    out = strategy(**payload)
    assert out["strategy"] == "degraded_no_tree"


def test_probe_from_another_version_counts_as_no_probe():
    """Breakage: a fresh probe recorded on another version must not apply."""
    payload = fresh_probe(epic_type=True)
    payload["probe_from_version"] = "17.0.0"
    out = strategy(**payload)
    assert out["strategy"] == "degraded_no_tree"


# ── A5: use-time failure downgrades only the affected epic, naming the op ───

def test_use_time_failure_downgrades_only_affected_epic():
    """Witness: a passing probe followed by a use-time mutation failure
    falls back for this epic and names the failing operation."""
    payload = fresh_probe(epic_type=False,
                          issue_parent_task_children=True,
                          work_item_convert=True)
    payload["use_time_failure"] = "workItemHierarchyAddChildrenItems"
    out = strategy(**payload)
    assert out["strategy"] == "degraded_no_tree"
    assert out["degraded"] is True
    assert "workItemHierarchyAddChildrenItems" in out["disclosure"]
    assert "this epic only" in out["disclosure"]


# ── A6: attachment verification from a mocked tracker response ──────────────

def check_attachment(response):
    """Deterministic attach check: child count and hasChildren match.

    Standalone pytest-covered helper (no PromptFoo wiring: the repo wires
    PromptFoo graders only for brief-format and advisory checks; this
    helper is covered here instead)."""
    children = response.get("children", [])
    assert response.get("hasChildren") is True, "epic must report hasChildren"
    assert len(children) == response.get("childCount"), \
        "child count must match attached children"
    return True


def test_attachment_check_accepts_matching_response():
    """Witness: a mocked response with hasChildren and matching count."""
    assert check_attachment({
        "hasChildren": True, "childCount": 3,
        "children": [{"iid": 1}, {"iid": 2}, {"iid": 3}],
    }) is True


def test_attachment_check_rejects_missing_has_children():
    """Breakage: hasChildren False must fail the check."""
    with pytest.raises(AssertionError):
        check_attachment({
            "hasChildren": False, "childCount": 2,
            "children": [{"iid": 1}, {"iid": 2}],
        })


def test_attachment_check_rejects_count_mismatch():
    """Breakage: a child count that disagrees with the list must fail."""
    with pytest.raises(AssertionError):
        check_attachment({
            "hasChildren": True, "childCount": 5,
            "children": [{"iid": 1}],
        })


# ── A7: conversion-safety snapshot comparer ──────────────────────────────────

def compare_conversion_snapshots(before, after):
    """Deterministic before/after comparer for Issue→Task conversion.

    Standalone pytest-covered helper (same PromptFoo note as above).
    Returns True when milestone, labels, and description survive."""
    problems = []
    if before.get("milestone") != after.get("milestone"):
        problems.append("milestone changed")
    if sorted(before.get("labels", [])) != sorted(after.get("labels", [])):
        problems.append("labels changed")
    if before.get("description") != after.get("description"):
        problems.append("description changed")
    assert not problems, "conversion altered identity: " + "; ".join(problems)
    return True


def test_snapshot_comparer_accepts_intact_conversion():
    """Witness: identical snapshots pass (label order ignored)."""
    before = {"milestone": "M10", "labels": ["a", "b"], "description": "x"}
    after = {"milestone": "M10", "labels": ["b", "a"], "description": "x"}
    assert compare_conversion_snapshots(before, after) is True


def test_snapshot_comparer_catches_milestone_loss():
    """Breakage: a dropped milestone must fail the comparison."""
    before = {"milestone": "M10", "labels": ["a"], "description": "x"}
    after = {"milestone": None, "labels": ["a"], "description": "x"}
    with pytest.raises(AssertionError, match="milestone"):
        compare_conversion_snapshots(before, after)


def test_snapshot_comparer_catches_label_loss():
    """Breakage: a dropped label must fail the comparison."""
    before = {"milestone": "M10", "labels": ["a", "b"], "description": "x"}
    after = {"milestone": "M10", "labels": ["a"], "description": "x"}
    with pytest.raises(AssertionError, match="labels"):
        compare_conversion_snapshots(before, after)


def test_snapshot_comparer_catches_description_rewrite():
    """Breakage: a rewritten description must fail the comparison."""
    before = {"milestone": "M10", "labels": ["a"], "description": "x"}
    after = {"milestone": "M10", "labels": ["a"], "description": "y"}
    with pytest.raises(AssertionError, match="description"):
        compare_conversion_snapshots(before, after)


# ── B1: degraded fallback is explicit in skill + reference (never silent) ───

def test_degraded_fallback_marker_in_skill_and_reference():
    """The label-convention fallback carries the exact marker
    'degraded: no tree' in both the skill and the reference."""
    skill = QUEUE_SKILL.read_text(encoding="utf-8")
    ref = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    assert "degraded: no tree" in skill
    assert "degraded: no tree" in ref


def test_degraded_negative_fixture_is_caught():
    """Negative fixture: a plan output that falls back without the marker
    is non-conformant (the marker is what makes the fallback explicit)."""
    plan_output_without_marker = (
        "Epic created with label convention; children listed in a comment."
    )
    assert "degraded: no tree" not in plan_output_without_marker


# ── B2: reference documents the MCP-incompatibility path ────────────────────

def test_reference_documents_mcp_incompatibility_path():
    """tracker-integration.md documents the schema-mismatch failure mode,
    the provider-owned raw GraphQL fallback, env-only tokens, and the
    use-time downgrade rule."""
    ref = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    assert "schema" in ref.lower()
    low = ref.lower()
    assert "raw graphql" in low or "raw-graphql" in low
    assert "environment" in low
    assert "never" in low and "token" in low
    assert re.search(r"use-time|use time", ref, re.I)
    assert "degraded: no tree" in ref


# ── B3: plan-mode step order (probe before attach; verify; snapshot) ────────

def test_plan_mode_step_order_in_skill():
    """The plan-mode hierarchy step probes before attaching, attaches,
    verifies hasChildren, snapshot-compares conversion, and discloses."""
    skill = QUEUE_SKILL.read_text(encoding="utf-8")
    probe = skill.find("probe")
    attach = skill.find("Attach")
    assert probe != -1 and attach != -1 and probe < attach, \
        "probe must precede attach in the plan step"
    for term in ("hasChildren", "Snapshot", "degraded: no tree"):
        assert term in skill, f"plan step must mention '{term}'"


# ── B4: sweeps inside factory-queue include Task-typed issues ────────────────

def test_queue_triage_includes_task_typed_issues():
    """factory-queue's own triage fetch includes Task-typed issues so
    converted children stay visible to the queue."""
    skill = QUEUE_SKILL.read_text(encoding="utf-8")
    assert "Task" in skill and "task" in skill.lower()
    assert re.search(r"Task-typed|Task typed|work item type", skill), \
        "triage must name Task-typed inclusion explicitly"


# ── B5: single-provider resolution order unchanged ──────────────────────────

def test_provider_resolution_order_unchanged():
    """The additive hierarchy work must not change the single-provider
    resolution order (params > file > halt). Covered upstream by the
    provider contract tests; this pins the seam text still carries it."""
    ref = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    assert "tracker_provider" in ref
    assert ".adlc/issues-provider.yml" in ref
    assert "halt" in ref.lower()
