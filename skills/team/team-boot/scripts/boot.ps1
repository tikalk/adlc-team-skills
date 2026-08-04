# team-boot session_start script — lean orientation for first user message injection.
# PowerShell native (ConvertFrom-Json).
$ErrorActionPreference = "Stop"

$INIT_FILE = ".adlc/init-options.json"

if (-not (Test-Path $INIT_FILE)) {
    Write-Output "<EXTREMELY_IMPORTANT>"
    Write-Output "Team AI directives not configured for this project."
    Write-Output "Run /team-setup to wire in the team constitution, CDR index, PDR/ADR indexes, and skill registry."
    Write-Output "</EXTREMELY_IMPORTANT>"
    exit 0
}

$init = Get-Content "$INIT_FILE" -Raw | ConvertFrom-Json
$TEAM_AI_DIRECTIVES = $init.team_ai_directives

if (-not $TEAM_AI_DIRECTIVES -or $TEAM_AI_DIRECTIVES -eq "null") {
    exit 0
}

if (-not (Test-Path $TEAM_AI_DIRECTIVES)) {
    Write-Output "<EXTREMELY_IMPORTANT>"
    Write-Output "Team AI directives path not found: $TEAM_AI_DIRECTIVES"
    Write-Output "Run /team-setup to reconfigure."
    Write-Output "</EXTREMELY_IMPORTANT>"
    exit 0
}

Write-Output "<EXTREMELY_IMPORTANT>"
Write-Output "# Team AI Directives"
Write-Output ""
Write-Output "Path: $TEAM_AI_DIRECTIVES"
Write-Output ""

# Constitution — principle titles only (lean)
Write-Output "## Constitution"
$constPath = Join-Path $TEAM_AI_DIRECTIVES "context_modules/constitution.md"
if (Test-Path $constPath) {
    Get-Content $constPath | Where-Object { $_ -match '^\d+\.' } | Select-Object -First 20
} else { Write-Output "(not found)" }
Write-Output ""

# CDR Index — compact: ID + Type + Descriptor only
Write-Output "## CDR Index"
$cdrPath = Join-Path $TEAM_AI_DIRECTIVES "CDR.md"
$CdrCount = 0
if (Test-Path $cdrPath) {
    $cdrLines = Get-Content $cdrPath | Where-Object { $_ -match '^\| CDR|^\| skill|^\| example' }
    $CdrCount = $cdrLines.Count
    $cdrLines | ForEach-Object {
        $cols = $_ -split '\|'
        if ($cols.Count -ge 10) {
            $id = $cols[1].Trim()
            $type = $cols[3].Trim()
            $desc = $cols[8].Trim()
            Write-Output "| $id | $type | $desc |"
        }
    }
} else { Write-Output "(not found)" }
Write-Output ""
Write-Output "_Total: $CdrCount CDR entries available._"
Write-Output ""

# Skills — names + descriptions only (lean)
Write-Output "## Available Skills"
$skillsPath = Join-Path $TEAM_AI_DIRECTIVES ".skills.json"
$SkillTotal = 0
if (Test-Path $skillsPath) {
    $skills = Get-Content $skillsPath -Raw | ConvertFrom-Json
    $SkillTotal = $skills.default.Count + $skills.external.PSObject.Properties.Count
    foreach ($name in $skills.default) { Write-Output "- $name" }
    foreach ($entry in $skills.external.PSObject.Properties) {
        Write-Output "- $($entry.Name): $($entry.Value.description)"
    }
} else { Write-Output "(none)" }
Write-Output ""
Write-Output "_Total: $SkillTotal skills available._"
Write-Output ""

# MCP Servers — names only (lean)
Write-Output "## MCP Servers"
$mcpPath = Join-Path $TEAM_AI_DIRECTIVES ".mcp.json"
if (Test-Path $mcpPath) {
    $mcp = Get-Content $mcpPath -Raw | ConvertFrom-Json
    foreach ($name in $mcp.mcpServers.PSObject.Properties.Name) { Write-Output "- $name" }
} else { Write-Output "(none)" }
Write-Output ""

Write-Output "Read full CDR.md, .skills.json, and context module files on demand when a task matches."
Write-Output ""
Write-Output "**Every response MUST include** a Team Context in Use section before the task answer:"
Write-Output "Match CDR entries and skills from the lists above to the current task."
Write-Output ""
Write-Output "| ID | Type | Relevance |"
Write-Output "|----|------|-----------|"
Write-Output "| CDR-2026-003 | Persona | High |"
Write-Output ""
Write-Output "Plus: _Searched $CdrCount CDR entries, $SkillTotal skills, J matched._"
Write-Output "</EXTREMELY_IMPORTANT>"
