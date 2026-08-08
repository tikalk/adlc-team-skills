#!/usr/bin/env pwsh
# setup-workspace-init.ps1 — Setup for workspace-init (self-contained)
#
# Creates .adlc/ directory structure, checks .gitignore conventions,
# discovers child repos at depth 1, and outputs JSON metadata.
$ErrorActionPreference = "Stop"

###############################################################################
# Path resolution (inline — no external helper dependency)
###############################################################################

function Resolve-ProjectRoot {
    $dir = (Get-Location).Path
    while ($dir -ne "") {
        if (Test-Path (Join-Path $dir ".adlc")) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($gitRoot) { return $gitRoot }
    return (Get-Location).Path
}

function Resolve-Branch {
    $b = git branch --show-current 2>$null
    if ($b) { return $b }
    return "unknown"
}

###############################################################################
# .adlc/ directory structure
###############################################################################

$AdlcSubdirs = @(
    "product"
    "architecture"
    "context"
    "skills"
    "drafts"
    "drafts/pdr"
    "drafts/adr"
    "drafts/cdr"
    "drafts/skills"
    "drafts/evals"
)

function New-AdlcStructure {
    param([string]$AdlcDir)
    $created = @()
    foreach ($subdir in $AdlcSubdirs) {
        $fullPath = Join-Path $AdlcDir $subdir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            $created += ".adlc/$subdir"
        }
    }
    return $created
}

###############################################################################
# .gitignore convention check (read-only — reports missing rules)
###############################################################################

$GitignoreRules = @(
    ".adlc/"
    ".agents/"
    ".opencode/"
    ".claude/"
    ".cursor/"
    ".codex/"
    ".gemini/"
    ".qwen/"
    ".devin/"
    ".tabnine/"
    "skills-lock.json"
    ".skills.json"
    ".mcp.json"
)

function Test-GitignoreRules {
    $missing = @()
    if (-not (Test-Path ".gitignore")) {
        return $GitignoreRules
    }
    $content = Get-Content ".gitignore" -ErrorAction SilentlyContinue
    foreach ($rule in $GitignoreRules) {
        if ($content -notcontains $rule) {
            $missing += $rule
        }
    }
    return $missing
}

###############################################################################
# Child repo discovery
###############################################################################

$ExcludeDirs = @('node_modules', '.venv', 'vvenv', 'venv', 'dist', 'build', 'target', '.idea', '.vscode', '.git', '.cache', '.specify')

function Test-Excluded {
    param([string]$Name)
    return $ExcludeDirs -contains $Name
}

function Test-Submodule {
    param([string]$Path)
    try {
        $submodules = git config --file .gitmodules --get-regexp "^submodule\..*\.path$" 2>$null
        return ($submodules -match "^[^ ]* $Path$")
    } catch {
        return $false
    }
}

function Test-TrackedInParent {
    param([string]$Path)
    try {
        $null = git ls-files --error-unmatch $Path 2>$null
        return $true
    } catch {
        return $false
    }
}

function Get-RemoteUrl {
    param([string]$RepoPath)
    try {
        return (git -C $RepoPath remote get-url origin 2>$null)
    } catch {
        return ""
    }
}

function Get-ChildRepos {
    param([string]$Root)
    $discovered = @()
    Get-ChildItem -Path $Root -Directory | ForEach-Object {
        $basename = $_.Name
        if (Test-Excluded -Name $basename) { return }
        $gitPath = Join-Path $_.FullName ".git"
        if ((Test-Path $gitPath -PathType Container) -or (Test-Path $gitPath -PathType Leaf)) {
            $discovered += $basename
        }
    }
    return $discovered
}

###############################################################################
# Main
###############################################################################

$ProjectRoot = Resolve-ProjectRoot
$Branch = Resolve-Branch
$AdlcDir = Join-Path $ProjectRoot ".adlc"
$GitignoreExists = Test-Path ".gitignore"

# Create .adlc/ structure
$AdlcDirsCreated = New-AdlcStructure -AdlcDir $AdlcDir

# Check .gitignore rules
$GitignoreRulesMissing = Test-GitignoreRules

# Discover child repos
$ChildRepoNames = Get-ChildRepos -Root $ProjectRoot

# Build child repo array
$ChildRepos = @()
foreach ($repoName in $ChildRepoNames) {
    $repoPath = Join-Path $ProjectRoot $repoName
    $remote = Get-RemoteUrl -RepoPath $repoPath
    $isSubmodule = Test-Submodule -Path $repoName
    $isTracked = Test-TrackedInParent -Path $repoName
    $ChildRepos += @{
        name = $repoName
        path = $repoPath
        remote = $remote
        is_submodule = $isSubmodule
        is_tracked = $isTracked
    }
}

# Output JSON
$result = @{
    REPO_ROOT = $ProjectRoot
    ADLC_DIR = $AdlcDir
    ADLC_DIRS_CREATED = $AdlcDirsCreated
    GITIGNORE_EXISTS = $GitignoreExists
    GITIGNORE_RULES_MISSING = $GitignoreRulesMissing
    CHILD_REPOS = $ChildRepos
    CHILD_COUNT = $ChildRepos.Count
    BRANCH = $Branch
}

$result | ConvertTo-Json -Compress
