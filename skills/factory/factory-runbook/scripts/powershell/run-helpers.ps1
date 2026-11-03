#!/usr/bin/env pwsh
# run-helpers.ps1 — run factory-runbook helpers in order (PowerShell twin of
# run-helpers.sh).
#
# Usage: run-helpers.ps1 <label> <helper> [<helper> ...]
#
# A helper may be named with its bash name (run-branch.sh) or its own
# (run-branch.ps1); either resolves to the .ps1 next to this script. A missing
# helper FAILS the step (exit 1, reason on stderr), never "skipped". A
# helper's own non-zero exit is the step's exit code. Helpers inherit the
# environment (ADLC_RUN_ID, ADLC_ISSUE_REF, ADLC_STEP_OUTPUT).

$ErrorActionPreference = 'Stop'

if ($args.Count -lt 2) {
    [Console]::Error.WriteLine('usage: run-helpers.ps1 <label> <helper> [...]')
    exit 2
}
$label = [string]$args[0]
$here = $PSScriptRoot

foreach ($raw in $args[1..($args.Count - 1)]) {
    $name = [string]$raw
    if ($name -eq '' -or $name.Contains('/') -or $name.Contains('\') -or $name.StartsWith('.')) {
        [Console]::Error.WriteLine("${label}: invalid helper name '$name'")
        exit 2
    }
    $base = [IO.Path]::GetFileNameWithoutExtension($name)
    $helper = Join-Path $here "$base.ps1"
    if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
        [Console]::Error.WriteLine("${label}: $base.ps1 not found in $here (factory-runbook skill incomplete)")
        exit 1
    }
    & pwsh -NoProfile -File $helper
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
