#!/usr/bin/env pwsh
# Setup-SddDocsPublish.ps1 — Setup for sdd-docs-publish (self-contained)
$ErrorActionPreference = "Stop"

$JsonMode = $false
foreach ($arg in $args) {
  if ($arg -eq "--json") { $JsonMode = $true }
}

function Resolve-ProjectRoot {
  $dir = (Get-Location).Path
  while ($dir -ne "" -and $dir -ne "/") {
    if (Test-Path (Join-Path $dir ".adlc")) { return $dir }
    $parent = Split-Path $dir -Parent
    if ($parent -eq $dir) { break }
    $dir = $parent
  }
  $gitRoot = git rev-parse --show-toplevel 2>$null
  if ($gitRoot) { return $gitRoot }
  return (Get-Location).Path
}

function Resolve-SddDocsLocation {
  param([string]$ProjectRoot)
  $loc = $env:SDD_DOCS_LOCATION
  if ($loc) { return $loc }
  $initOpts = Join-Path $ProjectRoot ".adlc" "init-options.json"
  if (Test-Path $initOpts) {
    try {
      $config = Get-Content $initOpts -Raw | ConvertFrom-Json
      if ($config.sdd_docs_location) { return $config.sdd_docs_location }
    } catch {}
  }
  return ""
}

function Get-SddProjectSubfolderName {
  param([string]$ProjectRoot)
  try {
    $commonDir = git -C $ProjectRoot rev-parse --git-common-dir 2>$null
    if ($commonDir) {
      return Split-Path (Resolve-Path (Join-Path (Split-Path $commonDir -Parent) .) -ErrorAction SilentlyContinue).Path -Leaf
    }
  } catch {}
  return Split-Path $ProjectRoot -Leaf
}

$ProjectRoot = Resolve-ProjectRoot
$SddDocsLocation = Resolve-SddDocsLocation -ProjectRoot $ProjectRoot
$ProjectSubfolder = Get-SddProjectSubfolderName -ProjectRoot $ProjectRoot

if ($SddDocsLocation) {
  if ($SddDocsLocation.StartsWith("~")) {
    $SddDocsLocation = Join-Path $env:HOME $SddDocsLocation.Substring(1).TrimStart("/", "\")
  }
  $SddRoot = Join-Path $SddDocsLocation.TrimEnd("/", "\") $ProjectSubfolder
  $SddConfigured = "true"
} else {
  $SddRoot = $ProjectRoot
  $SddConfigured = "false"
}

$SddIsGit = "false"
$SddClean = "false"
if ($SddConfigured -eq "true") {
  $gitCheck = git -C $SddDocsLocation rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -eq 0) {
    $SddIsGit = "true"
    $status = git -C $SddDocsLocation status --porcelain 2>$null
    if (-not $status) { $SddClean = "true" }
  }
}

$result = @{
  REPO_ROOT = $ProjectRoot
  SDD_DOCS_LOCATION = $SddDocsLocation
  SDD_ROOT = $SddRoot
  PROJECT_SUBFOLDER = $ProjectSubfolder
  SDD_CONFIGURED = ($SddConfigured -eq "true")
  SDD_IS_GIT = ($SddIsGit -eq "true")
  SDD_CLEAN = ($SddClean -eq "true")
}

$result | ConvertTo-Json -Compress
