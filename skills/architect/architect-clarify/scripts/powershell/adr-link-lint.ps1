# adr-link-lint.ps1 — ADR Related-ADRs link checker — flag dangling local links, never write.
# PowerShell twin of bash/adr-link-lint.sh; one behavior, two platform scripts; keep in lockstep.
#
# Scans ADR files for markdown links of the form ](ADR-*.md) and reports
# targets that do not resolve on disk next to the linking file. Catches the
# two failure shapes seen on adlc-workspace MR !158 (ChDR-007):
#   1. non-resolving relative prefix  [x](../memory/adr/ADR-000.md)
#      (resolves to memory/memory/adr/ from docs/adlc/memory/adr/)
#   2. short filename with no target  [x](ADR-000.md)
#      (real file carries a suffixed stem)
#
# Read-only by contract: this script never writes, moves or reformats an
# artifact. Remediation stays with implement/human (fix the link, keep
# sibling form per adr-template.md).
#
# Usage:
#   adr-link-lint.ps1 [--tsv] <file> [file...]
#
# Output:
#   default — one readable block per finding (location, target, shape,
#             suggested patch)
#   --tsv — file<TAB>line<TAB>target<TAB>shape for CI parsing
#
# Exit: 0 = all links resolve (or no links found), 1 = dangling links found.

$ErrorActionPreference = 'Stop'

$TSV = $false
$FILES = [System.Collections.Generic.List[string]]::new()
foreach ($arg in $args) {
    if ([string]$arg -eq '--tsv') { $TSV = $true }
    else { $FILES.Add([string]$arg) }
}

$failures = 0
foreach ($file in $FILES) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $dir = (Get-Item -LiteralPath $file).Directory.FullName
    $lineno = 0
    foreach ($rawLine in (Get-Content -LiteralPath $file)) {
        $lineno++
        $line = [string]$rawLine
        $rest = $line
        while ($rest -like '*](*)*') {
            $after = $rest.Substring($rest.IndexOf('](') + 2)
            $closeIdx = $after.IndexOf(')')
            if ($closeIdx -lt 0) { break }
            $target = $after.Substring(0, $closeIdx)
            $rest = $after.Substring($closeIdx + 1)
            if ($target -like 'http*' -or $target -like 'mailto:*' -or $target -like '#*' -or $target -eq '') { continue }
            # strip any #anchor for the existence check
            $check = ($target -split '#', 2)[0]
            if ($check -notlike '*ADR-*.md') { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $dir $check))) {
                $failures++
                $shape = 'short-or-moved'
                if ($check -like '../*' -or $check -like './*' -or $check -like '/*') { $shape = 'non-resolving-prefix' }
                # Suggest a suffixed sibling only on an exactly-one match; on
                # zero full-stem matches retry with the numeric prefix
                # (ADR-<digits>*) for wrong-suffix targets. Zero or 2+ -> fallback.
                $stem = Split-Path -Leaf $check
                $stem = $stem -replace '\.md$', ''
                $suggestion = ''
                $matches = @(Get-ChildItem -LiteralPath $dir -Filter "$stem*.md" -File -ErrorAction SilentlyContinue)
                if ($matches.Count -eq 0 -and $stem -match '^(ADR-[0-9]+)') {
                    $prefix = $Matches[1]
                    $matches = @(Get-ChildItem -LiteralPath $dir -Filter "$prefix*.md" -File -ErrorAction SilentlyContinue)
                }
                if ($matches.Count -eq 1) {
                    $suggestion = $matches[0].Name
                }
                if ($TSV) {
                    [Console]::Out.WriteLine(($file, $lineno, $target, $shape) -join "`t")
                } else {
                    [Console]::Out.WriteLine("DANGLING-LINK ${file}:${lineno}")
                    [Console]::Out.WriteLine("  target: $target ($shape)")
                    if ($suggestion -ne '') {
                        [Console]::Out.WriteLine("  suggest: ($suggestion)")
                    } else {
                        [Console]::Out.WriteLine('  suggest: sibling-form (ADR-<stem>.md) must exist next to the linking file')
                    }
                }
            }
        }
    }
}

if ($failures -gt 0) {
    if (-not $TSV) { [Console]::Out.WriteLine("adr-link-lint: $failures dangling link(s)") }
    exit 1
}
if (-not $TSV) { [Console]::Out.WriteLine('adr-link-lint: all Related-ADRs targets resolve') }
exit 0
