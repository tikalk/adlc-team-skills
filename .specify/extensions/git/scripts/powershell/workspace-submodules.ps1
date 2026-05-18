#!/usr/bin/env pwsh

param(
    [switch]$Json,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$IgnoreOnly
)

$ErrorActionPreference = "Stop"

# Source common functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonPath = Join-Path $scriptDir "git-common.ps1"
if (Test-Path $commonPath) {
    . $commonPath
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

# Check if this is a git repo
if (-not (Has-Git)) {
    if ($Json) {
        '{"error": "Not a git repository. Workspace must be initialized with git."}'
    } else {
        Write-Error "Not a git repository. Workspace must be initialized with git."
    }
    exit 1
}

# Setup spec-kit .gitignore rules first
if (-not $DryRun) {
    Setup-SpecKitGitignore 2>$null | Out-Null
}

# Arrays to track results
$registeredRepos = @()
$skippedRepos = @()
$errorRepos = @()
$ignoredRepos = @()

# Function to check if a path is already a submodule
function Is-Submodule($path) {
    try {
        $submodules = git config --file .gitmodules --get-regexp "^submodule\..*\.path$" 2>$null
        return $submodules -match "^[^ ]* $path$"
    } catch {
        return $false
    }
}

# Function to check if a path is tracked in parent index
function Is-TrackedInParent($path) {
    try {
        $null = git ls-files --error-unmatch $path 2>$null
        return $true
    } catch {
        return $false
    }
}

# Function to ensure .gitignore exists
function Ensure-Gitignore() {
    if (-not (Test-Path ".gitignore")) {
        New-Item -ItemType File -Name ".gitignore" | Out-Null
    }
}

# Function to setup spec-kit .gitignore rules
function Setup-SpecKitGitignore() {
    $rulesAdded = 0
    
    # Spec Kit ignore rules
    $ignoreRules = @(
        ".specify/extensions/.cache/",
        ".specify/extensions/.backup/",
        ".specify/extensions/*/*.local.yml",
        ".specify/extensions/.registry"
    )
    
    # Spec Kit negation rules
    $negationRules = @(
        "!.specify/",
        "!.specify/templates/",
        "!.specify/scripts/",
        "!.specify/memory/",
        "!.opencode/",
        "!.claude/",
        "!.cursor/",
        "!.windsurf/"
    )
    
    # Ensure .gitignore exists
    if (-not (Test-Path ".gitignore")) {
        New-Item -ItemType File -Name ".gitignore" | Out-Null
    }
    
    # Add ignore rules if missing
    foreach ($rule in $ignoreRules) {
        $gitignoreContent = Get-Content ".gitignore" -ErrorAction SilentlyContinue
        if ($gitignoreContent -notcontains $rule) {
            Add-Content -Path ".gitignore" -Value $rule
            $rulesAdded++
        }
    }
    
    # Add negation rules if missing
    foreach ($rule in $negationRules) {
        $gitignoreContent = Get-Content ".gitignore" -ErrorAction SilentlyContinue
        if ($gitignoreContent -notcontains $rule) {
            Add-Content -Path ".gitignore" -Value $rule
            $rulesAdded++
        }
    }
    
    # Commit changes if rules were added
    if ($rulesAdded -gt 0) {
        git add .gitignore 2>$null | Out-Null
        git commit -m "[Spec Kit] Configure .gitignore for spec-kit directories" 2>$null | Out-Null
    }
}

# Function to get remote URL from a child repo
function Get-RemoteUrl($repoPath) {
    try {
        return git -C $repoPath remote get-url origin 2>$null
    } catch {
        return ""
    }
}

# Discover child repos at depth 1
function Discover-ChildRepos {
    $discovered = @()
    
    Get-ChildItem -Path $repoRoot -Directory | ForEach-Object {
        $basename = $_.Name
        
        # Skip common non-project directories
        $skipDirs = @('.specify', '.git', 'node_modules', '__pycache__', '.venv', 'venv', 'dist', 'build', 'target', '.idea', '.vscode')
        if ($skipDirs -contains $basename) {
            return
        }
        
        # Check if it has a .git directory or file
        $gitPath = Join-Path $_.FullName ".git"
        if ((Test-Path $gitPath -PathType Container) -or (Test-Path $gitPath -PathType Leaf)) {
            $discovered += $basename
        }
    }
    
    return $discovered
}

# Discover child repos early (needed for safety check)
$childRepos = Discover-ChildRepos

# Build a pattern of child repo names for exclusion
# Match both with and without trailing slash (git diff returns just the name for directories)
$childPatterns = $childRepos | ForEach-Object { "^$_(/|$)" }

# Safety check: Check for uncommitted changes
# If -Force is used, allow child repos to be "dirty" (they'll be converted)
$hasUncommitted = $false
$nonChildChanges = @()

# Check for staged changes
$stagedChanges = git diff --cached --name-only 2>$null
if ($stagedChanges) {
    if ($Force) {
        $nonChildChanges = $stagedChanges | Where-Object { 
            $file = $_
            $isChild = $false
            foreach ($pattern in $childPatterns) {
                if ($file -match $pattern) {
                    $isChild = $true
                    break
                }
            }
            -not $isChild
        }
    } else {
        $nonChildChanges = $stagedChanges
    }
    if ($nonChildChanges) {
        $hasUncommitted = $true
    }
}

# Check for unstaged changes
$unstagedChanges = git diff --name-only 2>$null
if ($unstagedChanges) {
    if ($Force) {
        $nonChildChangesUnstaged = $unstagedChanges | Where-Object { 
            $file = $_
            $isChild = $false
            foreach ($pattern in $childPatterns) {
                if ($file -match $pattern) {
                    $isChild = $true
                    break
                }
            }
            -not $isChild
        }
    } else {
        $nonChildChangesUnstaged = $unstagedChanges
    }
    if ($nonChildChangesUnstaged) {
        $hasUncommitted = $true
        if (-not $nonChildChanges) {
            $nonChildChanges = $nonChildChangesUnstaged
        } else {
            $nonChildChanges = $nonChildChanges + $nonChildChangesUnstaged | Select-Object -Unique
        }
    }
}

# If there are non-child changes, abort
if ($hasUncommitted) {
    if ($Json) {
        '{"error": "Parent repository has uncommitted changes outside child repos. Commit or stash before running workspace setup."}'
    } else {
        Write-Error "Parent repository has uncommitted changes outside child repos.`nCommit or stash these changes before running workspace setup:`n`n$($nonChildChanges | Select-Object -First 20 | ForEach-Object { $_ } | Out-String)"
    }
    exit 1
}

# Main processing
if ($IgnoreOnly) {
    # Ignore-only mode: Add to .gitignore and remove from index
    Ensure-Gitignore
    
    foreach ($repoName in $childRepos) {
        # Remove from parent index if tracked
        if (Is-TrackedInParent $repoName) {
            if (-not $DryRun) {
                git rm --cached $repoName 2>$null | Out-Null
            }
        }
        
        # Add to .gitignore if not already there
        $gitignoreContent = Get-Content ".gitignore" -ErrorAction SilentlyContinue
        $entry = "$repoName/"
        if ($gitignoreContent -notcontains $entry) {
            if (-not $DryRun) {
                Add-Content -Path ".gitignore" -Value $entry
            }
            $ignoredRepos += $repoName
        } else {
            $skippedRepos += "$repoName`: already in .gitignore"
        }
    }
    
    # Commit .gitignore changes
    if ((-not $DryRun) -and ($ignoredRepos.Count -gt 0)) {
        git add .gitignore 2>$null | Out-Null
        git commit -m "[Spec Kit] Add child repos to .gitignore" 2>$null | Out-Null
    }
} else {
    # Submodule mode: Register as submodules
    foreach ($repoName in $childRepos) {
        $repoPath = Join-Path $repoRoot $repoName
        
        # Check if already a submodule
        if (Is-Submodule $repoName) {
            $skippedRepos += "$repoName`: already a submodule"
            continue
        }
        
        # Check if tracked in parent index
        if (Is-TrackedInParent $repoName) {
            # Get remote URL first
            $remoteUrl = Get-RemoteUrl $repoPath
            
            if (-not $remoteUrl) {
                $errorRepos += "$repoName`: no remote URL configured"
                continue
            }
            
            # Remove from parent index
            if (-not $DryRun) {
                git rm --cached $repoName 2>$null | Out-Null
            }
            
            # Register as submodule
            if ($DryRun) {
                $registeredRepos += "$repoName → $remoteUrl [DRY RUN]"
            } else {
                try {
                    git submodule add $remoteUrl $repoName 2>$null | Out-Null
                    $registeredRepos += "$repoName → $remoteUrl"
                } catch {
                    $errorRepos += "$repoName`: failed to add submodule"
                }
            }
            continue
        }
        
        # Get remote URL
        $remoteUrl = Get-RemoteUrl $repoPath
        
        if (-not $remoteUrl) {
            $errorRepos += "$repoName`: no remote URL configured"
            continue
        }
        
        # Register as submodule
        if ($DryRun) {
            $registeredRepos += "$repoName → $remoteUrl [DRY RUN]"
        } else {
            try {
                git submodule add $remoteUrl $repoName 2>$null | Out-Null
                $registeredRepos += "$repoName → $remoteUrl"
            } catch {
                $errorRepos += "$repoName`: failed to add submodule"
            }
        }
    }
    
    # Commit changes if not dry run and we registered repos
    if ((-not $DryRun) -and ($registeredRepos.Count -gt 0)) {
        $gitmodulesPath = Join-Path $repoRoot ".gitmodules"
        if (Test-Path $gitmodulesPath) {
            git add .gitmodules 2>$null | Out-Null
            # Try to commit, but don't fail if nothing to commit
            git commit -m "[Spec Kit] Register workspace submodules" 2>$null | Out-Null
        }
    }
}

# Output results
if ($Json) {
    $registeredJson = $registeredRepos | ForEach-Object { '"' + $_ + '"' }
    $skippedJson = $skippedRepos | ForEach-Object { '"' + $_ + '"' }
    $errorsJson = $errorRepos | ForEach-Object { '"' + $_ + '"' }
    $ignoredJson = $ignoredRepos | ForEach-Object { '"' + $_ + '"' }
    
    $mode = if ($IgnoreOnly) { "ignore" } else { "submodule" }
    $dryRunValue = if ($DryRun) { "true" } else { "false" }
    
    @"
{
  "DISCOVERED_COUNT": $($childRepos.Count),
  "REGISTERED_COUNT": $($registeredRepos.Count),
  "SKIPPED_COUNT": $($skippedRepos.Count),
  "ERROR_COUNT": $($errorRepos.Count),
  "IGNORED_COUNT": $($ignoredRepos.Count),
  "REGISTERED_REPOS": [$($registeredJson -join ',')],
  "SKIPPED_REPOS": [$($skippedJson -join ',')],
  "ERROR_REPOS": [$($errorsJson -join ',')],
  "IGNORED_REPOS": [$($ignoredJson -join ',')],
  "MODE": "$mode",
  "DRY_RUN": $dryRunValue
}
"@
} else {
    # Text output
    Write-Host "=========================================="
    if ($IgnoreOnly) {
        Write-Host "Workspace Ignore Setup"
    } else {
        Write-Host "Workspace Submodule Setup"
    }
    Write-Host "=========================================="
    Write-Host ""
    
    if ($registeredRepos.Count -gt 0) {
        Write-Host "Registered ($($registeredRepos.Count)):"
        foreach ($repo in $registeredRepos) {
            Write-Host "  ✓ $repo"
        }
        Write-Host ""
    }
    
    if ($ignoredRepos.Count -gt 0) {
        Write-Host "Added to .gitignore ($($ignoredRepos.Count)):"
        foreach ($repo in $ignoredRepos) {
            Write-Host "  ✓ $repo"
        }
        Write-Host ""
    }
    
    if ($skippedRepos.Count -gt 0) {
        Write-Host "Skipped ($($skippedRepos.Count)):"
        foreach ($repo in $skippedRepos) {
            Write-Host "  - $repo"
        }
        Write-Host ""
    }
    
    if ($errorRepos.Count -gt 0) {
        Write-Host "Errors ($($errorRepos.Count)):"
        foreach ($repo in $errorRepos) {
            Write-Host "  ⚠ $repo"
        }
        Write-Host ""
    }
    
    if (($registeredRepos.Count -eq 0) -and ($ignoredRepos.Count -eq 0) -and ($skippedRepos.Count -eq 0) -and ($errorRepos.Count -eq 0)) {
        Write-Host "No child repositories found at depth 1."
        Write-Host ""
    }
    
    if (-not $DryRun) {
        if ($IgnoreOnly -and ($ignoredRepos.Count -gt 0)) {
            Write-Host "Next steps:"
            Write-Host "  - Child repos are now ignored by the parent"
            Write-Host "  - Each child remains an independent git repository"
        } elseif ($registeredRepos.Count -gt 0) {
            Write-Host "Next steps:"
            Write-Host "  - Team members can clone with: git clone --recursive <workspace-url>"
            Write-Host "  - Or initialize submodules: git submodule update --init"
        }
    }
}