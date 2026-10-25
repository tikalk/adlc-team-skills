# radar-search.ps1 — deterministic search over the Tikal Tech Radar OKF knowledge tree.
# PowerShell native. No Python/Node dependency.
#
# Knowledge source: gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-radar
# `knowledge/technologies/` is the system of record. A shallow clone is cached and
# refreshed after ADLC_RADAR_TTL seconds (default 3 days). When the repository is
# unreachable the helper falls back to the stale clone (with a warning), then to the
# public radar JSON (ConvertFrom-Json), announcing the fallback on stdout.
#
# Usage:
#   pwsh radar-search.ps1 <query1> [query2 ...] [-Json] [-Refresh]
#
# Options:
#   -Json               JSON array output instead of the markdown table
#   -Refresh            force a git refresh even inside the TTL
#   -Quadrant <Q>       filter: DevOps | Backend | AI/ML | Web/Mobile
#   -Ring <R>           filter: Try | Start | Keep | Stop
#   -Limit <N>          max rows per category (body-term) match (default 5)
#   -IncludeExcluded    include docs marked `include: no`
#
# Environment: ADLC_RADAR_URL, ADLC_RADAR_BRANCH, ADLC_RADAR_CACHE,
# ADLC_RADAR_REPO, ADLC_RADAR_TTL, ADLC_RADAR_FALLBACK_URL,
# ADLC_RADAR_CONNECT_TIMEOUT
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Queries,
    [switch]$Json,
    [switch]$Refresh,
    [switch]$IncludeExcluded,
    [string]$Quadrant = "",
    [string]$Ring = "",
    [int]$Limit = 5
)

$ErrorActionPreference = "Continue"

function Get-EnvOr([string]$Name, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { return $Default }
    return $value
}

$RepoUrl = Get-EnvOr "ADLC_RADAR_URL" "git@gitlab.tikalk.dev:tikalk/engineering/agentic-sdlc/adlc-radar.git"
$RepoBranch = Get-EnvOr "ADLC_RADAR_BRANCH" "main"
$CacheTtl = [int](Get-EnvOr "ADLC_RADAR_TTL" "259200")
$CacheDir = Get-EnvOr "ADLC_RADAR_CACHE" (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".cache/adlc/radar")
$LocalRepo = Get-EnvOr "ADLC_RADAR_REPO" ""
$FallbackUrl = Get-EnvOr "ADLC_RADAR_FALLBACK_URL" "https://tikalk.com/radar.json"
$ConnectTimeout = Get-EnvOr "ADLC_RADAR_CONNECT_TIMEOUT" "10"
$SshCommand = "ssh -o ConnectTimeout=$ConnectTimeout -o BatchMode=yes"

function Get-UnixNow { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

function Format-UnixTime([long]$Epoch) {
    return [DateTimeOffset]::FromUnixTimeSeconds($Epoch).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Write-Notice([string]$Message) {
    Write-Output "> ⚠️ $Message"
    Write-Output ""
}

function Invoke-Git {
    param([string[]]$Arguments)
    $output = & git @Arguments 2>&1
    return @{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Get-CacheAge {
    $stamp = Join-Path $CacheDir ".adlc-radar-synced"
    if (Test-Path -LiteralPath $stamp) {
        $raw = (Get-Content -LiteralPath $stamp -Raw).Trim()
        $stamped = 0L
        if ([long]::TryParse($raw, [ref]$stamped) -and $stamped -gt 0) {
            return [long]((Get-UnixNow) - $stamped)
        }
    }
    $fetchHead = Join-Path $CacheDir ".git/FETCH_HEAD"
    if (Test-Path -LiteralPath $fetchHead) {
        $age = (Get-UnixNow) - [long]((Get-Item -LiteralPath $fetchHead).LastWriteTimeUtc - [DateTime]::UnixEpoch).TotalSeconds
        return $age
    }
    return 999999999L
}

function Get-SyncedAt {
    $stamp = Join-Path $CacheDir ".adlc-radar-synced"
    if (Test-Path -LiteralPath $stamp) {
        $raw = (Get-Content -LiteralPath $stamp -Raw).Trim()
        $stamped = 0L
        if ([long]::TryParse($raw, [ref]$stamped) -and $stamped -gt 0) { return (Format-UnixTime $stamped) }
    }
    $fetchHead = Join-Path $CacheDir ".git/FETCH_HEAD"
    if (Test-Path -LiteralPath $fetchHead) {
        $epoch = [long]((Get-Item -LiteralPath $fetchHead).LastWriteTimeUtc - [DateTime]::UnixEpoch).TotalSeconds
        return (Format-UnixTime $epoch)
    }
    return "unknown"
}

function Get-CacheSha {
    if (Test-Path -LiteralPath $CacheDir) {
        $result = Invoke-Git @("-C", $CacheDir, "rev-parse", "--short", "HEAD")
        if ($result.Code -eq 0) { return $result.Output.Trim() }
    }
    return "unknown"
}

function Initialize-Cache {
    $state = @{ Mode = "unavailable"; Reason = ""; Sha = ""; SyncedAt = "" }

    if ($LocalRepo -ne "") {
        if (Test-Path -LiteralPath (Join-Path $LocalRepo "knowledge/technologies")) {
            $state.Mode = "local"
            $shaResult = Invoke-Git @("-C", $LocalRepo, "rev-parse", "--short", "HEAD")
            $state.Sha = if ($shaResult.Code -eq 0) { $shaResult.Output.Trim() } else { "unknown" }
            $state.SyncedAt = "local clone"
            return $state
        }
        $state.Reason = "ADLC_RADAR_REPO=$LocalRepo has no knowledge/technologies"
        return $state
    }

    $knowledgePath = Join-Path $CacheDir "knowledge/technologies"
    if (-not (Test-Path -LiteralPath $knowledgePath)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CacheDir) | Out-Null
        $clone = Invoke-Git @("-c", "core.sshCommand=$SshCommand", "clone", "--depth", "1", "--quiet", "--branch", $RepoBranch, $RepoUrl, $CacheDir)
        if ($clone.Code -ne 0) {
            $state.Reason = "clone failed ($RepoUrl)"
            return $state
        }
        Set-Content -LiteralPath (Join-Path $CacheDir ".adlc-radar-synced") -Value (Get-UnixNow) -NoNewline
    }
    else {
        $age = Get-CacheAge
        if ($Refresh -or $age -ge $CacheTtl) {
            $fetch = Invoke-Git @("-C", $CacheDir, "-c", "core.sshCommand=$SshCommand", "fetch", "--depth", "1", "--quiet", "origin", $RepoBranch)
            $reset = if ($fetch.Code -eq 0) { Invoke-Git @("-C", $CacheDir, "reset", "--hard", "--quiet", "FETCH_HEAD") } else { @{ Code = 1 } }
            if ($reset.Code -eq 0) {
                Set-Content -LiteralPath (Join-Path $CacheDir ".adlc-radar-synced") -Value (Get-UnixNow) -NoNewline
            }
            else {
                $state.Mode = "stale"
                $state.Reason = "refresh failed ($RepoUrl)"
                $state.Sha = Get-CacheSha
                $state.SyncedAt = Get-SyncedAt
                return $state
            }
        }
    }

    $state.Mode = "okf"
    $state.Sha = Get-CacheSha
    $state.SyncedAt = Get-SyncedAt
    return $state
}

function Get-DocRecord([System.IO.FileInfo]$File) {
    $title = ""
    $quadrant = ""
    $ring = ""
    $include = ""
    $frontmatterOpen = $false
    $frontmatterDone = $false
    $inWhy = $false
    $why = New-Object System.Collections.Generic.List[string]

    foreach ($line in (Get-Content -LiteralPath $File.FullName)) {
        if (-not $frontmatterDone) {
            if ($line -eq "---") {
                if ($frontmatterOpen) { $frontmatterDone = $true } else { $frontmatterOpen = $true }
                continue
            }
            if ($frontmatterOpen) {
                if ($line -match '^([A-Za-z_]+):\s*(.*)$') {
                    $key = $Matches[1]
                    $value = $Matches[2].Trim().Trim('"')
                    if ($key -eq "title") { $title = $value }
                    elseif ($key -eq "quadrant") { $quadrant = $value }
                    elseif ($key -eq "ring") { $ring = $value }
                    elseif ($key -eq "include") { $include = $value }
                }
                continue
            }
        }
        if ($inWhy) {
            if ($line -match '^## ') { $inWhy = $false }
            else { $why.Add($line) | Out-Null; continue }
        }
        if ($line -match '^## Why\s*$') { $inWhy = $true }
    }

    if ([string]::IsNullOrWhiteSpace($title)) { return $null }
    $whyText = (($why -join " ") -replace '\s+', ' ').Trim()
    return [PSCustomObject]@{
        Title    = $title
        Quadrant = $quadrant
        Ring     = $ring
        Include  = $include
        Path     = $File.FullName
        Why      = $whyText
    }
}

function Get-KnowledgeDocs([string]$Root) {
    $techDir = Join-Path $Root "knowledge/technologies"
    if (-not (Test-Path -LiteralPath $techDir)) { return @() }
    $files = Get-ChildItem -LiteralPath $techDir -Directory |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter "*.md" -File } |
        Where-Object { $_.Name -ne "index.md" } |
        Sort-Object FullName
    $docs = @()
    foreach ($file in $files) {
        $record = Get-DocRecord $file
        if ($null -ne $record) { $docs += $record }
    }
    return $docs
}

function Normalize-Alias([string]$Query) {
    $q = $Query.Trim().ToLowerInvariant()
    switch ($q) {
        "k8s" { return "Kubernetes" }
        "kube" { return "Kubernetes" }
        "kubernetes" { return "Kubernetes" }
        "postgres" { return "PostgreSQL" }
        "postgresql" { return "PostgreSQL" }
        "pg" { return "PostgreSQL" }
        "gh actions" { return "GitHub Actions" }
        "github-actions" { return "GitHub Actions" }
        "cra" { return "Create React App" }
        "create-react-app" { return "Create React App" }
        "next" { return "Next.js" }
        "nextjs" { return "Next.js" }
        "vue" { return "Vue.js" }
        "vuejs" { return "Vue.js" }
        "node" { return "Node.js" }
        "nodejs" { return "Node.js" }
        "ts" { return "TypeScript" }
        "typescript" { return "TypeScript" }
        "iac" { return "Infrastructure as Code (IaC)" }
        "mcp" { return "Model Context Protocol (MCP)" }
        "rsc" { return "React Server Components" }
        "rtk" { return "Redux Toolkit" }
        "idp" { return "Internal Developer Portals (IDPs) (e.g., Port.io. Backstage)" }
        "eso" { return "External Secrets Operator" }
        "gke" { return "GKE Workload Identity" }
        default { return $Query }
    }
}

function Test-Filters($Doc) {
    if ($Quadrant -ne "" -and $Doc.Quadrant.ToLowerInvariant() -ne $Quadrant.ToLowerInvariant()) { return $false }
    if ($Ring -ne "" -and $Doc.Ring.ToLowerInvariant() -ne $Ring.ToLowerInvariant()) { return $false }
    return $true
}

function Get-WhySnippet([string]$Why) {
    if ($Why.Length -le 160) { return $Why }
    $cut = $Why.Substring(0, 157)
    $lastSpace = $cut.LastIndexOf(' ')
    if ($lastSpace -gt 0) { $cut = $cut.Substring(0, $lastSpace) }
    return "$cut..."
}

function Search-Docs($Docs, [string]$Query) {    $results = @()
    $canonical = Normalize-Alias $Query
    $needle = $canonical.ToLowerInvariant()
    foreach ($doc in $Docs) {
        if (-not (Test-Filters $doc)) { continue }
        if (-not $IncludeExcluded -and $doc.Include.ToLowerInvariant() -eq "no") { continue }
        $title = $doc.Title.ToLowerInvariant()
        if ($title -eq $needle -or $title.StartsWith($needle) -or $title.Contains($needle)) {
            $results += $doc
        }
    }
    if ($results.Count -gt 0) { return $results }

    # Category query: rank body terms, title hits weigh 3x.
    $terms = ($Query.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -ge 2 -and $_ -notmatch '^(no|not|such|the|and|or|for|with|need|want|using|use|of|to|in|on|at|by|is|are|be|we|our|a|an)$' }
    if ($terms.Count -eq 0) { return @() }
    $scored = @()
    foreach ($doc in $Docs) {
        if (-not (Test-Filters $doc)) { continue }
        if (-not $IncludeExcluded -and $doc.Include.ToLowerInvariant() -eq "no") { continue }
        $title = $doc.Title.ToLowerInvariant()
        $body = "$title $($doc.Why.ToLowerInvariant())"
        $score = 0
        foreach ($term in $terms) {
            $score += 3 * ([regex]::Matches($title, [regex]::Escape($term))).Count
            $score += ([regex]::Matches($body, [regex]::Escape($term))).Count
        }
        if ($score -ge 2) { $scored += [PSCustomObject]@{ Score = $score; Doc = $doc } }
    }
    return @($scored | Sort-Object Score -Descending | Select-Object -First $Limit | ForEach-Object { $_.Doc })
}

function Search-FallbackJson([string]$Data) {
    $radar = $Data | ConvertFrom-Json
    if (-not $radar.blips) { return @() }
    $results = @()
    foreach ($query in $Queries) {
        $canonical = Normalize-Alias $query
        $needle = $canonical.ToLowerInvariant()
        foreach ($blip in $radar.blips) {
            if ($Quadrant -ne "" -and $blip.quadrant.ToLowerInvariant() -ne $Quadrant.ToLowerInvariant()) { continue }
            if ($Ring -ne "" -and $blip.ring.ToLowerInvariant() -ne $Ring.ToLowerInvariant()) { continue }
            $name = $blip.name.ToLowerInvariant()
            if (-not ($name -eq $needle -or $name.StartsWith($needle) -or $name.Contains($needle))) { continue }
            $why = ""
            if ($blip.description) {
                $why = $blip.description
                if ($why -match '(?s)<p>Why\?</p>') {
                    $why = $why -replace '(?s)<p>Why\?</p>', ''
                    $why = ($why -split '(?s)<p>Description</p>')[0]
                }
                $why = ($why -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim()
            }
            $results += [PSCustomObject]@{
                Title = $blip.name; Quadrant = $blip.quadrant; Ring = $blip.ring
                Include = "yes"; Path = "public:radar.json"; Why = (Get-WhySnippet $why)
            }
        }
    }
    return $results
}

if ($null -eq $Queries -or $Queries.Count -eq 0) {
    Write-Output "Usage: radar-search.ps1 <tech1> [tech2 ...] [-Json] [-Refresh]"
    exit 1
}

$state = Initialize-Cache
$docs = @()
$results = @()
$dataUnavailable = $false

if ($state.Mode -eq "unavailable") {
    Write-Notice "Radar knowledge repository unavailable ($($state.Reason)) — working with the public radar JSON at $FallbackUrl. It is generated from the same knowledge tree and may lag it."
    try {
        if ($FallbackUrl -like "file://*") { $payload = Get-Content -LiteralPath $FallbackUrl.Substring(7) -Raw }
        elseif ($FallbackUrl -match '^/') { $payload = Get-Content -LiteralPath $FallbackUrl -Raw }
        else { $payload = (Invoke-WebRequest -Uri $FallbackUrl -TimeoutSec ([int]$ConnectTimeout) -UseBasicParsing).Content }
        $results = @(Search-FallbackJson $payload)
    }
    catch {
        $dataUnavailable = $true
        [Console]::Error.WriteLine("radar-search: public radar JSON unavailable at $FallbackUrl")
    }
}
else {
    if ($state.Mode -eq "stale") {
        Write-Notice "Radar knowledge repository unreachable ($($state.Reason)) — using the cached OKF tree from $($state.SyncedAt). Rings may have moved since then."
    }
    $root = if ($LocalRepo -ne "") { $LocalRepo } else { $CacheDir }
    $docs = @(Get-KnowledgeDocs $root)
    $seen = New-Object System.Collections.Generic.HashSet[string]
    foreach ($query in $Queries) {
        if ([string]::IsNullOrWhiteSpace($query)) { continue }
        foreach ($doc in @(Search-Docs $docs $query)) {
            $key = "$($doc.Title)|$($doc.Quadrant)|$($doc.Ring)"
            if ($seen.Add($key)) {
                $results += [PSCustomObject]@{
                    Title = $doc.Title; Quadrant = $doc.Quadrant; Ring = $doc.Ring
                    Include = $doc.Include; Path = $doc.Path; Why = (Get-WhySnippet $doc.Why)
                }
            }
        }
    }
}

switch ($state.Mode) {
    "local" { $sourceLabel = "adlc-radar OKF tree (local clone at $LocalRepo@$($state.Sha))" }
    "stale" { $sourceLabel = "adlc-radar OKF tree ($RepoBranch@$($state.Sha), synced $($state.SyncedAt); STALE — $($state.Reason))" }
    "fallback" { $sourceLabel = "FALLBACK public radar.json ($FallbackUrl)" }
    default { $sourceLabel = "adlc-radar OKF tree ($RepoBranch@$($state.Sha), synced $($state.SyncedAt))" }
}
if ($state.Mode -eq "unavailable") { $sourceLabel = "FALLBACK public radar.json ($FallbackUrl)" }

if ($Json) {
    $results | ConvertTo-Json -Depth 3
    exit 0
}

Write-Output "## Tikal Tech Radar Context"
Write-Output ""

if ($results.Count -gt 0) {
    Write-Output "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |"
    Write-Output "|------------|----------|------|------------------------|"
    foreach ($r in $results) {
        Write-Output "| $($r.Title) | $($r.Quadrant) | $($r.Ring) | $($r.Why) |"
    }
    Write-Output ""
    Write-Output "**Radar Guidance**"
    foreach ($group in ($results | Group-Object Title)) {
        $rings = $group.Group.Ring | Sort-Object -Unique
        $placements = ($group.Group | ForEach-Object { "$($_.Quadrant): $($_.Ring)" }) -join ","
        $hasStop = $rings -contains "Stop"
        $hasKeep = ($rings -contains "Keep") -or ($rings -contains "Start")
        $hasTry = $rings -contains "Try"
        if ($hasStop -and $hasKeep) {
            Write-Output "- ⚡ **Conflicting Placements**: ``$($group.Name)`` has multiple placements across categories ($placements). Check specific quadrant context."
        }
        elseif ($hasStop) {
            Write-Output "- ⚠️ **Stop**: ``$($group.Name)`` — Tikal advises against usage; better alternatives exist. Seek Keep/Start alternatives in the same quadrant."
        }
        elseif ($hasKeep) {
            Write-Output "- ✅ **Adopt**: ``$($group.Name)`` — Recommended standard ($placements)."
        }
        elseif ($hasTry) {
            Write-Output "- 🧪 **Try**: ``$($group.Name)`` — Seems promising on the surface; evaluate before broader adoption."
        }
    }
    Write-Output ""
}

if ($dataUnavailable) {
    Write-Output "_Source: Tikal Israeli Tech Radar — radar unavailable (knowledge repository and $FallbackUrl both unreachable) · 0 technologies matched._"
}
elseif ($results.Count -eq 0) {
    Write-Output "_Source: Tikal Israeli Tech Radar — $sourceLabel · 0 technologies matched._"
}
elseif ($state.Mode -eq "unavailable") {
    Write-Output "_Source: Tikal Israeli Tech Radar — $sourceLabel · $($results.Count) blip placement(s) matched._"
}
else {
    Write-Output "_Source: Tikal Israeli Tech Radar — $sourceLabel · $($docs.Count) documents scanned, $($results.Count) placement(s) matched._"
}
