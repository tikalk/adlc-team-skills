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

    setup-architect.sh is execution-guarded now, but extracting the one
    function under test keeps the harness minimal (same pattern as
    test_index_id_parsing.py). Fails
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


# ── the sourcing contract: `source setup-architect.sh` defines helpers only ──


def test_setup_architect_sh_is_source_safe(docs_tree):
    """The SKILL.md "Claiming Ledger Slots" flow sources setup-architect.sh
    and then calls its helpers, so a source must run no action: the argument
    parse, the default action and the dispatch belong to execution only.
    Before the guard, a bare source picked the default action and ran the
    whole update/init flow -- banner on stderr, `.adlc/` directories seeded
    into the caller's repo."""
    r = _run(f'source "{SETUP_ARCH}"; '
             f'next_ad_delta_version "{docs_tree}/docs/adlc/architect/AD.md"',
             docs_tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "v13.20.0", (
        f"sourcing setup-architect.sh must define helpers and run nothing "
        f"else; got stdout={r.stdout!r}")
    assert r.stderr == "", (
        f"sourcing setup-architect.sh must run no action; got stderr={r.stderr!r}")
    assert not (docs_tree / ".adlc" / "memory").exists(), (
        "sourcing setup-architect.sh must not seed directories")


# ── octal guard: zero-padded IDs ≥ 008 must not abort index generation ─────────

def _write_fm_status(path: Path, status: str, title: str = "T"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"---\nstatus: {status}\ndate: 2026-11-04\n---\n\n# {title}\n",
        encoding="utf-8",
    )


def test_generate_adr_index_handles_octal_looking_ids(tmp_path):
    """ADR-008/ADR-009 must render, byte-identical to the PDR-side 10# guard."""
    for stem, title in (("ADR-008", "Eight"), ("ADR-009", "Nine")):
        _write_fm_status(tmp_path / f".adlc/drafts/adr/{stem}.md", "proposed", title)
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title", "generate_adr_index")
    r = _run(f'source "{harness}"; generate_adr_index drafts', tmp_path)
    assert r.returncode == 0, f"octal abort: {r.stderr}"
    assert "invalid octal" not in r.stderr
    out = (tmp_path / ".adlc/drafts/adr/adr.md").read_text(encoding="utf-8")
    assert "| ADR-008 |" in out
    assert "| ADR-009 |" in out
    assert "ADR-000" not in out


def test_generate_adr_index_octal_ids_stay_byte_stable(tmp_path):
    """008/009 render through the same %03d path as 007: one code path."""
    for stem, title in (("ADR-007", "Seven"), ("ADR-008", "Eight")):
        _write_fm_status(tmp_path / f".adlc/drafts/adr/{stem}.md", "proposed", title)
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title", "generate_adr_index")
    r = _run(f'source "{harness}"; generate_adr_index drafts', tmp_path)
    assert r.returncode == 0, r.stderr
    out = (tmp_path / ".adlc/drafts/adr/adr.md").read_text(encoding="utf-8")
    assert "| ADR-007 |" in out and "| ADR-008 |" in out


def test_get_adr_by_id_accepts_octal_looking_bare_ids(tmp_path):
    """get_adr_by_id 8 / 008 must resolve ADR-008.md without an octal error."""
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-008.md", "proposed", "Eight")
    harness = _extract_func(tmp_path, SETUP_ARCH, "get_adr_by_id")
    for given in ("8", "008"):
        r = _run(f'source "{harness}"; get_adr_by_id "{given}" drafts', tmp_path)
        assert r.returncode == 0, f"id {given}: {r.stderr}"
        assert "Eight" in r.stdout
        assert "invalid octal" not in r.stderr


def test_write_and_move_adr_accept_octal_looking_ids(tmp_path):
    """write_adr 8 → ADR-008.md; move_adr 8 drafts memory — no octal abort."""
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title",
                            "generate_adr_index", "move_adr", "write_adr")
    r = _run(f'source "{harness}"; write_adr 8 "---\\nstatus: proposed\\n---\\n\\n# Eight\\n" drafts',
             tmp_path)
    assert r.returncode == 0, f"write_adr octal abort: {r.stderr}"
    assert (tmp_path / ".adlc/drafts/adr/ADR-008.md").exists()
    r = _run(f'source "{harness}"; move_adr 8 drafts memory', tmp_path)
    assert r.returncode == 0, f"move_adr octal abort: {r.stderr}"
    assert (tmp_path / "docs/adlc/memory/adr/ADR-008.md").exists()
    assert "invalid octal" not in r.stderr


# ── prefixed + suffixed IDs: Important 1+2 fix (callers may pass full IDs) ──

def test_get_adr_by_id_accepts_prefixed_ids(tmp_path):
    """get_adr_by_id 'ADR-008' must resolve ADR-008.md (Important 1).

    Callers (implement flows, slash-command args) pass the full display ID;
    without prefix-stripping this looks up ADR-ADR-008.md and returns 1.
    """
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-008.md", "proposed", "Eight")
    harness = _extract_func(tmp_path, SETUP_ARCH, "get_adr_by_id")
    r = _run(f'source "{harness}"; get_adr_by_id "ADR-008" drafts', tmp_path)
    assert r.returncode == 0, f"prefixed id rejected: {r.stderr}"
    assert "Eight" in r.stdout
    assert "invalid octal" not in r.stderr


def test_move_adr_accepts_prefixed_ids(tmp_path):
    """move_adr 'ADR-008' drafts memory must move ADR-008.md (Important 2).

    The bare-ID path silently no-ops on prefixed input (rc 0, file stays),
    so this pins the files, not just the return code.
    """
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-008.md", "proposed", "Eight")
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title",
                            "generate_adr_index", "move_adr")
    r = _run(f'source "{harness}"; move_adr "ADR-008" drafts memory', tmp_path)
    assert r.returncode == 0, r.stderr
    assert (tmp_path / "docs/adlc/memory/adr/ADR-008.md").exists(), (
        f"prefixed move left no dest: {r.stdout} {r.stderr}")
    assert not (tmp_path / ".adlc/drafts/adr/ADR-008.md").exists()
    assert "invalid octal" not in r.stderr


def test_move_pdr_accepts_prefixed_ids(tmp_path):
    """move_pdr 'PDR-008' drafts memory must move PDR-008.md (Important 2, PDR side)."""
    _write_fm_status(tmp_path / ".adlc/drafts/pdr/PDR-008.md", "accepted", "Eight")
    r = _run(f'source "{PDR_LIB}"; move_pdr "PDR-008" drafts memory', tmp_path)
    assert r.returncode == 0, f"prefixed pdr id rejected: {r.stderr}"
    assert (tmp_path / "docs/adlc/memory/pdr/PDR-008.md").exists(), (
        f"prefixed move left no dest: {r.stdout} {r.stderr}")
    assert not (tmp_path / ".adlc/drafts/pdr/PDR-008.md").exists()


def test_get_adr_by_id_accepts_suffixed_ids(tmp_path):
    """Suffixed stems resolve verbatim: '008-amendment-2' → ADR-008-amendment-2.md.

    Pins that the prefixed-ID fix must not strip or re-parse suffixes
    (008-amendment-2 is not 0082).
    """
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-008-amendment-2.md",
                     "proposed", "Eight Amended")
    harness = _extract_func(tmp_path, SETUP_ARCH, "get_adr_by_id")
    for given in ("008-amendment-2", "ADR-008-amendment-2"):
        r = _run(f'source "{harness}"; get_adr_by_id "{given}" drafts', tmp_path)
        assert r.returncode == 0, f"id {given}: {r.stderr}"
        assert "Eight Amended" in r.stdout
        assert "invalid octal" not in r.stderr


def test_move_adr_accepts_suffixed_ids(tmp_path):
    """move_adr moves suffixed stems verbatim, bare or prefixed."""
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-008-amendment-2.md",
                     "proposed", "Eight Amended")
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-009-workspace-profile.md",
                     "proposed", "Nine Profile")
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title",
                            "generate_adr_index", "move_adr")
    for given, stem in (("008-amendment-2", "ADR-008-amendment-2"),
                        ("ADR-009-workspace-profile", "ADR-009-workspace-profile")):
        r = _run(f'source "{harness}"; move_adr "{given}" drafts memory', tmp_path)
        assert r.returncode == 0, f"id {given}: {r.stderr}"
        assert (tmp_path / f"docs/adlc/memory/adr/{stem}.md").exists(), (
            f"suffixed move left no dest: {r.stdout} {r.stderr}")
        assert not (tmp_path / f".adlc/drafts/adr/{stem}.md").exists()


def test_get_adr_by_id_rejects_lowercase_prefix(tmp_path):
    """'adr-008' must NOT resolve: IDs are case-sensitive (ADR- prefix only)."""
    _write_fm_status(tmp_path / ".adlc/drafts/adr/ADR-008.md", "proposed", "Eight")
    harness = _extract_func(tmp_path, SETUP_ARCH, "get_adr_by_id")
    r = _run(f'source "{harness}"; get_adr_by_id "adr-008" drafts; echo "rc=$?"',
             tmp_path)
    assert "rc=1" in r.stdout, f"lowercase id must not resolve: {r.stdout} {r.stderr}"


# No PS twin for get/move ADR by ID: setup-architect.ps1 defines no
# Get-AdrById/Move-Adr (only Get-NextAdrNumber and friends), so there is
# nothing to pin on the PS side. Revisit if the fixer adds them.


@needs_pwsh
def test_powershell_move_pdr_accepts_prefixed_ids(tmp_path):
    """Move-Pdr 'PDR-008' drafts memory — prefixed IDs resolve (PS twin of
    test_move_pdr_accepts_prefixed_ids)."""
    _write_fm_status(tmp_path / ".adlc/drafts/pdr/PDR-008.md", "accepted", "Eight")
    r = _pwsh(
        f'$REPO_ROOT = "{tmp_path}"; . "{PDR_LIB_PS1}"; '
        f'Move-Pdr "PDR-008" drafts memory')
    assert r.returncode == 0, r.stderr
    assert "False" not in r.stdout.split(), f"prefixed move refused: {r.stdout} {r.stderr}"
    assert (tmp_path / "docs/adlc/memory/pdr/PDR-008.md").exists()
    assert not (tmp_path / ".adlc/drafts/pdr/PDR-008.md").exists()


def test_generate_pdr_index_derives_header_and_titlecase_status(tmp_path):
    """All-Accepted drafts must not claim 'Proposed PDRs only'; status
    renders Title-Case like adr.md ('Accepted', not frontmatter 'accepted')."""
    _write_fm_status(tmp_path / ".adlc/drafts/pdr/PDR-008.md", "accepted", "All Accepted")
    _write_fm_status(tmp_path / ".adlc/drafts/pdr/PDR-009.md", "accepted", "Also Accepted")
    r = _run(f'source "{PDR_LIB}"; generate_pdr_index drafts', tmp_path)
    assert r.returncode == 0, r.stderr
    out = (tmp_path / ".adlc/drafts/pdr/pdr.md").read_text(encoding="utf-8")
    assert "Proposed PDRs only" not in out
    assert "| Accepted |" in out
    assert "| accepted |" not in out


def test_generate_pdr_index_mixed_status_keeps_drafts_header(tmp_path):
    """Mixed Proposed/Accepted drafts keep the Drafts header; both title-cased."""
    _write_fm_status(tmp_path / ".adlc/drafts/pdr/PDR-008.md", "accepted", "Done")
    _write_fm_status(tmp_path / ".adlc/drafts/pdr/PDR-009.md", "proposed", "Pending")
    r = _run(f'source "{PDR_LIB}"; generate_pdr_index drafts', tmp_path)
    assert r.returncode == 0, r.stderr
    out = (tmp_path / ".adlc/drafts/pdr/pdr.md").read_text(encoding="utf-8")
    assert "(Drafts)" in out
    assert "| Accepted |" in out and "| Proposed |" in out


def test_count_pdr_accepted_matches_derived_index(tmp_path):
    """count_pdr_accepted must agree with generate_pdr_index status cells:
    frontmatter lower-case 'accepted' counts (the legacy grep did not)."""
    from pathlib import Path as _P
    (_P(tmp_path) / ".adlc/drafts/pdr").mkdir(parents=True, exist_ok=True)
    for stem, status in (("PDR-008", "accepted"), ("PDR-009", "Accepted"),
                         ("PDR-012", "proposed")):
        (_P(tmp_path) / f".adlc/drafts/pdr/{stem}.md").write_text(
            f"---\nstatus: {status}\ndate: 2026-11-04\nowner: me\ncategory: F\n"
            f"feature-area: core\ntitle: T\n---\n\n# T\n", encoding="utf-8")
    import subprocess as _sp, os as _os
    r = _sp.run(["bash", "-c", f'source \"{PDR_LIB}\"; count_pdr_accepted '
                 f'\"{tmp_path}/.adlc/drafts/pdr\"'],
                capture_output=True, text=True, timeout=60,
                env={**_os.environ, "REPO_ROOT": str(tmp_path)})
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "2", f"frontmatter accepted undercounted: {r.stdout!r}"


def test_setup_architect_preview_flag_exists(tmp_path):
    """`implement --preview` must exist: lists ADRs/views/rewrites without
    writing AD.md, views, or moving drafts (factory dry-run parity)."""
    import subprocess as _sp, os as _os
    src = SETUP_ARCH.read_text(encoding="utf-8")
    assert "--preview" in src, "setup-architect.sh must accept --preview"
    assert "PREVIEW" in src, "implement must gate writes behind PREVIEW"
