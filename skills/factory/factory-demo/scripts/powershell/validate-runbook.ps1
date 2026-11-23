# validate-runbook.ps1 — fail-closed validation of a demo runbook's anchor contract.
#
# Usage: validate-runbook.ps1 -Runbook <path>
# Twin of scripts/bash/validate-runbook.sh (one behavior, two platform scripts).
# Checks: readable; >=1 ### demo/* anchor; unique anchor names; every section
# carries a **Say:** line and a **Do...** line. Read-only; never writes.
param(
  [string]$Runbook = ""
)

function Invalid([string]$msg) { Write-Error "invalid: $msg"; exit 1 }

if (-not $Runbook) { Write-Error "usage: validate-runbook.ps1 -Runbook <path>"; exit 2 }
if (-not (Test-Path -LiteralPath $Runbook -PathType Leaf)) { Invalid "runbook unreadable: $Runbook" }

$lines = Get-Content -LiteralPath $Runbook
$hits = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^### (demo/[A-Za-z0-9_/-]+)\s*$') { $hits += [pscustomobject]@{ Anchor = $Matches[1]; Line = $i + 1 } }
}
if ($hits.Count -eq 0) { Invalid "no demo/* anchors in $Runbook" }

$seen = @{}
foreach ($h in $hits) {
  if ($seen.ContainsKey($h.Anchor)) { Invalid "$($h.Anchor): duplicated anchor" }
  $seen[$h.Anchor] = $true
}

for ($i = 0; $i -lt $hits.Count; $i++) {
  $start = $hits[$i].Line
  $end = if ($i + 1 -lt $hits.Count) { $hits[$i + 1].Line - 1 } else { $lines.Count }
  $section = $lines[($start - 1)..($end - 1)] -join "`n"
  if ($section -notmatch '(?m)^\*\*Say:\*\*') { Invalid "$($hits[$i].Anchor): section missing Say line" }
  if ($section -notmatch '(?m)^\*\*Do') { Invalid "$($hits[$i].Anchor): section missing Do line" }
}

$names = ($hits | ForEach-Object { $_.Anchor }) -join ' '
"valid: $($hits.Count) anchors ($names)"
