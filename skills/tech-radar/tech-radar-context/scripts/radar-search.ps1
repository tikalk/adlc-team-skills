# radar-search.ps1 — Deterministic search and alias normalization for Tikal Tech Radar.
# PowerShell native (ConvertFrom-Json). No Python/Node dependency.
#
# Usage:
#   pwsh radar-search.ps1 <query1> [query2 ...] [-Json]
#
# Examples:
#   pwsh radar-search.ps1 postgresql redis
#   pwsh radar-search.ps1 k8s "gh actions"
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Queries,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$radarJson = Join-Path $scriptDir ".." "resources" "radar.json"
if (-not (Test-Path $radarJson)) {
    $radarJson = Join-Path $PWD "skills" "tech-radar" "tech-radar-context" "resources" "radar.json"
}
if (-not (Test-Path $radarJson)) {
    Write-Error "radar.json not found"
    exit 1
}

$radar = Get-Content $radarJson -Raw | ConvertFrom-Json

$aliases = @{
    "k8s" = "Kubernetes"; "kube" = "Kubernetes"
    "postgres" = "PostgreSQL"; "postgresql" = "PostgreSQL"; "pg" = "PostgreSQL"
    "gh actions" = "GitHub Actions"; "github-actions" = "GitHub Actions"
    "cra" = "Create React App"; "create-react-app" = "Create React App"
    "next" = "Next.js"; "nextjs" = "Next.js"
    "vue" = "Vue.js"; "vuejs" = "Vue.js"
    "node" = "Node.js"; "nodejs" = "Node.js"
    "ts" = "TypeScript"; "typescript" = "TypeScript"
    "mongo" = "Beanie (mongo ORM)"; "mongodb" = "Beanie (mongo ORM)"
    "pydantic" = "PydanticAI"
    "iac" = "Infrastructure as Code (IaC)"
    "mcp" = "Model Context Protocol (MCP)"
    "rsc" = "React Server Components"
    "rtk" = "Redux Toolkit"
    "idp" = "Internal Developer Portals (IDPs) (e.g., Port.io. Backstage)"
    "eso" = "External Secrets Operator"
    "gke" = "GKE Workload Identity"
    "airflow" = "Airflow 3"
    "spark" = "Apache Spark 4.0"
}

function Normalize-Alias([string]$q) {
    $ql = $q.ToLower()
    if ($aliases.ContainsKey($ql)) { return $aliases[$ql] }
    return $q
}

function Extract-Why([string]$desc) {
    if (-not $desc) { return "" }
    $text = $desc
    if ($text -match '(?s)<p>Why\?</p>') {
        $text = $text -replace '(?s)<p>Why\?</p>', ''
        $text = ($text -split '(?s)<p>Description</p>')[0]
    }
    # Strip HTML tags, collapse whitespace
    $text = $text -replace '<[^>]+>', ' ' -replace '\s+', ' '
    return $text.Trim()
}

if ($Queries.Count -eq 0) {
    Write-Output "Usage: radar-search.ps1 <tech1> [tech2 ...] [-Json]"
    exit 1
}

$results = @()
$seen = @{}

foreach ($rawQ in $Queries) {
    $q = $rawQ.Trim().ToLower()
    if (-not $q) { continue }
    $canonical = Normalize-Alias $rawQ
    $cl = $canonical.ToLower()

    foreach ($blip in $radar.blips) {
        $name = $blip.name
        $nl = $name.ToLower()
        $match = ($nl -eq $cl) -or ($nl.StartsWith($cl)) -or ($nl.Contains($cl)) -or ($nl.Contains($q))
        if ($match) {
            $key = "$name|$($blip.quadrant)|$($blip.ring)"
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $why = Extract-Why $blip.description
                if ($why.Length -gt 160) { $why = $why.Substring(0, 157) + "..." }
                $results += [PSCustomObject]@{
                    name = $name
                    quadrant = $blip.quadrant
                    ring = $blip.ring
                    why = $why
                }
            }
        }
    }
}

if ($Json) {
    $results | ConvertTo-Json -Depth 3
    exit 0
}

# Markdown output
Write-Output "## Tikal Tech Radar Context"
Write-Output ""
Write-Output "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |"
Write-Output "|------------|----------|------|------------------------|"

foreach ($r in $results) {
    Write-Output "| $($r.name) | $($r.quadrant) | $($r.ring) | $($r.why) |"
}

Write-Output ""
Write-Output "**Radar Guidance**"

$techGroups = $results | Group-Object name
foreach ($g in $techGroups) {
    $rings = $g.Group.ring | Sort-Object -Unique
    $placements = ($g.Group | ForEach-Object { "$($_.quadrant): $($_.ring)" }) -join ","
    $hasStop = $rings -contains "Stop"
    $hasKeep = ($rings -contains "Keep") -or ($rings -contains "Start")
    $hasTry = $rings -contains "Try"

    if ($hasStop -and $hasKeep) {
        Write-Output "- ⚡ **Conflicting Placements**: ``$($g.Name)`` has multiple placements across categories ($placements). Check specific quadrant context."
    } elseif ($hasStop) {
        Write-Output "- ⚠️ **Stop**: ``$($g.Name)`` — Tikal advises against usage; seek Keep/Start alternatives in the same quadrant."
    } elseif ($hasKeep) {
        Write-Output "- ✅ **Adopt**: ``$($g.Name)`` — Recommended standard ($placements)."
    } elseif ($hasTry) {
        Write-Output "- 🧪 **Try**: ``$($g.Name)`` — Promising technology; suitable for low-risk trials or POCs."
    }
}

Write-Output ""
Write-Output "_Source: Tikal Israeli Tech Radar (local snapshot) · $($results.Count) blip placement(s) matched._"
