"""
test_tech_radar.py — Unit tests for the Tikal Tech Radar skill and its OKF reader.

The reader is pinned to a fixture knowledge tree (tests/fixtures/radar-okf) via
ADLC_RADAR_REPO, so the suite never touches gitlab.tikalk.dev or the network.
The public-JSON fallback is exercised with a local file:// fixture.
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL_DIR = ROOT / "skills" / "tech-radar" / "tech-radar-boot"
RADAR_SH = SKILL_DIR / "scripts" / "radar-search.sh"
RADAR_PS1 = SKILL_DIR / "scripts" / "radar-search.ps1"
SKILL_MD = SKILL_DIR / "SKILL.md"
FIXTURE_TREE = ROOT / "tests" / "fixtures" / "radar-okf"
FALLBACK_JSON = ROOT / "tests" / "fixtures" / "radar-fallback.json"

OKF_ENV = {"ADLC_RADAR_REPO": str(FIXTURE_TREE)}


def _run_sh(*args, env=None):
  """Run radar-search.sh with the fixture knowledge tree by default."""
  merged = dict(os.environ)
  for key in list(merged):
    if key.startswith("ADLC_RADAR_"):
      del merged[key]
  merged.update(OKF_ENV)
  if env:
    for key, value in env.items():
      if value is None:
        merged.pop(key, None)
      else:
        merged[key] = value
  return subprocess.run(
      ["bash", str(RADAR_SH), *args],
      capture_output=True,
      text=True,
      cwd=ROOT,
      env=merged,
  )


def _stdout(*args, env=None):
  result = _run_sh(*args, env=env)
  assert result.returncode == 0, f"radar-search.sh failed: {result.stderr}"
  return result.stdout


def test_alias_mapping_and_markdown_output():
  """Aliases resolve and the markdown table carries the OKF Why text."""
  stdout = _stdout("k8s", "postgres")

  assert "## Tikal Tech Radar Context" in stdout
  assert "Kubernetes" in stdout
  assert "PostgreSQL" in stdout
  assert "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |" in stdout
  assert "de facto container orchestration" in stdout
  assert "_Source: Tikal Israeli Tech Radar — adlc-radar OKF tree" in stdout


def test_json_mode_shape():
  """--json returns structured records with name/quadrant/ring/why/path."""
  data = json.loads(_stdout("--json", "fastapi"))

  assert isinstance(data, list)
  assert len(data) == 1
  assert data[0]["name"] == "FastAPI"
  assert data[0]["ring"] == "Keep"
  assert "Better alternative to Flask" in data[0]["why"]
  assert data[0]["path"].endswith("backend/fastapi.md")


def test_ts_no_false_positives():
  """Short query 'ts' must not match every title containing the substring."""
  stdout = _stdout("ts")

  assert "TypeScript" in stdout
  for noise in ("Kubernetes", "PostgreSQL", "Jenkins", "Apache Kafka"):
    assert noise not in stdout


def test_multiple_placements_are_all_returned():
  """A technology present in two quadrants yields one row per placement."""
  stdout = _stdout("node")

  assert "Node.js" in stdout
  assert stdout.count("| Node.js |") == 2


def test_conflict_detection_for_duplicate_rings():
  """Same name, conflicting rings → Conflicting Placements guidance."""
  stdout = _stdout("jenkins")

  assert "Conflicting Placements" in stdout
  assert "Backend: Stop" in stdout
  assert "DevOps: Keep" in stdout


def test_include_no_documents_are_excluded_by_default():
  """`include: no` documents stay in the tree but are skipped unless opted in."""
  default = _stdout("legacy queue")
  assert "Legacy Queue" not in default

  opted_in = _stdout("legacy queue", "--include-excluded")
  assert "Legacy Queue" in opted_in


def test_quadrant_and_ring_filters():
  """--quadrant/--ring narrow the result set."""
  only_stop = _stdout("node", "--quadrant", "devops", "--ring", "stop")

  assert "| Node.js | DevOps | Stop |" in only_stop
  assert "| Node.js | Backend | Keep |" not in only_stop


def test_category_query_uses_body_terms():
  """A purpose query with no product name ranks documents by body terms."""
  stdout = _stdout("event streaming")

  assert "Apache Kafka" in stdout
  assert "event streaming" in stdout


def test_zero_match_has_no_table():
  """0-match output = heading + source line only — no table anywhere."""
  out = _stdout("zzz-no-such-technology-xyz")

  assert "## Tikal Tech Radar Context" in out
  assert "0 technologies matched" in out
  table_lines = [ln for ln in out.splitlines() if ln.lstrip().startswith("|")]
  assert table_lines == [], f"0-match output must not contain a table, got: {table_lines}"


def test_fallback_to_public_json_when_repo_unavailable(tmp_path):
  """No checkout at all → announce the public-JSON fallback and answer from it."""
  out = _stdout(
      "k8s",
      env={
          "ADLC_RADAR_REPO": None,
          "ADLC_RADAR_CACHE": str(tmp_path / "empty-cache"),
          "ADLC_RADAR_URL": "/nonexistent/adlc-radar.git",
          "ADLC_RADAR_FALLBACK_URL": f"file://{FALLBACK_JSON}",
      },
  )

  assert "working with the public radar JSON" in out
  assert "FALLBACK public radar.json" in out
  assert "Kubernetes" in out
  assert "De facto container orchestration" in out


def test_stale_cache_is_used_with_a_warning(tmp_path):
  """Unreachable repo + existing checkout → stale OKF tree, explicitly flagged."""
  cache = tmp_path / "cache"
  shutil.copytree(FIXTURE_TREE / "knowledge", cache / "knowledge")
  subprocess.run(["git", "init", "-q"], cwd=cache, check=True)
  subprocess.run(["git", "add", "-A"], cwd=cache, check=True)
  subprocess.run(
      ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "init"],
      cwd=cache,
      check=True,
  )
  (cache / ".adlc-radar-synced").write_text("1\n")  # epoch 1 → far outside TTL

  out = _stdout(
      "postgres",
      env={
          "ADLC_RADAR_REPO": None,
          "ADLC_RADAR_CACHE": str(cache),
          "ADLC_RADAR_URL": "/nonexistent/adlc-radar.git",
          "ADLC_RADAR_FALLBACK_URL": f"file://{FALLBACK_JSON}",
      },
  )

  assert "cached OKF tree" in out
  assert "STALE — refresh failed" in out
  assert "PostgreSQL" in out
  # A usable checkout wins over the public JSON.
  assert "FALLBACK" not in out


def test_total_unavailability_reports_and_keeps_no_table(tmp_path):
  """Repo and public JSON both unreachable → source line, no table, exit 0."""
  out = _stdout(
      "k8s",
      env={
          "ADLC_RADAR_REPO": None,
          "ADLC_RADAR_CACHE": str(tmp_path / "empty-cache"),
          "ADLC_RADAR_URL": "/nonexistent/adlc-radar.git",
          "ADLC_RADAR_FALLBACK_URL": f"file://{tmp_path / 'missing.json'}",
      },
  )

  assert "radar unavailable" in out
  assert "0 technologies matched" in out
  assert [ln for ln in out.splitlines() if ln.lstrip().startswith("|")] == []


def test_reader_never_reads_generated_radar_json():
  """radar.json is generated output — the OKF reader must not parse it."""
  source = RADAR_SH.read_text(encoding="utf-8")
  # The public fallback URL is the only JSON the helper may consume.
  assert "https://tikalk.com/radar.json" in source
  assert "ADLC_RADAR_FALLBACK_URL" in source
  assert "knowledge/technologies/" in source
  # No repo-local / bundled JSON is read as knowledge.
  assert "resources/radar.json" not in source
  assert "knowledge/technologies/radar.json" not in source


def test_skill_md_documents_okf_source_and_cache():
  """SKILL.md must name the OKF repository, cache TTL, and the fallback ladder."""
  content = SKILL_MD.read_text(encoding="utf-8")

  assert "adlc-radar" in content
  assert "gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-radar" in content
  assert "knowledge/technologies/" in content
  assert "ADLC_RADAR_TTL" in content
  assert "259200" in content
  assert "stale" in content.lower()
  assert "public radar json" in content.lower()
  assert "radar-search.sh" in content
  assert "radar-search.ps1" in content
  assert "radar-search.py" not in content
  # Generated output must never be advertised as the source of record.
  assert "generated output" in content


def test_skill_md_canonical_ring_definitions():
  """SKILL.md ring table uses canonical Tikal definitions (not paraphrases)."""
  content = SKILL_MD.read_text(encoding="utf-8")

  assert "New stuff that on the surface seems good" in content
  assert "low-risk trials" not in content
  assert "if in beta, active progress and contribution" in content
  assert "Stable release (non-beta)" in content
  assert "Mature, battle-tested" not in content
  assert "better alternatives exist" in content
  assert "Deprecated / anti-pattern" not in content


def _source_tree_scripts(pattern):
  """radar helper scripts under skills/ only — generated mirrors excluded."""
  return [
      p
      for p in ROOT.glob(f"**/{pattern}")
      if ".agents" not in p.parts
      and ".opencode" not in p.parts
      and ".git" not in p.parts
  ]


def test_single_canonical_radar_search_script_pair():
  """Source tree must carry exactly one radar-search.sh + one radar-search.ps1."""
  sh_scripts = _source_tree_scripts("radar-search.sh")
  ps1_scripts = _source_tree_scripts("radar-search.ps1")
  assert len(sh_scripts) == 1, f"expected 1 radar-search.sh, found: {sh_scripts}"
  assert len(ps1_scripts) == 1, f"expected 1 radar-search.ps1, found: {ps1_scripts}"
  assert sh_scripts[0].parent.parent.name == "tech-radar-boot"


def test_ps1_parity_zero_match():
  """PowerShell parity: 0-match output has heading + source line, no table."""
  if shutil.which("pwsh") is None:
    pytest.skip("pwsh not installed")
  env = dict(os.environ)
  env.update(OKF_ENV)
  result = subprocess.run(
      ["pwsh", "-NoProfile", "-File", str(RADAR_PS1), "zzz-no-such-technology-xyz"],
      capture_output=True,
      text=True,
      cwd=ROOT,
      env=env,
  )
  assert result.returncode == 0, f"radar-search.ps1 failed: {result.stderr}"
  out = result.stdout
  assert "## Tikal Tech Radar Context" in out
  assert "0 technologies matched" in out
  assert [ln for ln in out.splitlines() if ln.lstrip().startswith("|")] == []


def test_ps1_parity_alias_and_json():
  """PowerShell parity: alias lookup + JSON shape."""
  if shutil.which("pwsh") is None:
    pytest.skip("pwsh not installed")
  env = dict(os.environ)
  env.update(OKF_ENV)
  result = subprocess.run(
      ["pwsh", "-NoProfile", "-File", str(RADAR_PS1), "k8s", "-Json"],
      capture_output=True,
      text=True,
      cwd=ROOT,
      env=env,
  )
  assert result.returncode == 0, f"radar-search.ps1 failed: {result.stderr}"
  data = json.loads(result.stdout)
  assert any(row["name"] == "Kubernetes" for row in data)
