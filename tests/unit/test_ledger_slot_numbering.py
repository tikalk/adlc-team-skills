"""Ledger slot allocation: the next record number, read from every source of truth.

Regression class: `next_pdr_number()` in setup-product-{specify,init}.sh parsed
record filenames with `sed 's/PDR-//'` and then required the result to be purely
numeric. A stemmed record (say `PDR-002-amendment-2.md`, number 002) yields
`002-amendment-2`, fails `^[0-9]+$`, and is **silently skipped** — so a helper
whose highest record carries a suffix reports a slot that is already taken. It
also scanned `.adlc/drafts/pdr/` alone, ignoring published records in
`docs/adlc/memory/pdr/`, so a promoted record's slot was free to be reissued.

Contract under test (canonical helpers only — borrowers reference these):
- a record's number is the leading digits of its filename stem; suffixes are
  preserved and never arithmetically parsed (same rule `generate_adr_index`
  already pins in test_index_id_parsing.py)
- the maximum is taken across drafts AND published memory
- purely numeric stems keep the legacy %03d display
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
PDR_LIB = ROOT / "skills/product/product-clarify/scripts/bash/pdr-lib.sh"
SETUP_SPECIFY = ROOT / "skills/product/product-specify/scripts/bash/setup-product-specify.sh"
SETUP_INIT = ROOT / "skills/product/product-init/scripts/bash/setup-product-init.sh"
SETUP_ARCH = ROOT / "skills/architect/architect-clarify/scripts/bash/setup-architect.sh"


def _write_fm(path: Path, title: str = "T"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"---\nstatus: accepted\ndate: 2026-09-27\n---\n\n# {title}\n",
        encoding="utf-8",
    )


@pytest.fixture()
def tree(tmp_path):
    """Highest record in each family carries a suffixed stem.

    That is the shape the old parser dropped, so a helper that only reads bare
    `NAME-<digits>.md` reports a slot that is already taken.
    """
    _write_fm(tmp_path / ".adlc/drafts/pdr/PDR-002.md")
    _write_fm(tmp_path / ".adlc/drafts/pdr/PDR-009-amendment-2.md")
    _write_fm(tmp_path / ".adlc/drafts/adr/ADR-003.md")
    _write_fm(tmp_path / ".adlc/drafts/adr/ADR-004-workspace-profile.md")
    return tmp_path


def _run(script: str, cwd: Path, env_extra=None):
    env = {**os.environ, "REPO_ROOT": str(cwd)}
    env.update(env_extra or {})
    return subprocess.run(["bash", "-c", script], cwd=cwd, capture_output=True,
                          text=True, timeout=60, env=env)


# ── the shared rule ──────────────────────────────────────────────────────────

def test_next_record_number_counts_suffixed_stems(tree):
    r = _run(f'source "{PDR_LIB}"; next_record_number PDR "{tree}/.adlc/drafts/pdr"',
             tree)
    assert r.returncode == 0, r.stderr
    # PDR-009-amendment-2 is the highest; it must not be skipped.
    assert r.stdout.strip() == "010"


def test_next_record_number_is_max_across_drafts_and_published(tree):
    _write_fm(tree / "docs/adlc/memory/pdr/PDR-021-agentic-verification-depth.md")
    r = _run(
        f'source "{PDR_LIB}"; next_record_number PDR '
        f'"{tree}/.adlc/drafts/pdr" "{tree}/docs/adlc/memory/pdr"',
        tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "022"


def test_next_record_number_zero_pads_three_digits(tree):
    r = _run(f'source "{PDR_LIB}"; next_record_number ADR "{tree}/.adlc/drafts/adr"',
             tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "005"


# ── the borrowers must actually use it ───────────────────────────────────────

@pytest.mark.parametrize("script", [SETUP_SPECIFY, SETUP_INIT],
                         ids=lambda p: p.parent.parent.name)
def test_product_setup_scripts_have_no_local_numbering(script):
    """A local `next_pdr_number` is a stale copy of the shared rule."""
    text = Path(script).read_text(encoding="utf-8")
    assert "next_pdr_number()" not in text, (
        f"{script} redefines next_pdr_number; source pdr-lib.sh and call "
        "next_record_number instead")
    assert "next_record_number" in text


def _extract_func(dest: Path, source: Path, *funcs: str) -> Path:
    """Extract functions into a source-safe harness file.

    setup-architect.sh runs a case-dispatch on source, so tests source an
    extracted copy instead (same pattern as test_index_id_parsing.py). Fails
    loudly if a range can't be found, so a refactor can't silently empty it.
    """
    src = source.read_text(encoding="utf-8").split("\n")
    out = ["#!/usr/bin/env bash"]
    for func in funcs:
        start = next((i for i, l in enumerate(src) if l == f"{func}() {{"), None)
        assert start is not None, f"function {func}() not found in {source}"
        end = next((i for i in range(start + 1, len(src)) if src[i] == "}"), None)
        assert end is not None, f"end of {func}() not found"
        out.extend(src[start:end + 1])
    harness = dest / "adharness.sh"
    harness.write_text("\n".join(out) + "\n", encoding="utf-8")
    return harness


def test_architect_exposes_next_adr_number(tree):
    harness = _extract_func(tree, SETUP_ARCH, "next_adr_number")
    r = _run(f'source "{harness}"; next_adr_number "{tree}"', tree)
    assert r.returncode == 0, r.stderr
    # ADR-004-workspace-profile is the highest stem.
    assert r.stdout.strip() == "005"


def test_next_adr_number_spans_published_memory(tree):
    harness = _extract_func(tree, SETUP_ARCH, "next_adr_number")
    _write_fm(tree / "docs/adlc/memory/adr/ADR-017-monitoring-connector.md")
    r = _run(f'source "{harness}"; next_adr_number "{tree}"', tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "018"


# ── the generator owns the index format ──────────────────────────────────────

def test_generate_adr_index_rewrites_a_hand_drifted_index(tree):
    """A hand-normalised index (bare IDs, stray rows) is regenerated to contract.

    The checked-in memory index in a consuming repo renders a suffixed record's
    ID bare while its File cell carries the stem, and carries rows whose file
    does not exist. Both must be corrected by regeneration.
    """
    drifted = tree / ".adlc/drafts/adr/adr.md"
    drifted.write_text(
        "# Architecture Decision Records\n\n## ADR Index\n\n"
        "| ID | Sub-System | Decision | Status | Date | Decision Makers | File |\n"
        "|----|------------|----------|--------|------|------------------|------|\n"
        "| ADR-004 | s | d | accepted | 2026-01-01 | x | "
        "[ADR-004-workspace-profile.md](ADR-004-workspace-profile.md) |\n"
        "| ADR-0123 | s | d | accepted | 2026-01-01 | x | [ADR-0123.md](ADR-0123.md) |\n",
        encoding="utf-8")
    harness = _extract_func(tree, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title", "generate_adr_index")
    r = _run(f'source "{harness}"; generate_adr_index drafts', tree)
    assert r.returncode == 0, r.stderr
    out = drifted.read_text(encoding="utf-8")
    assert "| ADR-004-workspace-profile |" in out, "suffixed stem must render verbatim"
    assert "| ADR-0123 |" not in out, "a row with no file must not survive regeneration"
    assert "| ADR-003 |" in out, "bare numeric stem keeps its legacy display"


# ── PowerShell twin: same contract, same regression class ───────────────────

PDR_LIB_PS1 = ROOT / "skills/product/product-clarify/scripts/powershell/pdr-lib.ps1"
SETUP_SPECIFY_PS1 = ROOT / "skills/product/product-specify/scripts/powershell/setup-product-specify.ps1"
SETUP_INIT_PS1 = ROOT / "skills/product/product-init/scripts/powershell/setup-product-init.ps1"

needs_pwsh = pytest.mark.skipif(shutil.which("pwsh") is None,
                                reason="pwsh not installed")


@needs_pwsh
def test_powershell_next_record_number_counts_suffixed_stems(tree):
    r = subprocess.run(
        ["pwsh", "-NoProfile", "-Command",
         f'. "{PDR_LIB_PS1}"; '
         f'Get-NextRecordNumber -Prefix PDR -Dirs @("{tree}/.adlc/drafts/pdr")'],
        capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "010"


@needs_pwsh
def test_powershell_next_record_number_spans_published_memory(tree):
    _write_fm(tree / "docs/adlc/memory/pdr/PDR-021-agentic-verification-depth.md")
    r = subprocess.run(
        ["pwsh", "-NoProfile", "-Command",
         f'. "{PDR_LIB_PS1}"; Get-NextRecordNumber -Prefix PDR -Dirs @('
         f'"{tree}/.adlc/drafts/pdr", "{tree}/docs/adlc/memory/pdr")'],
        capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "022"


@pytest.mark.parametrize("script", [SETUP_SPECIFY_PS1, SETUP_INIT_PS1],
                         ids=lambda p: p.parent.parent.name)
def test_powershell_setup_scripts_have_no_local_numbering(script):
    text = Path(script).read_text(encoding="utf-8-sig")
    assert "Get-NextPdrNumber" not in text, (
        f"{script} redefines Get-NextPdrNumber; dot-source pdr-lib.ps1 and call "
        "Get-NextRecordNumber instead")
    assert "Get-NextRecordNumber" in text
    assert "pdr-lib.ps1" in text


# ── document-internal slots: PRD section, REQ id, Feature #, AD delta version ─

PRD_FIXTURE = """# Product Requirements Document

## 25. Agentic Verification Delta (v2.22.0)

| REQ ID | Title | Source PDR | Priority |
|--------|-------|-----------|----------|
| REQ-216 | Day-one agents | PDR-001 | P1 |

### 25.3 New Features (v2.22.0 Delta)

| Feature # | Name | Source PDRs |
|-----------|------|-------------|
| 69 | Multi-Agent MCP Declaration | PDR-001, PDR-002, PDR-003 |

## 26. Multi-Agent MCP Declaration Delta (v2.23.0)
"""

AD_FIXTURE = """# Architecture Description

## v13.18.0 Delta: Agentic Verification

## v13.19.0 Delta: Multi-Agent MCP Materialization
"""


@pytest.fixture()
def docs_tree(tree):
    (tree / "docs/adlc/product").mkdir(parents=True, exist_ok=True)
    (tree / "docs/adlc/architect").mkdir(parents=True, exist_ok=True)
    (tree / "docs/adlc/product/PRD.md").write_text(PRD_FIXTURE, encoding="utf-8")
    (tree / "docs/adlc/architect/AD.md").write_text(AD_FIXTURE, encoding="utf-8")
    return tree


def test_next_prd_section_reads_the_document(docs_tree):
    r = _run(f'source "{PDR_LIB}"; next_prd_section "{docs_tree}/docs/adlc/product/PRD.md"',
             docs_tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "27"


def test_next_req_id_reads_the_document(docs_tree):
    r = _run(f'source "{PDR_LIB}"; next_req_id "{docs_tree}/docs/adlc/product/PRD.md"',
             docs_tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "217"


def test_next_feature_number_reads_the_document(docs_tree):
    r = _run(f'source "{PDR_LIB}"; next_feature_number "{docs_tree}/docs/adlc/product/PRD.md"',
             docs_tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "70"


def test_next_ad_delta_version_bumps_the_minor(docs_tree):
    harness = _extract_func(docs_tree, SETUP_ARCH, "next_ad_delta_version")
    r = _run(f'source "{harness}"; next_ad_delta_version "{docs_tree}/docs/adlc/architect/AD.md"',
             docs_tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "v13.20.0"


# ── the staleness precondition: a slot read from a stale base is still wrong ─

PATHS_SH = ROOT / "skills/team/workspace/scripts/bash/paths.sh"


def _git(repo, *args):
    subprocess.run(["git", *args], cwd=repo, capture_output=True, check=True)


@pytest.fixture()
def stale_repo(tmp_path):
    """`feature` sits one commit behind `main`.

    Built without a remote on purpose: the guard names its target, so a local
    ref exercises the same code path.
    """
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.name", "T")
    _git(repo, "config", "user.email", "t@example.com")
    _git(repo, "config", "commit.gpgsign", "false")
    (repo / "a.txt").write_text("a\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-qm", "a")
    # Name the base explicitly: `git init` may default to `master`, and the
    # tests target `main`.
    _git(repo, "branch", "-M", "main")
    _git(repo, "branch", "feature")
    (repo / "b.txt").write_text("b\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-qm", "b")
    _git(repo, "checkout", "-q", "feature")
    return repo


def test_ledger_base_behind_counts_only_the_commits_you_lack(stale_repo):
    """`git rev-list --left-right --count A...B` reports "left right" and the
    columns are trivial to transpose -- that misread is what let an intent run
    claim slots main already used. This reports ONE number."""
    r = _run(f'source "{PATHS_SH}"; ledger_base_behind main', stale_repo)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "1"


def test_ledger_base_behind_is_zero_when_current(stale_repo):
    r = _run(f'source "{PATHS_SH}"; ledger_base_behind HEAD', stale_repo)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "0"


def test_require_current_base_refuses_a_stale_base(stale_repo):
    r = _run(f'source "{PATHS_SH}"; require_current_base main; echo "rc=$?"', stale_repo)
    assert "rc=1" in r.stdout, f"must refuse a stale base: {r.stdout} {r.stderr}"
    assert "behind" in r.stderr, "the refusal must say what is wrong"


def test_require_current_base_passes_when_current(stale_repo):
    r = _run(f'source "{PATHS_SH}"; require_current_base HEAD; echo "rc=$?"', stale_repo)
    assert "rc=0" in r.stdout, f"must accept a current base: {r.stdout} {r.stderr}"


# ── PowerShell twins of the document slots and the staleness guard ──────────

PATHS_PS1 = ROOT / "skills/team/workspace/scripts/powershell/paths.ps1"
SETUP_ARCH_PS1 = ROOT / "skills/architect/architect-clarify/scripts/powershell/setup-architect.ps1"


def _pwsh(script: str):
    return subprocess.run(["pwsh", "-NoProfile", "-Command", script],
                          capture_output=True, text=True, timeout=60)


@needs_pwsh
def test_powershell_document_slots_match_the_bash_contract(docs_tree):
    r = _pwsh(
        f'. "{PDR_LIB_PS1}"; '
        f'Get-NextPrdSection "{docs_tree}/docs/adlc/product/PRD.md"; '
        f'Get-NextReqId "{docs_tree}/docs/adlc/product/PRD.md"; '
        f'Get-NextFeatureNumber "{docs_tree}/docs/adlc/product/PRD.md"')
    assert r.returncode == 0, r.stderr
    assert r.stdout.split() == ["27", "217", "70"]


@needs_pwsh
def test_powershell_ad_delta_version_matches_the_bash_contract(docs_tree):
    r = _pwsh(f'. "{SETUP_ARCH_PS1}"; '
              f'Get-NextAdDeltaVersion "{docs_tree}/docs/adlc/architect/AD.md"')
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "v13.20.0"


@needs_pwsh
def test_powershell_staleness_guard_refuses_a_stale_base(stale_repo):
    ok = _pwsh(f'cd "{stale_repo}"; . "{PATHS_PS1}"; Assert-CurrentBase main')
    assert ok.stdout.strip() == "False", f"must refuse: {ok.stdout} {ok.stderr}"
    assert "behind" in ok.stderr
    cur = _pwsh(f'cd "{stale_repo}"; . "{PATHS_PS1}"; Assert-CurrentBase HEAD')
    assert cur.stdout.strip() == "True", f"must accept: {cur.stdout} {cur.stderr}"


def test_powershell_twins_are_declared_for_the_new_helpers():
    """Text-level twin check: runs without pwsh, so the contract holds locally.

    The runtime cases above skip where pwsh is absent; this still fails if a
    twin goes missing entirely.
    """
    for label, path, names in [
        ("paths.ps1", PATHS_PS1, ["Get-LedgerBaseBehind", "Assert-CurrentBase"]),
        ("pdr-lib.ps1", PDR_LIB_PS1,
         ["Get-NextPrdSection", "Get-NextReqId", "Get-NextFeatureNumber"]),
        ("setup-architect.ps1", SETUP_ARCH_PS1, ["Get-NextAdDeltaVersion"]),
    ]:
        text = Path(path).read_text(encoding="utf-8-sig")
        for name in names:
            assert f"function {name}" in text, f"{label} must define {name}"
