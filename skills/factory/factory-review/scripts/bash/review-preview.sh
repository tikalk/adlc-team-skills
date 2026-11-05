#!/usr/bin/env bash
# factory-review pre-PR verdict preview (workspace issue 45, review-contract
# intake + pre-PR verdict preview records).
#
# Renders the would-be verdict against the working tree. ADVISORY ONLY:
#   * labeled "draft" — never a verdict
#   * no ``head=<sha>`` marker, no ``outcome=``, no ``important=``
#   * no head binding — not checked by check-verdict-head.sh
#   * no tracker writes — read-only passes reused, output to stdout only
#   * never posted to the tracker; no sensor may read this output
#
# Usage: review-preview.sh [working-tree]   # default: current directory
#
# Exits 0 on success. Missing provenance is reported (requested), but the
# script still exits 0 — it never blocks on provenance, it only records that
# provenance is absent so the author can supply it before opening a PR.

set -u
export LC_ALL=C

TREE="${1:-.}"

if ! cd "$TREE" 2>/dev/null; then
    echo "review-preview: cannot cd to $TREE" >&2
    exit 1
fi

# Changed files in the working tree (vs HEAD, or all files if no commit yet).
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    CHANGED=$(git diff --name-only HEAD 2>/dev/null || true)
else
    CHANGED=$(git ls-files 2>/dev/null || true)
fi

# Provenance: present if a PROVENANCE.md exists and is non-empty, or if any
# changed file mentions provenance / "files came from where".
PROVENANCE_PRESENT=0
if [ -f "PROVENANCE.md" ] && [ -s "PROVENANCE.md" ]; then
    PROVENANCE_PRESENT=1
elif printf '%s\n' "$CHANGED" | grep -qiE "provenance|files came from where"; then
    PROVENANCE_PRESENT=1
fi

cat <<EOF
factory-review pre-PR verdict preview — DRAFT (advisory, not a verdict)
=====================================================================

This is a draft preview only. It is NOT a factory-review verdict: it carries
no head-SHA marker, no outcome or importance fields, and it is never posted to
the tracker. No sensor reads this output.

Working tree: $TREE

Changed files:
$(if [ -n "$CHANGED" ]; then printf '%s\n' "$CHANGED" | sed 's/^/  /'; else echo "  (none)"; fi)

Evidence intake (read-only — passes reused, not executed in preview):
  bugs            structural check only
  security        structural check only
  spec-compliance structural check only
  test-integrity  structural check only
  ci-integrity    structural check only
  quality         structural check only

Provenance:
EOF

if [ "$PROVENANCE_PRESENT" -eq 1 ]; then
    cat <<EOF
  provenance: present — provenance file or provenance reference found in
  changed files. (Formal REVIEW.md policy fields + owner values are captured
   through the owner sign-off path; this preview reports presence only.)
EOF
else
    cat <<EOF
  missing — request "which files came from where" plus AI-contribution-policy
  compliance before opening the PR. No verdict is produced until provenance
  is provided (provenance joins evidence intake).
EOF
fi

cat <<EOF

Tracker writes: none. This preview performs no tracker writes and modifies
nothing in the working tree.

This preview is advisory. The head-bound verdict (a head SHA marker plus its
outcome and importance count) is produced only by factory-review on a
reviewed PR head and is checked by check-verdict-head.sh.
EOF

exit 0
