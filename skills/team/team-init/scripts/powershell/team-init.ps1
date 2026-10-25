# team-init.ps1 — Brownfield CDR discovery entry point
# (PowerShell twin of bash/team-init.sh; one behavior, two platform scripts.)
$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

$SCRIPT_DIR = $PSScriptRoot
# Source team-levelup helpers (shared utilities)
# (see the bash twin's note: the pre-move path was one level short)
$LEVELUP_HELPERS = Join-Path $SCRIPT_DIR "../../../team-levelup/scripts/powershell/helpers.ps1"
if (Test-Path -LiteralPath $LEVELUP_HELPERS) {
    . $LEVELUP_HELPERS
} else {
    [Console]::Error.WriteLine("Error: team-levelup helpers not found at $LEVELUP_HELPERS")
    exit 1
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
