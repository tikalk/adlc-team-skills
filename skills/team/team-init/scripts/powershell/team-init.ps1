# team-init.ps1 — Brownfield CDR discovery entry point
# (PowerShell twin of bash/team-init.sh; one behavior, two platform scripts.)
$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

# team-init delegates CDR lifecycle operations to the team-levelup skill.
# Invoke the team-levelup skill for CDR work; the path/numbering functions
# below are vendored self-contained (no cross-skill sourcing per scope rule).

function Resolve-TeamLevelupPaths {
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
    Write-Output "PROJECT_ROOT=$($script:PROJECT_ROOT)"
    Write-Output "TEAM_AI_DIRECTIVES=$($script:TEAM_AI_DIRECTIVES)"
    Write-Output "BRANCH=$($script:BRANCH)"
    Write-Output "ADLC_BRANCH=$($script:ADLC_BRANCH)"
    Write-Output "ADLC_WORKTREE=$($script:ADLC_WORKTREE)"
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

function Get-NextCdrNumber {
    param([string]$Td)
    if (-not $Td) { $Td = $script:TEAM_AI_DIRECTIVES }
    $max = 0
    $files = @(git -C $Td ls-tree --name-only $script:ADLC_BRANCH 'drafts/cdr/' 2>$null)
    foreach ($f in ($files | Sort-Object)) {
        $name = [System.IO.Path]::GetFileName($f)
        if ($name -cnotlike '*.md') { continue }
        if ($name.Substring(0, $name.Length - 3) -cmatch '^CDR-(\d+)') {
            $num = [int]$Matches[1]
            if ($num -gt $max) { $max = $num }
        }
    }
    return ('{0:d3}' -f ($max + 1))
}

if ($args.Count -ge 1 -and [string]$args[0] -eq '--setup') {
    Output-Json
    exit 0
}

# Resolve paths (function sets the script-scoped globals directly; output is
# informational only — never eval it)
$null = Resolve-TeamLevelupPaths

if (-not $script:TEAM_AI_DIRECTIVES -or -not (Test-Path -LiteralPath $script:TEAM_AI_DIRECTIVES -PathType Container)) {
    [Console]::Error.WriteLine('Team AI directives repository not configured.')
    [Console]::Error.WriteLine('Run: /team-setup')
    exit 1
}

# Ensure adlc orphan branch exists
Ensure-AdlcBranch $script:TEAM_AI_DIRECTIVES

# Get next CDR number
$NEXT_CDR = Get-NextCdrNumber $script:TEAM_AI_DIRECTIVES

Write-Output "REPO_ROOT=$($script:PROJECT_ROOT)"
Write-Output "TEAM_AI_DIRECTIVES=$($script:TEAM_AI_DIRECTIVES)"
Write-Output "NEXT_CDR=$NEXT_CDR"
Write-Output "ADLC_BRANCH=$($script:ADLC_BRANCH)"
Write-Output ''
Write-Output 'Ready for multi-agent brownfield analysis.'
Write-Output "CDRs will be written to: $($script:TEAM_AI_DIRECTIVES) (adlc branch, drafts/cdr/)"
