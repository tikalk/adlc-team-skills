# scrub-session.ps1 — Privacy-scrub a session summary
# (PowerShell twin of bash/scrub-session.sh; one behavior, two platform scripts.)
$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Invoke-ScrubSession {
    param([string]$Text)
    $out = $Text
    $out = [regex]::Replace($out, '(?i)(api[_-]?key[=: ]+)[^ ]+', '$1REDACTED')
    $out = [regex]::Replace($out, '(?i)(token[=: ]+)[^ ]+', '$1REDACTED')
    $out = [regex]::Replace($out, '(?i)(password[=: ]+)[^ ]+', '$1REDACTED')
    $out = [regex]::Replace($out, '(?i)(secret[=: ]+)[^ ]+', '$1REDACTED')
    $out = [regex]::Replace($out, '(AKIA[A-Z0-9]{16})', 'REDACTED')
    $out = [regex]::Replace($out, '(ghp_[A-Za-z0-9]{36})', 'REDACTED')
    $out = [regex]::Replace($out, '(glpat-[A-Za-z0-9_-]{20})', 'REDACTED')
    return $out
}

if ($args.Count -ge 2 -and [string]$args[0] -eq '--scrub') {
    Write-Output (Invoke-ScrubSession ([string]$args[1]))
}
