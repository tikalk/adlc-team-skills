# helpers.ps1 — Shared utilities for the team-levelup skill
# (PowerShell twin of bash/helpers.sh; one behavior, two platform scripts;
# keep in lockstep.)
#
# CLI entry (parity with bash/helpers.sh):
#   --json               emit the resolved paths as JSON
#   --next-cdr [DIR]     next CDR number (3-digit, zero-padded)
#   --index [DIR]        regenerate the CDR index on the adlc branch
#   --signal-gate FILE   run the contribution signal gate on a draft
#
# The bash twin's output_json shells out to python3 for JSON safety; this
# twin uses native ConvertTo-Json (no python dependency on Windows).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

###############################################################################
# 1. PATH RESOLUTION
###############################################################################

function Resolve-TeamLevelupPaths {
    # Sets the script-scoped globals (parity with the bash twin's globals);
    # also writes them to stdout as KEY=VALUE lines — informational only,
    # never eval it.
    if (-not $env:PROJECT_ROOT) {
        $root = @(git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and $root.Count -gt 0 -and $root[0]) {
            $script:PROJECT_ROOT = [string]$root[0]
        } else {
            $script:PROJECT_ROOT = (Get-Location).Path
        }
    } else {
        $script:PROJECT_ROOT = $env:PROJECT_ROOT
    }
    if (-not $env:BRANCH) {
        $b = @(git branch --show-current 2>$null)
        if ($LASTEXITCODE -eq 0 -and $b.Count -gt 0 -and $b[0]) {
            $script:BRANCH = [string]$b[0]
        } else {
            $script:BRANCH = 'unknown'
        }
    } else {
        $script:BRANCH = $env:BRANCH
    }

    $script:TEAM_AI_DIRECTIVES = if ($env:TEAM_AI_DIRECTIVES) { $env:TEAM_AI_DIRECTIVES } else { '' }
    if ($script:TEAM_AI_DIRECTIVES -eq '' -and (Test-Path (Join-Path $script:PROJECT_ROOT '.adlc/init-options.json'))) {
        $m = Select-String -LiteralPath (Join-Path $script:PROJECT_ROOT '.adlc/init-options.json') -Pattern '"team_ai_directives"\s*:\s*"([^"]*)"' | Select-Object -First 1
        if ($m -and $m.Matches.Count -gt 0) { $script:TEAM_AI_DIRECTIVES = $m.Matches[0].Groups[1].Value }
    }
    if ($script:TEAM_AI_DIRECTIVES -eq '' -or $script:TEAM_AI_DIRECTIVES -eq 'null') {
        $script:TEAM_AI_DIRECTIVES = Join-Path $script:PROJECT_ROOT 'team-ai-directives'
    }

    $script:ADLC_BRANCH = 'adlc'
    $script:ADLC_WORKTREE = "/tmp/adlc-worktree-$PID"
    $script:CDR_DRAFTS_DIR = 'drafts/cdr'
    $script:CDR_INDEX_FILE = 'drafts/cdr/cdr.md'
    $script:REPORTS_DIR = 'reports'
    $script:SESSIONS_DIR = 'reports/sessions'
    $script:PROJECTS_DIR = 'reports/projects'
    $script:CONFIDENCE_FILE = 'reports/confidence-scores.json'

    Write-Output "PROJECT_ROOT=$($script:PROJECT_ROOT)"
    Write-Output "TEAM_AI_DIRECTIVES=$($script:TEAM_AI_DIRECTIVES)"
    Write-Output "BRANCH=$($script:BRANCH)"
    Write-Output "ADLC_BRANCH=$($script:ADLC_BRANCH)"
    Write-Output "ADLC_WORKTREE=$($script:ADLC_WORKTREE)"
    Write-Output "CDR_DRAFTS_DIR=$($script:CDR_DRAFTS_DIR)"
    Write-Output "CDR_INDEX_FILE=$($script:CDR_INDEX_FILE)"
    Write-Output "REPORTS_DIR=$($script:REPORTS_DIR)"
    Write-Output "SESSIONS_DIR=$($script:SESSIONS_DIR)"
    Write-Output "PROJECTS_DIR=$($script:PROJECTS_DIR)"
    Write-Output "CONFIDENCE_FILE=$($script:CONFIDENCE_FILE)"
}

function Output-Json {
    $null = Resolve-TeamLevelupPaths
    $payload = [ordered]@{
        REPO_ROOT          = $script:PROJECT_ROOT
        TEAM_AI_DIRECTIVES = $script:TEAM_AI_DIRECTIVES
        BRANCH             = $script:BRANCH
        ADLC_BRANCH        = $script:ADLC_BRANCH
        ADLC_WORKTREE      = $script:ADLC_WORKTREE
    }
    Write-Output ($payload | ConvertTo-Json -Compress)
}

###############################################################################
# 2. ADLC ORPHAN BRANCH MANAGEMENT
###############################################################################

function Ensure-AdlcBranch {
    param([string]$Td)
    if (-not $Td) { $Td = $script:TEAM_AI_DIRECTIVES }
    git -C $Td show-ref --verify --quiet "refs/heads/$($script:ADLC_BRANCH)" *> $null
    if ($LASTEXITCODE -eq 0) { return }

    git -C $Td branch --orphan $script:ADLC_BRANCH *> $null
    git -C $Td worktree add $script:ADLC_WORKTREE $script:ADLC_BRANCH *> $null
    New-Item -ItemType Directory -Force -Path (Join-Path $script:ADLC_WORKTREE 'drafts/cdr'), (Join-Path $script:ADLC_WORKTREE 'reports/sessions'), (Join-Path $script:ADLC_WORKTREE 'reports/projects') | Out-Null
    git -C $script:ADLC_WORKTREE add -A *> $null
    git -C $script:ADLC_WORKTREE commit --allow-empty -m 'Initialize adlc orphan branch' *> $null
    git -C $script:ADLC_WORKTREE push origin $script:ADLC_BRANCH *> $null
    git -C $Td worktree remove $script:ADLC_WORKTREE *> $null
}

###############################################################################
# 3. CDR SLUG MINTING
###############################################################################

function Slugify {
    param([string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) {
        Write-Error "ERROR: Title is empty"
        return $null
    }
    
    # 1. Lowercase
    $slug = $Title.ToLower()
    
    # 2. ASCII-fold (approximate in PS without complex mapping)
    $slug = [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::GetEncoding("Cyrillic").GetBytes($slug))
    
    # 3. Sanitize (non-alnum -> -)
    $slug = $slug -replace '[^a-z0-9]', '-'
    
    # 4. Collapse (multiple - -> single -)
    $slug = $slug -replace '-+', '-'
    
    # 5. Trim
    $slug = $slug.Trim('-')
    
    # 6. Truncate (max 60 chars)
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
    
    if ([string]::IsNullOrWhiteSpace($slug)) {
        Write-Error "ERROR: slugify result for '$Title' is empty"
        return $null
    }
    
    return $slug
}

function Mint-CdrSlug {
    param([string]$Title, [string]$Namespace = "rule", [string]$Td = "")
    if (-not $Td) { $Td = $script:TEAM_AI_DIRECTIVES }
    if (-not $Td) { return $null }
    
    $slug = Slugify $Title
    if (-not $slug) { return $null }
    
    $candidate = "$Namespace-$slug"
    if ($Namespace -eq "constitution" -and $slug -eq "constitution") {
        $candidate = "constitution"
    }
    
    $count = 1
    $finalSlug = $candidate
    
    # Pre-fetch lists
    $draftsList = @(git -C $Td ls-tree -r --name-only $script:ADLC_BRANCH "drafts/cdr/" 2>$null)
    $publishedList = @(git -C $Td ls-tree -r --name-only main "context_modules/" 2>$null)
    
    while ($true) {
        $exists = $false
        if ($draftsList -contains "drafts/cdr/$finalSlug.md") {
            $exists = $true
        }
        
        if (-not $exists) {
            $slugPart = $finalSlug -replace "^$Namespace-", ""
            if ($finalSlug -eq "constitution") { $slugPart = "constitution" }
            
            # Check published files (underscores as hyphens)
            foreach ($p in $publishedList) {
                $name = [System.IO.Path]::GetFileNameWithoutExtension($p).Replace('_', '-')
                if ($name -eq $slugPart) {
                    $exists = $true
                    break
                }
            }
        }
        
        if (-not $exists) {
            return $finalSlug
        }
        
        $count++
        $finalSlug = "$candidate-$count"
        if ($count -gt 100) { break }
    }
}

###############################################################################
# 4. ADLC BRANCH READ/WRITE
###############################################################################

function Read-AdlcFile {
    param([string]$Td, [string]$Path)
    if (-not $Td) { $Td = $script:TEAM_AI_DIRECTIVES }
    $out = @(git -C $Td show "$($script:ADLC_BRANCH):$Path" 2>$null)
    if ($LASTEXITCODE -ne 0) { return '' }
    return ($out -join "`n")
}

function Write-AdlcFile {
    param([string]$Td, [string]$Path, [string]$Content)
    if (-not $Td) { $Td = $script:TEAM_AI_DIRECTIVES }
    git -C $Td worktree add $script:ADLC_WORKTREE $script:ADLC_BRANCH *> $null
    if ($LASTEXITCODE -ne 0) {
        git -C $Td worktree add --force $script:ADLC_WORKTREE $script:ADLC_BRANCH *> $null
    }
    $dest = Join-Path $script:ADLC_WORKTREE $Path
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Set-Content -LiteralPath $dest -Value $Content -NoNewline
    git -C $script:ADLC_WORKTREE add $Path *> $null
    git -C $script:ADLC_WORKTREE commit -m "team-levelup: update $Path" *> $null
    git -C $script:ADLC_WORKTREE push origin $script:ADLC_BRANCH *> $null
    git -C $Td worktree remove $script:ADLC_WORKTREE *> $null
}

###############################################################################
# 5. CDR INDEX GENERATION
###############################################################################

function Regenerate-CdrIndex {
    param([string]$Td)
    if (-not $Td) { $Td = $script:TEAM_AI_DIRECTIVES }
    $indexPath = 'drafts/cdr/cdr.md'

    $today = Get-Date -Format 'yyyy-MM-dd'

    $entries = ''
    $count = 0

    $files = @(git -C $Td ls-tree --name-only $script:ADLC_BRANCH 'drafts/cdr/' 2>$null)
    foreach ($f in ($files | Sort-Object)) {
        if ($f -cnotmatch '\.md$') { continue }
        $id = [IO.Path]::GetFileNameWithoutExtension($f)
        $content = Read-AdlcFile $Td $f

        $target = Get-Field $content '^### Target Module:' 0
        $target = $target -replace '`', ''
        if ($target.Length -gt 40) { $target = $target.Substring(0, 40) }
        $type = Get-Field $content '^### Context Type:' 20
        $status = (Get-Field $content '^### Status:' 12) -replace '\*\*', ''
        $created = Get-Field $content '^### Date:' 10
        $verified = Get-Field $content '^verified:' 10
        $age = Get-Field $content '^age_days:' 5
        $descriptor = Get-Field $content '^### Descriptor:' 60

        if (-not $created) { $created = $today }
        if (-not $verified) { $verified = '-' }
        if (-not $age) { $age = '-' }

        $entries += "| $id | $(If($target){$target}else{' '}) | $(If($type){$type}else{' '}) | $(If($status){$status}else{'Discovered'}) | $created | $verified | $age | $(If($descriptor){$descriptor}else{' '}) |`n"
        $count++
    }

    $indexContent = @"
# Context Directive Records

Context Directive Records (CDRs) track proposed and accepted contributions to team-ai-directives.

## CDR Index

| ID | Target Module | Type | Status | Created | Verified | Age | Descriptor |
|----|---------------|------|--------|---------|----------|-----|------------|
$entries
**Stats**: $count entries | Last Updated: $today
"@
    # the bash twin's echo adds the final newline; Set-Content -NoNewline does not
    $indexContent += "`n"

    Write-AdlcFile $Td $indexPath $indexContent
    return $indexPath
}

# Extract the first line matching a ^header pattern, strip the header, cap
# the length (parity with the bash twin's grep -m1 | sed | head -c pipeline).
# Cap 0 or negative = uncapped.
function Get-Field {
    param([string]$Content, [string]$Pattern, [int]$Cap)
    foreach ($line in ($Content -split "`n")) {
        if ($line -cmatch $Pattern) {
            $v = ($line -creplace $Pattern, '').Trim()
            # bash head -c counts BYTES; ASCII-safe here — chars == bytes
            if ($Cap -gt 0 -and $v.Length -gt $Cap) { $v = $v.Substring(0, $Cap) }
            return $v
        }
    }
    return ''
}

###############################################################################
# 6. SIGNAL GATE VALIDATION
###############################################################################

function Invoke-SignalGate {
    param([string]$File)
    $reasons = @()

    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        # bash grep on a missing file: every grep fails → only the
        # "no evidence" reason fires (its grep -Eq also fails).
        return 'SKIP: no evidence'
    }
    $content = Get-Content -Raw -LiteralPath $File
    if ($content -imatch 'project-specific|only applies to this project|single project') { $reasons += 'project-specific' }
    if ($content -imatch 'duplicate of|overlaps with existing|already in team-ai-directives') { $reasons += 'duplicate' }
    if ($content -cnotmatch '(src/|lib/|test/|docs/|commit|file)') { $reasons += 'no evidence' }
    if ($content -imatch 'low value|nice-to-have|minor convenience') { $reasons += 'low value' }

    if ($reasons.Count -gt 0) {
        return "SKIP: $($reasons -join ' ')"
    }
    return 'PASS'
}

###############################################################################
# CLI ENTRY
###############################################################################

switch ($args.Count) {
    0 { }
    default {
        switch ([string]$args[0]) {
            '--json' { Output-Json }
            '--mint-cdr' {
                $null = Resolve-TeamLevelupPaths
                Mint-CdrSlug ([string]$args[1]) ([string]$args[2]) ([string]$args[3])
            }
            '--index' {
                $null = Resolve-TeamLevelupPaths
                Regenerate-CdrIndex $(if ($args.Count -ge 2) { [string]$args[1] } else { '' })
            }
            '--signal-gate' {
                if ($args.Count -lt 2) {
                    [Console]::Error.WriteLine('ERROR: --signal-gate requires a file path')
                    exit 1
                }
                # parity: the bash twin's function return code IS the exit
                # code (PASS → 0, SKIP → 1)
                $verdict = Invoke-SignalGate ([string]$args[1])
                Write-Output $verdict
                if ($verdict -eq 'PASS') { exit 0 } else { exit 1 }
            }
        }
    }
}
