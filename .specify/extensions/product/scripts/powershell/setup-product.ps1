# Product Extension Setup Script
# Sets up PRD and PDR files for the product extension

param(
    [string]$Command = "help",
    [switch]$Json = $false,
    [switch]$NoDecompose = $false
)

$ErrorActionPreference = "Stop"

# Get script directory for common.ps1 sourcing
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find project root by walking up from script location
function Get-ProjectRoot {
    param([string]$StartPath)
    $dir = $StartPath
    while ($dir -ne "") {
        if ((Test-Path "$dir\.specify") -or (Test-Path "$dir\.git")) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    return $StartPath
}

$projectRoot = Get-ProjectRoot $scriptDir

# Load common functions - use absolute path from project root
$commonPath = "$projectRoot\.specify\scripts\powershell\common.ps1"
if (Test-Path $commonPath) {
    . $commonPath
} elseif (Test-Path "$scriptDir\common.ps1") {
    . "$scriptDir\common.ps1"
}

# Default locations
$PDR_LOCATION = ".specify/drafts/pdr.md"
$PRD_LOCATION = "PRD.md"

# Get repository root using common.ps1 function (searches upward for .specify first)
$repoRoot = Get-RepoRoot

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-LogWarn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Detect-Subsystems {
    $repoRoot = Get-RepoRoot
    $originalLocation = Get-Location
    
    try {
        Set-Location $repoRoot -ErrorAction SilentlyContinue | Out-Null
    } catch {
        return @()
    }
    
    $dirs = @()
    
    # 1. Top-level feature directories (src/, app/, features/)
    if (Test-Path "src") {
        Get-ChildItem -Path "src" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirname = $_.Name
            if ($dirname -notin @("utils", "common", "lib", "shared", "core")) {
                $dirs += $dirname
            }
        }
    }
    
    if (Test-Path "features") {
        Get-ChildItem -Path "features" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirs += $_.Name
        }
    }
    
    if (Test-Path "modules") {
        Get-ChildItem -Path "modules" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirs += $_.Name
        }
    }
    
    if (Test-Path "apps") {
        Get-ChildItem -Path "apps" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirs += $_.Name
        }
    }
    
    # 2. Check for docker-compose services
    $composeFile = $null
    if (Test-Path "docker-compose.yml") { $composeFile = "docker-compose.yml" }
    elseif (Test-Path "docker-compose.yaml") { $composeFile = "docker-compose.yaml" }
    
    if ($composeFile) {
        $content = Get-Content $composeFile -Raw
        $services = [regex]::Matches($content, '^\s*([a-zA-Z0-9_-]+):\s*$' , [System.Text.RegularExpressions.RegexOptions]::Multiline) | ForEach-Object { $_.Groups[1].Value }
        $services = $services | Where-Object { $_ -notin @("version", "services", "networks", "volumes") }
        
        foreach ($svc in $services) {
            $found = $false
            foreach ($d in $dirs) {
                if ($d.ToLower() -like "*$($svc.ToLower())*" -or $svc.ToLower() -like "*$($d.ToLower())*") {
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $dirs += $svc
            }
        }
    }
    
    # 3. Check for Node.js workspaces
    if (Test-Path "package.json") {
        try {
            $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
            if ($packageJson.workspaces) {
                $packageJson.workspaces | ForEach-Object {
                    $dirname = [System.IO.Path]::GetFileName($_)
                    if ($dirname -ne "node_modules" -and $dirs -notcontains $dirname) {
                        $dirs += $dirname
                    }
                }
            }
        } catch {}
    }
    
    # 4. Check for Python namespace packages
    if (Test-Path "pyproject.toml") {
        Get-ChildItem -Path . -Recurse -Filter "__init__.py" -ErrorAction SilentlyContinue | 
            Where-Object { $_.FullName -notmatch "node_modules|__pycache__" } | 
            Select-Object -First 20 | ForEach-Object {
                $dirname = $_.Directory.Name
                if ($dirname -ne "." -and $dirname -ne "src" -and $dirs -notcontains $dirname) {
                    $dirs += $dirname
                }
            }
    }
    
    # 5. Check for Go modules
    if (Test-Path "go.mod" -and (Test-Path "cmd")) {
        Get-ChildItem -Path "cmd" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($dirs -notcontains $_.Name) {
                $dirs += $_.Name
            }
        }
    }
    
    Set-Location $originalLocation | Out-Null
    
    return $dirs
}

function Setup-PDR {
    $pdrFile = $PDR_LOCATION
    
    if (Test-Path $pdrFile) {
        Write-LogInfo "PDR file already exists at $pdrFile"
    } else {
        Write-LogInfo "Creating PDR file at $pdrFile"
        $pdrDir = Split-Path -Parent $pdrFile
        if ($pdrDir -and -not (Test-Path $pdrDir)) {
            New-Item -ItemType Directory -Path $pdrDir -Force | Out-Null
        }
        
        @"
# Product Decision Records

## PDR Index

| ID | Category | Decision | Status | Date | Owner |
|----|----------|----------|--------|------|-------|
| PDR-001 | [Category] | [First decision title] | Proposed | YYYY-MM-DD | [Owner] |

---

## PDR-001: [Decision Title]

### Status

**Proposed** | Accepted | Deprecated | Superseded by PDR-XXX | **Discovered** (Inferred from existing product)

### Date

YYYY-MM-DD

### Owner

[Product Manager / Team / Stakeholder]

### Category

[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR]

### Context

**Problem/Opportunity:**
[Clear description of what needs to be decided]

**Market Forces:**
- [Market factor 1]
- [Customer feedback]
- [Internal business priority]

### Decision

**Decision Statement:**
[Clear statement of what was decided]

### Consequences

#### Positive

- [User benefit]
- [Business benefit]

#### Negative

- [Trade-off]
- [Opportunity cost]

#### Risks

- [Risk with mitigation]

### Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [Method] |

### Alternatives Considered

#### Option A: [Alternative]

**Description:** [Brief description]
**Trade-offs:** [Neutral comparison]
"@ | Set-Content -Path $pdrFile -Encoding UTF8
        
        Write-LogInfo "PDR file created at $pdrFile"
    }
    
    return $pdrFile
}

function Setup-PRD {
    $prdFile = $PRD_LOCATION
    
    if (Test-Path $prdFile) {
        Write-LogInfo "PRD file already exists at $prdFile"
    } else {
        Write-LogInfo "Creating PRD file at $prdFile"
        
        @"
# Product Requirements Document: [PRODUCT_NAME]

**Version:** 1.0  
**Date:** YYYY-MM-DD  
**Author:** [Author]  
**Status:** Draft  
**PDR Reference:** [.specify/drafts/pdr.md](.specify/drafts/pdr.md)

---

## 1. Overview

[High-level description of the product]

## 2. The Problem

[Problem statement]

## 3. Goals/Objectives

* **Primary Goal:** [Main objective]
* **Technical Goal:** [Technical outcome]
* **Business Goal:** [Business value]

## 4. Success Metrics

* **Adoption:** [Metric and target]
* **Engagement:** [Metric and target]
* **Revenue/Value:** [Metric and target]

## 5. Personas

* **Primary Persona:** [Persona Name]
  * **Role:** [Job title]
  * **Needs:** [What they need]

## 6. Functional Requirements

| ID | Story | Priority |
|----|-------|----------|
| US-001 | [As a... I want to... So that...] | Must |

## 7. Non-Functional Requirements

* **Performance:** [Requirements]
* **Security:** [Requirements]
* **Reliability:** [Requirements]

## 8. Out of Scope

* [Explicitly excluded feature]

## 9. Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| [Risk] | [Mitigation] |

---

## Appendix

### A. References

### B. Change History
"@ | Set-Content -Path $prdFile -Encoding UTF8
        
        Write-LogInfo "PRD file created at $prdFile"
    }
    
    return $prdFile
}

$REPO_ROOT = Get-RepoRoot

# PRD output location
$PRD_LOCATION = "PRD.md"

# DAG Action Functions

function Invoke-PlanDag {
    $pdrFile = Join-Path $REPO_ROOT ".specify\drafts\pdr.md"
    $stateFile = Join-Path $REPO_ROOT ".specify\product\state.json"
    $sectionsDir = Join-Path $REPO_ROOT ".specify\product\sections"
    
    Write-Host "📐 DAG Planning Phase" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if PDR file exists
    if (-not (Test-Path $pdrFile)) {
        Write-Host "❌ PDR drafts file does not exist: $pdrFile" -ForegroundColor Red
        Write-Host "Run '/product.specify' or '/product.init' first" -ForegroundColor Yellow
        exit 1
    }
    
    # Ensure directories exist
    $productDir = Join-Path $REPO_ROOT ".specify\product"
    if (-not (Test-Path $productDir)) {
        New-Item -ItemType Directory -Path $productDir -Force | Out-Null
    }
    if (-not (Test-Path $sectionsDir)) {
        New-Item -ItemType Directory -Path $sectionsDir -Force | Out-Null
    }
    
    # Count PDRs and extract feature-areas
    $content = Get-Content $pdrFile -Raw
    $pdrCount = ([regex]::Matches($content, "^### PDR-|^## PDR-", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    
    # Extract unique feature-areas from PDR index table
    $featureAreas = @()
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        # Parse PDR index table rows
        if ($line -match '^\|\s*PDR-\d+\s*\|\s*[^|]+\s*\|\s*([^|]+)\s*\|') {
            $featureArea = $Matches[1].Trim()
            if ($featureArea -and $featureArea -ne "Feature-Area" -and $featureArea -ne "Sub-System" -and $featureAreas -notcontains $featureArea) {
                $featureAreas += $featureArea
            }
        }
    }
    
    # Default to "Product" if no feature-areas found
    if ($featureAreas.Count -eq 0) {
        $featureAreas = @("Product")
    }
    
    Write-Host "📋 PDR file found: $pdrFile" -ForegroundColor Green
    Write-Host "   Found $pdrCount PDR(s)" -ForegroundColor Cyan
    Write-Host "   Feature-areas detected: $($featureAreas -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ready for DAG planning."
    Write-Host "The AI agent will:"
    Write-Host "  1. Analyze PDRs by feature-area"
    Write-Host "  2. Generate customized DAG per feature-area"
    Write-Host "  3. Present execution plan for user approval"
    Write-Host "  4. Save approved plan to state.json"
    
    if ($Json) {
        $featureAreasJson = $featureAreas | ForEach-Object {
            @{
                id = ($_ -replace '\s+', '-').ToLower()
                name = $_
            }
        }
        @{
            status = "success"
            action = "plan-dag"
            pdr_file = $pdrFile
            state_file = $stateFile
            sections_dir = $sectionsDir
            pdr_count = $pdrCount
            feature_areas = $featureAreasJson
        } | ConvertTo-Json -Depth 3
    }
}

function Invoke-ExecuteDag {
    $stateFile = Join-Path $REPO_ROOT ".specify\product\state.json"
    $sectionsDir = Join-Path $REPO_ROOT ".specify\product\sections"
    
    Write-Host "🔧 DAG Execution Phase" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if state file exists
    if (-not (Test-Path $stateFile)) {
        Write-Host "❌ No execution plan found: $stateFile" -ForegroundColor Red
        Write-Host "Run '/product.implement' first to generate and approve a DAG plan" -ForegroundColor Yellow
        exit 1
    }
    
    # Ensure sections directory exists
    if (-not (Test-Path $sectionsDir)) {
        New-Item -ItemType Directory -Path $sectionsDir -Force | Out-Null
    }
    
    Write-Host "📄 State file found: $stateFile" -ForegroundColor Green
    Write-Host "📁 Sections directory: $sectionsDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ready for DAG execution."
    Write-Host "The AI agent will:"
    Write-Host "  1. Read execution plan from state.json"
    Write-Host "  2. Identify next section(s) to generate"
    Write-Host "  3. Generate section with dependency context"
    Write-Host "  4. Write to .specify/product/sections/{feature-area}/{section}.md"
    Write-Host "  5. Update progress in state.json"
    
    if ($Json) {
        $stateContent = Get-Content $stateFile -Raw | ConvertFrom-Json
        @{
            status = "success"
            action = "execute-dag"
            state_file = $stateFile
            sections_dir = $sectionsDir
            state = $stateContent
        } | ConvertTo-Json -Depth 10
    }
}

function Invoke-Summarize {
    $stateFile = Join-Path $REPO_ROOT ".specify\product\state.json"
    $sectionsDir = Join-Path $REPO_ROOT ".specify\product\sections"
    $prdFile = $PRD_LOCATION
    $pdrFile = Join-Path $REPO_ROOT ".specify\drafts\pdr.md"
    
    Write-Host "📝 Summarization Phase" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if sections directory exists and has content
    if (-not (Test-Path $sectionsDir)) {
        Write-Host "❌ Sections directory not found: $sectionsDir" -ForegroundColor Red
        Write-Host "Run '/product.implement' to generate sections first" -ForegroundColor Yellow
        exit 1
    }
    
    # Count section files
    $sectionFiles = Get-ChildItem -Path $sectionsDir -Filter "*.md" -Recurse -File
    $sectionCount = $sectionFiles.Count
    
    if ($sectionCount -eq 0) {
        Write-Host "❌ No section files found in $sectionsDir" -ForegroundColor Red
        Write-Host "Run '/product.implement' to generate sections first" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "📁 Sections directory: $sectionsDir" -ForegroundColor Cyan
    Write-Host "   Found $sectionCount section file(s):" -ForegroundColor Cyan
    foreach ($file in $sectionFiles) {
        $relativePath = $file.FullName.Substring($sectionsDir.Length + 1)
        Write-Host "   - $relativePath" -ForegroundColor Gray
    }
    Write-Host ""
    
    Write-Host "Ready for summarization."
    Write-Host "The AI agent will:"
    Write-Host "  1. Read all section files from .specify/product/sections/"
    Write-Host "  2. Detect cross-feature-area conflicts"
    Write-Host "  3. Resolve conflicts using PDRs as source of truth"
    Write-Host "  4. Aggregate into unified PRD.md"
    Write-Host "  5. Move Accepted PDRs to canonical location"
    
    if ($Json) {
        $sectionsJson = $sectionFiles | ForEach-Object {
            @{
                path = $_.FullName
                relative = $_.FullName.Substring($sectionsDir.Length + 1)
            }
        }
        @{
            status = "success"
            action = "summarize"
            state_file = $stateFile
            sections_dir = $sectionsDir
            prd_file = $prdFile
            pdr_file = $pdrFile
            section_count = $sectionCount
            sections = $sectionsJson
        } | ConvertTo-Json -Depth 3
    }
}

switch ($Command.ToLower()) {
    "specify" {
        if ($Json) {
            $result = @{
                REPO_ROOT = $REPO_ROOT
                PDR_FILE = $PDR_LOCATION
                PRD_FILE = $PRD_LOCATION
                COMMAND = $Command
            }
            $result | ConvertTo-Json -Compress
        } else {
            Write-LogInfo "Setting up for product specification..."
            $pdrPath = Setup-PDR
            Write-LogInfo "Ready for PDR creation in $pdrPath"
        }
    }
    "init" {
        if ($Json) {
            $subsystems = @(Detect-Subsystems)
            $subsystemObjects = @()
            foreach ($s in $subsystems) {
                $subsystemObjects += @{
                    id = $s
                    name = $s
                    detection_method = "directory"
                    evidence = "$s/"
                }
            }
            $result = @{
                REPO_ROOT = $REPO_ROOT
                PDR_FILE = $PDR_LOCATION
                PRD_FILE = $PRD_LOCATION
                COMMAND = $Command
                subsystems = $subsystemObjects
                decomposition = -not $NoDecompose
            }
            $result | ConvertTo-Json -Compress
        } else {
            Write-LogInfo "Setting up for brownfield discovery..."
            $pdrPath = Setup-PDR
            Write-LogInfo "Ready for PDR discovery in $pdrPath"
            $subsystems = Detect-Subsystems
            if ($subsystems.Count -eq 0) {
                Write-LogInfo "No sub-systems detected."
            } else {
                Write-LogInfo "Detected $($subsystems.Count) sub-systems:"
                foreach ($s in $subsystems) {
                    Write-Host "  - $s" -ForegroundColor Cyan
                }
            }
        }
    }
    "implement" {
        if ($Json) {
            $result = @{
                REPO_ROOT = $REPO_ROOT
                PDR_FILE = $PDR_LOCATION
                PRD_FILE = $PRD_LOCATION
                COMMAND = $Command
            }
            $result | ConvertTo-Json -Compress
        } else {
            Write-LogInfo "Setting up for PRD generation..."
            $prdPath = Setup-PRD
            $pdrPath = Setup-PDR
            Write-LogInfo "Ready for PRD generation: $prdPath"
        }
    }
    "clarify" {
        if ($Json) {
            $result = @{
                REPO_ROOT = $REPO_ROOT
                PDR_FILE = $PDR_LOCATION
                PRD_FILE = $PRD_LOCATION
                COMMAND = $Command
            }
            $result | ConvertTo-Json -Compress
        } else {
            Write-LogInfo "Setting up for PDR clarification..."
            $pdrPath = Setup-PDR
            Write-LogInfo "Ready for clarification"
        }
    }
    "analyze" {
        if ($Json) {
            $result = @{
                REPO_ROOT = $REPO_ROOT
                PDR_FILE = $PDR_LOCATION
                PRD_FILE = $PRD_LOCATION
                COMMAND = $Command
            }
            $result | ConvertTo-Json -Compress
        } else {
            Write-LogInfo "Setting up for consistency analysis..."
            $prdPath = Setup-PRD
            $pdrPath = Setup-PDR
            Write-LogInfo "Ready for analysis"
        }
    }
    "validate" {
        if ($Json) {
            $result = @{
                REPO_ROOT = $REPO_ROOT
                PDR_FILE = $PDR_LOCATION
                PRD_FILE = $PRD_LOCATION
                COMMAND = $Command
            }
            $result | ConvertTo-Json -Compress
        } else {
            Write-LogInfo "Setting up for plan validation..."
            $prdPath = Setup-PRD
            $pdrPath = Setup-PDR
            Write-LogInfo "Ready for validation"
        }
    }
    "plan-dag" {
        Invoke-PlanDag
    }
    "execute-dag" {
        Invoke-ExecuteDag
    }
    "summarize" {
        Invoke-Summarize
    }
    default {
        Write-Host "Product Extension Setup Script" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage: .\setup-product.ps1 <command> [-Json] [-NoDecompose]" -ForegroundColor White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor White
        Write-Host "  specify    Setup for greenfield product specification"
        Write-Host "  init       Setup for brownfield product discovery"
        Write-Host "  implement  Setup for PRD generation"
        Write-Host "  clarify    Setup for PDR refinement"
        Write-Host "  analyze    Setup for consistency analysis"
        Write-Host "  validate   Setup for plan validation"
        Write-Host ""
        Write-Host "DAG Workflow Commands:" -ForegroundColor White
        Write-Host "  plan-dag     Phase 1: Generate DAG execution plan"
        Write-Host "  execute-dag  Phase 2: Execute DAG to generate sections"
        Write-Host "  summarize    Phase 3: Aggregate sections into PRD.md"
        Write-Host ""
        Write-Host "Options:" -ForegroundColor White
        Write-Host "  -Json          Output results in JSON format"
        Write-Host "  -NoDecompose   Disable automatic sub-system decomposition"
        Write-Host "  help       Show this help message"
    }
}
