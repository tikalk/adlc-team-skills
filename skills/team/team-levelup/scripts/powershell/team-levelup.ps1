# team-levelup.ps1 — Session-end CDR lifecycle entry point
# (PowerShell twin of bash/team-levelup.sh; one behavior, two platform scripts.)
$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

$SCRIPT_DIR = $PSScriptRoot
. (Join-Path $SCRIPT_DIR 'helpers.ps1')

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

# Output setup info
Write-Output "NEXT_CDR=$NEXT_CDR"
Write-Output "ADLC_BRANCH=$($script:ADLC_BRANCH)"
Write-Output "TEAM_AI_DIRECTIVES=$($script:TEAM_AI_DIRECTIVES)"
