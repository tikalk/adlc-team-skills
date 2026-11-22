# trim-evidence.ps1 — trim dead zones from a verify-lane recording.
# Bash twin: ../bash/trim-evidence.sh.
#
# Usage:
#   trim-evidence.ps1 -In <recording.mp4|webm> -Out <trimmed.mp4> `
#     [-Start <H:MM:SS|seconds>] [-End <H:MM:SS|seconds>]
#
# Trims leading/trailing dead zones via FFmpeg re-encode. The published
# recording must stay <=60s with per-criterion @M:SS timestamps (Task 1
# artifact contract). Without -Start/-End this only reports duration.
#
# Exit codes:
#   0  trimmed (or duration reported)
#   1  ffmpeg/ffprobe failed
#   2  usage error or missing input
param(
  [string]$In,
  [string]$Out,
  [string]$Start = "",
  [string]$End = ""
)

function Fail([string]$msg) { Write-Error "trim-evidence: $msg"; exit 2 }

if (-not $In) { Fail "-- -In is required" }
if (-not (Test-Path $In)) { Fail "input not found: $In" }
if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) { Fail "ffprobe not on PATH" }
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { Fail "ffmpeg not on PATH" }

$dur = & ffprobe -v error -show_entries format=duration -of csv=p=0 $In
if ($LASTEXITCODE -ne 0) { Write-Error "trim-evidence: ffprobe failed on $In"; exit 1 }
$durInt = [int]([double]$dur)
Write-Output "trim-evidence: input duration ${durInt}s"

if ((-not $Start) -and (-not $End)) {
  if ($durInt -gt 60) {
    Write-Warning "trim-evidence: ${durInt}s exceeds the 60s evidence target — pass -Start/-End to trim"
  }
  exit 0
}

if (-not $Out) { Fail "-Out is required when trimming" }
$ffArgs = @('-y')
if ($Start) { $ffArgs += @('-ss', $Start) }
$ffArgs += @('-i', $In)
if ($End) { $ffArgs += @('-to', $End) }
$ffArgs += @('-c:v', 'libvpx-vp9', '-c:a', 'libopus', $Out)
& ffmpeg -v error @ffArgs
if ($LASTEXITCODE -ne 0) { Write-Error "trim-evidence: ffmpeg failed"; exit 1 }

$newDur = & ffprobe -v error -show_entries format=duration -of csv=p=0 $Out
if ($LASTEXITCODE -ne 0) { Write-Error "trim-evidence: ffprobe failed on $Out"; exit 1 }
$newInt = [int]([double]$newDur)
Write-Output "trim-evidence: trimmed duration ${newInt}s -> $Out"
if ($newInt -gt 60) {
  Write-Warning "trim-evidence: trimmed output still exceeds the 60s target"
}
