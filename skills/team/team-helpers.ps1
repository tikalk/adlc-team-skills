#!/usr/bin/env pwsh
# team-helpers.ps1 — Shared utilities for team-* skills (PowerShell)
#
# Flags:
#   -Json              Output path info as JSON (default: key=value)
#   -Scaffold DIR      Create a fresh 11-file team AI directives scaffold at DIR
#   -AgentsOnly DIR    Create only AGENTS.md at DIR (for repair use)
#   -Name NAME         Team name for scaffold (default: "My Team")
param(
  [switch]$Json,
  [string]$Scaffold = "",
  [string]$AgentsOnly = "",
  [string]$Name = "My Team"
)

$ErrorActionPreference = "Stop"

# 1. PATH RESOLUTION
$ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
  $gitRoot = git rev-parse --show-toplevel 2>$null
  if ($gitRoot) { $gitRoot } else { (Get-Location).Path }
}

$Branch = if ($env:BRANCH) { $env:BRANCH } else {
  $b = git branch --show-current 2>$null
  if ($b) { $b } else { "unknown" }
}

$TeamAiDirective = ""

# 1. Check TEAM_AI_DIRECTIVE env var (highest priority)
if ($env:TEAM_AI_DIRECTIVE) {
  $TeamAiDirective = $env:TEAM_AI_DIRECTIVE
}

# 2. Check .adlc/init-options.json
if (-not $TeamAiDirective) {
  $InitOptions = Join-Path $ProjectRoot ".adlc" "init-options.json"
  if (Test-Path $InitOptions) {
    try {
      $Config = Get-Content $InitOptions -Raw | ConvertFrom-Json
      if ($Config.team_ai_directive) {
        $TeamAiDirective = $Config.team_ai_directive
      }
    } catch {}
  }
}

# 3. Fallback to default path
if (-not $TeamAiDirective) {
  $TeamAiDirective = Join-Path $ProjectRoot "team-ai-directives"
}

function Write-OutputKeyValue {
  Write-Output "PROJECT_ROOT=$ProjectRoot"
  Write-Output "TEAM_AI_DIRECTIVE=$TeamAiDirective"
  Write-Output "BRANCH=$Branch"
}

function Write-OutputJson {
  $output = @{
    REPO_ROOT = $ProjectRoot
    TEAM_AI_DIRECTIVE = $TeamAiDirective
    BRANCH = $Branch
  }
  return $output | ConvertTo-Json
}

# 2. TEAM AI DIRECTIVES STRUCTURE VALIDATION
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

# 3. SCAFFOLD
function New-TeamAiDirectivesScaffold {
  param([string]$Dest, [string]$TeamName = "My Team")
  $today = Get-Date -Format "yyyy-MM-dd"

  if ((Test-Path $Dest) -and (Get-ChildItem $Dest -Force).Count -gt 0) {
    Write-Error "Destination '$Dest' already exists and is not empty."
    exit 1
  }

  $null = New-Item -ItemType Directory -Force -Path (Join-Path $Dest "context_modules/rules")
  $null = New-Item -ItemType Directory -Force -Path (Join-Path $Dest "context_modules/personas")
  $null = New-Item -ItemType Directory -Force -Path (Join-Path $Dest "context_modules/examples")
  $null = New-Item -ItemType Directory -Force -Path (Join-Path $Dest "skills")

  $readme = @"
# ${TeamName} Team AI Directives

Team AI directives repository for ${TeamName}.

## Getting Started

1. Initialize a project with this directives repository:
   ```
   specify init my-project --team-ai-directives ./path/to/this/dir
   ```

2. Add context modules to `context_modules/` (rules, personas, examples).

3. Add skills to `skills/`.

4. Update `CDR.md` as context modules are approved.

See [Agentic SDLC Spec Kit](https://github.com/tikalk/agentic-sdlc-spec-kit) for full documentation.
"@
  Set-Content -Path (Join-Path $Dest "README.md") -Value $readme

  $agents = @'
# Agent Instructions

## Structure

- `context_modules/constitution.md` — Team constitution
- `context_modules/rules/` — Team rules and workflows
- `context_modules/personas/` — Team personas
- `context_modules/examples/` — Team examples
- `skills/` — Team skills
- `traces/` — Published session traces (from `/levelup-publish`)
- `CDR.md` — Context Directive Records

## Loading Order

1. Load constitution.md first
2. Load relevant rules for the current task
3. Load relevant personas for the current task
4. Load relevant examples for the current task

## Using Skills

Skills are located in the `skills/` directory. Browse available skills using team-skills and install them as needed.

## CDR.md

The CDR.md file tracks approved context contributions. Update it when adding new context modules.
'@
  Set-Content -Path (Join-Path $Dest "AGENTS.md") -Value $agents

  $cdr = @"
# Context Directive Records

Context Directive Records (CDRs) track decisions about contributing context modules (rules, personas, examples, skills) to team-ai-directives.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|

**Stats**: 0 entries | Last Updated: ${today}
"@
  Set-Content -Path (Join-Path $Dest "CDR.md") -Value $cdr

  $skillsJson = @'
{
  "schema_version": "2.0.0",
  "default": [],
  "skills": {},
  "external": {}
}
'@
  Set-Content -Path (Join-Path $Dest ".skills.json") -Value $skillsJson

  $mcpJson = @'
{
  "mcpServers": {}
}
'@
  Set-Content -Path (Join-Path $Dest ".mcp.json.example") -Value $mcpJson

  $constitution = @"
---
type: Constitution
title: "${TeamName} Constitution"
description: "Team-wide principles and governance"
resource: ./context_modules/constitution.md
tags: [constitution]
timestamp: ${today}T00:00:00Z
---

# ${TeamName} Constitution

No team-wide principles defined yet. Add principles as they are established.
"@
  Set-Content -Path (Join-Path $Dest "context_modules/constitution.md") -Value $constitution

  $indexTop = @"
# Context Modules

| Directory | Description |
|-----------|-------------|
| [rules/](rules/index.md) | Team rules and workflows |
| [personas/](personas/index.md) | Team personas |
| [examples/](examples/index.md) | Team examples |
"@
  Set-Content -Path (Join-Path $Dest "context_modules/index.md") -Value $indexTop

  Set-Content -Path (Join-Path $Dest "context_modules/rules/index.md") -Value "# Rules`n`nNo rules defined yet. Use /levelup-specify to create rules via CDRs."
  Set-Content -Path (Join-Path $Dest "context_modules/personas/index.md") -Value "# Personas`n`nNo personas defined yet. Use /levelup-specify to create personas via CDRs."
  Set-Content -Path (Join-Path $Dest "context_modules/examples/index.md") -Value "# Examples`n`nNo examples defined yet. Use /levelup-specify to create examples via CDRs."

  $null = New-Item -ItemType File -Force -Path (Join-Path $Dest "context_modules/rules/.gitkeep")
  $null = New-Item -ItemType File -Force -Path (Join-Path $Dest "context_modules/personas/.gitkeep")
  $null = New-Item -ItemType File -Force -Path (Join-Path $Dest "context_modules/examples/.gitkeep")
  $null = New-Item -ItemType File -Force -Path (Join-Path $Dest "skills/.gitkeep")

  Write-Output "Scaffolded team-ai-directives at ${Dest}"
  Write-Output "Team name: ${TeamName}"
  Write-Output "Files created: 14"

  $missing = Test-TeamAiDirectivesStructure -Dir $Dest
  if ($missing -gt 0) {
    Write-Output "WARNING: $missing required items missing"
  }
}

function New-AgentsOnly {
  param([string]$Dest)
  $null = New-Item -ItemType Directory -Force -Path $Dest

  $agents = @'
# Agent Instructions

## Structure

- `context_modules/constitution.md` — Team constitution
- `context_modules/rules/` — Team rules and workflows
- `context_modules/personas/` — Team personas
- `context_modules/examples/` — Team examples
- `skills/` — Team skills
- `traces/` — Published session traces (from `/levelup-publish`)
- `CDR.md` — Context Directive Records

## Loading Order

1. Load constitution.md first
2. Load relevant rules for the current task
3. Load relevant personas for the current task
4. Load relevant examples for the current task

## Using Skills

Skills are located in the `skills/` directory. Browse available skills using team-skills and install them as needed.

## CDR.md

The CDR.md file tracks approved context contributions. Update it when adding new context modules.
'@
  Set-Content -Path (Join-Path $Dest "AGENTS.md") -Value $agents
  Write-Output "Created AGENTS.md at ${Dest}"
}

# MAIN
if ($Scaffold) {
  New-TeamAiDirectivesScaffold -Dest $Scaffold -TeamName $Name
} elseif ($AgentsOnly) {
  New-AgentsOnly -Dest $AgentsOnly
} elseif ($Json) {
  Write-OutputJson
} else {
  Write-OutputKeyValue
}
