#!/usr/bin/env pwsh
# team-helpers.ps1 — Shared utilities for team-* skills (PowerShell)
#
# Flags:
#   -Json              Output path info as JSON (default: key=value)
#   -Scaffold DIR      Create a fresh 11-file team AI directives scaffold at DIR
#   -AgentsOnly DIR    Create only AGENTS.md at DIR (for repair use)
#   -InjectAgents DIR  Inject team-boot directive into project-level AGENTS.md at DIR
#   -Name NAME         Team name for scaffold (default: "My Team")
#
# Library functions (sourced by other skills' setup scripts, not CLI flags):
#   Resolve-SddDocsLocation, Get-SddProjectSubfolderName, Invoke-GitPublishWorkflow
param(
  [switch]$Json,
  [string]$Scaffold = "",
  [string]$AgentsOnly = "",
  [string]$InjectAgents = "",
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

$TeamAiDirectives = ""

# 1. Check TEAM_AI_DIRECTIVES env var (highest priority)
if ($env:TEAM_AI_DIRECTIVES) {
  $TeamAiDirectives = $env:TEAM_AI_DIRECTIVES
}

# 2. Check .adlc/init-options.json
if (-not $TeamAiDirectives) {
  $InitOptions = Join-Path $ProjectRoot ".adlc" "init-options.json"
  if (Test-Path $InitOptions) {
    try {
      $Config = Get-Content $InitOptions -Raw | ConvertFrom-Json
      if ($Config.team_ai_directives) {
        $TeamAiDirectives = $Config.team_ai_directives
      }
    } catch {}
  }
}

# 3. Fallback to default path
if (-not $TeamAiDirectives) {
  $TeamAiDirectives = Join-Path $ProjectRoot "team-ai-directives"
}

function Write-OutputKeyValue {
  param([string]$SddDocsLocation = "")
  Write-Output "PROJECT_ROOT=$ProjectRoot"
  Write-Output "TEAM_AI_DIRECTIVES=$TeamAiDirectives"
  Write-Output "BRANCH=$Branch"
  Write-Output "SDD_DOCS_LOCATION=$SddDocsLocation"
}

function Write-OutputJson {
  param([string]$SddDocsLocation = "")
  $output = @{
    REPO_ROOT = $ProjectRoot
    TEAM_AI_DIRECTIVES = $TeamAiDirectives
    BRANCH = $Branch
    SDD_DOCS_LOCATION = $SddDocsLocation
  }
  return $output | ConvertTo-Json
}

function Resolve-SddDocsLocation {
  param([string]$ProjectRoot = $ProjectRoot)
  $sddDocsLocation = ""

  # 1. Environment variable (highest priority)
  if ($env:SDD_DOCS_LOCATION) {
    $sddDocsLocation = $env:SDD_DOCS_LOCATION
  }

  # 2. .adlc/init-options.json
  if (-not $sddDocsLocation) {
    $initOptions = Join-Path $ProjectRoot ".adlc" "init-options.json"
    if (Test-Path $initOptions) {
      try {
        $config = Get-Content $initOptions -Raw | ConvertFrom-Json
        if ($config.sdd_docs_location) {
          $sddDocsLocation = $config.sdd_docs_location
        }
      } catch {}
    }
  }

  # 3. Default empty (project root)
  return $sddDocsLocation
}

function Get-SddProjectSubfolderName {
  param([string]$ProjectRoot = $ProjectRoot)
  $commonDir = $null
  try {
    $commonDir = git -C $ProjectRoot rev-parse --git-common-dir 2>$null
  } catch {}
  if ($commonDir) {
    return (Split-Path (Resolve-Path (Join-Path $commonDir "..")).Path -Leaf)
  }
  return (Split-Path $ProjectRoot -Leaf)
}

function Resolve-SddRoot {
  param([string]$ProjectRoot = $ProjectRoot)
  $sddDocsLocation = Resolve-SddDocsLocation -ProjectRoot $ProjectRoot

  if ($sddDocsLocation) {
    # Expand tilde to $HOME
    if ($sddDocsLocation.StartsWith("~")) {
      $sddDocsLocation = Join-Path $env:HOME $sddDocsLocation.Substring(1).TrimStart("/", "\")
    }
    $projectSubfolder = Get-SddProjectSubfolderName -ProjectRoot $ProjectRoot
    return (Join-Path $sddDocsLocation.TrimEnd("/", "\") $projectSubfolder)
  } else {
    return $ProjectRoot
  }
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

1. Wire this directives repository into a project:
   ```
   /team-setup
   ```
   Choose "Point to existing local path" and select this directory.

2. Add context modules to `context_modules/` (rules, personas, examples).

3. Add skills to `skills/` and register them in `.skills.json`.

4. Update `CDR.md` as context modules are approved.

See [ADLC Team Skills](https://github.com/tikalk/adlc-team-skills) for full documentation.
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
- `evals/` — Directive compliance goldensets (pass/fail cases)
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
  "version": "2.0.0",
  "source": "team-ai-directives",
  "description": "Team skills manifest. The `default` list contains skill names that are auto-installed during project setup. The `external` map contains on-demand skills fetched by URL. The `blocked` list contains skills that must never be installed.",
  "default": [],
  "external": {},
  "blocked": [],
  "policy": {
    "auto_install_default": true,
    "enforce_blocked": true,
    "allow_project_override": true
  }
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
- `evals/` — Directive compliance goldensets (pass/fail cases)
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

# 4. INJECT PROJECT-LEVEL AGENTS.md DIRECTIVE
function Invoke-ProjectAgentsInjection {
  param([string]$ProjectRoot = ".")

  $TeamDirective = ""

  # Resolve team_ai_directives from .adlc/init-options.json
  $InitOptions = Join-Path $ProjectRoot ".adlc" "init-options.json"
  if (Test-Path $InitOptions) {
    try {
      $Config = Get-Content $InitOptions -Raw | ConvertFrom-Json
      if ($Config.team_ai_directives) {
        $TeamDirective = $Config.team_ai_directives
      }
    } catch {}
  }

  # Fallback to env var
  if (-not $TeamDirective -and $env:TEAM_AI_DIRECTIVES) {
    $TeamDirective = $env:TEAM_AI_DIRECTIVES
  }

  # Fallback to default path
  if (-not $TeamDirective) {
    $TeamDirective = Join-Path $ProjectRoot "team-ai-directives"
  }

  $AgentsFile = Join-Path $ProjectRoot "AGENTS.md"
  $MarkerStart = "<!-- TEAM_AI_DIRECTIVES START -->"
  $MarkerEnd = "<!-- TEAM_AI_DIRECTIVES END -->"

  $Section = @"
$MarkerStart
## Team Directives & Constitution

This project is bound by the team AI directives repository at ``$TeamDirective``.
- **Strict Compliance**: You MUST invoke the ``team-boot`` skill BEFORE responding to any task or question. This is not optional and applies to every interaction. If a skill applies, you MUST invoke it immediately.
- **First-Tool-Call Gate**: Your FIRST tool call in any session MUST be ``skill({name: "team-boot"})``. If your first tool call is ``read``, ``grep``, ``glob``, ``bash``, or any other tool, you have VIOLATED this directive -- stop and invoke ``team-boot`` before continuing. Mechanically verifiable in any trace.
- **Plan-Mode Compatibility**: Loading a skill is read-only -- it injects instructions, it does NOT modify files. Plan mode / read-only phase NEVER forbids the ``skill`` tool. Do not fabricate a conflict between plan mode and the skill check.
- **Anti-Patterns** (do NOT rationalize skipping the skill check):
  - "Let me explore the codebase first" -> Skills tell you HOW to explore. Check first.
  - "This is a plain message, not a spec command" -> Skill check applies to EVERY interaction.
  - "I'll check after understanding the request" -> Check BEFORE understanding -- skills guide your questions.
  - "This is too simple" -> Simple things become complex. Check first.
  - "Plan mode forbids modifications" -> The ``skill`` tool is read-only; plan mode never forbids it.
  - "I need to be efficient / focus on the task" -> The check IS the first step, not overhead to optimize away.
  - "The task matters more than the check" -> The check IS part of the task; skipping it is a violation.
- **Team Constitution**: Read and strictly adhere to the principles in ``$TeamDirective/context_modules/constitution.md``. When creating or updating the project's constitution, you MUST inherit and align with these principles.
- **Rules, Personas & Examples**: Use the ``team-discover`` skill to find and load relevant rules, personas, or examples before making changes.
- **Tech Radar Guidance**: Use the ``tech-radar-context`` skill whenever evaluating or choosing technologies, frameworks, databases, libraries, or cloud infrastructure.
$MarkerEnd
"@

  if (Test-Path $AgentsFile) {
    $Content = Get-Content $AgentsFile -Raw -Encoding UTF8
    $StartIdx = $Content.IndexOf($MarkerStart)
    $EndIdx = $Content.IndexOf($MarkerEnd)

    if ($StartIdx -ge 0 -and $EndIdx -gt $StartIdx) {
      # Replace existing managed section
      $NewContent = $Content.Substring(0, $StartIdx) + $Section + $Content.Substring($EndIdx + $MarkerEnd.Length)
      if (-not $NewContent.EndsWith("`n")) { $NewContent += "`n" }
      elseif (-not $NewContent.EndsWith("`n`n")) { $NewContent += "`n" }
      Set-Content -Path $AgentsFile -Value $NewContent -Encoding UTF8
      Write-Output "Updated team AI directives section in $AgentsFile"
    } else {
      # Append managed section
      if ($Content -and -not $Content.EndsWith("`n")) { $Content += "`n" }
      if ($Content -and -not $Content.EndsWith("`n`n")) { $Content += "`n" }
      $Content += $Section + "`n"
      Set-Content -Path $AgentsFile -Value $Content -Encoding UTF8
      Write-Output "Injected team AI directives section into $AgentsFile"
    }
  } else {
    # Create new AGENTS.md
    Set-Content -Path $AgentsFile -Value ($Section + "`n") -Encoding UTF8
    Write-Output "Created $AgentsFile with team AI directives section"
  }
}

# 5. SHARED GIT PUBLISH WORKFLOW

# Reusable branch/commit/push/PR decision tree extracted from levelup-publish.
# Usage: Invoke-GitPublishWorkflow -TargetDir <path> -BranchPrefix <prefix> -CommitMsg <msg> [-Ready]
# Emits PUBLISH_OUTCOME=<draft_pr|ready_pr|push_only|local_only|git_init_offered>
# and PR_URL=<url> when applicable.
function Invoke-GitPublishWorkflow {
  param(
    [Parameter(Mandatory = $true)][string]$TargetDir,
    [Parameter(Mandatory = $true)][string]$BranchPrefix,
    [Parameter(Mandatory = $true)][string]$CommitMsg,
    [switch]$Ready
  )

  $ProjectName = Split-Path -Leaf ($env:PROJECT_ROOT -or (git rev-parse --show-toplevel 2>$null) -or (Get-Location).Path)
  $BranchName = "$BranchPrefix/$ProjectName"

  # Case D: target is not a git repository — offer git init or write-only/no-op.
  $gitCheck = git -C $TargetDir rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $gitCheck) {
    Write-Output "PUBLISH_OUTCOME=git_init_offered"
    Write-Output "TARGET_DIR=$TargetDir"
    Write-Output "Target directory is not a git repository. Options:"
    Write-Output ""
    Write-Output "1. Initialize git and commit:"
    Write-Output "   cd \"$TargetDir\""
    Write-Output "   git init"
    Write-Output "   git add -A"
    Write-Output "   git commit -m \"Initial commit\""
    Write-Output "   git checkout -b \"$BranchName\""
    Write-Output ""
    Write-Output "2. Write files only (skip git operations)."
    return
  }

  # Create branch (use main if it exists, otherwise HEAD).
  Push-Location $TargetDir
  try {
    $null = git checkout -b "$BranchName" main 2>$null
    if ($LASTEXITCODE -ne 0) {
      $null = git checkout -b "$BranchName"
    }
  } finally {
    Pop-Location
  }

  # Commit changes if there is anything to commit.
  $status = git -C $TargetDir status --porcelain 2>$null
  if ($status) {
    git -C $TargetDir add -A
    git -C $TargetDir commit -m "$CommitMsg"
  }

  # Check for remote "origin".
  $remoteUrl = git -C $TargetDir remote get-url origin 2>$null
  if ($remoteUrl) {
    git -C $TargetDir push -u origin "$BranchName"

    # Case A: remote + gh CLI available.
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
      $prTitle = ($CommitMsg -split "`r?`n")[0]
      $prBody = $CommitMsg
      $draftFlag = if ($Ready) { @() } else { @("--draft") }
      $prUrl = (cd $TargetDir && gh pr create @draftFlag --title "$prTitle" --body "$prBody" 2>$null) -join "`n"
      if ($prUrl) {
        if ($Ready) {
          Write-Output "PUBLISH_OUTCOME=ready_pr PR_URL=$prUrl"
        } else {
          Write-Output "PUBLISH_OUTCOME=draft_pr PR_URL=$prUrl"
        }
      } else {
        Write-Output "PUBLISH_OUTCOME=push_only"
        Write-Output "MESSAGE=Pushed to origin/$BranchName. Open a PR manually at your Git host."
      }
    } else {
      # Case B: remote exists but gh is not available.
      Write-Output "PUBLISH_OUTCOME=push_only"
      Write-Output "MESSAGE=Pushed to origin/$BranchName. Open a PR manually at your Git host."
    }
  } else {
    # Case C: no remote exists.
    Write-Output "PUBLISH_OUTCOME=local_only"
    Write-Output "MESSAGE=Committed to local branch $BranchName. Add a remote (git remote add origin <url>) and push when ready."
  }
}

# MAIN
$SddDocsLocation = Resolve-SddDocsLocation -ProjectRoot $ProjectRoot

if ($Scaffold) {
  New-TeamAiDirectivesScaffold -Dest $Scaffold -TeamName $Name
} elseif ($AgentsOnly) {
  New-AgentsOnly -Dest $AgentsOnly
} elseif ($InjectAgents -ne "") {
  Invoke-ProjectAgentsInjection -ProjectRoot $InjectAgents
} elseif ($Json) {
  Write-OutputJson -SddDocsLocation $SddDocsLocation
} else {
  Write-OutputKeyValue -SddDocsLocation $SddDocsLocation
}
