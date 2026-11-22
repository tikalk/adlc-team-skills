#!/usr/bin/env pwsh
# merge-risk.ps1 — deterministic merge-risk scorer (PowerShell twin of
# merge-risk.sh). Same arg interface, same band math, no LLM, no network.
#
# Usage:
#   merge-risk.ps1 --verification <poor|decent|good> --alignment <...> `
#     --impact <...> --rollback <...> --error-detection <...>
# Prints the per-category echo plus `Merge risk: <low|medium|high>`.
# The numeric score stays internal (deliberately unprinted).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$msg) { [Console]::Error.WriteLine("merge-risk: $msg"); exit 2 }

function ScoreOf([string]$value, [string]$flag) {
    switch ($value) {
        'poor' { return 1 }
        'decent' { return 2 }
        'good' { return 3 }
        default { Fail "$flag must be poor|decent|good, got '$value'" }
    }
    return 0
}

$verification = ''; $alignment = ''; $impact = ''; $rollback = ''; $errorDetection = ''
$i = 0
while ($i -lt $args.Count) {
    $flag = [string]$args[$i]
    if ($flag -eq '--help' -or $flag -eq '-h') {
        Write-Output 'usage: merge-risk.ps1 --verification <poor|decent|good> --alignment <...> --impact <...> --rollback <...> --error-detection <...>'
        exit 0
    }
    $val = if ($i + 1 -lt $args.Count) { [string]$args[$i + 1] } else { '' }
    if ($val -eq '' -or $val.StartsWith('--')) { Fail "$flag requires a value" }
    switch ($flag) {
        '--verification' { $verification = $val; $i += 2 }
        '--alignment' { $alignment = $val; $i += 2 }
        '--impact' { $impact = $val; $i += 2 }
        '--rollback' { $rollback = $val; $i += 2 }
        '--error-detection' { $errorDetection = $val; $i += 2 }
        default { Fail "unknown argument '$flag'" }
    }
}

if ([string]::IsNullOrEmpty($verification)) { Fail '--verification is required' }
if ([string]::IsNullOrEmpty($alignment)) { Fail '--alignment is required' }
if ([string]::IsNullOrEmpty($impact)) { Fail '--impact is required' }
if ([string]::IsNullOrEmpty($rollback)) { Fail '--rollback is required' }
if ([string]::IsNullOrEmpty($errorDetection)) { Fail '--error-detection is required' }

$sv = ScoreOf $verification '--verification'
$sa = ScoreOf $alignment '--alignment'
$si = ScoreOf $impact '--impact'
$sr = ScoreOf $rollback '--rollback'
$se = ScoreOf $errorDetection '--error-detection'

# Weighted score x15 denominator as integer: (4sv+2sa+4si+3sr+2se)/15.
# Bands (lower score = higher risk): high num<=22, medium 23..33, low num>=34.
$num = 4 * $sv + 2 * $sa + 4 * $si + 3 * $sr + 2 * $se

"verification: $verification"
"alignment: $alignment"
"impact: $impact"
"rollback: $rollback"
"error-detection: $errorDetection"

if ($num -le 22) { 'Merge risk: high' }
elseif ($num -le 33) { 'Merge risk: medium' }
else { 'Merge risk: low' }
