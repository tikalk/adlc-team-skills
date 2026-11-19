"""Twin parity: bash/verify-recurrence.sh and powershell/verify-recurrence.ps1 agree.

Covers run/ingest PASS + skips, ORIG-carrier idempotency, cross-second
DUPLICATE, provenance conflicts (exit 2, ledger bytes unchanged), retire
locking, and post-lock VALID ordering. PowerShell cases skip when `pwsh`
is unavailable locally; CI installs pinned PowerShell and executes them.
"""

import json
import os
import shutil
import stat
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
BASH_SCRIPT = ROOT / "skills/factory/factory-learn/scripts/bash/verify-recurrence.sh"
PS_SCRIPT = ROOT / "skills/factory/factory-learn/scripts/powershell/verify-recurrence.ps1"

H1 = "a" * 40
H2 = "b" * 40

MARKER = "<!-- factory-review:step=review run=r1 iter=0 status=completed findings=1 important=0 nits=0 head={h} -->"
HDR = "PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote"

HAVE_PWSH = shutil.which("pwsh") is not None
HAVE_FLOCK = shutil.which("flock") is not None
requires_pwsh = pytest.mark.skipif(not HAVE_PWSH, reason="pwsh not installed (CI runs the twin)")
requires_flock = pytest.mark.skipif(not HAVE_FLOCK, reason="flock unavailable on this host")


def make_gh(bin_dir: Path, head: str, comments: list, reviews: list | None = None):
    gh = bin_dir / "gh"
    gh.write_text(
        "#!/bin/bash\n"
        'if [ "$1" = "api" ]; then\n'
        '  case "$2" in\n'
        f'    *"/pulls/12") printf %s \'{json.dumps({"head": {"sha": head}})}\';;\n'
        f'    *"/issues/12/comments") printf %s \'{json.dumps(comments)}\';;\n'
        f'    *"/pulls/12/reviews") printf %s \'{json.dumps(reviews or [])}\';;\n'
        "    *) printf '[]';;\n"
        "  esac\n"
        "fi\n"
    )
    gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
    return gh


def make_runroot(base: Path, run="r1", repo="o/r", pr="12", head=H1,
                 findings="- [ ] pass:CI check:VH | text here\n"):
    rr = base / "rr"
    d = rr / "runs" / run / "scratchpads"
    d.mkdir(parents=True)
    (rr / "runs" / run / "brief.md").write_text(
        f"review-target-repo: {repo}\nreview-target-pr: {pr}\nreviewed-head: {head}\n")
    (d / "review-findings.txt").write_text(findings)
    return rr


def comment(ts, who, assoc, body):
    return {"created_at": ts, "user": {"login": who}, "author_association": assoc, "body": body}


def env_with(bin_dir: Path):
    e = dict(os.environ)
    e["PATH"] = f"{bin_dir}{os.pathsep}{e['PATH']}"
    return e


def run_bash(args, env):
    return subprocess.run(["bash", str(BASH_SCRIPT)] + args, capture_output=True, text=True, env=env, timeout=60)


def run_ps(args, env):
    return subprocess.run(["pwsh", "-NoProfile", "-File", str(PS_SCRIPT)] + args,
                          capture_output=True, text=True, env=env, timeout=120)


def seed_env(tmp_path, head=H1, who="alice", assoc="MEMBER"):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, head, [comment("2026-01-02T00:00:00Z", who, assoc, MARKER.format(h=head) + " ok")])
    rr = make_runroot(tmp_path, head=head)
    return env_with(bin_dir), rr


def test_twins_exist_and_layout():
    assert BASH_SCRIPT.is_file(), "bash twin missing"
    assert PS_SCRIPT.is_file(), "powershell twin missing"
    assert BASH_SCRIPT.parent.name == "bash"
    assert PS_SCRIPT.parent.name == "powershell"
    assert BASH_SCRIPT.stem == PS_SCRIPT.stem == "verify-recurrence"


def test_both_ingest_pass_and_skip(tmp_path):
    env, rr = seed_env(tmp_path)
    runners = [run_bash] + ([run_ps] if HAVE_PWSH else [])
    if not HAVE_PWSH:
        pytest.skip("pwsh not installed (CI runs the twin)")
    for runner in runners:
        p = runner(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(rr)], env)
        assert p.returncode == 0, p.stdout + p.stderr
        assert "ci\tvh" in p.stdout
    # skip behavior: untrusted author is a diagnostic row, not a failure
    bin_dir = tmp_path / "bin2"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "mallory", "NONE", MARKER.format(h=H1))])
    rr2 = make_runroot(tmp_path / "x")
    for runner in runners:
        p = runner(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(rr2)], env_with(bin_dir))
        assert p.returncode == 0, p.stdout + p.stderr
        assert "untrusted-author" in (p.stdout + p.stderr)


@requires_flock
def test_run_pass_and_idempotent_duplicate_bash(tmp_path):
    env, rr = seed_env(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    p = run_bash(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                  "--ledger", str(ledger)], env)
    assert p.returncode == 0, p.stdout + p.stderr
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1
    before = ledger.read_bytes()
    p2 = run_bash(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                   "--ledger", str(ledger)], env)
    assert p2.returncode == 0, p2.stdout + p2.stderr
    assert "DUPLICATE" in (p2.stdout + p2.stderr)
    assert ledger.read_bytes() == before


@requires_flock
@requires_pwsh
def test_run_pass_and_idempotent_duplicate_ps(tmp_path):
    env, rr = seed_env(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    p = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                "--ledger", str(ledger)], env)
    assert p.returncode == 0, p.stdout + p.stderr
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1
    c = rows[0].split("\t")
    assert c[0] == "12" and c[3] == H1 and c[8] == "live-head"
    before = ledger.read_bytes()
    p2 = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                 "--ledger", str(ledger)], env)
    assert p2.returncode == 0, p2.stdout + p2.stderr
    assert "DUPLICATE" in (p2.stdout + p2.stderr)
    assert "provenance conflict" not in (p2.stdout + p2.stderr)
    assert ledger.read_bytes() == before


@requires_flock
@requires_pwsh
def test_cross_second_rerun_is_duplicate_ps(tmp_path):
    env, rr = seed_env(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    stamps = ["2026-01-02T00:00:00Z", "2026-01-02T00:01:30Z"]
    shim = tmp_path / "bin" / "date"
    shim.write_text(
        "#!/bin/bash\n"
        f'idx_file="{tmp_path}/date_idx"\n'
        'idx=$(cat "$idx_file" 2>/dev/null || echo 0)\n'
        'echo $((idx + 1)) > "$idx_file"\n'
        f'stamps=({" ".join(stamps)})\n'
        'echo "${stamps[$idx]:-${stamps[-1]}}"\n'
    )
    shim.chmod(shim.stat().st_mode | stat.S_IEXEC)
    (tmp_path / "date_idx").write_text("0")
    p = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                "--ledger", str(ledger)], env)
    assert p.returncode == 0, p.stdout + p.stderr
    before = ledger.read_bytes()
    stored_at = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")][0].split("\t")[9]
    p2 = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                 "--ledger", str(ledger)], env)
    combined = p2.stdout + p2.stderr
    assert p2.returncode == 0, combined
    assert "DUPLICATE" in combined
    assert ledger.read_bytes() == before
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1 and rows[0].split("\t")[9] == stored_at


def do_conflict_case(runner, env, rr, ledger, mutate=None, tag="case"):
    before = ledger.read_bytes()
    p = runner(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                "--ledger", str(ledger)], env)
    return p, before


@requires_flock
def test_run_provenance_conflict_bash(tmp_path):
    env, rr = seed_env(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    p = run_bash(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                  "--ledger", str(ledger)], env)
    assert p.returncode == 0, p.stdout + p.stderr
    # conflicting head on the same key
    H3 = "c" * 40
    bin2 = tmp_path / "bin2"
    bin2.mkdir()
    make_gh(bin2, H3, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H3))])
    rr2 = tmp_path / "rr2"
    rr2.mkdir()
    d2 = rr2 / "runs" / "r1" / "scratchpads"
    d2.mkdir(parents=True)
    (rr2 / "runs" / "r1" / "brief.md").write_text(
        f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H3}\n")
    (d2 / "review-findings.txt").write_text("- [ ] pass:CI check:VH | sibling\n")
    before = ledger.read_bytes()
    p2 = run_bash(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr2),
                   "--ledger", str(ledger)], env_with(bin2))
    c2 = p2.stdout + p2.stderr
    assert p2.returncode == 2, c2
    assert "provenance conflict for" in c2
    assert ledger.read_bytes() == before
    assert "DUPLICATE" not in c2 and "VALID" not in p2.stdout


@requires_flock
@requires_pwsh
def test_run_provenance_conflict_ps(tmp_path):
    env, rr = seed_env(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    p = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr),
                "--ledger", str(ledger)], env)
    assert p.returncode == 0, p.stdout + p.stderr
    H3 = "c" * 40
    bin2 = tmp_path / "bin2"
    bin2.mkdir()
    make_gh(bin2, H3, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H3))])
    rr2 = tmp_path / "rr2"
    rr2.mkdir()
    d2 = rr2 / "runs" / "r1" / "scratchpads"
    d2.mkdir(parents=True)
    (rr2 / "runs" / "r1" / "brief.md").write_text(
        f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H3}\n")
    (d2 / "review-findings.txt").write_text("- [ ] pass:CI check:VH | sibling\n")
    before = ledger.read_bytes()
    p2 = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr2),
                 "--ledger", str(ledger)], env_with(bin2))
    c2 = p2.stdout + p2.stderr
    assert p2.returncode == 2, c2
    assert "provenance conflict for" in c2
    assert ledger.read_bytes() == before
    assert "DUPLICATE" not in c2 and "VALID" not in p2.stdout


@requires_pwsh
def test_aggregate_orig_idempotency_and_valid_after_lock_ps(tmp_path):
    """ORIG-carrier: byte-identical re-aggregate is DUPLICATE; VALID only post-lock."""
    env, rr = seed_env(tmp_path)
    payloads = tmp_path / "pay"
    payloads.mkdir()
    (payloads / "pr.json").write_text(json.dumps({"head": {"sha": H1}}))
    bodies = [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1))]
    (payloads / "comments.json").write_text(json.dumps(bodies))
    (payloads / "reviews.json").write_text("[]")
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    cand.write_text(seed)
    base = ["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
            "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
            "--run-root", str(rr), "--allow-fixture"]
    p = run_ps(base, env)
    combined = p.stdout + p.stderr
    assert p.returncode == 0, combined
    assert "VALID\t" in p.stdout, combined
    assert f"VALID\t{seed.strip()}" in p.stdout
    assert ledger.read_bytes() == before
    # conflict: same key, different provenance must exit 2 with no VALID
    cand.write_text(
        f"12\tci\tvh\t{H1}\tr1\t0\tbob\tMEMBER\tlive-head\t2026-01-02T00:00:00Z\tlive-head-at-verification\t\tconflict-note\n"
    )
    p2 = run_ps(base, env)
    combined2 = p2.stdout + p2.stderr
    assert p2.returncode == 2, combined2
    assert "provenance conflict for" in combined2
    assert "VALID\t" not in p2.stdout
    assert ledger.read_bytes() == before


@requires_pwsh
def test_retire_locked_and_view_ps(tmp_path):
    env, rr = seed_env(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    hdr = HDR
    r1 = f"12\tci\tvh\t{H1}\tr1\t0\ta\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn"
    r2 = f"13\tci\tvh\t{H2}\tr2\t0\tb\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn"
    ledger.write_text(hdr + "\n" + r1 + "\n" + r2 + "\n")
    p = run_ps(["retire", "--ledger", str(ledger), "--key", "12\tci\tvh\t0",
                "--reason", "test"], env)
    assert p.returncode == 0, p.stdout + p.stderr
    assert "rows=1" in (p.stdout + p.stderr)
    left = ledger.read_text()
    assert r1 not in left and r2 in left
    # retire used and released the lock: recurrence-view now sees the
    # remaining row from a *second* PR as recurring.
    vl = run_ps(["recurrence-view", "--ledger", str(ledger)], env)
    assert vl.returncode == 0, vl.stdout + vl.stderr
    assert "RECURRING\tci\tvh" not in vl.stdout, "only one PR left: no recurrence"
    with ledger.open("a") as f:
        f.write(r1.replace("12\t", "14\t", 1) + "\n")
    vl2 = run_ps(["recurrence-view", "--ledger", str(ledger)], env)
    assert vl2.returncode == 0, vl2.stdout + vl2.stderr
    assert "RECURRING\tci\tvh" in vl2.stdout


@requires_pwsh
def test_missing_and_invalid_inputs_ps(tmp_path):
    env, rr = seed_env(tmp_path)
    p = run_ps(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr)], env)
    assert p.returncode == 2
    p2 = run_ps(["bogus-cmd", "--ledger", "x"], env)
    assert p2.returncode == 2
    p3 = run_ps(["aggregate", "--ledger", "x", "--candidates", "y",
                 "--repo", "o/r", "--pr", "12", "--run-root", "z"], env)
    assert p3.returncode == 2
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text(HDR + "\n")
    p4 = run_ps(["retire", "--ledger", str(ledger), "--key", "badkey", "--reason", "x"], env)
    assert p4.returncode == 2


def _active_runners():
    return [("bash", run_bash)] + ([("pwsh", run_ps)] if HAVE_PWSH else [])


@requires_flock
def test_twin_marker_newline_and_traversal_rejected(tmp_path):
    """Both twins block newline/tab spoof in run= and ../ path traversal (F1)."""
    for label, runner in _active_runners():
        sub = tmp_path / label
        bin_dir = sub / "bin"
        bin_dir.mkdir(parents=True)
        rr = make_runroot(sub / "rr", head=H1)
        outside = sub / "rr" / "outside" / "scratchpads"
        outside.mkdir(parents=True)
        (sub / "rr" / "outside" / "brief.md").write_text(
            f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H1}\n"
        )
        (outside / "review-findings.txt").write_text("- [ ] pass:sec check:escape | bad\n")
        spoof = (
            f"<!-- factory-review:step=review head={H1} "
            f"run=dummy\n2099-12-31T23:59:59Z\tspoofed-owner\tOWNER\tok\t{H1}\tr1\t0\t0 -->"
        )
        trav = f"<!-- factory-review:step=review head={H1} run=../outside iter=0 -->"
        make_gh(
            bin_dir,
            H1,
            [
                comment("2026-01-01T00:00:00Z", "mallory", "NONE", spoof),
                comment("2026-01-02T00:00:00Z", "alice", "MEMBER", trav),
            ],
        )
        ledger = sub / "ledger.tsv"
        p = runner(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
        assert p.returncode == 0, f"{label}: {p.stdout}{p.stderr}"
        rows = [l for l in ledger.read_text().splitlines()[1:] if l.strip()]
        assert rows == [], f"{label} wrote forged rows: {rows}"


@requires_flock
def test_twin_layer_p_scoped_to_winner_and_no_dup_sidecars(tmp_path):
    """Both twins ignore NONE bystander prose (F2), strip multi-line HTML comments, and leave no .dup.tmp files (F8)."""
    for label, runner in _active_runners():
        sub = tmp_path / label
        bin_dir = sub / "bin"
        bin_dir.mkdir(parents=True)
        rr = make_runroot(sub / "rr", head=H1, findings="- [ ] pass:CI check:VH | ok\n")
        winner = (
            MARKER.format(h=H1)
            + "\n<!-- multiline\npass:hidden check:comment\n-->\n"
            + "Also pass:ghost check:unmatched in winner prose.\n"
        )
        make_gh(
            bin_dir,
            H1,
            [
                comment("2026-01-01T00:00:00Z", "mallory", "NONE", "pass:ci check:vh pass:poison check:none"),
                comment("2026-01-02T00:00:00Z", "alice", "MEMBER", winner),
            ],
        )
        ledger = sub / "ledger.tsv"
        env = env_with(bin_dir)
        p1 = runner(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env)
        assert p1.returncode == 0, f"{label}: {p1.stdout}{p1.stderr}"
        assert f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER" in ledger.read_text()
        assert "ghost\tunmatched\t-\t-\t-\tfinding-diverged" in p1.stdout
        assert "poison" not in p1.stdout and "hidden" not in p1.stdout

        p2 = runner(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env)
        assert p2.returncode == 0, f"{label}: {p2.stdout}{p2.stderr}"
        assert "DUPLICATE\t" in p2.stdout
        leftover_dups = list(sub.glob("*.dup.tmp.*"))
        assert leftover_dups == [], f"{label} left sidecar temp files: {leftover_dups}"


@requires_flock
def test_twin_aggregate_target_mismatch_and_cross_second_rerun(tmp_path):
    """Both twins enforce brief repo/pr in aggregate (F5), ignore NONE prose (F2), and treat cross-second reruns as DUPLICATE (F6)."""
    for label, runner in _active_runners():
        sub = tmp_path / label
        rr = sub / "rr"
        for rname, brepo, bpr in [("r_bad_repo", "other/repo", "12"), ("r_bad_pr", "o/r", "99"), ("r_ok", "o/r", "12")]:
            sp = rr / "runs" / rname / "scratchpads"
            sp.mkdir(parents=True)
            (rr / "runs" / rname / "brief.md").write_text(
                f"review-target-repo: {brepo}\nreview-target-pr: {bpr}\nreviewed-head: {H1}\n"
            )
            (sp / "review-findings.txt").write_text("- [ ] pass:CI check:VH | ok\n")
        pay = sub / "pay"
        pay.mkdir()
        (pay / "pr.json").write_text(json.dumps({"head": {"sha": H1}}))
        (pay / "comments.json").write_text(
            json.dumps([
                comment("2026-01-01T00:00:00Z", "mallory", "NONE", "pass:poison check:none"),
                comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1).replace("run=r1", "run=r_bad_repo")),
                comment("2026-01-02T00:00:01Z", "alice", "MEMBER", MARKER.format(h=H1).replace("run=r1", "run=r_bad_pr")),
                comment("2026-01-02T00:00:02Z", "alice", "MEMBER", MARKER.format(h=H1).replace("run=r1", "run=r_ok") + "\npass:extra check:prose\n"),
            ])
        )
        (pay / "reviews.json").write_text("[]")
        cand = sub / "cand.tsv"
        cand.write_text(
            f"12\tci\tvh\t{H1}\tr_bad_repo\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
            f"12\tci\tvh\t{H1}\tr_bad_pr\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
            f"12\tci\tvh\t{H1}\tr_ok\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
        )
        bin_dir = sub / "bin"
        bin_dir.mkdir()
        idx_file = sub / "date_idx"
        idx_file.write_text("0")
        date_shim = bin_dir / "date"
        date_shim.write_text(
            "#!/bin/bash\n"
            f'i=$(cat "{idx_file}")\n'
            f'echo $((i + 1)) > "{idx_file}"\n'
            'stamps=(2026-01-06T00:00:01Z 2026-01-06T00:00:08Z)\n'
            'echo "${stamps[$i]:-2026-01-06T00:00:08Z}"\n'
        )
        date_shim.chmod(date_shim.stat().st_mode | stat.S_IEXEC)
        env = env_with(bin_dir)
        ledger = sub / "ledger.tsv"
        args = [
            "aggregate", "--ledger", str(ledger), "--candidates", str(cand),
            "--fixture-payloads", str(pay), "--repo", "o/r", "--pr", "12",
            "--run-root", str(rr), "--allow-fixture",
        ]
        p1 = runner(args, env)
        assert p1.returncode == 0, f"{label}: {p1.stdout}{p1.stderr}"
        assert f"REJECT\tcandidate-mismatch\t12\tci\tvh\t{H1}\tr_bad_repo\t" in p1.stdout
        assert f"REJECT\tcandidate-mismatch\t12\tci\tvh\t{H1}\tr_bad_pr\t" in p1.stdout
        assert f"VALID\t12\tci\tvh\t{H1}\tr_ok\t0\talice\tMEMBER" in p1.stdout
        before = ledger.read_bytes()

        p2 = runner(args, env)
        assert p2.returncode == 0, f"{label}: {p2.stdout}{p2.stderr}"
        assert f"VALID\t12\tci\tvh\t{H1}\tr_ok\t0\talice\tMEMBER" in p2.stdout
        assert "provenance conflict" not in (p2.stdout + p2.stderr)
        assert ledger.read_bytes() == before
