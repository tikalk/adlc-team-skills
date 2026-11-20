# chdr-lib.ps1 — Shared ChDR lifecycle library for adlc-skills change-* skills (PowerShell twin of chdr-lib.sh)
#
# Canonical home of the change family's shared helpers, modeled on
# product-clarify's pdr-lib.ps1: change-clarify dot-sources this file
# directly; the sibling change-* setup scripts vendor the helpers they use
# (scope rule: skills never source each other's scripts — the source tree is
# skills/<group>/<skill>/ while the installed mirror is flat
# .agents/skills/<skill>/, so no single relative path resolves in both).
#
# Usage:
#   . .\chdr-lib.ps1                         # load functions
#   Resolve-MemoryRoot                       # store root for the CWD (ADR-514)
#   Ensure-MemoryStore -Root $r -Family chdr # loud create on promotion write

$ErrorActionPreference = "Stop"

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
$ADLC_DIR = if ($env:ADLC_DIR) { $env:ADLC_DIR } else { ".adlc" }
$DOCS_ADLC_DIR = if ($env:DOCS_ADLC_DIR) { $env:DOCS_ADLC_DIR } else { "docs/adlc" }
$DOCS_ADLC_MEMORY = if ($env:DOCS_ADLC_MEMORY) { $env:DOCS_ADLC_MEMORY } else { "docs/adlc/memory" }
$DOCS_ADLC_PRODUCT = if ($env:DOCS_ADLC_PRODUCT) { $env:DOCS_ADLC_PRODUCT } else { "docs/adlc/product" }
$DOCS_ADLC_ARCHITECT = if ($env:DOCS_ADLC_ARCHITECT) { $env:DOCS_ADLC_ARCHITECT } else { "docs/adlc/architect" }
$ADLC_DRAFTS = if ($env:ADLC_DRAFTS) { $env:ADLC_DRAFTS } else { ".adlc/drafts" }

# ============================================================================
# Path resolution
# ============================================================================

function Resolve-ProjectRoot {
    $dir = (Get-Location).Path
    while ($dir -ne [System.IO.Path]::GetPathRoot($dir)) {
        if (Test-Path (Join-Path $dir ".adlc")) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    $toplevel = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $toplevel) { return $toplevel }
    return (Get-Location).Path
}

# ============================================================================
# Decision-record store resolution (ADR-514)
# ============================================================================

# Test-MemoryRootMarker DIR — does DIR carry a decision-record store marker?
# A marker is a decision-record family subdir (adr/, pdr/, chdr/) or a family
# index file (adr.md/pdr.md/chdr.md) under docs/adlc/memory/ or the legacy
# .adlc/memory/. A bare .adlc/ is NOT a marker; a memory dir holding only
# non-decision content (evals/, constitution.md) is NOT a marker.
function Test-MemoryRootMarker {
    param([string]$Root)
    foreach ($mem in @("docs/adlc/memory", ".adlc/memory")) {
        if (-not (Test-Path (Join-Path $Root $mem))) { continue }
        foreach ($fam in @("adr", "pdr", "chdr")) {
            if ((Test-Path (Join-Path $Root "$mem/$fam")) -or
                (Test-Path (Join-Path $Root "$mem/$fam.md")) -or
                (Test-Path (Join-Path $Root "$mem/$fam/$fam.md"))) {
                return $true
            }
        }
    }
    return $false
}

# Test-WorkspaceRootAbove DIR — is any strict ancestor of DIR a workspace root
# (a directory holding .gitmodules or .adlc/workspace.yml)? Lets a submodule
# child climb past its own git toplevel toward the workspace store.
function Test-WorkspaceRootAbove {
    param([string]$Dir)
    $up = Split-Path $Dir -Parent
    while ($up -and $up -ne [System.IO.Path]::GetPathRoot($up)) {
        if ((Test-Path (Join-Path $up ".gitmodules")) -or
            (Test-Path (Join-Path $up ".adlc/workspace.yml"))) {
            return $true
        }
        $up = Split-Path $up -Parent
    }
    return $false
}

# Resolve-MemoryRoot — the decision-record store root for the current working
# directory. ONE bounded walk-up from the CWD:
#   1. the nearest ancestor with a decision-record family marker wins;
#   2. else the nearest workspace root (.gitmodules or .adlc/workspace.yml)
#      — the workspace-centralized default;
#   3. else the git toplevel (standalone repo).
# The walk never climbs past the git toplevel unless a workspace root sits
# above it (a submodule child inside a workspace). Side-effect-free: reads
# never create anything.
function Resolve-MemoryRoot {
    $dir = (Get-Location).Path
    $toplevel = (git -C $dir rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0) { $toplevel = $null }
    while ($dir -and $dir -ne [System.IO.Path]::GetPathRoot($dir)) {
        if (Test-MemoryRootMarker $dir) { return $dir }
        if ((Test-Path (Join-Path $dir ".gitmodules")) -or
            (Test-Path (Join-Path $dir ".adlc/workspace.yml"))) {
            return $dir
        }
        if ($toplevel -and ($dir -eq $toplevel) -and -not (Test-WorkspaceRootAbove $dir)) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    if ($toplevel) { return $toplevel }
    return (Get-Location).Path
}

# Ensure-MemoryStore ROOT FAMILY — write-path guard for record promotion.
# Creates ROOT/docs/adlc/memory/FAMILY when missing and says so LOUDLY: the
# created store is the opt-in marker and travels with clones. Silent when the
# store already exists; reads never call this.
function Ensure-MemoryStore {
    param([string]$Root, [string]$Family)
    $store = Join-Path $Root "$DOCS_ADLC_MEMORY/$Family"
    if (-not (Test-Path $store)) {
        New-Item -ItemType Directory -Path $store -Force | Out-Null
        $name = Split-Path $Root -Leaf
        [Console]::Error.WriteLine("No decision-record store found — initialized $store; commit it to opt $name into repo-scoped memory.")
    }
}
