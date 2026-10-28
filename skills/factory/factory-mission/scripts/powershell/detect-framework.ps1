#!/usr/bin/env pwsh
# detect-framework.ps1 — resolve the active mission-* lane (PowerShell twin; ADR-468 rule 2, PDR-149; M11 E6).
#
# Precedence: 1. `framework:` override in mission.yml (fails closed, exit 2).
# 2. Repo usage evidence — framework-native artifact fingerprints dated by
# `git log` per fingerprint (never mtimes); multi-match -> latest wins,
# conflict logged to stderr. 3. Installed packs in .agents/skills/. 4. Embedded
# default (strictly the zero-evidence fallback). Detection only observes.
#
# Usage: detect-framework.ps1 [-Mission <mission.yml>] [-RepoRoot <path>]
# Prints `<lane> <evidence>` on stdout; conflict detail to stderr as `conflict:` lines.
# Exit 0 on resolve, 2 on unknown framework, 1 on usage error.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message, [int]$Code = 1) {
    [Console]::Error.WriteLine("detect-framework: $Message")
    exit $Code
}

param(
    [string]$Mission = "",
    [string]$RepoRoot = ""
)

$ValidLanes = @("speckit", "superpowers", "addy", "matt", "embedded")

if ($Mission) {
    if (-not (Test-Path $Mission)) { Die "mission file not found: $Mission" 1 }
    $lines = Get-Content -Path $Mission
    $fw = $null
    foreach ($l in $lines) {
        if ($l -match '^\s*framework:\s*["'']?([A-Za-z0-9._-]+)["'']?\s*(#.*)?$') {
            $fw = $Matches[1]
        }
    }
    if ($fw) {
        if ($ValidLanes -notcontains $fw) {
            [Console]::Error.WriteLine("detect-framework: unknown framework: $fw")
            exit 2
        }
        Write-Output "$fw override"
        exit 0
    }
}

if (-not $RepoRoot) {
    $r = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $r) { Die "not inside a git work tree" 1 }
    $RepoRoot = $r.Trim()
}
Set-Location $RepoRoot

function Get-CommitDateForPath([string]$Paths) {
    $argList = @("log", "-1", "--format=%H %cI", "--") + ($Paths -split "\s+")
    $out = & git @argList 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
        $parts = $out.Trim() -split "\s+", 2
        if ($parts.Length -ge 2) { return $parts[1] }
    }
    return $null
}

$HitDate = @{}
$HitFp = @{}

# speckit: specs/ AND .specify/
if ((git ls-tree HEAD --name-only -- specs .specify 2>$null).Count -ge 2) {
    $d = Get-CommitDateForPath "specs .specify"
    if ($d) { $HitDate["speckit"] = $d; $HitFp["speckit"] = "specs .specify" }
}

# superpowers: docs/superpowers/plans/
$sp = git ls-tree HEAD --name-only -- docs/superpowers/plans 2>$null
if ($sp) {
    $d = Get-CommitDateForPath "docs/superpowers/plans"
    if ($d) { $HitDate["superpowers"] = $d; $HitFp["superpowers"] = "docs/superpowers/plans" }
}

# addy: CONSTRAINTS.md AND references/
if ((git ls-tree HEAD --name-only -- CONSTRAINTS.md references 2>$null).Count -ge 2) {
    $d = Get-CommitDateForPath "CONSTRAINTS.md references"
    if ($d) { $HitDate["addy"] = $d; $HitFp["addy"] = "CONSTRAINTS.md references" }
}

# matt: spec issues via /to-spec in docs/*.md
$mattFile = git grep -l --cached -e '/to-spec' -- 'docs/*.md' 2>$null | Select-Object -First 1
if ($mattFile) {
    $d = Get-CommitDateForPath $mattFile
    if ($d) { $HitDate["matt"] = $d; $HitFp["matt"] = $mattFile }
}

$Best = $null
$BestDate = $null
foreach ($lane in @("speckit", "superpowers", "addy", "matt")) {
    if ($HitDate.ContainsKey($lane)) {
        $candDate = $HitDate[$lane]
        if (-not $Best -or [string]::Compare($candDate, $BestDate, [System.StringComparison]::Ordinal) -gt 0) {
            $Best = $lane
            $BestDate = $candDate
        }
    }
}

if ($Best) {
    foreach ($lane in @("speckit", "superpowers", "addy", "matt")) {
        if ($lane -ne $Best -and $HitDate.ContainsKey($lane)) {
            [Console]::Error.WriteLine("conflict: $lane evidence ($($HitFp[$lane])) at $($HitDate[$lane]) superseded by $Best at $BestDate")
        }
    }
    Write-Output "$Best usage:$($HitFp[$Best])"
    exit 0
}

# Installed packs
function Map-PackToLane([string]$Pack) {
    if ($Pack -match 'spec-kit|speckit') { return "speckit" }
    if ($Pack -match 'superpowers') { return "superpowers" }
    if ($Pack -match 'addy|agent-skills') { return "addy" }
    if ($Pack -match 'matt|pocock') { return "matt" }
    return $null
}

if (Test-Path ".agents/skills") {
    $packs = git ls-tree HEAD --name-only -- .agents/skills/ 2>$null | ForEach-Object { $_ -replace '^\.agents/skills/', '' }
    if (-not $packs) { $packs = Get-ChildItem -Directory ".agents/skills" 2>$null | Select-Object -ExpandProperty Name }
    $newestPack = $null
    $newestLane = $null
    $newestDate = $null
    foreach ($p in $packs) {
        $lane = Map-PackToLane $p
        if (-not $lane) { continue }
        $d = Get-CommitDateForPath ".agents/skills/$p"
        if (-not $d) { continue }
        if (-not $newestPack -or [string]::Compare($d, $newestDate, [System.StringComparison]::Ordinal) -gt 0) {
            $newestPack = $p
            $newestLane = $lane
            $newestDate = $d
        }
    }
    if ($newestPack) {
        Write-Output "$newestLane installed:$newestPack"
        exit 0
    }
}

Write-Output "embedded default"
