"""End-of-plan decision-record check, proposal records, and early draft MR contract.

A mission's spec approval judges `spec.md` against `brief.md`, not against the
Accepted decision-record indexes. Without an alignment check at the end of
`plan`, a plan that contradicts an Accepted record or introduces an unrecorded
architectural/product choice reaches `test`/`code` unchallenged, while `--plan`
mode opens no draft MR for `gate-spec` to link when proposals are emitted.

Contract pinned here (naming decisions in words; local example IDs only):
1. `mission-brief` runs the record check at the end of `plan` (keeping the
   canonical 7-step lifecycle table intact), reading `plan.md` and `spec.md`
   against `docs/adlc/memory/adr/adr.md` and `docs/adlc/memory/pdr/pdr.md`
   (dual-read order with legacy `.adlc/memory` fallback), and emits `PASS` or
   `DECISION_RECORDS_CAPTURE_NEEDED`.
2. On `DECISION_RECORDS_CAPTURE_NEEDED`, `mission-brief` writes flat
   `status: proposed` records under `.adlc/drafts/{adr,pdr}/<ID>-<slug>.md`
   with non-empty `approvers`, `proposed-by`, and `source` frontmatter plus
   `# <ADR|PDR>-<NNN>: <title>`, `## Context and Problem Statement`, and
   `## Decision Outcome` body headings, and never edits Accepted records under
   `docs/adlc/memory/` or index files directly. Direct `mission-brief`
   invocation (outside `ADLC_RUN_ID`) stays advisory and instructs the human to
   run `/architect-clarify` + `/architect-implement` or `/product-clarify` +
   `/product-implement` to promote proposals into `docs/adlc/memory/`.
3. `factory-mission` delegates after `plan` by reading the `factory-runbook`
   publish procedure and running `<skills dir>/factory-runbook/scripts/bash/<name>.sh`
   (`--kind code`, `--output-type draft --step plan`) in canonical
   branch-first order (check out/reuse mission branch -> stage/commit
   allowlisted proposals -> push and open/reuse early draft MR when commits
   exist ahead of base; 0-commit `PASS` omits `mr_url`) without naming literal
   `factory-runbook` script files, handling both `--plan` (`return 0`,
   keeping `executing`, with `gate-spec` `reject` / `on_reject: abort` ->
   promote via `*-clarify` + `*-implement` -> re-run `factory-supervised` when
   `status: proposed` drafts are listed) and unattended
   `DECISION_RECORDS_CAPTURE_NEEDED` (`reason=decision-records`, `executing` ->
   `spec-gated`, non-zero exit) before Step 3 (`validation`), and tracks
   `record_captures` durably via prior `reason=decision-records` issue comments
   and `mission-state.json` (never writing custom keys into engine-owned
   `runs/<run_id>/state.json`) bounded by `max_record_captures: 2` in
   `mission-template.yml`.
"""

import re
from pathlib import Path, PurePosixPath

import yaml

ROOT = Path(__file__).parent.parent.parent
BRIEF_MD = ROOT / "skills/mission/mission-brief/SKILL.md"
FACTORY_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
MISSION_TEMPLATE = ROOT / "skills/factory/factory-runbook/mission-template.yml"


def section_body(text: str, heading: str) -> str:
    lines = text.splitlines(keepends=True)
    capturing = False
    in_fence = False
    collected: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            if capturing:
                collected.append(line)
            continue
        if not capturing:
            if not in_fence and stripped == heading:
                capturing = True
            continue
        if not in_fence and (line.startswith("## ") or line.startswith("### ")):
            break
        collected.append(line)
    assert capturing, f"missing required section: {heading}"
    return "".join(collected)


def validate_proposal_record(path: str, content: str) -> list[str]:
    """Validate a mission-emitted proposal record path, frontmatter, and body.

    Returns a list of contract violations (empty list == valid).
    """
    errors: list[str] = []
    raw_segments = path.split("/") if path else []
    posix = PurePosixPath(path) if path else PurePosixPath()
    parts = posix.parts
    valid_dir = (
        bool(path)
        and "\\" not in path
        and not posix.is_absolute()
        and ".." not in raw_segments
        and "." not in raw_segments
        and "" not in raw_segments
        and len(parts) == 4
        and parts[:2] == (".adlc", "drafts")
        and parts[2] in ("adr", "pdr")
    )
    expected_prefix = "ADR" if len(parts) >= 3 and parts[2] == "adr" else "PDR"
    valid_path = valid_dir and bool(
        re.fullmatch(rf"{expected_prefix}-\d{{3,4}}-[a-z0-9-]+\.md", parts[3])
    )
    if not valid_path:
        errors.append(
            f"proposal path {path!r} must be a flat .adlc/drafts/{{adr,pdr}}/<ID>-<slug>.md "
            "path (exact 4 parts, no '..' or backslashes; never docs/adlc/memory/)"
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

    after_close = content.find("\n", end + 1)
    body = content[after_close + 1 :] if after_close != -1 else ""
    if not re.search(r"(?m)^# (?:ADR|PDR)-\d{3,4}(?:-[a-z0-9-]+)?:\s+\S", body):
        errors.append("body must include '# <ADR|PDR>-<NNN>: <title>' heading")
    outcome_match = re.search(
        r"(?ms)^## Decision Outcome\s*$\n(.*?)(?=^## |\Z)", body
    )
    if not outcome_match or not outcome_match.group(1).strip():
        errors.append(
            "body must include '## Decision Outcome' with non-empty text beneath it"
        )
    return errors


GOOD_PROPOSAL = """---
status: proposed
date: 2026-11-18
approvers: [Lior Kanfi]
proposed-by: run-001
source: "spec.md §Acceptance Criteria; plan.md §Files"
---

# ADR-004: Support workspace profile inheritance

## Context and Problem Statement

Child repositories repeat identical profile settings instead of inheriting shared defaults from the workspace root.

## Decision Outcome

Resolve missing local profile keys from the workspace root profile before falling back to built-in defaults.
"""


def test_proposal_validator_accepts_valid_and_rejects_violations():
    assert (
        validate_proposal_record(
            ".adlc/drafts/adr/ADR-004-workspace-profile.md", GOOD_PROPOSAL
        )
        == []
    )
    assert (
        validate_proposal_record(
            ".adlc/drafts/pdr/PDR-002-amendment-2.md",
            GOOD_PROPOSAL.replace("# ADR-004:", "# PDR-002:"),
        )
        == []
    )

    # Writing directly to Accepted memory is forbidden.
    mem_err = validate_proposal_record(
        "docs/adlc/memory/adr/ADR-004-workspace-profile.md", GOOD_PROPOSAL
    )
    assert any(".adlc/drafts/" in e for e in mem_err)

    # Path traversal (`..`), nested subdirectories, and backslashes are rejected.
    traversal_err = validate_proposal_record(
        ".adlc/drafts/adr/../../../docs/adlc/memory/adr/ADR-001.md", GOOD_PROPOSAL
    )
    assert any("exact 4 parts" in e for e in traversal_err)

    nested_err = validate_proposal_record(
        ".adlc/drafts/adr/nested/ADR-004-workspace-profile.md", GOOD_PROPOSAL
    )
    assert any("exact 4 parts" in e for e in nested_err)

    backslash_err = validate_proposal_record(
        r".adlc\drafts\adr\ADR-004-workspace-profile.md", GOOD_PROPOSAL
    )
    assert any("exact 4 parts" in e for e in backslash_err)

    # Accepted status emitted by mission is forbidden (clarify owns promotion).
    accepted_err = validate_proposal_record(
        ".adlc/drafts/adr/ADR-004-workspace-profile.md",
        GOOD_PROPOSAL.replace("status: proposed", "status: accepted"),
    )
    assert any("status must be 'proposed'" in e for e in accepted_err)

    # Empty approvers or missing proposed-by/source are rejected.
    no_approvers = validate_proposal_record(
        ".adlc/drafts/adr/ADR-004-workspace-profile.md",
        GOOD_PROPOSAL.replace("approvers: [Lior Kanfi]", "approvers: []"),
    )
    assert any("approvers" in e for e in no_approvers)

    # Missing `# <ADR|PDR>-` title or missing/empty `## Decision Outcome` is rejected.
    no_title = validate_proposal_record(
        ".adlc/drafts/adr/ADR-004-workspace-profile.md",
        GOOD_PROPOSAL.replace("# ADR-004:", "# Plain Title:"),
    )
    assert any("# <ADR|PDR>-<NNN>:" in e for e in no_title)

    no_outcome = validate_proposal_record(
        ".adlc/drafts/adr/ADR-004-workspace-profile.md",
        GOOD_PROPOSAL.split("## Decision Outcome")[0],
    )
    assert any("## Decision Outcome" in e for e in no_outcome)

    empty_outcome = validate_proposal_record(
        ".adlc/drafts/adr/ADR-004-workspace-profile.md",
        GOOD_PROPOSAL.split("## Decision Outcome")[0] + "## Decision Outcome\n   \n",
    )
    assert any("## Decision Outcome" in e for e in empty_outcome)


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
        "disable-model-invocation: true",
        "/architect-clarify",
        "/architect-implement",
        "/product-clarify",
        "/product-implement",
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
        "# <ADR|PDR>-<NNN>: <title>",
        "## Context and Problem Statement",
        "## Decision Outcome",
        "/architect-clarify",
        "/architect-implement",
        "/product-clarify",
        "/product-implement",
        "docs/adlc/memory/{adr,pdr}/",
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


def test_factory_mission_encapsulates_runbook_and_orders_branch_first():
    text = FACTORY_MD.read_text(encoding="utf-8")
    for forbidden_script in (
        "commit-step.sh",
        "run-branch.sh",
        "open-mr.sh",
        "commit-step.ps1",
        "run-branch.ps1",
        "open-mr.ps1",
    ):
        assert forbidden_script not in text, (
            f"factory-mission must delegate via factory-runbook, never reference {forbidden_script!r}"
        )

    setup = section_body(text, "### Phase 0 to 4: Setup & Compilation")
    step8 = next(
        (ln for ln in setup.splitlines() if ln.strip().startswith("8.")),
        "",
    )
    assert "factory-runbook/scripts/bash/<name>.sh" in step8, (
        "Phase 0 to 4 step 8 must point at the runbook helpers "
        "('factory-runbook/scripts/bash/<name>.sh')"
    )
    assert "`--kind code`" in step8 and "`--output-type draft --step plan`" in step8
    branch_idx = step8.index("factory/mission/<repo>-<iid>")
    commit_idx = step8.index(".adlc/drafts/adr/*.md")
    open_mr_idx = step8.index("open or reuse the early draft code MR/PR")
    assert branch_idx < commit_idx < open_mr_idx, (
        "step 8 must order branch checkout -> proposal commit -> open/reuse draft MR"
    )
    assert "empty-branch no-op" in step8 and "omitted" in step8


def test_factory_mission_enforces_early_exits_record_cap_and_spec_gated_bounce():
    text = FACTORY_MD.read_text(encoding="utf-8")
    for token in (
        "DECISION_RECORDS_CAPTURE_NEEDED",
        "max_record_captures",
        "record_captures",
        "blocked: decision-records",
        "--plan",
    ):
        assert token in text, f"factory-mission missing {token!r}"

    factory_run = section_body(text, "## In a factory run — read this first")
    step3_pos = factory_run.index("3. **Once the code MR/PR is open,**")
    step2_block = factory_run[:step3_pos]

    # Step 2 must cover both early exits before Step 3 (`validation`).
    for step2_token in (
        "factory-runbook/scripts/bash/<name>.sh",
        "--plan",
        "return `0`",
        "plan-ready",
        "plan-ready: decision-records-proposed",
        "only when an MR/PR was opened or reused",
        "gate-spec",
        "on_reject: abort",
        "factory-supervised",
        "/architect-clarify",
        "/architect-implement",
        "/product-clarify",
        "/product-implement",
        "docs/adlc/memory/",
        "DECISION_RECORDS_CAPTURE_NEEDED",
        "Safety Constraint 8",
        "<!-- factory-run:ended run=<run_id> issue=<iid> reason=decision-records -->",
        "`spec-gated`",
        "Set Lifecycle",
        "blocked: decision-records",
        "exit non-zero",
    ):
        assert step2_token in step2_block, (
            f"factory-run Step 2 before Step 3 missing {step2_token!r}"
        )

    setup = section_body(text, "### Phase 0 to 4: Setup & Compilation")
    for setup_token in (
        "`spec-gated`",
        "reason=decision-records",
        "Safety Constraint 8",
        "disable-model-invocation: true",
        "/architect-clarify",
        "/architect-implement",
        "/product-clarify",
        "/product-implement",
        "docs/adlc/memory/",
        "on_reject: abort",
        "factory-supervised",
        ".adlc/workflows/runs/<run_id>/mission-state.json",
        "exit non-zero",
    ):
        assert setup_token in setup, f"Phase 0 to 4 setup missing {setup_token!r}"

    # Never introduce a non-existent `executing` -> `spec` lifecycle label.
    assert not re.search(r"`executing`\s*(?:→|->|to)\s*`spec`", text), (
        "lifecycle bounce must target `spec-gated`, never bare `spec`"
    )


def test_promotion_chain_supervised_gate_reject_flow_and_durable_record_captures():
    brief_text = BRIEF_MD.read_text(encoding="utf-8")
    factory_text = FACTORY_MD.read_text(encoding="utf-8")

    # Both skills must name clarify + implement to move Accepted proposals into docs/adlc/memory/.
    for label, doc in (
        ("mission-brief/SKILL.md", brief_text),
        ("factory-mission/SKILL.md", factory_text),
    ):
        assert "`/architect-clarify` + `/architect-implement`" in doc, (
            f"{label} must pair /architect-clarify + /architect-implement for promotion"
        )
        assert "`/product-clarify` + `/product-implement`" in doc, (
            f"{label} must pair /product-clarify + /product-implement for promotion"
        )
        assert "docs/adlc/memory/" in doc, (
            f"{label} must target docs/adlc/memory/ when promoting proposals"
        )

    # Supervised Phase 1 (`--plan`) must document gate-spec reject -> promote -> re-run factory-supervised.
    setup = section_body(factory_text, "### Phase 0 to 4: Setup & Compilation")
    step8 = next(
        (ln for ln in setup.splitlines() if ln.strip().startswith("8.")),
        "",
    )
    reject_idx = step8.index("rejects `gate-spec` (`on_reject: abort`)")
    promote_idx = step8.index("`/architect-clarify` + `/architect-implement`")
    rerun_idx = step8.index("re-runs `factory-supervised`")
    assert reject_idx < promote_idx < rerun_idx, (
        "step 8 must order gate-spec reject -> promote via clarify+implement -> re-run factory-supervised"
    )

    # Durable record_captures tracking: prior reason=decision-records issue comments + mission-state.json,
    # never writing record_captures into engine-owned runs/<run_id>/state.json.
    step9 = next(
        (ln for ln in setup.splitlines() if ln.strip().startswith("9.")),
        "",
    )
    assert "reason=decision-records" in step9
    assert ".adlc/workflows/runs/<run_id>/mission-state.json" in step9
    assert "never writing custom keys into `runs/<run_id>/state.json`" in step9
    assert not re.search(
        r"track\s+`?record_captures`?\s+in\s+`?(?:\.adlc/workflows/)?runs/<run_id>/state\.json`?",
        factory_text,
    ), "factory-mission must not instruct writing record_captures into runs/<run_id>/state.json"