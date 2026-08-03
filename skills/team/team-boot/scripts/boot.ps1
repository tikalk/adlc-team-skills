# team-boot session_start script — assembles team AI directives context.
# PowerShell native (ConvertFrom-Json).
$ErrorActionPreference = "Stop"

$INIT_FILE = ".adlc/init-options.json"

if (-not (Test-Path $INIT_FILE)) {
    Write-Output "Team AI directives not configured for this project."
    Write-Output "Run /team-setup to wire in team context modules (constitution, CDR index, PDR/ADR indexes)."
    exit 0
}

$init = Get-Content "$INIT_FILE" -Raw | ConvertFrom-Json
$TEAM_AI_DIRECTIVES = $init.team_ai_directives

if (-not $TEAM_AI_DIRECTIVES -or $TEAM_AI_DIRECTIVES -eq "null") {
    exit 0
}

if (-not (Test-Path $TEAM_AI_DIRECTIVES)) {
    Write-Output "Team AI directives path not found: $TEAM_AI_DIRECTIVES"
    exit 0
}

Write-Output "# Team AI Directives Context"
Write-Output ""
Write-Output "## Constitution"
$constPath = Join-Path $TEAM_AI_DIRECTIVES "context_modules/constitution.md"
if (Test-Path $constPath) { Get-Content $constPath -Raw } else { Write-Output "(not found)" }
Write-Output ""
Write-Output "## CDR Index"
$cdrPath = Join-Path $TEAM_AI_DIRECTIVES "CDR.md"
if (Test-Path $cdrPath) {
    $content = Get-Content $cdrPath -Raw
    $sections = $content -split "^---", 2
    Write-Output $sections[0]
} else { Write-Output "(not found)" }
Write-Output ""
Write-Output "## PDR Index"
if (Test-Path ".adlc/memory/pdr/pdr.md") { Get-Content ".adlc/memory/pdr/pdr.md" -Raw } else { Write-Output "(none)" }
Write-Output ""
Write-Output "## ADR Index"
if (Test-Path ".adlc/memory/adr/adr.md") { Get-Content ".adlc/memory/adr/adr.md" -Raw } else { Write-Output "(none)" }
Write-Output ""
Write-Output "## Available Skills"
$skillsPath = Join-Path $TEAM_AI_DIRECTIVES ".skills.json"
if (Test-Path $skillsPath) { Get-Content $skillsPath -Raw } else { Write-Output "(none)" }
Write-Output ""
Write-Output "---"
Write-Output "The CDR index lists all available team context modules. When a task"
Write-Output "matches a CDR descriptor, read the full module file at the Target"
Write-Output "Module path for the complete directive text."
