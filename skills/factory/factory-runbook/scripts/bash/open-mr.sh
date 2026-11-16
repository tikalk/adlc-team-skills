#!/usr/bin/env bash
# open-mr.sh — push the intent or mission run branch and open (or reuse)
# its one draft MR
# (ADR-431-amendment §3, ADR-432, ADR-444; adlc-workspace#26; --kind code under ADR-473).
#
# With a factory run context (ADLC_RUN_ID): pushes ONLY the current run branch
# (factory/*), finds an open MR/PR for it or creates one draft (squash off; the
# description states the merge-commit rule, ADR-431 §5), with the issue's
# milestone and assignees (ADR-432 chain: issue assignees, else the runner's
# own account; a cross-host run — issue and code on different hosts — sets no
# milestone, assigns the runner and links the issue URL), and merges {"mr_url": ...} into ADLC_STEP_OUTPUT. A run branch
# with no commits beyond the base opens nothing (empty run). Titles are
# built from repo, iid and run id only — never issue text. The tracker token's
# scopes are checked before anything is pushed or created (ADR-432); a missing
# scope or a tracker refusal blocks: non-zero exit, nothing written. Without
# ADLC_RUN_ID this is a no-op. Prints the MR URL.
set -euo pipefail

die() { echo "open-mr: $*" >&2; exit 2; }
json() { node -e "$1" "${@:2}"; }

usage() {
  echo 'usage: open-mr.sh [--kind <intent|code>]' >&2
  exit 2
}

kind="intent"
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) [ $# -ge 2 ] || usage; kind="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$kind" in
  intent|code) ;;
  *) die "unsupported --kind: $kind (expected 'intent' or 'code')" ;;
esac

if [ -z "${ADLC_RUN_ID:-}" ]; then
  echo "open-mr: no run context (ADLC_RUN_ID unset) — skipped" >&2
  exit 0
fi
root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git work tree"
cd "$root"
branch="$(git branch --show-current)"
case "$kind" in
  intent)
    case "$branch" in
      factory/intent/*) ;;
      *) die "not on an intent run branch (factory/intent/*): '$branch'" ;;
    esac ;;
  code)
    case "$branch" in
      factory/mission/*|factory/code/*|factory/mission-*) ;;
      *) die "not on a code run branch (factory/mission/*, factory/code/*): '$branch'" ;;
    esac ;;
esac

origin="$(git config --get remote.origin.url)" || die "no origin remote"
read -r host project < <(json '
  const u = process.argv[1];
  let m = u.match(/^https:\/\/([^/@]+)\/(.+?)(?:\.git)?\/?$/) || u.match(/^(?:ssh:\/\/)?[^@]+@([^:/]+)[:/](.+?)(?:\.git)?$/);
  if (!m) process.exit(3);
  console.log(m[1] + " " + m[2]);
' "$origin") || die "cannot parse origin URL"
repo="${project##*/}"

issue_project="" iid=""
if [ -n "${ADLC_ISSUE_REF:-}" ]; then
  # Same rule as run-branch.sh.
  case "$ADLC_ISSUE_REF" in *..*) die "invalid ADLC_ISSUE_REF";; esac
  [[ "$ADLC_ISSUE_REF" =~ ^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+([A-Za-z0-9_][A-Za-z0-9._-]*))#([0-9]+)$ ]] || die "invalid ADLC_ISSUE_REF"
  issue_project="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[4]}"
  if [ "$kind" = "code" ]; then
    title="Draft: factory: ${issue_project##*/}#${iid} (run ${ADLC_RUN_ID})"
  else
    title="Draft: factory: ${issue_project##*/}#${iid} records (run ${ADLC_RUN_ID})"
  fi
else
  if [ "$kind" = "code" ]; then
    title="Draft: factory: run ${ADLC_RUN_ID}"
  else
    title="Draft: factory: run ${ADLC_RUN_ID} records"
  fi
fi
if [ "$kind" = "code" ]; then
  description="Factory mission run \`${ADLC_RUN_ID}\`${iid:+ for ${issue_project}#${iid}}. Merge with a merge commit, no squash — approved step SHAs must stay reachable."
else
  description="Factory intent run \`${ADLC_RUN_ID}\`${iid:+ for ${issue_project}#${iid}}. Merge with a merge commit, no squash (ADR-431 §5) — approved step SHAs must stay reachable."
fi

# The code host picks the MR/PR provider; ISSUE_PROVIDER names only the
# issue's tracker. Tokens go only to GITLAB_HOST or github.com — any other
# origin host is refused before any API call.
issue_provider="${ISSUE_PROVIDER:-gitlab}"
case "$issue_provider" in gitlab|github) ;; *) die "unsupported ISSUE_PROVIDER: $issue_provider" ;; esac
gitlab_host="${GITLAB_HOST:-}"; gitlab_host="${gitlab_host#https://}"; gitlab_host="${gitlab_host%/}"
if [ "$host" = "github.com" ]; then
  provider=github
elif [ -n "$gitlab_host" ] && [ "$host" = "$gitlab_host" ]; then
  provider=gitlab
elif [ -z "$gitlab_host" ] && [ "$issue_provider" = gitlab ]; then
  die "GITLAB_HOST is not set (the token is never sent to a guessed host)"
else
  die "origin host $host is neither GITLAB_HOST (${gitlab_host:-unset}) nor github.com — no token is sent to it"
fi

# Cross-host run (issue on one tracker, code on the other): milestones and
# users do not map across trackers, so the issue is not read through the
# code host, no milestone is set, the assignee is the runner's own account
# (the fallback chain with no issue and no initiator), and the description
# links the issue by its full URL.
cross_host=0
if [ -n "$iid" ] && [ "$provider" != "$issue_provider" ]; then
  cross_host=1
  if [ "$issue_provider" = gitlab ]; then
    [ -n "$gitlab_host" ] || die "GITLAB_HOST is not set (cannot link the issue)"
    issue_url="https://${gitlab_host}/${issue_project}/-/issues/${iid}"
  else
    issue_url="https://github.com/${issue_project}/issues/${iid}"
  fi
  description="${description} Issue: ${issue_url}"
fi

# An empty run opens nothing: with no commits on the run branch beyond the
# base there is nothing to review, so no push, no MR and no mr_url (the gate
# then shows no link). A re-dispatch continuing a pushed branch is not empty.
base=""
for b in "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)" origin/main origin/master; do
  if [ -n "$b" ] && git rev-parse -q --verify "$b^{commit}" >/dev/null; then base="$b"; break; fi
done
if [ -n "$base" ] && [ "$(git rev-list --count "$base..HEAD")" = 0 ]; then
  echo "open-mr: no commits on $branch beyond $base — nothing to review, no MR opened" >&2
  exit 0
fi

if [ "$provider" = gitlab ]; then
  api() { glab api --hostname "$host" "$@"; }
else
  api() { gh api --hostname github.com "$@"; }
fi

# Scope pre-flight (ADR-432): block before any mutation when the tracker token
# cannot create the MR/PR. The outcome is carried as denied_scope
# (api|repo|null) into the resolve-mr-ownership payload below, whose
# `block` ruling names the missing scope and dies before push.
denied_scope="null"
if [ "$provider" = gitlab ]; then
  self="$(api personal_access_tokens/self 2>/dev/null)" || die "cannot read the tracker token's scopes (needs a personal/project access token with 'api' scope)"
  json 'const t = JSON.parse(process.argv[1] || "{}"); process.exit(Array.isArray(t.scopes) && t.scopes.includes("api") ? 0 : 3)' "$self" \
    || denied_scope="api"
  if [ "$denied_scope" = "api" ]; then
    reason="$(json 'console.log(JSON.stringify({provider:"gitlab",issue:{},mr:{},initiator:"",runner:null,denied_scope:"api"}))' | "$(dirname "$0")/resolve-mr-ownership.sh" | json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).reason || "api"))')"
    die "tracker token lacks the 'api' scope needed to open the merge request ($reason)"
  fi
else
  scopes="$(api -i user 2>/dev/null | tr -d '\r' | sed -n 's/^[Xx]-[Oo][Aa]uth-[Ss]copes:[[:space:]]*//p')" || die "cannot read the tracker token's scopes"
  # Classic tokens report scopes; fine-grained and app tokens do not (the
  # create call below still blocks on a refusal).
  if [ -n "$scopes" ] && ! printf '%s' "$scopes" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -qx 'repo'; then
    die "tracker token lacks the 'repo' scope needed to open the pull request"
  fi
fi

enc() { json 'console.log(encodeURIComponent(process.argv[1]))' "$1"; }

# resolve_mr_ownership <provider> <issue_json> <mr_json> <initiator> <runner_json> <denied_scope_json>
# builds the {provider,issue,mr,initiator,runner,denied_scope} payload and
# invokes resolve-mr-ownership.sh; prints the resolver's JSON answer.
# (Operation 11: the resolver owns the milestone/assignee decision.)
resolve_mr_ownership() {
  json '
    const [provider, issue_raw, mr_raw, initiator, runner_raw, denied_raw] = process.argv.slice(1);
    const parse = (s, fb) => { try { const v = JSON.parse(s); return v === undefined ? fb : v; } catch { return fb; } };
    console.log(JSON.stringify({
      provider, issue: parse(issue_raw, {}), mr: parse(mr_raw, {}),
      initiator: initiator || "", runner: parse(runner_raw, null),
      denied_scope: parse(denied_raw, null),
    }));
  ' "$1" "$2" "$3" "$4" "$5" "$6" | "$(dirname "$0")/resolve-mr-ownership.sh"
}

# ownership_block_or_empty <resolver_json> — exits non-zero naming the scope
# when action == "block", else prints "".
ownership_block_or_empty() {
  json '
    const o = JSON.parse(process.argv[1] || "{}");
    if (o.action === "block") { console.error("open-mr: " + (o.reason || "blocked by resolve-mr-ownership")); process.exit(3); }
    console.log("");
  ' "$1" || die "$(json 'console.log(JSON.parse(process.argv[1] || "{}").reason || "blocked by resolve-mr-ownership")' "$1")"
}

# push_reuse — the reuse path pushes too, so commits from a run that reuses a
# capture-time (or earlier) MR reach it. Fast-forward only: never --force; a
# rejected push means the branch moved on the remote.
push_reuse() {
  git push -q -u origin "refs/heads/$branch:refs/heads/$branch" \
    || die "push of $branch was rejected: the branch moved on the remote; re-run run-branch to catch up, then open-mr again"
}

url=""
if [ "$provider" = gitlab ]; then
  p="$(enc "$project")"
  # Only an MR whose source branch lives in this project is the run's own:
  # the list also returns MRs opened from forks, and a fork can pick the
  # same predictable branch name. A fork MR is never reused.
  existing="$(api "projects/$p/merge_requests?source_branch=$(enc "$branch")&state=opened")" || die "cannot list merge requests"
  url="$(json 'const a = JSON.parse(process.argv[1] || "[]"); const m = Array.isArray(a) && a.find((x) => x && x.source_project_id != null && x.source_project_id === x.target_project_id); console.log(m && m.web_url || "")' "$existing")"
  if [ -n "$url" ]; then
    # Reuse path: push the run's commits (fast-forward only), then return the
    # open MR untouched — no issue read, no resolve-mr-ownership call
    # (preserve-only = touch nothing).
    push_reuse
  else
    git push -q -u origin "refs/heads/$branch:refs/heads/$branch" || die "push of $branch failed"
    if [ -n "$iid" ] && [ "$cross_host" = 0 ]; then
      issue_json="$(api "projects/$(enc "$issue_project")/issues/$iid")" || die "cannot read issue $issue_project#$iid"
      # Normalize the connector GET into resolver verbatim form
      # {milestone_id, assignees:[ids]} (provider mapping table, Operation 11).
      issue_json="$(json '
        const i = JSON.parse(process.argv[1] || "{}");
        const mid = (i.milestone_id !== undefined && i.milestone_id !== null && i.milestone_id !== "")
          ? i.milestone_id : (i.milestone && i.milestone.id || null);
        const ids = (i.assignees || []).map(a => (a && typeof a === "object" ? a.id : a)).filter(v => v !== undefined && v !== null);
        const num = mid === null || mid === "" ? null : Number(mid);
        console.log(JSON.stringify({ milestone_id: (mid === null || mid === "") ? null : num, assignees: ids.map(Number).filter(n => !Number.isNaN(n)) }));
      ' "$issue_json")"
    else
      issue_json="{}"
    fi
    initiator="${ADLC_INITIATOR:-}"
    [ "$cross_host" = 0 ] || initiator=""  # an identity from the other tracker
    runner_json="$(api user | json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.stringify(JSON.parse(s).id))}catch(e){console.log("null")}})')"
    if [ "$denied_scope" = "api" ]; then denied_json='"api"'; else denied_json='null'; fi
    ownership="$(resolve_mr_ownership gitlab "$issue_json" '{}' "$initiator" "$runner_json" "$denied_json")" || die "cannot resolve MR ownership"
    ownership_block_or_empty "$ownership" >/dev/null
    # Create body = fixed keys + ONLY resolver-returned non-null fields.
    # One JSON body via --input: current glab refuses bracketed field names
    # (`assignee_ids[]=`) in a JSON request, and -f would send the ids and the
    # milestone as strings.
    body="$(json '
      const [source_branch, target_branch, title, description, ownership] = process.argv.slice(1);
      const o = JSON.parse(ownership || "{}");
      const b = { source_branch, target_branch, title, description, squash: false };
      if (o.milestone !== null && o.milestone !== undefined && o.milestone_field === "milestone_id") b.milestone_id = Number(o.milestone);
      if (o.assignee !== null && o.assignee !== undefined && o.assignee_field === "assignee_ids") {
        const ids = Array.isArray(o.assignee) ? o.assignee : [o.assignee];
        const nums = ids.map(Number).filter(n => !Number.isNaN(n));
        if (nums.length) b.assignee_ids = nums;
      }
      console.log(JSON.stringify(b));
    ' "$branch" "$(api "projects/$p" | json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).default_branch||"main"))')" "$title" "$description" "$ownership")"
    created="$(printf '%s' "$body" | api -X POST "projects/$p/merge_requests" -H 'Content-Type: application/json' --input -)" || die "the tracker refused to create the merge request (missing scope?)"
    url="$(json 'console.log(JSON.parse(process.argv[1]).web_url || "")' "$created")"
  fi
else
  owner="${project%%/*}"
  existing="$(api "repos/$project/pulls?head=$owner:$branch&state=open")" || die "cannot list pull requests"
  url="$(json 'const a = JSON.parse(process.argv[1] || "[]"); console.log(Array.isArray(a) && a[0] && a[0].html_url || "")' "$existing")"
  if [ -n "$url" ]; then
    # Reuse path: push the run's commits (fast-forward only), then return the
    # open PR untouched — no issue read, no resolve-mr-ownership call
    # (preserve-only = touch nothing).
    push_reuse
  else
    git push -q -u origin "refs/heads/$branch:refs/heads/$branch" || die "push of $branch failed"
    target="$(api "repos/$project" | json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).default_branch||"main"))')"
    created="$(api -X POST "repos/$project/pulls" -f "head=$branch" -f "base=$target" -f "title=${title#Draft: }" -f "body=$description" -F draft=true)" || die "the tracker refused to create the pull request (missing scope?)"
    url="$(json 'console.log(JSON.parse(process.argv[1]).html_url || "")' "$created")"
    number="$(json 'console.log(JSON.parse(process.argv[1]).number || "")' "$created")"
    # GitHub via resolve-mr-ownership: bare PR create first, then PATCH
    # milestone / POST assignees ONLY for resolver-returned non-null fields.
    if [ -n "$number" ]; then
      if [ -n "$iid" ] && [ "$cross_host" = 0 ]; then
        mr_issue_json="$(api "repos/$project/issues/$number" 2>/dev/null || echo '{}')"
        issue_json="$(api "repos/$issue_project/issues/$iid")" || die "cannot read issue $issue_project#$iid"
      elif [ -n "$iid" ]; then
        mr_issue_json="$(api "repos/$project/issues/$number" 2>/dev/null || echo '{}')"
        issue_json="{}"
      else
        mr_issue_json="{}"
        issue_json="{}"
      fi
      initiator="${ADLC_INITIATOR:-}"
      [ "$cross_host" = 0 ] || initiator=""  # an identity from the other tracker
      runner_json="$(api user | json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.stringify(JSON.parse(s).login))}catch(e){console.log("null")}})')"
      if [ "$denied_scope" = "repo" ]; then denied_json='"repo"'; else denied_json='null'; fi
      # mr = the created PR's current issue fields ({ } when unreadable).
      mr_json="$(json '
        const m = JSON.parse(process.argv[1] || "{}");
        const o = {};
        if (m.milestone !== undefined) o.milestone = m.milestone;
        if (m.assignees !== undefined) o.assignees = m.assignees;
        console.log(JSON.stringify(o));
      ' "$mr_issue_json")"
      ownership="$(resolve_mr_ownership github "$issue_json" "$mr_json" "$initiator" "$runner_json" "$denied_json")" || die "cannot resolve MR ownership"
      ownership_block_or_empty "$ownership" >/dev/null
      milestone_to_set="$(json 'const o = JSON.parse(process.argv[1] || "{}"); console.log(o.milestone === null || o.milestone === undefined ? "" : o.milestone)' "$ownership")"
      assignee_to_set="$(json '
        const o = JSON.parse(process.argv[1] || "{}");
        if (o.assignee === null || o.assignee === undefined) { console.log(""); } else {
        const a = Array.isArray(o.assignee) ? o.assignee : [o.assignee];
        console.log(a.map(v => (v && typeof v === "object" ? (v.login || "") : String(v))).filter(Boolean).join(" ")); }
      ' "$ownership")"
      [ -z "$milestone_to_set" ] || api -X PATCH "repos/$project/issues/$number" -F "milestone=$milestone_to_set" >/dev/null || die "cannot set milestone"
      for l in $assignee_to_set; do api -X POST "repos/$project/issues/$number/assignees" -f "assignees[]=$l" >/dev/null || die "cannot set assignee"; done
    fi
  fi
fi
[ -n "$url" ] || die "no MR URL returned"

if [ -n "${ADLC_STEP_OUTPUT:-}" ]; then
  mkdir -p "$(dirname "$ADLC_STEP_OUTPUT")"
  json '
    const fs = require("node:fs"); const [file, url] = process.argv.slice(1);
    let o = {}; try { const v = JSON.parse(fs.readFileSync(file, "utf-8")); if (v && typeof v === "object" && !Array.isArray(v)) o = v; } catch {}
    o.mr_url = url; fs.writeFileSync(file, JSON.stringify(o));
  ' "$ADLC_STEP_OUTPUT" "$url"
fi
echo "$url"
