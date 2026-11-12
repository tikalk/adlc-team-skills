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

# Sanitize any path-like label before printing: never emit a raw path that
# could contain verdict-marker-like tokens (head=, outcome=, important=).
# A directory or file named e.g. outcome=merge-ready must not inject a
# misleading token into stdout or stderr. The placeholder drops the '='
# entirely ("outcome [redacted]"): the draft grader matches bare substrings
# like "outcome=", so even a "<value>" placeholder would still match.
# NOTE: keep this sed program byte-identical everywhere it is used below
# (SAFE_TREE_LABEL, SAFE_CHANGED, SAFE_PROVENANCE_SOURCE).
SAFE_TREE_LABEL=$(printf '%s' "$TREE" | sed 's/head=[0-9a-fA-F]*/head [redacted]/g; s/outcome=[a-z-]*/outcome [redacted]/g; s/important=[0-9]*/important [redacted]/g')

if ! cd -- "$TREE" 2>/dev/null; then
    echo "review-preview: cannot cd to $SAFE_TREE_LABEL" >&2
    exit 1
fi

# Safe git invocation: disable repository-local core.fsmonitor (which can
# execute attacker-configured commands) and suppress the pager. These flags
# apply per-invocation and do not alter the repository configuration.
# Content diffs additionally pass --no-ext-diff --no-textconv so that
# repository-configured external diff drivers (diff.external,
# .gitattributes driver `command`) and textconv filters can neither execute
# commands nor fabricate the scanned content.
GIT_SAFE="git -c core.fsmonitor= --no-pager"

# Changed files in the working tree: tracked modifications/staged changes,
# plus untracked, non-ignored files (git diff --name-only HEAD misses
# untracked files).
if $GIT_SAFE rev-parse --verify HEAD >/dev/null 2>&1; then
    CHANGED=$($GIT_SAFE diff --name-only HEAD 2>/dev/null || true)
    UNTRACKED=$($GIT_SAFE ls-files --others --exclude-standard 2>/dev/null || true)
else
    CHANGED=""
    UNTRACKED=$($GIT_SAFE ls-files --others --exclude-standard 2>/dev/null || true)
fi
CHANGED=$(printf '%s\n%s\n' "$CHANGED" "$UNTRACKED" | grep -v '^$' || true)

# Provenance: detected by inspecting PROVENANCE.md content and the contents
# of changed files for provenance references. A filename containing
# "provenance" alone is not evidence. The format of formal provenance is
# governed by the owner sign-off path and is not defined here;
# this preview only reports whether a textual provenance reference was found.
PROVENANCE_PRESENT=0
PROVENANCE_SOURCE="none"
if [ -f "PROVENANCE.md" ] && grep -q '[^[:space:]]' "PROVENANCE.md" 2>/dev/null; then
    PROVENANCE_PRESENT=1
    PROVENANCE_SOURCE="provenance file"
fi
# Inspect added lines of changed files for provenance references (e.g. "which
# files came from where"). Do not treat a filename as provenance evidence.
# Only newly added lines count: pre-existing committed content mentioning
# provenance (e.g. a historical CHANGELOG entry) is not new evidence, so an
# unrelated edit to such a file must not suppress the missing-provenance
# request. Untracked files are entirely new, so their full content counts.
if [ "$PROVENANCE_PRESENT" -eq 0 ] && [ -n "$CHANGED" ]; then
    while IFS= read -r changed_file; do
        [ -f "$changed_file" ] || continue
        if $GIT_SAFE ls-files --error-unmatch -- "$changed_file" >/dev/null 2>&1; then
            _scan=$($GIT_SAFE diff --no-ext-diff --no-textconv -U0 HEAD -- "$changed_file" 2>/dev/null | grep '^+' | grep -v '^+++' || true)
        else
            _scan=$(cat -- "$changed_file" 2>/dev/null || true)
        fi
        if printf '%s\n' "$_scan" | grep -qiE 'which files came from where|provenance'; then
            PROVENANCE_PRESENT=1
            PROVENANCE_SOURCE="reference in $changed_file"
            break
        fi
    done <<< "$CHANGED"
fi

# Display the target tree safely: never print a raw path that could contain
# verdict-marker-like tokens (head=, outcome=, important=). Use the sanitized
# label defined above; apply the same substitution to each changed-file name
# so a file named e.g. outcome=merge-ready.py cannot inject a token either.
SAFE_CHANGED=$(printf '%s\n' "$CHANGED" | sed 's/head=[0-9a-fA-F]*/head [redacted]/g; s/outcome=[a-z-]*/outcome [redacted]/g; s/important=[0-9]*/important [redacted]/g')

cat <<EOF
factory-review pre-PR verdict preview — DRAFT (advisory, not a verdict)
=====================================================================

This is a draft preview only. It is NOT a factory-review verdict: it carries
no head-SHA marker, no outcome or importance fields, and it is never posted to
the tracker. No sensor reads this output.

Working tree: $SAFE_TREE_LABEL

Changed files:
$(if [ -n "$SAFE_CHANGED" ]; then printf '%s\n' "$SAFE_CHANGED" | sed 's/^/  /'; else echo "  (none)"; fi)

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
    # Sanitize the source label: it may embed a changed-file name that
    # itself contains verdict-marker-like tokens (same class as Nit 4).
    SAFE_PROVENANCE_SOURCE=$(printf '%s' "$PROVENANCE_SOURCE" | sed 's/head=[0-9a-fA-F]*/head [redacted]/g; s/outcome=[a-z-]*/outcome [redacted]/g; s/important=[0-9]*/important [redacted]/g')
    cat <<EOF
  provenance: detected — $SAFE_PROVENANCE_SOURCE.
  (A textual provenance reference is not proof of complete or compliant
   provenance. Formal REVIEW.md policy fields + owner values are captured
   through the owner sign-off path; this preview reports detection only.)
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
