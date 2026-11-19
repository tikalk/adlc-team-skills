"""Piece 3: recurrence-evidence controls (v1 live-head-only ledger)."""
import json
import os
from pathlib import Path
import stat
import subprocess

ROOT = Path(__file__).parent.parent.parent
SCRIPT = ROOT / "skills/factory/factory-learn/scripts/bash/verify-recurrence.sh"
CHECK_VERDICT_HEAD = ROOT / "skills/factory/factory-review/scripts/bash/check-verdict-head.sh"
LEDGER = ROOT / "skills/factory/factory-learn/references/recurrence-ledger.tsv"
LEARN = ROOT / "skills/factory/factory-learn/SKILL.md"
REVIEW = ROOT / "skills/factory/factory-review/SKILL.md"
HDR = "PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote"
H1 = "a" * 40
H2 = "b" * 40
MARKER = "<!-- factory-review:step=review run={run} iter={it} status=completed findings=1 important=0 nits=0 head={h} -->"


def _rr(tmp, name, brief_repo, brief_pr, brief_head, findings):
    rd = tmp / "runs" / name
    (rd / "scratchpads").mkdir(parents=True, exist_ok=True)
    (rd / "brief.md").write_text(
        f"review-target-repo: {brief_repo}\nreview-target-pr: {brief_pr}\nreviewed-head: {brief_head}\n",
        encoding="utf-8",
    )
    (rd / "scratchpads" / "review-findings.txt").write_text(findings, encoding="utf-8")


def _comment(ts, who, assoc, body):
    return {
        "created_at": ts,
        "user": {"login": who},
        "author_association": assoc,
        "body": body,
    }


def _make_gh(bin_dir, pr_head, comments, reviews=None, call_log=None):
    bin_dir.mkdir(parents=True, exist_ok=True)
    gh = bin_dir / "gh"
    log_line = f'echo "$2" >> "{call_log}"\n' if call_log is not None else ""
    gh.write_text(
        "#!/bin/bash\n"
        '[ "$1" = "api" ] || exit 1\n'
        f"{log_line}"
        'case "$2" in\n'
        f'  *"/pulls/12") printf \'%s\\n\' \'{json.dumps({"head": {"sha": pr_head}})}\' ;;\n'
        f'  *"/issues/12/comments") printf \'%s\\n\' \'{json.dumps(comments)}\' ;;\n'
        f'  *"/pulls/12/reviews") printf \'%s\\n\' \'{json.dumps(reviews or [])}\' ;;\n'
        '  *) exit 1 ;;\n'
        'esac\n',
        encoding="utf-8",
    )
    gh.chmod(gh.stat().st_mode | stat.S_IEXEC)


def _env_with(bin_dir):
    env = dict(os.environ)
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
    return env


def _run_script(args, env=None):
    return subprocess.run(
        ["bash", str(SCRIPT)] + args,
        capture_output=True,
        text=True,
        env=env,
        timeout=30,
    )


def test_ledger_header_and_skill_wiring():
    hdr = LEDGER.read_text(encoding="utf-8").splitlines()[0]
    assert hdr == HDR
    learn = LEARN.read_text(encoding="utf-8")
    assert "recurrence-ledger" in learn and "verify-recurrence" in learn
    assert "verify-recurrence.ps1" in learn
    assert "ledger-writer" in learn


def test_marker_only_sha_parsing(tmp_path):
    """check-verdict-head.sh and verify-recurrence.sh parse SHA only from the HTML comment marker."""
    bodies_ok = f"<!-- factory-review:step=review run=r1 iter=0 status=completed findings=1 important=0 nits=0 head={H1} -->\nok\n"
    bodies_prose = f"<!-- factory-review:step=review run=r1 iter=0 status=completed -->\nReviewed head={H1} in prose\n"
    bodies_bad = "<!-- factory-review:step=review run=r1 iter=0 head=deadbeef -->\n"
    fx = tmp_path / "v.txt"

    fx.write_text(bodies_ok, encoding="utf-8")
    p_ok = subprocess.run(
        ["bash", str(CHECK_VERDICT_HEAD), "--verdicts", str(fx), "--pr-head", H1],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert p_ok.returncode == 0, p_ok.stdout + p_ok.stderr

    fx.write_text(bodies_prose, encoding="utf-8")
    p_prose = subprocess.run(
        ["bash", str(CHECK_VERDICT_HEAD), "--verdicts", str(fx), "--pr-head", H1],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert p_prose.returncode == 1, "prose-only head= outside marker region must not satisfy check-verdict-head"

    fx.write_text(bodies_bad, encoding="utf-8")
    p_bad = subprocess.run(
        ["bash", str(CHECK_VERDICT_HEAD), "--verdicts", str(fx), "--pr-head", H1],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert p_bad.returncode == 1, "malformed non-40-hex marker SHA must fail check-verdict-head"

    # Also verify verify-recurrence.sh rejects prose-only and malformed marker SHAs while accepting bodies_ok.
    _rr(tmp_path, "r1", "o/r", "12", H1, "- [ ] pass:CI check:VH | real finding\n")
    bin_bad = tmp_path / "bin_bad"
    _make_gh(
        bin_bad,
        H1,
        [
            _comment("2026-01-01T00:00:00Z", "alice", "MEMBER", bodies_prose),
            _comment("2026-01-02T00:00:00Z", "alice", "MEMBER", bodies_bad),
        ],
    )
    ing_bad = _run_script(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path)], _env_with(bin_bad))
    assert ing_bad.returncode == 0, ing_bad.stdout + ing_bad.stderr
    assert "no-marker-head" in ing_bad.stdout
    assert "malformed-head" in ing_bad.stdout
    assert f"12\tci\tvh\t{H1}" not in ing_bad.stdout

    bin_ok = tmp_path / "bin_ok"
    _make_gh(bin_ok, H1, [_comment("2026-01-03T00:00:00Z", "alice", "MEMBER", bodies_ok)])
    ing_ok = _run_script(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path)], _env_with(bin_ok))
    assert ing_ok.returncode == 0, ing_ok.stdout + ing_ok.stderr
    assert f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head" in ing_ok.stdout


def test_finding_line_normalization(tmp_path):
    """verify-recurrence.sh normalizes mixed-case/underscore pass and check slugs."""
    _rr(tmp_path, "r1", "o/r", "12", H1, "- [x] pass:CI_Integrity check:Verdict__Head! | Check verdict head\n")
    bin_dir = tmp_path / "bin"
    _make_gh(bin_dir, H1, [_comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(run="r1", it="0", h=H1))])
    p = _run_script(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path)], _env_with(bin_dir))
    assert p.returncode == 0, p.stdout + p.stderr
    assert f"12\tci-integrity\tverdict-head\t{H1}\tr1\t0\talice\tMEMBER" in p.stdout


def test_idempotence_and_provenance_conflict(tmp_path):
    """Rerun with newer clock is DUPLICATE (ledger unchanged); conflicting author exits 2."""
    _rr(tmp_path, "r1", "o/r", "12", H1, "- [ ] pass:ci check:vh | finding\n")
    bin_dir = tmp_path / "bin"
    _make_gh(bin_dir, H1, [_comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(run="r1", it="0", h=H1))])
    date_idx = tmp_path / "date_idx"
    date_idx.write_text("0", encoding="utf-8")
    date_shim = bin_dir / "date"
    date_shim.write_text(
        "#!/bin/bash\n"
        f'i=$(cat "{date_idx}")\n'
        f'echo $((i + 1)) > "{date_idx}"\n'
        'stamps=(2026-01-01T00:00:00Z 2026-01-02T00:00:00Z 2026-01-03T00:00:00Z)\n'
        'echo "${stamps[$i]:-2026-01-03T00:00:00Z}"\n',
        encoding="utf-8",
    )
    date_shim.chmod(date_shim.stat().st_mode | stat.S_IEXEC)
    ledger = tmp_path / "ledger.tsv"
    env = _env_with(bin_dir)

    r1 = _run_script(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path), "--ledger", str(ledger)], env)
    assert r1.returncode == 0, r1.stdout + r1.stderr
    seeded_bytes = ledger.read_bytes()
    assert "2026-01-01T00:00:00Z" in ledger.read_text(encoding="utf-8")

    r2 = _run_script(["run", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path), "--ledger", str(ledger)], env)
    assert r2.returncode == 0, r2.stdout + r2.stderr
    assert "DUPLICATE\t" in r2.stdout
    assert ledger.read_bytes() == seeded_bytes

    bin_conflict = tmp_path / "bin_conflict"
    _make_gh(bin_conflict, H1, [_comment("2026-01-02T00:00:00Z", "bob", "MEMBER", MARKER.format(run="r1", it="0", h=H1))])
    r3 = _run_script(
        ["run", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path), "--ledger", str(ledger)],
        _env_with(bin_conflict),
    )
    assert r3.returncode == 2, r3.stdout + r3.stderr
    assert "provenance conflict" in r3.stderr
    assert ledger.read_bytes() == seeded_bytes


def test_divergence_rule_only_structured_and_scoped_to_winner(tmp_path):
    """Plain prose never diverges; untrusted bystander prose never poisons the winner (F2)."""
    _rr(tmp_path, "r1", "o/r", "12", H1, "- [ ] pass:ci check:vh | real finding\n")
    bin_dir = tmp_path / "bin"
    call_log = tmp_path / "gh_calls.log"
    winner_body = (
        MARKER.format(run="r1", it="0", h=H1)
        + "\n<!-- multi-line comment\npass:hidden check:ignored\n-->\n"
        + "The review found a CI problem in plain prose. Also pass:extra check:unmatched.\n"
    )
    attacker_body = "pass:ci check:vh and pass:poison check:untrusted from NONE user"
    _make_gh(
        bin_dir,
        H1,
        [
            _comment("2026-01-01T00:00:00Z", "mallory", "NONE", attacker_body),
            _comment("2026-01-02T00:00:00Z", "alice", "MEMBER", winner_body),
        ],
        call_log=call_log,
    )
    p = _run_script(["ingest", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path)], _env_with(bin_dir))
    assert p.returncode == 0, p.stdout + p.stderr
    assert f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER" in p.stdout
    assert "extra\tunmatched\t-\t-\t-\tfinding-diverged" in p.stdout
    assert "poison" not in p.stdout
    assert "hidden" not in p.stdout
    calls = call_log.read_text(encoding="utf-8").splitlines()
    assert len(calls) == 3, f"expected single fetch of pr, comments, reviews; got {calls}"


def test_marker_newline_injection_and_path_traversal_blocked(tmp_path):
    """Newline/tab spoof in run= and path traversal in run=/iter= are rejected (F1)."""
    _rr(tmp_path, "r1", "o/r", "12", H1, "- [ ] pass:security check:injected | forged\n")
    # Also plant a traversal target outside runs/ to prove ../ never resolves.
    (tmp_path / "outside" / "scratchpads").mkdir(parents=True)
    (tmp_path / "outside" / "brief.md").write_text(
        f"review-target-repo: o/r\nreview-target-pr: 12\nreviewed-head: {H1}\n",
        encoding="utf-8",
    )
    (tmp_path / "outside" / "scratchpads" / "review-findings.txt").write_text(
        "- [ ] pass:security check:traversed | escaped\n",
        encoding="utf-8",
    )
    spoof_body = (
        f"<!-- factory-review:step=review head={H1} "
        f"run=dummy\n2099-12-31T23:59:59Z\tspoofed-owner\tOWNER\tok\t{H1}\tr1\t0\t0 -->"
    )
    traversal_body = f"<!-- factory-review:step=review head={H1} run=../outside iter=0 -->"
    bin_dir = tmp_path / "bin"
    _make_gh(
        bin_dir,
        H1,
        [
            _comment("2026-01-02T00:00:00Z", "mallory", "NONE", spoof_body),
            _comment("2026-01-03T00:00:00Z", "alice", "MEMBER", traversal_body),
        ],
    )
    ledger = tmp_path / "ledger.tsv"
    p = _run_script(
        ["run", "--repo", "o/r", "--pr", "12", "--run-root", str(tmp_path), "--ledger", str(ledger)],
        _env_with(bin_dir),
    )
    assert p.returncode == 0, p.stdout + p.stderr
    assert "spoofed-owner" not in ledger.read_text(encoding="utf-8")
    assert "traversed" not in ledger.read_text(encoding="utf-8")
    data_rows = [l for l in ledger.read_text(encoding="utf-8").splitlines()[1:] if l.strip()]
    assert data_rows == []


def test_aggregate_target_mismatch_poisoning_and_cross_second_rerun(tmp_path):
    """Aggregate enforces brief repo/pr match (F5), ignores NONE prose poisoning (F2), and allows cross-second reruns (F6)."""
    _rr(tmp_path, "r_wrong_repo", "wrong/repo", "12", H1, "- [ ] pass:ci check:vh | x\n")
    _rr(tmp_path, "r_wrong_pr", "o/r", "999", H1, "- [ ] pass:ci check:vh | x\n")
    _rr(tmp_path, "r_ok", "o/r", "12", H1, "- [ ] pass:ci check:vh | x\n")

    pay = tmp_path / "pay"
    pay.mkdir()
    (pay / "pr.json").write_text(json.dumps({"head": {"sha": H1}}), encoding="utf-8")
    (pay / "comments.json").write_text(
        json.dumps([
            _comment("2026-01-01T00:00:00Z", "mallory", "NONE", "pass:poison check:untrusted"),
            _comment("2026-01-02T00:00:00Z", "alice", "MEMBER", MARKER.format(run="r_wrong_repo", it="0", h=H1)),
            _comment("2026-01-02T00:00:01Z", "alice", "MEMBER", MARKER.format(run="r_wrong_pr", it="0", h=H1)),
            _comment(
                "2026-01-02T00:00:02Z",
                "alice",
                "MEMBER",
                MARKER.format(run="r_ok", it="0", h=H1) + "\npass:other check:unmatched\n",
            ),
        ]),
        encoding="utf-8",
    )
    (pay / "reviews.json").write_text("[]", encoding="utf-8")

    cand = tmp_path / "cand.tsv"
    cand.write_text(
        "\n".join([
            f"12\tci\tvh\t{H1}\tr_wrong_repo\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn",
            f"12\tci\tvh\t{H1}\tr_wrong_pr\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn",
            f"12\tci\tvh\t{H1}\t../outside\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn",
            f"12\tci\tvh\t{H1}\tr_ok\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn",
        ]) + "\n",
        encoding="utf-8",
    )

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    date_idx = tmp_path / "agg_date_idx"
    date_idx.write_text("0", encoding="utf-8")
    date_shim = bin_dir / "date"
    date_shim.write_text(
        "#!/bin/bash\n"
        f'i=$(cat "{date_idx}")\n'
        f'echo $((i + 1)) > "{date_idx}"\n'
        'stamps=(2026-01-05T00:00:01Z 2026-01-05T00:00:09Z)\n'
        'echo "${stamps[$i]:-2026-01-05T00:00:09Z}"\n',
        encoding="utf-8",
    )
    date_shim.chmod(date_shim.stat().st_mode | stat.S_IEXEC)
    env = _env_with(bin_dir)

    ledger = tmp_path / "ledger.tsv"
    args = [
        "aggregate", "--ledger", str(ledger), "--candidates", str(cand),
        "--fixture-payloads", str(pay), "--repo", "o/r", "--pr", "12",
        "--run-root", str(tmp_path), "--allow-fixture",
    ]
    a1 = _run_script(args, env)
    assert a1.returncode == 0, a1.stdout + a1.stderr
    assert "REJECT\tcandidate-mismatch\t12\tci\tvh\t" in a1.stdout
    assert f"VALID\t12\tci\tvh\t{H1}\tr_ok\t0\talice\tMEMBER" in a1.stdout
    rows = [l for l in ledger.read_text(encoding="utf-8").splitlines()[1:] if l.strip()]
    assert len(rows) == 1
    assert "\tr_ok\t" in rows[0]
    before = ledger.read_bytes()

    # Second run at a later UTC timestamp must succeed as DUPLICATE/VALID, never conflict.
    a2 = _run_script(args, env)
    assert a2.returncode == 0, a2.stdout + a2.stderr
    assert f"VALID\t12\tci\tvh\t{H1}\tr_ok\t0\talice\tMEMBER" in a2.stdout
    assert "provenance conflict" not in (a2.stdout + a2.stderr)
    assert ledger.read_bytes() == before


def test_review_brief_fields_required():
    text = REVIEW.read_text(encoding="utf-8")
    assert "review-target-repo" in text and "review-target-pr" in text and "reviewed-head" in text


def test_publication_procedure_documented():
    learn = LEARN.read_text(encoding="utf-8")
    assert "origin/main" in learn, "rebase onto latest main must be documented"
    assert "union" in learn.lower() or "both row sets" in learn
    assert "check-verdict-head" in learn, "merge-gate authority must be named"


def test_recurrence_requires_two_distinct_prs(tmp_path):
    """verify-recurrence.sh recurrence-view reports RECURRING only across >=2 distinct PRs."""
    ledger = tmp_path / "ledger.tsv"
    ledger.write_text(
        HDR + "\n"
        + f"12\tci\tvh\t{H1}\tr1\t0\ta\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tn\n"
        + f"12\tci\tvh\t{H1}\tr1\t1\ta\tMEMBER\tlive-head\t2026-01-02T00:00:00Z\tlive-head-at-verification\t\tn\n",
        encoding="utf-8",
    )
    p1 = _run_script(["recurrence-view", "--ledger", str(ledger)])
    assert p1.returncode == 0, p1.stdout + p1.stderr
    assert p1.stdout.strip() == "", "two iterations on one PR must not report RECURRING"

    with ledger.open("a", encoding="utf-8") as fh:
        fh.write(f"13\tci\tvh\t{H2}\tr2\t0\tb\tMEMBER\tlive-head\t2026-01-03T00:00:00Z\tlive-head-at-verification\t\tn\n")
    p2 = _run_script(["recurrence-view", "--ledger", str(ledger)])
    assert p2.returncode == 0, p2.stdout + p2.stderr
    assert p2.stdout.strip() == "RECURRING\tci\tvh\tprs:2"
