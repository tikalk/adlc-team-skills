#!/usr/bin/env pwsh
# open-mr.ps1 — push the intent or mission run branch and open (or reuse)
# its one draft MR
# (PowerShell twin of open-mr.sh; ADR-431-amendment §3, ADR-432, ADR-444;
# adlc-workspace#26; --kind code under ADR-473).
#
# Usage: open-mr.ps1 [--kind <intent|code>] (default intent).
#
# With a factory run context (ADLC_RUN_ID): pushes ONLY the current run branch
# (factory/*), finds an open MR/PR for it or creates one draft (squash off; the
# description states the merge-commit rule, ADR-431 §5), with the issue's
# milestone and assignees (ADR-432 chain: issue assignees, else the runner's
# own account), and merges {"mr_url": ...} into ADLC_STEP_OUTPUT. A run branch
# with no commits beyond the base opens nothing (empty run). Titles are
# built from repo, iid and run id only — never issue text. --kind code
# opens the mission code MR instead (branch factory/mission/* or
# factory/code/*, mission-flavoured title). The tracker token's
# scopes are checked before anything is pushed or created (ADR-432); a missing
# scope or a tracker refusal blocks: non-zero exit, nothing written. Without
# ADLC_RUN_ID this is a no-op. Prints the MR URL.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("open-mr: $Message")
    exit 2
}

$kind = 'intent'
$rest = [System.Collections.Generic.List[object]]::new()
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--kind') { $i++; if ($i -ge $args.Count) { Die 'missing --kind value' }; $kind = [string]$args[$i]; continue }
    $rest.Add($args[$i])
}
if ($kind -notin @('intent', 'code')) { Die "unsupported --kind: $kind (expected 'intent' or 'code')" }
if ($rest.Count -gt 0) { Die "unknown argument: $($rest[0])" }
# json <node-script> [args...] — node is the JSON engine (same as the bash twin).
function json([string]$Script, [string[]]$JArgs = @()) {
    if ($JArgs.Count -gt 0) { node -e $Script @JArgs } else { node -e $Script }
}

if (-not $env:ADLC_RUN_ID) {
    [Console]::Error.WriteLine('open-mr: no run context (ADLC_RUN_ID unset) — skipped')
    exit 0
}
$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $root) { Die 'not inside a git work tree' }
Set-Location $root.Trim()
$branch = (git branch --show-current).Trim()
if ($kind -eq 'intent') {
    if ($branch -notlike 'factory/intent/*') { Die "not on an intent run branch (factory/intent/*): '$branch'" }
} else {
    if ($branch -notlike 'factory/mission/*' -and $branch -notlike 'factory/code/*' -and $branch -notlike 'factory/mission-*') {
        Die "not on a code run branch (factory/mission/*, factory/code/*): '$branch'"
    }
}

$origin = (git config --get remote.origin.url 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $origin) { Die 'no origin remote' }
$origin = $origin.Trim()
$parsed = json 'const u = process.argv[1];
let m = u.match(/^https:\/\/([^\/@]+)\/(.+?)(?:\.git)?\/?$/) || u.match(/^(?:ssh:\/\/)?[^@]+@([^:\/]+)[:\/](.+?)(?:\.git)?$/);
if (!m) process.exit(3);
console.log(m[1] + " " + m[2]);' @($origin)
if ($LASTEXITCODE -ne 0) { Die 'cannot parse origin URL' }
$host_ = ($parsed -split ' ', 2)[0]; $project = ($parsed -split ' ', 2)[1]
$repo = ($project -split '/')[-1]

$issueProject = ''; $iid = ''; $title = $null
if ($env:ADLC_ISSUE_REF) {
    if ($env:ADLC_ISSUE_REF -like '*..*') { Die 'invalid ADLC_ISSUE_REF' }
    if ($env:ADLC_ISSUE_REF -match '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+([A-Za-z0-9_][A-Za-z0-9._-]*))#([0-9]+)$') {
        $issueProject = $Matches[1]; $iid = $Matches[4]
        $ipRepo = ($issueProject -split '/')[-1]
        if ($kind -eq 'code') {
            $title = "Draft: factory: ${ipRepo}#${iid} (run $($env:ADLC_RUN_ID))"
        } else {
            $title = "Draft: factory: ${ipRepo}#${iid} records (run $($env:ADLC_RUN_ID))"
        }
    } else { Die 'invalid ADLC_ISSUE_REF' }
} else {
    if ($kind -eq 'code') {
        $title = "Draft: factory: run $($env:ADLC_RUN_ID)"
    } else {
        $title = "Draft: factory: run $($env:ADLC_RUN_ID) records"
    }
}
$forIssue = if ($iid) { " for ${issueProject}#${iid}" } else { '' }
if ($kind -eq 'code') {
    $description = "Factory mission run ``$($env:ADLC_RUN_ID)``$forIssue. Merge with a merge commit, no squash — approved step SHAs must stay reachable."
} else {
    $description = "Factory intent run ``$($env:ADLC_RUN_ID)``$forIssue. Merge with a merge commit, no squash (ADR-431 §5) — approved step SHAs must stay reachable."
}

$provider = if ($env:ISSUE_PROVIDER) { $env:ISSUE_PROVIDER } else { 'gitlab' }
switch ($provider) {
    'gitlab' {
        if (-not $env:GITLAB_HOST) { Die 'GITLAB_HOST is not set (the token is never sent to a guessed host)' }
        $want = $env:GITLAB_HOST -replace '^https://', ''
        $want = $want.TrimEnd('/')
        if ($host_ -ne $want) { Die "origin host $host_ is not GITLAB_HOST ($want)" }
    }
    'github' { if ($host_ -ne 'github.com') { Die "origin host $host_ is not github.com" } }
    default { Die "unsupported ISSUE_PROVIDER: $provider" }
}

# An empty run opens nothing: with no commits on the run branch beyond the
# base there is nothing to review, so no push, no MR and no mr_url (the gate
# then shows no link). A re-dispatch continuing a pushed branch is not empty.
$base = ''
foreach ($b in @((git symbolic-ref -q --short refs/remotes/origin/HEAD 2>$null), 'origin/main', 'origin/master')) {
    $b = if ($b) { $b.Trim() } else { '' }
    if ($b) {
        git rev-parse -q --verify "$b^{commit}" *> $null
        if ($LASTEXITCODE -eq 0) { $base = $b; break }
    }
}
if ($base) {
    $count = [int](git rev-list --count "$base..HEAD").Trim()
    if ($count -eq 0) {
        [Console]::Error.WriteLine("open-mr: no commits on $branch beyond $base — nothing to review, no MR opened")
        exit 0
    }
}

function Api([string[]]$ApiArgs) {
    if ($provider -eq 'gitlab') { glab api --hostname $host_ @ApiArgs }
    else { gh api --hostname github.com @ApiArgs }
}

# Scope pre-flight (ADR-432): block before any mutation when the tracker token
# cannot create the MR/PR. The outcome is carried as denied_scope
# (api|repo|null) into the resolve-mr-ownership payload below, whose
# `block` ruling names the missing scope and dies before push.
$deniedScope = 'null'
if ($provider -eq 'gitlab') {
    $self = Api @('personal_access_tokens/self') 2>$null
    if ($LASTEXITCODE -ne 0) { Die "cannot read the tracker token's scopes (needs a personal/project access token with 'api' scope)" }
    json 'const t = JSON.parse(process.argv[1] || "{}"); process.exit(Array.isArray(t.scopes) && t.scopes.includes("api") ? 0 : 3)' @($self) *> $null
    if ($LASTEXITCODE -ne 0) {
        $deniedScope = 'api'
        $reasonPayload = json 'console.log(JSON.stringify({provider: "gitlab", issue: {}, mr: {}, initiator: "", runner: null, denied_scope: "api"}))'
        $reasonAnswer = Invoke-ResolveMrOwnershipFile $reasonPayload
        $reason = json 'console.log(JSON.parse(process.argv[1] || "{}").reason || "api")' @($reasonAnswer)
        Die "tracker token lacks the 'api' scope needed to open the merge request ($reason)"
    }
} else {
    $raw = gh api --hostname github.com -i user 2>$null
    if ($LASTEXITCODE -ne 0) { Die "cannot read the tracker token's scopes" }
    $scopes = ($raw | Where-Object { $_ -match '^[Xx]-[Oo][Aa][Uu][Tt][Hh]-[Ss][Cc][Oo][Pp][Ee][Ss]:' }) -replace '^[^:]*:\s*', ''
    # Classic tokens report scopes; fine-grained and app tokens do not (the
    # create call below still blocks on a refusal).
    if ($scopes) {
        $have = ($scopes -split ',').ForEach({ $_.Trim() }) -contains 'repo'
        if (-not $have) { Die "tracker token lacks the 'repo' scope needed to open the pull request" }
    }
}

function Enc([string]$S) { json 'console.log(encodeURIComponent(process.argv[1]))' @($S) }

# Invoke-ResolveMrOwnershipFile <json-string> — pass a JSON payload to
# resolve-mr-ownership.ps1 via a temp file (never a script-to-script pipe:
# `[Console]::In` is the process console, not the pipe, so `payload |
# resolve-mr-ownership.ps1` arrives empty). Prints the resolver's JSON answer.
function Invoke-ResolveMrOwnershipFile([string]$Payload) {
    $payloadFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($payloadFile, $Payload)
        $answer = & "${PSScriptRoot}/resolve-mr-ownership.ps1" $payloadFile
        if ($LASTEXITCODE -ne 0) { Die 'cannot resolve MR ownership' }
        return ($answer -join "`n")
    } finally {
        Remove-Item -Force $payloadFile -ErrorAction SilentlyContinue
    }
}

# Invoke-ResolveMrOwnership <provider> <issueJson> <mrJson> <initiator> <runnerJson> <deniedJson>
# builds the {provider,issue,mr,initiator,runner,denied_scope} payload and
# invokes resolve-mr-ownership.ps1; prints the resolver's JSON answer.
# (Operation 11: the resolver owns the milestone/assignee decision.)
function Invoke-ResolveMrOwnership([string]$Provider_, [string]$IssueJson, [string]$MrJson, [string]$Initiator_, [string]$RunnerJson, [string]$DeniedJson) {
    $payload = json '
    const [provider, issue_raw, mr_raw, initiator, runner_raw, denied_raw] = process.argv.slice(1);
    const parse = (s, fb) => { try { const v = JSON.parse(s); return v === undefined ? fb : v; } catch { return fb; } };
    console.log(JSON.stringify({
      provider, issue: parse(issue_raw, {}), mr: parse(mr_raw, {}),
      initiator: initiator || "", runner: parse(runner_raw, null),
      denied_scope: parse(denied_raw, null),
    }));' @($Provider_, $IssueJson, $MrJson, $Initiator_, $RunnerJson, $DeniedJson)
    return Invoke-ResolveMrOwnershipFile $payload
}

# Assert-OwnershipNotBlocked <resolverJson> — exits non-zero naming the scope
# when action == "block".
function Assert-OwnershipNotBlocked([string]$OwnershipJson) {
    json '
    const o = JSON.parse(process.argv[1] || "{}");
    if (o.action === "block") { console.error("open-mr: " + (o.reason || "blocked by resolve-mr-ownership")); process.exit(3); }
    console.log("");
    ' @($OwnershipJson) *> $null
    if ($LASTEXITCODE -ne 0) {
        $why = json 'console.log(JSON.parse(process.argv[1] || "{}").reason || "blocked by resolve-mr-ownership")' @($OwnershipJson)
        Die $why
    }
}

$url = ''
if ($provider -eq 'gitlab') {
    $p = Enc $project
    $existing = Api @("projects/$p/merge_requests?source_branch=$(Enc $branch)&state=opened")
    if ($LASTEXITCODE -ne 0) { Die 'cannot list merge requests' }
    $url = json 'const a = JSON.parse(process.argv[1] || "[]"); console.log(Array.isArray(a) && a[0] && a[0].web_url || "")' @($existing)
    if (-not $url) {
        # Create path: push first; reuse path returns the open MR untouched
        # above — no issue read, no resolve-mr-ownership call.
        git push -q -u origin "refs/heads/${branch}:refs/heads/${branch}"
        if ($LASTEXITCODE -ne 0) { Die "push of $branch failed" }
        if ($iid) {
            $issueRaw = Api @("projects/$(Enc $issueProject)/issues/$iid")
            if ($LASTEXITCODE -ne 0) { Die "cannot read issue $issueProject#$iid" }
            # Normalize the connector GET into resolver verbatim form
            # {milestone_id, assignees:[ids]}.
            $issueJson = json '
        const i = JSON.parse(process.argv[1] || "{}");
        const mid = (i.milestone_id !== undefined && i.milestone_id !== null && i.milestone_id !== "")
          ? i.milestone_id : (i.milestone && i.milestone.id || null);
        const ids = (i.assignees || []).map(a => (a && typeof a === "object" ? a.id : a)).filter(v => v !== undefined && v !== null);
        const num = mid === null || mid === "" ? null : Number(mid);
        console.log(JSON.stringify({ milestone_id: (mid === null || mid === "") ? null : num, assignees: ids.map(Number).filter(n => !Number.isNaN(n)) }));
      ' @($issueRaw)
        } else {
            $issueJson = '{}'
        }
        $initiator = if ($env:ADLC_INITIATOR) { $env:ADLC_INITIATOR } else { '' }
        $runnerRaw = (Api @('user')) -join "`n"
        $runnerJson = json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.stringify(JSON.parse(s).id))}catch(e){console.log("null")}})' @($runnerRaw)
        if ($deniedScope -eq 'api') { $deniedJson = '"api"' } else { $deniedJson = 'null' }
        $ownership = Invoke-ResolveMrOwnership 'gitlab' $issueJson '{}' $initiator $runnerJson $deniedJson
        Assert-OwnershipNotBlocked $ownership
        # Create body = fixed keys + ONLY resolver-returned non-null fields.
        # One JSON body via --input: current glab refuses bracketed field names
        # (`assignee_ids[]=`) in a JSON request, and -f would send the ids and
        # the milestone as strings.
        $projJson = (Api @("projects/$p")) -join "`n"
        $target = json 'console.log(JSON.parse(process.argv[1]).default_branch||"main")' @($projJson)
        $createBody = json '
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
    ' @($branch, $target, $title, $description, $ownership)
        $bodyFile = [System.IO.Path]::GetTempFileName()
        try {
            [System.IO.File]::WriteAllText($bodyFile, $createBody)
            $created = Api @('-X', 'POST', "projects/$p/merge_requests", '-H', 'Content-Type: application/json', '--input', $bodyFile)
            $createExit = $LASTEXITCODE
        } finally {
            Remove-Item -Force $bodyFile -ErrorAction SilentlyContinue
        }
        if ($createExit -ne 0) { Die 'the tracker refused to create the merge request (missing scope?)' }
        $url = json 'console.log(JSON.parse(process.argv[1]).web_url || "")' @($created)
    }
} else {
    $owner = ($project -split '/')[0]
    $existing = Api @("repos/$project/pulls?head=${owner}:${branch}&state=open")
    if ($LASTEXITCODE -ne 0) { Die 'cannot list pull requests' }
    $url = json 'const a = JSON.parse(process.argv[1] || "[]"); console.log(Array.isArray(a) && a[0] && a[0].html_url || "")' @($existing)
    if (-not $url) {
        # Create path: push first; reuse path returns the open PR untouched
        # above — no issue read, no resolve-mr-ownership call.
        git push -q -u origin "refs/heads/${branch}:refs/heads/${branch}"
        if ($LASTEXITCODE -ne 0) { Die "push of $branch failed" }
        $projJson = (Api @("repos/$project")) -join "`n"
        $target = json 'console.log(JSON.parse(process.argv[1]).default_branch||"main")' @($projJson)
        $ghTitle = $title -replace '^Draft: ', ''
        $created = Api @('-X', 'POST', "repos/$project/pulls",
            '-f', "head=$branch", '-f', "base=$target", '-f', "title=$ghTitle", '-f', "body=$description", '-F', 'draft=true')
        if ($LASTEXITCODE -ne 0) { Die 'the tracker refused to create the pull request (missing scope?)' }
        $url = json 'console.log(JSON.parse(process.argv[1]).html_url || "")' @($created)
        $number = json 'console.log(JSON.parse(process.argv[1]).number || "")' @($created)
        # GitHub via resolve-mr-ownership: bare PR create first, then PATCH
        # milestone / POST assignees ONLY for resolver-returned non-null fields.
        if ($number) {
            if ($iid) {
                $mrIssueRaw = Api @("repos/$project/issues/$number") 2>$null
                if ($LASTEXITCODE -ne 0) { $mrIssueRaw = '{}' }
                $issueJson = Api @("repos/$issueProject/issues/$iid")
                if ($LASTEXITCODE -ne 0) { Die "cannot read issue $issueProject#$iid" }
            } else {
                $mrIssueRaw = '{}'
                $issueJson = '{}'
            }
            $initiator = if ($env:ADLC_INITIATOR) { $env:ADLC_INITIATOR } else { '' }
            $runnerRaw = (Api @('user')) -join "`n"
            $runnerJson = json 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.stringify(JSON.parse(s).login))}catch(e){console.log("null")}})' @($runnerRaw)
            if ($deniedScope -eq 'repo') { $deniedJson = '"repo"' } else { $deniedJson = 'null' }
            # mr = the created PR's current issue fields ({ } when unreadable).
            $mrJson = json '
        const m = JSON.parse(process.argv[1] || "{}");
        const o = {};
        if (m.milestone !== undefined) o.milestone = m.milestone;
        if (m.assignees !== undefined) o.assignees = m.assignees;
        console.log(JSON.stringify(o));
      ' @($mrIssueRaw)
            $ownership = Invoke-ResolveMrOwnership 'github' $issueJson $mrJson $initiator $runnerJson $deniedJson
            Assert-OwnershipNotBlocked $ownership
            $milestoneToSet = json 'const o = JSON.parse(process.argv[1] || "{}"); console.log(o.milestone === null || o.milestone === undefined ? "" : o.milestone)' @($ownership)
            $assigneesToSet = json '
        const o = JSON.parse(process.argv[1] || "{}");
        if (o.assignee === null || o.assignee === undefined) { console.log(""); } else {
        const a = Array.isArray(o.assignee) ? o.assignee : [o.assignee];
        console.log(a.map(v => (v && typeof v === "object" ? (v.login || "") : String(v))).filter(Boolean).join(" ")); }
      ' @($ownership)
            if ($milestoneToSet) {
                Api @('-X', 'PATCH', "repos/$project/issues/$number", '-F', "milestone=$milestoneToSet") *> $null
                if ($LASTEXITCODE -ne 0) { Die 'cannot set milestone' }
            }
            foreach ($l in ($assigneesToSet -split ' ')) {
                if ($l) {
                    Api @('-X', 'POST', "repos/$project/issues/$number/assignees", '-f', "assignees[]=$l") *> $null
                    if ($LASTEXITCODE -ne 0) { Die 'cannot set assignee' }
                }
            }
        }
    }
}
if (-not $url) { Die 'no MR URL returned' }

if ($env:ADLC_STEP_OUTPUT) {
    $file = $env:ADLC_STEP_OUTPUT
    $dir = Split-Path $file -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    json 'const fs = require("node:fs"); const [file, url] = process.argv.slice(1);
    let o = {}; try { const v = JSON.parse(fs.readFileSync(file, "utf-8")); if (v && typeof v === "object" && !Array.isArray(v)) o = v; } catch {}
    o.mr_url = url; fs.writeFileSync(file, JSON.stringify(o));' @($file, $url) *> $null
    if ($LASTEXITCODE -ne 0) { Die 'cannot write ADLC_STEP_OUTPUT' }
}
Write-Output $url
