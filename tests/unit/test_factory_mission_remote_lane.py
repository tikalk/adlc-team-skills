"""Contract tests for factory-mission remote lane (remote:coder).

Verifies lanes.md documents the remote lane and that env setup is delegated
to the adlc-cli provider transport (ADR-007 / PDR-010), not skill-side scripts.
"""
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
LANES = ROOT / "skills/factory/factory-mission/references/lanes.md"
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts/bash"
ENV_SYNC = SCRIPTS / "remote-coder-env-sync.sh"
TEARDOWN = SCRIPTS / "remote-coder-teardown.sh"


def test_lanes_documents_remote_lane():
    text = LANES.read_text()
    assert "`remote:<provider>`" in text
    assert "--provider" in text
    assert "known: `coder`" in text
    assert not re.search(r"\bargo\b", text, re.IGNORECASE)


def test_lanes_no_agent_fallback():
    text = LANES.read_text()
    assert "NEVER degrades to `agent`" in text
    assert "halt" in text.lower()


def test_lanes_degradation_ladder():
    text = LANES.read_text()
    assert "remote:<provider>" in text and "HALT" in text


def test_env_sync_script_removed():
    assert not ENV_SYNC.exists(), (
        "remote-coder-env-sync.sh must be deleted: env setup is owned by "
        "adlc-cli --provider coder (ADR-007)"
    )


def test_teardown_script_syntax_clean_and_executable():
    assert TEARDOWN.exists(), f"missing {TEARDOWN.name}"
    r = subprocess.run(["bash", "-n", str(TEARDOWN)], capture_output=True, text=True)
    assert r.returncode == 0, f"{TEARDOWN.name} syntax: {r.stderr}"
    mode = oct(TEARDOWN.stat().st_mode & 0o777)
    assert mode == "0o755", f"{TEARDOWN.name} mode {mode}, want 0o755"


def test_lanes_delegates_setup_to_adlc_cli():
    text = LANES.read_text()
    assert "adlc-cli workspace setup" in text
    assert "--provider coder" in text
    assert "`.adlc/workspace.yml`" in text
    assert ".adlc/workspaces/" in text


def test_lanes_has_no_skill_side_env_sync():
    text = LANES.read_text()
    assert "Sync env over `coder ssh`" not in text
    assert "adlc-cli skills add" not in text
    assert "coder scp" not in text
    assert "NEVER carries its own env bootstrap" in text


def test_lanes_transport_failure_halts_without_fallback():
    text = LANES.read_text()
    assert "not implemented: live coder transport" in text
    assert "do not fall back to a script" in text.lower()


def test_lanes_secret_contract():
    text = LANES.read_text()
    assert "${VAR}" in text
    assert "fail-fast" in text
    assert "scrubs it" in text and "every output path" in text
    assert "vars channel" in text
    assert "location-free" in text


def test_lanes_per_mission_workspace_name():
    text = LANES.read_text()
    assert "name: ${WORKSPACE_NAME}" in text
    assert "WORKSPACE_NAME=<repo>-mission-<issue>" in text
    assert "never invents a fallback name" in text
    assert "name_var" in text


def _fake_coder(tmp_path, behavior="missing"):
    """A fake `coder` CLI.

    behaviors:
      missing  — the workspace list is empty (nothing to delete)
      exists   — the workspace is in the list (the teardown gate asks first)
      broken   — the list call itself fails (API error / expired token)
    """
    bindir = tmp_path / "fakebin"
    bindir.mkdir(exist_ok=True)
    fake = bindir / "coder"
    if behavior == "missing":
        body = (
            "#!/usr/bin/env bash\n"
            'if [ "$1" = "list" ]; then echo \'[{"name":"other-ws"}]\'; exit 0; fi\n'
            "echo 'fake coder: workspace exists'\nexit 0\n"
        )
    elif behavior == "broken":
        body = (
            "#!/usr/bin/env bash\n"
            "echo 'fake coder: unauthorized' >&2\nexit 1\n"
        )
    elif behavior == "garbage":
        body = (
            "#!/usr/bin/env bash\n"
            "echo '<html>502 Bad Gateway</html>'\nexit 0\n"
        )
    else:
        body = (
            "#!/usr/bin/env bash\n"
            'if [ "$1" = "list" ]; then echo \'[{"name":"coder-mission-1"}]\'; exit 0; fi\n'
            "echo 'fake coder: workspace exists'\nexit 0\n"
        )
    fake.write_text(body)
    fake.chmod(0o755)
    return bindir


def _env_without_coder(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(tmp_path) + os.pathsep + "/usr/bin" + os.pathsep + "/bin"
    return env


def test_teardown_requires_coder_cli(tmp_path):
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1"],
                       capture_output=True, text=True,
                       env=_env_without_coder(tmp_path))
    assert r.returncode == 127


def test_teardown_refuses_non_lane_name(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path)) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "some-random-ws", "--yes"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 3
    assert "REFUSE" in r.stdout + r.stderr


def test_teardown_missing_workspace_noop(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "missing")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-99999"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 0
    assert "nothing to delete" in r.stdout + r.stderr


def test_teardown_finds_workspace_via_show(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "exists")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 6, "the gate waits for the confirmation — it is not a done state"
    assert "Teardown gate" in r.stdout + r.stderr
    assert "left running" in r.stdout + r.stderr


def test_teardown_lookup_failure_is_not_reported_as_nothing_to_delete(tmp_path):
    """A failed lookup (expired token, outage) must not read as 'deleted'."""
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "broken")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1", "--yes"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 4, "a failed lookup must exit non-zero"
    out = r.stdout + r.stderr
    assert "NOT deleted" in out
    assert "nothing to delete" not in out


def test_teardown_accepts_a_long_dashed_repo_name(tmp_path):
    """The lane's own naming shape must pass the teardown gate."""
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "exists")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "engineering-internal-app-coder-mission-42", "--yes"],
                       capture_output=True, text=True, env=env)
    assert "REFUSE" not in (r.stdout + r.stderr), "a lane-shaped name must not be refused"


def test_zero_secret_literals():
    text = TEARDOWN.read_text()
    assert not re.search(r"glpat-|ghp_|xoxb-|sk-|CODER_TOKEN=.|GITLAB_TOKEN=.", text)


def test_lanes_developer_owned_tab():
    text = LANES.read_text()
    assert "NEVER opens tabs" in text
    assert "developer owns their tab" in text or "OWN tab" in text


def test_lanes_dispatch_matrix():
    text = LANES.read_text()
    assert "interactive" in text and "remote:coder" in text
    assert "HALT execution" in text, "the no-provider path must keep the halt-and-refuse rule"


def test_lanes_attach_order():
    text = LANES.read_text()
    ssh_pos = text.find("coder ssh <workspace>")
    herdr_pos = text.find("herdr --remote")
    assert ssh_pos != -1 and herdr_pos != -1 and ssh_pos < herdr_pos
    assert "opencode" in text


def test_skill_issue_plus_provider():
    skill = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    assert "--provider coder" in skill
    assert "never opens tabs" in skill


def _adlc_cli_cmd():
    """Resolve the adlc-cli executable: $ADLC_CLI (may include args) or PATH."""
    raw = os.environ.get("ADLC_CLI", "").strip()
    if raw:
        return raw.split()
    found = shutil.which("adlc-cli")
    return [found] if found else None


def test_lane_setup_command_executes_via_adlc_cli(tmp_path):
    """The lane's documented setup command runs the real adlc-cli transport.

    Proves the delegation end to end: the repo's workspace file declares
    `name: ${WORKSPACE_NAME}`, the CLI expands it, and the handle lands in
    .adlc/workspaces/<name>.json — with no env-sync script involved.
    """
    cmd = _adlc_cli_cmd()
    if not cmd:
        pytest.skip("adlc-cli not on PATH (set ADLC_CLI to the binary to run this test)")
    ws = tmp_path / "workspace.yml"
    ws.write_text("schema_version: 1\nname: ${WORKSPACE_NAME}\nworkspace:\n  dirs: []\n")
    env = dict(os.environ)
    env["WORKSPACE_NAME"] = "lane-mission-test"
    # The transport is pinned to the mock: this test is about the COMMAND
    # (the documented lane invocation), not about provisioning a real
    # workspace. Without this the test would reach the live coder CLI.
    env["ADLC_CODER_MOCK"] = "1"
    r = subprocess.run(
        cmd + ["workspace", "setup", str(ws), "--provider", "coder"],
        capture_output=True, text=True, env=env, cwd=tmp_path,
    )
    out = r.stdout + r.stderr
    if "provider path: coder workspace" not in out:
        # The binary does not speak the provider surface at all (an adlc-cli
        # older than the transport) — an environment mismatch, so skip. A
        # binary that DOES speak the surface must make the command work: the
        # marker is printed before anything can fail, so a broken command
        # still reaches the assertion below and fails the test.
        pytest.skip(f"adlc-cli at {' '.join(cmd)} has no --provider coder surface "
                    f"(older CLI?): {out.strip()[:200]}")
    assert r.returncode == 0, (
        f"the documented command failed on a provider-capable CLI: {out.strip()[:300]}"
    )
    handle = tmp_path / ".adlc" / "workspaces" / "lane-mission-test.json"
    assert handle.exists(), f"expected the handle at {handle}"
    assert not ENV_SYNC.exists(), "the lane must not need an env-sync script"


def test_lanes_names_the_teardown_script():
    """The kept teardown script must be named in the contract, or it is dead code."""
    text = LANES.read_text()
    assert "remote-coder-teardown.sh" in text, "the contract must name the teardown script"
    assert "scripts/bash/remote-coder-teardown.sh" in text
    assert ".agents/skills/factory-mission/scripts/bash/remote-coder-teardown.sh" in text


def test_lanes_keeps_the_halt_and_refuse_rule():
    """The no-provider path must keep the halt-and-refuse rule (tracker-integration.md)."""
    text = LANES.read_text()
    assert "HALT execution" in text
    skill = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    assert "HALT execution" in skill, "the skill must not weaken the human-required gate"


def test_lanes_degradation_rule_excludes_remote_lanes():
    """'losing a lane is never a reason to stop' must not license a remote downgrade."""
    text = re.sub(r"\s+", " ", LANES.read_text())
    assert "losing a lane is never a reason to stop" not in text, (
        "the unqualified 'losing a lane is never a reason to stop' licenses a remote downgrade"
    )
    assert "losing a `cli:` lane is never a reason to stop" in text
    assert "A `remote:` lane is exempt from this rule" in text


def test_lanes_documents_the_brief_never_crosses_the_transport():
    """The remote session compiles its own brief — no transfer channel is needed."""
    text = LANES.read_text()
    assert "The brief never crosses the transport" in text
    assert "compiles" in text and "brief from the issue URL" in text


def test_lanes_hands_the_session_to_the_developer():
    """The lane owns the workspace; the developer owns the session."""
    text = LANES.read_text()
    assert "Hand the session to the developer" in text
    assert "coder ssh <workspace>" in text
    assert "/factory-mission --url <issue-url>" in text
    # the developer's command drops --provider: the workspace is ready
    assert "without `--provider" in text


def test_lanes_runs_the_session_in_the_project_root():
    """The hook + skills are bound at the project root, not inside the clone."""
    text = LANES.read_text()
    assert "cd <project root>" in text
    assert "project root" in text
    assert "dispatcher.mjs" in text


def test_lanes_uses_the_interactive_tui_not_a_prompt_flag():
    """The workspace image ships opencode 1.x: `--prompt` is a 2.x flag."""
    text = LANES.read_text()
    assert "opencode --prompt" not in text, (
        "opencode --prompt starts the TUI on opencode 1.x — it never returns"
    )
    assert "opencode run" in text


def test_lanes_uses_the_real_cli_version_command():
    """`adlc-cli --version` does not exist — the contract must use `adlc-cli version`."""
    text = LANES.read_text()
    assert "adlc-cli --version" not in text, "the CLI has no --version flag"
    assert "adlc-cli version" in text


def test_lanes_remote_execution_targets_the_mission_workspace():
    """A remote step must target the workspace the lane provisioned."""
    text = LANES.read_text()
    assert "--workspace <repo>-mission-<issue>" in text


def test_teardown_unparseable_payload_is_a_failed_lookup(tmp_path):
    """A garbage payload is not an empty list — it is a failed lookup."""
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "garbage")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1", "--yes"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 4, "an unparseable payload must exit non-zero"
    assert "NOT deleted" in r.stdout + r.stderr


def test_teardown_lists_all_workspaces_not_only_owned(tmp_path):
    """`coder list` defaults to owner:me — the teardown must pass --all."""
    bindir = tmp_path / "fakebin"
    bindir.mkdir(exist_ok=True)
    fake = bindir / "coder"
    fake.write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "list" ]; then\n'
        '  case " $* " in\n'
        '    *" --all "*) echo \'[{"name":"coder-mission-1"}]\' ;;\n'
        "    *) echo '[]' ;;\n"
        "  esac\n"
        "  exit 0\n"
        "fi\n"
        "echo 'fake coder: deleted'\nexit 0\n"
    )
    fake.chmod(0o755)
    env = dict(os.environ)
    env["PATH"] = str(bindir) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1", "--yes"],
                       capture_output=True, text=True, env=env)
    out = r.stdout + r.stderr
    assert "not found" not in out, f"the teardown must list all workspaces: {out}"
    assert "deleted" in out


def test_teardown_yes_deletes_without_a_prompt(tmp_path):
    """--yes is the explicit confirmation — it must not block on stdin."""
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "exists")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1", "--yes"],
                       capture_output=True, text=True, env=env, input="")
    assert r.returncode == 0, r.stdout + r.stderr
    assert "deleted" in r.stdout + r.stderr


def test_teardown_without_confirmation_never_reads_as_done(tmp_path):
    """Only "deleted" exits 0 — an orchestrator must not read the gate as done."""
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "exists")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1"],
                       capture_output=True, text=True, env=env, input="n\n")
    assert r.returncode == 6, "the gate waits for the confirmation"
    assert "deleted" not in r.stdout + r.stderr


# --- contract pinning (second review: the ladder/matrix/owner were unpinned) ---

def test_lanes_pins_the_degradation_ladder():
    """The ladder itself must say a remote lane halts — not only the prose."""
    text = LANES.read_text()
    ladder = re.search(r"```\n(cli:<runtime>.*?remote:<provider>.*?)\n```", text, re.S)
    assert ladder, "the degradation ladder block must exist"
    block = ladder.group(1)
    assert "remote:<provider>" in block
    remote_line = [l for l in block.splitlines() if "remote:<provider>" in l][0]
    target = remote_line.split("\u2192", 1)[-1].strip().lower()
    assert target.startswith("halt"), (
        f"the ladder must route a remote lane to HALT, not to another lane: {remote_line!r}"
    )


def test_lanes_pins_the_dispatch_matrix():
    """The matrix row for the remote lane must name the remote lane."""
    text = LANES.read_text()
    row = re.search(r"\|[^\n]*`--provider coder`[^\n]*\|", text)
    assert row, "the dispatch matrix must have a --provider coder row"
    assert "remote:coder" in row.group(0), f"the row must name the remote lane: {row.group(0)!r}"


def test_lanes_pins_one_owner_per_step():
    """The developer/executor split must be stated, not implied."""
    text = LANES.read_text()
    assert "One owner per step" in text
    assert "the DEVELOPER drives" in text
    assert "never spawns the **agent** CLI" in text


def test_lanes_pins_the_teardown_invocation():
    """The teardown invocation must name the script AND its confirmation flag."""
    text = LANES.read_text()
    assert re.search(r"remote-coder-teardown\.sh\s+<workspace>\s+--yes", text), (
        "the contract must show the teardown invocation with --yes"
    )


def test_lanes_pins_the_remote_placeholders():
    """The remote placeholder table must define {workspace} and {workspace_file}."""
    text = LANES.read_text()
    assert "| `{workspace}` |" in text
    assert "| `{workspace_file}` |" in text


def test_lanes_pins_the_provider_surface_check():
    """The provider check must look for the transport's marker, not a fake probe."""
    text = LANES.read_text()
    assert "provider path: coder workspace" in text
    assert "workspace setup --help" not in text, (
        "that command is not a help request — it runs the setup"
    )


def test_lanes_pins_the_brief_owner():
    """The brief has no transfer owner: the remote session compiles its own."""
    text = LANES.read_text()
    assert "developer" in text
    assert "no brief file to place on" in text


def test_eval_criterion_is_consistent_across_the_goldset_files():
    """One criterion, one name — the three goldset files must agree."""
    import json
    evals = ROOT / "evals/promptfoo"
    goldset = json.loads((evals / "goldset.json").read_text())
    factory = json.loads((evals / "goldset-factory.json").read_text())
    ids_g = {c["id"] for c in goldset["cases"]}
    ids_f = {c["id"] for c in factory["cases"]}
    assert {"EVAL-014-CASE-1", "EVAL-014-CASE-2", "EVAL-014-CASE-3"} <= ids_g
    assert {"EVAL-FACTORY-018-CASE-1", "EVAL-FACTORY-018-CASE-2", "EVAL-FACTORY-018-CASE-3"} <= ids_f
    md = (evals / "goldset.md").read_text()
    assert "## Criterion EVAL-014:" in md
    grader = (evals / "graders" / "check_factory_mission_provider_transport.py").read_text()
    assert "EVAL-014" in grader


def test_teardown_stderr_noise_is_not_a_lookup_failure(tmp_path):
    """A warning on stderr must not turn a good JSON payload into a failure."""
    bindir = tmp_path / "fakebin"
    bindir.mkdir(exist_ok=True)
    fake = bindir / "coder"
    fake.write_text(
        "#!/usr/bin/env bash\n"
        'if [ "$1" = "list" ]; then\n'
        "  echo 'warning: using the default org' >&2\n"
        "  echo '[{\"name\":\"coder-mission-1\"}]'\n"
        "  exit 0\n"
        "fi\n"
        "echo 'fake coder: deleted'\nexit 0\n"
    )
    fake.chmod(0o755)
    env = dict(os.environ)
    env["PATH"] = str(bindir) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1", "--yes"],
                       capture_output=True, text=True, env=env)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out
    assert "NOT deleted" not in out, f"stderr noise must not read as a failed lookup: {out}"
    assert "deleted" in out


# --- the dispatch dimension alone picks the lane (validated design rule) ---

def test_lanes_pins_the_dispatch_dimension_as_the_lane_discriminator():
    """`interactive` is the dispatch label the remote lane requires."""
    text = LANES.read_text()
    matrix = re.search(r"\| Dispatch label \| Provider flag \| Lane \|.*?\n\n", text, re.S)
    assert matrix, "the dispatch matrix must have a dispatch-label column"
    rows = matrix.group(0)
    interactive_row = [l for l in rows.splitlines() if "`interactive`" in l]
    assert interactive_row, "the matrix must have an interactive row"
    assert "--provider coder" in interactive_row[0]
    assert "remote:coder" in interactive_row[0]
    # autonomous/supervised refuse the provider
    other = [l for l in rows.splitlines() if "`autonomous`" in l]
    assert other and "refused" in other[0]
    # the gating dimension is orthogonal: it must not appear as a lane trigger
    assert "or gating human-required" not in rows


def test_skill_pins_the_dispatch_rule():
    """SKILL.md must not offer a gating label as a lane trigger."""
    skill = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    assert "The DISPATCH dimension picks the lane" in skill
    assert "dispatch is `interactive` or gating is `human-required`" not in skill
    assert "Gating `human-required` does not" in skill


def test_lanes_teardown_is_triggered_by_the_developer_saying_done():
    """'done' must run the teardown — the developer types no path."""
    text = LANES.read_text()
    assert "the developer says \"done\", the lane tears down" in text
    assert "mission done" in text
    assert "resolved by the skill" in text
    assert "the skill's own directory" in text
    assert ".adlc/workspaces/<name>.json" in text


def test_skill_acts_on_done_without_asking_for_a_path():
    """The skill must tear down on request, resolving its own script path."""
    skill = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    assert "Teardown on request" in skill
    assert "do NOT ask the developer for a path" in skill
    assert "remote-coder-teardown.sh" in skill


def test_lanes_delivers_the_workspace_environment_to_the_remote():
    """The vars the profile references must reach the remote session."""
    text = re.sub(r"\s+", " ", LANES.read_text())
    assert ".adlc/secrets.env" in text
    assert "the profile is where a workspace declares what it needs" in text


def test_lanes_pins_the_model_when_the_profile_delivers_a_token():
    """A GITLAB_TOKEN in the session env hijacks opencode's model provider."""
    text = re.sub(r"\s+", " ", LANES.read_text())
    assert "opencode -m <model>" in text
    assert "Pin the model when the profile delivers a token" in text
    assert "401" in text


def test_teardown_removes_the_stale_handle(tmp_path):
    """A handle that outlives its workspace makes the next lane run reuse a
    machine that no longer exists."""
    text = TEARDOWN.read_text()
    assert 'HANDLE=".adlc/workspaces/${WORKSPACE}.json"' in text
    assert 'rm -f "$HANDLE"' in text


def test_lanes_states_that_the_variables_come_from_the_developer_environment():
    """The lane supplies the profile's vars from the developer's env — and
    names the missing one instead of inventing a value."""
    text = re.sub(r"\s+", " ", LANES.read_text())
    assert "from the developer's environment" in text
    assert "Missing required workspace variable" in text
    assert "never invents a value" in text
