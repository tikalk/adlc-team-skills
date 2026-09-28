#!/usr/bin/env pwsh
# team-helpers.ps1 — Compatibility shim. Prefer team-paths / team-scaffold / team-validate.
param(
  [switch]$Json,
  [string]$Scaffold = "",
  [string]$AgentsOnly = "",
  [string]$InjectAgents = "",
  [string]$Name = "My Team"
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "team-paths.ps1")
. (Join-Path $ScriptDir "team-validate.ps1")
. (Join-Path $ScriptDir "team-scaffold.ps1")

$isDirect = $MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.'
if ($isDirect -and $PSCommandPath -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
  if ($Scaffold -or $AgentsOnly -or ($InjectAgents -ne "")) {
    & (Join-Path $ScriptDir "team-scaffold.ps1") -Scaffold $Scaffold -AgentsOnly $AgentsOnly -InjectAgents $InjectAgents -Name $Name
  } else {
    & (Join-Path $ScriptDir "team-paths.ps1") -Json:$Json
  }
}
