# Context analysis helper for LevelUp extension
# Scans codebase for patterns that could become team-ai-directives contributions

param(
    [switch]$Json,
    [string]$Focus = "",
    [string]$Heuristic = "surprising",
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: analyze-context.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Json              Output results in JSON format"
    Write-Host "  -Focus TYPE        Focus on specific context type (rules|personas|examples|constitution|skills)"
    Write-Host "  -Heuristic TYPE    Discovery heuristic (surprising|all|minimal)"
    Write-Host "  -Help              Show this help message"
    exit 0
}

# Get script directory for common.ps1 sourcing
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find project root by walking up from script location
function Get-ProjectRoot {
    param([string]$StartPath)
    $dir = $StartPath
    while ($dir -ne "") {
        if ((Test-Path "$dir\.specify") -or (Test-Path "$dir\.git")) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    return $StartPath
}

$projectRoot = Get-ProjectRoot $scriptDir

# Load common functions - use absolute path from project root
$commonPath = "$projectRoot\.specify\scripts\powershell\common.ps1"
if (Test-Path $commonPath) {
    . $commonPath
} elseif (Test-Path "$scriptDir\common.ps1") {
    . "$scriptDir\common.ps1"
}

# Get repository root using common.ps1 function (searches upward for .specify first)
$repoRoot = Get-RepoRoot

# Detect technology stack
function Detect-Technologies {
    $techs = @()
    
    # Python
    if ((Test-Path (Join-Path $repoRoot "requirements.txt")) -or 
        (Test-Path (Join-Path $repoRoot "pyproject.toml")) -or 
        (Test-Path (Join-Path $repoRoot "setup.py"))) {
        $techs += "python"
    }
    
    # Node.js/JavaScript
    if (Test-Path (Join-Path $repoRoot "package.json")) {
        $techs += "nodejs"
    }
    
    # TypeScript
    if (Test-Path (Join-Path $repoRoot "tsconfig.json")) {
        $techs += "typescript"
    }
    
    # Go
    if (Test-Path (Join-Path $repoRoot "go.mod")) {
        $techs += "go"
    }
    
    # Java
    if ((Test-Path (Join-Path $repoRoot "pom.xml")) -or 
        (Test-Path (Join-Path $repoRoot "build.gradle"))) {
        $techs += "java"
    }
    
    # Rust
    if (Test-Path (Join-Path $repoRoot "Cargo.toml")) {
        $techs += "rust"
    }
    
    # Docker
    if ((Test-Path (Join-Path $repoRoot "Dockerfile")) -or 
        (Test-Path (Join-Path $repoRoot "docker-compose.yml"))) {
        $techs += "docker"
    }
    
    # Kubernetes
    if ((Test-Path (Join-Path $repoRoot "k8s")) -or 
        (Test-Path (Join-Path $repoRoot "kubernetes")) -or 
        (Test-Path (Join-Path $repoRoot "charts"))) {
        $techs += "kubernetes"
    }
    
    # Terraform
    if (Test-Path (Join-Path $repoRoot "terraform")) {
        $techs += "terraform"
    }
    
    # GitHub Actions
    if (Test-Path (Join-Path $repoRoot ".github/workflows")) {
        $techs += "github-actions"
    }
    
    return $techs
}

# Count files matching pattern
function Count-Files {
    param([string]$Pattern)
    return (Get-ChildItem -Path $repoRoot -Filter $Pattern -Recurse -ErrorAction SilentlyContinue).Count
}

# Main analysis
$technologies = Detect-Technologies
$pythonPatterns = @()
$jsPatterns = @()
$infraPatterns = @()

# File counts
$pythonFiles = Count-Files "*.py"
$jsFiles = Count-Files "*.js"
$tsFiles = Count-Files "*.ts"
$testFiles = (Get-ChildItem -Path $repoRoot -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match "test|spec" }).Count

# Output results
if ($Json) {
    $output = @{
        repo_root = $repoRoot
        technologies = $technologies -join ","
        heuristic = $Heuristic
        focus = $Focus
        file_counts = @{
            python = $pythonFiles
            javascript = $jsFiles
            typescript = $tsFiles
            tests = $testFiles
        }
        patterns = @{
            python = $pythonPatterns -join ","
            javascript = $jsPatterns -join ","
            infrastructure = $infraPatterns -join ","
        }
    }
    $output | ConvertTo-Json -Compress
} else {
    Write-Host "=== LevelUp Context Analysis ==="
    Write-Host ""
    Write-Host "Repository: $repoRoot"
    Write-Host "Heuristic: $Heuristic"
    if ($Focus) {
        Write-Host "Focus: $Focus"
    }
    Write-Host ""
    Write-Host "=== Detected Technologies ==="
    foreach ($tech in $technologies) {
        Write-Host "  - $tech"
    }
    Write-Host ""
    Write-Host "=== File Counts ==="
    Write-Host "  Python files: $pythonFiles"
    Write-Host "  JavaScript files: $jsFiles"
    Write-Host "  TypeScript files: $tsFiles"
    Write-Host "  Test files: $testFiles"
    Write-Host ""
    Write-Host "=== Potential CDRs ==="
    Write-Host "  Run /levelup.init to generate CDRs from these patterns"
}
