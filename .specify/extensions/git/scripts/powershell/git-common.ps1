#!/usr/bin/env pwsh
# Git-specific common functions for the git extension.
# Extracted from scripts/powershell/common.ps1 — contains only git-specific
# branch validation and detection logic.

# Find the project root by looking for .specify directory
function Find-SpecifyRoot {
    param([string]$Dir = (Get-Location))
    $Dir = (Resolve-Path $Dir -ErrorAction SilentlyContinue).Path
    if (-not $Dir) { return $null }

    while ($true) {
        $specifyPath = Join-Path $Dir ".specify"
        if (Test-Path $specifyPath -PathType Container) {
            return $Dir
        }
        $parent = Split-Path $Dir -Parent
        if (-not $parent -or $parent -eq $Dir) { break }
        $Dir = $parent
    }
    return $null
}

# Get repository root, prioritizing .specify directory over git
function Get-RepoRoot {
    $specifyRoot = Find-SpecifyRoot
    if ($specifyRoot) {
        return $specifyRoot
    }

    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) { return $gitRoot }
    } catch { }

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $extensionDir = Split-Path -Parent $scriptDir
    $projectDir = Split-Path -Parent $extensionDir
    return $projectDir
}

# Check if we have git available at the repo root
function Has-Git {
    param([string]$RepoRoot = (Get-Location))
    try {
        $gitDir = Join-Path $RepoRoot ".git"
        if (-not (Test-Path $gitDir)) { return $false }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
        $null = git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Alias for compatibility
function Test-HasGit {
    param([string]$RepoRoot = (Get-Location))
    try {
        if (-not (Test-Path (Join-Path $RepoRoot '.git'))) { return $false }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
        git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-SpecKitEffectiveBranchName {
    param([string]$Branch)
    if ($Branch -match '^([^/]+)/([^/]+)$') {
        return $Matches[2]
    }
    return $Branch
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )

    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }

    $raw = $Branch
    $Branch = Get-SpecKitEffectiveBranchName $raw

    # Accept sequential prefix (3+ digits) but exclude malformed timestamps
    # Malformed: 7-or-8 digit date + 6-digit time with no trailing slug (e.g. "2026031-143022" or "20260319-143022")
    $hasMalformedTimestamp = ($Branch -match '^[0-9]{7}-[0-9]{6}-') -or ($Branch -match '^(?:\d{7}|\d{8})-\d{6}$')
    $isSequential = ($Branch -match '^[0-9]{3,}-') -and (-not $hasMalformedTimestamp)
    if (-not $isSequential -and $Branch -notmatch '^\d{8}-\d{6}-') {
        [Console]::Error.WriteLine("ERROR: Not on a feature branch. Current branch: $raw")
        [Console]::Error.WriteLine("Feature branches should be named like: 001-feature-name, 1234-feature-name, or 20260319-143022-feature-name")
        return $false
    }
    return $true
}
