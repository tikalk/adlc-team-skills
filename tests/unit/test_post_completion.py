"""One completion record per mission run, on every outcome (SF-SKILL-05).

Evidence (octopus-next): #1507, #1510, #1512, #1516 ended Argo "Succeeded"
with no completion note; the records that exist use three marker spellings,
one with an invented run id (#1523 `run=test-1523`); #1530 got "completed"
30 minutes before its completion gate parked the run.

Follow-up (SF-FIX-11), each reproduced with the fake tracker before the fix:
a retry of the same run that succeeds after a `failed` record must not leave
"Mission failed" as the only word on the issue; a GitHub issue with 100 or
more comments got three duplicate records and exit 1 (the read was one page,
oldest first); a tracker error said only "cannot read the notes".

Both twins run the same cases against the fake `glab` / `gh` in
tests/fixtures/fake-tracker (pwsh rows skip where pwsh is absent; CI runs them).
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-runbook/scripts"
FAKE = ROOT / "tests/fixtures/fake-tracker"
MISSION = ROOT / "skills/factory/factory-mission/SKILL.md"
ISSUE = "tikalk/engineering/octopus-next#1516"
RUN = "4335f623-f024-4f9c-87d1-9e7dd935f157"
MR = "https://gitlab.example.test/x/-/merge_requests/1321"

TWINS = [
    pytest.param(["bash", str(SCRIPTS / "bash/post-completion.sh")], id="bash",
                 marks=pytest.mark.requires_bash),
    pytest.param(["pwsh", "-NoProfile", "-File", str(SCRIPTS / "powershell/post-completion.ps1")], id="pwsh",
                 marks=pytest.mark.skipif(shutil.which("pwsh") is None, reason="needs pwsh (CI runs it)")),
]

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


def run(cmd, tmp_path, *args, run_id=RUN, issue_ref=ISSUE, env_extra=None, **knobs):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("FAKE_", "ADLC_")) and k not in ("WORKFLOW_INPUTS", "ISSUE_PROVIDER")}
    env.update({"PATH": f"{FAKE}{os.pathsep}{env['PATH']}", "FAKE_TRACKER_DIR": str(tmp_path),
                "GITLAB_HOST": "gitlab.example.test", "POST_COMPLETION_BACKOFF": "0"}, **knobs)
    lane = {}
    if run_id:
        lane["run_id"] = run_id
    if issue_ref:
        lane["issue_ref"] = issue_ref
    if lane:
        env["WORKFLOW_INPUTS"] = json.dumps(lane)
    env.update(env_extra or {})
    return subprocess.run([*cmd, *args], capture_output=True, text=True, env=env, cwd=tmp_path)


def notes(tmp_path):
    f = tmp_path / "notes.json"
    return json.loads(f.read_text()) if f.exists() else []


@pytest.mark.parametrize("cmd", TWINS)
def test_done_record_has_the_one_marker_and_the_mr(cmd, tmp_path):
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "GL retry every 6h", "--mr-url", MR)
    assert r.returncode == 0, r.stderr
    body = notes(tmp_path)[0]["body"]
    assert body.startswith(f"<!-- factory-mission:step=complete status=completed run={RUN} type=decision outcome=done -->\n")
    assert f"**Code MR:** {MR}" in body and "**Conclusion:** GL retry every 6h" in body
    assert "factory-run:ended" not in body
    assert "**Next:**" not in body  # a raw lane run has no gate after it


@pytest.mark.parametrize("cmd", TWINS)
@pytest.mark.parametrize("outcome, status", [("no-op", "completed"), ("blocked", "failed"), ("failed", "failed")])
def test_every_outcome_is_recorded(cmd, tmp_path, outcome, status):
    r = run(cmd, tmp_path, "--outcome", outcome, "--conclusion", "why")
    assert r.returncode == 0, r.stderr
    body = notes(tmp_path)[0]["body"]
    assert f"status={status} run={RUN} type=decision outcome={outcome} -->" in body
    assert "**Code MR:** none" in body
    # A run that ended badly gets the state machine's ended marker in the same note.
    assert (f"<!-- factory-run:ended reason=step-failed run={RUN} step=execute -->" in body) == (status == "failed")


@pytest.mark.parametrize("cmd", TWINS)
def test_one_record_per_run_and_outcome(cmd, tmp_path):
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a").returncode == 0
    # The same outcome again (an Argo retry of the pod, a second call): nothing new.
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "b")
    assert r.returncode == 0 and "already" in r.stdout
    assert len(notes(tmp_path)) == 1
    # A second run on the same issue gets its own record.
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "c", run_id="r2").returncode == 0
    assert len(notes(tmp_path)) == 2


@pytest.mark.parametrize("cmd", TWINS)
def test_a_retry_that_succeeds_after_a_failed_record_is_recorded(cmd, tmp_path):
    """The lane retries a pod with the same WORKFLOW_INPUTS.run_id and
    `workflow resume` keeps ADLC_RUN_ID. Before the fix the second call
    printed "already on …", exited 0 and posted nothing: the issue said
    "Mission failed" while the code MR was open."""
    assert run(cmd, tmp_path, "--outcome", "failed", "--conclusion", "pod lost").returncode == 0
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "retry worked", "--mr-url", MR)
    assert r.returncode == 0, r.stderr
    assert "already" not in r.stdout
    all_notes = notes(tmp_path)
    assert len(all_notes) == 2
    newest = all_notes[0]["body"]
    assert newest.startswith(f"<!-- factory-mission:step=complete status=completed run={RUN} type=decision outcome=done -->\n")
    assert f"**Code MR:** {MR}" in newest
    assert "**Replaces:** this run's earlier record (`failed`)" in newest
    assert "factory-run:ended" not in newest
    # The retry's own retry changes nothing.
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "retry worked", "--mr-url", MR)
    assert r.returncode == 0 and "already" in r.stdout
    assert len(notes(tmp_path)) == 2


@pytest.mark.parametrize("cmd", TWINS)
def test_the_newest_record_of_the_run_decides(cmd, tmp_path):
    for outcome in ("failed", "done", "failed"):
        assert run(cmd, tmp_path, "--outcome", outcome, "--conclusion", "x").returncode == 0
    bodies = [n["body"] for n in notes(tmp_path)]
    assert len(bodies) == 3
    assert "outcome=failed" in bodies[0] and "earlier record (`done`)" in bodies[0]
    # GitLab answers with created_at; the newest by time wins, whatever the list order.
    stamped = [dict(n, created_at=f"2026-11-20T10:00:0{i}Z") for i, n in enumerate(reversed(notes(tmp_path)))]
    (tmp_path / "notes.json").write_text(json.dumps(stamped))
    r = run(cmd, tmp_path, "--outcome", "failed", "--conclusion", "x")
    assert r.returncode == 0 and "already" in r.stdout


@pytest.mark.parametrize("cmd", TWINS)
@pytest.mark.parametrize("existing, outcome", [
    (f"<!-- factory-run:ended reason=step-failed run={RUN} step=execute -->\nblocked", "blocked"),
    (f"<!-- factory-run:ended run={RUN} issue=1516 reason=decision-records -->\nproposals", "blocked"),
    (f"<!-- factory-run:ended run={RUN} issue=1516 reason=decision-records -->\nproposals", "failed"),
    (f"<!-- factory-mission:status=completed:run={RUN} -->\nold spelling", "done"),
    (f"<!-- factory-mission:status=completed:run={RUN} -->\nold spelling", "no-op"),
])
def test_an_earlier_note_of_this_run_that_says_the_same_counts_as_its_record(cmd, tmp_path, existing, outcome):
    (tmp_path / "notes.json").write_text(json.dumps([{"id": 1, "body": existing}]))
    r = run(cmd, tmp_path, "--outcome", outcome, "--conclusion", "x")
    assert r.returncode == 0 and "already" in r.stdout
    assert len(notes(tmp_path)) == 1


@pytest.mark.parametrize("cmd", TWINS)
def test_done_after_the_plan_phase_ended_note_is_recorded(cmd, tmp_path):
    """A run halted for decision records leaves `factory-run:ended`; the same
    run, resumed, opens its MR. That `done` must reach the issue."""
    (tmp_path / "notes.json").write_text(json.dumps([
        {"id": 1, "body": f"<!-- factory-run:ended run={RUN} issue=1516 reason=decision-records -->\nproposals"}]))
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "x", "--mr-url", MR)
    assert r.returncode == 0, r.stderr
    assert len(notes(tmp_path)) == 2
    assert "outcome=done" in notes(tmp_path)[0]["body"] and "earlier record (`ended`)" in notes(tmp_path)[0]["body"]


def _busy_thread(n):
    return [{"id": 500 - i, "body": f"comment {i}"} for i in range(n)]


@pytest.mark.parametrize("cmd", TWINS)
def test_a_github_issue_with_100_comments_gets_one_record(cmd, tmp_path):
    """GitHub lists comments oldest first, 100 a page. Before the fix the
    read-back never saw the new record: three posts, then exit 1."""
    (tmp_path / "notes.json").write_text(json.dumps(_busy_thread(100)))
    gh = {"ISSUE_PROVIDER": "github", "FAKE_PAGE_SIZE": "100"}
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", issue_ref="tikalk/adlc-team-skills#7", env_extra=gh)
    assert r.returncode == 0, r.stdout + r.stderr
    calls = (tmp_path / "calls.log").read_text().splitlines()
    assert [c for c in calls if c.startswith("POST")] == ["POST repos/tikalk/adlc-team-skills/issues/7/comments"]
    assert len(notes(tmp_path)) == 101
    # …and the next call of the same run finds it on the second page.
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", issue_ref="tikalk/adlc-team-skills#7", env_extra=gh)
    assert r.returncode == 0 and "already" in r.stdout
    assert len(notes(tmp_path)) == 101


@pytest.mark.parametrize("cmd", TWINS)
def test_a_gitlab_record_older_than_one_page_is_found(cmd, tmp_path):
    record = {"id": 1, "body": f"<!-- factory-mission:step=complete status=completed run={RUN} type=decision outcome=done -->"}
    (tmp_path / "notes.json").write_text(json.dumps(_busy_thread(100) + [record]))
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", FAKE_PAGE_SIZE="100")
    assert r.returncode == 0 and "already" in r.stdout
    assert len(notes(tmp_path)) == 101


@pytest.mark.parametrize("cmd", TWINS)
def test_another_runs_record_does_not_count(cmd, tmp_path):
    (tmp_path / "notes.json").write_text(json.dumps([
        {"id": 1, "body": f"<!-- factory-mission:step=complete status=completed run={RUN}x type=decision outcome=done -->"}]))
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "x").returncode == 0
    assert len(notes(tmp_path)) == 2


@pytest.mark.parametrize("cmd", TWINS)
def test_a_workflow_run_says_the_completion_gate_still_follows(cmd, tmp_path):
    out = tmp_path / "step-output.json"
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "x", "--mr-url", MR,
            env_extra={"ADLC_RUN_ID": "ca40c5d6", "ADLC_STEP_OUTPUT": str(out)})
    assert r.returncode == 0, r.stderr
    body = notes(tmp_path)[0]["body"]
    assert "run=ca40c5d6 " in body and "**Next:** the completion gate" in body


@pytest.mark.parametrize("cmd", TWINS)
def test_details_file_is_carried_verbatim(cmd, tmp_path):
    (tmp_path / "pow.md").write_text("**Proof of work:** 2 of 3 Definition-of-Done item(s) done, 1 skipped:\n- **x** — skipped: y\n")
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "x", "--details-file", str(tmp_path / "pow.md"))
    assert r.returncode == 0, r.stderr
    body = notes(tmp_path)[0]["body"]
    assert "**Proof of work:** 2 of 3" in body and body.rstrip().endswith(f"**Run:** {RUN}")


@pytest.mark.parametrize("cmd", TWINS)
def test_a_lost_post_fails(cmd, tmp_path):
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", FAKE_DROP="1")
    assert r.returncode == 1 and "not on" in r.stderr
    assert len([l for l in (tmp_path / "calls.log").read_text().splitlines() if l.startswith("POST")]) == 3


@pytest.mark.parametrize("cmd", TWINS)
def test_the_trackers_own_error_is_in_the_error_line(cmd, tmp_path):
    """A 401, a 403 and a 404 all read "cannot read the notes"; the tracker
    CLI prints the HTTP status on stderr, and that line is now kept."""
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", FAKE_READ_FAIL="1")
    assert r.returncode == 2 and "cannot read the notes" in r.stderr and "fake glab: 500" in r.stderr
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", FAKE_REFUSE="1")
    assert r.returncode == 1
    assert r.stderr.count("the tracker refused the post — fake glab: 403") == 3


@pytest.mark.parametrize("cmd", TWINS)
def test_an_unreadable_read_back_never_posts_again(cmd, tmp_path):
    """Posting again without seeing the thread is how duplicates were made."""
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", FAKE_READ_FAIL_AFTER_POST="1")
    assert r.returncode == 2, r.stdout + r.stderr
    assert "cannot be read back" in r.stderr and "fake glab: 502" in r.stderr
    assert len(notes(tmp_path)) == 1


def test_both_twins_run_the_same_record_search():
    sh = (SCRIPTS / "bash/post-completion.sh").read_text(encoding="utf-8")
    ps = (SCRIPTS / "powershell/post-completion.ps1").read_text(encoding="utf-8")
    js_sh = sh.split("RECORD_JS='\n", 1)[1].split("\n'\n", 1)[0]
    js_ps = ps.split("$recordJs = @'\n", 1)[1].split("\n'@", 1)[0]
    assert js_sh == js_ps


@pytest.mark.parametrize("cmd", TWINS)
def test_refusals(cmd, tmp_path):
    # No run context: a record names its run, so nothing is posted.
    r = run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", run_id="")
    assert r.returncode == 2 and "no run context" in r.stderr
    # The chart's placeholder is not a run id.
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", run_id="pending").returncode == 2
    assert run(cmd, tmp_path, "--outcome", "maybe", "--conclusion", "a").returncode == 2
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "  ").returncode == 2
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", "--mr-url", "http://x").returncode == 2
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", issue_ref="").returncode == 2
    assert run(cmd, tmp_path, "--outcome", "done", "--conclusion", "a", FAKE_READ_FAIL="1").returncode == 2
    assert notes(tmp_path) == []


def _factory_run_section():
    text = MISSION.read_text(encoding="utf-8")
    start = text.index("## In a factory run")
    return text[start:text.index("## In a local session", start)]


def test_factory_run_section_requires_the_record_on_every_outcome():
    section = _factory_run_section()
    assert "post-completion.sh --issue <issue ref> --outcome <done|no-op|blocked|failed>" in section
    for outcome in ("`done`", "`no-op`", "`blocked`", "`failed`"):
        assert outcome in section, outcome
    assert "never set `ADLC_RUN_ID` yourself" in section
    # Step 4's no-MR note is that one record, not a second note.
    assert "leave the run's one note with step 6" in section


def test_phase_6_retires_the_old_marker_spelling():
    text = MISSION.read_text(encoding="utf-8")
    phase6 = text[text.index("### Phase 6"):]
    assert "post-completion.sh" in phase6
    assert "(marker: `factory-mission:status=completed:run=<run_id>`)" not in text
