"""Grader for the CDR routing recall eval (adlc-workspace#36).

The model lists the records it would open, one per line. Lines are mapped to
module names (IDs resolve through cdr-aliases.json, since the old full-table
shape shows IDs only). Score = recall of the case's expected modules; extra
picks outside expect/allow/always_allow are reported as false positives but
do not fail the case. A case with expect=[] passes only on NONE (or only
always-allowed picks).
"""
import json
import re
from pathlib import Path

_ALIASES = json.loads((Path(__file__).parent / "cdr-aliases.json").read_text())
_MODULES = set(_ALIASES.values())


def parse_picks(output: str) -> set:
    picks = set()
    text = output or ""
    for tok in re.findall(r"[A-Za-z0-9_.\-/]+", text):
        tok = tok.strip(".-/")
        if tok in _ALIASES:
            picks.add(_ALIASES[tok])
            continue
        name = tok.rsplit("/", 1)[-1]
        name = re.sub(r"\.md$", "", name)
        if name in _MODULES:
            picks.add(name)
    return picks


def get_assert(output: str, context: dict = None) -> dict:
    case = json.loads(((context or {}).get("vars") or {}).get("case_json", "{}"))
    expect = set(case.get("expect", []))
    ok_extra = set(case.get("allow", [])) | set(case.get("always_allow", []))
    picks = parse_picks(output)
    false_pos = sorted(picks - expect - ok_extra)

    if not expect:
        passed = not (picks - ok_extra)
        score = 1.0 if passed else 0.0
        reason = "expected NONE" + ("" if passed else f"; picked {sorted(picks - ok_extra)}")
    else:
        hit = picks & expect
        if case.get("any_of"):
            score = 1.0 if hit else 0.0
        else:
            score = len(hit) / len(expect)
        passed = score == 1.0
        missed = sorted(expect - picks)
        reason = f"recall {score:.2f}" + (f"; missed {missed}" if missed and not (case.get('any_of') and hit) else "")
    if false_pos:
        reason += f"; false positives {false_pos}"
    return {"pass": passed, "score": score, "reason": reason}
