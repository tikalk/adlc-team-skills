# score-confidence.ps1 — Calculate confidence score for a CDR
# (PowerShell twin of bash/score-confidence.sh; one behavior, two platform
# scripts. The bash twin uses awk for float math; this twin uses [double].)

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Get-Calc {
    param([double]$Value)
    return ('{0:F2}' -f $Value)
}

function Get-CdrField {
    param([string]$CdrFile, [string]$Pattern)
    if (-not (Test-Path -LiteralPath $CdrFile -PathType Leaf)) { return '' }
    foreach ($line in (Get-Content -LiteralPath $CdrFile)) {
        if ($line -cmatch $Pattern) {
            return ($line -creplace $Pattern, '').Trim()
        }
    }
    return ''
}

function Get-CalculateConfidence {
    param([string]$CdrFile, [string]$ConfidenceFile = '')

    $baseScore = 0.60
    $bonuses = 0.00
    $usageMultiplier = 1.0

    # Determine base score by type
    $type = (Get-CdrField $CdrFile '^### Context Type:').ToLower()
    if (-not $type) { $type = 'rule' }
    switch ($type) {
        'rule'         { $baseScore = 0.60 }
        'persona'      { $baseScore = 0.50 }
        'example'      { $baseScore = 0.50 }
        'constitution' { $baseScore = 0.70 }
        default        { $baseScore = 0.60 }
    }

    $content = if (Test-Path -LiteralPath $CdrFile -PathType Leaf) { Get-Content -Raw -LiteralPath $CdrFile } else { '' }

    # Bonus: paired eval exists
    if ($content -cmatch '### Paired Eval') { $bonuses += 0.20 }

    # Bonus: evidence includes file paths/commits
    if ($content -cmatch '(src/|lib/|test/|docs/|commit|file)') { $bonuses += 0.10 }

    # Bonus: multiple projects
    $projectField = if (Test-Path -LiteralPath $CdrFile -PathType Leaf) { Get-CdrField $CdrFile '^project:' } else { '' }
    if ($projectField -cmatch ',') { $bonuses += 0.10 }

    # Usage multiplier from confidence-scores.json
    if ($ConfidenceFile -ne '' -and (Test-Path -LiteralPath $ConfidenceFile -PathType Leaf)) {
        $cdrId = [IO.Path]::GetFileNameWithoutExtension($CdrFile)
        # Parse success_rate from JSON (no jq dependency — same grep/sed
        # contract as the bash twin: "CDR-001": { "success_rate": 0.75, ... })
        $successRate = 1.0
        $raw = Get-Content -Raw -LiteralPath $ConfidenceFile
        $m = [regex]::Match($raw, ('"' + [regex]::Escape($cdrId) + '"[\s\S]{0,300}?"success_rate"\s*:\s*([0-9.]+)'))
        if ($m.Success) { $successRate = [double]$m.Groups[1].Value }

        if ($successRate -gt 0.8) { $usageMultiplier = 1.2 }
        elseif ($successRate -lt 0.5) { $usageMultiplier = 0.8 }
    }

    $finalScore = ($baseScore + $bonuses) * $usageMultiplier
    # Cap at 1.0
    if ($finalScore -gt 1.0) { $finalScore = 1.00 }

    $tier = 'LOW'
    if ($finalScore -ge 0.8) { $tier = 'HIGH' }
    elseif ($finalScore -ge 0.5 -and $finalScore -lt 0.8) { $tier = 'MEDIUM' }

    return "$(Get-Calc $finalScore) $tier"
}

# CLI entry
if ($args.Count -ge 2 -and [string]$args[0] -eq '--calculate') {
    Write-Output (Get-CalculateConfidence ([string]$args[1]) $(if ($args.Count -ge 3) { [string]$args[2] } else { '' }))
}
