# validate-pdr.ps1 — PDR Validation Script for individual PDR files
# PowerShell twin of bash/validate-pdr.sh; one behavior, two platform
# scripts; keep in lockstep.
# Usage: validate-pdr.ps1 [PDR_FILE]

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

$PDR_FILE = if ($args.Count -ge 1) { [string]$args[0] } else { '' }
if ($PDR_FILE -eq '' -or -not (Test-Path -LiteralPath $PDR_FILE -PathType Leaf)) {
    [Console]::Error.WriteLine("ERROR: PDR file not found: $PDR_FILE")
    [Console]::Error.WriteLine("Usage: validate-pdr.ps1 <pdr-file.md>")
    exit 1
}

$ERRORS = 0
$WARNINGS = 0
function pass([string]$msg) { [Console]::Out.WriteLine("  ✓ $msg") }
function warn([string]$msg) { [Console]::Out.WriteLine("  ⚠ $msg"); $script:WARNINGS++ }
function fail([string]$msg) { [Console]::Out.WriteLine("  ✗ $msg"); $script:ERRORS++ }

# PowerShell -match is case-insensitive (grep -qi parity); -cmatch where the
# bash grep is case-sensitive.
$lines = Get-Content -LiteralPath $PDR_FILE
$content = $lines -join "`n"

[Console]::Out.WriteLine("🔍 Validating PDR: $PDR_FILE")

# Check required sections
foreach ($header in 'Context', 'Decision', 'Consequences') {
    if ($content -imatch "(?m)^###?\s*$header") {
        pass "Has '$header' section"
    } else {
        fail "Missing '$header' section"
    }
}

# Check status
if ($content -imatch '(?m)^\*\*Status\*\*' -or $content -imatch '(?m)^\*\*(Proposed|Accepted|Discovered|Deprecated|Superseded)') {
    pass "Has valid status"
} else {
    warn "No valid status marker found"
}

# Check alternatives
if ($content -imatch "Alternatives Considered") {
    pass "Has 'Alternatives Considered' section"
} else {
    warn "Missing 'Alternatives Considered'"
}

# Check for placeholders
if ($content -cmatch '\[(Category|Problem|Decision Title|Owner)\]') {
    warn "Contains template placeholders"
}

# Summary
[Console]::Out.WriteLine("")
if ($ERRORS -eq 0 -and $WARNINGS -eq 0) {
    [Console]::Out.WriteLine("✓ PDR validation passed")
    exit 0
} elseif ($ERRORS -eq 0) {
    [Console]::Out.WriteLine("⚠ $WARNINGS warning(s)")
    exit 2
} else {
    [Console]::Out.WriteLine("✗ $ERRORS error(s) and $WARNINGS warning(s)")
    exit 1
}
