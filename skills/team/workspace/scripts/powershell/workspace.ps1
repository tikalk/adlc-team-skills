# workspace.ps1 — Multi-repo workspace coordinator for shared team context.
# PowerShell twin of bash/workspace.sh; one behavior, two platform scripts;
# keep in lockstep.
#
# Modes:
#   (default)  Discover child repos at depth 1, show summary.
#   --link     Register child repos as Git submodules.
#   --status   Detailed audit: branch, dirty, unpushed, SHA drift, .adlc presence.
#   --dry-run  Preview (combine with --link).
#   --force    Convert repos already tracked in parent index (combine with --link).
#   --json     Emit JSON on stdout.
#
# The bash twin shells out to python3 for JSON safety; this twin uses native
# ConvertTo-Json (no python dependency on Windows).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

$JSON_MODE = $false
$LINK_MODE = $false
$STATUS_MODE = $false
$DRY_RUN = $false
$FORCE = $false

foreach ($a in $args) {
    switch ([string]$a) {
        '--json'   { $JSON_MODE = $true }
        '--link'   { $LINK_MODE = $true }
        '--status' { $STATUS_MODE = $true }
        '--dry-run' { $DRY_RUN = $true }
        '--force'  { $FORCE = $true }
        default    { }
    }
}

# --- helpers -----------------------------------------------------------------

function Get-RepoRoot {
    $out = @(git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $out.Count -gt 0 -and $out[0]) { return [string]$out[0] }
    return (Get-Location).Path
}

function Test-Git {
    git rev-parse --is-inside-work-tree *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-Submodule {
    param([string]$Path)
    $out = @(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($line in $out) {
        # each line: "<submodule.<name>.path> <path>"
        if ($line -cmatch ("^[^ ]+ " + [regex]::Escape($Path) + "$")) { return $true }
    }
    return $false
}

function Test-TrackedInParent {
    param([string]$Path)
    git ls-files --error-unmatch $Path *> $null
    return ($LASTEXITCODE -eq 0)
}

function Get-RemoteUrl {
    param([string]$RepoPath)
    $out = @(git -C $RepoPath remote get-url origin 2>$null)
    if ($LASTEXITCODE -eq 0 -and $out.Count -gt 0 -and $out[0]) { return [string]$out[0] }
    return ''
}

# Directories that are never considered child repos.
# NOTE: .specify is intentionally NOT excluded — it may be a legit child repo.
$EXCLUDE_DIRS = @('node_modules', '.venv', 'vvenv', 'dist', 'build', 'target', '.idea', '.vscode', '.git', '.cache')

function Test-Excluded {
    param([string]$Name)
    return ($EXCLUDE_DIRS -contains $Name)
}

function Get-ChildRepos {
    param([string]$Root)
    $discovered = @()
    foreach ($dir in (Get-ChildItem -LiteralPath $Root -Directory | Sort-Object -Property Name)) {
        if (Test-Excluded $dir.Name) { continue }
        if ((Test-Path (Join-Path $dir.FullName '.git'))) {
            $discovered += $dir.Name
        }
    }
    return $discovered
}

function Get-UnpushedCount {
    param([string]$RepoPath)
    $branch = @(git -C $RepoPath branch --show-current 2>$null)
    if ($LASTEXITCODE -ne 0 -or $branch.Count -eq 0 -or -not $branch[0]) { return 0 }
    $log = @(git -C $RepoPath log --oneline "origin/$branch..HEAD" 2>$null)
    if ($LASTEXITCODE -ne 0) { return 0 }
    return $log.Count
}

function Get-ParentSha {
    param([string]$Name)
    $out = @(git ls-tree HEAD $Name 2>$null)
    if ($LASTEXITCODE -ne 0 -or $out.Count -eq 0) { return '' }
    # "<mode> <type> <sha>\t<path>"
    $fields = ([string]$out[0]) -split '\s+'
    if ($fields.Count -ge 3) { return $fields[2] }
    return ''
}

function Get-ChildHeadSha {
    param([string]$RepoPath)
    $out = @(git -C $RepoPath rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $out.Count -gt 0 -and $out[0]) { return [string]$out[0] }
    return ''
}

function Test-RepoDirty {
    param([string]$RepoPath)
    git -C $RepoPath diff --quiet HEAD -- *> $null
    return ($LASTEXITCODE -ne 0)
}

# --- pre-flight --------------------------------------------------------------

if (-not (Test-Git)) {
    if ($JSON_MODE) {
        Write-Output '{"error": "Not a git repository. Workspace must be initialized with git."}'
    } else {
        [Console]::Error.WriteLine('Error: Not a git repository. Workspace must be initialized with git.')
    }
    exit 1
}

$REPO_ROOT = Get-RepoRoot
Set-Location -LiteralPath $REPO_ROOT

$PARENT_BRANCH = ''
$pb = @(git branch --show-current 2>$null)
if ($LASTEXITCODE -eq 0 -and $pb.Count -gt 0 -and $pb[0]) { $PARENT_BRANCH = [string]$pb[0] } else { $PARENT_BRANCH = 'unknown' }
$PARENT_HAS_ADLC = Test-Path (Join-Path $REPO_ROOT '.adlc')

# Determine mode
if ($STATUS_MODE)      { $MODE = 'status' }
elseif ($LINK_MODE)    { $MODE = 'link' }
else                   { $MODE = 'discover' }

# Discover children early (needed for safety check on --link)
$CHILD_REPOS = @(Get-ChildRepos $REPO_ROOT)

# --- safety check for --link -------------------------------------------------

if ($LINK_MODE) {
    $childPatterns = @()
    foreach ($repo in $CHILD_REPOS) {
        $childPatterns += ('^' + [regex]::Escape($repo) + '(/|$)')
    }
    # single alternation of child path prefixes (empty when no children)
    $childPattern = $childPatterns -join '|'

    $hasUncommitted = $false
    $nonChildChanges = @()

    $staged = @()
    git diff --quiet --cached *> $null
    if ($LASTEXITCODE -ne 0) {
        $staged = @(git diff --cached --name-only 2>$null)
    }
    if ($staged.Count -gt 0) {
        $filtered = $staged
        if ($FORCE -and $childPattern -ne '') {
            $filtered = @($staged | Where-Object { $_ -cnotmatch $childPattern })
        } elseif ($FORCE) {
            $filtered = @()
        }
        if ($filtered.Count -gt 0) { $hasUncommitted = $true; $nonChildChanges += $filtered }
    }

    $unstaged = @()
    git diff-index --quiet HEAD -- *> $null
    if ($LASTEXITCODE -ne 0) {
        $unstaged = @(git diff --name-only 2>$null)
    }
    if ($unstaged.Count -gt 0) {
        $filtered2 = $unstaged
        if ($FORCE -and $childPattern -ne '') {
            $filtered2 = @($unstaged | Where-Object { $_ -cnotmatch $childPattern })
        } elseif ($FORCE) {
            $filtered2 = @()
        }
        if ($filtered2.Count -gt 0) {
            $hasUncommitted = $true
            if ($nonChildChanges.Count -eq 0) { $nonChildChanges = $filtered2 } else { $nonChildChanges += $filtered2 }
        }
    }

    if ($hasUncommitted) {
        if ($JSON_MODE) {
            Write-Output '{"error": "Parent repository has uncommitted changes outside child repos. Commit or stash before running --link."}'
        } else {
            [Console]::Error.WriteLine('ERROR: Parent repository has uncommitted changes outside child repos.')
            [Console]::Error.WriteLine('Commit or stash these changes before running --link:')
            [Console]::Error.WriteLine('')
            foreach ($line in ($nonChildChanges | Select-Object -First 20)) {
                [Console]::Error.WriteLine($line)
            }
        }
        exit 1
    }
}

# --- build repo records ------------------------------------------------------

$REPO_RECORDS = @()
$DISPLAY = @()      # @{name; branch; dirty; submod; drift}
$REGISTERED = @()
$SKIPPED = @()
$ERRORS = @()

foreach ($repo_name in $CHILD_REPOS) {
    if (-not $repo_name) { continue }
    $repo_path = Join-Path $REPO_ROOT $repo_name

    $remote = Get-RemoteUrl $repo_path
    $branch = ''
    $b = @(git -C $repo_path branch --show-current 2>$null)
    if ($LASTEXITCODE -eq 0 -and $b.Count -gt 0) { $branch = [string]$b[0] }
    $dirty = Test-RepoDirty $repo_path
    $unpushed = Get-UnpushedCount $repo_path
    $submod = Test-Submodule $repo_name
    $p_sha = Get-ParentSha $repo_name
    $c_sha = Get-ChildHeadSha $repo_path
    $drift = ($p_sha -ne '' -and $c_sha -ne '' -and $p_sha -ne $c_sha)
    $has_adlc = Test-Path (Join-Path $repo_path '.adlc')

    # Per-repo record (native JSON — the bash twin shells out to python3
    # for the same quote/backslash/newline safety).
    $REPO_RECORDS += [ordered]@{
        name         = $repo_name
        path         = $repo_path
        remote       = $remote
        branch       = $branch
        dirty        = [bool]$dirty
        unpushed     = [int]$unpushed
        is_submodule = [bool]$submod
        parent_sha   = $p_sha
        child_sha    = $c_sha
        sha_drift    = [bool]$drift
        has_adlc     = [bool]$has_adlc
    }
    $DISPLAY += [ordered]@{
        name   = $repo_name
        branch = $branch
        dirty  = [bool]$dirty
        submod = [bool]$submod
        drift  = [bool]$drift
    }

    # link-mode actions
    if ($LINK_MODE) {
        if ($submod) {
            $SKIPPED += "${repo_name}: already a submodule"
            continue
        }
        if ($remote -eq '') {
            $ERRORS += "${repo_name}: no remote URL configured"
            continue
        }
        if ($remote -notmatch '^(https://|git@|ssh://)') {
            $ERRORS += "${repo_name}: remote URL scheme not allowed (use https:// or git@/ssh://)"
            continue
        }
        if (Test-TrackedInParent $repo_name) {
            if (-not $FORCE) {
                $ERRORS += "${repo_name}: tracked in parent index (use --force)"
                continue
            }
            if (-not $DRY_RUN) {
                git rm --cached $repo_name *> $null
            }
        }
        if ($DRY_RUN) {
            $REGISTERED += "${repo_name} -> ${remote} [DRY RUN]"
        } else {
            git submodule add $remote $repo_name *> $null
            if ($LASTEXITCODE -eq 0) {
                $REGISTERED += "${repo_name} -> ${remote}"
            } else {
                $ERRORS += "${repo_name}: failed to add submodule"
            }
        }
    }
}

# commit after link
if ($LINK_MODE -and (-not $DRY_RUN) -and $REGISTERED.Count -gt 0) {
    if (Test-Path .gitmodules) {
        git add .gitmodules *> $null
        git commit -m '[workspace] Register child repos as submodules' *> $null
    }
}

# --- output ------------------------------------------------------------------

if ($JSON_MODE) {
    $payload = [ordered]@{
        PARENT_REPO      = $REPO_ROOT
        PARENT_BRANCH    = $PARENT_BRANCH
        PARENT_HAS_ADLC  = [bool]$PARENT_HAS_ADLC
        MODE             = $MODE
        DRY_RUN          = [bool]$DRY_RUN
        DISCOVERED_COUNT = $CHILD_REPOS.Count
        REGISTERED_COUNT = $REGISTERED.Count
        SKIPPED_COUNT    = $SKIPPED.Count
        ERROR_COUNT      = $ERRORS.Count
        REPOS            = @($REPO_RECORDS)
        ERRORS           = @($ERRORS)
    }
    Write-Output ($payload | ConvertTo-Json -Depth 10)
} else {
    Write-Output '=========================================='
    $title = switch ($MODE) {
        'link'   { 'Workspace Link (Submodule Setup)' }
        'status' { 'Workspace Status' }
        default  { 'Workspace Discovery' }
    }
    Write-Output $title
    Write-Output '=========================================='
    Write-Output "Parent: $REPO_ROOT"
    Write-Output "Branch: $PARENT_BRANCH"
    # lowercase true/false — bash boolean parity
    $adlcLabel = if ($PARENT_HAS_ADLC) { 'true' } else { 'false' }
    Write-Output "Has .adlc: $adlcLabel"
    Write-Output ''

    if ($CHILD_REPOS.Count -eq 0) {
        Write-Output 'No child repositories found at depth 1.'
        exit 0
    }

    Write-Output "Discovered ($($CHILD_REPOS.Count)):"
    foreach ($d in $DISPLAY) {
        $marker = if ($d.submod) { '*' } else { ' ' }
        $status = 'clean'
        if ($d.dirty) { $status = 'dirty' }
        if ($d.drift) { $status = "${status}+drift" }
        Write-Output "  $marker $($d.name) [$($d.branch)] $status"
    }
    Write-Output ''
    Write-Output 'Legend:  * = submodule registered,  +drift = parent SHA != child HEAD'

    if ($LINK_MODE) {
        Write-Output ''
        if ($REGISTERED.Count -gt 0) {
            Write-Output "Registered ($($REGISTERED.Count)):"
            foreach ($r in $REGISTERED) { Write-Output "  + $r" }
        }
        if ($SKIPPED.Count -gt 0) {
            Write-Output "Skipped ($($SKIPPED.Count)):"
            foreach ($r in $SKIPPED) { Write-Output "  - $r" }
        }
        if ($ERRORS.Count -gt 0) {
            Write-Output "Errors ($($ERRORS.Count)):"
            foreach ($r in $ERRORS) { Write-Output "  ! $r" }
        }
        if ((-not $DRY_RUN) -and $REGISTERED.Count -gt 0) {
            Write-Output ''
            Write-Output 'Next steps:'
            Write-Output '  - Team members can clone with: git clone --recursive <workspace-url>'
            Write-Output '  - Or initialize submodules: git submodule update --init'
        }
    }
}
