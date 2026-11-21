"""The factory-review `validation` label is set through a deterministic
command that confirms by re-reading (adlc-team-skills#185).

Live evidence: in an interactive session on 2026-11-21 the verdict for
adlc-workspace MR !155 posted correctly (discussion note 89511, marker
head-bound) but §2 step 6's `validation` label never ran — the agent reported
"verdict posted, verified" while the MR labels were still empty. Step 5's
verdict has post-verdict.sh's post-then-confirm loop; the label had no
confirm, so a skipped or silently-dropped set looked exactly like a finished
review. These tests pin:

- the skill text: step 6 names the confirm command (bash + PowerShell twin),
  its idempotence, its fail-closed exits, and the honesty rule for a failure;
- the script (bash, and its PowerShell twin where pwsh exists): it sets the
  label, confirms by re-read, is idempotent, fails closed (exit 1) on a
  silent loss, refuses (exit 2) on a tracker error or bad usage, and
  --check-only answers without writing.
"""
import json
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review/SKILL.md"
SCRIPT = ROOT / "skills/factory/factory-review/scripts/bash/confirm-validation-label.sh"
PS_SCRIPT = ROOT / "skills/factory/factory-review/scripts/powershell/confirm-validation-label.ps1"

MR = "tikalk/engineering/octopus-next!1298"
PR = "tikalk/adlc-team-skills#166"


# A fake `glab api` / `gh api`. State in $FAKE_TRACKER_DIR: pr.json (the
# PR/MR with its labels), calls.log. Knobs: FAKE_DROP=1 accept label writes
# but never store them (the silent-loss case); FAKE_REFUSE=1 refuse writes;
# FAKE_READ_FAIL=1 fail every GET.
FAKE = r'''#!/usr/bin/env bash
set -u
d="${FAKE_TRACKER_DIR:?}"
[ "${1:-}" = api ] || { echo "fake: only 'api' is supported" >&2; exit 64; }
shift
method=GET path="" input=""
while [ $# -gt 0 ]; do
  case "$1" in
    --hostname) shift 2 ;;
    -X) method="$2"; shift 2 ;;
    -H) shift 2 ;;
    --input) input="$2"; shift 2 ;;
    *) path="$1"; shift ;;
  esac
done
echo "$method $path" >> "$d/calls.log"
[ -f "$d/pr.json" ] || echo '{"labels":[]}' > "$d/pr.json"
if [ "$method" = GET ]; then
  [ "${FAKE_READ_FAIL:-0}" = 1 ] && { echo "fake: 500 Internal Server Error (HTTP 500)" >&2; exit 1; }
  cat "$d/pr.json"
  exit 0
fi
[ "${FAKE_REFUSE:-0}" = 1 ] && { printf 'fake: 403 Forbidden (HTTP 403)\ntry again later\n\n' >&2; exit 1; }
if [ "$input" = - ]; then body="$(cat)"; else body="$(cat "$input")"; fi
[ "${FAKE_DROP:-0}" = 1 ] && { echo '{}'; exit 0; }
node -e '
  const fs = require("fs");
  const [f, raw, provider] = process.argv.slice(1);
  const parsed = JSON.parse(raw);
  const add = parsed.labels || (parsed.add_labels !== undefined ? [parsed.add_labels] : []);
  const pr = JSON.parse(fs.readFileSync(f, "utf8"));
  const names = new Set((pr.labels || []).map(l => typeof l === "string" ? l : l.name));
  for (const n of add) names.add(n);
  pr.labels = [...names].map(n => (provider === "gitlab" ? n : {name: n}));
  fs.writeFileSync(f, JSON.stringify(pr)); console.log("{}");' "$d/pr.json" "$body" "$FAKE_PROVIDER"
'''

needs_tools = pytest.mark.skipif(shutil.which("bash") is None or shutil.which("node") is None,
                                 reason="needs bash and node")
INTERPRETERS = [
    pytest.param("bash", marks=[pytest.mark.requires_bash, needs_tools]),
    pytest.param("pwsh", marks=pytest.mark.skipif(shutil.which("pwsh") is None or shutil.which("node") is None,
                                                  reason="needs pwsh and node (CI runs it)")),
]


@pytest.fixture
def tracker(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name in ("glab", "gh"):
        p = bin_dir / name
        p.write_text(FAKE)
        p.chmod(p.stat().st_mode | stat.S_IEXEC)
    state = tmp_path / "state"
    state.mkdir()
    (state / "pr.json").write_text('{"labels":[]}')
    return {"bin": bin_dir, "state": state, "tmp": tmp_path}


def run(tracker, interpreter, *args, provider="gitlab", **knobs):
    ref = PR if "github" in provider else MR
    env = {k: v for k, v in os.environ.items() if not k.startswith("FAKE_") and k != "ADLC_RUN_ID"}
    env.update({"PATH": f"{tracker['bin']}{os.pathsep}{env['PATH']}", "GITLAB_HOST": "gitlab.example.test",
                "FAKE_TRACKER_DIR": str(tracker["state"]), "FAKE_PROVIDER": provider})
    for k, v in knobs.items():
        if v is None:
            env.pop(k, None)
        else:
            env[k] = v
    script = PS_SCRIPT if interpreter == "pwsh" else SCRIPT
    cmd = ["pwsh", "-NoProfile", "-File", str(script)] if interpreter == "pwsh" else ["bash", str(script)]
    full = [a.replace("MRREF", ref) for a in args]
    return subprocess.run([*cmd, *full], capture_output=True, text=True, env=env)


def labels_of(tracker):
    return json.loads((tracker["state"] / "pr.json").read_text())["labels"]


def names(tracker, provider="gitlab"):
    ls = labels_of(tracker)
    return [l if isinstance(l, str) else l["name"] for l in ls]


# ── the skill text ──────────────────────────────────────────────────────────

def step6():
    text = SKILL.read_text(encoding="utf-8")
    return text[text.index("6. Set the PR label"):text.index("7. **Separation of Duties", text.index("6. Set the PR label"))]


def test_step6_posts_the_label_through_the_confirm_command():
    body = step6()
    assert "scripts/bash/confirm-validation-label.sh" in body
    assert "scripts/powershell/confirm-validation-label.ps1" in body


def test_step6_names_the_fail_closed_contract_and_the_honesty_rule():
    body = step6()
    assert "exit 0" in body and "exit 1" in body
    assert "never end it as `completed` with an unconfirmed label" in body


# ── behaviour, against a fake `glab api` / `gh api` ─────────────────────────

@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("provider", ["gitlab", "github"])
def test_sets_the_label_and_confirms(tracker, interpreter, provider):
    r = run(tracker, interpreter, "--mr", "MRREF", provider=provider)
    assert r.returncode == 0, r.stderr
    assert "carries 'validation'" in r.stdout
    assert "validation" in names(tracker, provider)


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_is_idempotent_when_the_label_is_already_there(tracker, interpreter):
    assert run(tracker, interpreter, "--mr", "MRREF").returncode == 0
    r = run(tracker, interpreter, "--mr", "MRREF")
    assert r.returncode == 0 and "already carries" in r.stdout


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_silently_dropped_set_fails_closed(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", "MRREF", FAKE_DROP="1")
    assert r.returncode == 1, r.stderr
    assert "not on" in (r.stdout + r.stderr) or "FAIL" in (r.stdout + r.stderr)


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_refused_set_is_a_usage_or_tracker_error(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", "MRREF", FAKE_REFUSE="1")
    assert r.returncode == 2, r.stderr
    assert "refused" in r.stderr


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_check_only_answers_without_writing(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", "MRREF", "--check-only")
    assert r.returncode == 1
    assert "validation" not in names(tracker)
    assert run(tracker, interpreter, "--mr", "MRREF").returncode == 0
    assert run(tracker, interpreter, "--mr", "MRREF", "--check-only").returncode == 0


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("args", [["--mr", "not-a-ref"], ["--mr", "MRREF", "--to", "../x"]])
def test_usage_errors_exit_2_and_write_nothing(tracker, interpreter, args):
    r = run(tracker, interpreter, *args)
    assert r.returncode == 2, r.stderr
    assert "validation" not in names(tracker)


def test_both_twins_run_the_same_node_read():
    """The label reader is the same JavaScript in both twins, so the twins
    cannot disagree on whether the label is there."""
    sh = SCRIPT.read_text(encoding="utf-8")
    ps = PS_SCRIPT.read_text(encoding="utf-8")
    js_sh = sh.split("READ_JS='\n", 1)[1].split("\n'\n", 1)[0]
    js_ps = ps.split("$readJs = @'\n", 1)[1].split("\n'@", 1)[0]
    norm = lambda t: "\n".join(l for l in t.splitlines() if l.strip())
    assert norm(js_sh) == norm(js_ps), "the label-reader JS differs between the twins"


def test_both_twins_set_the_same_label_shape():
    """The twins run the same node read logic; a drift shows here first."""
    for script in (SCRIPT, PS_SCRIPT):
        text = script.read_text(encoding="utf-8")
        assert "confirm-validation-label" in text
        assert "--check-only" in text
