#!/usr/bin/env bash
# factory-review pre-PR verdict preview (workspace issue 45, review-contract
# intake + pre-PR verdict preview records).
#
# Renders the deterministic preview envelope against the working tree.
# ADVISORY ONLY. This script generates no findings: it collects changed
# files, sanitizes marker-like tokens, runs provenance intake, and renders
# reviewer-supplied evidence verbatim. The six owner-confirmed passes
# (bugs, security, spec-compliance, test-integrity, ci-integrity, quality)
# are executed by the single reviewer following SKILL.md section 6; the
# reviewer passes its per-pass evidence via --evidence-file <path> (a file
# OUTSIDE the target tree — never write inside the reviewed tree) or "-"
# for stdin. Without evidence input every pass reports
# "unverified: reviewer procedure not invoked in this shell-only run".
#
#   * labeled "draft" — never a verdict
#   * no ``head=<sha>`` marker, no ``outcome=``, no ``important=``
#   * no bare ``factory-review:step=review`` marker (incl. inside filenames)
#   * no head binding — not checked by check-verdict-head.sh
#   * no tracker writes — read-only, output to stdout only
#   * never posted to the tracker; no sensor may read this output
#
# Usage: review-preview.sh [working-tree] [--evidence-file <path>|-]   # default: current directory, no evidence
#
# Exits 0 on success. Missing provenance is reported (requested), but the
# script still exits 0 — it never blocks on provenance, it only records that
# provenance is absent so the author can supply it before opening a PR.

set -u
export LC_ALL=C
export GIT_CONFIG_NOSYSTEM=1

TREE="."
EVIDENCE_FILE=""

while [ $# -gt 0 ]; do
    case "${1:-}" in
        --evidence-file)
            [ $# -ge 2 ] || { echo "review-preview: --evidence-file requires a path" >&2; exit 1; }
            EVIDENCE_FILE="$2"
            shift 2
            ;;
        --evidence-file=*)
            EVIDENCE_FILE="${1#--evidence-file=}"
            shift
            ;;
        -h|--help)
            echo "Usage: review-preview.sh [working-tree] [--evidence-file <path>|-]"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "review-preview: unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [ "$TREE" = "." ]; then
                TREE="$1"
                shift
            else
                echo "review-preview: unexpected argument: $1" >&2
                exit 1
            fi
            ;;
    esac
done

# Sanitize any path-like label before printing: never emit a raw path that
# could contain verdict-marker-like tokens (head=, outcome=, important=).
# A directory or file named e.g. outcome=merge-ready must not inject a
# misleading token into stdout or stderr. The placeholder drops the '='
# entirely ("outcome [redacted]"): the draft grader matches bare substrings
# like "outcome=", so even a "<value>" placeholder would still match.
# Sanitize the bare review marker too: a file, directory, or evidence line
# mentioning factory-review:step=review must not inject the marker (the
# marker check rejects the bare prefix, so the token itself is broken up).
# NOTE: keep this sed program byte-identical everywhere it is used below
# (SAFE_TREE_LABEL, SAFE_CHANGED, SAFE_PROVENANCE_SOURCE, SAFE_EVIDENCE).
SAFE_MARKER_RE='s/factory-review:step=review/factory-review:step=[redacted]/g'
safe_label() { printf '%s' "$1" | sed 's/head=[0-9a-fA-F][0-9a-fA-F]*/head [redacted]/g; s/outcome=[a-z-]*/outcome [redacted]/g; s/important=[0-9]*/important [redacted]/g' | sed "$SAFE_MARKER_RE"; }
SAFE_TREE_LABEL=$(safe_label "$TREE")

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
GIT_SAFE="git -c core.fsmonitor= -c core.quotePath=false --no-pager --no-optional-locks"

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
# verdict-marker-like tokens (head=, outcome=, important=, bare review
# marker). Use the sanitized label defined above; apply the same
# substitution to each changed-file name so a file named e.g.
# outcome=merge-ready.py cannot inject a token either.
SAFE_CHANGED=$(safe_label "$(printf '%s\n' "$CHANGED")")

cat <<EOF
factory-review pre-PR verdict preview — DRAFT (advisory, not a verdict)
=====================================================================

This is a draft preview only. It is NOT a factory-review verdict: it carries
no head-SHA marker, no outcome or importance fields, and it is never posted to
the tracker. No sensor reads this output.

Working tree: $SAFE_TREE_LABEL

Changed files:
$(if [ -n "$SAFE_CHANGED" ]; then printf '%s\n' "$SAFE_CHANGED" | sed 's/^/  /'; else echo "  (none)"; fi)

Evidence intake (read-only — reviewer evidence rendered below):
EOF

# Reviewer evidence: optional, rendered verbatim after sanitization.
# The twins generate no findings — every evidence line arrives from the
# SKILL.md section 6 reviewer procedure via --evidence-file (outside the
# target tree) or stdin ("-"). Without evidence input every pass is
# reported as not-invoked (honest, fails the execution-evidence check).
if [ -n "$EVIDENCE_FILE" ]; then
    if [ "$EVIDENCE_FILE" = "-" ]; then
        EVIDENCE_RAW=$(cat)
    elif [ -f "$EVIDENCE_FILE" ]; then
        EVIDENCE_RAW=$(cat -- "$EVIDENCE_FILE" 2>/dev/null || true)
    else
        echo "review-preview: evidence file not found: $(safe_label "$EVIDENCE_FILE")" >&2
        exit 1
    fi
    if [ -n "$EVIDENCE_RAW" ]; then
        SAFE_EVIDENCE=$(safe_label "$EVIDENCE_RAW")
        printf '%s\n' "$SAFE_EVIDENCE"
    fi
fi

PASS_ORDER="bugs security spec-compliance test-integrity ci-integrity quality"
for _pass in $PASS_ORDER; do
    if [ -n "${EVIDENCE_RAW:-}" ] && printf '%s\n' "$EVIDENCE_RAW" | grep -qi "^pass:[[:space:]]*$_pass\\b"; then
        printf '  pass: %s — evidence rendered above (reviewer-attested, see evidence lines)\n' "$_pass"
    else
        printf '  pass: %s — unverified: reviewer procedure not invoked in this shell-only run\n' "$_pass"
    fi
done

cat <<EOF

Provenance:
EOF

if [ "$PROVENANCE_PRESENT" -eq 1 ]; then
    # Sanitize the source label: it may embed a changed-file name that
    # itself contains verdict-marker-like tokens (same class as Nit 4).
    SAFE_PROVENANCE_SOURCE=$(safe_label "$PROVENANCE_SOURCE")
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
