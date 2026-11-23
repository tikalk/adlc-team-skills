# list-anchors.ps1 — parse a demo runbook and emit its ### demo/* anchors in file order.
#
# Usage: list-anchors.ps1 -Runbook <path> [-From <anchor>] [-Json]
# Twin of scripts/bash/list-anchors.sh (one behavior, two platform scripts).
# Exit codes: 0 ok; 1 runbook unreadable; 2 no anchors/usage; 3 unknown --from anchor.
# Read-only by construction; never writes.
param(
  [string]$Runbook = "",
  [string]$From = "",
  [switch]$Json
)

function Fail([string]$msg, [int]$code) { Write-Error "list-anchors: $msg"; exit $code }

if (-not $Runbook) { Write-Error "usage: list-anchors.ps1 -Runbook <path> [-From <anchor>] [-Json]"; exit 2 }
if (-not (Test-Path -LiteralPath $Runbook -PathType Leaf)) { Fail "runbook unreadable: $Runbook" 1 }

$lines = Get-Content -LiteralPath $Runbook
$hits = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^### (demo/[A-Za-z0-9_/-]+)\s*$') { $hits += [pscustomobject]@{ Anchor = $Matches[1]; Line = $i + 1 } }
}
if ($hits.Count -eq 0) { Fail "no demo/* anchors in $Runbook" 2 }

if ($From) {
  $idx = -1
  for ($i = 0; $i -lt $hits.Count; $i++) { if ($hits[$i].Anchor -ceq $From) { $idx = $i; break } }
  if ($idx -lt 0) { Fail "unknown -From anchor: $From" 3 }
  $hits = @($hits[$idx..($hits.Count - 1)])
}

if ($Json) {
  $parts = $hits | ForEach-Object { '{"anchor":"' + $_.Anchor + '","line":' + $_.Line + '}' }
  '[' + ($parts -join ',') + ']'
} else {
  $hits | ForEach-Object { $_.Anchor }
}
