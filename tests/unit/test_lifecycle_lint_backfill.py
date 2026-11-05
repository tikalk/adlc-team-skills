"""Lifecycle lint + backfill (adlc-workspace#83, G4).

- factory-tickets `lifecycle-lint` is read-only. Every non-interactive issue
  must carry exactly one lifecycle label, and a closed issue must be `done` or
  `cancelled`. Each violation gets one proposed label. A proposal of "-" means
  a human decides (an open issue that only carries a terminal label).
  `interactive` issues are reported, never counted or proposed.
- factory-setup `lifecycle-backfill` reads the lint's JSON plan. Without
  --apply it only prints the dry-run table (issue, current labels, proposed
  label). With --apply it makes one Set Lifecycle call per row (add the
  proposal, remove every other lifecycle label), re-reads the labels, and
  skips "-" rows.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
LINT = ROOT / "skills/factory/factory-tickets/scripts/bash/lifecycle-lint.sh"
BACKFILL = ROOT / "skills/factory/factory-setup/scripts/bash/lifecycle-backfill.sh"
TICKETS_MD = ROOT / "skills/factory/factory-tickets/SKILL.md"
MODE3 = ROOT / "skills/factory/factory-setup/references/mode-configured.md"

pytestmark = pytest.mark.skipif(shutil.which("jq") is None, reason="jq required")


def issue(iid, state, labels, merged=None):
    return {"iid": iid, "state": state, "labels": labels, "closed_by_merged": merged}


FIXTURE = [
    issue(1, "opened", ["supervised", "executing"]),                    # ok
    issue(2, "opened", ["autonomous", "intent", "parked"]),            # two -> parked
    issue(3, "opened", ["supervised"]),                                 # none -> intent
    issue(4, "opened", ["autonomous", "done"]),                         # open terminal only -> "-"
    issue(5, "opened", ["autonomous", "validation", "done"]),           # open + terminal -> validation
    issue(6, "closed", ["autonomous", "done"]),                         # ok
    issue(7, "closed", ["supervised", "validation"], merged=True),      # -> done
    issue(8, "closed", ["supervised", "executing"], merged=False),      # -> cancelled
    issue(9, "closed", [], merged=False),                               # none -> cancelled
    issue(10, "closed", ["done", "validation"]),                        # extra -> done
    issue(11, "opened", ["interactive", "intent", "executing"]),        # reported only
]


def run(script, *args, env=None, input_text=None):
    return subprocess.run(["bash", str(script), *args], capture_output=True, text=True,
                          env={**os.environ, **(env or {})}, input=input_text)


@pytest.fixture
def fixture_file(tmp_path):
    p = tmp_path / "issues.json"
    p.write_text(json.dumps(FIXTURE))
    return p


def lint_plan(fixture_file, tmp_path):
    plan = tmp_path / "plan.json"
    r = run(LINT, "--issues", str(fixture_file), "--json", str(plan))
    return r, json.loads(plan.read_text())


def test_lint_flags_each_violation_with_one_proposal(fixture_file, tmp_path):
    r, plan = lint_plan(fixture_file, tmp_path)
    assert r.returncode == 1, r.stderr
    got = {row["iid"]: row["proposed"] for row in plan["violations"]}
    assert got == {2: "parked", 3: "intent", 4: "-", 5: "validation",
                   7: "done", 8: "cancelled", 9: "cancelled", 10: "done"}


def test_lint_reports_interactive_without_counting_it(fixture_file, tmp_path):
    r, plan = lint_plan(fixture_file, tmp_path)
    assert [row["iid"] for row in plan["interactive"]] == [11]
    assert 11 not in [row["iid"] for row in plan["violations"]]
    assert "8 violations" in r.stdout and "1 interactive" in r.stdout


def test_lint_passes_a_clean_tracker(tmp_path):
    clean = tmp_path / "clean.json"
    clean.write_text(json.dumps([issue(1, "opened", ["autonomous", "executing"]),
                                 issue(2, "closed", ["supervised", "cancelled"])]))
    r = run(LINT, "--issues", str(clean))
    assert r.returncode == 0, r.stdout + r.stderr
    assert "0 violations" in r.stdout


def test_lint_is_read_only():
    text = LINT.read_text(encoding="utf-8")
    for write in ("-X PUT", "-X POST", "--method PUT", "issue update", "issue edit", "label create"):
        assert write not in text, f"lint must not write: {write}"


def test_backfill_dry_run_prints_the_table_and_writes_nothing(fixture_file, tmp_path):
    _, plan = lint_plan(fixture_file, tmp_path)
    planfile = tmp_path / "plan.json"
    log = tmp_path / "calls.log"
    stub = tmp_path / "bin"
    stub.mkdir()
    (stub / "glab").write_text(f"#!/bin/sh\necho \"$@\" >> {log}\necho '{{}}'\n")
    (stub / "glab").chmod(0o755)
    r = run(BACKFILL, "--plan", str(planfile), "--provider", "gitlab", "--project", "g/p",
            env={"PATH": f"{stub}:{os.environ['PATH']}"})
    assert r.returncode == 0, r.stderr
    assert "| Issue | Current labels | Proposed |" in r.stdout
    assert "dry run" in r.stdout.lower()
    assert not log.exists(), "dry run must make no tracker call"


def test_backfill_apply_swaps_each_row_and_skips_human_rows(fixture_file, tmp_path):
    lint_plan(fixture_file, tmp_path)
    planfile = tmp_path / "plan.json"
    state = {str(i["iid"]): i["labels"] for i in FIXTURE}
    statefile = tmp_path / "state.json"
    statefile.write_text(json.dumps(state))
    stub = tmp_path / "bin"
    stub.mkdir()
    # glab api [-X PUT] projects/<p>/issues/<iid> [-f add_labels=..] [-f remove_labels=..]
    (stub / "glab").write_text(f"""#!/usr/bin/env python3
import json, sys
s = json.load(open({str(statefile)!r}))
a = sys.argv[1:]
iid = [x for x in a if "/issues/" in x][0].rsplit("/", 1)[1]
add = [x.split("=", 1)[1] for x in a if x.startswith("add_labels=")]
rm = [x.split("=", 1)[1] for x in a if x.startswith("remove_labels=")]
if "PUT" in a:
    with open({str(tmp_path / 'puts.log')!r}, "a") as f:
        f.write(json.dumps({{"iid": iid, "add": add, "rm": rm}}) + "\\n")
    labels = [l for l in s[iid] if l not in ",".join(rm).split(",")]
    for l in ",".join(add).split(","):
        if l and l not in labels:
            labels.append(l)
    s[iid] = labels
    json.dump(s, open({str(statefile)!r}, "w"))
print(json.dumps({{"labels": s[iid]}}))
""")
    (stub / "glab").chmod(0o755)
    r = run(BACKFILL, "--plan", str(planfile), "--provider", "gitlab", "--project", "g/p", "--apply",
            env={"PATH": f"{stub}:{os.environ['PATH']}"})
    assert r.returncode == 0, r.stdout + r.stderr
    puts = [json.loads(l) for l in (tmp_path / "puts.log").read_text().splitlines()]
    assert sorted(int(p["iid"]) for p in puts) == [2, 3, 5, 7, 8, 9, 10], "one call per row, '-' rows skipped"
    final = json.loads(statefile.read_text())
    lifecycle = {"intent", "spec-gated", "executing", "parked", "validation", "done", "cancelled"}
    for iid in ("2", "3", "5", "7", "8", "9", "10"):
        assert len([l for l in final[iid] if l in lifecycle]) == 1, (iid, final[iid])
    assert "skipped #4" in r.stdout


def test_tickets_skill_documents_the_read_only_lint():
    text = TICKETS_MD.read_text(encoding="utf-8")
    assert "lifecycle-lint" in text and "read-only" in text.lower()


def test_mode3_documents_the_confirm_gated_backfill():
    text = MODE3.read_text(encoding="utf-8")
    assert "lifecycle-backfill" in text
    line = next(l for l in text.splitlines() if "lifecycle-backfill" in l and "--apply" in l)
    assert "confirm" in line.lower()


def test_twins_exist():
    for bash in (LINT, BACKFILL):
        ps = bash.parent.parent / "powershell" / (bash.stem + ".ps1")
        assert ps.exists(), f"missing PowerShell twin {ps}"
