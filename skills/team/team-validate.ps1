#!/usr/bin/env pwsh
# team-validate.ps1 — Structure checks for team AI directives.
param([string]$Dir = "")
$ErrorActionPreference = "Stop"

function Test-TeamAiDirectivesStructure {
  param([string]$Dir)
  $missing = 0
  $required = @(
    "context_modules/constitution.md",
    "context_modules/rules",
    "context_modules/personas",
    "context_modules/examples",
    "CDR.md",
    ".skills.json"
  )
  foreach ($item in $required) {
    $path = Join-Path $Dir $item
    if (-not (Test-Path $path)) {
      Write-Output "MISSING: $item"
      $missing++
    }
  }
  return $missing
}

$isDirect = $MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.'
if ($isDirect -and $PSCommandPath -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
  if (-not $Dir) { Write-Error "Usage: team-validate.ps1 -Dir <path>"; exit 1 }
  $missing = Test-TeamAiDirectivesStructure -Dir $Dir
  if ($missing -eq 0) { Write-Output "OK: team AI directives structure valid at $Dir" }
  else { Write-Error "INVALID: $missing required path(s) missing under $Dir"; exit $missing }
}
