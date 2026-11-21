#!/usr/bin/env bash
# trim-evidence.sh — trim dead zones from a verify-lane recording.
# PowerShell twin: ../powershell/trim-evidence.ps1.
#
# Usage:
#   trim-evidence.sh --in <recording.mp4|webm> --out <trimmed.mp4> \
#     [--start <H:MM:SS|seconds>] [--end <H:MM:SS|seconds>]
#
# Trims leading/trailing dead zones via FFmpeg re-encode. The published
# recording must stay <=60s with per-criterion @M:SS timestamps (Task 1
# artifact contract). Without --start/--end this only reports duration.
#
# Exit codes:
#   0  trimmed (or duration reported)
#   1  ffmpeg/ffprobe failed
#   2  usage error or missing input
set -uo pipefail

die() { echo "trim-evidence: $*" >&2; exit 2; }

IN="" OUT="" START="" END=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --in)    [ -n "${2:-}" ] || die "--in requires a value"; IN="$2"; shift 2 ;;
    --out)   [ -n "${2:-}" ] || die "--out requires a value"; OUT="$2"; shift 2 ;;
    --start) [ -n "${2:-}" ] || die "--start requires a value"; START="$2"; shift 2 ;;
    --end)   [ -n "${2:-}" ] || die "--end requires a value"; END="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)       die "unknown argument '$1'" ;;
  esac
done

[ -n "$IN" ] || die "--in is required"
[ -f "$IN" ] || die "input not found: $IN"
command -v ffprobe >/dev/null 2>&1 || die "ffprobe not on PATH"
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not on PATH"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN") \
  || { echo "trim-evidence: ffprobe failed on $IN" >&2; exit 1; }
DUR_INT=${DUR%.*}
echo "trim-evidence: input duration ${DUR_INT}s"

if [ -z "$START" ] && [ -z "$END" ]; then
  if [ "$DUR_INT" -gt 60 ]; then
    echo "trim-evidence: WARNING: ${DUR_INT}s exceeds the 60s evidence target — pass --start/--end to trim" >&2
  fi
  exit 0
fi

[ -n "$OUT" ] || die "--out is required when trimming"
ARGS=(-y)
[ -n "$START" ] && ARGS+=(-ss "$START")
ARGS+=(-i "$IN")
[ -n "$END" ] && ARGS+=(-to "$END")
ffmpeg -v error "${ARGS[@]}" -c:v libvpx-vp9 -c:a libopus "$OUT" \
  || { echo "trim-evidence: ffmpeg failed" >&2; exit 1; }

NEW_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT") \
  || { echo "trim-evidence: ffprobe failed on $OUT" >&2; exit 1; }
echo "trim-evidence: trimmed duration ${NEW_DUR%.*}s -> $OUT"
if [ "${NEW_DUR%.*}" -gt 60 ]; then
  echo "trim-evidence: WARNING: trimmed output still exceeds the 60s target" >&2
fi
