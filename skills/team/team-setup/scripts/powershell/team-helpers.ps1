#!/usr/bin/env pwsh
# team-helpers.ps1 — Shared utilities for team-* skills (PowerShell)
#
# Flags:
#   -Json              Output path info as JSON (default: key=value)
#   -Scaffold DIR      Create a fresh 11-file team AI directives scaffold at DIR
#   -AgentsOnly DIR    Create only AGENTS.md at DIR (for repair use)
#   -InjectAgents DIR  Inject team-boot directive into project-level AGENTS.md at DIR
#   -AgentsStatus DIR  Report managed-section status in project-level AGENTS.md at DIR
#   -AgentsUninstall DIR  Remove managed section from project-level AGENTS.md at DIR
#   -Name NAME         Team name for scaffold (default: "My Team")
param(
  [switch]$Json,
  [string]$Scaffold = "",
  [string]$AgentsOnly = "",
  [string]$InjectAgents = "",
  [string]$AgentsStatus = "",
  [string]$AgentsUninstall = "",
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
  Write-Output "PROJECT_ROOT=$ProjectRoot"
  Write-Output "TEAM_AI_DIRECTIVES=$TeamAiDirectives"
  Write-Output "BRANCH=$Branch"
}

function Write-OutputJson {
  $output = @{
    REPO_ROOT = $ProjectRoot
    TEAM_AI_DIRECTIVES = $TeamAiDirectives
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
generated: { by: agent:team-setup, at: ${today}T00:00:00Z }
id: constitution
cdr_ref: null
created: ${today}
verified:
  - { by: agent:team-setup, at: ${today}T00:00:00Z }
status: stable
stale_after: 180d
---

# ${TeamName} Constitution

No team-wide principles defined yet. Add principles as they are established.
"@
  Set-Content -Path (Join-Path $Dest "context_modules/constitution.md") -Value $constitution

  $indexTop = @"
---
okf_version: "0.2"
---

# Context Modules

* [Rules](rules/index.md) - Team rules and workflows
* [Personas](personas/index.md) - Team personas
* [Examples](examples/index.md) - Team examples
"@
  Set-Content -Path (Join-Path $Dest "context_modules/index.md") -Value $indexTop
  Set-Content -Path (Join-Path $Dest "context_modules/log.md") -Value "# Context Modules Update Log`n"

  Set-Content -Path (Join-Path $Dest "context_modules/rules/index.md") -Value "# Rules`n`nNo rules defined yet. Use /team-levelup to create rules via CDRs."
  Set-Content -Path (Join-Path $Dest "context_modules/rules/log.md") -Value "# Rules Update Log`n"
  Set-Content -Path (Join-Path $Dest "context_modules/personas/index.md") -Value "# Personas`n`nNo personas defined yet. Use /team-levelup to create personas via CDRs."
  Set-Content -Path (Join-Path $Dest "context_modules/personas/log.md") -Value "# Personas Update Log`n"
  Set-Content -Path (Join-Path $Dest "context_modules/examples/index.md") -Value "# Examples`n`nNo examples defined yet. Use /team-levelup to create examples via CDRs."
  Set-Content -Path (Join-Path $Dest "context_modules/examples/log.md") -Value "# Examples Update Log`n"

  $cdrDerived = @"
# Context Directive Records (Derived Index)

> ⚠️ Auto-generated by `/team-repair`. Do not edit manually.
> Source of truth: `context_modules/*/index.md` + module frontmatter.
> Decision lifecycle (Accepted/Rejected) lives in the `adlc` orphan branch `drafts/cdr/`.

## CDR Index

| ID | Path | Type | Description | Generated | Verified | Age | Status |
|----|------|------|-------------|-----------|----------|-----|--------|

**Stats**: 0 entries | Last Updated: ${today}
"@
  Set-Content -Path (Join-Path $Dest "CDR.md") -Value $cdrDerived

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
# Team AI Directives

This project is bound by the team AI directives repository at ``$TeamDirective``.

team-boot runs automatically at session start via the event hook (for agents with event support), injecting a lean orientation into the first user message with the team constitution, CDR index, Class Boots catalog, skills registry, and MCP servers.

If the team AI directives context is NOT in your system prompt or first user message (agent without event support), invoke the ``team-boot`` skill before responding to any task or question.

If team AI directives are unconfigured, invoke the ``team-setup`` skill.

Invoke the matching class boot when a task or decision matches a row — invoke it
at the START of the matching task, before planning the todo list and before
implementation, so the class context informs planning; never defer to session end
or post-hoc. When no local memory index exists in the current working directory
and the directory sits inside a workspace (detected via a ``.gitmodules`` marker
in an ancestor), the boot reads the workspace root's ``docs/adlc/memory/`` index
instead (the dual-read order applies: ``docs/adlc/memory`` first, legacy
``.adlc/memory`` fallback).

## Class Boots

| Boot | Injects | Invoke When | Capture Via |
|--|--|--|--|
| architect-boot | ADR index (docs/adlc/memory/adr/ + legacy .adlc/memory/adr/) | architecture work; tech-stack/pattern choice | /architect-specify |
| product-boot | PDR index (docs/adlc/memory/pdr/ + legacy .adlc/memory/pdr/) | product/feature scope, personas, monetization | /product-specify |
| change-boot | ChDR index (docs/adlc/memory/chdr.md + legacy .adlc/memory/chdr.md) | change-history rationale, reverts, issue-linked commits, git commands w/ human-authored messages, authored PRs, CHANGELOG edits | /change-init |
| team-levelup | CDR module bodies (team-ai-directives) | CDR descriptor match; reusable team pattern | /team-levelup |
| tech-radar-boot | Tikal Tech Radar context | choosing/evaluating technology | radar context + /architect-specify |

Each class boot emits its class context section and its own searched line (_Searched N records, K matched._).

**Every response MUST include** a Team Context & Decisions section before the task answer (Status ``in use`` rows ground the session in accepted records; Status ``pending`` rows capture emerging decisions in the same table):

## Team Context & Decisions

| ID | Name | Type | Rel | Status | Clarify |
|--|--|--|--|--|--|
| CDR-YYYY-NNN | <name> | <type> | <relevance> | in use | — |
| — | <decision> | <ADR/PDR/CDR/ChDR/Eval> | <trigger> | pending | <clarify skill> |

Plus: ``_Scope: N CDRs · A ADRs · P PDRs · C ChDRs · E evals · M skills — J rows shown · Unrecorded: N pending · Unclarified: M captured drafts._`` — **J MUST equal the number of rows (any indexed type). Status ``in use`` + Clarify ``—`` = grounding context (accepted records only); Status ``pending``/``captured``/``clarified``/``handed off`` + Clarify skill = owed decisions. No draft row may carry Status ``in use`` — drafts appear only as pending decision rows. 0 rows matched → emit the section heading + the counts line only — no table. A 0-row table header collapses into unrendered single-line markdown; never emit one (do not copy a hard-coded row or inflate the count).** Scope names the always-available layer and class indexes (counts only, never content) plus the session's open decisions; class boots append their own scope line when fired.

Render the section as markdown blocks — heading, table (when rows exist), and counts line each on their own lines; never collapse the table into a single line.

## Decision Capture

Detect decisions as they emerge; full detection and capture guidance lives in the matching class boot:

- Tech stack / pattern choice → ADR → /architect-specify (pull tech-radar-boot context first for tech selection)
- Feature scope / persona / monetization → PDR → /product-specify
- Reusable team rule / pattern → CDR → /team-levelup
- Revert/hotfix rationale / issue-linked commit → ChDR → /change-init

Maintain the decision rows in the same table above (Status pending/captured/clarified/handed off + Clarify skill); with no pending decisions, emit the heading + the counts line only — no table.

At session end, deliver the clarify prompt naming each captured draft (ID + clarify skill); if the user defers clarify, mark those rows handed off. Only suggest capture when genuinely warranted.

Surface each detected decision as a task-list todo (write the draft to ``.adlc/drafts/{type}/``, then run the matching clarify skill at session end). After code-modifying tasks, add a trailing todo to sweep Team Context & Decisions until _Unrecorded: 0 pending · Unclarified: 0 drafts_ (a draft leaves Unclarified only via its clarify skill or an explicit user handoff to a named clarify or execute skill).
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

function Get-ProjectAgentsSectionStatus {
  param([string]$ProjectRoot = ".")
  $AgentsFile = Join-Path $ProjectRoot "AGENTS.md"
  $MarkerStart = "<!-- TEAM_AI_DIRECTIVES START -->"
  $MarkerEnd = "<!-- TEAM_AI_DIRECTIVES END -->"
  if (-not (Test-Path $AgentsFile)) {
    Write-Output "STATUS: missing (no AGENTS.md at $ProjectRoot)"
    return
  }
  $Content = Get-Content $AgentsFile -Raw -Encoding UTF8
  if ($Content.Contains($MarkerStart) -and $Content.Contains($MarkerEnd)) {
    Write-Output "STATUS: installed ($AgentsFile contains the managed section)"
  } else {
    Write-Output "STATUS: not-installed ($AgentsFile lacks the managed section)"
  }
}

function Remove-ProjectAgentsSection {
  param([string]$ProjectRoot = ".")
  $AgentsFile = Join-Path $ProjectRoot "AGENTS.md"
  $MarkerStart = "<!-- TEAM_AI_DIRECTIVES START -->"
  $MarkerEnd = "<!-- TEAM_AI_DIRECTIVES END -->"
  if (-not (Test-Path $AgentsFile)) {
    Write-Output "Nothing to remove: no AGENTS.md at $ProjectRoot"
    return
  }
  $Content = Get-Content $AgentsFile -Raw -Encoding UTF8
  $StartIdx = $Content.IndexOf($MarkerStart)
  $EndIdx = $Content.IndexOf($MarkerEnd)
  if ($StartIdx -lt 0 -or $EndIdx -le $StartIdx) {
    Write-Output "No managed section in $AgentsFile (nothing removed)"
    return
  }
  $NewContent = $Content.Substring(0, $StartIdx) + $Content.Substring($EndIdx + $MarkerEnd.Length)
  while ($NewContent.Contains("`n`n`n")) { $NewContent = $NewContent.Replace("`n`n`n", "`n`n") }
  $NewContent = $NewContent.Trim("`r", "`n")
  if ($NewContent) { $NewContent += "`n" }
  Set-Content -Path $AgentsFile -Value $NewContent -Encoding UTF8
  Write-Output "Removed team AI directives section from $AgentsFile"
}

# MAIN
if ($Scaffold) {
  New-TeamAiDirectivesScaffold -Dest $Scaffold -TeamName $Name
} elseif ($AgentsOnly) {
  New-AgentsOnly -Dest $AgentsOnly
} elseif ($InjectAgents -ne "") {
  Invoke-ProjectAgentsInjection -ProjectRoot $InjectAgents
} elseif ($AgentsStatus -ne "") {
  Get-ProjectAgentsSectionStatus -ProjectRoot $AgentsStatus
} elseif ($AgentsUninstall -ne "") {
  Remove-ProjectAgentsSection -ProjectRoot $AgentsUninstall
} elseif ($Json) {
  Write-OutputJson
} else {
  Write-OutputKeyValue
}
