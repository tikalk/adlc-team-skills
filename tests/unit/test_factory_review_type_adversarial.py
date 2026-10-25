"""Review-type COMMENT submissions + adversarial three-persona depth (REQ-188/REQ-189).

REQ-188: verdicts land as native Review-type COMMENT submissions (never
Approve) — head-SHA-bound, idempotent per run/iter/head. General comments
(Op 4) stay reserved for status/lease/decisions.

REQ-189: the `review` step runs adverse-style three-persona depth
(Auditor/Adversary/Pragmatist, Round-1 parallel stay-in-lane, Round-2
cross-exam validate/challenge/add) with a deterministic synthesis counting
rule; converge reads synthesis output, not single-agent findings.

RED gate: this suite FAILS on the pre-implementation tree and PASSES once
the Implement Agent lands the skill changes.
"""

import json
import os
import re
import shutil
import signal
import subprocess
import time
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review"
SKILL_MD = SKILL / "SKILL.md"
LOOP_MD = SKILL / "references/review-loop.md"
TRACKER_MD = (
    ROOT / "skills/factory/factory-mission/references/tracker-integration.md"
)
SYNTH_SH = SKILL / "scripts/bash/synthesize-findings.sh"
SYNTH_PS = SKILL / "scripts/powershell/synthesize-findings.ps1"
SYNTH_TWINS = [(("bash"), SYNTH_SH)] + (
    [(("pwsh"), SYNTH_PS)] if shutil.which("pwsh") else []
)

REVIEW_MARKER = "factory-review:step=review"


def review_marker_templates(text):
    """Every review marker template in the text, joined across wrapped lines."""
    joined = re.sub(r"\s*\n\s*", " ", text)
    return [m for m in re.findall(r"<!--.*?-->", joined) if REVIEW_MARKER in m]


def op7_section():
    text = TRACKER_MD.read_text(encoding="utf-8")
    start = text.index("### Operation 7")
    end_candidates = [
        m.start() for m in re.finditer(r"^### Operation 8", text, re.M)
    ]
    end = min([e for e in end_candidates if e > start], default=len(text))
    return text[start:end]


def approve_code_paths(text):
    """Submission code paths that must never exist (prose is filtered out).

    The words "never Approve"/"Non-Approving"/"strictly advisory" in prose
    are allowed — only executable submission paths count.
    """
    hits = []
    for pat in (
        r"--approve\b",
        r"event\s*=\s*APPROVE",
        r"glab\s+mr\s+approve",
        r"--request-changes\b",
        r"event\s*=\s*REQUEST_CHANGES",
        r"create_pull_request_review\(\s*event\s*=\s*[\"']APPROVE",
    ):
        if re.search(pat, text):
            hits.append(pat)
    return hits


# ── A. REQ-188 Review-type COMMENT (no Approve) ─────────────────────────────

def test_skill_documents_comment_only_review_submission():
    """Verdicts go through a COMMENT submission path, and no Approve path exists."""
    content = SKILL_MD.read_text(encoding="utf-8")
    has_comment_path = (
        "create_pull_request_review(event=COMMENT)" in content
        or "create_pull_request_review(event = COMMENT)" in content
        or re.search(r"gh\s+pr\s+review\s+.*--comment", content) is not None
    )
    assert has_comment_path, (
        "SKILL.md must document the Review-type COMMENT submission path "
        "(`create_pull_request_review(event=COMMENT)` or "
        "`gh pr review <pr> --comment --body-file`)"
    )
    hits = approve_code_paths(content)
    assert not hits, (
        "SKILL.md must contain no Approve/Request-changes submission code "
        f"path (prose allowances excluded): {hits}"
    )


def test_tracker_op7_documents_both_providers_comment_paths():
    """Op 7 is COMMENT-only on both providers — GitHub AND GitLab."""
    section = op7_section()
    assert re.search(r"event\s*=\s*COMMENT|--comment\b", section), (
        "Op 7 must document the GitHub COMMENT path "
        "(Reviews API COMMENT event / `gh pr review --comment`)"
    )
    assert "REQUEST_CHANGES" not in section and "--approve" not in section, (
        "Op 7 must stay COMMENT-only — no Approve/Request-changes lane"
    )
    assert re.search(r"[Gg]it[Ll]ab", section), (
        "Op 7 must document the GitLab provider path, not GitHub alone"
    )
    assert re.search(
        r"review-type|threaded discussion|discussion.*note|note.*discussion",
        section,
        re.IGNORECASE,
    ), (
        "Op 7 must document the GitLab MR review-type threaded discussion "
        "note (provider-native surface, not a plain issue note, not "
        "`glab mr approve`)"
    )


def test_review_submission_markers_carry_head_one_per_comment():
    """Every review marker template carries head=<sha>; one marker, one comment."""
    for doc in (SKILL_MD, LOOP_MD):
        templates = review_marker_templates(doc.read_text(encoding="utf-8"))
        assert templates, f"{doc.name} must show the review marker template"
        for template in templates:
            assert "head=" in template, (
                "every review-submission marker must carry the head it "
                f"certifies: {template.strip()}"
            )
    content = SKILL_MD.read_text(encoding="utf-8") + LOOP_MD.read_text(
        encoding="utf-8"
    )
    assert re.search(
        r"one-marker-one-comment|one marker per comment|one marker, one comment",
        content,
        re.IGNORECASE,
    ), (
        "the skill must state the one-marker-one-comment rule: a Review-type "
        "verdict submission carries exactly one marker (idempotent per "
        "run/iter/head), never batched verdicts in one submission"
    )


def test_skill_states_comment_reservation_rule():
    """General comments stay reserved; verdicts go through Review-type submissions."""
    content = SKILL_MD.read_text(encoding="utf-8")
    assert re.search(
        r"general comments.*(status|lease|decision)|Op ?4.*(status|lease|decision)",
        content,
        re.IGNORECASE | re.DOTALL,
    ), (
        "SKILL.md must reserve general comments (Op 4) for "
        "status/lease/decisions only"
    )
    assert re.search(
        r"verdict.*Review-type|Review-type.*verdict",
        content,
        re.IGNORECASE | re.DOTALL,
    ), "SKILL.md must route verdicts through Review-type submissions"


# ── B. REQ-189 adversarial three-persona + synthesis ────────────────────────

def test_skill_names_the_persona_trio():
    content = SKILL_MD.read_text(encoding="utf-8")
    for persona in ("Auditor", "Adversary", "Pragmatist"):
        assert persona in content, (
            f"SKILL.md must name the {persona} persona of the review trio"
        )


def test_personas_have_orthogonal_scopes():
    content = SKILL_MD.read_text(encoding="utf-8")
    for scope in (
        "correctness",
        "security",
        "maintainability",
    ):
        assert scope.lower() in content.lower(), (
            f"SKILL.md must assign the {scope} scope to its persona "
            "(Auditor=correctness-logic, Adversary=security-abuse, "
            "Pragmatist=maintainability-design)"
        )
    assert re.search(r"stay-in-lane|stay in lane", content, re.IGNORECASE), (
        "SKILL.md must state the stay-in-lane rule for Round 1"
    )


def test_review_loop_documents_round1_parallel():
    content = LOOP_MD.read_text(encoding="utf-8")
    assert re.search(r"Round-?1|Round 1", content), (
        "review-loop.md must document Round 1 (parallel, stay-in-lane)"
    )
    assert re.search(r"parallel", content, re.IGNORECASE), (
        "Round 1 personas must run in parallel"
    )


def test_review_loop_documents_round2_cross_exam():
    content = LOOP_MD.read_text(encoding="utf-8")
    assert re.search(r"Round-?2|cross-exam|cross exam", content, re.IGNORECASE), (
        "review-loop.md must document Round-2 cross-examination"
    )
    for verb in ("validate", "challenge", "add"):
        assert verb in content.lower(), (
            f"Round 2 must define the '{verb}' cross-exam move"
        )


def test_review_loop_documents_synthesis_counting_rule():
    content = LOOP_MD.read_text(encoding="utf-8")
    for tag in ("cross-validated", "consensus", "disputed", "solo"):
        assert tag in content.lower(), (
            f"review-loop.md must define the '{tag}' synthesis tag"
        )
    assert re.search(
        r"cross-validated.*consensus.*Important|only.*cross-validated.*consensus"
        r"|actionable.*Important|cross-validated \+ consensus.*actionable",
        content,
        re.IGNORECASE | re.DOTALL,
    ), (
        "the synthesis rule must state which tagged Important findings trigger "
        "`fix` (cross-validated + consensus actionable; solo only in "
        "--single-round; disputed held for converge)"
    )


def _run_synth(script, input_str=None, file_arg=None):
    """Run one synthesis twin; `-` or no arg reads stdin (python parity)."""
    if script.suffix == ".sh":
        cmd = ["bash", str(script)]
    else:
        cmd = ["pwsh", "-NoProfile", "-File", str(script)]
    if file_arg is not None:
        cmd.append(str(file_arg))
    elif input_str is not None:
        cmd.append("-")
    return subprocess.run(
        cmd, input=input_str, capture_output=True, text=True, timeout=30
    )


def test_synthesize_findings_script_exists():
    assert SYNTH_SH.exists(), f"the synthesis script is missing: {SYNTH_SH}"
    assert SYNTH_PS.exists(), f"the synthesis twin is missing: {SYNTH_PS}"


def test_synthesize_findings_is_deterministic(tmp_path):
    """Same findings JSON in → same tags out, across runs and across twins."""
    findings = {
        "findings": [
            {
                "id": "F1",
                "reports": ["Auditor", "Adversary"],
                "validations": [],
                "challenges": [],
            },
            {
                "id": "F2",
                "reports": ["Pragmatist"],
                "validations": ["Auditor"],
                "challenges": [],
            },
            {
                "id": "F3",
                "reports": ["Auditor"],
                "validations": [],
                "challenges": ["Adversary"],
            },
        ]
    }
    src = tmp_path / "findings.json"
    src.write_text(json.dumps(findings), encoding="utf-8")
    outs = {}
    for name, script in SYNTH_TWINS:
        runs = []
        for _ in range(2):
            proc = _run_synth(script, file_arg=src)
            assert proc.returncode == 0, proc.stdout + proc.stderr
            runs.append(proc.stdout)
        assert runs[0] == runs[1], f"{name} twin must be deterministic"
        outs[name] = runs[0]
    if len(outs) == 2:
        assert json.loads(outs["bash"]) == json.loads(outs["pwsh"]), (
            "the twins must agree on every tag"
        )
    for tag in ("cross-validated", "consensus", "disputed"):
        assert tag in outs["bash"].lower(), (
            f"synthesis output must tag findings (missing '{tag}'): {outs['bash']}"
        )


def test_synthesize_findings_records_round2_add_as_finding():
    """A Round-2 `add` is a separate finding with the adder in `reports`."""
    findings = {
        "findings": [
            {
                "id": "F1a",
                "reports": ["Adversary"],
                "validations": [],
                "challenges": [],
            },
        ]
    }
    for name, script in SYNTH_TWINS:
        proc = _run_synth(script, input_str=json.dumps(findings))
        assert proc.returncode == 0, f"{name}: {proc.stdout + proc.stderr}"
        tags = json.loads(proc.stdout)["tags"]
        assert tags == [{"id": "F1a", "tag": "solo"}], (
            f"{name}: a lone Round-2 add must tag as solo: {proc.stdout}"
        )


def test_review_loop_documents_adversary_lane_preference():
    content = LOOP_MD.read_text(encoding="utf-8")
    assert "Adversary" in content, (
        "review-loop.md must name the Adversary lane explicitly"
    )
    assert re.search(
        r"Adversary.*cli:<other-runtime>|cli:<other-runtime>.*Adversary",
        content,
        re.DOTALL,
    ), "the Adversary must prefer the `cli:<other-runtime>` lane"
    assert re.search(r"degradation.*disclosed|disclosed.*degradation", content, re.IGNORECASE), (
        "lane degradation must be disclosed"
    )


def test_review_loop_documents_single_round_fallback():
    content = LOOP_MD.read_text(encoding="utf-8")
    assert "--single-round" in content, (
        "review-loop.md must document the `--single-round` fallback"
    )
    assert re.search(
        r"--single-round.*solo|skips? Round 2|skip.*Round-?2",
        content,
        re.IGNORECASE | re.DOTALL,
    ), "`--single-round` must skip Round 2 with findings tagged `solo`"


def test_converge_reads_synthesis_output():
    content = LOOP_MD.read_text(encoding="utf-8")
    assert re.search(
        r"converge.*synthesis|synthesis.*converge",
        content,
        re.IGNORECASE | re.DOTALL,
    ), "converge must read the synthesis output, not single-agent findings"
    assert "synthesize-findings.sh" in content, (
        "converge must name the synthesis script it re-runs to verify tags"
    )
    assert "synthesize-findings.ps1" in content, (
        "converge must name the PowerShell synthesis twin too"
    )
