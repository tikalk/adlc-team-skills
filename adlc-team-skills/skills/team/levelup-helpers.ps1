#!/usr/bin/env pwsh
# levelup-helpers.ps1 — Shared utilities for levelup-* skills (PowerShell)
#
# Flags:
#   -Json              Output path/state info as JSON
#   -NextCdr [DIR]    Print next CDR number
#   -Index [DIR]      Regenerate cdr.md index
#   -SignalGate FILE  Validate single CDR file against signal gate
#   -Conflicts [DIR]  Scan rules directory for conflicts
param(
  [switch]$Json,
  [string]$NextCdr = "",
  [string]$Index = "",
  [string]$SignalGate = "",
  [string]$Conflicts = ""
)

$ErrorActionPreference = "Stop"

# Path resolution
$projectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
  $gitRoot = git rev-parse --show-toplevel 2>$null
  if ($gitRoot) { $gitRoot } else { (Get-Location).Path }
}

$branch = if ($env:BRANCH) { $env:BRANCH } else {
  $b = git branch --show-current 2>$null
  if ($b) { $b } else { "unknown" }
}

$teamDirectives = ""
if ($env:ADLC_TEAM_AI_DIRECTIVES) {
  $teamDirectives = $env:ADLC_TEAM_AI_DIRECTIVES
}
if (-not $teamDirectives) {
  $initOptions = Join-Path $projectRoot ".adlc" "init-options.json"
  if (Test-Path $initOptions) {
    try {
      $config = Get-Content $initOptions -Raw | ConvertFrom-Json
      if ($config.team_ai_directives) {
        $teamDirectives = $config.team_ai_directives
      }
    } catch {}
  }
}
if (-not $teamDirectives) {
  $teamDirectives = Join-Path $projectRoot ".adlc" "team-ai-directives"
}

$cdrDraftsDir = Join-Path $projectRoot ".adlc" "drafts" "cdr"
$cdrIndexFile = Join-Path $cdrDraftsDir "cdr.md"
$skillsDraftsDir = Join-Path $projectRoot ".adlc" "drafts" "skills"
$levelupStateFile = Join-Path $projectRoot ".adlc" "levelup" "state.json"

function Write-OutputJson {
  $output = @{
    REPO_ROOT = $projectRoot
    TEAM_DIRECTIVES = $teamDirectives
    BRANCH = $branch
    CDR_DRAFTS_DIR = $cdrDraftsDir
    CDR_INDEX_FILE = $cdrIndexFile
    SKILLS_DRAFTS_DIR = $skillsDraftsDir
    LEVELUP_STATE_FILE = $levelupStateFile
  }
  return $output | ConvertTo-Json
}

function Get-NextCdrNumber {
  param([string]$Dir)
  if (-not $Dir) { $Dir = $cdrDraftsDir }
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  $max = 0
  Get-ChildItem -Path $Dir -Filter "CDR-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.BaseName -match '^CDR-(\d+)$') {
      $num = [int]$matches[1]
      if ($num -gt $max) { $max = $num }
    }
  }
  return "{0:D3}" -f ($max + 1)
}

function Invoke-SignalGate {
  param([string]$File)
  $reasons = @()
  $content = Get-Content $File -Raw -ErrorAction SilentlyContinue
  if ($content -match 'project-specific|only applies to this project|single project') {
    $reasons += "project-specific"
  }
  if ($content -match 'duplicate of|overlaps with existing|already in team-ai-directives') {
    $reasons += "duplicate"
  }
  if ($content -notmatch '(src/|lib/|test/|docs/|commit|file)') {
    $reasons += "no evidence"
  }
  if ($content -match 'low value|nice-to-have|minor convenience') {
    $reasons += "low value"
  }
  if ($reasons.Count -gt 0) {
    return "SKIP: $($reasons -join ' ')"
  }
  return "PASS"
}

function Invoke-ConflictScan {
  param([string]$RulesDir)
  if (-not $RulesDir) { $RulesDir = Join-Path $teamDirectives "context_modules" "rules" }
  if (-not (Test-Path $RulesDir)) { return "[]" }

  $rules = Get-ChildItem -Path $RulesDir -Filter "*.md" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $m = [regex]::Match($content, "^#\s+(.+)$", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    @{ file = (Resolve-Path -Relative -Path $_.FullName).Substring(2); statement = if ($m.Success) { $m.Groups[1].Value.Trim() } else { "" }; content = $content }
  }

  $conflicts = @()
  $opposites = @(@("must", "never"), @("always", "never"), @("require", "forbid"), @("allow", "prohibit"))
  for ($i = 0; $i -lt $rules.Count; $i++) {
    for ($j = $i + 1; $j -lt $rules.Count; $j++) {
      $s1 = $rules[$i].statement.ToLower()
      $s2 = $rules[$j].statement.ToLower()
      foreach ($pair in $opposites) {
        $a = $pair[0]; $b = $pair[1]
        if (($s1.Contains($a) -and $s2.Contains($b)) -or ($s1.Contains($b) -and $s2.Contains($a))) {
          $conflicts += @{
            type = "direct_contradiction"
            rule_a = $rules[$i].file
            rule_b = $rules[$j].file
            hint = "'$a' vs '$b'"
          }
        }
      }
    }
  }
  return $conflicts | ConvertTo-Json
}

if ($Json) {
  Write-Output (Write-OutputJson)
} elseif ($NextCdr -ne "") {
  Write-Output (Get-NextCdrNumber -Dir $NextCdr)
} elseif ($Index -ne "") {
  New-Item -ItemType Directory -Force -Path $Index | Out-Null
  $today = Get-Date -Format "yyyy-MM-dd"
  $lines = @(
    "# Context Directive Records"
    ""
    "Context Directive Records (CDRs) track proposed and accepted contributions to team-ai-directives."
    ""
    "## CDR Index"
    ""
    "| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |"
    "|----|---------------|------|--------|---------|----------|-----|------------|"
  )
  $count = 0
  Get-ChildItem -Path $Index -Filter "CDR-*.md" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
    $count++
    $id = $_.BaseName
    $content = Get-Content $_.FullName -Raw
    $target = if ($content -match '### Target Module\s*\n\s*`?([^`\n]+)') { $matches[1].Trim() } else { "" }
    $type = if ($content -match '### Context Type\s*\n\s*(.+)') { $matches[1].Trim() } else { "" }
    $status = if ($content -match '### Status\s*\n\s*\*\*(.+?)\*\*') { $matches[1].Trim() } else { "Discovered" }
    $date = if ($content -match '### Date\s*\n\s*(.+)') { $matches[1].Trim() } else { $today }
    $verified = if ($content -match 'verified:\s*(.+)') { $matches[1].Trim() } else { "-" }
    $age = if ($content -match 'age_days:\s*(.+)') { $matches[1].Trim() } else { "-" }
    $descriptor = if ($content -match '### Descriptor\s*\n\s*(.+)') { $matches[1].Trim() } else { "" }
    $lines += "| $id | $target | $type | $status | $date | $verified | $age | $descriptor |"
  }
  $lines += ""
  $lines += "**Stats**: $count entries | Last Updated: $today"
  $indexPath = if ($Index -eq $cdrDraftsDir) { $cdrIndexFile } else { Join-Path $Index "cdr.md" }
  $lines | Set-Content -Path $indexPath
  Write-Output $indexPath
} elseif ($SignalGate -ne "") {
  Write-Output (Invoke-SignalGate -File $SignalGate)
} elseif ($Conflicts -ne "") {
  Write-Output (Invoke-ConflictScan -RulesDir $Conflicts)
} else {
  Write-Output (Write-OutputJson)
}
