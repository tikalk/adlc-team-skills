"""Specify→clarify handoff contract guards.

Every record family follows ``X-specify`` (draft capture) → ``X-clarify``
(human gate). Inside factory workflows the chain is structural
(``factory-intent`` / ``factory-init``). For standalone use the contract is:

1. the install-closure map carries ``X-specify → X-clarify`` for every
   family, so installing a specify skill alone still yields its gate; and
2. no ``*-specify`` prose promises that the model will invoke its clarify
   skill — clarify skills are ``disable-model-invocation: true``, so outside
   an explicit workflow step only the user can run them.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"

FAMILIES = ("architect", "product", "change", "evals")


def test_specify_clarify_edges_in_deps_manifest():
    """skills-deps.json: every X-specify requires its X-clarify gate."""
    manifest = json.loads((ROOT / ".skills-deps.json").read_text(encoding="utf-8"))
    requires = manifest["requires"]
    for family in FAMILIES:
        specify, clarify = f"{family}-specify", f"{family}-clarify"
        assert clarify in requires.get(specify, []), (
            f".skills-deps.json: {specify} must require {clarify} "
            f"(got {requires.get(specify, [])})"
        )


def test_specify_prose_does_not_promise_auto_invocation():
    """No *-specify skill may claim an automatic clarify handoff or trigger."""
    offenders = []
    for family in FAMILIES:
        path = SKILLS / family / f"{family}-specify" / "SKILL.md"
        content = path.read_text(encoding="utf-8").lower()
        for token in ("auto-handoff", "auto handoff"):
            if token in content:
                offenders.append(f"{path.relative_to(ROOT)} contains {token!r}")
    assert not offenders, (
        "clarify skills are disable-model-invocation: true; specify prose must "
        "name the command, not promise automatic invocation:\n" + "\n".join(offenders)
    )
