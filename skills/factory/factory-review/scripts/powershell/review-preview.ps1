# factory-review pre-PR verdict preview — PowerShell twin (workspace issue 45, review-contract intake + pre-PR verdict preview records).
#
# Renders the would-be verdict against the working tree. ADVISORY ONLY:
#   * labeled "draft" — never a verdict
#   * no head=<sha> marker, no outcome=, no important=
#   * no head binding — not checked by check-verdict-head.sh
#   * no tracker writes — read-only passes reused, output to stdout only
#   * never posted to the tracker; no sensor may read this output
#
# Usage: review-preview.ps1 [working-tree]   # default: current directory
#
# Exits 0 on success. Missing provenance is reported (requested), but the
# script still exits 0 — it never blocks on provenance, it only records that
# provenance is absent so the author can supply it before opening a PR.

[CmdletBinding()]
param(
    [string]$Tree = "."
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $Tree -PathType Container)) {
    Write-Error "review-preview: cannot access $Tree"
    exit 1
}

Push-Location -Path $Tree | Out-Null

try {
    $head = git rev-parse --verify HEAD 2>$null
    if ($head) {
        $changed = git diff --name-only HEAD 2>$null
    } else {
        $changed = git ls-files 2>$null
    }
} finally {
    Pop-Location | Out-Null
}

$provenancePresent = 0
if (Test-Path -Path "PROVENANCE.md" -PathType Leaf) {
    $len = (Get-Item "PROVENANCE.md").Length
    if ($len -gt 0) { $provenancePresent = 1 }
}
if ($provenancePresent -eq 0 -and $changed) {
    foreach ($line in $changed) {
        if ($line -match "provenance|files came from where") {
            $provenancePresent = 1
            break
        }
    }
}

@"
factory-review pre-PR verdict preview — DRAFT (advisory, not a verdict)
=====================================================================

This is a draft preview only. It is NOT a factory-review verdict: it carries
no head-SHA marker, no outcome or importance fields, and it is never posted to
the tracker. No sensor reads this output.

Working tree: $Tree

Changed files:
@"
 | Out-String

if ($changed) {
    $changed | ForEach-Object { Write-Output "  $_" }
} else {
    Write-Output "  (none)"
}

@"
Evidence intake (read-only — passes reused, not executed in preview):
  bugs            structural check only
  security        structural check only
  spec-compliance structural check only
  test-integrity  structural check only
  ci-integrity    structural check only
  quality         structural check only

Provenance:
"@ | Out-String

if ($provenancePresent -eq 1) {
    @"
  provenance: present — provenance file or provenance reference found in
  changed files. (Formal REVIEW.md policy fields + owner values are captured
   through the owner sign-off path; this preview reports presence only.)
"@ | Out-String
} else {
    @"
  missing — request "which files came from where" plus AI-contribution-policy
  compliance before opening the PR. No verdict is produced until provenance
  is provided (provenance joins evidence intake).
"@ | Out-String
}

@"
Tracker writes: none. This preview performs no tracker writes and modifies
nothing in the working tree.

This preview is advisory. The head-bound verdict (a head SHA marker plus its
outcome and importance count) is produced only by factory-review on a
reviewed PR head and is checked by
check-verdict-head.sh.
"@ | Out-String

exit 0
