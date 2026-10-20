#!/usr/bin/env bash
# Verify that the latest factory-review verdict names the current PR head.
#
# A factory-review verdict certifies exactly ONE head SHA — the one carried in
# its `head=<sha>` marker. Any push after the verdict (a fix, a rebase, a
# force-push) moves the head and invalidates it, so the review must run again
# on the new head before merge-readiness is claimed.
#
# The skill states that rule; this script makes it mechanical: it reads the
# PR's comments and review bodies, finds the latest factory-review review
# verdict, and compares the head it names with the head being merged.
#
# Usage:
#   check-verdict-head.sh --repo <owner/repo> --pr <number> [--pr-head <sha>]
#   check-verdict-head.sh --verdicts <file> --pr-head <sha>      # offline
#
# Exit codes:
#   0 = no factory-review verdict, or the verdict names the current head
#   1 = the verdict is stale or unbound — the review must be re-run on this head
#   2 = usage or infrastructure error
#
# The --verdicts file holds one comment body per record, separated by a line
# containing only "%%%". It exists so the check can be unit-tested without a
# network.

set -u

REPO=""
PR=""
PR_HEAD=""
VERDICTS_FILE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo) REPO="${2:-}"; shift 2 ;;
        --pr) PR="${2:-}"; shift 2 ;;
        --pr-head) PR_HEAD="${2:-}"; shift 2 ;;
        --verdicts) VERDICTS_FILE="${2:-}"; shift 2 ;;
        --help|-h) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "check-verdict-head: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

if [ -z "$PR_HEAD" ]; then
    echo "check-verdict-head: --pr-head <sha> is required" >&2
    exit 2
fi

# The marker that carries a review verdict.
MARKER='factory-review:step=review'

fetch_bodies() {
    if [ -n "$VERDICTS_FILE" ]; then
        cat "$VERDICTS_FILE"
        return 0
    fi
    if ! command -v gh >/dev/null 2>&1; then
        echo "check-verdict-head: gh is not available and --verdicts was not given" >&2
        exit 2
    fi
    if [ -z "$REPO" ] || [ -z "$PR" ]; then
        echo "check-verdict-head: --repo and --pr are required without --verdicts" >&2
        exit 2
    fi
    # Issue comments and review bodies both carry the marker; inline review
    # comments have no body, so the review body is what matters.
    {
        gh api "repos/$REPO/issues/$PR/comments" --paginate --jq '.[] | .body // ""'
        gh api "repos/$REPO/pulls/$PR/reviews" --paginate --jq '.[] | .body // ""'
    } 2>/dev/null || {
        echo "check-verdict-head: could not read the PR's comments (gh api failed)" >&2
        exit 2
    }
}

# The head named by the latest review verdict, or the empty string when there
# is no verdict at all. Records are separated by a line of only %%% and are
# walked newest-first, so an older verdict never shadows a newer one.
latest_verdict_head() {
    awk -v marker="$MARKER" '
        { line[NR] = $0 }
        END {
            n = 0
            cur = ""
            for (i = 1; i <= NR; i++) {
                if (line[i] == "%%%") { rec[++n] = cur; cur = "" }
                else cur = (cur == "" ? line[i] : cur "\n" line[i])
            }
            rec[++n] = cur
            for (i = n; i >= 1; i--) {
                body = rec[i]
                if (index(body, marker) == 0) continue
                # head=<sha> — the first one in this body
                idx = index(body, "head=")
                if (idx == 0) { print "UNBOUND"; exit }
                rest = substr(body, idx + 5)
                gsub(/[^0-9a-fA-F].*$/, "", rest)
                if (rest != "") { print rest; exit }
                print "UNBOUND"; exit
            }
        }
    '
}

BODIES=$(fetch_bodies) || exit 2
if [ -z "$BODIES" ]; then
    echo "check-verdict-head: OK — no factory-review verdict on this PR; nothing to verify."
    exit 0
fi

VERDICT_HEAD=$(printf '%s\n' "$BODIES" | latest_verdict_head)

if [ -z "$VERDICT_HEAD" ]; then
    echo "check-verdict-head: OK — no factory-review verdict on this PR; nothing to verify."
    exit 0
fi

if [ "$VERDICT_HEAD" = "UNBOUND" ]; then
    echo "check-verdict-head: FAIL — a factory-review verdict exists but names no head."
    echo "  A verdict that names no head certifies nothing: it cannot be checked"
    echo "  against a head, so it cannot support a merge-ready claim."
    echo "  Re-run the review on the current head so the marker names it."
    exit 1
fi

if [ "$VERDICT_HEAD" = "$PR_HEAD" ]; then
    echo "check-verdict-head: OK — the verdict names the current head ($PR_HEAD)."
    exit 0
fi

echo "check-verdict-head: FAIL — the verdict names $VERDICT_HEAD but the head is $PR_HEAD."
echo "  A fix push invalidates the verdict: re-run the review passes on the current"
echo "  head and post the updated verdict naming $PR_HEAD before claiming merge-readiness."
exit 1
