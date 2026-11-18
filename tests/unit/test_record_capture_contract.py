"""End-of-plan decision-record check, proposal records, and early draft MR contract.

A mission's spec approval judges `spec.md` against `brief.md`, not against the
Accepted decision-record indexes. Without an alignment check at the end of
`plan`, a plan that contradicts an Accepted record or introduces an unrecorded
architectural/product choice reaches `test`/`code` unchallenged, while `--plan`
mode opens no draft MR for `gate-spec` to link.

Contract pinned here (naming decisions in words; local example IDs only):
1. `mission-brief` runs the record check at the end of `plan` (keeping the
   canonical 7-step lifecycle table intact), reading `plan.md` and `spec.md`
   against `docs/adlc/memory/adr/adr.md` and `docs/adlc/memory/pdr/pdr.md`
   (dual-read order with legacy `.adlc/memory` fallback), and emits `PASS` or
   `DECISION_RECORDS_CAPTURE_NEEDED`.
2. On `DECISION_RECORDS_CAPTURE_NEEDED`, `mission-brief` writes `status: proposed`
   records under `.adlc/drafts/adr/` or `.adlc/drafts/pdr/` with non-empty
   `approvers`, `proposed-by`, and `source` frontmatter, and never edits
   Accepted records under `docs/adlc/memory/` or index files directly.
   Direct `mission-brief` invocation (outside `ADLC_RUN_ID`) stays advisory.
3. `factory-mission` opens/reuses the early draft MR after `plan` in both
   supervised (`--plan` and full) and autonomous runs by invoking
   `factory-runbook` (`--kind code`), commits proposals via `commit-step.sh`,
   tracks `record_captures` in `runs/<run_id>/state.json` bounded by
   `max_record_captures: 2` in `mission-template.yml`, blocks `test`/`code`
   while `DECISION_RECORDS_CAPTURE_NEEDED` is unresolved, and bounces tracker
   lifecycle `executing` -> `spec-gated` with `blocked: decision-records` when
   unattended execution halts or the cap is exhausted.
"""

import re
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
BRIEF_MD = ROOT / "skills/mission/mission-brief/SKILL.md"
FACTORY_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
MISSION_TEMPLATE = ROOT / "skills/factory/factory-runbook/mission-template.yml"


def section_body(text: str, heading: str) -> str:
    pattern = rf"(?ms)^{re.escape(heading)}\s*$(.*?)(?=^## |^### |\Z)"
    match = re.search(pattern, text)
    assert match, f"missing required section: {heading}"
    return match.group(1)


def validate_proposal_record(path: str, content: str) -> list[str]:
    """Validate a mission-emitted proposal record path and YAML frontmatter.

    Returns a list of contract violations (empty list == valid).
    """
    errors: list[str] = []
    if not (
        path.startswith(".adlc/drafts/adr/")
        or path.startswith(".adlc/drafts/pdr/")
    ) or not path.endswith(".md"):
        errors.append(
            f"proposal path {path!r} must live under .adlc/drafts/{{adr,pdr}}/*.md "
            "(never docs/adlc/memory/)"
        )
    if not content.startswith("---\n"):
        errors.append("missing YAML frontmatter")
        return errors
    end = content.find("\n---", 4)
    if end == -1:
        errors.append("unclosed YAML frontmatter")
        return errors
    meta = yaml.safe_load(content[4:end]) or {}
    if not isinstance(meta, dict):
        errors.append("frontmatter must be a mapping")
        return errors
    if meta.get("status") != "proposed":
        errors.append(f"status must be 'proposed', got {meta.get('status')!r}")
    approvers = meta.get("approvers")
    if not (
        isinstance(approvers, list)
        and len(approvers) > 0
        and all(isinstance(a, str) and a.strip() for a in approvers)
    ):
        errors.append("approvers must be a non-empty list of decision-makers")
    proposed_by = meta.get("proposed-by")
    if not isinstance(proposed_by, str) or not proposed_by.strip():
        errors.append("proposed-by must name the run_id or 'direct'")
    source = meta.get("source")
    if not isinstance(source, str) or not source.strip():
        errors.append("source must name the spec.md / plan.md sections")
    return errors


GOOD_PROPOSAL = """---
status: proposed
date: 2026-11-18
approvers: [Lior Kanfi]
proposed-by: run-001
source: "spec.md §Acceptance Criteria; plan.md §Files"
---

# ADR-001: Use SQLite snapshot cache for offline index reads
"""


def test_proposal_validator_accepts_valid_and_rejects_violations():
    assert validate_proposal_record(".adlc/drafts/adr/ADR-001.md", GOOD_PROPOSAL) == []
    assert validate_proposal_record(".adlc/drafts/pdr/PDR-001.md", GOOD_PROPOSAL) == []

    # Writing directly to Accepted memory is forbidden.
    mem_err = validate_proposal_record(
        "docs/adlc/memory/adr/ADR-001.md", GOOD_PROPOSAL
    )
    assert any(".adlc/drafts/" in e for e in mem_err)

    # Accepted status emitted by mission is forbidden (clarify owns promotion).
    accepted_err = validate_proposal_record(
        ".adlc/drafts/adr/ADR-001.md",
        GOOD_PROPOSAL.replace("status: proposed", "status: accepted"),
    )
    assert any("status must be 'proposed'" in e for e in accepted_err)

    # Empty approvers or missing proposed-by/source are rejected.
    no_approvers = validate_proposal_record(
        ".adlc/drafts/adr/ADR-001.md",
        GOOD_PROPOSAL.replace("approvers: [Lior Kanfi]", "approvers: []"),
    )
    assert any("approvers" in e for e in no_approvers)


def test_mission_brief_runs_record_check_at_end_of_plan():
    text = BRIEF_MD.read_text(encoding="utf-8")
    default_lane = section_body(text, "## Default lane (embedded)")
    plan_item = next(
        (ln for ln in default_lane.splitlines() if ln.strip().startswith("8.")),
        "",
    )
    assert "plan.md" in plan_item and "record check" in plan_item.lower(), (
        "Default lane step 8 (Write plan.md) must run the end-of-plan record check"
    )

    check = section_body(text, "## Record check at the end of plan")
    for token in (
        "PASS",
        "DECISION_RECORDS_CAPTURE_NEEDED",
        "docs/adlc/memory/adr/adr.md",
        "docs/adlc/memory/pdr/pdr.md",
        ".adlc/memory",
    ):
        assert token in check, f"record-check section missing {token!r}"
    assert "never edits" in check.lower(), (
        "record check must forbid editing Accepted records or indexes directly"
    )


def test_mission_brief_defines_proposal_records_and_advisory_direct_mode():
    text = BRIEF_MD.read_text(encoding="utf-8")
    proposals = section_body(text, "### Proposal records")
    for token in (
        ".adlc/drafts/adr/",
        ".adlc/drafts/pdr/",
        "status: proposed",
        "approvers:",
        "proposed-by:",
        "source:",
        "architect-clarify",
        "product-clarify",
    ):
        assert token in proposals, f"proposal-records contract missing {token!r}"

    # Direct invocation (outside ADLC_RUN_ID) stays advisory.
    assert "advisory" in text.lower() and "ADLC_RUN_ID" in text


def test_mission_template_declares_max_record_captures_default():
    raw = MISSION_TEMPLATE.read_text(encoding="utf-8")
    parsed = yaml.safe_load(raw)
    assert parsed["workflow"]["max_record_captures"] == 2, (
        "mission-template.yml must declare workflow.max_record_captures: 2"
    )


def test_factory_mission_enforces_early_mr_record_cap_and_spec_gated_bounce():
    text = FACTORY_MD.read_text(encoding="utf-8")
    for token in (
        "DECISION_RECORDS_CAPTURE_NEEDED",
        "max_record_captures",
        "record_captures",
        "blocked: decision-records",
        "--plan",
    ):
        assert token in text, f"factory-mission missing {token!r}"

    setup = section_body(text, "### Phase 0 to 4: Setup & Compilation")
    assert "open-mr" in setup or "factory-runbook" in setup, (
        "Phase 0 to 4 must publish/reuse the early draft MR after plan via factory-runbook"
    )
    assert "`--kind code`" in setup, (
        "early draft MR after plan must use --kind code"
    )
    assert "`spec-gated`" in setup, (
        "record-capture halt must bounce lifecycle from executing back to spec-gated "
        "(tracker-integration has no 'spec' label)"
    )
    # Never introduce a non-existent `executing` -> `spec` lifecycle label.
    assert not re.search(r"`executing`\s*(?:→|->|to)\s*`spec`", text), (
        "lifecycle bounce must target `spec-gated`, never bare `spec`"
    )
