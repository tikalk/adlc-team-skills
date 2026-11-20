"""Dynamic per-working-directory decision-record store resolution (ADR-514).

Contract under test — ``resolve_memory_root()`` resolves THE store root for
the current working directory via ONE bounded walk-up:

1. nearest ancestor carrying a decision-record family marker wins — a
   ``adr/``, ``pdr/`` or ``chdr/`` subdir (or the family index file
   ``adr.md``/``pdr.md``/``chdr.md``) under ``docs/adlc/memory/`` or legacy
   ``.adlc/memory/``. A bare ``.adlc/`` is NOT a marker; a memory dir holding
   only non-decision content (``evals/``, ``constitution.md``) is NOT a marker.
2. else the nearest workspace root (``.gitmodules`` or
   ``/.adlc/workspace.yml``) — the workspace-centralized default.
3. else the git toplevel (standalone repo); the walk never climbs past it
   unless a workspace root sits above it (submodule child in a workspace).

Reads are side-effect-free and honest-empty. Writes (record promotion)
create a missing store LOUDLY:

    No decision-record store found — initialized <path>; commit it to opt
    <name> into repo-scoped memory.

The same function is copied per skill (scope rule: skills never source each
other's scripts), so the quadrant tests run against every copy — the drift
mitigation ADR-514 names.
"""

import os
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SETUP_ARCH = ROOT / "skills/architect/architect-clarify/scripts/bash/setup-architect.sh"
PDR_LIB = ROOT / "skills/product/product-clarify/scripts/bash/pdr-lib.sh"
CHDR_LIB = ROOT / "skills/change/change-clarify/scripts/bash/chdr-lib.sh"
SETUP_CHANGE_SPECIFY = ROOT / "skills/change/change-specify/scripts/bash/setup-change-specify.sh"
SETUP_CHANGE_CLARIFY = ROOT / "skills/change/change-clarify/scripts/bash/setup-change-clarify.sh"
SETUP_CHANGE_INIT = ROOT / "skills/change/change-init/scripts/bash/setup-change-init.sh"
SETUP_CHANGE_PUBLISH = ROOT / "skills/change/change-publish/scripts/bash/setup-change-publish.sh"

RESOLVE_FUNCS = ("_memory_root_has_marker", "_workspace_root_above", "resolve_memory_root")

LOUD_NOTICE = "No decision-record store found — initialized"


def _run(script: str, cwd: Path, env_extra=None):
    env = {k: v for k, v in os.environ.items()
           if k not in ("REPO_ROOT", "MEMORY_ROOT", "TEAM_AI_DIRECTIVES")}
    env.update(env_extra or {})
    return subprocess.run(["bash", "-c", script], cwd=cwd, capture_output=True,
                          text=True, timeout=60, env=env)


def _extract_func(dest: Path, source: Path, *funcs: str) -> Path:
    """Extract functions into a source-safe harness (same pattern as
    test_ledger_slot_numbering.py). Fails loudly if a function is missing."""
    src = source.read_text(encoding="utf-8").split("\n")
    out = ["#!/usr/bin/env bash"]
    for func in funcs:
        start = next((i for i, l in enumerate(src) if l == f"{func}() {{"), None)
        assert start is not None, f"function {func}() not found in {source}"
        end = next((i for i in range(start + 1, len(src)) if src[i] == "}"), None)
        assert end is not None, f"end of {func}() not found in {source}"
        out.extend(src[start:end + 1])
    harness = dest / "adharness.sh"
    harness.write_text("\n".join(out) + "\n", encoding="utf-8")
    return harness


def _harness(tmp_path: Path, tag: str, source: Path, *funcs: str) -> str:
    """Build a harness for `source`: lib files source directly, setup scripts
    get the functions extracted (they are execution-guarded / noisy)."""
    dest = tmp_path / f"harness-{tag}"
    dest.mkdir(exist_ok=True)
    if source.name.endswith("-lib.sh"):
        return str(source)
    return str(_extract_func(dest, source, *funcs))


# Every copy of the resolution algorithm: the three family libs plus the
# vendored copies in the change sibling setup scripts.
COPIES = [
    ("architect", SETUP_ARCH),
    ("product", PDR_LIB),
    ("change", CHDR_LIB),
    ("change-specify", SETUP_CHANGE_SPECIFY),
    ("change-init", SETUP_CHANGE_INIT),
    ("change-publish", SETUP_CHANGE_PUBLISH),
]
COPY_IDS = [c[0] for c in COPIES]


def _resolve(source: Path, tag: str, tmp_path: Path, cwd: Path):
    harness = _harness(tmp_path, tag, source, *RESOLVE_FUNCS)
    r = _run(f'source "{harness}"; cd "{cwd}"; resolve_memory_root', cwd)
    assert r.returncode == 0, f"{tag}: {r.stderr}"
    return r.stdout.strip()


def _git(repo: Path, *args):
    subprocess.run(["git", *args], cwd=repo, capture_output=True, check=True)


def _git_repo(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    _git(path, "init", "-q")
    return path


# ── fixtures: the four quadrants ─────────────────────────────────────────────

@pytest.fixture()
def repo_mode(tmp_path):
    """Quadrant 1: the CWD repo carries its own store marker."""
    repo = _git_repo(tmp_path / "repo")
    (repo / "docs/adlc/memory/adr").mkdir(parents=True)
    (repo / "sub").mkdir()
    return repo


@pytest.fixture()
def workspace(tmp_path):
    """Workspace root (`.gitmodules` + store marker) with a markerless child
    git repo — the workspace-centralized default shape."""
    ws = _git_repo(tmp_path / "ws")
    (ws / ".gitmodules").write_text("[submodule \"child\"]\n", encoding="utf-8")
    (ws / ".adlc").mkdir()
    (ws / "docs/adlc/memory/adr").mkdir(parents=True)
    child = _git_repo(ws / "child")
    (child / "src").mkdir()
    return ws


@pytest.fixture()
def bare_workspace(tmp_path):
    """Workspace root with `.gitmodules` but no store marker anywhere."""
    ws = _git_repo(tmp_path / "ws")
    (ws / ".gitmodules").write_text("[submodule \"child\"]\n", encoding="utf-8")
    child = _git_repo(ws / "child")
    (child / "src").mkdir()
    return ws


@pytest.fixture()
def standalone(tmp_path):
    """Quadrant 4: standalone git repo, no marker, no workspace above."""
    repo = _git_repo(tmp_path / "alone")
    (repo / "pkg").mkdir()
    return repo


# ── (b) the walk-up chain, all three steps, per copy ─────────────────────────

@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_step1_nearest_marker_wins(tmp_path, repo_mode, tag, source):
    assert _resolve(source, tag, tmp_path, repo_mode / "sub") == str(repo_mode)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_step1_marker_below_workspace_root_wins(tmp_path, workspace, tag, source):
    """A repo-mode marker beats the workspace root above it (quadrant 1)."""
    child = workspace / "child"
    (child / "docs/adlc/memory/chdr").mkdir(parents=True)
    assert _resolve(source, tag, tmp_path, child / "src") == str(child)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_step2_markerless_child_in_workspace_uses_workspace_root(
        tmp_path, workspace, tag, source):
    """Zero-regression: markerless repo in a workspace → workspace store."""
    assert _resolve(source, tag, tmp_path, workspace / "child" / "src") == str(workspace)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_step2_workspace_root_without_marker(tmp_path, bare_workspace, tag, source):
    assert _resolve(source, tag, tmp_path, bare_workspace / "child" / "src") \
        == str(bare_workspace)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_step2_workspace_yml_marks_workspace_root(tmp_path, tag, source):
    """`.adlc/workspace.yml` is a workspace-root marker even without .gitmodules."""
    ws = tmp_path / "ws"
    (ws / ".adlc").mkdir(parents=True)
    (ws / ".adlc/workspace.yml").write_text("name: ws\n", encoding="utf-8")
    child = _git_repo(ws / "child")
    assert _resolve(source, tag, tmp_path, child) == str(ws)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_step3_standalone_git_toplevel(tmp_path, standalone, tag, source):
    assert _resolve(source, tag, tmp_path, standalone / "pkg") == str(standalone)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_walk_is_bounded_at_a_standalone_toplevel(tmp_path, tag, source):
    """A marker ABOVE the git toplevel (and no workspace root) is not adopted:
    the walk never climbs past the toplevel of a standalone repo."""
    outer = tmp_path / "outer"
    (outer / "docs/adlc/memory/adr").mkdir(parents=True)
    repo = _git_repo(outer / "inner")
    (repo / "sub").mkdir()
    assert _resolve(source, tag, tmp_path, repo / "sub") == str(repo)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_no_git_anywhere_falls_back_to_pwd(tmp_path, tag, source):
    plain = tmp_path / "plain"
    (plain / "sub").mkdir(parents=True)
    assert _resolve(source, tag, tmp_path, plain / "sub") == str(plain / "sub")


# ── (a) marker detection, including the negative cases ───────────────────────

@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_legacy_memory_family_dir_is_a_marker(tmp_path, tag, source):
    root = tmp_path / "r"
    (root / ".adlc/memory/pdr").mkdir(parents=True)
    (root / "sub").mkdir()
    assert _resolve(source, tag, tmp_path, root / "sub") == str(root)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_family_index_file_is_a_marker(tmp_path, tag, source):
    root = tmp_path / "r"
    (root / "docs/adlc/memory").mkdir(parents=True)
    (root / "docs/adlc/memory/chdr.md").write_text("# ChDR Index\n", encoding="utf-8")
    (root / "sub").mkdir()
    assert _resolve(source, tag, tmp_path, root / "sub") == str(root)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_bare_adlc_dir_is_not_a_marker(tmp_path, bare_workspace, tag, source):
    """adlc-argo-wf shape: `.adlc/` carries init-options/workflows, no memory."""
    child = bare_workspace / "child"
    (child / ".adlc").mkdir()
    (child / ".adlc/init-options.json").write_text("{}\n", encoding="utf-8")
    assert _resolve(source, tag, tmp_path, child / "src") == str(bare_workspace)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_evals_only_memory_dir_is_not_a_marker(tmp_path, bare_workspace, tag, source):
    """adlc-cli shape: `.adlc/memory/evals/` is non-decision content."""
    child = bare_workspace / "child"
    (child / ".adlc/memory/evals").mkdir(parents=True)
    assert _resolve(source, tag, tmp_path, child / "src") == str(bare_workspace)


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_constitution_only_memory_dir_is_not_a_marker(tmp_path, bare_workspace, tag, source):
    child = bare_workspace / "child"
    mem = child / "docs/adlc/memory"
    mem.mkdir(parents=True)
    (mem / "constitution.md").write_text("# Constitution\n", encoding="utf-8")
    assert _resolve(source, tag, tmp_path, child / "src") == str(bare_workspace)


# ── byte-identity: the copies must not drift (ADR-514 mitigation) ────────────

def _func_body(text: str, name: str) -> str:
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if l == f"{name}() {{"), None)
    assert start is not None, f"function {name}() not found"
    end = next((i for i in range(start + 1, len(lines)) if lines[i] == "}"), None)
    assert end is not None, f"end of {name}() not found"
    return "\n".join(lines[start:end + 1])


def test_resolve_memory_root_copies_are_byte_identical():
    for fn in RESOLVE_FUNCS:
        variants = {}
        for tag, path in COPIES:
            variants.setdefault(_func_body(path.read_text(encoding="utf-8"), fn), []).append(tag)
        assert len(variants) == 1, (
            f"{fn} drifted across copies: "
            + "; ".join(f"{'/'.join(tags)} has its own body" for tags in variants.values()))


def test_ensure_memory_store_copies_are_byte_identical():
    """The loud-create helper must not drift where it is vendored."""
    carriers = [SETUP_ARCH, PDR_LIB, CHDR_LIB, SETUP_CHANGE_PUBLISH]
    variants = {}
    for path in carriers:
        body = _func_body(path.read_text(encoding="utf-8"), "ensure_memory_store")
        variants.setdefault(body, []).append(path.name)
    assert len(variants) == 1, (
        "ensure_memory_store drifted: "
        + "; ".join(f"{'/'.join(names)}" for names in variants.values()))


# ── (e) loud first-write creation ────────────────────────────────────────────

@pytest.mark.parametrize("family", ["adr", "pdr", "chdr"])
def test_ensure_memory_store_creates_loudly(tmp_path, family):
    root = tmp_path / "repo"
    root.mkdir()
    r = _run(f'source "{CHDR_LIB}"; ensure_memory_store "{root}" "{family}"', root)
    assert r.returncode == 0, r.stderr
    store = root / "docs/adlc/memory" / family
    assert store.is_dir(), "the family store dir must be created"
    assert LOUD_NOTICE in r.stderr, f"the creation notice must be loud: {r.stderr!r}"
    assert f"commit it to opt {root.name} into repo-scoped memory." in r.stderr
    assert str(store) in r.stderr


def test_ensure_memory_store_is_silent_when_the_store_exists(tmp_path):
    root = tmp_path / "repo"
    (root / "docs/adlc/memory/chdr").mkdir(parents=True)
    r = _run(f'source "{CHDR_LIB}"; ensure_memory_store "{root}" chdr', root)
    assert r.returncode == 0, r.stderr
    assert LOUD_NOTICE not in r.stderr


def test_move_adr_into_a_missing_store_creates_it_loudly(tmp_path):
    """architect promotion: move_adr drafts → memory on a store-less root."""
    (tmp_path / ".adlc/drafts/adr").mkdir(parents=True)
    (tmp_path / ".adlc/drafts/adr/ADR-003.md").write_text(
        "---\nstatus: accepted\ndate: 2026-11-13\n---\n\n# Three\n", encoding="utf-8")
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title", "generate_adr_index",
                            "move_adr", *RESOLVE_FUNCS, "ensure_memory_store")
    r = _run(f'source "{harness}"; move_adr 3 drafts memory', tmp_path,
             env_extra={"REPO_ROOT": str(tmp_path), "MEMORY_ROOT": str(tmp_path)})
    assert r.returncode == 0, r.stderr
    assert (tmp_path / "docs/adlc/memory/adr/ADR-003.md").exists()
    assert LOUD_NOTICE in r.stderr


def test_move_pdr_into_a_missing_store_creates_it_loudly(tmp_path):
    """product promotion: move_pdr drafts → memory on a store-less root."""
    (tmp_path / ".adlc/drafts/pdr").mkdir(parents=True)
    (tmp_path / ".adlc/drafts/pdr/PDR-003.md").write_text(
        "---\nstatus: accepted\ndate: 2026-11-13\n---\n\n# Three\n", encoding="utf-8")
    r = _run(f'source "{PDR_LIB}"; move_pdr 3 drafts memory', tmp_path,
             env_extra={"REPO_ROOT": str(tmp_path), "MEMORY_ROOT": str(tmp_path)})
    assert r.returncode == 0, r.stderr
    assert (tmp_path / "docs/adlc/memory/pdr/PDR-003.md").exists()
    assert LOUD_NOTICE in r.stderr


def test_change_publish_setup_creates_a_missing_store_loudly(tmp_path):
    """change promotion path: setup-change-publish.sh seeds the store with a
    loud notice when the resolved root has none (standalone repo)."""
    repo = _git_repo(tmp_path / "repo")
    r = _run(f'bash "{SETUP_CHANGE_PUBLISH}"', repo)
    assert r.returncode == 0, r.stderr
    assert (repo / "docs/adlc/memory/chdr").is_dir()
    assert LOUD_NOTICE in r.stderr


def test_setup_scripts_never_leak_the_notice_into_json_stdout(tmp_path):
    """The loud notice goes to stderr; stdout stays parseable JSON."""
    import json
    repo = _git_repo(tmp_path / "repo")
    r = _run(f'bash "{SETUP_CHANGE_PUBLISH}"', repo)
    assert r.returncode == 0, r.stderr
    data = json.loads(r.stdout)
    assert data["MEMORY_DIR"] == str(repo / "docs/adlc/memory/chdr")


# ── (f) reads never create ────────────────────────────────────────────────────

def _snapshot(root: Path):
    return sorted(str(p.relative_to(root)) for p in root.rglob("*"))


@pytest.mark.parametrize("tag,source", COPIES, ids=COPY_IDS)
def test_resolve_memory_root_creates_nothing(tmp_path, standalone, tag, source):
    before = _snapshot(standalone)
    _resolve(source, tag, tmp_path, standalone / "pkg")
    assert _snapshot(standalone) == before


def test_memory_scope_reads_create_nothing(tmp_path):
    """list/count/index reads on a missing store: honest empty, no mkdir."""
    harness = _extract_func(tmp_path, SETUP_ARCH,
                            "parse_fm_field", "parse_fm_title", "generate_adr_index",
                            "get_adr_count", "list_adrs")
    before = _snapshot(tmp_path)
    r = _run(f'source "{harness}"; get_adr_count memory; list_adrs memory; '
             f'generate_adr_index memory', tmp_path,
             env_extra={"REPO_ROOT": str(tmp_path), "MEMORY_ROOT": str(tmp_path)})
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip().split("\n")[0] == "0"
    assert _snapshot(tmp_path) == before, "reads must not seed directories"


def test_pdr_memory_scope_reads_create_nothing(tmp_path):
    before = _snapshot(tmp_path)
    r = _run(f'source "{PDR_LIB}"; generate_pdr_index memory', tmp_path,
             env_extra={"REPO_ROOT": str(tmp_path), "MEMORY_ROOT": str(tmp_path)})
    assert r.returncode == 0, r.stderr
    assert _snapshot(tmp_path) == before


# ── change-family end-to-end resolution through the setup scripts ────────────

def test_change_publish_memory_dir_follows_the_workspace_root(tmp_path, workspace):
    """Zero-regression, byte-identical: markerless child → workspace store."""
    r = _run(f'bash "{SETUP_CHANGE_PUBLISH}"', workspace / "child")
    assert r.returncode == 0, r.stderr
    import json
    data = json.loads(r.stdout)
    assert data["MEMORY_DIR"] == str(workspace / "docs/adlc/memory/chdr")
    assert data["REPO_ROOT"] == str(workspace)


def test_change_clarify_memory_dir_follows_the_resolved_root(tmp_path, workspace):
    r = _run(f'bash "{SETUP_CHANGE_CLARIFY}"', workspace / "child")
    assert r.returncode == 0, r.stderr
    import json
    data = json.loads(r.stdout)
    assert data["MEMORY_DIR"] == str(workspace / "docs/adlc/memory/chdr")


def test_change_publish_memory_dir_follows_a_repo_mode_marker(tmp_path, workspace):
    """Repo-mode child: the marker flips the store to the child repo."""
    child = workspace / "child"
    (child / "docs/adlc/memory/chdr").mkdir(parents=True)
    r = _run(f'bash "{SETUP_CHANGE_PUBLISH}"', child)
    assert r.returncode == 0, r.stderr
    import json
    data = json.loads(r.stdout)
    assert data["MEMORY_DIR"] == str(child / "docs/adlc/memory/chdr")
