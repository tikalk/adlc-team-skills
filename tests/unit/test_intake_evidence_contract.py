"""The Mission Brief carries an Evidence base with a counter-evidence bucket.

The 2026-11-18 inbox audit found three structural intake defects: requester
self-notes were counted as sources but never read, same-day arrivals fell
outside the synthesis cutoff without a trace, and there was no counter-
evidence bucket at all. The brief format had no field able to express
"read", "contradicts", or "my own note", so the defects could not be
recorded — let alone caught.

This pins the contract (the intake evidence base decision in adlc-workspace): the canonical template
carries the four buckets, the `as of` cutoff, and rules R1–R4; the three
consumers (factory-queue plan mode, factory-mission intake, factory-
orchestrator's research path) each enforce or produce it. A brief missing
the Counter bucket must fail the validator, not pass by silence.

Criterion class B (skill prose). Positive witness: the shipped template,
the three SKILL.md files, and a well-formed fixture. Breakage witness: a
fixture with no Counter bucket, which the validator rejects.
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
TEMPLATE = (
    ROOT / "skills" / "mission" / "mission-brief" / "references"
    / "mission-brief-template.md"
)
QUEUE = ROOT / "skills" / "factory" / "factory-queue" / "SKILL.md"
MISSION = ROOT / "skills" / "factory" / "factory-mission" / "SKILL.md"
ORCHESTRATOR = ROOT / "skills" / "factory" / "factory-orchestrator" / "SKILL.md"

BUCKETS = ("Read", "Counter", "Unread", "Self-notes")


def read(path):
    return path.read_text(encoding="utf-8")


def validate_evidence_base(text):
    """Return the contract errors in a brief's Evidence base block.

    An empty list means the block is well formed: all four buckets present,
    `as of` declared, each Read entry naming a claim, and each Unread entry
    carrying its arrival timestamp.
    """
    header = re.search(r"\*\*Evidence base\*\* \(as of ([^)]+)\):", text)
    if header is None:
        if re.search(r"Evidence base\*{0,2}: direct request — no external sources\.", text):
            return []
        return ["missing Evidence base block with an 'as of' cutoff"]
    if not header.group(1).strip():
        return ["empty 'as of' cutoff"]

    block = text[header.end():]
    errors = []
    for bucket in BUCKETS:
        if not re.search(rf"^- {bucket}\b", block, re.M):
            errors.append(f"missing {bucket} bucket")

    for line in re.findall(r"^- Read: (.*)$", block, re.M):
        if "→" not in line:
            errors.append(f"Read entry names no supported claim: {line}")
    for line in re.findall(r"^- Unread: (.*)$", block, re.M):
        if "(" not in line:
            errors.append(f"Unread entry has no arrival timestamp: {line}")
    return errors


GOOD_BRIEF = """## Mission Brief

**Goal**: route factory intake through one evidence contract

**Evidence base** (as of 2026-11-18T14:00:00Z):
- Read: inbox thread on prose cost → the counter-position exists
- Counter: lauren's reply → contradicts the flat prose-cost assumption
- Unread: 2026-11-18 late reply (2026-11-18T15:30:00Z) — after cutoff
- Self-notes (claims, not evidence): my audit notes → claim to verify
"""

BAD_BRIEF = """## Mission Brief

**Goal**: route factory intake through one evidence contract

**Evidence base** (as of 2026-11-18T14:00:00Z):
- Read: inbox thread on prose cost → the counter-position exists
- Unread: 2026-11-18 late reply (2026-11-18T15:30:00Z) — after cutoff
- Self-notes (claims, not evidence): my audit notes → claim to verify
"""


def test_template_carries_the_evidence_base_contract():
    text = read(TEMPLATE)
    assert "**Evidence base** (as of <ISO timestamp>):" in text
    for bucket in BUCKETS:
        assert re.search(rf"^- {bucket}\b", text, re.M), (
            f"template must carry the {bucket} bucket"
        )
    for rule in ("R1 — Read means summarized", "R2 — Counter-evidence is required",
                 "R3 — Self-notes are claims, not evidence",
                 "R4 — The cutoff is declared"):
        assert rule in text, f"template must state {rule}"
    assert "Evidence base: direct request — no external sources." in text, (
        "a brief with no external sources must state the block, not omit it"
    )


def test_well_formed_brief_passes_and_missing_counter_fails():
    assert validate_evidence_base(GOOD_BRIEF) == []
    errors = validate_evidence_base(BAD_BRIEF)
    assert errors == ["missing Counter bucket"], (
        "a brief without a counter-evidence bucket must fail the contract"
    )


def test_direct_request_brief_states_the_absence_of_sources():
    assert validate_evidence_base(
        "**Evidence base**: direct request — no external sources.\n"
    ) == []
    assert validate_evidence_base("## Mission Brief\n\n**Goal**: x\n") == [
        "missing Evidence base block with an 'as of' cutoff"
    ]


def test_queue_plan_mode_generates_the_block_and_flags_a_gap():
    text = read(QUEUE)
    assert "Evidence base" in text
    assert "rules R1–R4" in text
    assert "mission-brief/references/mission-brief-template.md" in text
    assert "direct request — no external sources" in text
    assert "preview flags any generated gate/task brief whose `Evidence base` block is missing" in text


def test_mission_intake_validates_the_block_without_blocking_legacy_briefs():
    text = read(MISSION)
    assert "Evidence base" in text
    assert "mission-brief/references/mission-brief-template.md" in text
    assert "`none found in <scope>` is valid" in text
    assert "Evidence base: not declared (legacy brief)" in text, (
        "legacy briefs must disclose the gap and proceed, not hard-block"
    )


def test_orchestrator_research_carries_the_block_into_the_queue():
    text = read(ORCHESTRATOR)
    assert "Evidence base" in text
    assert "mission-brief/references/mission-brief-template.md" in text
    assert "Evidence base: not declared (direct research)" in text
    assert "claims, not evidence" in text
