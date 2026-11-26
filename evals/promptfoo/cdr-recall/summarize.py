"""Print CDR routing recall per index shape from a promptfoo JSON result,
and gate on it (EVAL-018).

Usage: python3 summarize.py results.json [--gate] [--shape S]
                            [--min-recall R] [--max-false-pos N]

--gate             exit 1 when the 'shipped' shape recalls less than
                   'full-table' (nightly: what team-boot injects must not
                   lose recall against the pre-#36 table).
--gate-margin M    tolerate shipped up to M below full-table (default 0).
                   One case of model noise moves a single run by 1/N, so a
                   margin-free comparison of two single runs is a coin flip
                   when both shapes are near 100%.
--shape S          shape the floor applies to (default: shipped).
--min-recall R     exit 1 when shape S's mean recall is below R (0..1).
--max-false-pos N  exit 1 when shape S picks more than N records outside a
                   case's expect/allow lists, summed over all cases.

Without --min-recall/--max-false-pos the floor is not enforced: the run
prints BASELINE and passes, so a first CI run can set the floor from data.
An empty or missing shape is a failure, never a pass.
"""
import argparse
import json
import re
import sys
from collections import defaultdict

_FP = re.compile(r"false positives \[([^\]]*)\]")


def false_pos_count(reason: str) -> int:
    m = _FP.search(reason or "")
    if not m or not m.group(1).strip():
        return 0
    return len([x for x in m.group(1).split(",") if x.strip()])


def tally(data: dict):
    rows = data.get("results", {})
    rows = rows.get("results", []) if isinstance(rows, dict) else rows
    score, misses, fps = defaultdict(list), defaultdict(list), defaultdict(int)
    for r in rows:
        shape = (r.get("prompt") or {}).get("label", "?")
        case = (r.get("testCase") or {}).get("description") or r.get("vars", {}).get("task", "?")
        grade = r.get("gradingResult") or {}
        s = grade.get("score", 0.0) if not r.get("error") else 0.0
        reason = grade.get("reason", "") or r.get("error", "")
        score[shape].append(s)
        fps[shape] += false_pos_count(reason)
        if s < 1.0 or false_pos_count(reason):
            misses[shape].append(f"{case}: {reason}")
    return score, misses, fps


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("results")
    ap.add_argument("--gate", action="store_true")
    ap.add_argument("--gate-margin", type=float, default=0.0)
    ap.add_argument("--shape", default="shipped")
    ap.add_argument("--min-recall", type=float)
    ap.add_argument("--max-false-pos", type=int)
    a = ap.parse_args(argv[1:])

    with open(a.results) as f:
        score, misses, fps = tally(json.load(f))
    print(f"{'shape':<12} {'cases':>5} {'recall':>7} {'full hits':>9} {'false pos':>9}")
    means = {}
    for shape, ss in score.items():
        means[shape] = sum(ss) / len(ss)
        print(f"{shape:<12} {len(ss):>5} {means[shape]:>7.2%} "
              f"{sum(1 for s in ss if s == 1.0):>9} {fps[shape]:>9}")
    for shape, ms in misses.items():
        print(f"\n{shape} misses / false positives:")
        for m in ms:
            print(f"  - {m}")

    failed = False
    if a.gate:
        if not {"shipped", "full-table"} <= means.keys():
            print("\nGATE FAIL: --gate needs both 'shipped' and 'full-table' results")
            failed = True
        elif means["shipped"] < means["full-table"] - a.gate_margin - 1e-9:
            print(f"\nGATE FAIL: shipped recall {means['shipped']:.2%} below full-table "
                  f"{means['full-table']:.2%} by more than {a.gate_margin:.2%}")
            failed = True
        else:
            print(f"\nGATE PASS: shipped {means['shipped']:.2%} vs full-table "
                  f"{means['full-table']:.2%} (margin {a.gate_margin:.2%})")

    if a.shape not in means:
        # Missing/empty shape fails with or without a floor (docstring).
        print(f"\nFLOOR FAIL: no results for shape '{a.shape}'")
        failed = True
    elif a.min_recall is None and a.max_false_pos is None:
        print(f"\nBASELINE: no floor set; {a.shape} recall {means[a.shape]:.2%}, "
              f"{fps[a.shape]} false positives over {len(score[a.shape])} cases")
    else:
        floor_failed = False
        if a.min_recall is not None and means[a.shape] < a.min_recall:
            print(f"\nFLOOR FAIL: {a.shape} recall {means[a.shape]:.2%} < {a.min_recall:.2%}")
            floor_failed = True
        if a.max_false_pos is not None and fps[a.shape] > a.max_false_pos:
            print(f"\nFLOOR FAIL: {a.shape} false positives {fps[a.shape]} > {a.max_false_pos}")
            floor_failed = True
        failed = failed or floor_failed
        if not floor_failed:
            print(f"\nFLOOR PASS: {a.shape} recall {means[a.shape]:.2%}, {fps[a.shape]} false positives")
    if not score:
        print("\nFAIL: result file has no rows")
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
