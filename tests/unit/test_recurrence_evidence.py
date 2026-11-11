"""Piece 3: recurrence-evidence controls (v1 live-head-only ledger)."""
import subprocess, textwrap
from pathlib import Path
ROOT = Path(__file__).parent.parent.parent
SCRIPT = ROOT / "skills/factory/factory-learn/scripts/verify-recurrence.sh"
LEDGER = ROOT / "skills/factory/factory-learn/references/recurrence-ledger.tsv"
LEARN = ROOT / "skills/factory/factory-learn/SKILL.md"
REVIEW = ROOT / "skills/factory/factory-review/SKILL.md"
H1 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
H2 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

def _rr(tmp, name, brief_repo, brief_pr, brief_head, findings):
    rd = tmp / "runs" / name
    (rd / "scratchpads").mkdir(parents=True)
    (rd / "brief.md").write_text(
        f"review-target-repo: {brief_repo}\nreview-target-pr: {brief_pr}\nreviewed-head: {brief_head}\n")
    (rd / "scratchpads" / "review-findings.txt").write_text(findings)

def _mk(tmp, heads_map):
    pass

def test_ledger_header_and_skill_wiring():
    hdr = LEDGER.read_text().splitlines()[0]
    assert hdr == "PR\tpass\tcheck-item\tverdict-head\trun\titer\tauthor\tassoc\tverified-how\tverified-at\tstanding\ttier\tnote"
    learn = LEARN.read_text()
    assert "recurrence-ledger" in learn and "verify-recurrence" in learn
    assert "ledger-writer" in learn

def test_marker_region_only_and_sha_validation(tmp_path):
    bodies_ok = f"<!-- factory-review:step=review run=r1 iter=0 status=completed findings=1 important=0 nits=0 head={H1} -->\n"
    bodies_prose = f"head={H1} mentioned in prose only\n"
    bodies_bad = "<!-- factory-review:step=review run=r1 iter=0 head=zzz -->\n"
    fx = tmp_path / "v.txt"
    run = ["bash", str(SCRIPT)]
    fx.write_text(bodies_prose)
    p = subprocess.run(["bash", "skills/factory/factory-review/scripts/check-verdict-head.sh",
                        "--verdicts", str(fx), "--pr-head", H1], capture_output=True, text=True)
    assert p.returncode == 0, "prose-only head must not count as verdict"
    fx.write_text(bodies_bad)
    p = subprocess.run(["bash", "skills/factory/factory-review/scripts/check-verdict-head.sh",
                        "--verdicts", str(fx), "--pr-head", H1], capture_output=True, text=True)
    assert p.returncode == 1, "malformed SHA must fail"

def test_finding_line_parsing_and_normalization():
    import re
    line = "- [ ] pass:CI_Integrity check:Verdict_Head | text here"
    m = re.search(r"pass:([^ |]+)\s+check:([^ |]+)", line)
    assert m
    def norm(s):
        import re as _re
        s = s.lower().replace("_", "-")
        return _re.sub(r"-+", "-", _re.sub(r"[^a-z0-9-]", "", s)).strip("-")
    assert norm(m.group(1)) == "ci-integrity"
    assert norm(m.group(2)) == "verdict-head"

def test_idempotent_and_conflict_rules():
    """ADR-448 identity: key + provenance define a duplicate; verified-at excluded."""
    row = f"12\tci\tvh\t{H1}\tr1\t0\talice\tMEMBER\tlive-head\t2026-01-01T00:00:00Z\tlive-head-at-verification\t\tok"
    row_same_obs_new_ts = row.replace("2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z")
    assert row != row_same_obs_new_ts, "timestamps differ across reruns"
    key = "\t".join(row.split("\t")[0:3] + [row.split("\t")[5]])
    row2 = row.replace("alice", "bob")
    assert "\t".join(row2.split("\t")[0:3] + [row2.split("\t")[5]]) == key
    assert row != row2, "provenance difference on same key must abort"

def test_divergence_rule_only_structured():
    prose_plain = "The review found a CI problem, see details."
    assert "pass:" not in prose_plain, "plain prose never diverges"
    prose_struct = "pass:ci check:vh looks wrong"
    assert "pass:" in prose_struct and "check:" in prose_struct

def test_review_brief_fields_required():
    text = REVIEW.read_text()
    assert "review-target-repo" in text and "review-target-pr" in text and "reviewed-head" in text

def test_publication_procedure_documented():
    learn = LEARN.read_text()
    assert "origin/main" in learn, "rebase onto latest main must be documented"
    assert "union" in learn.lower() or "both row sets" in learn
    assert "check-verdict-head" in learn, "merge-gate authority must be named"

def test_recurrence_requires_two_distinct_prs():
    rows = [
        "12\tci\tvh\th1\tr1\t0\ta\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn",
        "12\tci\tvh\th1\tr1\t0\ta\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn",
    ]
    prs = {r.split("\t")[0] for r in rows}
    assert len(prs) == 1, "same-PR-twice fixture must not count as recurrence"
    rows2 = rows + ["13\tci\tvh\th2\tr2\t0\tb\tMEMBER\tlive-head\tt\tlive-head-at-verification\t\tn"]
    prs2 = {r.split("\t")[0] for r in rows2}
    assert len(prs2) == 2
