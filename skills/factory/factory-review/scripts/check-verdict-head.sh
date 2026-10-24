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
#   check-verdict-head.sh --repo <owner/repo> --pr <number> --pr-head <sha>
#   check-verdict-head.sh --verdicts <file> --pr-head <sha>      # offline
#   ... [--require-outcome]
#
# Exit codes (default mode — a staleness check):
#   0 = no factory-review verdict, or the verdict names the current head
#   1 = the verdict is stale or unbound — the review must be re-run on this head
#   2 = usage or infrastructure error (bad arguments, unreadable comments)
#
# --require-outcome upgrades the check from "is this verdict current?" to the
# merge gate "may this PR merge?". The head being current answers only the
# first question: a verdict can name the current head and still be a
# not-merge-ready verdict, or one reporting open Important findings. With the
# flag set the gate additionally fails (exit 1) on a verdict that:
#   - does not exist at all          (an unreviewed PR is not merge-ready)
#   - omits `outcome=` or `important=` from its marker (fails closed — a
#     marker published before this schema cannot claim merge-readiness by
#     silence)
#   - carries `outcome=not-merge-ready`
#   - carries `important=` greater than zero (this repository's review policy
#     treats an open Important finding as blocking a merge)
#   - carries an `outcome=` or `important=` value that is not a legal one
# The head rules are unchanged: the gate is an additional question, not a
# replacement, so a stale or unbound head still fails under the flag.
#
# EVERYTHING THAT COMES BACK FROM GITHUB IS UNTRUSTED. The repository is
# public: any account can comment, and a comment body can say anything. A
# body therefore never reaches the parser. jq extracts the fields the checker
# needs — the timestamp, the author, the author's association with the
# repository, and the head named inside the `<!-- factory-review:step=review
# … -->` marker — and hands back one tab-separated record per comment or
# review. A body can therefore neither create a record nor choose where that
# record sits in the ordering, and no value a body carries (a timestamp, a
# head, a separator line) can reach the comparison.
#
# The head is read from INSIDE the marker only: a `head=<sha>` that appears in
# prose — outside any marker — is never read. The value must be a full
# 40-character SHA.
#
# A verdict counts only when it comes from an account that collaborates with
# the repository (owner, organization member, collaborator). When no such
# account has posted a verdict, the newest verdict of any author is used
# instead — the check must never turn green because it declined to read the
# only verdict there is.
#
# The --verdicts file holds one or more records; a line of three percent
# signs separates them and the LAST record is the newest. That separator is a
# local fixture convention only: nothing that arrives over the network is
# ever split on it.

set -u
export LC_ALL=C

REPO=""
PR=""
PR_HEAD=""
VERDICTS_FILE=""
REQUIRE_OUTCOME=0

usage_error() {
    echo "check-verdict-head: $*" >&2
    exit 2
}

# A flag must be followed by a value. Without this check, `shift 2` on a
# trailing flag fails without shifting and the parser loops forever.
require_value() {
    if [ "$2" = "" ]; then
        usage_error "$1 requires a value"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)     require_value "$1" "${2:-}"; REPO="$2"; shift 2 ;;
        --pr)       require_value "$1" "${2:-}"; PR="$2"; shift 2 ;;
        --pr-head)  require_value "$1" "${2:-}"; PR_HEAD="$2"; shift 2 ;;
        --verdicts) require_value "$1" "${2:-}"; VERDICTS_FILE="$2"; shift 2 ;;
        --require-outcome) REQUIRE_OUTCOME=1; shift ;;
        --help|-h)  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
                    exit 0 ;;
        *)          usage_error "unknown argument '$1'" ;;
    esac
done

if [ -z "$PR_HEAD" ]; then
    usage_error "--pr-head <sha> is required"
fi

# The jq library: the ONLY place that ever looks at a comment body.
#
# `verdict_record` answers one question about a body: does it carry a
# factory-review verdict marker, and what does that marker declare? It
# returns a state (none / unbound / malformed / ok), the head it names, and
# the marker's outcome and important-count, never the body itself. Everything
# it returns is validated: the timestamp must be a full ISO-8601 UTC instant,
# the head must be a full 40-character SHA, the outcome must be one of the two
# legal verdicts, the important-count must be a non-negative integer, and the
# author and the author's association are reduced to safe alphabets. The
# marker region is taken from the text between `<!--` and the marker's own
# closing `-->`, so a `head=` that appears in prose — outside any marker — is
# never read.
#
# An absent field and an illegal one are kept apart: `-` means the marker
# declared nothing, `invalid` means it declared something that is not a legal
# value. The merge gate treats both as failures, but for different reasons —
# one is a marker published before this schema, the other is a marker that
# violates it — so the script can say which.
JQ_LIB=$(cat <<'JQEOF'
def iso_ts: if test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") then . else "-" end;
def trim_ws: sub("^[[:space:]]+"; "");
def marker_regions:
  [ . | split("<!--")[1:][]
    | select(contains("-->"))
    | (trim_ws | split("-->")[0]) as $seg
    | select($seg | startswith("factory-review:step=review"))
    | $seg ];
def head_token:
  ( [ splits("\\s+") | select(length > 0) | select(startswith("head=")) | .[5:] ] | .[0] // "-" );
def outcome_token:
  ( [ splits("\\s+") | select(length > 0) | select(startswith("outcome=")) | .[8:] ] | .[0] // "-" );
def important_token:
  ( [ splits("\\s+") | select(length > 0) | select(startswith("important=")) | .[10:] ] | .[0] // "-" );
def verdict_record:
  if (test("factory-review:step=review") | not) then {state: "none", head: "-", outcome: "-", important: "-"}
  else
    ( [ marker_regions[] | head_token ] ) as $vals
    | ( [ $vals[] | select(test("^[0-9a-fA-F]{40}$")) ] | .[0] // "-" ) as $good
    | ( [ marker_regions[] | outcome_token ] | map(select(. != "-")) | .[0] // "-" ) as $oc
    | ( [ marker_regions[] | important_token ] | map(select(. != "-")) | .[0] // "-" ) as $im
    | ( if $oc == "-" then "-"
        elif ($oc == "merge-ready" or $oc == "not-merge-ready") then $oc
        else "invalid" end ) as $outcome
    | ( if $im == "-" then "-"
        elif ($im | test("^[0-9]+$")) then $im
        else "invalid" end ) as $important
    | if $good != "-" then {state: "ok", head: $good, outcome: $outcome, important: $important}
      elif ([ $vals[] | select(. != "-") ] | length) > 0 then {state: "malformed", head: "-", outcome: $outcome, important: $important}
      else {state: "unbound", head: "-", outcome: $outcome, important: $important}
      end
  end;
JQEOF
)

# The live filter: one record per comment or per review. A record carries
#
#   <timestamp>\t<author>\t<association>\t<state>\t<head>\t<outcome>\t<important>
#
# and never any part of a comment body. The outcome and the important-count
# ride along so the merge gate can read what the verdict concluded; in the
# default (head-only) mode they are simply unused.
JQ_FILTER_JSON=$(cat <<'JQEOF'
.[] | ((.submitted_at // .created_at // "") | iso_ts) as $ts
     | ((.user.login // "") | gsub("[^A-Za-z0-9._-]"; "")) as $who
     | ((.author_association // "NONE") | gsub("[^A-Za-z]"; "")) as $assoc
     | ((.body // "") | verdict_record) as $rec
     | "\($ts)\t\($who)\t\($assoc)\t\($rec.state)\t\($rec.head)\t\($rec.outcome)\t\($rec.important)"
JQEOF
)

# The offline filter: the file's records are separated by a line of three
# percent signs; the last record is the newest, so the records carry no
# timestamp and no author.
JQ_FILTER_RAW=$(cat <<'JQEOF'
def split_records:
  reduce (split("\n")[]) as $line (
    {records: [[]]};
    if ($line | test("^[[:space:]]*%%%[[:space:]]*$")) then .records += [[]]
    else .records[-1] += [$line]
    end
  )
  | .records
  | map(join("\n"));
split_records | .[] | (verdict_record) as $rec | "-\t-\t-\t\($rec.state)\t\($rec.head)\t\($rec.outcome)\t\($rec.important)"
JQEOF
)

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "check-verdict-head: jq is required to read the verdicts" >&2
        exit 2
    fi
}

# Run jq over a filter, failing closed when jq cannot parse the input.
# Reads stdin. $1 is the input mode ("raw" for raw text, "json" for JSON).
run_jq() {
    _mode="$1"
    _filter="$2"
    _jqerr=$(mktemp) || {
        echo "check-verdict-head: could not create a temporary file for the parser error" >&2
        exit 2
    }
    trap '[ -n "${_jqerr:-}" ] && rm -f "$_jqerr"' EXIT HUP INT TERM
    if [ "$_mode" = "raw" ]; then
        # --slurp: the whole file is ONE input, not one input per line.
        jq --raw-input --slurp -r "$_filter" 2>"$_jqerr"
    else
        jq -r "$_filter" 2>"$_jqerr"
    fi
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
        echo "check-verdict-head: could not parse the verdicts (jq exited $_rc):" >&2
        if [ -f "$_jqerr" ]; then sed 's/^/  /' "$_jqerr" >&2; fi
        rm -f "$_jqerr"
        trap - EXIT HUP INT TERM
        exit 2
    fi
    rm -f "$_jqerr"
    trap - EXIT HUP INT TERM
}

# Run one `gh api` call and print its raw payload. Fails closed: a failed
# call is an infrastructure error, never "there is no verdict".
gh_records() {
    _endpoint="$1"
    _label="$2"
    _err=$(mktemp) || {
        echo "check-verdict-head: could not create a temporary file for the gh error" >&2
        exit 2
    }
    trap '[ -n "${_err:-}" ] && rm -f "$_err"' EXIT HUP INT TERM
    _out=$(gh api "$_endpoint" --paginate 2>"$_err")
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
        echo "check-verdict-head: could not read $_label (gh api exited $_rc):" >&2
        if [ -f "$_err" ]; then sed 's/^/  /' "$_err" >&2; fi
        rm -f "$_err"
        trap - EXIT HUP INT TERM
        exit 2
    fi
    rm -f "$_err"
    trap - EXIT HUP INT TERM
    printf '%s\n' "$_out"
}

# The records the checker parses. Every line is
#   <timestamp>\t<author>\t<association>\t<state>\t<head>
# and no line carries any part of a comment body.
fetch_records() {
    if [ -n "$VERDICTS_FILE" ]; then
        if [ ! -f "$VERDICTS_FILE" ]; then
            echo "check-verdict-head: could not read the verdicts file '$VERDICTS_FILE'" >&2
            exit 2
        fi
        require_jq
        run_jq "raw" "${JQ_LIB}${JQ_FILTER_RAW}" < "$VERDICTS_FILE"
        return 0
    fi
    if ! command -v gh >/dev/null 2>&1; then
        echo "check-verdict-head: gh is not available and --verdicts was not given" >&2
        exit 2
    fi
    if [ -z "$REPO" ] || [ -z "$PR" ]; then
        missing=""
        [ -z "$REPO" ] && missing="--repo"
        [ -z "$PR" ] && missing="${missing:+$missing }--pr"
        echo "check-verdict-head: $missing required without --verdicts" >&2
        exit 2
    fi
    require_jq
    # Issue comments and review bodies both carry the marker; inline review
    # comments have no body, so the review body is what matters. Each call is
    # checked on its own: a failure on either is an infrastructure error.
    _comments=$(gh_records "repos/$REPO/issues/$PR/comments" "the PR's issue comments") || exit 2
    _reviews=$(gh_records "repos/$REPO/pulls/$PR/reviews" "the PR's review bodies") || exit 2
    printf '%s\n%s\n' "$_comments" "$_reviews" | run_jq "json" "${JQ_LIB}${JQ_FILTER_JSON}"
}

# The newest verdict among the records.
#
# Prints "<state>\t<head>\t<author>\t<association>\t<outcome>\t<important>",
# where the state is one of
#   none      — no record carries a verdict marker at all
#   unbound   — a verdict exists but its marker names no head
#   malformed — a verdict names something that is not a full 40-character SHA
#   ok        — the verdict names <head>
# The newest record wins: the newest timestamp, and among equal timestamps
# the later record. A record without a timestamp never beats a timestamped
# one. A verdict only counts when it comes from an account that collaborates
# with the repository; when no such account has posted one, the newest
# verdict of any author is used, so that the check never goes green merely
# because it declined to read the only verdict there is.
select_verdict() {
    awk -F'\t' '
        function trusted(a) {
            return (a == "OWNER" || a == "MEMBER" || a == "COLLABORATOR")
        }
        BEGIN { FS = "\t"; n = 0 }
        $4 == "none" { next }
        {
            n++
            ts[n] = $1; who[n] = $2; assoc[n] = $3; st[n] = $4; hd[n] = $5
            oc[n] = $6; im[n] = $7
        }
        END {
            has_trusted = 0
            for (i = 1; i <= n; i++) if (trusted(assoc[i])) has_trusted = 1
            best = 0
            for (i = 1; i <= n; i++) {
                if (has_trusted && !trusted(assoc[i])) continue
                if (best == 0) { best = i; continue }
                if (ts[i] != ts[best]) {
                    if (ts[i] == "-") continue
                    if (ts[best] != "-" && ts[i] < ts[best]) continue
                }
                best = i
            }
            if (best == 0) { print "none\t-\t-\t-\t-\t-"; exit 0 }
            print st[best] "\t" hd[best] "\t" who[best] "\t" assoc[best] "\t" oc[best] "\t" im[best]
        }
    '
}

RECORDS=$(fetch_records) || exit 2

if ! SELECTED=$(printf '%s\n' "$RECORDS" | select_verdict); then
    echo "check-verdict-head: could not parse the PR's comments (the parser failed)" >&2
    exit 2
fi

STATE=$(printf '%s\n' "$SELECTED" | cut -f1)
VERDICT_HEAD=$(printf '%s\n' "$SELECTED" | cut -f2)
VERDICT_AUTHOR=$(printf '%s\n' "$SELECTED" | cut -f3)
VERDICT_ASSOC=$(printf '%s\n' "$SELECTED" | cut -f4)
VERDICT_OUTCOME=$(printf '%s\n' "$SELECTED" | cut -f5)
VERDICT_IMPORTANT=$(printf '%s\n' "$SELECTED" | cut -f6)

if [ "$VERDICT_AUTHOR" = "-" ]; then
    AUTHOR_NOTE="(author unknown)"
elif [ "$VERDICT_ASSOC" = "OWNER" ] || [ "$VERDICT_ASSOC" = "MEMBER" ] || [ "$VERDICT_ASSOC" = "COLLABORATOR" ]; then
    AUTHOR_NOTE="(posted by $VERDICT_AUTHOR — $VERDICT_ASSOC)"
else
    AUTHOR_NOTE="(posted by $VERDICT_AUTHOR — not a collaborator with the repository)"
fi

if [ "$STATE" = "none" ]; then
    if [ "$REQUIRE_OUTCOME" = "1" ]; then
        echo "check-verdict-head: FAIL — no factory-review verdict on this PR."
        echo "  The merge gate asks whether this PR may merge. A PR with no verdict"
        echo "  has not been certified merge-ready, so the gate cannot pass it:"
        echo "  passing on silence would turn the check green for exactly the PRs"
        echo "  nobody reviewed. Run the review on this head."
        exit 1
    fi
    echo "check-verdict-head: OK — no factory-review verdict on this PR; nothing to verify."
    exit 0
fi

if [ "$STATE" = "unbound" ]; then
    echo "check-verdict-head: FAIL — a factory-review verdict exists but names no head."
    echo "  $AUTHOR_NOTE"
    echo "  A verdict that names no head certifies nothing: it cannot be checked"
    echo "  against a head, so it cannot support a merge-ready claim."
    echo "  Re-run the review on the current head so the marker names it."
    exit 1
fi

if [ "$STATE" = "malformed" ]; then
    echo "check-verdict-head: FAIL — the verdict's head= value is not a full 40-character SHA."
    echo "  $AUTHOR_NOTE"
    echo "  A verdict that names no usable head certifies nothing: it cannot be checked"
    echo "  against a head, so it cannot support a merge-ready claim."
    echo "  Re-run the review on the current head so the marker names it."
    exit 1
fi

verdict_head=$(printf '%s' "$VERDICT_HEAD" | tr '[:upper:]' '[:lower:]')
pr_head=$(printf '%s' "$PR_HEAD" | tr '[:upper:]' '[:lower:]')

if [ "$verdict_head" != "$pr_head" ]; then
    echo "check-verdict-head: FAIL — the verdict names $VERDICT_HEAD but the head is $PR_HEAD."
    echo "  $AUTHOR_NOTE"
    echo "  A fix push invalidates the verdict: re-run the review passes on the current"
    echo "  head and post the updated verdict naming $PR_HEAD before claiming merge-readiness."
    exit 1
fi

# The verdict is current. In the default mode that answers the whole question
# and the check passes; the question asked there is staleness. The merge gate
# asks one more: does this verdict say the PR may merge? A current verdict can
# still be a not-merge-ready one, or one carrying open Important findings, and
# neither may be shown as a green merge gate. Every field the gate reads is
# checked fail-closed: a verdict that declares nothing cannot certify anything.
if [ "$REQUIRE_OUTCOME" = "1" ]; then
    if [ -z "$VERDICT_OUTCOME" ] || [ "$VERDICT_OUTCOME" = "-" ]; then
        echo "check-verdict-head: FAIL — the verdict declares no outcome."
        echo "  $AUTHOR_NOTE"
        echo "  The marker names the head but omits outcome=, so it says nothing about"
        echo "  merge-readiness. The gate fails closed: a verdict that declares nothing"
        echo "  cannot certify that the PR may merge. Re-run the review so the marker"
        echo "  carries outcome=merge-ready or outcome=not-merge-ready."
        exit 1
    fi

    if [ "$VERDICT_OUTCOME" = "invalid" ]; then
        echo "check-verdict-head: FAIL — the verdict's outcome= is not a legal value."
        echo "  $AUTHOR_NOTE"
        echo "  outcome= must be merge-ready or not-merge-ready; a value the gate does"
        echo "  not recognise cannot be trusted to mean either. Re-run the review so the"
        echo "  marker carries a legal outcome."
        exit 1
    fi

    if [ -z "$VERDICT_IMPORTANT" ] || [ "$VERDICT_IMPORTANT" = "-" ] || [ "$VERDICT_IMPORTANT" = "invalid" ]; then
        echo "check-verdict-head: FAIL — the verdict's important= is missing or not a count."
        echo "  $AUTHOR_NOTE"
        echo "  The gate reads important= to learn whether Important findings are open."
        echo "  A marker that omits it, or makes it unreadable, cannot prove that none"
        echo "  are, so the gate fails closed. Re-run the review so the marker carries"
        echo "  important=<count>."
        exit 1
    fi

    if [ "$VERDICT_OUTCOME" = "not-merge-ready" ]; then
        echo "check-verdict-head: FAIL — the verdict says outcome=not-merge-ready."
        echo "  $AUTHOR_NOTE"
        echo "  The verdict is current, so it is not stale; it concludes the PR may not"
        echo "  merge. The gate reports that conclusion instead. Address the blocking"
        echo "  findings and re-run the review to clear it."
        exit 1
    fi

    if [ "$VERDICT_IMPORTANT" -gt 0 ] 2>/dev/null; then
        echo "check-verdict-head: FAIL — the verdict reports $VERDICT_IMPORTANT open Important finding(s)."
        echo "  $AUTHOR_NOTE"
        echo "  An Important finding blocks a merge, so a verdict counting one cannot"
        echo "  certify merge-readiness even when its outcome= says merge-ready: the"
        echo "  count is the fact, the outcome string only summarises it. Resolve the"
        echo "  findings and re-run the review."
        exit 1
    fi

    echo "check-verdict-head: OK — the verdict names the current head and declares merge-ready."
    echo "  $AUTHOR_NOTE"
    exit 0
fi

echo "check-verdict-head: OK — the verdict names the current head ($PR_HEAD)."
echo "  $AUTHOR_NOTE"
exit 0
