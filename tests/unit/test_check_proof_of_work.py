"""Proof of work: every Definition-of-Done item done with evidence, or
disclosed as skipped / not applicable with a reason (SF-SKILL-07).

Evidence: octopus-next#1508 — the mission skipped a DoD item the issue said
how to do (a verified screenshot from a named staging script) and wrote "not
run (no staging env in this pod)"; the only proof-of-work check was
"mr_url is not empty".

Both twins run the same cases (pwsh rows skip where pwsh is absent; CI runs
them), and a text test keeps their embedded checkers identical.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-runbook/scripts"
BASH = SCRIPTS / "bash/check-proof-of-work.sh"
PS = SCRIPTS / "powershell/check-proof-of-work.ps1"
FAKE = ROOT / "tests/fixtures/fake-tracker"
MISSION = ROOT / "skills/factory/factory-mission/SKILL.md"
ISSUE = "tikalk/engineering/octopus-next#1508"

TWINS = [
    pytest.param(["bash", str(BASH)], id="bash", marks=pytest.mark.requires_bash),
    pytest.param(["pwsh", "-NoProfile", "-File", str(PS)], id="pwsh",
                 marks=pytest.mark.skipif(shutil.which("pwsh") is None, reason="needs pwsh (CI runs it)")),
]

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")

DOD = """## Mission Brief
- not an item

## Definition of Done

- [ ] **Unit tests** for the filter
- [ ] Verified UI screenshot via `scripts/review/staging-e2e.sh`
1. Docs updated
- [x] No chart changes

### Notes inside the DoD
- also an item? no: a deeper heading is still inside the section
## Update (2026-11-09)
- not an item either
"""
ITEMS = ["**Unit tests** for the filter", "Verified UI screenshot via `scripts/review/staging-e2e.sh`",
         "Docs updated", "No chart changes", "also an item? no: a deeper heading is still inside the section"]


def entries(**over):
    base = [
        {"item": "Unit tests for the filter", "status": "done", "evidence": "route.test.ts: 19 passed"},
        {"item": "verified UI screenshot via scripts/review/staging-e2e.sh", "status": "done", "evidence": "MR description, screenshot 1"},
        {"item": "docs updated", "status": "done", "evidence": "docs/outbox.md"},
        {"item": "No chart changes", "status": "not-applicable", "reason": "the change touches no chart"},
        {"item": ITEMS[4], "status": "done", "evidence": "n/a"},
    ]
    for i, e in over.items():
        base[int(i[1:])] = e
    return [e for e in base if e is not None]


def env_without_context(**extra):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("FAKE_", "ADLC_")) and k not in ("WORKFLOW_INPUTS", "ISSUE_PROVIDER")}
    env.update(extra)
    return env


def run(cmd, tmp_path, ledger, *extra, dod=DOD, env=None):
    (tmp_path / "dod.md").write_text(dod)
    (tmp_path / "l.json").write_text(json.dumps({"items": ledger}))
    return subprocess.run([*cmd, "--ledger", str(tmp_path / "l.json"), "--dod-file", str(tmp_path / "dod.md"), *extra],
                          capture_output=True, text=True, cwd=tmp_path, env=env or env_without_context())


@pytest.mark.parametrize("cmd", TWINS)
def test_all_done_passes_and_discloses_not_applicable(cmd, tmp_path):
    r = run(cmd, tmp_path, entries(), "--summary-file", str(tmp_path / "s.md"))
    assert r.returncode == 0, r.stderr
    assert r.stdout.startswith("**Proof of work:** 4 of 5 Definition-of-Done item(s) done, 1 not applicable:")
    assert "- **No chart changes** — not-applicable: the change touches no chart" in r.stdout
    assert (tmp_path / "s.md").read_text() == r.stdout


@pytest.mark.parametrize("cmd", TWINS)
def test_a_skipped_item_is_disclosed_with_exit_3(cmd, tmp_path):
    led = entries(e1={"item": ITEMS[1], "status": "skipped", "reason": "staging-e2e.sh exited 2: env file missing in the pod"})
    r = run(cmd, tmp_path, led)
    assert r.returncode == 3, r.stderr
    assert "1 skipped" in r.stdout
    assert "— skipped: staging-e2e.sh exited 2: env file missing in the pod" in r.stdout
    # The owner's stricter alternative: any skip fails.
    assert run(cmd, tmp_path, led, "--fail-on-skip").returncode == 1


@pytest.mark.parametrize("cmd", TWINS)
@pytest.mark.parametrize("over, why", [
    ({"e1": None}, "no ledger entry for DoD item"),
    ({"e1": {"item": ITEMS[1], "status": "done", "evidence": " "}}, "is done but has no evidence"),
    ({"e1": {"item": ITEMS[1], "status": "skipped", "reason": "pending — no staging env"}}, "is not a reason"),
    ({"e1": {"item": ITEMS[1], "status": "skipped", "reason": "TODO later"}}, "is not a reason"),
    ({"e3": {"item": ITEMS[3], "status": "not-applicable"}}, "without a reason"),
    ({"e1": {"item": ITEMS[1], "status": "todo"}}, "expected done, skipped or not-applicable"),
])
def test_unaccounted_items_fail(cmd, tmp_path, over, why):
    r = run(cmd, tmp_path, entries(**over))
    assert r.returncode == 1
    assert why in r.stderr


@pytest.mark.parametrize("cmd", TWINS)
def test_usage_and_shape_errors_exit_2(cmd, tmp_path):
    assert run(cmd, tmp_path, entries(), dod="## Goal\n- x\n").returncode == 2           # no DoD section
    assert run(cmd, tmp_path, entries(), dod="## Definition of Done\n\ntext only\n").returncode == 2  # no items
    (tmp_path / "bad.json").write_text("{not json")
    r = subprocess.run([*cmd, "--ledger", str(tmp_path / "bad.json"), "--dod-file", str(tmp_path / "dod.md")],
                       capture_output=True, text=True, cwd=tmp_path, env=env_without_context())
    assert r.returncode == 2
    # Outside a factory run there is no default ledger.
    r = subprocess.run([*cmd, "--dod-file", str(tmp_path / "dod.md")], capture_output=True, text=True,
                       cwd=tmp_path, env=env_without_context())
    assert r.returncode == 2 and "--ledger is required" in r.stderr


@pytest.mark.parametrize("cmd", TWINS)
def test_the_run_context_supplies_the_ledger_and_the_issue(cmd, tmp_path):
    # In a lane pod: the ledger sits at .adlc/workflows/runs/<run id>/ and the
    # DoD is read from the run's issue through the tracker.
    run_id = "4335f623"
    ledger_dir = tmp_path / ".adlc/workflows/runs" / run_id
    ledger_dir.mkdir(parents=True)
    (ledger_dir / "proof-of-work.json").write_text(json.dumps({"items": entries()}))
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    glab = fake_bin / "glab"
    glab.write_text("#!/usr/bin/env bash\n"
                    f"node -e 'console.log(JSON.stringify({{description: require(\"fs\").readFileSync(process.argv[1], \"utf8\")}}))' {tmp_path / 'issue.md'}\n")
    glab.chmod(0o755)
    (tmp_path / "issue.md").write_text("Intro\n\n" + DOD)
    env = env_without_context(PATH=f"{fake_bin}{os.pathsep}{os.environ['PATH']}", GITLAB_HOST="gitlab.example.test",
                              WORKFLOW_INPUTS=json.dumps({"run_id": run_id, "issue_ref": ISSUE}))
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=tmp_path, env=env)
    assert r.returncode == 0, r.stderr
    assert "4 of 5" in r.stdout


def _checker(text, start, end):
    i = text.index(start) + len(start)
    return text[i:text.index(end, i)].strip("\n")


def test_both_twins_embed_the_same_checker():
    bash = _checker(BASH.read_text(encoding="utf-8"), "node -e '\n", "\n' \"$desc_file\"")
    ps = _checker(PS.read_text(encoding="utf-8"), "$checker = @'\n", "\n'@")
    assert bash.startswith("const fs = require(\"fs\");")
    assert bash == ps


def test_mission_requires_the_ledger_and_the_check():
    text = MISSION.read_text(encoding="utf-8")
    start = text.index("## In a factory run")
    section = text[start:text.index("## In a local session", start)]
    assert "proof-of-work.json" in section and "check-proof-of-work.sh --issue <issue ref>" in section
    assert '"pending" is not a reason' in section
    assert "never complete on exit 1" in section
    assert "`--details-file` to the completion record" in section
