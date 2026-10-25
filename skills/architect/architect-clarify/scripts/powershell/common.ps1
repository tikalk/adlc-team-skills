# common.ps1 — minimal common helpers for adlc-skills architect-* skills
# (PowerShell twin of bash/common.sh). Bundled with the skill so it works
# standalone, outside the Spec Kit extension system. One behavior, two
# platform scripts; keep in lockstep.

$script:CommonPsDir = $PSScriptRoot
$pathsPs = Join-Path $CommonPsDir "../../../../team/workspace/scripts/powershell/paths.ps1"
if (-not (Test-Path $pathsPs)) {
    $pathsPs = Join-Path $CommonPsDir "../../../workspace/scripts/powershell/paths.ps1"
}
if (Test-Path $pathsPs) {
    . $pathsPs
}

# Locate the project root by walking up from CWD until we find .adlc or .git.
function Get-ProjectRoot {
    $dir = (Get-Location).Path
    while ($true) {
        if ((Test-Path (Join-Path $dir ".adlc")) -or (Test-Path (Join-Path $dir ".git"))) {
            return $dir
        }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    # Fallback: current working directory.
    return (Get-Location).Path
}

# Seed bundled templates into the project's .adlc/templates/ directory.
# Only copies files when the destination does not exist, so user
# customizations are preserved.
function Seed-Templates {
    param($RepoRoot)
    if (-not $RepoRoot) { $RepoRoot = Get-ProjectRoot }
    $srcDir = Join-Path $PSScriptRoot "../../templates"
    if (-not (Test-Path $srcDir)) { return }

    $adlcDir = if ($env:ADLC_DIR) { $env:ADLC_DIR } else { ".adlc" }
    $destDir = Join-Path $RepoRoot "$adlcDir/templates"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null

    foreach ($f in Get-ChildItem -LiteralPath $srcDir) {
        $dest = Join-Path $destDir $f.Name
        if ($f.PSIsContainer) {
            if (-not (Test-Path $dest)) {
                Copy-Item -Recurse -LiteralPath $f.FullName -Destination $dest
            }
        } else {
            if (-not (Test-Path $dest)) {
                Copy-Item -LiteralPath $f.FullName -Destination $dest
            }
        }
    }
}

# Emulates the get_feature_paths function from the Spec Kit common.sh.
# The architect setup script evals this output to obtain REPO_ROOT.
function Get-FeaturePaths {
    $repoRoot = Get-ProjectRoot
    Seed-Templates -RepoRoot $repoRoot
    return "REPO_ROOT=`"$repoRoot`""
}

# Get architecture diagram format (mermaid or ascii).
# Override via ARCHITECTURE_DIAGRAM_FORMAT env var; defaults to "mermaid".
# Invalid values fall back to "mermaid".
function Get-ArchitectureDiagramFormat {
    $format = if ($env:ARCHITECTURE_DIAGRAM_FORMAT) { $env:ARCHITECTURE_DIAGRAM_FORMAT } else { "mermaid" }
    if ($format -eq "mermaid" -or $format -eq "ascii") { return $format }
    return "mermaid"
}

# Validate Mermaid diagram syntax (lightweight regex validation).
# Returns $true if valid, $false if invalid.
# Args: $MermaidCode - Mermaid code string
function Test-MermaidSyntax {
    param([string]$MermaidCode)

    if ([string]::IsNullOrWhiteSpace($MermaidCode)) { return $false }

    if ($MermaidCode -notmatch '(?m)^(graph|flowchart|sequenceDiagram|classDiagram|stateDiagram|erDiagram|gantt|pie|journey|gitGraph|mindmap|timeline)') {
        return $false
    }

    $openBrackets = ([regex]::Matches($MermaidCode, '\[')).Count
    $closeBrackets = ([regex]::Matches($MermaidCode, '\]')).Count
    $openParens = ([regex]::Matches($MermaidCode, '\(')).Count
    $closeParens = ([regex]::Matches($MermaidCode, '\)')).Count

    if ($openBrackets -ne $closeBrackets -or $openParens -ne $closeParens) {
        return $false
    }

    return $true
}
