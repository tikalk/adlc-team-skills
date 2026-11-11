#!/usr/bin/env bash
# verify-recurrence.sh — validate factory-review verdict evidence, append live-head
# observations to the recurrence ledger.
#
# v1 evidence rule: only an observation meeting ALL conditions enters the
# validated ledger: marker head= parsed from the marker region only, exactly
# 40 hex chars, equal to the independently fetched live PR head SHA, newest
# qualifying collaborator verdict for that head, run corroborated by the run
# home, and valid finding-lines. Everything else is diagnostic/rejected.
#
# Layer M (marker, machine-readable): sole source of run/iter/head.
# Layer F (findings): sole source of (pass, check-item); exact syntax only:
#   - [ ] pass:<slug> check:<slug> | <one-line text>
# Layer P (prose): explanatory only, never compared, except an explicit
# structured pass:<slug> check:<slug> pair in prose with no matching Layer F
# pair, which rejects that pair (finding-diverged).
#
# Commands:
#   run       --repo R --pr N --run-root P --ledger L [--reject-log PATH]
#   ingest    --repo R --pr N --run-root P            (diagnostic, no writes)
#   aggregate --ledger L --candidates F --fixture-payloads D --repo R --pr N --run-root P --allow-fixture
#   retire    --ledger L --key K --reason R            (explicit human resolution)
#   recurrence-view --ledger L
#
# run fetches live GitHub evidence itself and never reads candidate files.
# aggregate is fixture-only: it revalidates every candidate row against
# fixture payloads (pr.json, comments.json, reviews.json) and prints
# VALID rows (appended to the given ledger under lock) plus REJECT rows.
# retire removes exactly the rows whose (PR,pass,check-item,iter) key matches.
# recurrence-view prints (pass,check-item) pairs observed on >= 2 distinct PRs.
#
# Commands mirror the aggregate ORIG rule: duplicate identity is the
# recurrence key (PR,pass,check-item,iter) plus provenance columns
# (verdict-head case-folded, run, author, assoc, verified-how, standing,
# tier, note); verified-at is confirmation metadata and excluded (ADR-448).
# Re-runs of the same observation report DUPLICATE, leave ledger bytes
# unchanged, and never restamp the stored row. Any other provenance
# difference on the same key fails closed (exit 2, ledger unchanged).
#
# Exit codes: 0 = completed (validation rejections are rows, not failures).
# 2 = infra error (lock-held, fetch failed, fixture misuse, provenance abort).
#
# No remote Git ref lock is used. Production serializes cross-machine via the
# repo's strict-required-checks merge flow (stale PRs cannot merge) plus the
# single-active-writer operational rule. Local mutation is serialized with
# flock(1) on a sidecar lock and committed via temp-file + atomic mv.
#
# EVERYTHING THAT COMES BACK FROM GITHUB IS UNTRUSTED. jq extracts only the
# fields the validator needs (timestamp, author, association, marker run/iter/
# head). A body can neither create a record nor choose its position.

set -u
export LC_ALL=C

CMD="${1:-}"
if [ -n "$CMD" ]; then shift; fi

REPO=""; PR=""; RUN_ROOT=""; LEDGER=""; REJECT_LOG=""; CANDIDATES=""
ALLOW_FIXTURE=0; RETIRE_KEY=""; RETIRE_REASON=""; FIXTURE_PAYLOADS=""; STARTED_SENTINEL=""; PROCEED_SENTINEL=""
LEDGER_HEADER="PR	pass	check-item	verdict-head	run	iter	author	assoc	verified-how	verified-at	standing	tier	note"
LOCK_TIMEOUT="${VERIFY_RECURRENCE_LOCK_TIMEOUT:-60}"

usage_error() { echo "verify-recurrence: $*" >&2; exit 2; }

require_value() {
    if [ "${2:-}" = "" ]; then usage_error "$1 requires a value"; fi
}

case "$CMD" in
run|ingest|aggregate|retire|recurrence-view) ;;
*) usage_error "usage: verify-recurrence.sh {run|ingest|aggregate|retire|recurrence-view} ..." ;;
esac

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo) require_value "$1" "${2:-}"; REPO="$2"; shift 2 ;;
        --pr) require_value "$1" "${2:-}"; PR="$2"; shift 2 ;;
        --run-root) require_value "$1" "${2:-}"; RUN_ROOT="$2"; shift 2 ;;
        --ledger) require_value "$1" "${2:-}"; LEDGER="$2"; shift 2 ;;
        --reject-log) require_value "$1" "${2:-}"; REJECT_LOG="$2"; shift 2 ;;
        --candidates) require_value "$1" "${2:-}"; CANDIDATES="$2"; shift 2 ;;
        --fixture-payloads) require_value "$1" "${2:-}"; FIXTURE_PAYLOADS="$2"; shift 2 ;;
        --started-sentinel) require_value "$1" "${2:-}"; STARTED_SENTINEL="$2"; shift 2 ;;
        --proceed-sentinel) require_value "$1" "${2:-}"; PROCEED_SENTINEL="$2"; shift 2 ;;
        --key) require_value "$1" "${2:-}"; RETIRE_KEY="$2"; shift 2 ;;
        --reason) require_value "$1" "${2:-}"; RETIRE_REASON="$2"; shift 2 ;;
        --allow-fixture) ALLOW_FIXTURE=1; shift ;;
        --help|-h) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        --fixture-comments|--fixture-reviews|--fixture-pr)
            usage_error "$1 was removed; use --fixture-payloads <dir> with aggregate --allow-fixture" ;;
        *) usage_error "unknown argument '$1'" ;;
    esac
done

case "$CMD" in
run)
    [ -n "$REPO" ] || usage_error "--repo required for run"
    [ -n "$PR" ] || usage_error "--pr required for run"
    [ -n "$RUN_ROOT" ] || usage_error "--run-root required for run"
    [ -n "$LEDGER" ] || usage_error "--ledger required for run"
    ;;
ingest)
    [ -n "$REPO" ] || usage_error "--repo required for ingest"
    [ -n "$PR" ] || usage_error "--pr required for ingest"
    [ -n "$RUN_ROOT" ] || usage_error "--run-root required for ingest"
    ;;
aggregate)
    [ "$ALLOW_FIXTURE" = "1" ] || usage_error "aggregate is fixture-only; pass --allow-fixture"
    [ -n "$LEDGER" ] || usage_error "--ledger required for aggregate"
    [ -n "$CANDIDATES" ] || usage_error "--candidates required for aggregate"
    [ -n "$FIXTURE_PAYLOADS" ] || usage_error "--fixture-payloads <dir> required for aggregate"
    [ -n "$REPO" ] || usage_error "--repo required for aggregate"
    [ -n "$PR" ] || usage_error "--pr required for aggregate"
    [ -n "$RUN_ROOT" ] || usage_error "--run-root required for aggregate"
    ;;
retire)
    [ -n "$LEDGER" ] || usage_error "--ledger required for retire"
    [ -n "$RETIRE_KEY" ] || usage_error "--key required for retire"
    case "$RETIRE_KEY" in
        *$'\t'*) ;;
        *) usage_error "--key must be TAB-separated PR,pass,check-item,iter" ;;
    esac
    _kfields=$(printf '%s' "$RETIRE_KEY" | awk -F'\t' '{print NF}')
    [ "$_kfields" = "4" ] || usage_error "--key must be TAB-separated PR,pass,check-item,iter"
    [ -n "$RETIRE_REASON" ] || usage_error "--reason required for retire"
    ;;
recurrence-view)
    [ -n "$LEDGER" ] || usage_error "--ledger required for recurrence-view"
    ;;
esac

require_jq() {
    command -v jq >/dev/null 2>&1 || { echo "verify-recurrence: jq is required" >&2; exit 2; }
}

gh_json() {
    _endpoint="$1"; _label="$2"
    _err=$(mktemp) || { echo "verify-recurrence: cannot create temp file" >&2; exit 2; }
    _out=$(gh api "$_endpoint" --paginate 2>"$_err"); _rc=$?
    if [ "$_rc" -ne 0 ]; then
        echo "verify-recurrence: could not read $_label (gh exited $_rc):" >&2
        sed 's/^/  /' "$_err" >&2; rm -f "$_err"; exit 2
    fi
    rm -f "$_err"
    printf '%s\n' "$_out"
}
JQ_LIB=$(cat <<'JQEOF'
def iso_ts: if test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") then . else "-" end;
def trim_ws: sub("^[[:space:]]+"; "");
def marker_regions:
  [ . | split("<!--")[1:][]
    | select(contains("-->"))
    | (trim_ws | split("-->")[0]) as $seg
    | select($seg | startswith("factory-review:step=review"))
    | $seg ];
def field($f):
  ( [ marker_regions[]
      | split(" ")[] | select(startswith($f + "=")) | .[($f | length) + 1:] ]
    | .[0] // "-" );
def verdict_record:
  if (test("factory-review:step=review") | not) then {state: "none", head: "-", run: "-", iter: "-"}
  else
    (field("head")) as $h
    | (field("run")) as $r
    | (field("iter")) as $it
    | if ($h | test("^[0-9a-fA-F]{40}$")) then {state: "ok", head: $h, run: $r, iter: $it}
      elif ($h != "-") then {state: "malformed", head: "-", run: $r, iter: $it}
      else {state: "unbound", head: "-", run: $r, iter: $it}
      end
  end;
JQEOF
)
JQ_FILTER_JSON=$(cat <<'JQEOF'
.[] | ((.submitted_at // .created_at // "") | iso_ts) as $ts
     | ((.user.login // "") | gsub("[^A-Za-z0-9._-]"; "")) as $who
     | ((.author_association // "NONE") | gsub("[^A-Za-z]"; "")) as $assoc
     | ((.body // "") | verdict_record) as $rec
     | "\($ts)\t\($who)\t\($assoc)\t\($rec.state)\t\($rec.head)\t\($rec.run)\t\($rec.iter)"
JQEOF
)
norm_slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[ _]\+/-/g' -e 's/[^a-z0-9-]//g' -e 's/^-\+//' -e 's/-\+$//'; }

parse_findings() {
    # Prints one normalized "pass<TAB>check" per valid line; malformed lines
    # go to stderr as MALFORMED and are ignored when valid lines remain.
    _f="$1"
    _tmp=$(mktemp) || { echo "verify-recurrence: cannot create temp file" >&2; return 2; }
    _rc=0
    awk '
        /^-[[:space:]]+\[[ xX]\][[:space:]]+pass:/ {
            line = $0
            sub(/^-[[:space:]]+\[[ xX]\][[:space:]]+/, "", line)
            if (match(line, /pass:[^[:space:]|]+[[:space:]]+check:[^[:space:]|]+/)) {
                print substr(line, RSTART, RLENGTH)
            } else { print "MALFORMED:" line > "/dev/stderr"; bad++ }
            next
        }
    ' "$_f" > "$_tmp" 2>"$_tmp.err"
    _rc=$?
    if [ -s "$_tmp.err" ]; then sed 's/^/verify-recurrence: malformed finding line: /' "$_tmp.err" >&2; fi
    if [ ! -s "$_tmp" ]; then
        grep -q . "$_tmp.err" 2>/dev/null && rm -f "$_tmp" "$_tmp.err" && return 1
        rm -f "$_tmp" "$_tmp.err" && return 1
    fi
    cat "$_tmp"; rm -f "$_tmp" "$_tmp.err"
    return 0
}

finding_pairs() {
    # finding_pairs <file>: normalized pass<TAB>check lines, deduped. rc 1 = none valid.
    parse_findings "$1" | while IFS= read -r _ln; do
        _p=$(printf '%s' "$_ln" | sed -n 's/.*pass:\([^ |]*\).*/\1/p'); _c=$(printf '%s' "$_ln" | sed -n 's/.*check:\([^ |]*\).*/\1/p')
        printf '%s\t%s\n' "$(norm_slug "$_p")" "$(norm_slug "$_c")"
    done | awk -F'\t' '$1 != "" && $2 != ""' | LC_ALL=C sort -u || return 1
}

prose_struct_pairs() {
    # Layer P: explicit structured pairs in comment prose (marker regions
    # stripped). Empty output = none. Never evidence by itself.
    [ -f "$1" ] || return 0
    sed -e 's/<!--[^>]*-->//g' "$1" 2>/dev/null \
        | grep -o -E 'pass:[A-Za-z0-9_.-]+[[:space:]]+check:[A-Za-z0-9_.-]+' 2>/dev/null \
        | while IFS= read -r _sp; do
            _p=$(printf '%s' "$_sp" | sed -n 's/.*pass:\([^ ]*\).*/\1/p')
            _c=$(printf '%s' "$_sp" | sed -n 's/.*check:\([^ ]*\).*/\1/p')
            _np=$(norm_slug "$_p"); _nc=$(norm_slug "$_c")
            [ -n "$_np" ] && [ -n "$_nc" ] && printf '%s\t%s\n' "$_np" "$_nc"
        done | LC_ALL=C sort -u || true
}

live_head_for() {
    _repo="$1"; _pr="$2"
    _prjson=$(gh_json "repos/$_repo/pulls/$_pr" "the PR"); 
    printf '%s' "$_prjson" | jq -r '.head.sha // empty' | head -1
}

fetch_marker_records() {
    _repo="$1"; _pr="$2"
    _c=$(gh_json "repos/$_repo/issues/$_pr/comments" "the PR issue comments")
    _r=$(gh_json "repos/$_repo/pulls/$_pr/reviews" "the PR review bodies")
    printf '%s\n%s\n' "$_c" "$_r" | jq -r "${JQ_LIB}${JQ_FILTER_JSON}"
}

utc_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
validate_one() {
    _ts="$1"; _who="$2"; _assoc="$3"; _state="$4"; _mhead="$5"; _run="$6"; _iter="$7"; _live="$8"
    _lc_live=$(printf '%s' "$_live" | tr '[:upper:]' '[:lower:]')
    _lc_m=$(printf '%s' "$_mhead" | tr '[:upper:]' '[:lower:]')
    case "$_assoc" in OWNER|MEMBER|COLLABORATOR) ;; *) printf 'REJECT\t%s\t%s\t%s\tuntrusted-author\n' "$_mhead" "$_run" "$_iter"; return 0 ;; esac
    case "$_state" in
        malformed) printf 'REJECT\t%s\t%s\t%s\tmalformed-head\n' "$_mhead" "$_run" "$_iter"; return 0 ;;
        unbound|none) printf 'REJECT\t%s\t%s\t%s\tno-marker-head\n' "$_mhead" "$_run" "$_iter"; return 0 ;;
    esac
    if [ "$_lc_m" != "$_lc_live" ]; then printf 'REJECT\t%s\t%s\t%s\tstale-head\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    _brief="$RUN_ROOT/runs/$_run/brief.md"
    if [ ! -f "$_brief" ]; then printf 'REJECT\t%s\t%s\t%s\trun-unresolvable\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    _b_repo=$(grep -E '^review-target-repo:[[:space:]]*' "$_brief" | head -1 | sed 's/^review-target-repo:[[:space:]]*//')
    _b_pr=$(grep -E '^review-target-pr:[[:space:]]*' "$_brief" | head -1 | sed 's/^review-target-pr:[[:space:]]*//')
    _b_head=$(grep -E '^reviewed-head:[[:space:]]*' "$_brief" | head -1 | sed 's/^reviewed-head:[[:space:]]*//')
    if [ -z "$_b_repo" ] || [ -z "$_b_pr" ] || [ -z "$_b_head" ]; then printf 'REJECT\t%s\t%s\t%s\trun-unresolvable\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    if [ "$_b_repo" != "$REPO" ] || [ "$_b_pr" != "$PR" ]; then printf 'REJECT\t%s\t%s\t%s\trun-mismatch\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    _lc_b=$(printf '%s' "$_b_head" | tr '[:upper:]' '[:lower:]')
    if [ "$_lc_b" != "$_lc_live" ]; then printf 'REJECT\t%s\t%s\t%s\trun-mismatch\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    _findings="$RUN_ROOT/runs/$_run/scratchpads/review-findings.txt"
    if [ ! -f "$_findings" ]; then printf 'REJECT\t%s\t%s\t%s\tfinding-unparseable\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    if ! _pairs_raw=$(parse_findings "$_findings" 2>/dev/null); then
        printf 'REJECT\t%s\t%s\t%s\tfinding-unparseable\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    if [ -z "$_pairs_raw" ]; then printf 'REJECT\t%s\t%s\t%s\tfinding-unparseable\n' "$_mhead" "$_run" "$_iter"; return 0; fi
    printf 'OK\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_mhead" "$_run" "$_iter" "$_who" "$_assoc" "$_ts"
}

pairs_for_run() {
    # All valid normalized Layer F pairs for a run (no prose comparison).
    _run="$1"
    finding_pairs "$RUN_ROOT/runs/$_run/scratchpads/review-findings.txt" || return 1
}
emit_rows_for_winner() {
    _mhead="$1"; _run="$2"; _iter="$3"; _who="$4"; _assoc="$5"; _verified_at="$6"
    _lc_m=$(printf '%s' "$_mhead" | tr '[:upper:]' '[:lower:]')
    pairs_for_run "$_run" | while IFS="$(printf '\t')" read -r _pass _check; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$PR" "$_pass" "$_check" "$_lc_m" "$_run" "$_iter" "$_who" "$_assoc" \
            "live-head" "$_verified_at" "live-head-at-verification" "" "verified live-head $_mhead"
    done
}

_fetch_prose_bodies() {
    # Prints raw comment/review bodies (Layer P source). Untrusted content.
    _repo="$1"; _pr="$2"
    _c=$(gh_json "repos/$_repo/issues/$_pr/comments" "the PR issue comments")
    _r=$(gh_json "repos/$_repo/pulls/$_pr/reviews" "the PR review bodies")
    printf '%s\n%s\n' "$_c" "$_r" | jq -r '.[] | (.body // "")' 2>/dev/null || true
}

_collect_diverged() {
    # Prints DIV<TAB>pass<TAB>check for structured prose pairs with no
    # matching Layer F pair. Unrelated valid F pairs are unaffected.
    _run="$1"
    _f="$RUN_ROOT/runs/$_run/scratchpads/review-findings.txt"
    _fp=$(finding_pairs "$_f") || return 0
    _pf=$(mktemp) || return 2
    prose_struct_pairs "${_PROSE_FILE:-/dev/null}" > "$_pf" 2>/dev/null || true
    while IFS="$(printf '\t')" read -r _pp _pc; do
        [ -z "${_pp:-}" ] && continue
        if ! printf '%s\n' "$_fp" | grep -qFx "$(printf '%s\t%s' "$_pp" "$_pc")"; then
            printf 'DIV\t%s\t%s\n' "$_pp" "$_pc"
        fi
    done < "$_pf"
    rm -f "$_pf"
}

cmd_ingest_or_run() {
    _mode="$1"
    _live=$(live_head_for "$REPO" "$PR") || exit 2
    if ! printf '%s' "$_live" | grep -qE '^[0-9a-fA-F]{40}$'; then echo "verify-recurrence: live PR head unreadable" >&2; exit 2; fi
    _verified_at=$(utc_now)
    _records=$(fetch_marker_records "$REPO" "$PR") || exit 2
    _ok_line=$(printf '%s\n' "$_records" | awk -F'\t' -v live="$_live" '
        function trusted(a){return (a=="OWNER"||a=="MEMBER"||a=="COLLABORATOR")}
        function lower(s){out="";for(i=1;i<=length(s);i++){c=substr(s,i,1);n=index("ABCDEF",c);out=out (n?substr("abcdef",n,1):c)}return out}
        $4=="ok" && trusted($3) && lower($5)==lower(live) {n++; ts[n]=$1; who[n]=$2; as[n]=$3; st[n]=$4; hd[n]=$5; rn[n]=$6; it[n]=$7}
        END{if(!n)exit 1; best=1; for(i=2;i<=n;i++){if(ts[i]!="-"&&(ts[best]=="-"||ts[i]>ts[best]))best=i} print ts[best]"\t"who[best]"\t"as[best]"\t"st[best]"\t"hd[best]"\t"rn[best]"\t"it[best]}')
    _cand_tmp=$(mktemp); _rej_tmp=$(mktemp)
    _PROSE_FILE=""; export _PROSE_FILE
    if [ "$_mode" = "ingest" ] || [ "$_mode" = "run" ]; then
        _PROSE_FILE=$(mktemp)
        _fetch_prose_bodies "$REPO" "$PR" > "$_PROSE_FILE" 2>/dev/null || true
    fi
    printf '%s\n' "$_records" | while IFS="$(printf '\t')" read -r _ts _who _assoc _state _mhead _run _iter; do
        [ -z "${_ts:-}" ] && continue
        validate_one "$_ts" "$_who" "$_assoc" "$_state" "$_mhead" "$_run" "$_iter" "$_live"
    done | while IFS="$(printf '\t')" read -r _kind _a _b _c _d _e _f; do
        if [ "$_kind" = "REJECT" ]; then printf 'REJECT\t%s\t%s\t%s\t-\t-\t-\t-\t-\t%s\n' "$PR" "$_a" "$_b" "$_d" >> "$_rej_tmp"; fi
    done
    printf '%s\n' "$_records" | while IFS="$(printf '\t')" read -r _ts _who _assoc _state _mhead _run _iter; do
        [ -z "${_ts:-}" ] && continue
        _lc_m=$(printf '%s' "$_mhead" | tr '[:upper:]' '[:lower:]'); _lc_l=$(printf '%s' "$_live" | tr '[:upper:]' '[:lower:]')
        if [ "$_lc_m" != "$_lc_l" ] && [ "$_state" = "ok" ]; then printf 'REJECT\t%s\t%s\t%s\t-\t-\t-\t-\t-\thead-interval-unproven\n' "$PR" "$_mhead" "$_run" >> "$_rej_tmp"; fi
    done
    if [ -n "$_ok_line" ]; then
        _w_ts=$(printf '%s' "$_ok_line" | cut -f1); _w_who=$(printf '%s' "$_ok_line" | cut -f2); _w_as=$(printf '%s' "$_ok_line" | cut -f3)
        _w_st=$(printf '%s' "$_ok_line" | cut -f4); _w_hd=$(printf '%s' "$_ok_line" | cut -f5); _w_rn=$(printf '%s' "$_ok_line" | cut -f6); _w_it=$(printf '%s' "$_ok_line" | cut -f7)
        _v=$(validate_one "$_w_ts" "$_w_who" "$_w_as" "$_w_st" "$_w_hd" "$_w_rn" "$_w_it" "$_live")
        _vk=$(printf '%s' "$_v" | cut -f1)
        if [ "$_vk" = "OK" ]; then
            emit_rows_for_winner "$_w_hd" "$_w_rn" "$_w_it" "$_w_who" "$_w_as" "$_verified_at" > "$_cand_tmp"
            _div_tmp=$(mktemp)
            _PROSE_FILE="$_PROSE_FILE" _collect_diverged "$_w_rn" > "$_div_tmp" 2>/dev/null || true
            if [ -s "$_div_tmp" ]; then
                while IFS="$(printf '\t')" read -r _dk _dp _dc; do
                    [ -z "${_dp:-}" ] && continue
                    printf 'REJECT\t%s\t%s\t%s\t%s\t%s\t-\t-\t-\tfinding-diverged\n' "$PR" "$_w_hd" "$_w_rn" "$_dp" "$_dc" >> "$_rej_tmp"
                done < "$_div_tmp"
                _keep=$(mktemp)
                while IFS="$(printf '\t')" read -r _cr _cp _cc _ch _cru _ci _cw _ca _chw _cva _cst _ct _cn; do
                    [ -z "${_cr:-}" ] && continue
                    if ! grep -qFx "$(printf 'DIV\t%s\t%s' "$_cp" "$_cc")" "$_div_tmp" 2>/dev/null; then
                        printf '%s\n' "$_cr	$_cp	$_cc	$_ch	$_cru	$_ci	$_cw	$_ca	$_chw	$_cva	$_cst	$_ct	$_cn" >> "$_keep"
                    fi
                done < "$_cand_tmp"
                mv "$_keep" "$_cand_tmp"
            fi
            rm -f "$_div_tmp"
        else
            _rr=$(printf '%s' "$_v" | cut -f5)
            printf 'REJECT\t%s\t%s\t%s\t-\t-\t-\t-\t-\t%s\n' "$PR" "$_w_hd" "$_w_rn" "$_rr" >> "$_rej_tmp"
        fi
    fi
    if [ -n "${_PROSE_FILE:-}" ]; then rm -f "$_PROSE_FILE"; fi
    if [ "$_mode" = "ingest" ]; then
        echo "--- candidates (untrusted worklist, never production evidence) ---"
        cat "$_cand_tmp"
        echo "--- rejects ---"
        cat "$_rej_tmp"
        rm -f "$_cand_tmp" "$_rej_tmp"; return 0
    fi
    if [ ! -f "$LEDGER" ]; then printf '%s\n' "$LEDGER_HEADER" > "$LEDGER" || exit 2; fi
    _lock="$LEDGER.lock"
    _dup_tmp=$(mktemp) || exit 2
    (
        _lfd=9
        eval "exec $_lfd>\"$_lock\""
        if ! command -v flock >/dev/null 2>&1; then
            echo "verify-recurrence: flock(1) is required but unavailable; refusing ledger write" >&2
            exit 2
        fi
        if ! flock -w "$LOCK_TIMEOUT" "$_lfd"; then echo "verify-recurrence: ledger lock timeout" >&2; exit 2; fi
        _cur=$(mktemp) || exit 2
        cp "$LEDGER" "$_cur" || { rm -f "$_cur"; exit 2; }
        _conflict=0
        : > "$_dup_tmp" || exit 2
        while IFS= read -r _row; do
            [ -z "$_row" ] && continue
            _key=$(printf '%s' "$_row" | cut -f1-4,6)
            _pkey=$(printf '%s' "$_row" | awk -F'\t' '{print $1"\t"$2"\t"$3"\t"$6}')
            grep -qFx -- "$_row" "$_cur"; _gres=$?
            if [ "$_gres" -eq 0 ]; then printf 'DUPLICATE\t%s\n' "$_row" >> "$_dup_tmp"; continue; fi
            if [ "$_gres" -ne 1 ]; then echo "verify-recurrence: ledger read error during idempotency check" >&2; rm -f "$_cur" "$_cand_tmp" "$_rej_tmp" "$_dup_tmp"; exit 2; fi
            # ADR-448: identity is (key + provenance); verified-at is metadata.
            # A same-observation rerun with a fresh timestamp is a duplicate,
            # not a conflict. Any other provenance difference fails closed.
            _idem=$(awk -F'\t' -v k="$_pkey" '
                NR>1 {
                    kk=$1"\t"$2"\t"$3"\t"$6
                    if (kk==k) {
                        prov=$4"\t"$5"\t"$7"\t"$8"\t"$9"\t"$11"\t"$12"\t"$13
                        print prov
                    }
                }' "$_cur")
            if [ -n "$_idem" ]; then
                _row_prov=$(printf '%s' "$_row" | awk -F'\t' '{print $4"\t"$5"\t"$7"\t"$8"\t"$9"\t"$11"\t"$12"\t"$13}')
                _idem_lc=$(printf '%s' "$_idem" | cut -f1 | tr '[:upper:]' '[:lower:]')
                _row_lc=$(printf '%s' "$_row_prov" | cut -f1 | tr '[:upper:]' '[:lower:]')
                _idem_rest=$(printf '%s' "$_idem" | cut -f2-)
                _row_rest=$(printf '%s' "$_row_prov" | cut -f2-)
                if [ "$_idem_lc" = "$_row_lc" ] && [ "$_idem_rest" = "$_row_rest" ]; then
                    printf 'DUPLICATE\t%s\n' "$_row" >> "$_dup_tmp"; continue
                fi
                echo "verify-recurrence: provenance conflict for $_pkey; use retire" >&2; _conflict=1; break
            fi
            printf '%s\n' "$_row" >> "$_cur"
        done < "$_cand_tmp"
        if [ "$_conflict" = "1" ]; then rm -f "$_cur" "$_cand_tmp" "$_rej_tmp" "$_dup_tmp"; exit 2; fi
        mv "$_cur" "$LEDGER" || exit 2
    )
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
        rm -f "$_cand_tmp" "$_rej_tmp"
        exit $_rc
    fi
    if [ -s "$_dup_tmp" ]; then
        echo "--- duplicates (re-confirmed, ledger unchanged) ---"
        cat "$_dup_tmp"
    fi
    cat "$_cand_tmp"
    echo "--- rejects ---"
    cat "$_rej_tmp"
    if [ -n "$REJECT_LOG" ]; then cat "$_rej_tmp" > "$REJECT_LOG" 2>/dev/null || true; fi
    rm -f "$_cand_tmp" "$_rej_tmp" "$_dup_tmp"
    exit $_rc
}
cmd_recurrence_view() {
    [ -f "$LEDGER" ] || usage_error "ledger not found"
    awk -F'\t' 'NR>1 && NF>=3 {key=$2"\t"$3; prs[key]=prs[key] " " $1; n=split(prs[key],a," ");
        delete seen; c=0; for(i in a){if(a[i]!="" && !seen[a[i]]++){c++}}
        cnt[key]=c}
        END{for(k in cnt) if(cnt[k]>=2) print "RECURRING\t" k "\tprs:" cnt[k]}' "$LEDGER" | LC_ALL=C sort
}

_append_rows_locked() {
    _src="$1"
    _mode="${2:-rows}"
    _outcome="${3:-}"
    [ -f "$LEDGER" ] || printf '%s\n' "$LEDGER_HEADER" > "$LEDGER" || exit 2
    _lock="$LEDGER.lock"
    (
        _lfd=9
        eval "exec $_lfd>\"$_lock\""
        if ! command -v flock >/dev/null 2>&1; then
            echo "verify-recurrence: flock(1) is required but unavailable; refusing ledger write" >&2
            exit 2
        fi
        if ! flock -w "$LOCK_TIMEOUT" "$_lfd"; then echo "verify-recurrence: ledger lock timeout" >&2; exit 2; fi
        if [ "${CMD:-}" = "aggregate" ] && [ -n "${STARTED_SENTINEL:-}" ]; then : > "$STARTED_SENTINEL" || exit 2; fi
        if [ "${CMD:-}" = "aggregate" ] && [ -n "${PROCEED_SENTINEL:-}" ]; then
            for _i in $(seq 1 1200); do
                [ -f "$PROCEED_SENTINEL" ] && break
                sleep 0.05
            done
            [ -f "$PROCEED_SENTINEL" ] || { echo "verify-recurrence: proceed sentinel not observed" >&2; exit 2; }
        fi
        _cur=$(mktemp) || exit 2
        cp "$LEDGER" "$_cur" || { rm -f "$_cur"; exit 2; }
        _conflict=0
        _gres=0
        _pend_orig=""
        if [ -n "${_outcome:-}" ]; then : > "$_outcome" || exit 2; fi
        while IFS= read -r _row || [ -n "${_row:-}" ]; do
            [ -z "${_row:-}" ] && continue
            if [ "$_mode" = "aggregate-pairs" ]; then
                case "$_row" in
                    ORIG?*) _pend_orig=$(printf '%s' "$_row" | cut -f2-); continue;;
                esac
                if [ -n "${_pend_orig:-}" ]; then
                    _orig="$_pend_orig"; _pend_orig=""
                    grep -qFx -- "$_orig" "$_cur"; _gres=$?
                    if [ "$_gres" -eq 0 ]; then
                        if [ -n "${_outcome:-}" ]; then printf 'DUPLICATE\t%s\n' "$_orig" >> "$_outcome" || exit 2; fi
                        # Byte-identical original already recorded: the
                        # re-stamped companion row is a re-confirmation, not
                        # a new observation. Check whether the companion
                        # itself is already recorded (e.g. retried aggregate
                        # after a partial run); if so skip, else record the
                        # single re-confirmation marker-free row verbatim is
                        # impossible (re-stamp differs), so suppress the
                        # companion entirely: ledger already has this
                        # observation.
                        continue
                    fi
                    if [ "$_gres" -ne 1 ]; then echo "verify-recurrence: ledger read error during idempotency check" >&2; rm -f "$_cur"; exit 2; fi
                fi
            fi
            _pkey=$(printf '%s' "$_row" | awk -F'\t' '{print $1"\t"$2"\t"$3"\t"$6}')
            grep -qFx -- "$_row" "$_cur"; _gres=$?
            if [ "$_gres" -eq 0 ]; then
                if [ -n "${_outcome:-}" ]; then printf 'DUPLICATE\t%s\n' "$_row" >> "$_outcome" || exit 2; fi
                continue
            fi
            if [ "$_gres" -ne 1 ]; then echo "verify-recurrence: ledger read error during idempotency check" >&2; rm -f "$_cur"; exit 2; fi
            if awk -F'\t' -v k="$_pkey" 'NR>1{kk=$1"\t"$2"\t"$3"\t"$6; if(kk==k){print}}' "$_cur" | grep -q .; then
                echo "verify-recurrence: provenance conflict for $_pkey; use retire" >&2; _conflict=1; break
            fi
            printf '%s\n' "$_row" >> "$_cur"
            if [ -n "${_outcome:-}" ]; then printf 'APPENDED\t%s\n' "$_row" >> "$_outcome" || exit 2; fi
        done < "$_src"
        if [ "$_conflict" = "1" ]; then rm -f "$_cur"; exit 2; fi
        mv "$_cur" "$LEDGER" || exit 2
    )
    return $?
}

cmd_aggregate() {
    [ -f "$CANDIDATES" ] || usage_error "candidates file not found"
    [ -d "$FIXTURE_PAYLOADS" ] || usage_error "fixture payload dir not found (--fixture-payloads)"
    for _f in pr.json comments.json reviews.json; do
        [ -f "$FIXTURE_PAYLOADS/$_f" ] || usage_error "fixture payload missing: $_f"
    done
    _flive=$(jq -r '.head.sha // empty' "$FIXTURE_PAYLOADS/pr.json" | head -1)
    if ! printf '%s' "$_flive" | grep -qE '^[0-9a-fA-F]{40}$'; then
        echo "verify-recurrence: fixture pr.json has no head.sha" >&2; exit 2
    fi
    _fverified_at=$(utc_now)
    _frecords=$(jq -r "${JQ_LIB}${JQ_FILTER_JSON}" "$FIXTURE_PAYLOADS/comments.json" "$FIXTURE_PAYLOADS/reviews.json" 2>/dev/null) || {
        echo "verify-recurrence: cannot parse fixture payloads" >&2; exit 2; }
    _fprose=$(mktemp) || exit 2
    jq -r '.[] | (.body // "")' "$FIXTURE_PAYLOADS/comments.json" "$FIXTURE_PAYLOADS/reviews.json" 2>/dev/null > "$_fprose" || true
    _valid=$(mktemp) || exit 2
    while IFS= read -r _row || [ -n "${_row:-}" ]; do
        case "$_row" in PR*|"" ) continue ;; esac
        _c_pr=$(printf '%s' "$_row" | cut -f1); _c_pass=$(printf '%s' "$_row" | cut -f2)
        _c_check=$(printf '%s' "$_row" | cut -f3); _c_head=$(printf '%s' "$_row" | cut -f4)
        _c_run=$(printf '%s' "$_row" | cut -f5); _c_iter=$(printf '%s' "$_row" | cut -f6)
        _c_how=$(printf '%s' "$_row" | cut -f9)
        _lc_c=$(printf '%s' "$_c_head" | tr '[:upper:]' '[:lower:]')
        _lc_l=$(printf '%s' "$_flive" | tr '[:upper:]' '[:lower:]')
        [ "$_lc_c" = "$_lc_l" ] && [ "$_c_how" = "live-head" ] || { printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; }
        if [ "$_c_pr" != "$PR" ]; then printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; fi
        _hit=$(printf '%s\n' "$_frecords" | awk -F'\t' -v h="$_c_head" -v r="$_c_run" -v it="$_c_iter" '
            function trusted(a){return (a=="OWNER"||a=="MEMBER"||a=="COLLABORATOR")}
            function lower(s){o="";for(i=1;i<=length(s);i++){c=substr(s,i,1);n=index("ABCDEF",c);o=o (n?substr("abcdef",n,1):c)}return o}
            $4=="ok" && trusted($3) && lower($5)==lower(h) && $6==r && $7==it {print $2"\t"$3; f=1}
            END{exit !f}')
        if [ -z "$_hit" ]; then printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; fi
        _brief="$RUN_ROOT/runs/$_c_run/brief.md"
        _b_repo=$(grep -E '^review-target-repo:[[:space:]]*' "$_brief" 2>/dev/null | head -1 | sed 's/^review-target-repo:[[:space:]]*//')
        _b_pr=$(grep -E '^review-target-pr:[[:space:]]*' "$_brief" 2>/dev/null | head -1 | sed 's/^review-target-pr:[[:space:]]*//')
        _b_head=$(grep -E '^reviewed-head:[[:space:]]*' "$_brief" 2>/dev/null | head -1 | sed 's/^reviewed-head:[[:space:]]*//')
        _lc_b=$(printf '%s' "$_b_head" | tr '[:upper:]' '[:lower:]')
        if [ -z "$_b_repo" ] || [ -z "$_b_pr" ] || [ "$_lc_b" != "$_lc_l" ]; then
            printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; fi
        _fp=$(finding_pairs "$RUN_ROOT/runs/$_c_run/scratchpads/review-findings.txt" 2>/dev/null) || {
            printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; }
        if ! printf '%s\n' "$_fp" | grep -qFx "$(printf '%s\t%s' "$_c_pass" "$_c_check")"; then
            printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; fi
        _pp=$(prose_struct_pairs "$_fprose" 2>/dev/null || true)
        _div=0
        while IFS="$(printf '\t')" read -r _q1 _q2; do
            [ -z "${_q1:-}" ] && continue
            if ! printf '%s\n' "$_fp" | grep -qFx "$(printf '%s\t%s' "$_q1" "$_q2")"; then _div=1; break; fi
        done <<PROSEEOF
$_pp
PROSEEOF
        if [ "$_div" = "1" ]; then printf 'REJECT\tcandidate-mismatch\t%s\n' "$_row"; continue; fi
        _lc_h=$(printf '%s' "$_c_head" | tr '[:upper:]' '[:lower:]')
        # Carry the validated original before its re-stamped form so the
        # locked append path can recognize byte-identical rows (idempotence)
        # before the re-stamp turns them into same-key conflicts.
        # A candidate is reported (VALID/duplicate) only after the locked
        # append below succeeds. Pre-lock output must never claim success
        # for a row a later provenance conflict rejects.
        printf 'ORIG\t%s\n' "$_row" >> "$_valid"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tlive-head\t%s\tlive-head-at-verification\t\t%s\n' \
            "$_c_pr" "$_c_pass" "$_c_check" "$_lc_h" "$_c_run" "$_c_iter" \
            "$(printf '%s' "$_row" | cut -f7)" "$(printf '%s' "$_row" | cut -f8)" \
            "$_fverified_at" "revalidated fixture row" >> "$_valid"
    done < "$CANDIDATES"
    rm -f "$_fprose"
    if [ -s "$_valid" ]; then
        _outcome=$(mktemp) || exit 2
        _append_rows_locked "$_valid" aggregate-pairs "$_outcome" || { _rc=$?; rm -f "$_valid" "$_outcome" "$_fprose"; exit "$_rc"; }
        while IFS= read -r _oline || [ -n "${_oline:-}" ]; do
            case "$_oline" in
                APPENDED*|DUPLICATE*) printf 'VALID\t%s\n' "$(printf '%s' "$_oline" | cut -f2-)" ;;
            esac
        done < "$_outcome"
        rm -f "$_valid" "$_outcome"
    fi
    echo "aggregate fixture revalidation complete"
}

cmd_retire() {
    [ -f "$LEDGER" ] || usage_error "ledger not found"
    _lock="$LEDGER.lock"
    (
        _lfd=9
        eval "exec $_lfd>\"$_lock\""
        if ! command -v flock >/dev/null 2>&1; then
            echo "verify-recurrence: flock(1) is required but unavailable; refusing ledger write" >&2
            exit 2
        fi
        if ! flock -w "$LOCK_TIMEOUT" "$_lfd"; then echo "verify-recurrence: ledger lock timeout" >&2; exit 2; fi
        _before=$(grep -cv '^PR\t' "$LEDGER" 2>/dev/null || echo 0)
        _tmp=$(mktemp) || exit 2
        awk -F'\t' -v k="$RETIRE_KEY" 'NR==1 || ($1"\t"$2"\t"$3"\t"$6)!=k' "$LEDGER" > "$_tmp" || { rm -f "$_tmp"; exit 2; }
        _after=$(grep -cv '^PR\t' "$_tmp" 2>/dev/null || echo 0)
        if [ "$_after" = "$_before" ]; then
            rm -f "$_tmp"
            echo "verify-recurrence: retire key not found: $RETIRE_KEY (no rows removed)" >&2
            exit 2
        fi
        mv "$_tmp" "$LEDGER" || exit 2
        echo "retired [$RETIRE_KEY] rows=$((_before - _after)) reason=$RETIRE_REASON"
    )
}

case "$CMD" in
run) cmd_ingest_or_run run ;;
ingest) cmd_ingest_or_run ingest ;;
aggregate) cmd_aggregate ;;
retire) cmd_retire ;;
recurrence-view) cmd_recurrence_view ;;
esac
