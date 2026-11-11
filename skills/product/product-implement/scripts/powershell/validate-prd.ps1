# validate-prd.ps1 — PRD Validation Script v1.5.7
# PowerShell twin of bash/validate-prd.sh; one behavior, two platform
# scripts; keep in lockstep.
# Validates PRD compliance with product extension standards
# Checks: Section 1 = Doc Info, in-section diagrams, Mermaid, business sections, self-contained, PDR traceability
# Usage: validate-prd.ps1 [PRD_FILE] [--strict|--warn]
#
# Exit codes:
#   0 = All checks passed
#   1 = Critical failures (in strict mode) or validation errors
#   2 = Warnings only (default warn mode)

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

# Colors for output
$RED = "`e[0;31m"
$YELLOW = "`e[1;33m"
$GREEN = "`e[0;32m"
$BLUE = "`e[0;34m"
$NC = "`e[0m" # No Color

# Configuration
$STRICT_MODE = $false
$WARN_MODE = $true
$PRD_FILE = if ($args.Count -ge 1) { [string]$args[0] } else { 'docs/adlc/product/PRD.md' }
# dual-read: bare invocation on a legacy-only repo falls back to the
# repo-root PRD.md (mirrors the dual-check in setup-product-analyze.sh).
# An explicit path argument is always honored verbatim.
if ($args.Count -eq 0 -and -not (Test-Path -LiteralPath $PRD_FILE) -and (Test-Path -LiteralPath 'PRD.md')) {
    $PRD_FILE = 'PRD.md'
}
$WARNINGS = 0
$ERRORS = 0

function Show-Help {
    Write-Output "Usage: $PSCommandPath [PRD_FILE] [--strict|--warn]"
    Write-Output ""
    Write-Output "Validates PRD compliance with product extension v1.5.6 standards"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  --strict    Exit with error on any issue (default: warn only)"
    Write-Output "  --warn      Show warnings but don't exit with error (default)"
    Write-Output "  --help      Show this help message"
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  $PSCommandPath                          # Validate PRD.md with warnings"
    Write-Output "  $PSCommandPath my-prd.md --strict       # Strict validation of my-prd.md"
    Write-Output "  $PSCommandPath .adlc/product/sections/ecosystem/overview.md  # Validate section"
}

# Parse arguments
foreach ($arg in $args) {
    switch ([string]$arg) {
        '--strict' {
            $STRICT_MODE = $true
            $WARN_MODE = $false
        }
        '--warn' {
            $STRICT_MODE = $false
            $WARN_MODE = $true
        }
        '--help' { Show-Help; exit 0 }
        '-h' { Show-Help; exit 0 }
    }
}

# Check if file exists
if (-not (Test-Path -LiteralPath $PRD_FILE -PathType Leaf)) {
    [Console]::Out.WriteLine(('{0}ERROR: PRD file not found: {1}{2}' -f $RED, $PRD_FILE, $NC))
    exit 1
}

# Read the file once; $lines is 1-based-mapped via [$i-1].
$lines = @(Get-Content -LiteralPath $PRD_FILE)
$content = $lines -join "`n"

# Function to report success
function pass {
    param([string]$msg)
    [Console]::Out.WriteLine(('{0}✓{1} {2}' -f $GREEN, $NC, $msg))
}

# Function to report warning
function warn {
    param([string]$msg)
    if ($WARN_MODE) {
        [Console]::Out.WriteLine(('{0}⚠ WARNING{1}: {2}' -f $YELLOW, $NC, $msg))
    } else {
        [Console]::Out.WriteLine(('{0}✗ ERROR{1}: {2}' -f $RED, $NC, $msg))
    }
    $script:WARNINGS++
}

# Function to report error
function fail {
    param([string]$msg)
    [Console]::Out.WriteLine(('{0}✗ FAIL{1}: {2}' -f $RED, $NC, $msg))
    $script:ERRORS++
}

# grep -c parity: count LINES matching (case-sensitive unless noted).
function Count-Lines {
    param([string]$Pattern)
    return @($lines | Where-Object { $_ -cmatch $Pattern }).Count
}

[Console]::Out.WriteLine(('{0}🔍 Validating PRD: {1}{2}' -f $BLUE, $PRD_FILE, $NC))
$modeLabel = if ($STRICT_MODE) { 'STRICT' } else { 'WARN' }
[Console]::Out.WriteLine(('{0}Extension Version: 1.5.7 | Mode: {1}{2}' -f $BLUE, $modeLabel, $NC))
[Console]::Out.WriteLine("================================================")

# ============================================
# CHECK 1: Section 1 is Document Information (v1.5.6)
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[1/9] Checking Section 1 is Document Information...{1}' -f $BLUE, $NC))

# Get the first section header
$FIRST_SECTION = @($lines | Where-Object { $_ -cmatch '^## [0-9]+\.?\s' } | Select-Object -First 1)

if ($FIRST_SECTION.Count -eq 0) {
    fail "No numbered sections found (## 1. format required)"
} else {
    if ($FIRST_SECTION[0] -imatch '^## 1\.\s*Document Information') {
        pass "Section 1 is 'Document Information' (v1.5.6 compliant)"
    } elseif ($FIRST_SECTION[0] -imatch '^## 1\.\s*Visual Summary') {
        warn "Section 1 is 'Visual Summary' - v1.5.6 requires 'Document Information' as Section 1 (diagrams are now in-section)"
    } else {
        warn "Section 1 is: $($FIRST_SECTION[0])"
        warn "Expected Section 1 to be 'Document Information' per v1.5.6 template"
    }
}

# Check that Visual Summary does NOT exist as a separate section
if ($content -imatch '(?m)^## [0-9]*\.?\s*Visual Summary') {
    warn "Found 'Visual Summary' as a separate section - v1.5.6 embeds diagrams in-section instead"
} else {
    pass "No separate Visual Summary section (diagrams are embedded in-section per v1.5.6)"
}

# ============================================
# CHECK 2: No ASCII Diagrams in Main Content
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[2/9] Checking for ASCII diagrams...{1}' -f $BLUE, $NC))

# Box-drawing characters (Unicode range U+2500 to U+257F)
$ASCII_MATCHES = @(Get-Content -LiteralPath $PRD_FILE | Select-String -Pattern '[─━│┃┄┅┆┇┈┉┊┋┌┍┎┏┐┑┒┓└┕┖┗┘┙┚┛├┝┞┟┠┡┢┣┤┥┦┧┨┩┪┫┬┭┮┯┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋╌╍╎╏═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬╭╮╯╰╱╲╳╴╵╶╷╸╹╺╻╼╽╾╿]')

if ($ASCII_MATCHES.Count -gt 0) {
    # Check context - are they in <details> blocks?
    $OUTSIDE_DETAILS = $false

    foreach ($m in $ASCII_MATCHES) {
        $LINE_NUM = $m.LineNumber
        # Simple check: count details tags before this line (head -n N parity)
        $head = if ($LINE_NUM -ge 1) { $lines[0..($LINE_NUM - 1)] } else { @() }
        $DETAILS_OPEN = @($head | Where-Object { $_ -cmatch '<details>' }).Count
        $DETAILS_CLOSE = @($head | Where-Object { $_ -cmatch '</details>' }).Count

        if ($DETAILS_OPEN -le $DETAILS_CLOSE) {
            $OUTSIDE_DETAILS = $true
            break
        }
    }

    if ($OUTSIDE_DETAILS) {
        fail "ASCII box-drawing characters found OUTSIDE <details> blocks"
        foreach ($m in (@($ASCII_MATCHES) | Select-Object -First 3)) {
            [Console]::Out.WriteLine("  Line: $($m.LineNumber):$($m.Line)")
        }
        if ($ASCII_MATCHES.Count -gt 3) {
            [Console]::Out.WriteLine("  ... and $($ASCII_MATCHES.Count - 3) more lines")
        }
        [Console]::Out.WriteLine("")
        [Console]::Out.WriteLine("  ASCII diagrams are ONLY allowed in <details> blocks as fallbacks.")
        [Console]::Out.WriteLine('  Main content MUST use Mermaid (```mermaid)')
    } else {
        pass "ASCII characters found only in <details> blocks (allowed as fallback)"
    }
} else {
    pass "No ASCII box-drawing characters found"
}

# ============================================
# CHECK 3: Mermaid Diagrams Present
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[3/9] Checking Mermaid diagrams...{1}' -f $BLUE, $NC))

$MERMAID_COUNT = Count-Lines '^\s*```mermaid'

if ($MERMAID_COUNT -eq 0) {
    fail "No Mermaid diagrams found - MUST have at least 1"
    [Console]::Out.WriteLine('  Use: ```mermaid blocks with flowchart/stateDiagram/etc')
} elseif ($MERMAID_COUNT -lt 2) {
    warn "Only $MERMAID_COUNT Mermaid diagram(s) - recommend 2+ (hierarchy, deps, flows)"
} else {
    pass "Found $MERMAID_COUNT Mermaid diagrams"
}

# Check for deprecated 'graph' keyword
$GRAPH_COUNT = Count-Lines '^\s*graph\s+(TD|TB|LR|BT|RL)'
if ($GRAPH_COUNT -gt 0) {
    warn "Found $GRAPH_COUNT deprecated 'graph' keyword(s) - use 'flowchart' (Mermaid v10+)"
}

# ============================================
# CHECK 4: No Unfilled Placeholders
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[4/9] Checking for unfilled placeholders...{1}' -f $BLUE, $NC))

$PLACEHOLDER_PATTERNS = @(
    '\[PRODUCT_NAME\]'
    '\[FEATURE_AREA_NAME\]'
    '\[PDR_IDS\]'
    '\[DATE\]'
    '\[PLACEHOLDER\]'
    '\[TODO\]'
    '\[TBD\]'
    '\[Author\]'
    '\[X\.X\]'
)

$FOUND_PLACEHOLDERS = 0
foreach ($pattern in $PLACEHOLDER_PATTERNS) {
    $lineNums = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch $pattern) { $lineNums += $i }
    }
    if ($lineNums.Count -gt 0) {
        foreach ($i in $lineNums) {
            fail "Unfilled placeholder: $($i + 1):$($lines[$i])"
        }
        $FOUND_PLACEHOLDERS += $lineNums.Count
    }
}

if ($FOUND_PLACEHOLDERS -eq 0) {
    pass "No unfilled placeholders found"
}

# ============================================
# CHECK 5: PDR Traceability
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[5/9] Checking PDR traceability...{1}' -f $BLUE, $NC))

# Count requirements
$REQ_COUNT = Count-Lines '^\s*[-*+]?\s*\*\*REQ-[0-9]+:?\*\*'
# Count PDR references
$PDR_REFS = Count-Lines 'PDR-[0-9]+'

if ($REQ_COUNT -gt 0) {
    pass "Found $REQ_COUNT requirements (REQ-XXX format)"

    # Check if requirements have PDR references
    $REQ_WITH_PDR = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '^\s*[-*+]?\s*\*\*REQ-[0-9]+:?\*\*') {
            # Check next 3 lines for PDR reference (sed N,N+3 parity)
            $end = [Math]::Min($i + 3, $lines.Count - 1)
            $CONTEXT = $lines[$i..$end] -join "`n"
            if ($CONTEXT -cmatch 'PDR-[0-9]+') {
                $REQ_WITH_PDR++
            }
        }
    }

    if ($REQ_WITH_PDR -lt $REQ_COUNT) {
        warn "Only $REQ_WITH_PDR/$REQ_COUNT requirements have PDR traceability"
        [Console]::Out.WriteLine('  Each requirement MUST reference a source PDR')
    } else {
        pass "All requirements trace to PDRs"
    }
} else {
    warn "No REQ-XXX format requirements found - consider using this format for traceability"
}

# ============================================
# CHECK 6: Required Sections Present
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[6/9] Checking required sections...{1}' -f $BLUE, $NC))

$REQUIRED_SECTIONS = @(
    "1.*Document Information"
    "2.*Overview"
    "3.*Problem|3.*The Problem"
    "4.*Goals|4.*Objectives"
    "5.*Metrics|5.*Success Metrics"
    "6.*Personas"
    "7.*Functional Requirements|7.*Requirements"
    "8.*Non-Functional|8.*NFRs"
    "9.*Out of Scope"
    "10.*Risks|10.*Mitigation"
    "11.*Roadmap|11.*Milestones"
    "12.*PDR Summary|12.*Product Decision"
)

$MISSING_SECTIONS = 0
foreach ($section_pattern in $REQUIRED_SECTIONS) {
    if (-not ($content -imatch "(?m)^## [0-9]*\.?.*($section_pattern)")) {
        warn "Missing or misnumbered section matching: $section_pattern"
        $MISSING_SECTIONS++
    }
}

if ($MISSING_SECTIONS -eq 0) {
    pass "All required sections present and numbered"
}

# ============================================
# CHECK 6.5: Business Sections (v1.5.3)
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[6.5/9] Checking business stakeholder sections (v1.5.6)...{1}' -f $BLUE, $NC))

$BUSINESS_SECTIONS = @(
    "1\.5.*Executive Summary"
    "3\.5.*Market Opportunity"
    "10\.5.*Investment"
    "11\.5.*Go-to-Market"
)

$MISSING_BUSINESS = 0
foreach ($biz_pattern in $BUSINESS_SECTIONS) {
    if ($content -imatch "(?m)^## $biz_pattern") {
        pass "Found business section: $biz_pattern"
    } else {
        warn "Missing business section: $biz_pattern (recommended for stakeholder PRDs)"
        $MISSING_BUSINESS++
    }
}

if ($MISSING_BUSINESS -eq 0) {
    pass "All 4 business stakeholder sections present"
}

# ============================================
# CHECK 6.6: Self-Contained PRD (v1.5.3)
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[6.6/9] Checking self-contained PRD (v1.5.6 - no external .adlc/ links)...{1}' -f $BLUE, $NC))

# Check for reader-facing links to .adlc/ paths
$EXTERNAL_LINKS_FILTERED = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -cmatch '\]\(\.adlc/') {
        # Skip if inside HTML comment
        if (-not ($lines[$i] -cmatch '<!--')) {
            $EXTERNAL_LINKS_FILTERED += "$($i + 1):$($lines[$i])"
        }
    }
}

if ($EXTERNAL_LINKS_FILTERED.Count -gt 0) {
    warn "PRD contains reader-facing links to .adlc/ files (should be self-contained)"
    foreach ($line in ($EXTERNAL_LINKS_FILTERED | Select-Object -First 5)) {
        [Console]::Out.WriteLine("  $line")
    }
    [Console]::Out.WriteLine('  Use in-document anchors instead: [Section 1.1](#11-feature-hierarchy)')
} else {
    pass "PRD is self-contained (no reader-facing .adlc/ links)"
}

# ============================================
# CHECK 7: Constitution Alignment Claims
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine(('{0}[7/9] Checking constitution alignment...{1}' -f $BLUE, $NC))

if ($content -imatch 'Constitution Alignment|Aligns with Constitution') {
    pass "Constitution alignment section found"

    # Check if constitution is populated (not just template)
    # dual-read: canonical docs/adlc/memory first, legacy fallback.
    $CONST_FILE = 'docs/adlc/memory/constitution.md'
    if (-not (Test-Path -LiteralPath $CONST_FILE)) {
        $CONST_FILE = '.adlc/memory/constitution.md'
    }
    if (Test-Path -LiteralPath $CONST_FILE -PathType Leaf) {
        $constContent = (Get-Content -Raw -LiteralPath $CONST_FILE)
        if ($constContent -cmatch '\[PRINCIPLE_[0-9]+_NAME\]|\[PROJECT_NAME\]') {
            warn "Constitution file contains template placeholders - populate or remove alignment claims"
        } else {
            pass "Constitution file appears to be populated"
        }
    } else {
        warn "Constitution file not found at $CONST_FILE"
    }
} else {
    warn "No constitution alignment section found (recommended but not required)"
}

# ============================================
# SUMMARY
# ============================================
[Console]::Out.WriteLine("")
[Console]::Out.WriteLine("================================================")
[Console]::Out.WriteLine(('{0}Validation Summary{1}' -f $BLUE, $NC))
[Console]::Out.WriteLine("================================================")

if ($ERRORS -eq 0 -and $WARNINGS -eq 0) {
    [Console]::Out.WriteLine(('{0}✓ All checks passed! PRD is compliant with v1.5.6{1}' -f $GREEN, $NC))
    [Console]::Out.WriteLine("")
    [Console]::Out.WriteLine("You may proceed to mark sections as 'completed'")
    exit 0
} elseif ($ERRORS -eq 0) {
    [Console]::Out.WriteLine(('{0}⚠ {1} warning(s) found{2}' -f $YELLOW, $WARNINGS, $NC))
    [Console]::Out.WriteLine("   PRD is usable but has issues that should be addressed")
    [Console]::Out.WriteLine("")

    if ($STRICT_MODE) {
        [Console]::Out.WriteLine(('{0}Exiting with error (strict mode){1}' -f $RED, $NC))
        [Console]::Out.WriteLine("   Fix all warnings before marking 'completed'")
        exit 1
    } else {
        [Console]::Out.WriteLine("   Run with --strict to enforce no warnings")
        exit 2
    }
} else {
    [Console]::Out.WriteLine(('{0}✗ {1} error(s) and {2} warning(s) found{3}' -f $RED, $ERRORS, $WARNINGS, $NC))
    [Console]::Out.WriteLine("")
    [Console]::Out.WriteLine("PRD is NON-COMPLIANT with v1.5.6 standards")
    [Console]::Out.WriteLine("Fix all errors before proceeding")
    exit 1
}
