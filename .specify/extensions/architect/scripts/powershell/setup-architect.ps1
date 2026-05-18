# Setup architecture description with Rozanski & Woods methodology
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet('init', 'map', 'update', 'review', 'specify', 'clarify', 'implement', 'analyze', 'validate', 'plan-dag', 'execute-dag', 'summarize', '')]
    [string]$Action = '',
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Context,
    [string]$Views = 'core',
    [string]$AdrHeuristic = 'surprising',
    [switch]$NoDecompose,
    [switch]$Json,
    [switch]$Help
)

$Decompose = -not $NoDecompose

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output "Usage: ./setup-architect.ps1 [action] [context] [-Views VIEWS] [-AdrHeuristic HEURISTIC] [-Json] [-Help]"
    Write-Output ""
    Write-Output "Actions:"
    Write-Output "  specify    Interactive PRD exploration to create system ADRs (greenfield)"
    Write-Output "  clarify    Refine and resolve ambiguities in existing ADRs"
    Write-Output "  init       Reverse-engineer architecture from existing codebase (brownfield)"
    Write-Output "  implement  Generate full Architecture Description (AD.md) from ADRs"
    Write-Output "  analyze    Validate architecture for consistency and quality issues"
    Write-Output "  validate   Validate plan alignment with architecture (READ-ONLY)"
    Write-Output "  map        (alias for init) Reverse-engineer architecture from existing codebase"
    Write-Output "  update     Update architecture based on code/spec changes"
    Write-Output "  review     Validate architecture against constitution"
    Write-Output ""
    Write-Output "DAG Workflow Actions (used internally by implement):"
    Write-Output "  plan-dag   Phase 1: Generate DAG execution plan for user approval"
    Write-Output "  execute-dag Phase 2: Execute DAG to generate views per sub-system"
    Write-Output "  summarize  Phase 3: Aggregate views into unified AD.md"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -Views VIEWS         Architecture views to generate: core (default), all, or comma-separated"
    Write-Output "  -AdrHeuristic H      ADR generation heuristic: surprising (default), all, minimal"
    Write-Output "  -NoDecompose         Disable automatic sub-system decomposition (default: auto-detect)"
    Write-Output "  -Json                Output results in JSON format"
    Write-Output "  -Help                Show this help message"
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  ./setup-architect.ps1 specify `"B2B SaaS for supply chain management`""
    Write-Output "  ./setup-architect.ps1 init -Views all `"Django monolith with PostgreSQL`""
    Write-Output "  ./setup-architect.ps1 init -Views concurrency,operational `"Microservices architecture`""
    Write-Output "  ./setup-architect.ps1 clarify -AdrHeuristic all `"Document all decisions`""
    Write-Output "  ./setup-architect.ps1 implement `"Generate full AD.md from ADRs`""
    Write-Output ""
    Write-Output "Pro Tip: Add context/description after the action for better results."
    Write-Output "The AI will use your input to understand system scope and constraints."
    exit 0
}

# Get repository root
function Get-RepositoryRoot {
    # Try environment variable first
    if ($env:REPO_ROOT -and (Test-Path $env:REPO_ROOT)) {
        return $env:REPO_ROOT
    }

    # Fallback: search for repository markers
    $currentDir = Get-Location
    while ($currentDir -and (Test-Path $currentDir)) {
        if ((Test-Path "$currentDir\.git") -or (Test-Path "$currentDir\.specify")) {
            return $currentDir
        }
        $currentDir = Split-Path $currentDir -Parent
    }

    throw "Could not determine repository root"
}

# Detect tech stack from codebase
function Get-TechStack {
    Write-Host "Scanning codebase for technology stack..." -ForegroundColor Cyan
    
    $techStack = @()
    
    # Languages
    if (Test-Path "package.json") {
        $techStack += "**Languages**: JavaScript/TypeScript"
        $techStack += "**Package Manager**: npm/yarn"
    }
    
    if ((Test-Path "requirements.txt") -or (Test-Path "setup.py") -or (Test-Path "pyproject.toml")) {
        $techStack += "**Languages**: Python"
        if (Test-Path "pyproject.toml") {
            $techStack += "**Package Manager**: pip/poetry/uv"
        }
    }
    
    if (Test-Path "Cargo.toml") {
        $techStack += "**Languages**: Rust"
        $techStack += "**Package Manager**: Cargo"
    }
    
    if (Test-Path "go.mod") {
        $techStack += "**Languages**: Go"
        $techStack += "**Package Manager**: go modules"
    }
    
    if ((Test-Path "pom.xml") -or (Test-Path "build.gradle")) {
        $techStack += "**Languages**: Java"
        if (Test-Path "pom.xml") {
            $techStack += "**Build System**: Maven"
        } else {
            $techStack += "**Build System**: Gradle"
        }
    }
    
    if ((Get-ChildItem -Filter "*.csproj" -ErrorAction SilentlyContinue).Count -gt 0 -or 
        (Get-ChildItem -Filter "*.sln" -ErrorAction SilentlyContinue).Count -gt 0) {
        $techStack += "**Languages**: C#/.NET"
        $techStack += "**Build System**: dotnet"
    }
    
    # Frameworks
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" -Raw -ErrorAction SilentlyContinue
        if ($packageJson) {
            if ($packageJson -match "react") {
                $techStack += "**Frontend Framework**: React"
            }
            if ($packageJson -match "vue") {
                $techStack += "**Frontend Framework**: Vue"
            }
            if ($packageJson -match "angular") {
                $techStack += "**Frontend Framework**: Angular"
            }
            if ($packageJson -match "express") {
                $techStack += "**Backend Framework**: Express"
            }
            if ($packageJson -match "fastify") {
                $techStack += "**Backend Framework**: Fastify"
            }
        }
    }
    
    # Databases
    if ((Test-Path "docker-compose.yml") -or (Test-Path "docker-compose.yaml")) {
        $dockerCompose = Get-Content "docker-compose.*" -Raw -ErrorAction SilentlyContinue
        if ($dockerCompose) {
            if ($dockerCompose -match "postgres") {
                $techStack += "**Database**: PostgreSQL"
            }
            if ($dockerCompose -match "mysql") {
                $techStack += "**Database**: MySQL"
            }
            if ($dockerCompose -match "mongodb") {
                $techStack += "**Database**: MongoDB"
            }
            if ($dockerCompose -match "redis") {
                $techStack += "**Cache**: Redis"
            }
        }
    }
    
    # Infrastructure
    if (Test-Path "Dockerfile") {
        $techStack += "**Containerization**: Docker"
    }
    
    if ((Test-Path "kubernetes") -or (Test-Path "k8s")) {
        $techStack += "**Orchestration**: Kubernetes"
    }
    
    if ((Test-Path "terraform") -or (Get-ChildItem -Filter "*.tf" -ErrorAction SilentlyContinue).Count -gt 0) {
        $techStack += "**IaC**: Terraform"
    }
    
    if (Test-Path ".github/workflows") {
        $techStack += "**CI/CD**: GitHub Actions"
    }
    
    if (Test-Path ".gitlab-ci.yml") {
        $techStack += "**CI/CD**: GitLab CI"
    }
    
    if (Test-Path "Jenkinsfile") {
        $techStack += "**CI/CD**: Jenkins"
    }
    
    return $techStack -join "`n"
}

# Detect sub-systems from codebase structure
function Get-Subsystems {
    Write-Host "Detecting sub-systems from codebase structure..." -ForegroundColor Cyan
    
    $dirs = @()
    
    # 1. Top-level feature directories (src/, app/, services/)
    if (Test-Path "src") {
        Get-ChildItem -Path "src" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirname = $_.Name
            # Skip common non-sub-system directories
            if (@("utils", "common", "lib", "shared", "core") -notcontains $dirname) {
                $dirs += $dirname
            }
        }
    }
    
    if (Test-Path "services") {
        Get-ChildItem -Path "services" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirs += $_.Name
        }
    }
    
    if (Test-Path "modules") {
        Get-ChildItem -Path "modules" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirs += $_.Name
        }
    }
    
    if (Test-Path "apps") {
        Get-ChildItem -Path "apps" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dirs += $_.Name
        }
    }
    
    # 2. Check for docker-compose services (microservices indicator)
    $composeFile = $null
    if (Test-Path "docker-compose.yml") { $composeFile = "docker-compose.yml" }
    elseif (Test-Path "docker-compose.yaml") { $composeFile = "docker-compose.yaml" }
    
    if ($composeFile) {
        $composeContent = Get-Content $composeFile -Raw
        $services = [regex]::Matches($composeContent, '^\s*([a-zA-Z0-9_-]+):\s*$' | ForEach-Object { $_.Groups[1].Value } | Where-Object { @("version", "services", "networks", "volumes") -notcontains $_ })
        foreach ($svc in $services) {
            $found = $false
            foreach ($d in $dirs) {
                if ($d.ToLower() -like "*$($svc.ToLower())*" -or $svc.ToLower() -like "*$($d.ToLower())*") {
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $dirs += $svc
            }
        }
    }
    
    # 3. Check for Node.js workspaces (monorepo indicator)
    if (Test-Path "package.json") {
        $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($packageJson.workspaces) {
            $packageJson.workspaces | ForEach-Object {
                $dirname = Split-Path $_ -Leaf
                if ($dirname -ne "node_modules") {
                    $dirs += $dirname
                }
            }
        }
    }
    
    # 4. Check for Python namespace packages
    if (Test-Path "pyproject.toml") {
        Get-ChildItem -Path . -Recurse -Filter "__init__.py" -Depth 3 -ErrorAction SilentlyContinue | ForEach-Object {
            $dirname = Split-Path $_.DirectoryName -Leaf
            if ($dirname -ne "src" -and $dirname -ne ".") {
                $dirs += $dirname
            }
        } | Select-Object -Unique
    }
    
    # Remove duplicates
    $uniqueDirs = $dirs | Select-Object -Unique
    
    if ($uniqueDirs.Count -gt 0) {
        Write-Host "Detected potential sub-systems:" -ForegroundColor Cyan
        $count = 0
        foreach ($d in $uniqueDirs) {
            $count++
            Write-Host "  - $d" -ForegroundColor Gray
        }
        Write-Host "Total: $count sub-system(s)" -ForegroundColor Cyan
    } else {
        Write-Host "No distinct sub-systems detected from directory structure." -ForegroundColor Yellow
    }
    
    # Return as JSON if JSON mode
    if ($Json) {
        $subsystems = @()
        foreach ($d in $uniqueDirs) {
            $subsystems += @{
                id = $d
                name = $d
                detection_method = "directory"
                evidence = "directory: $d/"
            }
        }
        return $subsystems | ConvertTo-Json -Compress
    }
}

# Map directory structure
function Get-DirectoryStructure {
    Write-Host "Scanning directory structure..." -ForegroundColor Cyan
    
    $structure = @()
    
    if (Test-Path "src") {
        $structure += "**Source Code**: src/"
        if ((Test-Path "src/api") -or (Test-Path "src/routes")) {
            $structure += "  - API Layer: src/api/ or src/routes/"
        }
        if (Test-Path "src/services") {
            $structure += "  - Business Logic: src/services/"
        }
        if (Test-Path "src/models") {
            $structure += "  - Data Models: src/models/"
        }
        if (Test-Path "src/utils") {
            $structure += "  - Utilities: src/utils/"
        }
    }
    
    if ((Test-Path "tests") -or (Test-Path "test")) {
        $structure += "**Tests**: tests/ or test/"
    }
    
    if (Test-Path "docs") {
        $structure += "**Documentation**: docs/"
    }
    
    if (Test-Path "scripts") {
        $structure += "**Scripts**: scripts/"
    }
    
    if ((Test-Path "infra") -or (Test-Path "infrastructure")) {
        $structure += "**Infrastructure**: infra/ or infrastructure/"
    }
    
    return $structure -join "`n"
}

# Function to scan existing docs for deduplication
function Scan-ExistingDocs {
    param([string]$RepoRoot = (Get-RepositoryRoot))
    
    Write-Host "Scanning existing documentation for deduplication..." -ForegroundColor Cyan
    
    $findings = @()
    
    # Check for existing architecture docs
    if (Test-Path "$RepoRoot\AD.md") {
        $findings += "EXISTING_AD: $RepoRoot\AD.md"
    }
    
    if (Test-Path "$RepoRoot\docs\architecture.md") {
        $findings += "EXISTING_ARCHITECTURE: $RepoRoot\docs\architecture.md"
    }
    
    # Scan README for tech stack
    if (Test-Path "$RepoRoot\README.md") {
        $readme = Get-Content "$RepoRoot\README.md" -Raw
        if ($readme -match "Tech Stack|Technology|Built with") {
            $findings += "TECH_STACK_IN_README: $RepoRoot\README.md"
        }
        if ($readme -match "PostgreSQL|MySQL|MongoDB|Redis") {
            $findings += "DATABASE_IN_README: $RepoRoot\README.md"
        }
        if ($readme -match "React|Vue|Angular") {
            $findings += "FRONTEND_IN_README: $RepoRoot\README.md"
        }
    }
    
    # Scan AGENTS.md for context
    if (Test-Path "$RepoRoot\AGENTS.md") {
        $findings += "AGENTS_CONTEXT: $RepoRoot\AGENTS.md"
    }
    
    # Scan CONTRIBUTING.md for dev guidelines
    if (Test-Path "$RepoRoot\CONTRIBUTING.md") {
        $findings += "DEV_GUIDELINES: $RepoRoot\CONTRIBUTING.md"
    }
    
    return $findings -join "`n"
}

# Function to parse views parameter
function Parse-Views {
    param([string]$ViewsArg)
    
    switch ($ViewsArg.ToLower()) {
        "all" { return "context functional information concurrency development deployment operational" }
        "full" { return "context functional information concurrency development deployment operational" }
        "core" { return "context functional information development deployment" }
        "minimal" { return "context functional information development deployment" }
        "" { return "context functional information development deployment" }
        default {
            # Parse comma-separated: "concurrency,operational"
            $validViews = @()
            $allViews = @("context", "functional", "information", "concurrency", "development", "deployment", "operational")
            $requestedViews = $ViewsArg -split ","
            
            foreach ($view in $requestedViews) {
                $view = $view.Trim().ToLower()
                if ($allViews -contains $view) {
                    $validViews += $view
                }
            }
            
            # Always include core views
            $coreViews = @("context", "functional", "information", "development", "deployment")
            foreach ($coreView in $coreViews) {
                if ($validViews -notcontains $coreView) {
                    $validViews += $coreView
                }
            }
            
            return $validViews -join " "
        }
    }
}

# Generate and insert diagrams into architecture.md
function New-ArchitectureDiagrams {
    param(
        [string]$ArchitectureFile,
        [string]$SystemName = "System",
        [string]$ViewsList = ""
    )
    
    Write-Host "📊 Generating architecture diagrams..." -ForegroundColor Cyan
    
    # Get diagram format from config
    $diagramFormat = Get-ArchitectureDiagramFormat
    
    Write-Host "   Using diagram format: $diagramFormat"
    
    # Source diagram generators
    $scriptDir = Split-Path $PSCommandPath -Parent
    if ($diagramFormat -eq 'mermaid') {
        . "$scriptDir\Mermaid-Generator.ps1"
    } else {
        . "$scriptDir\ASCII-Generator.ps1"
    }
    
    # Determine which views to generate (use env var if ViewsList not provided)
    if (-not $ViewsList) {
        $ViewsList = $env:ARCHITECTURE_VIEWS
    }
    if (-not $ViewsList) {
        $ViewsList = "core"
    }
    
    # Parse views and convert to array
    $parsedViews = Parse-Views -ViewsArg $ViewsList
    $views = $parsedViews -split ' '
    
    Write-Host "   Generating views: $($views -join ', ')"
    
    # Generate each diagram
    foreach ($view in $views) {
        Write-Host "   Generating $view view diagram..."
        
        try {
            $diagramCode = if ($diagramFormat -eq 'mermaid') {
                New-MermaidDiagram -ViewType $view -SystemName $SystemName
                
                # Validate Mermaid syntax
                if (-not (Test-MermaidSyntax -MermaidCode $diagramCode)) {
                    Write-Host "   ⚠️  Mermaid validation failed for $view view, using ASCII fallback" -ForegroundColor Yellow
                    . "$scriptDir\ASCII-Generator.ps1"
                    New-AsciiDiagram -ViewType $view -SystemName $SystemName
                }
                else {
                    $diagramCode
                }
            }
            else {
                New-AsciiDiagram -ViewType $view -SystemName $SystemName
            }
        }
        catch {
            Write-Host "   ⚠️  Error generating $view diagram: $_" -ForegroundColor Yellow
        }
    }
    
    Write-Host "✅ Diagram generation complete" -ForegroundColor Green
}

# Specify action (greenfield - interactive PRD exploration to create ADRs)
function Invoke-Specify {
    param($repoRoot, $contextArgs)
    
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    $adrTemplate = Join-Path $repoRoot ".specify\templates\adr-template.md"
    
    Write-Host "📐 Setting up for interactive ADR creation..." -ForegroundColor Cyan
    
    # Show decomposition status
    if ($Decompose) {
        Write-Host ""
        Write-Host "🔄 Sub-system decomposition: ENABLED" -ForegroundColor Cyan
        Write-Host "   (AI agent will detect domains from PRD and propose sub-systems)" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "⚠️  Sub-system decomposition: DISABLED (-NoDecompose flag)" -ForegroundColor Yellow
        Write-Host "   (AI agent will generate monolithic ADRs)" -ForegroundColor Gray
    }
    
    # Ensure memory directory exists
    $memoryDir = Join-Path $repoRoot ".specify\memory"
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }
    
    # Initialize ADR file from template if it doesn't exist
    if (-not (Test-Path $adrFile)) {
        if (Test-Path $adrTemplate) {
            Write-Host "Creating ADR file from template..." -ForegroundColor Cyan
            Copy-Item $adrTemplate $adrFile
            Write-Host "✅ Created: $adrFile" -ForegroundColor Green
        } else {
            # Create minimal ADR file
            $minimalAdr = @"
# Architecture Decision Records

## ADR Index

| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|

---

"@
            Set-Content -Path $adrFile -Value $minimalAdr
            Write-Host "✅ Created minimal ADR file: $adrFile" -ForegroundColor Green
        }
    } else {
        Write-Host "✅ ADR file already exists: $adrFile" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Ready for interactive PRD exploration."
    Write-Host "The AI agent will:"
    if ($Decompose) {
        Write-Host "  0. (Phase 0) Detect domains in PRD and propose sub-systems" -ForegroundColor Gray
        Write-Host "     → Ask user to confirm sub-system breakdown" -ForegroundColor Gray
    }
    Write-Host "  1. Analyze your PRD/requirements input"
    Write-Host "  2. Ask clarifying questions about architecture"
    Write-Host "  3. Create ADRs for each key decision"
    Write-Host "  4. Save decisions to .specify/drafts/adr.md (Proposed status)"
    Write-Host "     (ADRs will be moved to .specify/memory after /architect.implement)"
    if ($Decompose) {
        Write-Host "  5. Organize ADRs by sub-system"
    }
    Write-Host ""
    Write-Host "After completion, run '/architect.implement' to generate full AD.md"
    
    if ($Json) {
        @{status="success"; action="specify"; adr_file=$adrFile; context=($contextArgs -join " "); decomposition=$Decompose} | ConvertTo-Json
    }
}

# Clarify action (refine existing ADRs)
function Invoke-Clarify {
    param($repoRoot, $contextArgs)
    
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    
    if (-not (Test-Path $adrFile)) {
        Write-Error "ADR file does not exist: $adrFile`nRun '/architect.specify' or '/architect.init' first"
        exit 1
    }
    
    Write-Host "🔍 Loading existing ADRs for clarification..." -ForegroundColor Cyan
    
    # Count existing ADRs
    $content = Get-Content $adrFile -Raw
    $adrCount = ([regex]::Matches($content, "^## ADR-", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    Write-Host "Found $adrCount ADR(s) in $adrFile"
    
    Write-Host ""
    Write-Host "Ready for ADR refinement."
    Write-Host "The AI agent will:"
    Write-Host "  1. Review existing ADRs"
    Write-Host "  2. Ask targeted clarification questions"
    Write-Host "  3. Update ADRs based on your responses"
    Write-Host "  4. Flag any inconsistencies or gaps"
    
    if ($Json) {
        @{status="success"; action="clarify"; adr_file=$adrFile; adr_count=$adrCount; context=($contextArgs -join " ")} | ConvertTo-Json
    }
}

# Implement action (generate full AD.md from ADRs)
function Invoke-Implement {
    param($repoRoot, $contextArgs)
    
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    $adFile = Join-Path $repoRoot "AD.md"
    $adTemplate = Join-Path $repoRoot ".specify\templates\AD-template.md"
    
    if (-not (Test-Path $adrFile)) {
        Write-Error "ADR file does not exist: $adrFile`nRun '/architect.specify' or '/architect.init' first"
        exit 1
    }
    
    Write-Host "📐 Setting up for Architecture Description generation..." -ForegroundColor Cyan
    
    # Initialize AD.md from template if it doesn't exist
    if (-not (Test-Path $adFile)) {
        if (Test-Path $adTemplate) {
            Write-Host "Creating AD.md from template..." -ForegroundColor Cyan
            Copy-Item $adTemplate $adFile
            Write-Host "✅ Created: $adFile" -ForegroundColor Green
        } else {
            Write-Host "⚠️  AD template not found: $adTemplate" -ForegroundColor Yellow
            Write-Host "The AI agent will create AD.md from scratch"
        }
    } else {
        Write-Host "✅ AD.md already exists, will be updated: $adFile" -ForegroundColor Green
    }
    
    # Count ADRs for context
    $content = Get-Content $adrFile -Raw
    $adrCount = ([regex]::Matches($content, "^## ADR-", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    
    Write-Host ""
    Write-Host "Ready for Architecture Description generation."
    Write-Host "The AI agent will:"
    Write-Host "  1. Read all $adrCount ADR(s) from .specify/drafts/adr.md"
    Write-Host "  2. Generate 7 Rozanski & Woods viewpoints"
    Write-Host "  3. Apply Security and Performance perspectives"
    Write-Host "  4. Create Mermaid diagrams for each view"
    Write-Host "  5. Write complete AD.md to project root"
    Write-Host "  6. Move Accepted ADRs to canonical location"
    Write-Host "  7. Clean up drafts if all ADRs are Accepted"
    
    if ($Json) {
        @{status="success"; action="implement"; adr_file=$adrFile; ad_file=$adFile; adr_count=$adrCount; context=($contextArgs -join " ")} | ConvertTo-Json
    }
}

# Initialize action (brownfield - reverse-engineer from codebase, ADRs only)
function Invoke-Init {
    param($repoRoot, $contextArgs)
    
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    $adrTemplate = Join-Path $repoRoot ".specify\templates\adr-template.md"
    
    Write-Host "🔍 Initializing brownfield architecture discovery..." -ForegroundColor Cyan
    
    # Ensure memory directory exists
    $memoryDir = Join-Path $repoRoot ".specify\memory"
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }
    
    # Scan existing docs for deduplication
    Write-Host ""
    $existingDocs = Scan-ExistingDocs -RepoRoot $repoRoot
    if ($existingDocs) {
        Write-Host "📋 Found existing documentation:" -ForegroundColor Yellow
        $existingDocs -split "`n" | ForEach-Object { Write-Host "  - $_" }
        Write-Host ""
    }
    
    # Detect tech stack for context
    Write-Host "🔍 Scanning codebase..." -ForegroundColor Cyan
    $techStack = Get-TechStack
    $dirStructure = Get-DirectoryStructure
    
    # Phase 0: Sub-system detection (if decomposition enabled)
    $subsystemsJson = ""
    $decomposeStatus = "disabled"
    
    if ($Decompose) {
        Write-Host ""
        Write-Host "🔄 Phase 0: Sub-System Detection" -ForegroundColor Cyan
        $subsystemsJson = Get-Subsystems
        $decomposeStatus = "enabled"
        
        if ($subsystemsJson -and $subsystemsJson -ne "[]") {
            Write-Host ""
            Write-Host "📦 Sub-systems will be used to organize ADRs" -ForegroundColor Cyan
            Write-Host "   (AI agent will confirm with user before proceeding)" -ForegroundColor Gray
        }
    } else {
        Write-Host ""
        Write-Host "⚠️  Sub-system decomposition disabled (-NoDecompose flag)" -ForegroundColor Yellow
    }
    
    # Initialize ADR file from template if it doesn't exist
    if (-not (Test-Path $adrFile)) {
        if (Test-Path $adrTemplate) {
            Write-Host "Creating ADR file from template..." -ForegroundColor Cyan
            Copy-Item $adrTemplate $adrFile
            Write-Host "✅ Created: $adrFile" -ForegroundColor Green
        } else {
            # Create minimal ADR file
            $minimalAdr = @"
# Architecture Decision Records

## ADR Index

| ID | Sub-System | Decision | Status | Date | Owner |
|----|------------|----------|--------|------|-------|

---

"@
            Set-Content -Path $adrFile -Value $minimalAdr
            Write-Host "✅ Created minimal ADR file: $adrFile" -ForegroundColor Green
        }
    } else {
        Write-Host "✅ ADR file already exists: $adrFile" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "📊 Codebase Analysis Summary:" -ForegroundColor Cyan
    Write-Host $techStack
    Write-Host ""
    Write-Host $dirStructure
    
    Write-Host ""
    Write-Host "Ready for brownfield architecture discovery."
    Write-Host "The AI agent will:"
    if ($Decompose) {
        Write-Host "  0. (Phase 0) Propose sub-systems from code structure" -ForegroundColor Gray
        Write-Host "     → Ask user to confirm sub-system breakdown" -ForegroundColor Gray
    }
    Write-Host "  1. Analyze codebase structure and patterns"
    Write-Host "  2. Infer architectural decisions from code"
    Write-Host "  3. Create ADRs marked as 'Discovered (Inferred)'"
    if ($Decompose) {
        Write-Host "  4. Organize ADRs by sub-system"
    }
    Write-Host "  5. Auto-trigger /architect.clarify to validate findings"
    Write-Host ""
    Write-Host "NOTE: AD.md will NOT be created until ADRs are validated." -ForegroundColor Yellow
    Write-Host "      After clarification, run /architect.implement to generate AD.md"
    
    if ($Json) {
        @{
            status="success"
            action="init"
            adr_file=$adrFile
            tech_stack=$techStack
            existing_docs=$existingDocs
            source="brownfield"
            decomposition=$decomposeStatus
            subsystems=$subsystemsJson
        } | ConvertTo-Json
    }
}

# Map action (brownfield)
function Invoke-Map {
    param($repoRoot)
    
    Write-Host "🔍 Mapping existing codebase to architecture..." -ForegroundColor Cyan
    
    # Scan existing docs for deduplication
    Write-Host ""
    $existingDocs = Scan-ExistingDocs -RepoRoot $repoRoot
    if ($existingDocs) {
        Write-Host "Existing Documentation Found:" -ForegroundColor Yellow
        Write-Host $existingDocs
        Write-Host ""
    }
    
    # Detect tech stack
    Write-Host ""
    Write-Host "Tech Stack Detected:" -ForegroundColor Yellow
    $techStack = Get-TechStack
    Write-Host $techStack
    
    # Map directory structure
    Write-Host ""
    Write-Host "Code Organization:" -ForegroundColor Yellow
    $dirStructure = Get-DirectoryStructure
    Write-Host $dirStructure
    
    # Output structured data for AI agent to populate AD.md Section C
    if ($Json) {
        @{
            status="success"
            action="map"
            tech_stack=$techStack
            directory_structure=$dirStructure
            existing_docs=$existingDocs
        } | ConvertTo-Json
    } else {
        Write-Host ""
        Write-Host "📋 Mapping complete. Use this information to populate AD.md:"
        Write-Host "  - Section C (Tech Stack Summary): Use detected technologies above"
        Write-Host "  - Development View: Use directory structure above"
        Write-Host "  - Deployment View: Check docker-compose.yml, k8s configs, terraform"
        Write-Host "  - Functional View: Use API endpoints detected"
        Write-Host "  - Information View: Check database schemas, ORM models"
        Write-Host "  - ⚠️  Reference existing docs instead of duplicating"
    }
}

# Update action
function Invoke-Update {
    param($repoRoot, $architectureFile)
    
    if (-not (Test-Path $architectureFile)) {
        Write-Error "Architecture does not exist: $architectureFile`nRun '/architect.specify' or '/architect.init' first"
        exit 1
    }
    
    Write-Host "🔄 Updating architecture based on recent changes..." -ForegroundColor Cyan
    
    # Check for recent commits
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "Recent changes:" -ForegroundColor Yellow
        git log --oneline --since="7 days ago" 2>$null | Select-Object -First 10
    }
    
    # Detect current tech stack
    Write-Host ""
    Write-Host "Current Tech Stack:" -ForegroundColor Yellow
    Get-TechStack
    
    # Regenerate diagrams with current format
    New-ArchitectureDiagrams -ArchitectureFile $architectureFile -SystemName "System"
    
    Write-Host ""
    Write-Host "✅ Update analysis complete" -ForegroundColor Green
    Write-Host "Review the architecture document and update affected sections:"
    Write-Host "  - New tables/models? → Update Information View"
    Write-Host "  - New services/components? → Update Functional View + Deployment View"
    Write-Host "  - New queues/async? → Update Concurrency View"
    Write-Host "  - New dependencies? → Update Development View"
    Write-Host "  - Add ADR if significant decision was made"
    
    if ($Json) {
        @{status="success"; action="update"; file=$architectureFile} | ConvertTo-Json
    }
}

# Review action
function Invoke-Review {
    param($repoRoot, $architectureFile)
    
    if (-not (Test-Path $architectureFile)) {
        Write-Error "Architecture does not exist: $architectureFile`nRun '/architect.specify' or '/architect.init' first"
        exit 1
    }
    
    Write-Host "🔍 Reviewing architecture..." -ForegroundColor Cyan
    
    $issues = @()
    $content = Get-Content $architectureFile -Raw
    
    # Check for required sections
    if ($content -notmatch "## 1\. Introduction") {
        $issues += "Missing: Introduction section"
    }
    
    if ($content -notmatch "## 2\. Stakeholders & Concerns") {
        $issues += "Missing: Stakeholders section"
    }
    
    if ($content -notmatch "## 3\. Architectural Views") {
        $issues += "Missing: Architectural Views section"
    }
    
    if ($content -notmatch "### 3\.1 Context View") {
        $issues += "Missing: Context View"
    }
    
    if ($content -notmatch "### 3\.2 Functional View") {
        $issues += "Missing: Functional View"
    }
    
    if ($content -notmatch "## 4\. Architectural Perspectives") {
        $issues += "Missing: Perspectives section"
    }
    
    if ($content -notmatch "## 5\. Global Constraints & Principles") {
        $issues += "Missing: Global Constraints section"
    }
    
    # Check for placeholders
    if ($content -match "\[SYSTEM_NAME\]") {
        $issues += "Placeholder: System name not filled in"
    }
    
    if ($content -match "\[STAKEHOLDER_") {
        $issues += "Placeholder: Stakeholders not filled in"
    }
    
    # Report results
    if ($issues.Count -eq 0) {
        Write-Host "✅ Architecture review passed - no major issues found" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Architecture review found issues:" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host "  - $issue"
        }
    }
    
    # Check constitution alignment (new path: memory/constitution.md)
    $constitutionFile = Join-Path $repoRoot ".specify\memory\constitution.md"
    if (-not (Test-Path $constitutionFile)) {
        # Fallback to legacy path
        $constitutionFile = Join-Path $repoRoot ".specify\memory\constitution.md"
    }
    if (Test-Path $constitutionFile) {
        Write-Host ""
        Write-Host "📜 Checking constitution alignment..." -ForegroundColor Cyan
        Write-Host "✅ Constitution file found: $constitutionFile" -ForegroundColor Green
        Write-Host "Manually verify that architecture adheres to constitutional principles"
    }
    
    if ($Json) {
        if ($issues.Count -eq 0) {
            @{status="success"; action="review"; issues=@()} | ConvertTo-Json
        } else {
            @{status="warning"; action="review"; issues=$issues} | ConvertTo-Json
        }
    }
}

# Analyze action (validate architecture consistency)
function Invoke-Analyze {
    param(
        [string]$repoRoot,
        [string[]]$contextArgs
    )
    
    Write-Host "🔍 Architecture Analysis Mode" -ForegroundColor Cyan
    Write-Host ""
    
    $adFile = Join-Path $repoRoot "AD.md"
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    $constitutionFile = Join-Path $repoRoot ".specify\memory\constitution.md"
    
    $adExists = Test-Path $adFile
    $adrExists = Test-Path $adrFile
    $constitutionExists = Test-Path $constitutionFile
    
    if ($adExists) {
        Write-Host "📄 AD.md found: $adFile" -ForegroundColor Green
    } else {
        Write-Host "⚠️  AD.md not found at $adFile" -ForegroundColor Yellow
    }
    
    if ($adrExists) {
        $content = Get-Content $adrFile -Raw
        $adrCount = ([regex]::Matches($content, "^### ADR-", [System.Text.RegularExpressions.RegularExpressions]('Multiline'))).Count
        Write-Host "📋 ADR file found: $adrFile ($adrCount ADRs)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  ADR file not found at $adrFile" -ForegroundColor Yellow
    }
    
    if ($constitutionExists) {
        Write-Host "📜 Constitution found: $constitutionFile" -ForegroundColor Green
    }
    
    $featureAds = @()
    $featureAdrs = @()
    
    $specsDir = Join-Path $repoRoot "specs"
    if (Test-Path $specsDir) {
        $featureAds = Get-ChildItem -Path $specsDir -Recurse -Filter "AD.md" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        $featureAdrs = Get-ChildItem -Path $specsDir -Recurse -Filter "adr.md" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        
        if ($featureAds.Count -gt 0) {
            Write-Host "📁 Feature ADs found: $($featureAds.Count)" -ForegroundColor Cyan
        }
        if ($featureAdrs.Count -gt 0) {
            Write-Host "📁 Feature ADRs found: $($featureAdrs.Count)" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "Ready for architecture consistency analysis."
    Write-Host "The AI agent will:"
    Write-Host "  1. Load all architecture artifacts"
    Write-Host "  2. Execute detection passes A-G"
    Write-Host "  3. Assign severity levels to findings"
    Write-Host "  4. Generate structured analysis report"
    Write-Host "  5. Suggest remediation actions"
    
    if ($Json) {
        @{
            status = "success"
            action = "analyze"
            ad_file = $adFile
            ad_exists = $adExists
            adr_file = $adrFile
            adr_exists = $adrExists
            constitution_file = $constitutionFile
            constitution_exists = $constitutionExists
            feature_ads = $featureAds
            feature_adrs = $featureAdrs
            context = ($contextArgs -join " ")
        } | ConvertTo-Json
    }
}

# Validate action (READ-ONLY architecture validation for plan alignment)
function Invoke-Validate {
    param($repoRoot, $contextArgs)
    
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    
    Write-Host "🔍 Architecture Validation Mode (READ-ONLY)" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if architecture exists
    if (-not (Test-Path $adrFile)) {
        Write-Host "⏭️  Architecture not found: $adrFile" -ForegroundColor Yellow
        Write-Host "     Skipping validation gracefully" -ForegroundColor Gray
        if ($Json) {
            @{status="skipped"; action="validate"; reason="architecture_not_found"} | ConvertTo-Json
        }
        exit 0
    }
    
    $content = Get-Content $adrFile -Raw
    $adrCount = ([regex]::Matches($content, "^## ADR-", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    
    Write-Host "📋 ADR file found: $adrFile" -ForegroundColor Green
    Write-Host "   Found $adrCount ADR(s)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ready for READ-ONLY architecture validation."
    Write-Host "The AI agent will:"
    Write-Host "  1. Load architecture from ADRs and AD.md"
    Write-Host "  2. Validate plan alignment with architecture"
    Write-Host "  3. Identify blocking/high-severity issues"
    Write-Host "  4. Report findings (READ-ONLY, no modifications)"
    
    if ($Json) {
        @{status="success"; action="validate"; adr_file=$adrFile; adr_count=$adrCount; context=($contextArgs -join " ")} | ConvertTo-Json
    }
}

# Plan DAG action (Phase 1 of implement - generate execution plan)
function Invoke-PlanDag {
    param($repoRoot, $contextArgs)
    
    $adrFile = Join-Path $repoRoot ".specify\drafts\adr.md"
    $stateFile = Join-Path $repoRoot ".specify\architect\state.json"
    $viewsDir = Join-Path $repoRoot ".specify\architect\views"
    
    Write-Host "📐 DAG Planning Phase" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if ADR file exists
    if (-not (Test-Path $adrFile)) {
        Write-Error "ADR drafts file does not exist: $adrFile`nRun '/architect.specify' or '/architect.init' first"
        exit 1
    }
    
    # Ensure directories exist
    $architectDir = Join-Path $repoRoot ".specify\architect"
    if (-not (Test-Path $architectDir)) {
        New-Item -ItemType Directory -Path $architectDir -Force | Out-Null
    }
    if (-not (Test-Path $viewsDir)) {
        New-Item -ItemType Directory -Path $viewsDir -Force | Out-Null
    }
    
    # Count ADRs and extract sub-systems
    $content = Get-Content $adrFile -Raw
    $adrCount = ([regex]::Matches($content, "^### ADR-|^## ADR-", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    
    # Extract unique sub-systems from ADR index table
    $subsystems = @()
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        # Parse ADR index table rows: | ADR-XXX | SubSystem | ...
        if ($line -match '^\|\s*ADR-\d+\s*\|\s*([^|]+)\s*\|') {
            $subsystem = $Matches[1].Trim()
            if ($subsystem -and $subsystem -ne "Sub-System" -and $subsystems -notcontains $subsystem) {
                $subsystems += $subsystem
            }
        }
    }
    
    # Default to "System" if no sub-systems found
    if ($subsystems.Count -eq 0) {
        $subsystems = @("System")
    }
    
    Write-Host "📋 ADR file found: $adrFile" -ForegroundColor Green
    Write-Host "   Found $adrCount ADR(s)" -ForegroundColor Cyan
    Write-Host "   Sub-systems detected: $($subsystems -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ready for DAG planning."
    Write-Host "The AI agent will:"
    Write-Host "  1. Analyze ADRs by sub-system"
    Write-Host "  2. Generate customized DAG per sub-system"
    Write-Host "  3. Present execution plan for user approval"
    Write-Host "  4. Save approved plan to state.json"
    
    if ($Json) {
        $subsystemsJson = $subsystems | ForEach-Object {
            @{
                id = ($_ -replace '\s+', '-').ToLower()
                name = $_
            }
        }
        @{
            status = "success"
            action = "plan-dag"
            adr_file = $adrFile
            state_file = $stateFile
            views_dir = $viewsDir
            adr_count = $adrCount
            subsystems = $subsystemsJson
            context = ($contextArgs -join " ")
        } | ConvertTo-Json -Depth 3
    }
}

# Execute DAG action (Phase 2 of implement - generate views based on state)
function Invoke-ExecuteDag {
    param($repoRoot, $contextArgs)
    
    $stateFile = Join-Path $repoRoot ".specify\architect\state.json"
    $viewsDir = Join-Path $repoRoot ".specify\architect\views"
    
    Write-Host "🔧 DAG Execution Phase" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if state file exists
    if (-not (Test-Path $stateFile)) {
        Write-Error "No execution plan found: $stateFile`nRun '/architect.implement' first to generate and approve a DAG plan"
        exit 1
    }
    
    # Ensure views directory exists
    if (-not (Test-Path $viewsDir)) {
        New-Item -ItemType Directory -Path $viewsDir -Force | Out-Null
    }
    
    Write-Host "📄 State file found: $stateFile" -ForegroundColor Green
    Write-Host "📁 Views directory: $viewsDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ready for DAG execution."
    Write-Host "The AI agent will:"
    Write-Host "  1. Read execution plan from state.json"
    Write-Host "  2. Identify next view(s) to generate"
    Write-Host "  3. Generate view with dependency context"
    Write-Host "  4. Write to .specify/architect/views/{subsystem}/{view}.md"
    Write-Host "  5. Update progress in state.json"
    
    if ($Json) {
        $stateContent = Get-Content $stateFile -Raw | ConvertFrom-Json
        @{
            status = "success"
            action = "execute-dag"
            state_file = $stateFile
            views_dir = $viewsDir
            state = $stateContent
        } | ConvertTo-Json -Depth 10
    }
}

# Summarize action (Phase 3 of implement - aggregate views into AD.md)
function Invoke-Summarize {
    param($repoRoot, $contextArgs)
    
    $stateFile = Join-Path $repoRoot ".specify\architect\state.json"
    $viewsDir = Join-Path $repoRoot ".specify\architect\views"
    $adFile = Join-Path $repoRoot "AD.md"
    $adrFile = Join-Path $repoRoot ".specify\drafts\adr.md"
    
    Write-Host "📝 Summarization Phase" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if views directory exists and has content
    if (-not (Test-Path $viewsDir)) {
        Write-Error "Views directory not found: $viewsDir`nRun '/architect.implement' to generate views first"
        exit 1
    }
    
    # Count view files
    $viewFiles = Get-ChildItem -Path $viewsDir -Filter "*.md" -Recurse -File
    $viewCount = $viewFiles.Count
    
    if ($viewCount -eq 0) {
        Write-Error "No view files found in $viewsDir`nRun '/architect.implement' to generate views first"
        exit 1
    }
    
    Write-Host "📁 Views directory: $viewsDir" -ForegroundColor Cyan
    Write-Host "   Found $viewCount view file(s):" -ForegroundColor Cyan
    foreach ($file in $viewFiles) {
        $relativePath = $file.FullName.Substring($viewsDir.Length + 1)
        Write-Host "   - $relativePath" -ForegroundColor Gray
    }
    Write-Host ""
    
    Write-Host "Ready for summarization."
    Write-Host "The AI agent will:"
    Write-Host "  1. Read all view files from .specify/architect/views/"
    Write-Host "  2. Detect cross-subsystem conflicts"
    Write-Host "  3. Resolve conflicts using ADRs as source of truth"
    Write-Host "  4. Aggregate into unified AD.md"
    Write-Host "  5. Apply Security and Performance perspectives"
    Write-Host "  6. Move Accepted ADRs to canonical location"
    
    if ($Json) {
        $viewsJson = $viewFiles | ForEach-Object {
            @{
                path = $_.FullName
                relative = $_.FullName.Substring($viewsDir.Length + 1)
            }
        }
        @{
            status = "success"
            action = "summarize"
            state_file = $stateFile
            views_dir = $viewsDir
            ad_file = $adFile
            adr_file = $adrFile
            view_count = $viewCount
            views = $viewsJson
        } | ConvertTo-Json -Depth 3
    }
}

# Main execution
try {
    $repoRoot = Get-RepositoryRoot
    
    # Ensure memory directory exists
    $memoryDir = Join-Path $repoRoot ".specify\memory"
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }
    
    # Architecture files (new structure: AD.md at root, ADRs in memory/)
    $adFile = Join-Path $repoRoot "AD.md"
    $adrFile = Join-Path $repoRoot ".specify\memory\adr.md"
    $templateFile = Join-Path $repoRoot ".specify\templates\architecture-template.md"
    $adTemplateFile = Join-Path $repoRoot ".specify\templates\AD-template.md"
    
    # Export for use in functions
    $env:ARCHITECTURE_VIEWS = $Views
    $env:ADR_HEURISTIC = $AdrHeuristic
    
    # Default action if not specified
    if (-not $Action) {
        if (Test-Path $adFile) {
            $Action = "update"
        } else {
            $Action = "init"
        }
    }
    
    # Execute action
    switch ($Action) {
        'specify' {
            Invoke-Specify -repoRoot $repoRoot -contextArgs $Context
        }
        'clarify' {
            Invoke-Clarify -repoRoot $repoRoot -contextArgs $Context
        }
        'init' {
            Invoke-Init -repoRoot $repoRoot -contextArgs $Context
        }
        'map' {
            Invoke-Map -repoRoot $repoRoot
        }
        'implement' {
            Invoke-Implement -repoRoot $repoRoot -contextArgs $Context
        }
        'analyze' {
            Invoke-Analyze -repoRoot $repoRoot -contextArgs $Context
        }
        'validate' {
            Invoke-Validate -repoRoot $repoRoot -contextArgs $Context
        }
        'plan-dag' {
            Invoke-PlanDag -repoRoot $repoRoot -contextArgs $Context
        }
        'execute-dag' {
            Invoke-ExecuteDag -repoRoot $repoRoot -contextArgs $Context
        }
        'summarize' {
            Invoke-Summarize -repoRoot $repoRoot -contextArgs $Context
        }
        'update' {
            Invoke-Update -repoRoot $repoRoot -architectureFile $adFile
        }
        'review' {
            Invoke-Review -repoRoot $repoRoot -architectureFile $adFile
        }
        default {
            Write-Error "Unknown action: $Action`nUse -Help for usage information"
            exit 1
        }
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
