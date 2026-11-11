#!/usr/bin/env pwsh
# synthesize-findings.ps1 — deterministic synthesis of adversarial review
# findings (PowerShell twin of bash/synthesize-findings.sh). One behavior,
# two platform scripts; keep in lockstep.
#
# Reads findings JSON (file arg or stdin) shaped like:
# {"findings":[{"id":"F1","reports":["Auditor","Adversary"],
# "validations":[],"challenges":[],"adds":[]}, ...]}
# writes tags JSON to stdout. Deterministic: same input -> byte-identical
# output. Counting rule: >=2 *distinct* reporters -> cross-validated; 1
# report + >=1 validate from a *different* persona (no challenge) ->
# consensus; 1 report + >=1 challenge -> disputed; else solo.
# Round-2 `add` moves arrive as separate findings with the adder in
# `reports`; the script never invents findings — every `add` is already a
# record.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("synthesize-findings: $Message")
    exit 2
}

if ($args.Count -eq 1 -and ($args[0] -eq '-h' -or $args[0] -eq '--help')) {
    Write-Output @'
synthesize-findings.ps1 — deterministic synthesis of adversarial review findings

Usage:
  synthesize-findings.ps1 [findings.json | -]     # - or no arg reads stdin

Reads {"findings":[{"id","reports","validations","challenges"}, ...]},
writes {"tags":[{"id","tag"}]} to stdout. Tags: cross-validated (>=2
distinct reporters), consensus (1 report + validate from a different
persona, no challenge), disputed (1 report + challenge), solo.
'@
    exit 0
}
if ($args.Count -gt 1) { Die 'expected at most one findings JSON path' }

$src = if ($args.Count -eq 1) { [string]$args[0] } else { '-' }
$raw = $null
if ($src -ne '-') {
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { Die "no such file: $src" }
    $raw = Get-Content -Raw -LiteralPath $src
} else {
    $raw = [Console]::In.ReadToEnd()
}

try { $data = $raw | ConvertFrom-Json -Depth 30 } catch { Die "invalid findings JSON: $($_.Exception.Message)" }
if ($null -eq $data -or $data -isnot [psobject] -or $data -is [array] -or $null -eq $data.findings -or $data.findings -isnot [array]) {
    Die 'expected {"findings": [...]}'
}
foreach ($f in $data.findings) {
    if ($null -eq $f -or $f -isnot [psobject]) { Die 'every finding must be an object' }
}

# Distinct reporter/validator names from a reports-like value. Non-list
# input (e.g. a string) yields an empty set, so malformed records fall
# through to `solo` instead of being length-counted.
function Get-Personas($Value) {
    if ($null -eq $Value -or $Value -isnot [array]) { return @() }
    return @($Value | Where-Object { $_ -is [string] -and $_ -ne '' } | Select-Object -Unique)
}

function Get-Tag($Finding) {
    $reports = Get-Personas $Finding.reports
    $validations = Get-Personas $Finding.validations
    $challenges = $Finding.challenges
    if (-not $challenges) { $challenges = @() }
    elseif ($challenges -isnot [array]) { $challenges = @($challenges) }
    if ($reports.Count -ge 2) { return 'cross-validated' }
    if ($reports.Count -eq 1 -and $challenges.Count -gt 0) { return 'disputed' }
    if ($reports.Count -eq 1) {
        foreach ($v in $validations) {
            if ($reports -notcontains $v) { return 'consensus' }
        }
    }
    return 'solo'
}

$tags = [System.Collections.Generic.List[object]]::new()
foreach ($f in $data.findings) {
    $idProp = $f.PSObject.Properties['id']
    # python's f.get("id", "") — missing key yields "", an explicit null stays null
    $id = if ($null -ne $idProp) { $idProp.Value } else { '' }
    $tags.Add([ordered]@{ id = $id; tag = (Get-Tag $f) })
}
Write-Output (([ordered]@{ tags = $tags }) | ConvertTo-Json -Depth 10 -Compress)
