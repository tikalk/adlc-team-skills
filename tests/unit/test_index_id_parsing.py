"""Golden tests for suffixed decision-record IDs (amendment variants).

Regression class: render/parse/resolve helpers assumed bare `NAME-<digits>.md`
filenames. Suffixed variants (`-amendment`, `-amendment-2`, `-workspace-profile`)
broke three ways: ID parse miss (whole filename as ID), corrupt render
(`printf %03d` on non-numeric → `ADR-000`), and wrong-file targeting
(digit-strip turned `003-amendment-2` into `0032`).

Contract under test (canonical helpers only — borrowers reference these):
- IDs are filename stems verbatim; purely numeric stems keep legacy %03d display
- lexical filename sort (zero-padded repos keep amendment-before-base order)
- resolve exact stems first (`ADR-<given>.md`), numeric fallback for bare IDs
- path separators rejected (traversal guard replacing accidental digit-strip sanitizing)
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SETUP_ARCH = ROOT / "skills/architect/architect-clarify/scripts/bash/setup-architect.sh"
PDR_LIB = ROOT / "skills/product/product-clarify/scripts/bash/pdr-lib.sh"

ADR_FUNCS = ["parse_fm_field", "parse_fm_title", "generate_adr_index",
             "get_adr_by_id", "list_adrs", "write_adr", "move_adr"]


def _extract_adr_harness(dest: Path, source: Path = SETUP_ARCH) -> Path:
    """Extract ADR helper functions into a source-safe harness file.

    setup-architect.sh executes a case-dispatch on source, so tests source an
    extracted copy instead. Fails loudly if a function range can't be found
    (keeps the test honest when the source file is refactored).
    """
    src = source.read_text(encoding="utf-8").split("\n")
    out = ["#!/usr/bin/env bash"]
    for func in ADR_FUNCS:
        start = next((i for i, l in enumerate(src) if l == f"{func}() {{"), None)
        assert start is not None, f"function {func}() not found"
        end = next((i for i in range(start + 1, len(src)) if src[i] == "}"), None)
        assert end is not None, f"end of {func}() not found"
        out.extend(src[start:end + 1])
    harness = dest / "adr-harness.sh"
    harness.write_text("\n".join(out) + "\n", encoding="utf-8")
    return harness
def _write_fm(path: Path, status="Proposed", title=None, extra=""):
    title = title if title is not None else path.stem
    path.write_text(
        f"---\nstatus: {status}\ndate: 2026-09-27\n---\n\n# {title}\n\n{extra}\n",
        encoding="utf-8",
    )


@pytest.fixture()
def adlc_tree(tmp_path):
    """Fixture project: bare + suffixed ADR/PDR drafts with frontmatter."""
    drafts_adr = tmp_path / ".adlc" / "drafts" / "adr"
    drafts_pdr = tmp_path / ".adlc" / "drafts" / "pdr"
    drafts_adr.mkdir(parents=True)
    drafts_pdr.mkdir(parents=True)
    _write_fm(drafts_adr / "ADR-003.md")
    _write_fm(drafts_adr / "ADR-003-amendment-2.md")
    _write_fm(drafts_pdr / "PDR-002.md")
    _write_fm(drafts_pdr / "PDR-002-amendment-2.md")
    return tmp_path


def _run_bash(script: str, cwd: Path, env_extra=None):
    env = {**os.environ, "REPO_ROOT": str(cwd)}
    if env_extra:
        env.update(env_extra)
    return subprocess.run(["bash", "-c", script], cwd=cwd, capture_output=True,
                          text=True, timeout=60, env=env)


def test_adr_render_preserves_suffixed_ids(adlc_tree):
    harness = _extract_adr_harness(adlc_tree)
    r = _run_bash(f'source "{harness}"; generate_adr_index drafts', adlc_tree)
    assert r.returncode == 0, r.stderr
    index = (adlc_tree / ".adlc/drafts/adr/adr.md").read_text(encoding="utf-8")
    assert "| ADR-003-amendment-2 |" in index
    assert "| ADR-003 |" in index
    assert "ADR-000" not in index
    # lexical order: amendment row precedes its base row
    assert index.index("ADR-003-amendment-2") < index.index("| ADR-003 |")


def test_adr_resolve_never_strips_suffixes(adlc_tree):
    harness = _extract_adr_harness(adlc_tree)
    script = (f'source "{harness}"; '
              'get_adr_by_id "003-amendment-2" drafts | grep -c "ADR-003-amendment-2"; '
              'get_adr_by_id "003" drafts | grep -c "ADR-003"; '
              'get_adr_by_id "nope" drafts; echo "missing-rc=$?"')
    r = _run_bash(script, adlc_tree)
    assert r.returncode == 0, r.stderr
    assert r.stdout.splitlines()[:2] == ["1", "1"]  # both greps found their title line
    assert "missing-rc=1" in r.stdout
    # traversal rejected, no file read
    r2 = _run_bash(f'source "{harness}"; get_adr_by_id "../x" drafts; echo "rc=$?"', adlc_tree)
    assert "rc=1" in r2.stdout


def test_adr_move_and_list_preserve_stems(adlc_tree):
    harness = _extract_adr_harness(adlc_tree)
    r = _run_bash(f'source "{harness}"; move_adr "003-amendment-2" drafts memory; '
                  'list_adrs memory; echo "---"; list_adrs drafts', adlc_tree)
    assert r.returncode == 0, r.stderr
    assert (adlc_tree / "docs/adlc/memory/adr/ADR-003-amendment-2.md").exists()
    assert not (adlc_tree / ".adlc/drafts/adr/ADR-003-amendment-2.md").exists()
    assert "003-amendment-2" in r.stdout
    assert "0032" not in r.stdout  # the old strip-digits corruption


def test_pdr_render_and_move_preserve_suffixed_ids(adlc_tree):
    r = _run_bash(f'source "{PDR_LIB}"; generate_pdr_index drafts', adlc_tree)
    assert r.returncode == 0, r.stderr
    index = (adlc_tree / ".adlc/drafts/pdr/pdr.md").read_text(encoding="utf-8")
    assert "| PDR-002-amendment-2 |" in index
    assert "| PDR-002 |" in index
    assert "PDR-000" not in index
    assert "2#PDR" not in r.stdout + r.stderr
    r2 = _run_bash(f'source "{PDR_LIB}"; move_pdr "002-amendment-2" drafts memory', adlc_tree)
    assert r2.returncode == 0, r2.stderr
    assert (adlc_tree / "docs/adlc/memory/pdr/PDR-002-amendment-2.md").exists()


def _bare_fixture(base: Path):
    """Suffixed-free fixture: only bare numeric names."""
    for d, names in (("adr", ["ADR-003.md", "ADR-007.md"]),
                     ("pdr", ["PDR-002.md", "PDR-9.md"])):
        dd = base / ".adlc" / "drafts" / d
        dd.mkdir(parents=True)
        for n in names:
            _write_fm(dd / n)


def _generate_all(root: Path, adr_src: Path, pdr_src: Path):
    """Run both index generators with REPO_ROOT=root; return (adr.md, pdr.md)."""
    harness = _extract_adr_harness(root, source=adr_src)
    r1 = _run_bash(f'source "{harness}"; generate_adr_index drafts', root)
    assert r1.returncode == 0, r1.stderr
    r2 = _run_bash(f'source "{pdr_src}"; generate_pdr_index drafts', root)
    assert r2.returncode == 0, r2.stderr + r2.stdout
    return ((root / ".adlc/drafts/adr/adr.md").read_text(encoding="utf-8"),
            (root / ".adlc/drafts/pdr/pdr.md").read_text(encoding="utf-8"))


def test_bare_numeric_names_byte_stable(tmp_path):
    """No display-rule change for bare-numeric names: rows for bare IDs are
    byte-identical old vs new on a suffixed-free fixture. The index header
    line is excluded: 'Proposed PDRs only' -> 'All PDRs' is an intended
    contract change (drafts hold mixed statuses), pinned in
    test_ledger_slot_numbering.py."""
    new_root, old_root = tmp_path / "new", tmp_path / "old"
    _bare_fixture(new_root)
    _bare_fixture(old_root)
    new_out = _generate_all(new_root, SETUP_ARCH, PDR_LIB)
    old_setup = old_root / "old-setup-architect.sh"
    old_setup.write_text(
        subprocess.run(["git", "show", f"HEAD:{SETUP_ARCH.relative_to(ROOT)}"],
                       cwd=ROOT, capture_output=True, text=True, check=True).stdout,
        encoding="utf-8")
    old_pdr = old_root / "old-pdr-lib.sh"
    old_pdr.write_text(
        subprocess.run(["git", "show", f"HEAD:{PDR_LIB.relative_to(ROOT)}"],
                       cwd=ROOT, capture_output=True, text=True, check=True).stdout,
        encoding="utf-8")
    old_out = _generate_all(old_root, old_setup, old_pdr)
    assert new_out[0] == old_out[0]  # adr.md untouched
    assert [l for l in new_out[1].splitlines() if not l.startswith("> Auto-generated")] == \
        [l for l in old_out[1].splitlines() if not l.startswith("> Auto-generated")]


def test_regenerate_is_idempotent(adlc_tree):
    """Double generation on the suffixed fixture yields identical output."""
    first = _generate_all(adlc_tree, SETUP_ARCH, PDR_LIB)
    second = _generate_all(adlc_tree, SETUP_ARCH, PDR_LIB)
    assert first == second


def test_adr_move_accepts_full_id_with_prefix(adlc_tree):
    """move_adr accepts full IDs (`ADR-003`) as well as stems (`003-...`).

    Regression: move_adr built `ADR-$adr_id.md` verbatim, so a full-ID caller
    resolved `ADR-ADR-003.md` (missing) and the numeric fallback skipped it
    (`ADR-003` is not bare-numeric) — a silent no-op with exit 0. Callers
    (agents, docs) pass the full ID from index rows; the resolver
    (get_adr_by_id) must agree with the mover on what an ID looks like.
    """
    harness = _extract_adr_harness(adlc_tree)
    r = _run_bash(f'source "{harness}"; move_adr "ADR-003" drafts memory', adlc_tree)
    assert r.returncode == 0, r.stderr
    assert (adlc_tree / "docs/adlc/memory/adr/ADR-003.md").exists(), \
        "move_adr ADR-003 drafts→memory silently no-oped (double-prefix ADR-ADR-003.md)"
    assert not (adlc_tree / ".adlc/drafts/adr/ADR-003.md").exists()
