#!/usr/bin/env pwsh
# Compatibility wrapper — delegates to shared team helpers.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir ".." "team-helpers.ps1") @args
