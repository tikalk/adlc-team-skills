"""
test_tech_radar.py — Unit tests for Tikal Tech Radar skill dataset and search helper.
"""

import json
import subprocess
import sys
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent
RADAR_JSON_PATH = (
    ROOT
    / "skills"
    / "tech-radar"
    / "tech-radar-context"
    / "resources"
    / "radar.json"
)
RADAR_SEARCH_SCRIPT = (
    ROOT
    / "skills"
    / "tech-radar"
    / "tech-radar-context"
    / "scripts"
    / "radar-search.sh"
)


def test_radar_json_exists_and_is_valid():
  """Verify radar.json exists, is valid JSON, and contains expected keys."""
  assert RADAR_JSON_PATH.exists(), f"Missing radar.json at {RADAR_JSON_PATH}"

  with open(RADAR_JSON_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

  assert "quadrants" in data
  assert "rings" in data
  assert "blips" in data
  assert len(data["blips"]) >= 400, (
      f"Expected at least 400 blips, got {len(data['blips'])}"
  )


def test_every_blip_has_required_fields_and_why_text():
  """Verify every blip in radar.json has name, quadrant, ring, and a parseable Why? block."""
  with open(RADAR_JSON_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

  import re

  for blip in data["blips"]:
    assert "name" in blip and blip["name"], "Blip missing name"
    assert "quadrant" in blip and blip["quadrant"], (
        f"Blip {blip['name']} missing quadrant"
    )
    assert "ring" in blip and blip["ring"], f"Blip {blip['name']} missing ring"
    assert "description" in blip and blip["description"], (
        f"Blip {blip['name']} missing description"
    )

    # Verify <p>Why?</p> block exists in description
    assert "<p>Why?</p>" in blip["description"], (
        f"Blip {blip['name']} description missing <p>Why?</p> block"
    )


def test_fixed_blip_descriptions_are_accurate():
  """Verify that previously corrupted blips (Chaos Toolkit, k6, kube-score, Swarm) have accurate description blocks."""
  with open(RADAR_JSON_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

  by_name = {b["name"]: b for b in data["blips"]}

  assert "cert-manager" not in by_name["Chaos Toolkit"]["description"]
  assert "Chaos Toolkit" in by_name["Chaos Toolkit"]["description"]

  assert "k3s" not in by_name["k6"]["description"]
  assert "k6" in by_name["k6"]["description"]

  assert "Kong" not in by_name["kube-score"]["description"]
  assert "kube-score" in by_name["kube-score"]["description"]

  assert "Docker Swarm" in by_name["Swarm"]["description"]


def test_radar_search_script_alias_mapping_and_markdown_output():
  """Verify radar-search.sh normalizes aliases and outputs markdown table."""
  assert RADAR_SEARCH_SCRIPT.exists()

  # Test alias k8s -> Kubernetes
  result = subprocess.run(
      ["bash", str(RADAR_SEARCH_SCRIPT), "k8s", "postgres"],
      capture_output=True,
      text=True,
      cwd=ROOT,
  )

  assert result.returncode == 0
  stdout = result.stdout

  assert "## Tikal Tech Radar Context" in stdout
  assert "Kubernetes" in stdout
  assert "PostgreSQL" in stdout
  assert "Source: Tikal Israeli Tech Radar" in stdout


def test_radar_search_script_json_mode():
  """Verify radar-search.sh --json outputs structured JSON."""
  result = subprocess.run(
      ["bash", str(RADAR_SEARCH_SCRIPT), "--json", "fastapi"],
      capture_output=True,
      text=True,
      cwd=ROOT,
  )

  assert result.returncode == 0
  data = json.loads(result.stdout)

  assert isinstance(data, list)
  assert len(data) >= 1
  assert data[0]["name"] == "FastAPI"
  assert data[0]["ring"] == "Keep"
  assert "why" in data[0]


def _run_radar_search(*queries):
  """Helper: run radar-search.sh and return stdout."""
  result = subprocess.run(
      ["bash", str(RADAR_SEARCH_SCRIPT), *queries],
      capture_output=True,
      text=True,
      cwd=ROOT,
  )
  assert result.returncode == 0, f"radar-search.sh failed: {result.stderr}"
  return result.stdout


def test_radar_search_ts_no_false_positives():
  """Short query 'ts' must not match every name containing the substring 'ts'.

  Regression: the old raw-query contains($q) clause matched 'A2A Agents',
  'Argo Rollouts', 'EKS Blueprints', etc. (17 rows). After the fix, 'ts' should
  only match TypeScript and its compound entries (Node.js + Typescript).
  """
  stdout = _run_radar_search("ts")
  assert "TypeScript" in stdout
  # None of these false-positive names should appear
  assert "A2A Agents" not in stdout
  assert "Argo Rollouts" not in stdout
  assert "EKS Blueprints" not in stdout
  assert "Cert-manager" not in stdout


def test_radar_search_airflow_returns_all_placements():
  """'airflow' must return all Airflow blips, not just Airflow 3.

  Regression: the old alias 'airflow' -> 'Airflow 3' would have narrowed
  results if not for the contains($c) clause. After removing the narrowing
  alias, all three placements surface.
  """
  stdout = _run_radar_search("airflow")
  assert "Airflow" in stdout
  assert "Airflow 2" in stdout
  assert "Airflow 3" in stdout


def test_radar_search_jenkins_conflict_detection():
  """Jenkins has conflicting placements (Backend:Stop, DevOps:Keep) — must flag it."""
  stdout = _run_radar_search("jenkins")
  assert "Conflicting Placements" in stdout
  assert "Jenkins" in stdout
  # JCasC (with parens) must be handled by the awk exact-match, not broken by grep regex
  assert "JCasC" in stdout


def test_radar_skill_canonical_ring_definitions():
  """SKILL.md ring table must use canonical Tikal ring definitions (not paraphrased).

  Locks the definitions so they can't silently drift back to the inaccurate
  paraphrases ('Mature, battle-tested', 'Emerging / promising', 'low-risk trials').
  """
  skill_md = (
      ROOT / "skills" / "tech-radar" / "tech-radar-context" / "SKILL.md"
  ).read_text(encoding="utf-8")

  # Canonical Try definition
  assert "New stuff that on the surface seems good" in skill_md
  assert "low-risk trials" not in skill_md

  # Canonical Start definition (beta nuance)
  assert "if in beta, active progress and contribution" in skill_md

  # Canonical Keep definition (non-beta distinction)
  assert "Stable release (non-beta)" in skill_md
  assert "Mature, battle-tested" not in skill_md

  # Canonical Stop definition
  assert "better alternatives exist" in skill_md
  assert "Deprecated / anti-pattern" not in skill_md
