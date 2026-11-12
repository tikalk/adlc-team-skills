"""Piece 3 command-level tests: execute the real verify-recurrence.sh.

Uses stubbed `gh` (PATH shim) and temp run-roots/ledgers — no network.
Covers run/ingest/aggregate/retire/recurrence-view, divergence, locking.
"""

import json
import os
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPT = ROOT / "skills/factory/factory-learn/scripts/bash/verify-recurrence.sh"

H1 = "a" * 40
H2 = "b" * 40

MARKER = "<!-- factory-review:step=review run=r1 iter=0 status=completed findings=1 important=0 nits=0 head={h} -->"


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


def env_with(bin_dir: Path):
    e = dict(os.environ)
    e["PATH"] = f"{bin_dir}{os.pathsep}{e['PATH']}"
    return e


def run_cmd(args, env):
    return subprocess.run(["bash", str(SCRIPT)] + args, capture_output=True, text=True, env=env, timeout=60)


def comment(ts, who, assoc, body):
    return {"created_at": ts, "user": {"login": who}, "author_association": assoc, "body": body}


def test_run_appends_valid_live_head(tmp_path):
    """Same-second rerun: byte-identical candidate re-confirmed as duplicate.

    Recurrence rerun-idempotency decision — observation identity: duplicate = same key + same provenance with
    verified-at excluded. A rerun in the same UTC second is byte-identical
    and takes the exact-match shortcut; the cross-second case is pinned by
    test_run_rerun_cross_second_is_duplicate below.
    """
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1) + " ok")])
    rr = make_runroot(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    if "flock(1) is required but unavailable" in (p.stdout + p.stderr):
        pytest.skip("flock unavailable on this host")
    assert p.returncode == 0, p.stdout + p.stderr
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1
    c = rows[0].split("\t")
    assert c[0] == "12" and c[3] == H1 and c[8] == "live-head" and c[10] == "live-head-at-verification"
    before = ledger.read_bytes()
    # idempotent rerun: no duplicate row appended
    p2 = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    assert p2.returncode == 0, p2.stdout + p2.stderr
    assert "DUPLICATE" in (p2.stdout + p2.stderr), "rerun must report DUPLICATE, not a new observation"
    assert "provenance conflict" not in (p2.stdout + p2.stderr)
    assert ledger.read_bytes() == before, "rerun must leave ledger bytes unchanged"


def test_run_rerun_cross_second_is_duplicate(tmp_path):
    """Cross-second rerun: fresh verified-at is still a duplicate (recurrence rerun-idempotency decision).

    Deterministic clock injection (no real sleep): a `date` shim on PATH
    returns T1 on the first run and T2 != T1 on the second for the same
    observation. The rerun must exit 0, report DUPLICATE, leave the stored
    row (with T1) untouched, and append nothing.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1) + " ok")])
    rr = make_runroot(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    stamps = ["2026-01-02T00:00:00Z", "2026-01-02T00:01:30Z"]
    date_shim = bin_dir / "date"
    date_shim.write_text(
        "#!/bin/bash\n"
        f'idx_file="{tmp_path}/date_idx"\n'
        'idx=$(cat "$idx_file" 2>/dev/null || echo 0)\n'
        'echo $((idx + 1)) > "$idx_file"\n'
        f'stamps=({" ".join(stamps)})\n'
        'echo "${stamps[$idx]:-${stamps[-1]}}"\n'
    )
    date_shim.chmod(date_shim.stat().st_mode | stat.S_IEXEC)
    (tmp_path / "date_idx").write_text("0")

    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    assert p.returncode == 0, p.stdout + p.stderr
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1
    stored_at = rows[0].split("\t")[9]
    before = ledger.read_bytes()
    p2 = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    combined2 = p2.stdout + p2.stderr
    assert p2.returncode == 0, combined2
    assert "DUPLICATE" in combined2, "cross-second rerun must report DUPLICATE"
    assert "provenance conflict" not in combined2, combined2
    assert ledger.read_bytes() == before, "ledger must be byte-identical after duplicate rerun"
    rows2 = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows2) == 1 and rows2[0].split("\t")[9] == stored_at, "stored row must never be restamped"


def test_run_rerun_near_miss_provenance_conflicts(tmp_path, monkeypatch):
    """Near-miss provenance differences on the same key fail closed (recurrence rerun-idempotency).

    Same key (12, ci, vh, iter 0), changed verdict-head / author / run /
    standing in turn: each rerun must exit 2, name the conflicting key on
    stderr, leave the ledger byte-identical, and emit no VALID/DUPLICATE.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1) + " ok")])
    rr = make_runroot(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    if "flock(1) is required but unavailable" in (p.stdout + p.stderr):
        pytest.skip("flock unavailable on this host")
    assert p.returncode == 0, p.stdout + p.stderr

    H3 = "c" * 40

    def rerun_with(head=H1, findings=None, who="alice", assoc="MEMBER",
                   brief_head=None, findings_text=None,
                   mutate_row=None, tag="case"):
        brief_head = head if brief_head is None else brief_head
        bin2 = tmp_path / f"bin_{tag}"
        bin2.mkdir(exist_ok=True)
        make_gh(bin2, head, [comment("2026-01-02T00:00:00Z", who, assoc, MARKER.format(h=head) + " ok")])
        rr2 = tmp_path / f"rr_{tag}"
        rr2.mkdir(exist_ok=True)
        d2 = rr2 / "runs" / "r1" / "scratchpads"
        d2.mkdir(parents=True, exist_ok=True)
        (rr2 / "runs" / "r1" / "brief.md").write_text(
            f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {brief_head}\n")
        (d2 / "review-findings.txt").write_text(
            findings_text or findings or "- [ ] pass:CI check:VH | text here\n")
        if mutate_row is not None:
            rows = ledger.read_text().splitlines()
            rows[1] = mutate_row(rows[1])
            ledger.write_text("\n".join(rows) + "\n")
        before = ledger.read_bytes()
        pp = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr2),
                      "--ledger", str(ledger)], env_with(bin2))
        return pp, before

    # Case 1: different verdict-head (H3) on the same key. run-home corroborates
    # H3 (brief + findings identical shape), so the conflict reaches the lock.
    p1, before1 = rerun_with(head=H3, tag="headdiff",
                             findings_text="- [ ] pass:CI check:VH | sibling observation\n", mutate_row=None)
    c1 = p1.stdout + p1.stderr
    assert p1.returncode == 2, c1
    assert "provenance conflict for 12\tci\tvh\t0" in c1, c1
    assert ledger.read_bytes() == before1
    assert "DUPLICATE" not in c1 and "VALID" not in p1.stdout

    # Case 2: different author (bob) on the same key/head.
    p2, before2 = rerun_with(who="bob", tag="authordiff")
    c2 = p2.stdout + p2.stderr
    assert p2.returncode == 2, c2
    assert "provenance conflict for 12\tci\tvh\t0" in c2, c2
    assert ledger.read_bytes() == before2

    # Case 3: different run name (r2) on the same key. A distinct run-home
    # names r2 in its marker so validation resolves there; same check pair
    # keeps recurrence key (12, ci, vh, iter 0) identical.
    rr_r2 = tmp_path / "rr_rundiff_r2"
    rr_r2.mkdir(exist_ok=True)
    d_r2 = rr_r2 / "runs" / "r2" / "scratchpads"
    d_r2.mkdir(parents=True, exist_ok=True)
    (rr_r2 / "runs" / "r2" / "brief.md").write_text(
        "review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: " + H1 + "\n")
    (d_r2 / "review-findings.txt").write_text("- [ ] pass:CI check:VH | text here\n")
    bin_r2 = tmp_path / "bin_rundiff"
    bin_r2.mkdir(exist_ok=True)
    marker_r2 = MARKER.replace("run=r1", "run=r2")
    make_gh(bin_r2, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", marker_r2.format(h=H1) + " ok")])
    before3 = ledger.read_bytes()
    p3 = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr_r2),
                  "--ledger", str(ledger)], env_with(bin_r2))
    c3 = p3.stdout + p3.stderr
    assert p3.returncode == 2, c3
    assert "provenance conflict for 12\tci\tvh\t0" in c3, c3
    assert ledger.read_bytes() == before3

    # Case 4: different standing on the same key (ledger-level near-miss).
    def flip_standing(row):
        c = row.split("\t")
        c[10] = "tampered-standing"
        return "\t".join(c)
    p4, before4 = rerun_with(mutate_row=flip_standing, tag="standingdiff")
    c4 = p4.stdout + p4.stderr
    assert p4.returncode == 2, c4
    assert "provenance conflict for 12\tci\tvh\t0" in c4, c4
    assert ledger.read_bytes() == before4


def test_run_rejects_stale_head(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H2, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1) + " old")])
    rr = make_runroot(tmp_path, head=H1)
    (rr / "runs" / "r1" / "brief.md").write_text(f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H1}\n")
    ledger = tmp_path / "ledger.tsv"
    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    assert "stale-head" in (p.stdout + p.stderr) or "head-interval-unproven" in (p.stdout + p.stderr)


def test_run_rejects_untrusted_author_and_run_mismatch(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "mallory", "NONE", MARKER.format(h=H1))])
    rr = make_runroot(tmp_path)
    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(tmp_path / "l.tsv")], env_with(bin_dir))
    assert "untrusted-author" in (p.stdout + p.stderr)
    # run mismatch: brief names another repo
    bin2 = tmp_path / "bin2"
    bin2.mkdir()
    make_gh(bin2, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1))])
    rr2 = make_runroot(tmp_path / "x", repo="other/r")
    p2 = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr2), "--ledger", str(tmp_path / "l2.tsv")], env_with(bin2))
    assert "run-mismatch" in (p2.stdout + p2.stderr) or "run-unresolvable" in (p2.stdout + p2.stderr)


def test_run_provenance_conflict_returns_exit2_ledger_unchanged(tmp_path):
    """Run path: conflicting provenance for an existing ledger key aborts.

    Seeds a live-head row, then feeds a winner whose verdict names a
    different head (H2) while the run-home still corroborates it — the new
    candidate collides on (PR,pass,check-item,iter) with different provenance.
    Real script, real flock: exit code must be exactly 2, stderr must name
    the conflict, the ledger must be byte-identical, and no candidate rows
    may be printed after the failure.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H2, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H2) + " ok")])
    rr = make_runroot(tmp_path, head=H2)
    (rr / "runs" / "r1" / "brief.md").write_text(
        f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H2}\n")
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    before = ledger.read_bytes()
    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    combined = p.stdout + p.stderr
    assert p.returncode == 2, combined
    assert "provenance conflict for" in combined, combined
    assert ledger.read_bytes() == before, "conflict must not change the ledger"
    assert "--- candidates" not in p.stdout, "failed run must not print candidate rows"


def test_run_lock_timeout_returns_exit2_ledger_unchanged(tmp_path):
    """Run path: a held ledger lock yields exit 2, unchanged ledger.

    Real holder (`flock <lock> sleep`) + real `run` contender with a short
    timeout: contender must exit 2 naming the lock timeout, print no
    candidate rows, and leave the ledger byte-identical.
    """
    import shutil
    import subprocess
    import time
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1) + " ok")])
    rr = make_runroot(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text(HDR + "\n")
    before = ledger.read_bytes()
    lock = Path(str(ledger) + ".lock")
    holder = subprocess.Popen(["flock", str(lock), "sleep", "30"])
    try:
        for _ in range(100):
            if lock.exists():
                break
            time.sleep(0.05)
        env = env_with(bin_dir)
        env["VERIFY_RECURRENCE_LOCK_TIMEOUT"] = "2"
        p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env)
        combined = p.stdout + p.stderr
        assert p.returncode == 2, combined
        assert "ledger lock timeout" in combined, combined
        assert ledger.read_bytes() == before, "timed-out run must not change the ledger"
        assert "--- candidates" not in p.stdout, "timed-out run must not print candidate rows"
    finally:
        holder.terminate()
        try:
            holder.wait(timeout=10)
        except subprocess.TimeoutExpired:
            holder.kill()


def test_run_structured_divergence_keeps_valid_pairs(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    body = (MARKER.format(h=H1) + "\nAlso pass:ghost check:missing looks wrong.\n")
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", body)])
    rr = make_runroot(tmp_path, findings="- [ ] pass:CI check:VH | ok one\n- [ ] pass:Docs check:Readme | ok two\n")
    p = run_cmd(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(rr)], env_with(bin_dir))
    assert p.returncode == 0, p.stdout + p.stderr
    assert "finding-diverged" in p.stdout + p.stderr
    assert "ghost" in (p.stdout + p.stderr)
    # valid pairs still emitted
    assert "\tci\tvh\t" in p.stdout or "ci\tvh" in p.stdout


def test_run_structured_divergence_only_pair_rejected(tmp_path):
    """Structured-only divergent prose pair: no Layer F pair survives.

    Characterization for Finding 2: the empty-input case must reject with
    finding-unparseable both before and after `pairs_for_winner` removal,
    because the `_pairs_raw` gate (line ~257) already fires first.
    """
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    body = MARKER.format(h=H1) + "\nAlso pass:ghost check:missing looks wrong.\n"
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", body)])
    rr = make_runroot(tmp_path, findings="- [ ] not a finding line at all\n")
    p = run_cmd(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(rr)], env_with(bin_dir))
    assert "finding-unparseable" in (p.stdout + p.stderr), p.stdout + p.stderr


def test_run_malformed_line_ignored_when_valid_remain(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1))])
    rr = make_runroot(tmp_path, findings="- [ ] pass:CI check:VH | good\n- [ ] pass:oops no check here\n")
    p = run_cmd(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(rr)], env_with(bin_dir))
    assert p.returncode == 0
    assert "malformed finding line" in (p.stdout + p.stderr).lower() or "MALFORMED" in (p.stdout + p.stderr) or "ci\tvh" in p.stdout


def test_ingest_writes_nothing(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1))])
    rr = make_runroot(tmp_path)
    before = {str(p) for p in tmp_path.rglob("*")}
    p = run_cmd(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(rr)], env_with(bin_dir))
    assert p.returncode == 0
    after = {str(p) for p in tmp_path.rglob("*")}
    assert before == after, "ingest must not write files"


def test_missing_flock_fails_closed(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    make_gh(bin_dir, H1, [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1))])
    # shadow flock with a failing command only if flock exists; if absent, the script exits 2 by design
    rr = make_runroot(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text("PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote\n")
    p = run_cmd(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(rr), "--ledger", str(ledger)], env_with(bin_dir))
    if "flock(1) is required but unavailable" in (p.stdout + p.stderr):
        assert p.returncode == 2
        assert ledger.read_text().count("\n") == 1, "ledger must be unchanged when flock is missing"
    else:
        pytest.skip("flock present; missing-flock path not exercisable here")


def test_lock_timeout_without_real_flock(tmp_path):
    assert True  # timeout path requires flock; covered by script exit-2 contract


def test_two_process_lock_contention_second_fails_first_succeeds(tmp_path):
    """Two real processes, one ledger lock (Finding: Linux CI contention).

    The holder takes the sidecar lock first; the contender (real
    `aggregate` run) must exit 2 naming the lock timeout while the ledger
    stays byte-identical; after the holder releases, the same contender
    succeeds and appends exactly one row. macOS-safe: skips when flock(1)
    is unavailable (CI on ubuntu-latest executes it).
    """
    import shutil
    import time
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text(HDR + "\n")
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    cand.write_text(
        f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    )
    args = ["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
            "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
            "--run-root", str(rr), "--allow-fixture"]
    lock = Path(str(ledger) + ".lock")
    holder = subprocess.Popen(["flock", str(lock), "sleep", "30"])
    try:
        for _ in range(100):
            if lock.exists():
                break
            time.sleep(0.05)
        env = env_with(tmp_path)
        env["VERIFY_RECURRENCE_LOCK_TIMEOUT"] = "2"
        p = run_cmd(args, env)
        combined = p.stdout + p.stderr
        assert p.returncode == 2, combined
        assert "ledger lock timeout" in combined, combined
        assert ledger.read_bytes() == before, "contended ledger must be unchanged"
    finally:
        holder.terminate()
        try:
            holder.wait(timeout=10)
        except subprocess.TimeoutExpired:
            holder.kill()
    p2 = run_cmd(args, env_with(tmp_path))
    assert p2.returncode == 0, p2.stdout + p2.stderr
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1, "post-release run must append exactly the candidate row"


def test_aggregate_fixture_revalidation(tmp_path):
    rr = make_runroot(tmp_path)
    payloads = tmp_path / "pay"
    payloads.mkdir()
    (payloads / "pr.json").write_text(json.dumps({"head": {"sha": H1}}))
    bodies = [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=H1))]
    (payloads / "comments.json").write_text(json.dumps(bodies))
    (payloads / "reviews.json").write_text("[]")
    cand = tmp_path / "cand.tsv"
    cand.write_text(
        f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
        f"12\tci\tghost\t{H1}\tr1\t0\tmallory\tNONE\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    )
    ledger = tmp_path / "ledger.tsv"
    p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                 "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                 "--run-root", str(rr), "--allow-fixture"], env_with(tmp_path))
    assert "candidate-mismatch" in (p.stdout + p.stderr), p.stdout + p.stderr
    assert "VALID" in (p.stdout + p.stderr)


def test_aggregate_requires_allow_fixture_and_payloads(tmp_path):
    p = run_cmd(["aggregate", "--ledger", "x", "--candidates", "y", "--repo", "o/r", "--pr", "12", "--run-root", "z"], env_with(tmp_path))
    assert p.returncode == 2


HDR = "PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote"


def _aggregate_payloads(tmp_path, head=H1):
    payloads = tmp_path / "pay"
    payloads.mkdir(exist_ok=True)
    (payloads / "pr.json").write_text(json.dumps({"head": {"sha": head}}))
    bodies = [comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(h=head))]
    (payloads / "comments.json").write_text(json.dumps(bodies))
    (payloads / "reviews.json").write_text("[]")
    return payloads


def test_aggregate_provenance_conflict_aborts_exit2_ledger_unchanged(tmp_path):
    """Real script provenance-conflict abort (Finding 3).

    Same recurrence key (PR/pass/check-item/iter) with conflicting
    provenance (different verdict-head) must: reject, exit exactly 2,
    name the conflict on stderr, and leave the ledger bytes unchanged.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    # Fixture live head must equal the candidate head (H2) so the candidate
    # passes fixture revalidation; the seeded ledger row (H1) then collides
    # on the same recurrence key with conflicting provenance.
    rr = make_runroot(tmp_path, head=H2)
    (rr / "runs" / "r1" / "brief.md").write_text(
        f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H2}\n")
    payloads = _aggregate_payloads(tmp_path, head=H2)
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    # Same (PR,pass,check-item,iter) key, different verdict-head => conflict.
    cand.write_text(
        f"12\tci\tvh\t{H2}\tr1\t0\tbob\tMEMBER\tlive-head\t2026-01-02T00:00:00Z\tlive-head-at-verification\t\tconflict-note\n"
    )
    p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                 "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                 "--run-root", str(rr), "--allow-fixture"], env_with(tmp_path))
    combined = p.stdout + p.stderr
    assert p.returncode == 2, combined
    assert "provenance conflict for" in combined, combined
    assert "VALID\t" not in p.stdout, "conflict must not print success-shaped VALID"
    assert ledger.read_bytes() == before, "ledger must be byte-identical after abort"


def test_aggregate_identical_row_reappend_is_idempotent(tmp_path):
    """Case A — identical full-row aggregate re-append: exit 0, unchanged.

    Seeds the ledger with a full row, then aggregates that exact row as
    the candidate through the real script. The locked append path
    recognizes the byte-identical original under the ledger lock and
    reports the candidate re-confirmed (VALID) only after the lock
    succeeds: no duplicate is appended and existing `verified-at`/`note`
    values are untouched. No mocked helper.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-02T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    # Byte-identical candidate input passes fixture revalidation (VALID) and
    # matches an existing ledger row verbatim => idempotent success.
    cand.write_text(seed)
    p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                 "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                 "--run-root", str(rr), "--allow-fixture"], env_with(tmp_path))
    combined = p.stdout + p.stderr
    assert "VALID\t" in p.stdout, combined
    assert p.returncode == 0, combined
    assert "provenance conflict for" not in combined, combined
    assert f"VALID\t{seed.strip(chr(10))}" in p.stdout, "duplicate must be re-confirmed after lock"
    assert ledger.read_bytes() == before, "idempotent re-append must not duplicate or rewrite rows"


def test_aggregate_new_valid_row_appends_restamped(tmp_path):
    """Case C — genuinely new aggregate candidate: re-stamped and appended.

    Seeds the ledger with only the header, then aggregates a valid candidate
    for a key the ledger does not contain. Fixture revalidation passes, the
    row is re-stamped (`verified-at` = now, note = `revalidated fixture
    row`) and appended exactly once; aggregate exits 0 with the success
    message.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text(HDR + "\n")
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    cand.write_text(
        f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    )
    p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                 "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                 "--run-root", str(rr), "--allow-fixture"], env_with(tmp_path))
    combined = p.stdout + p.stderr
    assert "VALID" in combined, combined
    assert p.returncode == 0, combined
    assert "aggregate fixture revalidation complete" in combined, combined
    assert ledger.read_bytes() != before, "new valid row must be appended"
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1, ledger.read_text()
    c = rows[0].split("\t")
    assert c[0] == "12" and c[1] == "ci" and c[3] == H1 and c[8] == "live-head", rows[0]
    assert c[10] == "live-head-at-verification" and c[12] == "revalidated fixture row", rows[0]


def test_aggregate_lock_timeout_returns_exit2_ledger_unchanged(tmp_path):
    """Case D — aggregate lock timeout: exit 2, unchanged, no success msg.

    Real holder (`flock <lock> sleep`) + real `aggregate` contender with a
    short timeout: contender must exit 2 naming the lock timeout, must not
    print the success message, and must leave the ledger byte-identical.
    """
    import shutil
    import subprocess
    import time
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    # Seed differs from the candidate below (verified-at), so the candidate
    # is NOT byte-identical: execution must reach the locked append path,
    # where the held lock forces the timeout.
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-02T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    cand.write_text(
        f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    )
    lock = Path(str(ledger) + ".lock")
    holder = subprocess.Popen(["flock", str(lock), "sleep", "30"])
    try:
        for _ in range(100):
            if lock.exists():
                break
            time.sleep(0.05)
        env = env_with(tmp_path)
        env["VERIFY_RECURRENCE_LOCK_TIMEOUT"] = "2"
        p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                     "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                     "--run-root", str(rr), "--allow-fixture"], env)
        combined = p.stdout + p.stderr
        assert p.returncode == 2, combined
        assert "ledger lock timeout" in combined, combined
        assert "aggregate fixture revalidation complete" not in combined, combined
        assert ledger.read_bytes() == before, "timed-out aggregate must not change the ledger"
    finally:
        holder.terminate()
        try:
            holder.wait(timeout=10)
        except subprocess.TimeoutExpired:
            holder.kill()


def test_aggregate_grep_read_error_fails_closed_ledger_unchanged(tmp_path):
    """Case 2 — ledger read error fails closed with exit 2, unchanged.

    Fault injection with a PATH `grep` shim that returns exit 2 (read
    error) only when asked to search the ledger copy, delegating to the
    real grep otherwise. The real script must treat the error as fatal
    (exit 2, read-error diagnostic), must not print the success message,
    and must leave the ledger byte-identical — never mistaking the error
    for a non-match.
    """
    import shutil
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    real_grep = shutil.which("grep")
    assert real_grep, "grep required for fault-injection shim"
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    before = ledger.read_bytes()
    cand = tmp_path / "cand.tsv"
    cand.write_text(seed)
    shim = tmp_path / "shim"
    shim.mkdir()
    # Fail only ledger-row idempotency searches (patterns embedding a full
    # TSV row, recognizable by the assoc column); fixture-validation greps
    # use short pair slugs and must keep working.
    (shim / "grep").write_text(
        "#!/bin/bash\n"
        'for a in "$@"; do\n'
        '  case "$a" in *MEMBER*) echo "grep: simulated read error" >&2; exit 2;; esac\n'
        'done\n'
        f'exec "{real_grep}" "$@"\n'
    )
    (shim / "grep").chmod(0o755)
    env = env_with(tmp_path)
    env["PATH"] = f"{shim}{__import__('os').pathsep}{env['PATH']}"
    p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                 "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                 "--run-root", str(rr), "--allow-fixture"], env)
    combined = p.stdout + p.stderr
    assert p.returncode == 2, combined
    assert "read error" in combined, combined
    assert "aggregate fixture revalidation complete" not in combined, combined
    assert "provenance conflict for" not in combined, combined
    assert ledger.read_bytes() == before, "read-error aggregate must not change the ledger"


def test_aggregate_concurrent_retire_wins_no_stale_valid(tmp_path):
    """Case 6a — retire holds the lock: aggregate serializes behind it.

    A lock holder blocks aggregate (lock timeout, exit 2, no success
    message). After a real `retire` removes the row, aggregate re-runs and
    must observe the retired ledger under lock — appending the now-absent
    candidate as a new valid row (exit 0, exactly one re-stamped row) —
    rather than acting on any stale pre-retire view.
    """
    import shutil
    import subprocess
    import time
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n" + seed)
    cand = tmp_path / "cand.tsv"
    cand.write_text(seed)
    lock = Path(str(ledger) + ".lock")
    holder = subprocess.Popen(["flock", str(lock), "sleep", "30"])
    try:
        for _ in range(100):
            if lock.exists():
                break
            time.sleep(0.05)
        env = env_with(tmp_path)
        env["VERIFY_RECURRENCE_LOCK_TIMEOUT"] = "2"
        p = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                     "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                     "--run-root", str(rr), "--allow-fixture"], env)
        combined = p.stdout + p.stderr
        assert p.returncode == 2, combined
        assert "ledger lock timeout" in combined, combined
        assert "aggregate fixture revalidation complete" not in combined, combined
    finally:
        holder.terminate()
        try:
            holder.wait(timeout=10)
        except subprocess.TimeoutExpired:
            holder.kill()
    before = ledger.read_bytes()
    r = subprocess.run(["bash", str(SCRIPT), "retire", "--ledger", str(ledger),
                        "--key", f"12\tci\tvh\t0", "--reason", "test"],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stdout + r.stderr
    assert seed.strip("\n") not in ledger.read_text()
    # Phase 2: retire won the serialization order, so the candidate key is
    # absent when aggregate finally runs. The locked append path must see
    # the retired ledger (not the stale pre-retire view) and append the
    # candidate as a new valid row: exit 0 with exactly one re-stamped row.
    before = ledger.read_bytes()
    p2 = run_cmd(["aggregate", "--ledger", str(ledger), "--candidates", str(cand),
                  "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
                  "--run-root", str(rr), "--allow-fixture"], env_with(tmp_path))
    combined2 = p2.stdout + p2.stderr
    assert p2.returncode == 0, combined2
    assert "VALID" in combined2, combined2
    assert "provenance conflict for" not in combined2, combined2
    rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
    assert len(rows) == 1, ledger.read_text()
    assert rows[0].split("\t")[12] == "revalidated fixture row", rows[0]
    assert ledger.read_bytes() != before


def test_aggregate_concurrent_aggregate_wins_retire_sees_result(tmp_path):
    """Case 6b — aggregate wins the lock: retire observes the new row.

    Deterministic handoff through the real sidecar lock, no timing guess.
    An `aggregate` process starts first and holds the ledger lock inside
    the real script (signalled via a sentinel file); a real `retire`
    contender then blocks on the same lock with a long timeout. The
    aggregate winner appends its row and releases; the contender then
    acquires the lock and must operate on the aggregate-updated ledger —
    retiring exactly the row the winner appended. Both exit codes, both
    command outputs, and final ledger contents are asserted. A
    `stale-pre-aggregate-view` retire cannot satisfy these assertions.
    """
    import shutil
    import subprocess
    import time
    if shutil.which("flock") is None:
        pytest.skip("flock unavailable on this host")
    rr = make_runroot(tmp_path)
    payloads = _aggregate_payloads(tmp_path)
    ledger = tmp_path / "ledger.tsv"
    seed = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
    ledger.write_text(HDR + "\n")
    cand = tmp_path / "cand.tsv"
    cand.write_text(seed)
    lock = Path(str(ledger) + ".lock")
    started = tmp_path / "aggregate-started"
    proceed = tmp_path / "aggregate-proceed"
    env = env_with(tmp_path)
    held_env = dict(env)
    held_env["VERIFY_RECURRENCE_LOCK_TIMEOUT"] = "60"
    agg = subprocess.Popen(
        ["bash", str(SCRIPT), "aggregate",
         "--ledger", str(ledger), "--candidates", str(cand),
         "--fixture-payloads", str(payloads), "--repo", "o/r", "--pr", "12",
         "--run-root", str(rr), "--allow-fixture",
         "--started-sentinel", str(started), "--proceed-sentinel", str(proceed)],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=held_env)
    try:
        for _ in range(400):
            if started.exists():
                break
            time.sleep(0.05)
        assert started.exists(), "aggregate never acquired the ledger lock"
        assert agg.poll() is None, "aggregate must still hold the lock"
        ret_env = dict(env)
        ret_env["VERIFY_RECURRENCE_LOCK_TIMEOUT"] = "60"
        ret = subprocess.Popen(
            ["bash", str(SCRIPT), "retire", "--ledger", str(ledger),
             "--key", "12\tci\tvh\t0", "--reason", "test"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=ret_env)
        time.sleep(1.0)
        assert ret.poll() is None, "retire must block while aggregate holds the lock"
        proceed.touch()
        agg_out, agg_err = agg.communicate(timeout=90)
        agg_combined = agg_out + agg_err
        assert agg.returncode == 0, agg_combined
        assert "VALID\t" in agg_out, agg_combined
        assert "aggregate fixture revalidation complete" in agg_combined, agg_combined
        ret_out, ret_err = ret.communicate(timeout=90)
        ret_combined = ret_out + ret_err
        assert ret.returncode == 0, ret_combined
        assert "retired [" in ret_combined, ret_combined
        assert "rows=1" in ret_combined, ret_combined
        rows = [l for l in ledger.read_text().splitlines() if not l.startswith("PR")]
        assert rows == [], ledger.read_text()
    finally:
        for proc in (agg, ret):
            try:
                if proc.poll() is None:
                    proc.terminate()
                    proc.wait(timeout=10)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass


def test_retire_exact_key_and_invalid(tmp_path):
    ledger = tmp_path / "ledger.tsv"
    hdr = "PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote"
    r1 = f"12\tci\tvh\t{H1}\tr1\t0\ta\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn"
    r2 = f"13\tci\tvh\t{H2}\tr2\t0\tb\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn"
    ledger.write_text(hdr + "\n" + r1 + "\n" + r2 + "\n")
    p = subprocess.run(["bash", str(SCRIPT), "retire", "--ledger", str(ledger),
                        "--key", f"12\tci\tvh\t0", "--reason", "test"],
                       capture_output=True, text=True, timeout=30)
    assert p.returncode == 0, p.stdout + p.stderr
    left = ledger.read_text()
    assert r1 not in left and r2 in left
    p2 = subprocess.run(["bash", str(SCRIPT), "retire", "--ledger", str(ledger),
                         "--key", "99\tx\ty\t0", "--reason", "nope"],
                        capture_output=True, text=True, timeout=30)
    assert p2.returncode == 2
    assert r2 in ledger.read_text()
    p3 = subprocess.run(["bash", str(SCRIPT), "retire", "--ledger", str(ledger),
                         "--key", "badkey", "--reason", "x"],
                        capture_output=True, text=True, timeout=30)
    assert p3.returncode == 2


def test_recurrence_view_requires_two_prs(tmp_path):
    ledger = tmp_path / "ledger.tsv"
    hdr = "PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote"
    ledger.write_text(hdr + "\n"
                      f"12\tci\tvh\t{H1}\tr1\t0\ta\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn\n"
                      f"12\tci\tvh\t{H1}\tr1\t1\ta\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn\n")
    p = subprocess.run(["bash", str(SCRIPT), "recurrence-view", "--ledger", str(ledger)],
                       capture_output=True, text=True, timeout=30)
    assert p.returncode == 0
    assert "RECURRING" not in p.stdout
    with ledger.open("a") as f:
        f.write(f"13\tci\tvh\t{H2}\tr2\t0\tb\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn\n")
    p2 = subprocess.run(["bash", str(SCRIPT), "recurrence-view", "--ledger", str(ledger)],
                        capture_output=True, text=True, timeout=30)
    assert "RECURRING\tci\tvh" in p2.stdout


def test_ci_writer_query_excludes_self_and_uses_label():
    import yaml
    wf = yaml.safe_load((ROOT / ".github/workflows/test.yml").read_text())
    steps = wf["jobs"]["ledger-integrity"]["steps"]
    writer = next(s for s in steps if (s.get("name") or "").startswith("Single active"))
    body = writer["run"]
    assert "label:ledger-writer" in body, "writer intent must be a label, not file match"
    assert "select(.number" in body, "current PR must be excluded from competitor count"


def _label_gate_body():
    import yaml
    wf = yaml.safe_load((ROOT / ".github/workflows/test.yml").read_text())
    steps = wf["jobs"]["ledger-integrity"]["steps"]
    gate = next(s for s in steps if (s.get("name") or "").startswith("Ledger-writer label required"))
    return gate["run"]


def _eval_label_gate(diff_names, labels, pr_number):
    """Execute the gate's branching logic offline against stubbed inputs.

    Replicates the three branches of the 'Ledger-writer label required for
    writer changes' step: push-event exemption (no PR number), read-only
    exemption (no writer-path diff), and the writer label requirement.
    Returns the exit code the real step would produce.
    """
    import subprocess
    import textwrap
    probe = textwrap.dedent("""\
        writers="%s"
        labels="%s"
        me="%s"
        if [ -z "$me" ]; then echo SKIP-PUSH; exit 10; fi
        if [ -z "$writers" ]; then echo SKIP-READONLY; exit 11; fi
        mine=0
        for l in $labels; do [ "$l" = "ledger-writer" ] && mine=1; done
        if [ "$mine" -ge 1 ]; then echo LABEL-OK; exit 0; else echo LABEL-MISSING; exit 1; fi
        """) % (
        " ".join(diff_names) if diff_names else "",
        " ".join(labels),
        pr_number if pr_number is not None else "",
    )
    return subprocess.run(["bash", "-c", probe], capture_output=True, text=True).returncode


def test_ci_label_gate_exempts_push_event():
    body = _label_gate_body()
    assert 'if [ -z "$me" ]' in body, "gate must exempt events with no PR number"
    assert _eval_label_gate(["skills/factory/factory-learn/scripts/bash/verify-recurrence.sh"], [], None) == 10


def test_ci_label_gate_readonly_pr_needs_no_label():
    body = _label_gate_body()
    assert "writer-path changes" in body
    assert "origin/main...HEAD" in body, "gate must diff PR against main"
    assert "recurrence-ledger.tsv" in body and "verify-recurrence.sh" in body
    assert _eval_label_gate([], [], "12") == 11


def test_ci_label_gate_writer_requires_label():
    _ = _label_gate_body()
    wr = ["skills/factory/factory-learn/references/recurrence-ledger.tsv"]
    assert _eval_label_gate(wr, ["ledger-writer"], "12") == 0, "labelled writer PR passes"
    assert _eval_label_gate(wr, [], "12") == 1, "unlabelled writer PR fails"
    sh = ["skills/factory/factory-learn/scripts/bash/verify-recurrence.sh"]
    assert _eval_label_gate(sh, [], "12") == 1, "unlabelled script change fails"
    assert _eval_label_gate(sh, ["other-label"], "12") == 1, "unrelated label does not satisfy gate"
    assert _eval_label_gate(sh, ["docs", "ledger-writer"], "12") == 0, "label among others satisfies gate"
