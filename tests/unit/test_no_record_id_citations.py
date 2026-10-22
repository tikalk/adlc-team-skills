"""No file in this repository may cite a decision-record id.

This repository holds **no decision records of its own** — the catalogue is
centralized in the adlc-workspace (``docs/decision-memory.md`` records that
centralization). Every id cited here therefore pointed at a file in another
repository, and at an id that can move under the citation: a workspace
record was renumbered while a branch here was open, which would have left
the citation resolving to a different decision.

So a shipped skill names the *decision* in prose, never by id. What is
allowed is the **local example namespace** — the ids used when illustrating
a record the skills create in a consumer's own workspace, and the fixtures
the tests write to exercise the id parsers. Those are part of this
repository's own output contract, not citations of a record it does not own.
"""

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent

ID_RE = re.compile(r"\b(?:ADR|PDR)-\d{3,4}(?:-[a-z0-9-]+)?\b")

# The local example namespace. ADR-000 is the placeholder the setup scripts
# write; ADR-001..ADR-009 and PDR-001..PDR-012 are the worked examples in
# the templates and docs; ADR-012 / PDR-009 are examples in the eval
# scenarios; ADR-0123 / PDR-0123 are the status-vocabulary placeholders; the
# "-amendment-2" forms are the suffixed ids the parser fixtures use.
LOCAL_EXAMPLE_IDS = {
    "ADR-000", "ADR-001", "ADR-002", "ADR-003", "ADR-003-amendment-2",
    "ADR-004", "ADR-005", "ADR-006", "ADR-007", "ADR-008", "ADR-009",
    "ADR-012", "ADR-0123",
    "PDR-000", "PDR-001", "PDR-002", "PDR-002-amendment-2", "PDR-003",
    "PDR-004", "PDR-005", "PDR-008", "PDR-009", "PDR-012", "PDR-0123",
}

# The surfaces the rule covers.
SCANNED = [
    "skills", "evals", "docs", "tests", "scripts",
    "README.md", "AGENTS.md", "CHANGELOG.md", "CONTRIBUTING.md", "RELEASE.md",
]
SUFFIXES = (".md", ".sh", ".ps1", ".yml", ".yaml", ".py", ".json", ".js")
# Generated or vendored trees: not source, not policed.
SKIP_DIRS = {".git", ".agents", ".opencode", "node_modules", "results", "__pycache__"}


def repo_files():
    for target in SCANNED:
        path = ROOT / target
        if not path.exists():
            continue
        files = [path] if path.is_file() else [f for f in path.rglob("*") if f.is_file()]
        for f in files:
            if f.suffix not in SUFFIXES:
                continue
            if any(part in SKIP_DIRS for part in f.parts):
                continue
            yield f


def cited_ids():
    """Every record id cited in the repository, with its locations."""
    found = {}
    for path in repo_files():
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for match in ID_RE.finditer(line):
                found.setdefault(match.group(0), []).append(
                    f"{path.relative_to(ROOT)}:{lineno}"
                )
    return found


def test_no_workspace_record_citations():
    offenders = {
        cid: where
        for cid, where in cited_ids().items()
        if cid not in LOCAL_EXAMPLE_IDS
    }
    assert not offenders, (
        "this repository owns no decision records — do not cite their ids:\n"
        + "\n".join(f"  {cid}: {len(where)} occurrence(s), e.g. {where[0]}"
                    for cid, where in sorted(offenders.items()))
        + "\nFix: name the decision in prose; keep ids only in the local "
          "example namespace (see LOCAL_EXAMPLE_IDS in this test)."
    )


def test_local_example_ids_are_all_in_use():
    """The allowlist is not padded with dead entries — it mirrors reality."""
    stale = LOCAL_EXAMPLE_IDS - set(cited_ids())
    assert not stale, f"allowlist lists ids nothing uses any more: {sorted(stale)}"


def test_the_sweep_actually_found_something():
    """Guard against a regex that silently matches nothing."""
    found = cited_ids()
    assert len(found) >= 20, f"the id scan found only {len(found)} ids — is the regex still right?"


def test_decision_memory_states_the_centralization():
    """The record of *why* this repo cites no ids must survive the sweep."""
    text = (ROOT / "docs/decision-memory.md").read_text(encoding="utf-8")
    assert "no ADR/PDR memory of its own" in text, (
        "docs/decision-memory.md must keep stating that this repo owns no records"
    )
    assert "cites no record IDs" in text, (
        "docs/decision-memory.md must state the no-citation rule"
    )


def test_the_installed_mirror_obeys_the_same_rule():
    """The mirror is what consumers actually install — it must obey too."""
    mirror = ROOT / ".agents/skills"
    if not mirror.exists():
        pytest.skip("installed mirror absent — regenerate with adlc-cli")
    offenders = []
    for path in mirror.rglob("*"):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        for match in ID_RE.finditer(path.read_text(encoding="utf-8", errors="replace")):
            if match.group(0) not in LOCAL_EXAMPLE_IDS:
                offenders.append(f"{path.relative_to(ROOT)}: {match.group(0)}")
    assert not offenders, f"the installed mirror cites record ids: {offenders[:10]}"
