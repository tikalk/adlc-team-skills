#!/usr/bin/env pwsh

param(
    [switch]$Json,
    [switch]$DryRun,
    [switch]$Check
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
        '{"error": "Not a git repository."}'
    } else {
        Write-Error "Not a git repository."
    }
    exit 1
}

# Rules to manage
$ignoreRules = @(
    ".specify/extensions/.cache/",
    ".specify/extensions/.backup/",
    ".specify/extensions/*/*.local.yml",
    ".specify/extensions/.registry"
)

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

$addedIgnore = @()
$addedNegations = @()
$verifiedIgnore = @()
$verifiedNegations = @()

# Ensure .gitignore exists
function Ensure-Gitignore() {
    if (-not (Test-Path ".gitignore")) {
        if (-not $DryRun -and -not $Check) {
            New-Item -ItemType File -Name ".gitignore" | Out-Null
        }
    }
}

# Check if rule exists in .gitignore
function Rule-Exists($rule) {
    $gitignoreContent = Get-Content ".gitignore" -ErrorAction SilentlyContinue
    return $gitignoreContent -contains $rule
}

# Process rules
function Process-Rules() {
    foreach ($rule in $ignoreRules) {
        if (Rule-Exists $rule) {
            $verifiedIgnore += $rule
        } else {
            if (-not $Check -and -not $DryRun) {
                Add-Content -Path ".gitignore" -Value $rule
                $addedIgnore += $rule
            } elseif ($DryRun) {
                $addedIgnore += $rule
            }
        }
    }

    foreach ($rule in $negationRules) {
        if (Rule-Exists $rule) {
            $verifiedNegations += $rule
        } else {
            if (-not $Check -and -not $DryRun) {
                Add-Content -Path ".gitignore" -Value $rule
                $addedNegations += $rule
            } elseif ($DryRun) {
                $addedNegations += $rule
            }
        }
    }
}

# Main execution
Ensure-Gitignore
Process-Rules

# Commit changes if not dry run and rules were added
if (-not $DryRun -and -not $Check) {
    if ($addedIgnore.Count -gt 0 -or $addedNegations.Count -gt 0) {
        git add .gitignore 2>$null | Out-Null
        git commit -m "[Spec Kit] Configure .gitignore for spec-kit directories" 2>$null | Out-Null
    }
}

# Output results
if ($Json) {
    $addedIgnoreJson = $addedIgnore | ForEach-Object { '"' + $_ + '"' }
    $addedNegationsJson = $addedNegations | ForEach-Object { '"' + $_ + '"' }
    $verifiedIgnoreJson = $verifiedIgnore | ForEach-Object { '"' + $_ + '"' }
    $verifiedNegationsJson = $verifiedNegations | ForEach-Object { '"' + $_ + '"' }
    
    $dryRunValue = if ($DryRun) { "true" } else { "false" }
    $checkValue = if ($Check) { "true" } else { "false" }
    
    @"
{
  "ADDED_IGNORE": [$($addedIgnoreJson -join ',')],
  "ADDED_NEGATIONS": [$($addedNegationsJson -join ',')],
  "VERIFIED_IGNORE": [$($verifiedIgnoreJson -join ',')],
  "VERIFIED_NEGATIONS": [$($verifiedNegationsJson -join ',')],
  "DRY_RUN": $dryRunValue,
  "CHECK_ONLY": $checkValue
}
"@
} else {
    # Text output
    if ($DryRun) {
        Write-Host "=========================================="
        Write-Host "Spec Kit .gitignore Setup (DRY RUN)"
        Write-Host "=========================================="
        Write-Host ""
        
        if ($addedIgnore.Count -gt 0) {
            Write-Host "Would add ignore rules ($($addedIgnore.Count)):"
            foreach ($rule in $addedIgnore) {
                Write-Host "  → $rule"
            }
            Write-Host ""
        }
        
        if ($addedNegations.Count -gt 0) {
            Write-Host "Would add negation rules ($($addedNegations.Count)):"
            foreach ($rule in $addedNegations) {
                Write-Host "  → $rule"
            }
            Write-Host ""
        }
        
        if ($addedIgnore.Count -eq 0 -and $addedNegations.Count -eq 0) {
            Write-Host "All rules already configured"
            Write-Host ""
        }
    } elseif ($Check) {
        Write-Host "=========================================="
        Write-Host "Spec Kit .gitignore Setup (CHECK ONLY)"
        Write-Host "=========================================="
        Write-Host ""
        
        if ($verifiedIgnore.Count -eq $ignoreRules.Count -and $verifiedNegations.Count -eq $negationRules.Count) {
            Write-Host "All rules already configured ✓"
            Write-Host ""
        } else {
            $missingIgnore = $ignoreRules.Count - $verifiedIgnore.Count
            $missingNegations = $negationRules.Count - $verifiedNegations.Count
            Write-Host "Missing rules ($missingIgnore ignore, $missingNegations negations)"
            Write-Host ""
        }
        
        Write-Host "Verified ignore rules ($($verifiedIgnore.Count)):"
        foreach ($rule in $verifiedIgnore) {
            Write-Host "  ✓ $rule"
        }
        Write-Host ""
        
        Write-Host "Verified negation rules ($($verifiedNegations.Count)):"
        foreach ($rule in $verifiedNegations) {
            Write-Host "  ✓ $rule"
        }
        Write-Host ""
    } else {
        Write-Host "=========================================="
        Write-Host "Spec Kit .gitignore Setup"
        Write-Host "=========================================="
        Write-Host ""
        
        if ($addedIgnore.Count -gt 0 -or $addedNegations.Count -gt 0) {
            if ($addedIgnore.Count -gt 0) {
                Write-Host "Rules added ($($addedIgnore.Count)):"
                foreach ($rule in $addedIgnore) {
                    Write-Host "  ✓ $rule"
                }
                Write-Host ""
            }
            
            if ($addedNegations.Count -gt 0) {
                Write-Host "Negation rules added ($($addedNegations.Count)):"
                foreach ($rule in $addedNegations) {
                    Write-Host "  ✓ $rule"
                }
                Write-Host ""
            }
            
            Write-Host "Changes committed:"
            Write-Host "  [Spec Kit] Configure .gitignore for spec-kit directories"
        } else {
            Write-Host "All rules already configured ✓"
            Write-Host ""
            Write-Host "Verified rules ($($verifiedIgnore.Count) ignore, $($verifiedNegations.Count) negations)"
        }
        Write-Host ""
    }
}

exit 0