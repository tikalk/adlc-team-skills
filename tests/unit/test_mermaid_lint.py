"""Mermaid syntax validator (the mermaid detection pass) — corpus, severity, location, read-only.

The validator is a deterministic static scan over ```mermaid fenced blocks:
one finding per broken block, each carrying a severity, a location and a
suggested patch. These tests pin the rule set once so product-analyze and
architect-analyze can reference it instead of forking the prose (the mermaid detection pass
mitigation for rule drift).
"""

import hashlib
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
LINTER = ROOT / "skills/architect/architect-clarify/scripts/bash/mermaid-lint.sh"
LINTER_PS = ROOT / "skills/architect/architect-clarify/scripts/powershell/mermaid-lint.ps1"
HAVE_PWSH = shutil.which("pwsh") is not None

pytestmark = pytest.mark.skipif(
    shutil.which("bash") is None, reason="bash not available"
)


def run_linter(tmp_path, text, *args):
    """Run the linter over one artifact; return (exit_code, findings).

    The machine channel is tab-separated: severity, rule, file, line, fence,
    message, offending line, suggested patch. When pwsh is installed the
    PowerShell twin runs too and must agree byte-for-byte (CDR-022: one
    behavior, two platform scripts).
    """
    artifact = tmp_path / "artifact.md"
    artifact.write_text(text, encoding="utf-8")
    proc = subprocess.run(
        ["bash", str(LINTER), "--tsv", str(artifact), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if HAVE_PWSH:
        proc_ps = subprocess.run(
            ["pwsh", "-NoProfile", "-File", str(LINTER_PS), "--tsv", str(artifact), *args],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert proc_ps.returncode == proc.returncode, (
            f"twins disagree on exit code: bash={proc.returncode} pwsh={proc_ps.returncode}\n"
            f"bash: {proc.stdout}\npwsh: {proc_ps.stdout}"
        )
        assert proc_ps.stdout == proc.stdout, (
            "twins disagree on findings:\n"
            f"bash: {proc.stdout}\npwsh: {proc_ps.stdout}"
        )
    fields = ("severity", "rule", "file", "line", "fence", "message", "offending", "suggestion")
    findings = []
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        assert len(parts) == len(fields), f"malformed TSV row: {line!r}"
        record = dict(zip(fields, parts))
        record["line"] = int(record["line"])
        record["fence"] = int(record["fence"])
        findings.append(record)
    return proc.returncode, findings


def rules(findings):
    return [f["rule"] for f in findings]


# ── the linter exists and is executable-by-bash ─────────────────────────────

def test_linter_is_present():
    assert LINTER.exists(), f"canonical mermaid linter missing at {LINTER}"
    assert LINTER_PS.exists(), f"mermaid linter twin missing at {LINTER_PS}"


# ── broken corpus: one finding per broken block, with location + patch ─────

BROKEN = """\
# Broken corpus

## graph keyword (style, renderable)

```mermaid
graph TD
  A --> B
```

## empty body

```mermaid
flowchart TD
```

## malformed gantt header

```mermaid
gantt
  this line is not a gantt key
```

## empty block

```mermaid
```

## unclosed fence (truncated file — the block is never closed)

```mermaid
flowchart TD
  A --> B
"""


# ── a declared type with no statement at all: renderable, so MEDIUM ────────
#
# mermaid renders a typed diagram whose body carries no statement (an empty
# chart), so an empty body is a style finding — never a syntax break. Every
# type behaves the same way, and the finding sits on the type declaration.

EMPTY_TYPED = """\
# A declared type with no statement

```mermaid
gantt
```

```mermaid
sequenceDiagram
```

```mermaid
erDiagram
```

```mermaid
flowchart TD
```
"""


def test_broken_corpus_finds_every_broken_block(tmp_path):
    code, findings = run_linter(tmp_path, BROKEN)
    assert code == 1, "a HIGH (syntax-break) must set exit code 1"
    found = rules(findings)
    for expected in (
        "M001-fence-not-closed",
        "M009-non-mandated-keyword",
        "M005-empty-body",
        "M006-malformed-gantt-header",
        "M004-empty-block",
    ):
        assert expected in found, f"expected rule {expected} in {found}"


def test_syntax_breaks_are_high_and_style_is_medium(tmp_path):
    _, findings = run_linter(tmp_path, BROKEN)
    by_rule = {f["rule"]: f for f in findings}
    for rule in (
        "M001-fence-not-closed",
        "M004-empty-block",
        "M006-malformed-gantt-header",
    ):
        assert by_rule[rule]["severity"] == "HIGH", f"{rule} must be HIGH"
    assert by_rule["M009-non-mandated-keyword"]["severity"] == "MEDIUM", (
        "'graph' renders — a style finding, not a syntax break"
    )
    assert by_rule["M005-empty-body"]["severity"] == "MEDIUM", (
        "an empty typed diagram renders — a style finding, not a syntax break"
    )


def test_every_finding_carries_location_and_a_suggested_patch(tmp_path):
    for corpus in (BROKEN, EMPTY_TYPED):
        _, findings = run_linter(tmp_path, corpus)
        assert findings, "expected findings"
        for f in findings:
            assert f["file"].endswith("artifact.md")
            assert isinstance(f["line"], int) and f["line"] >= 1, "location line missing"
            assert isinstance(f["fence"], int) and f["fence"] >= 1, "fence index missing"
            assert f["suggestion"].strip(), f"no suggested patch for {f['rule']}"
            assert f["offending"].strip(), f"no offending line for {f['rule']}"


def test_fence_index_counts_blocks_in_order(tmp_path):
    _, findings = run_linter(tmp_path, BROKEN)
    fences = [f["fence"] for f in findings]
    assert fences == sorted(fences), "fence indices must be in document order"
    assert fences[0] == 1, "the first broken block is fence #1"
    assert fences[-1] == 5, "the truncated trailing block is the last fence"


# ── valid corpus: zero findings ─────────────────────────────────────────────

VALID = """\
# Valid corpus

```mermaid
flowchart TD
  A[Start] --> B[End]
```

```mermaid
sequenceDiagram
  participant A
  A->>B: hello
```

```mermaid
erDiagram
  CUSTOMER ||--o{ ORDER : places
```

```mermaid
gantt
  dateFormat YYYY-MM-DD
  section S1
  Task :a1, 2026-01-01, 3d
```

```mermaid
journey
  title My day
  section Go
    Make tea: 5: Me
```

```mermaid
gantt
    Task name : a1, 2024-01-01, 3d
```

```mermaid
gantt
  %% the roadmap
  dateFormat YYYY-MM-DD
  Task : a1, 2026-01-01, 3d
```

```mermaid
sequenceDiagram
  %% a note
  participant A
  A->>B: hi
```

```mermaid
erDiagram
  %% a note
  CUSTOMER ||--o{ ORDER : places
```

```mermaid
%% a leading comment
flowchart TD
  A --> B
```

```mermaid
%%{init: {"theme":"dark"}}%%
flowchart TD
  A --> B
```

```mermaid
flowchart TD
  A --> B
  %% a trailing comment
```
"""


def test_valid_corpus_has_no_findings(tmp_path):
    code, findings = run_linter(tmp_path, VALID)
    assert findings == [], f"valid corpus must not be flagged: {findings}"
    assert code == 0, "a clean scan must exit 0"


def test_indented_diagram_lines_are_accepted(tmp_path):
    """A diagram body is normally indented — the type keyword must still be
    recognised, and an indented statement must not read as an empty body."""
    text = "```mermaid\n  flowchart TD\n    A --> B\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert findings == [], f"indented valid block must not be flagged: {findings}"
    assert code == 0


# ── unknown type: MEDIUM, never a false HIGH (the mermaid detection pass) ─────────────────────

def test_unknown_diagram_type_is_medium_not_high(tmp_path):
    text = "```mermaid\nsomeFutureDiagram\n  whatever\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert len(findings) == 1
    assert findings[0]["rule"] == "M002-unknown-diagram-type"
    assert findings[0]["severity"] == "MEDIUM", "unknown type must never be a false HIGH"
    assert code == 2, "MEDIUM-only findings exit 2"


# ── the keyword table holds only real mermaid keywords ─────────────────────

@pytest.mark.parametrize("header", ["chart TD", "flow chart TD"])
def test_bogus_type_keywords_are_reported_never_silently_accepted(tmp_path, header):
    """`flow` and `chart` are not mermaid keywords — mermaid spells it
    `flowchart` (one word) or the legacy `graph`. A block that opens with
    one of them is an unknown type: MEDIUM, never a false HIGH, never
    silently accepted."""
    text = f"```mermaid\n{header}\n  A --> B\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert len(findings) == 1, f"{header!r} must be reported, got {findings}"
    assert findings[0]["rule"] == "M002-unknown-diagram-type"
    assert findings[0]["severity"] == "MEDIUM", "a bogus type is never a false HIGH"
    assert code == 2, "MEDIUM-only findings exit 2"


# ── gantt: a task line is a valid first statement ──────────────────────────

def test_gantt_may_open_with_a_task_line(tmp_path):
    """`dateFormat` is optional in mermaid — a gantt may open directly with
    a task line. Reporting it HIGH was a false syntax break."""
    text = "```mermaid\ngantt\n    Task name : a1, 2024-01-01, 3d\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert findings == [], f"a valid gantt must not be flagged: {findings}"
    assert code == 0


def test_gantt_may_open_with_a_tagged_task_line(tmp_path):
    """A task line carries optional tags before the id — still a task line."""
    text = "```mermaid\ngantt\n    Completed task :done, des1, 2026-01-06, 2026-01-08\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert findings == [], f"a valid gantt must not be flagged: {findings}"
    assert code == 0


def test_malformed_gantt_header_is_still_high(tmp_path):
    """A first statement that is neither a gantt key nor a task line is a
    syntax break — the finding stays HIGH."""
    text = "```mermaid\ngantt\n  this line is not a gantt key\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == ["M006-malformed-gantt-header"]
    assert findings[0]["severity"] == "HIGH"
    assert code == 1


def test_task_line_shaped_gantt_statement_is_at_most_medium(tmp_path):
    """An ambiguous task line is not a syntax break — never a false HIGH."""
    text = "```mermaid\ngantt\n    Task : a1\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert findings, "an ambiguous task line must still be reported"
    assert findings[0]["rule"] == "M006-malformed-gantt-header"
    assert findings[0]["severity"] == "MEDIUM", "never a false HIGH"
    assert code == 2, "MEDIUM-only findings exit 2"


# ── mermaid comments and directives carry no content ────────────────────────

def test_a_comment_is_not_read_as_the_diagram_type(tmp_path):
    """`%% …` is a comment and `%%{ … }%%` is a directive — mermaid strips
    both before it parses. A comment ahead of the type must not be read as
    the type, and a comment between the type and the first statement must not
    be read as the first statement: both are valid diagrams."""
    text = "```mermaid\n%% a leading comment\nflowchart TD\n  A --> B\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert findings == [], f"a comment-first diagram must not be flagged: {findings}"
    assert code == 0


def test_a_comment_is_not_read_as_the_first_statement(tmp_path):
    """The first *statement* is read, not the first line after the type — for
    every diagram type whose first statement is checked."""
    text = (
        "```mermaid\nsequenceDiagram\n  %% a note\n  participant A\n```\n"
    )
    code, findings = run_linter(tmp_path, text)
    assert findings == [], f"a comment-first diagram must not be flagged: {findings}"
    assert code == 0


def test_a_comment_below_the_first_statement_changes_nothing(tmp_path):
    """A comment after the first statement was already handled correctly —
    it stays that way."""
    text = "```mermaid\nflowchart TD\n  A --> B\n  %% a trailing comment\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert findings == [], f"a trailing comment must not be flagged: {findings}"
    assert code == 0


def test_a_comments_only_block_is_an_empty_block(tmp_path):
    """mermaid strips comments before it parses, so a block holding only a
    comment is an *empty* block to mermaid — and mermaid's own parser refuses
    it ("No diagram type detected"). The block cannot render, so the finding
    stays HIGH: a real syntax break, not a false one."""
    text = "```mermaid\n  %% only a comment\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == ["M004-empty-block"]
    assert findings[0]["severity"] == "HIGH"
    assert code == 1


def test_a_directive_only_block_is_an_empty_block(tmp_path):
    """A directive carries no diagram content either — same verdict."""
    text = "```mermaid\n%%{init: {\"theme\":\"dark\"}}%%\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == ["M004-empty-block"]
    assert findings[0]["severity"] == "HIGH"
    assert code == 1


def test_a_type_with_only_a_comment_below_it_is_an_empty_body(tmp_path):
    """A comment carries no content, so a type with only a comment below it
    has no statement either — it reads exactly like a type with nothing below
    it. mermaid renders it (an empty chart), so the finding is MEDIUM: a
    style finding, never a syntax break, and never silent."""
    text = "```mermaid\nflowchart TD\n  %% only a comment\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == ["M005-empty-body"]
    assert findings[0]["severity"] == "MEDIUM", (
        "an empty typed diagram renders — never a false HIGH"
    )
    assert findings[0]["line"] == 2, "the finding sits on the type-declaration line"
    assert code == 2, "MEDIUM-only findings exit 2"


# ── a declared type with no statement: renderable, so MEDIUM (never HIGH) ──

def test_an_empty_typed_diagram_renders_and_is_never_a_syntax_break(tmp_path):
    """The rationale for the severity: mermaid renders a typed diagram that
    carries no statement (an empty chart), so an empty body is not a syntax
    break. HIGH stays reserved for a block that cannot render at all."""
    text = "```mermaid\nflowchart TD\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == ["M005-empty-body"]
    assert findings[0]["severity"] == "MEDIUM", (
        "an empty typed diagram renders — never a false HIGH"
    )
    assert code == 2, "MEDIUM-only findings exit 2"


@pytest.mark.parametrize(
    "type_line",
    ["gantt", "sequenceDiagram", "erDiagram", "flowchart TD"],
    ids=["gantt", "sequence", "er", "flowchart"],
)
def test_a_typed_block_with_no_statement_is_reported_once_as_medium(tmp_path, type_line):
    """The empty-body rule is type-agnostic: a declared type with no
    statement produces exactly one finding — the same rule id for every
    type — located on the type-declaration line, with a non-empty offending
    text and a suggested patch. A finding never carries line 0."""
    text = f"```mermaid\n{type_line}\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == ["M005-empty-body"], (
        f"{type_line!r} with no statement must report exactly one finding, got {findings}"
    )
    finding = findings[0]
    assert finding["severity"] == "MEDIUM", (
        "an empty typed diagram renders — never a false HIGH"
    )
    assert finding["line"] == 2, "the finding sits on the type-declaration line"
    assert finding["line"] >= 1, "a finding must never carry line 0"
    assert finding["offending"].strip() == type_line, (
        "the offending text is the type declaration itself"
    )
    assert finding["suggestion"].strip(), "a suggested patch is required"
    assert code == 2, "MEDIUM-only findings exit 2"


def test_a_trailing_blank_line_does_not_silence_the_empty_body_finding(tmp_path):
    """The same condition must read the same: a body holding only a blank
    line carries no statement either, so the verdict is identical to the
    block with nothing below the type."""
    empty = run_linter(tmp_path, "```mermaid\nflowchart TD\n```\n")[1]
    blank = run_linter(tmp_path, "```mermaid\nflowchart TD\n\n```\n")[1]
    assert blank, "a blank body must not silence the finding"
    assert [(f["rule"], f["severity"], f["line"]) for f in empty] == [
        (f["rule"], f["severity"], f["line"]) for f in blank
    ]
    assert blank[0]["rule"] == "M005-empty-body"
    assert blank[0]["severity"] == "MEDIUM"


@pytest.mark.parametrize(
    ("type_line", "statement", "rule"),
    [
        ("sequenceDiagram", "this is not a participant", "M007-malformed-sequence-diagram"),
        # `this is not an entity` was pinned here as HIGH M008, but mermaid
        # parses it as five isolated entities and renders it — so it was a
        # false positive, not a malformed block. The er case now uses a shape
        # mermaid genuinely rejects: a name carrying `!`, outside the
        # entity-name grammar.
        ("erDiagram", "not an entity at all!!!", "M008-malformed-entity-diagram"),
    ],
    ids=["sequence", "er"],
)
def test_a_malformed_first_statement_keeps_the_per_type_rule_at_high(
    tmp_path, type_line, statement, rule
):
    """The empty-body change softened only the *empty* case: a first
    statement that exists but is malformed still trips the per-type rule at
    HIGH — a syntax break, not a style finding."""
    text = f"```mermaid\n{type_line}\n  {statement}\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert [f["rule"] for f in findings] == [rule]
    assert findings[0]["severity"] == "HIGH"
    assert findings[0]["line"] == 3, "the finding sits on the offending statement"
    assert code == 1


# ── shapes mermaid ACCEPTS must never be HIGH (the parser is the ground truth) ──
#
# Every shape below was fed to mermaid 12.2.0's own `mermaid.parse()`; the
# verdicts are recorded in the review evidence. A static validator that calls
# a parseable block a syntax break is a worse defect than the break it hunts:
# it trains authors to ignore the pass. So the contract asserted here is
# one-directional — mermaid accepts ⇒ the linter never says HIGH — and it is
# checked across the types the per-type rules cover.

# mermaid accepts each of these as a first statement (or as a whole block).
PARSEABLE_BUT_ONES_LINTER_FLAGGED = [
    # sequenceDiagram: documented statements missing from the keyword table.
    ("sequenceDiagram", "title My chart", "R5: `title` is a sequence statement"),
    ("sequenceDiagram", "autonumber", "R5: `autonumber` is a sequence statement"),
    (
        "sequenceDiagram",
        "box Grey Group\n    participant A\n  end",
        "`box` opens a participant group",
    ),
    (
        "sequenceDiagram",
        "critical\n    A->>B: x\n  end",
        "`critical` opens a critical block",
    ),
    (
        "sequenceDiagram",
        "break\n    A->>B: x\n  end",
        "`break` opens a break block",
    ),
    # erDiagram: a bare identifier list is not a relation, but it parses —
    # mermaid reads each identifier as an isolated entity and renders it.
    ("erDiagram", "CUSTOMER", "R4: a bare entity is a valid erDiagram"),
    ("erDiagram", "CUSTOMER ORDER", "several isolated entities"),
    ("erDiagram", "this is not an entity", "parsed as five isolated entities"),
    ("erDiagram", "customer_order-2.b", "the entity-name grammar allows these"),
]


@pytest.mark.parametrize(
    ("type_line", "statement", "why"),
    PARSEABLE_BUT_ONES_LINTER_FLAGGED,
    ids=[
        "seq-title",
        "seq-autonumber",
        "seq-box",
        "seq-critical",
        "seq-break",
        "er-bare-entity",
        "er-two-entities",
        "er-words-as-entities",
        "er-entity-name-grammar",
    ],
)
def test_a_block_mermaid_parses_is_never_reported_high(tmp_path, type_line, statement, why):
    """The direction that matters: mermaid accepts ⇒ never HIGH.

    The per-type rules may still describe the shape at MEDIUM (an erDiagram of
    bare entities is renderable but has no relation), but calling it a syntax
    break is false, and a false HIGH is what made the pass untrustworthy.
    """
    text = f"```mermaid\n{type_line}\n  {statement}\n```\n"
    _, findings = run_linter(tmp_path, text)
    highs = [f for f in findings if f["severity"] == "HIGH"]
    assert not highs, (
        f"mermaid parses this block, so HIGH is false ({why}): "
        f"{[(f['rule'], f['severity']) for f in findings]}"
    )


@pytest.mark.parametrize(
    ("type_line", "statement", "rule"),
    [
        ("sequenceDiagram", "title My chart", "M007-malformed-sequence-diagram"),
        ("sequenceDiagram", "autonumber", "M007-malformed-sequence-diagram"),
        ("erDiagram", "CUSTOMER", "M008-malformed-entity-diagram"),
        ("erDiagram", "this is not an entity", "M008-malformed-entity-diagram"),
    ],
    ids=["seq-title", "seq-autonumber", "er-bare", "er-multi"],
)
def test_a_parseable_first_statement_is_silenced_at_the_keyword_level(
    tmp_path, type_line, statement, rule
):
    """The shape is not merely downgraded — the per-type rule must not fire at
    all once the statement's head is a documented keyword for that type.

    A downgrade still leaves a finding an author has to triage; a documented
    `title`/`autonumber`/bare-entity statement is simply valid, so the pass
    has nothing to say about it."""
    text = f"```mermaid\n{type_line}\n  {statement}\n```\n"
    _, findings = run_linter(tmp_path, text)
    assert rule not in rules(findings), (
        f"{rule} must not fire on a shape mermaid parses: {findings}"
    )


# ── the shape that DOES stay HIGH (the other direction) ─────────────────────

def test_an_entity_name_outside_the_grammar_stays_high(tmp_path):
    """`!` is rejected by mermaid's entity-name grammar, so `not an entity at
    all!!!` is a genuine parse error even though it has no relation connector.
    Removing the bare-entity HIGH must not blanket-silence this."""
    text = "```mermaid\nerDiagram\n  not an entity at all!!!\n```\n"
    code, findings = run_linter(tmp_path, text)
    assert rules(findings) == ["M008-malformed-entity-diagram"]
    assert findings[0]["severity"] == "HIGH"
    assert code == 1


# ── read-only contract (the lifecycle write scope lifecycle write scope) ─────────────────────

def test_linter_does_not_modify_the_artifact(tmp_path):
    artifact = tmp_path / "artifact.md"
    artifact.write_text(BROKEN, encoding="utf-8")
    before = hashlib.sha256(artifact.read_bytes()).hexdigest()
    listing_before = sorted(p.name for p in tmp_path.iterdir())
    subprocess.run(
        ["bash", str(LINTER), "--tsv", str(artifact)],
        capture_output=True,
        text=True,
        timeout=30,
    )
    after = hashlib.sha256(artifact.read_bytes()).hexdigest()
    assert before == after, "the lint pass must not write to the artifact"
    assert sorted(p.name for p in tmp_path.iterdir()) == listing_before, (
        "the lint pass must not create files"
    )


def test_linter_is_deterministic(tmp_path):
    first = run_linter(tmp_path, BROKEN)[1]
    second = run_linter(tmp_path, BROKEN)[1]
    assert first == second, "the same input must yield the same findings"


# ── usage errors ───────────────────────────────────────────────────────────

def test_missing_file_is_a_usage_error(tmp_path):
    proc = subprocess.run(
        ["bash", str(LINTER), str(tmp_path / "nope.md")],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 3, "a missing file must not be reported as a finding"


def test_no_arguments_is_a_usage_error():
    proc = subprocess.run(
        ["bash", str(LINTER)], capture_output=True, text=True, timeout=30
    )
    assert proc.returncode == 3
