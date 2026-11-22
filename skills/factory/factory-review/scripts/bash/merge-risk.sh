#!/usr/bin/env bash
# merge-risk.sh — deterministic merge-risk scorer (scoring weights).
# Category verdicts come from the review agents; the math lives here so the
# policy (weights) is reviewable code while the judgment stays with evidence.
#
# Usage:
#   merge-risk.sh --verification <poor|decent|good> --alignment <...> \
#     --impact <...> --rollback <...> --error-detection <...>
# Prints the per-category echo plus `Merge risk: <low|medium|high>`.
# The numeric score stays internal (deliberately unprinted).
#
# Weights: Impact 2x, Verification 2x, Rollback 1.5x,
# Error detection 1x, Alignment 1x. Mapping: poor=1, decent=2, good=3.
# Bands (lower score = higher risk): high score<1.5 / medium 1.5-<2.25 / low score>=2.25.
set -uo pipefail

die() { echo "merge-risk: $*" >&2; exit 2; }

req() { [ "$#" -ge 2 ] || die "$1 requires a value"; }

verification=""; alignment=""; impact=""; rollback=""; error_detection=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --verification) req "$@"; verification="$2"; shift 2 ;;
        --alignment) req "$@"; alignment="$2"; shift 2 ;;
        --impact) req "$@"; impact="$2"; shift 2 ;;
        --rollback) req "$@"; rollback="$2"; shift 2 ;;
        --error-detection) req "$@"; error_detection="$2"; shift 2 ;;
        --help|-h) sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) die "unknown argument '$1'" ;;
    esac
done

valid_class() {
    case "$1" in
        poor|decent|good) ;;
        *) die "$2 must be poor|decent|good, got '$1'" ;;
    esac
}

score_of() {
    case "$1" in
        poor) echo 1 ;;
        decent) echo 2 ;;
        good) echo 3 ;;
    esac
}

[ -n "$verification" ] || die "--verification is required"
[ -n "$alignment" ] || die "--alignment is required"
[ -n "$impact" ] || die "--impact is required"
[ -n "$rollback" ] || die "--rollback is required"
[ -n "$error_detection" ] || die "--error-detection is required"

valid_class "$verification" "--verification"
valid_class "$alignment" "--alignment"
valid_class "$impact" "--impact"
valid_class "$rollback" "--rollback"
valid_class "$error_detection" "--error-detection"

sv=$(score_of "$verification" "--verification")
sa=$(score_of "$alignment" "--alignment")
si=$(score_of "$impact" "--impact")
sr=$(score_of "$rollback" "--rollback")
se=$(score_of "$error_detection" "--error-detection")

# Weighted score x2 to keep integer halves out of bash arithmetic:
# (2*sv + 1*sa + 2*si + 1.5*sr + 1*se) / 7.5  ==  (4sv+2sa+4si+3sr+2se) / 15
num=$((4 * sv + 2 * sa + 4 * si + 3 * sr + 2 * se))

echo "verification: $verification"
echo "alignment: $alignment"
echo "impact: $impact"
echo "rollback: $rollback"
echo "error-detection: $error_detection"

# Bands on num/15 (lower score = higher risk): high num<=22
# (score<1.5), medium 23..33 (1.5<=score<2.25), low num>=34 (score>=2.25).
if [ "$num" -le 22 ]; then
    echo "Merge risk: high"
elif [ "$num" -le 33 ]; then
    echo "Merge risk: medium"
else
    echo "Merge risk: low"
fi
