param(
    [switch]$Json
)

###############################################################################
# Inline path resolution (matches levelup setup scripts)
###############################################################################

$ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
    try { (git rev-parse --show-toplevel 2>$null) } catch { $null }
}
if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }

$Branch = if ($env:BRANCH) { $env:BRANCH } else {
    try { (git branch --show-current 2>$null) } catch { 'unknown' }
}
if (-not $Branch) { $Branch = 'unknown' }

# Resolve team directives: env var → init-options.json → default fallback
$TeamAiDirective = $env:TEAM_AI_DIRECTIVE
if (-not $TeamAiDirective) {
    $InitOptions = Join-Path $ProjectRoot ".adlc\init-options.json"
    if (Test-Path $InitOptions) {
        try {
            $Opts = Get-Content $InitOptions -Raw | ConvertFrom-Json
            $TeamAiDirective = $Opts.team_ai_directive
        } catch {
            $TeamAiDirective = ""
        }
    }
}
if (-not $TeamAiDirective) {
    $TeamAiDirective = Join-Path $ProjectRoot "team-ai-directives"
}

if ($Json) {
    @{ REPO_ROOT = $ProjectRoot; TEAM_AI_DIRECTIVE = $TeamAiDirective; BRANCH = $Branch } | ConvertTo-Json -Compress
} else {
    "REPO_ROOT=$ProjectRoot"
    "TEAM_AI_DIRECTIVE=$TeamAiDirective"
    "BRANCH=$Branch"
}
