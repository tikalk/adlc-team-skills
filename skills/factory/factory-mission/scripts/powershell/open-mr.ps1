#!/usr/bin/env pwsh
# open-mr.ps1 — push the intent run branch and open (or reuse) its one draft MR
# (PowerShell twin of open-mr.sh; ADR-431-amendment §3, ADR-432, ADR-444;
# adlc-workspace#26).
#
# With a factory run context (ADLC_RUN_ID): pushes ONLY the current run branch
# (factory/*), finds an open MR/PR for it or creates one draft (squash off; the
# description states the merge-commit rule, ADR-431 §5), with the issue's
# milestone and assignees (ADR-432 chain: issue assignees, else the runner's
# own account), and merges {"mr_url": ...} into ADLC_STEP_OUTPUT. A run branch
# with no commits beyond the base opens nothing (empty run). Titles are
# built from repo, iid and run id only — never issue text. The tracker token's
# scopes are checked before anything is pushed or created (ADR-432); a missing
# scope or a tracker refusal blocks: non-zero exit, nothing written. Without
# ADLC_RUN_ID this is a no-op. Prints the MR URL.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("open-mr: $Message")
    exit 2
}
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
if ($branch -notlike 'factory/intent/*') { Die "not on an intent run branch (factory/intent/*): '$branch'" }

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
        $title = "Draft: factory: ${ipRepo}#${iid} records (run $($env:ADLC_RUN_ID))"
    } else { Die 'invalid ADLC_ISSUE_REF' }
} else {
    $title = "Draft: factory: run $($env:ADLC_RUN_ID) records"
}
$forIssue = if ($iid) { " for ${issueProject}#${iid}" } else { '' }
$description = "Factory intent run ``$($env:ADLC_RUN_ID)``$forIssue. Merge with a merge commit, no squash (ADR-431 §5) — approved step SHAs must stay reachable."

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
# cannot create the MR/PR.
if ($provider -eq 'gitlab') {
    $self = Api @('personal_access_tokens/self') 2>$null
    if ($LASTEXITCODE -ne 0) { Die "cannot read the tracker token's scopes (needs a personal/project access token with 'api' scope)" }
    json 'const t = JSON.parse(process.argv[1] || "{}"); process.exit(Array.isArray(t.scopes) && t.scopes.includes("api") ? 0 : 3)' @($self) *> $null
    if ($LASTEXITCODE -ne 0) { Die "tracker token lacks the 'api' scope needed to open the merge request" }
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

git push -q -u origin "refs/heads/${branch}:refs/heads/${branch}"
if ($LASTEXITCODE -ne 0) { Die "push of $branch failed" }

function Enc([string]$S) { json 'console.log(encodeURIComponent(process.argv[1]))' @($S) }

$url = ''
if ($provider -eq 'gitlab') {
    $p = Enc $project
    $existing = Api @("projects/$p/merge_requests?source_branch=$(Enc $branch)&state=opened")
    if ($LASTEXITCODE -ne 0) { Die 'cannot list merge requests' }
    $url = json 'const a = JSON.parse(process.argv[1] || "[]"); console.log(Array.isArray(a) && a[0] && a[0].web_url || "")' @($existing)
    if (-not $url) {
        $projJson = (Api @("projects/$p")) -join "`n"
        $target = json 'console.log(JSON.parse(process.argv[1]).default_branch||"main")' @($projJson)
        $apiArgs = [System.Collections.Generic.List[string]]::new()
        $apiArgs.AddRange([string[]]@('-X', 'POST', "projects/$p/merge_requests",
            "-f", "source_branch=$branch", "-f", "target_branch=$target",
            "-f", "title=$title", '-f', 'squash=false', "-f", "description=$description"))
        $assignees = ''
        if ($iid) {
            $issue = Api @("projects/$(Enc $issueProject)/issues/$iid")
            if ($LASTEXITCODE -ne 0) { Die "cannot read issue $issueProject#$iid" }
            $milestone = json 'const i = JSON.parse(process.argv[1]); console.log(i.milestone && i.milestone.id || "")' @($issue)
            if ($milestone) { $apiArgs.AddRange([string[]]@('-f', "milestone_id=$milestone")) }
            $assignees = json 'const i = JSON.parse(process.argv[1]); console.log((i.assignees || []).map(a => a.id).join(" "))' @($issue)
        }
        if (-not $assignees) {
            $userJson = (Api @('user')) -join "`n"
            $assignees = json 'console.log(JSON.parse(process.argv[1]).id||"")' @($userJson)
        }
        foreach ($a in ($assignees -split ' ')) {
            if ($a) { $apiArgs.AddRange([string[]]@('-f', "assignee_ids[]=$a")) }
        }
        $created = Api @($apiArgs.ToArray())
        if ($LASTEXITCODE -ne 0) { Die 'the tracker refused to create the merge request (missing scope?)' }
        $url = json 'console.log(JSON.parse(process.argv[1]).web_url || "")' @($created)
    }
} else {
    $owner = ($project -split '/')[0]
    $existing = Api @("repos/$project/pulls?head=${owner}:${branch}&state=open")
    if ($LASTEXITCODE -ne 0) { Die 'cannot list pull requests' }
    $url = json 'const a = JSON.parse(process.argv[1] || "[]"); console.log(Array.isArray(a) && a[0] && a[0].html_url || "")' @($existing)
    if (-not $url) {
        $projJson = (Api @("repos/$project")) -join "`n"
        $target = json 'console.log(JSON.parse(process.argv[1]).default_branch||"main")' @($projJson)
        $ghTitle = $title -replace '^Draft: ', ''
        $created = Api @('-X', 'POST', "repos/$project/pulls",
            '-f', "head=$branch", '-f', "base=$target", '-f', "title=$ghTitle", '-f', "body=$description", '-F', 'draft=true')
        if ($LASTEXITCODE -ne 0) { Die 'the tracker refused to create the pull request (missing scope?)' }
        $url = json 'console.log(JSON.parse(process.argv[1]).html_url || "")' @($created)
        $number = json 'console.log(JSON.parse(process.argv[1]).number || "")' @($created)
        if ($iid -and $number) {
            $issue = Api @("repos/$issueProject/issues/$iid")
            if ($LASTEXITCODE -ne 0) { Die "cannot read issue $issueProject#$iid" }
            $milestone = json 'const i = JSON.parse(process.argv[1]); console.log(i.milestone && i.milestone.number || "")' @($issue)
            if ($milestone) {
                Api @('-X', 'PATCH', "repos/$project/issues/$number", '-F', "milestone=$milestone") *> $null
                if ($LASTEXITCODE -ne 0) { Die 'cannot set milestone' }
            }
            $logins = json 'const i = JSON.parse(process.argv[1]); console.log((i.assignees || []).map(a => a.login).join(" "))' @($issue)
            if (-not $logins) {
                $userJson = (Api @('user')) -join "`n"
                $logins = json 'console.log(JSON.parse(process.argv[1]).login||"")' @($userJson)
            }
            foreach ($l in ($logins -split ' ')) {
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
