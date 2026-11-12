#!/usr/bin/env pwsh
# verify-recurrence.ps1 — validate factory-review verdict evidence, append live-head
# observations to the recurrence ledger (PowerShell twin of bash/verify-recurrence.sh).
# One behavior, two platform scripts; keep in lockstep.
#
# Commands:
#   run       --repo R --pr N --run-root P --ledger L [--reject-log PATH]
#   ingest    --repo R --pr N --run-root P            (diagnostic, no writes)
#   aggregate --ledger L --candidates F --fixture-payloads D --repo R --pr N --run-root P --allow-fixture
#   retire    --ledger L --key K --reason R            (explicit human resolution)
#   recurrence-view --ledger L
#
# Exit codes: 0 = completed (validation rejections are rows, not failures).
# 2 = infra error (lock-held, fetch failed, fixture misuse, provenance abort).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

$script:LedgerHeader = "PR`tpass`tcheck-item`tverdict-head`trun`titer`tauthor`tassoc`tverified-how`tverified-at`tstanding`ttier`tnote"
$script:LockTimeoutSec = 60
if ($env:VERIFY_RECURRENCE_LOCK_TIMEOUT) {
    [int]$parsed = 0
    if ([int]::TryParse($env:VERIFY_RECURRENCE_LOCK_TIMEOUT, [ref]$parsed)) {
        $script:LockTimeoutSec = $parsed
    }
}

function Die([string]$Message) {
    [Console]::Error.WriteLine("verify-recurrence: $Message")
    exit 2
}

function Usage-Error([string]$Message) {
    [Console]::Error.WriteLine("verify-recurrence: $Message")
    exit 2
}

# UTC clock. Shells out to `date` so the deterministic `date` shim used in
# tests controls both twins; falls back to .NET when `date` is unavailable.
function Get-UtcNow {
    try {
        $out = & date -u '+%Y-%m-%dT%H:%M:%SZ' 2>$null
        if ($LASTEXITCODE -eq 0 -and $out -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') {
            return $out.Trim()
        }
    } catch { }
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Invoke-GhJson([string]$Endpoint, [string]$Label) {
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $out = & gh api $Endpoint --paginate 2> $errFile
        if ($LASTEXITCODE -ne 0) {
            $detail = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
            [Console]::Error.WriteLine("verify-recurrence: could not read $Label (gh exited $LASTEXITCODE):")
            if ($detail) { [Console]::Error.WriteLine("  $detail") }
            exit 2
        }
        return ($out -join "`n")
    } finally {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
}

# Acquire an exclusive lock on $LockPath with a timeout. Returns the open
# FileStream (caller must Close/Dispose it); exits 2 on timeout.
function Open-LedgerLock([string]$LockPath, [int]$TimeoutSec) {
    $dir = Split-Path -Parent $LockPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    while ($true) {
        try {
            return [IO.File]::Open($LockPath, [IO.FileMode]::OpenOrCreate,
                [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        } catch [IO.IOException] {
            if ([DateTime]::UtcNow -ge $deadline) {
                [Console]::Error.WriteLine('verify-recurrence: ledger lock timeout')
                exit 2
            }
            Start-Sleep -Milliseconds 100
        }
    }
}

function New-SidecarTemp([string]$SiblingPath) {
    $dir = Split-Path -Parent $SiblingPath
    if (-not $dir) { $dir = (Get-Location).Path }
    $name = [IO.Path]::GetFileName($SiblingPath) + '.tmp.' + $PID + '.' + [guid]::NewGuid().ToString('N')
    return (Join-Path $dir $name)
}

# Normalization: lower, [ _]+ -> -, strip [^a-z0-9-], trim leading/trailing -.
function Convert-NormSlug([string]$s) {
    $t = $s.ToLowerInvariant() -replace '[ _]+', '-'
    $t = $t -replace '[^a-z0-9-]', ''
    $t = $t -replace '^-+', ''
    return ($t -replace '-+$', '')
}

function Get-IsoTs([string]$s) {
    if ($s -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') { return $s }
    return '-'
}

# Layer M: verdict record from a body string. Returns hashtable
# @{state; head; run; iter}. Mirrors the jq verdict_record exactly:
# no factory-review marker -> none; marker head= present: 40-hex -> ok,
# other non-'-' head -> malformed, else unbound.
function Get-VerdictRecord([string]$body) {
    if ($body -notmatch 'factory-review:step=review') {
        return @{ state = 'none'; head = '-'; run = '-'; iter = '-' }
    }
    $first = $null
    foreach ($seg in $body.Split('<!--')) {
        if ($seg -notmatch '-->') { continue }
        $b2 = (($seg -split '-->', 2)[0] -replace '^\s+', '')
        if ($b2.StartsWith('factory-review:step=review')) { $first = $b2; break }
    }
    if ($null -eq $first) {
        return @{ state = 'none'; head = '-'; run = '-'; iter = '-' }
    }
    $h = '-'; $r = '-'; $it = '-'
    foreach ($tok in $first.Split(' ')) {
        if ($tok.StartsWith('head=')) { $h = $tok.Substring(5) }
        elseif ($tok.StartsWith('run=')) { $r = $tok.Substring(4) }
        elseif ($tok.StartsWith('iter=')) { $it = $tok.Substring(5) }
    }
    if ($h -match '^[0-9a-fA-F]{40}$') {
        return @{ state = 'ok'; head = $h; run = $r; iter = $it }
    } elseif ($h -ne '-') {
        return @{ state = 'malformed'; head = '-'; run = $r; iter = $it }
    }
    return @{ state = 'unbound'; head = '-'; run = $r; iter = $it }
}

# Marker records via gh: each line is ts`twho`tassoc`tstate`thead`trun`titer
# over comments + reviews. jq order: submitted_at // created_at, login
# gsub [^A-Za-z0-9._-], assoc gsub [^A-Za-z] (default NONE).
function Get-MarkerRecords([string]$Repo, [string]$Pr) {
    $cj = Invoke-GhJson "repos/$Repo/issues/$Pr/comments" 'the PR issue comments'
    $rj = Invoke-GhJson "repos/$Repo/pulls/$Pr/reviews" 'the PR review bodies'
    $ids = @()
    foreach ($rawStr in @($cj, $rj)) {
        if (-not $rawStr) { continue }
        try { $arr = $rawStr | ConvertFrom-Json } catch { Die 'could not read marker records (gh exited 2):' }
        if ($null -eq $arr) { continue }
        if ($arr -isnot [System.Collections.IEnumerable] -or $arr -is [string]) { $arr = @($arr) }
        foreach ($it in $arr) { $ids += $it }
    }
    $lines = @()
    foreach ($it in $ids) {
        $ts = Get-IsoTs ([string](($it.submitted_at, $it.created_at) | Where-Object { $_ } | Select-Object -First 1))
        $who = [string](($it.user.login, '') | Select-Object -First 1)
        $who = $who -replace '[^A-Za-z0-9._-]', ''
        $assoc = [string](($it.author_association, 'NONE') | Select-Object -First 1)
        $assoc = $assoc -replace '[^A-Za-z]', ''
        $rec = Get-VerdictRecord ([string](($it.body, '') | Select-Object -First 1))
        $lines += ($ts, $who, $assoc, $rec.state, $rec.head, $rec.run, $rec.iter) -join "`t"
    }
    return $lines
}

# Layer F: valid finding-line extraction. Prints raw "pass:.. check:.." spans
# (like the awk match) to stdout; malformed bullet lines to stderr.
# Throws 'FINDING-UNPARSEABLE' (message) when no valid line exists.
function Get-FindingPairs([string]$File) {
    $spans = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [IO.File]::ReadLines($File)) {
        if ($line -match '^-\s+\[[ xX]\]\s+pass:') {
            $rest = $line -replace '^-\s+\[[ xX]\]\s+', ''
            $m = [regex]::Match($rest, 'pass:[^\s|]+\s+check:[^\s|]+')
            if ($m.Success) { $spans.Add($m.Value) }
            else { [Console]::Error.WriteLine("verify-recurrence: malformed finding line: MALFORMED:$rest") }
        }
    }
    if ($spans.Count -eq 0) { throw 'FINDING-UNPARSEABLE' }
    $set = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($span in $spans) {
        $pm = [regex]::Match($span, '.*pass:([^ |]*).*')
        $cm = [regex]::Match($span, '.*check:([^ |]*).*')
        $p = Convert-NormSlug $pm.Groups[1].Value
        $c = Convert-NormSlug $cm.Groups[1].Value
        if ($p -and $c) { [void]$set.Add("$p`t$c") }
    }
    if ($set.Count -eq 0) { throw 'FINDING-UNPARSEABLE' }
    return @($set)
}

# Layer P: structured pass:/check: pairs in marker-stripped prose.
function Get-ProseStructPairs([string]$File) {
    if (-not $File -or -not (Test-Path -LiteralPath $File)) { return @() }
    $text = [IO.File]::ReadAllText($File)
    $stripped = [regex]::Replace($text, '<!--[^>]*-->', '')
    $set = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($m in [regex]::Matches($stripped, 'pass:[A-Za-z0-9_.-]+\s+check:[A-Za-z0-9_.-]+')) {
        $sm = [regex]::Match($m.Value, '.*pass:([^ ]*).*')
        $cm = [regex]::Match($m.Value, '.*check:([^ ]*).*')
        $p = Convert-NormSlug $sm.Groups[1].Value
        $c = Convert-NormSlug $cm.Groups[1].Value
        if ($p -and $c) { [void]$set.Add("$p`t$c") }
    }
    return @($set)
}

# Validates one marker record against live head + run home.
# Returns 'OK`t$mhead`t$run`t$iter`t$who`t$assoc`t$ts' or
# 'REJECT`t$mhead`t$run`t$iter`t<reason>'.
function Test-OneRecord([string]$ts, [string]$who, [string]$assoc,
    [string]$state, [string]$mhead, [string]$run, [string]$iter,
    [string]$live, [string]$Repo, [string]$Pr, [string]$RunRoot) {
    $lcLive = $live.ToLowerInvariant()
    $lcM = $mhead.ToLowerInvariant()
    if ($assoc -notin @('OWNER', 'MEMBER', 'COLLABORATOR')) {
        return "REJECT`t$mhead`t$run`t$iter`tuntrusted-author"
    }
    switch ($state) {
        'malformed' { return "REJECT`t$mhead`t$run`t$iter`tmalformed-head" }
        'unbound'   { return "REJECT`t$mhead`t$run`t$iter`tno-marker-head" }
        'none'      { return "REJECT`t$mhead`t$run`t$iter`tno-marker-head" }
    }
    if ($lcM -ne $lcLive) { return "REJECT`t$mhead`t$run`t$iter`tstale-head" }
    $brief = Join-Path $RunRoot "runs/$run/brief.md"
    if (-not (Test-Path -LiteralPath $brief)) {
        return "REJECT`t$mhead`t$run`t$iter`trun-unresolvable"
    }
    $bRepo = $null; $bPr = $null; $bHead = $null
    foreach ($bl in [IO.File]::ReadLines($brief)) {
        if ($null -eq $bRepo -and $bl -match '^review-target-repo:\s*(.*)$') { $bRepo = $Matches[1] }
        elseif ($null -eq $bPr -and $bl -match '^review-target-pr:\s*(.*)$') { $bPr = $Matches[1] }
        elseif ($null -eq $bHead -and $bl -match '^reviewed-head:\s*(.*)$') { $bHead = $Matches[1] }
    }
    if (-not $bRepo -or -not $bPr -or -not $bHead) {
        return "REJECT`t$mhead`t$run`t$iter`trun-unresolvable"
    }
    if ($bRepo -ne $Repo -or $bPr -ne $Pr) {
        return "REJECT`t$mhead`t$run`t$iter`trun-mismatch"
    }
    if ($bHead.ToLowerInvariant() -ne $lcLive) {
        return "REJECT`t$mhead`t$run`t$iter`trun-mismatch"
    }
    $findings = Join-Path $RunRoot "runs/$run/scratchpads/review-findings.txt"
    if (-not (Test-Path -LiteralPath $findings)) {
        return "REJECT`t$mhead`t$run`t$iter`tfinding-unparseable"
    }
    try { $null = Get-FindingPairs $findings }
    catch { return "REJECT`t$mhead`t$run`t$iter`tfinding-unparseable" }
    return "OK`t$mhead`t$run`t$iter`t$who`t$assoc`t$ts"
}

# Aggregate-only helper: SrcRows alternates ORIG-carrier / re-stamped rows.
function Invoke-LockedAppend([string]$Ledger, [string[]]$SrcRows,
    [string]$Cmd, [string]$StartedSentinel, [string]$ProceedSentinel) {
    if (-not (Test-Path -LiteralPath $Ledger)) {
        [IO.File]::WriteAllText($Ledger, $script:LedgerHeader + "`n")
    }
    $lock = Open-LedgerLock ($Ledger + '.lock') $script:LockTimeoutSec
    try {
        if ($Cmd -eq 'aggregate' -and $StartedSentinel) {
            [IO.File]::WriteAllText($StartedSentinel, '')
        }
        if ($Cmd -eq 'aggregate' -and $ProceedSentinel) {
            $deadline = [DateTime]::UtcNow.AddSeconds(60)
            while (-not (Test-Path -LiteralPath $ProceedSentinel)) {
                if ([DateTime]::UtcNow -ge $deadline) {
                    return @{ outcome = @(); conflict = ''; error = 'proceed sentinel not observed' }
                }
                Start-Sleep -Milliseconds 50
            }
        }
        $cur = New-SidecarTemp $Ledger
        try { Copy-Item -LiteralPath $Ledger -Destination $cur -Force }
        catch { return @{ outcome = @(); conflict = ''; error = 'ledger read error during idempotency check' } }
        try {
            $curLines = [IO.File]::ReadAllLines($cur)
        } catch {
            Remove-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
            return @{ outcome = @(); conflict = ''; error = 'ledger read error during idempotency check' }
        }
        $outcome = @()
        $conflict = ''
        $pendOrig = $null
        $have = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($l in $curLines) { [void]$have.Add($l) }
        foreach ($row in $SrcRows) {
            if (-not $row) { continue }
            if ($row.StartsWith('ORIG' + "`t")) {
                $pendOrig = $row.Substring(5)
                continue
            }
            if ($null -ne $pendOrig) {
                $orig = $pendOrig; $pendOrig = $null
                if ($have.Contains($orig)) {
                    $outcome += "DUPLICATE`t$orig"
                    continue
                }
            }
            $cols = $row.Split("`t")
            $pkey = @($cols[0], $cols[1], $cols[2], $cols[5]) -join "`t"
            if ($have.Contains($row)) {
                $outcome += "DUPLICATE`t$row"
                continue
            }
            $provConflict = $false
            foreach ($l in $curLines) {
                if ($l.StartsWith('PR' + "`t")) { continue }
                $c = $l.Split("`t")
                if ($c.Count -lt 6) { continue }
                if ((@($c[0], $c[1], $c[2], $c[5]) -join "`t") -eq $pkey) {
                    $provConflict = $true
                    break
                }
            }
            if ($provConflict) { $conflict = $pkey; break }
            $curLines += $row
            [void]$have.Add($row)
            $outcome += "APPENDED`t$row"
        }
        if ($conflict) {
            Remove-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
            return @{ outcome = $outcome; conflict = $conflict; error = '' }
        }
        [IO.File]::WriteAllLines($cur, $curLines)
        Move-Item -LiteralPath $cur -Destination $Ledger -Force
        return @{ outcome = $outcome; conflict = ''; error = '' }
    } finally {
        $lock.Close(); $lock.Dispose()
    }
}

# cmd run / ingest.
function Invoke-IngestOrRun([string]$Mode, [string]$Repo, [string]$Pr,
    [string]$RunRoot, [string]$Ledger, [string]$RejectLog) {
    $prj = Invoke-GhJson "repos/$Repo/pulls/$Pr" 'the PR'
    $live = ''
    try { $live = (($prj | ConvertFrom-Json).head.sha) } catch { $live = '' }
    if ($live -notmatch '^[0-9a-fA-F]{40}$') {
        [Console]::Error.WriteLine('verify-recurrence: live PR head unreadable')
        exit 2
    }
    $live = ([string]$live).Split("`n")[0].Trim()
    $verifiedAt = Get-UtcNow
    $records = Get-MarkerRecords $Repo $Pr
    # Newest qualifying collaborator verdict for the live head
    # (bash awk: first record wins ties; '-' ts never beats a real ts).
    $best = $null
    foreach ($r in $records) {
        $f = $r.Split("`t")
        if ($f.Count -lt 7) { continue }
        if ($f[3] -ne 'ok') { continue }
        if ($f[2] -notin @('OWNER', 'MEMBER', 'COLLABORATOR')) { continue }
        if ($f[4].ToLowerInvariant() -ne $live.ToLowerInvariant()) { continue }
        if ($null -eq $best) { $best = $f; continue }
        if ($f[0] -ne '-' -and ($best[0] -eq '-' -or $f[0] -gt $best[0])) { $best = $f }
    }
    $rej = @()
    foreach ($r in $records) {
        $f = $r.Split("`t")
        if ($f.Count -lt 7 -or -not $f[0]) { continue }
        $v = Test-OneRecord $f[0] $f[1] $f[2] $f[3] $f[4] $f[5] $f[6] $live $Repo $Pr $RunRoot
        if ($v.StartsWith('REJECT')) {
            $rf = $v.Split("`t")
            $rej += "REJECT`t$Pr`t$($rf[1])`t$($rf[2])`t-`t-`t-`t-`t-`t$($rf[4])"
        }
        $lcM = $f[4].ToLowerInvariant(); $lcL = $live.ToLowerInvariant()
        if ($lcM -ne $lcL -and $f[3] -eq 'ok') {
            $rej += "REJECT`t$Pr`t$($f[4])`t$($f[5])`t-`t-`t-`t-`t-`thead-interval-unproven"
        }
    }
    $candRows = @()
    if ($null -ne $best) {
        $v = Test-OneRecord $best[0] $best[1] $best[2] $best[3] $best[4] $best[5] $best[6] $live $Repo $Pr $RunRoot
        if ($v.StartsWith('OK')) {
            $vf = $v.Split("`t")
            try { $pairs = Get-FindingPairs (Join-Path $RunRoot "runs/$($best[5])/scratchpads/review-findings.txt") }
            catch { $pairs = @() }
            foreach ($pp in $pairs) {
                $pc = $pp.Split("`t")
                $candRows += ($Pr, $pc[0], $pc[1], $vf[1].ToLowerInvariant(), $vf[2], $vf[3], $vf[4], $vf[5],
                    'live-head', $verifiedAt, 'live-head-at-verification', '', "verified live-head $($vf[1])") -join "`t"
            }
            # Layer P divergence: structured prose pairs with no Layer F
            # match are rejected; only those candidate rows are dropped.
            $proseFile = [IO.Path]::GetTempFileName()
            try {
                $cj2 = Invoke-GhJson "repos/$Repo/issues/$Pr/comments" 'the PR issue comments'
                $rj2 = Invoke-GhJson "repos/$Repo/pulls/$Pr/reviews" 'the PR review bodies'
                $bodies = @()
                foreach ($rawStr in @($cj2, $rj2)) {
                    if (-not $rawStr) { continue }
                    try { $arr = $rawStr | ConvertFrom-Json } catch { $arr = @() }
                    foreach ($it in $arr) { $bodies += [string](($it.body, '') | Select-Object -First 1) }
                }
                [IO.File]::WriteAllText($proseFile, ($bodies -join "`n"))
                $pp2 = Get-ProseStructPairs $proseFile
            } finally {
                Remove-Item -LiteralPath $proseFile -Force -ErrorAction SilentlyContinue
            }
            $div = @()
            foreach ($q in $pp2) {
                if ($pairs -notcontains $q) { $div += $q }
            }
            foreach ($d in $div) {
                $dc = $d.Split("`t")
                $rej += "REJECT`t$Pr`t$($vf[1])`t$($vf[2])`t$($dc[0])`t$($dc[1])`t-`t-`t-`tfinding-diverged"
            }
            if ($div.Count -gt 0) {
                $divKeys = @{}
                foreach ($d in $div) { $divKeys[('DIV' + "`t" + $d)] = $true }
                $candRows = @($candRows | Where-Object {
                    $cc = $_.Split("`t")
                    -not $divKeys.ContainsKey(('DIV' + "`t" + $cc[1] + "`t" + $cc[2]))
                })
            }
        } else {
            $rf2 = $v.Split("`t")
            $rej += "REJECT`t$Pr`t$($best[4])`t$($best[5])`t-`t-`t-`t-`t-`t$($rf2[4])"
        }
    }
    if ($Mode -eq 'ingest') {
        Write-Output '--- candidates (untrusted worklist, never production evidence) ---'
        foreach ($c in $candRows) { Write-Output $c }
        Write-Output '--- rejects ---'
        foreach ($r in $rej) { Write-Output $r }
        return
    }
    # run: locked idempotent append; DUPLICATE re-reports the same row.
    if (-not (Test-Path -LiteralPath $Ledger)) {
        [IO.File]::WriteAllText($Ledger, $script:LedgerHeader + "`n")
    }
    $dupOut = New-SidecarTemp ($Ledger + '.dup')
    try { [IO.File]::WriteAllText($dupOut, '') } catch { Die 'cannot create temp file' }
    $lock = Open-LedgerLock ($Ledger + '.lock') $script:LockTimeoutSec
    try {
        $cur = New-SidecarTemp $Ledger
        try { Copy-Item -LiteralPath $Ledger -Destination $cur -Force }
        catch { Die 'cannot create temp file' }
        $curLines = [IO.File]::ReadAllLines($cur)
        $have = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($l in $curLines) { [void]$have.Add($l) }
        $conflict = ''
        $dupLines = @()
        foreach ($row in $candRows) {
            if (-not $row) { continue }
            $cols = $row.Split("`t")
            $pkey = @($cols[0], $cols[1], $cols[2], $cols[5]) -join "`t"
            if ($have.Contains($row)) { $dupLines += "DUPLICATE`t$row"; continue }
            # Rerun-idempotency: identity is (key + provenance, head
            # case-folded); verified-at is metadata. Other differences
            # on the same key fail closed.
            $idem = @()
            for ($i = 1; $i -lt $curLines.Count; $i++) {
                $c = $curLines[$i].Split("`t")
                if ($c.Count -lt 6) { continue }
                if ((@($c[0], $c[1], $c[2], $c[5]) -join "`t") -eq $pkey) {
                    $idem += (@($c[3].ToLowerInvariant(), $c[4]) + @($c[6], $c[7], $c[8]) + @($c[10], $c[11]) + @($c[12])) -join "`t"
                }
            }
            if ($idem.Count -gt 0) {
                $rp = (@($cols[3].ToLowerInvariant(), $cols[4]) + @($cols[6], $cols[7], $cols[8]) + @($cols[10], $cols[11]) + @($cols[12])) -join "`t"
                $match = $false
                foreach ($e in $idem) { if ($e -ceq $rp) { $match = $true; break } }
                if ($match) { $dupLines += "DUPLICATE`t$row"; continue }
                [Console]::Error.WriteLine("verify-recurrence: provenance conflict for $pkey; use retire")
                $conflict = $pkey
                break
            }
            $curLines += $row
            [void]$have.Add($row)
        }
        if ($conflict) {
            Remove-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $dupOut -Force -ErrorAction SilentlyContinue
            $lock.Close(); $lock.Dispose()
            exit 2
        }
        [IO.File]::WriteAllLines($cur, $curLines)
        Move-Item -LiteralPath $cur -Destination $Ledger -Force
    } finally {
        $lock.Close(); $lock.Dispose()
    }
    if ($dupLines.Count -gt 0) {
        [IO.File]::WriteAllLines($dupOut, $dupLines)
        Write-Output '--- duplicates (re-confirmed, ledger unchanged) ---'
        foreach ($d in $dupLines) { Write-Output $d }
    } else {
        Remove-Item -LiteralPath $dupOut -Force -ErrorAction SilentlyContinue
    }
    foreach ($c in $candRows) { Write-Output $c }
    Write-Output '--- rejects ---'
    foreach ($r in $rej) { Write-Output $r }
    if ($RejectLog) { [IO.File]::WriteAllLines($RejectLog, $rej) }
}

# cmd aggregate (fixture-only).
function Invoke-Aggregate([string]$Ledger, [string]$Candidates,
    [string]$FixturePayloads, [string]$Repo, [string]$Pr, [string]$RunRoot,
    [string]$StartedSentinel, [string]$ProceedSentinel) {
    if (-not (Test-Path -LiteralPath $Candidates)) { Usage-Error 'candidates file not found' }
    if (-not (Test-Path -LiteralPath $FixturePayloads -PathType Container)) {
        Usage-Error 'fixture payload dir not found (--fixture-payloads)'
    }
    foreach ($f in @('pr.json', 'comments.json', 'reviews.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $FixturePayloads $f))) {
            Usage-Error "fixture payload missing: $f"
        }
    }
    try {
        $flive = (((Get-Content -LiteralPath (Join-Path $FixturePayloads 'pr.json') -Raw) | ConvertFrom-Json).head.sha)
    } catch { $flive = '' }
    $flive = ([string]$flive).Split("`n")[0].Trim()
    if ($flive -notmatch '^[0-9a-fA-F]{40}$') {
        [Console]::Error.WriteLine('verify-recurrence: fixture pr.json has no head.sha')
        exit 2
    }
    $fverifiedAt = Get-UtcNow
    $frecords = @()
    try {
        $cj = Get-Content -LiteralPath (Join-Path $FixturePayloads 'comments.json') -Raw
        $rj = Get-Content -LiteralPath (Join-Path $FixturePayloads 'reviews.json') -Raw
        foreach ($rawStr in @($cj, $rj)) {
            if (-not $rawStr) { continue }
            $arr = $rawStr | ConvertFrom-Json
            foreach ($it in $arr) {
                $ts = Get-IsoTs ([string](($it.submitted_at, $it.created_at) | Where-Object { $_ } | Select-Object -First 1))
                $who = ([string](($it.user.login, '') | Select-Object -First 1)) -replace '[^A-Za-z0-9._-]', ''
                $assoc = ([string](($it.author_association, 'NONE') | Select-Object -First 1)) -replace '[^A-Za-z]', ''
                $rec = Get-VerdictRecord ([string](($it.body, '') | Select-Object -First 1))
                $frecords += ($ts, $who, $assoc, $rec.state, $rec.head, $rec.run, $rec.iter) -join "`t"
            }
        }
    } catch {
        [Console]::Error.WriteLine('verify-recurrence: cannot parse fixture payloads')
        exit 2
    }
    $fprose = [IO.Path]::GetTempFileName()
    try {
        $pb = @()
        foreach ($rawStr in @($cj, $rj)) {
            if (-not $rawStr) { continue }
            try { $arr = $rawStr | ConvertFrom-Json } catch { continue }
            foreach ($it in $arr) { $pb += [string](($it.body, '') | Select-Object -First 1) }
        }
        [IO.File]::WriteAllText($fprose, ($pb -join "`n"))
    } catch { }
    $validRows = @()
    $candLines = [IO.File]::ReadAllLines($Candidates)
    foreach ($row in $candLines) {
        if (-not $row -or $row.StartsWith('PR' + "`t")) { continue }
        $cc = $row.Split("`t")
        if ($cc.Count -lt 9) { Write-Output "REJECT`tcandidate-mismatch`t$row"; continue }
        $cPr = $cc[0]; $cPass = $cc[1]; $cCheck = $cc[2]; $cHead = $cc[3]
        $cRun = $cc[4]; $cIter = $cc[5]; $cHow = $cc[8]
        if ($cHead.ToLowerInvariant() -ne $flive.ToLowerInvariant() -or $cHow -ne 'live-head') {
            Write-Output "REJECT`tcandidate-mismatch`t$row"; continue
        }
        if ($cPr -ne $Pr) { Write-Output "REJECT`tcandidate-mismatch`t$row"; continue }
        $hit = $false
        foreach ($fr in $frecords) {
            $f = $fr.Split("`t")
            if ($f[3] -eq 'ok' -and $f[2] -in @('OWNER', 'MEMBER', 'COLLABORATOR') -and
                $f[4].ToLowerInvariant() -eq $cHead.ToLowerInvariant() -and
                $f[5] -eq $cRun -and $f[6] -eq $cIter) { $hit = $true; break }
        }
        if (-not $hit) { Write-Output "REJECT`tcandidate-mismatch`t$row"; continue }
        $brief = Join-Path $RunRoot "runs/$cRun/brief.md"
        $bRepo = $null; $bPr = $null; $bHead = $null
        if (Test-Path -LiteralPath $brief) {
            foreach ($bl in [IO.File]::ReadLines($brief)) {
                if ($null -eq $bRepo -and $bl -match '^review-target-repo:\s*(.*)$') { $bRepo = $Matches[1] }
                elseif ($null -eq $bPr -and $bl -match '^review-target-pr:\s*(.*)$') { $bPr = $Matches[1] }
                elseif ($null -eq $bHead -and $bl -match '^reviewed-head:\s*(.*)$') { $bHead = $Matches[1] }
            }
        }
        if (-not $bRepo -or -not $bPr -or (-not $bHead) -or
            $bHead.ToLowerInvariant() -ne $flive.ToLowerInvariant()) {
            Write-Output "REJECT`tcandidate-mismatch`t$row"; continue
        }
        $fp = @()
        try { $fp = Get-FindingPairs (Join-Path $RunRoot "runs/$cRun/scratchpads/review-findings.txt") }
        catch { Write-Output "REJECT`tcandidate-mismatch`t$row"; continue }
        $want = "$cPass`t$cCheck"
        if ($fp -notcontains $want) { Write-Output "REJECT`tcandidate-mismatch`t$row"; continue }
        $pp3 = Get-ProseStructPairs $fprose
        $div = $false
        foreach ($q in $pp3) { if ($fp -notcontains $q) { $div = $true; break } }
        if ($div) { Write-Output "REJECT`tcandidate-mismatch`t$row"; continue }
        $lcH = $cHead.ToLowerInvariant()
        $validRows += 'ORIG' + "`t" + $row
        $validRows += (($cPr, $cPass, $cCheck, $lcH, $cRun, $cIter,
            $cc[6], $cc[7], 'live-head', $fverifiedAt,
            'live-head-at-verification', '', 'revalidated fixture row') -join "`t")
    }
    Remove-Item -LiteralPath $fprose -Force -ErrorAction SilentlyContinue
    if ($validRows.Count -gt 0) {
        # VALID is reported only after the locked append succeeds: capture
        # stdout, run the append, then emit. A provenance conflict aborts
        # with exit 2 and prints no success-shaped VALID.
        $res = Invoke-LockedAppend $Ledger $validRows 'aggregate' $StartedSentinel $ProceedSentinel
        if ($res.error) {
            [Console]::Error.WriteLine("verify-recurrence: $($res.error)")
            exit 2
        }
        if ($res.conflict) {
            [Console]::Error.WriteLine("verify-recurrence: provenance conflict for $($res.conflict); use retire")
            exit 2
        }
        foreach ($o in $res.outcome) {
            if ($o.StartsWith('APPENDED') -or $o.StartsWith('DUPLICATE')) {
                Write-Output ('VALID' + "`t" + $o.Substring($o.IndexOf("`t") + 1))
            }
        }
    }
    Write-Output 'aggregate fixture revalidation complete'
}

# cmd retire.
function Invoke-Retire([string]$Ledger, [string]$RetireKey, [string]$RetireReason) {
    if (-not (Test-Path -LiteralPath $Ledger)) { Usage-Error 'ledger not found' }
    $lock = Open-LedgerLock ($Ledger + '.lock') $script:LockTimeoutSec
    try {
        $lines = [IO.File]::ReadAllLines($Ledger)
        $before = @($lines | Where-Object { -not $_.StartsWith('PR' + "`t") }).Count
        $kept = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq 0) { $kept += $lines[$i]; continue }
            $c = $lines[$i].Split("`t")
            if ($c.Count -lt 6) { $kept += $lines[$i]; continue }
            if ((@($c[0], $c[1], $c[2], $c[5]) -join "`t") -ne $RetireKey) {
                $kept += $lines[$i]
            }
        }
        $after = @($kept | Where-Object { -not $_.StartsWith('PR' + "`t") }).Count
        if ($after -eq $before) {
            [Console]::Error.WriteLine("verify-recurrence: retire key not found: $RetireKey (no rows removed)")
            $lock.Close(); $lock.Dispose()
            exit 2
        }
        $tmp = New-SidecarTemp $Ledger
        [IO.File]::WriteAllLines($tmp, $kept)
        Move-Item -LiteralPath $tmp -Destination $Ledger -Force
        $removed = $before - $after
        Write-Output "retired [$RetireKey] rows=$removed reason=$RetireReason"
    } finally {
        $lock.Close(); $lock.Dispose()
    }
}

# cmd recurrence-view.
function Invoke-RecurrenceView([string]$Ledger) {
    if (-not (Test-Path -LiteralPath $Ledger)) { Usage-Error 'ledger not found' }
    $byKey = @{}
    foreach ($l in [IO.File]::ReadLines($Ledger)) {
        if ($l.StartsWith('PR' + "`t")) { continue }
        $c = $l.Split("`t")
        if ($c.Count -lt 3) { continue }
        $key = $c[1] + "`t" + $c[2]
        if (-not $byKey.ContainsKey($key)) { $byKey[$key] = @{} }
        $byKey[$key][$c[0]] = $true
    }
    $out = @()
    foreach ($k in $byKey.Keys) {
        if ($byKey[$k].Count -ge 2) {
            $out += "RECURRING`t$k`tprs:$($byKey[$k].Count)"
        }
    }
    $arr = [string[]]$out
    [Array]::Sort($arr, [System.StringComparer]::Ordinal)
    foreach ($o in $arr) { Write-Output $o }
}

# ---- argument parsing (mirrors the bash CLI) ----
$__cmd = $null
$__repo = ''; $__pr = ''; $__runRoot = ''; $__ledger = ''; $__rejectLog = ''
$__candidates = ''; $__fixturePayloads = ''; $__allowFixture = $false
$__key = ''; $__reason = ''
$__started = ''; $__proceed = ''
$__rest = @($args)
if ($__rest.Count -gt 0) { $__cmd = $__rest[0]; if ($__rest.Count -gt 1) { $__rest = $__rest[1..($__rest.Count - 1)] } else { $__rest = @() } }
switch ($__cmd) {
    'run' { }
    'ingest' { }
    'aggregate' { }
    'retire' { }
    'recurrence-view' { }
    default { Usage-Error 'usage: verify-recurrence.ps1 {run|ingest|aggregate|retire|recurrence-view} ...' }
}
$i = 0
while ($i -lt $__rest.Count) {
    $a = $__rest[$i]
    switch ($a) {
        '--repo' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--repo requires a value' }; $__repo = $__rest[$i + 1]; $i += 2 }
        '--pr' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--pr requires a value' }; $__pr = $__rest[$i + 1]; $i += 2 }
        '--run-root' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--run-root requires a value' }; $__runRoot = $__rest[$i + 1]; $i += 2 }
        '--ledger' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--ledger requires a value' }; $__ledger = $__rest[$i + 1]; $i += 2 }
        '--reject-log' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--reject-log requires a value' }; $__rejectLog = $__rest[$i + 1]; $i += 2 }
        '--candidates' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--candidates requires a value' }; $__candidates = $__rest[$i + 1]; $i += 2 }
        '--fixture-payloads' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--fixture-payloads requires a value' }; $__fixturePayloads = $__rest[$i + 1]; $i += 2 }
        '--started-sentinel' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--started-sentinel requires a value' }; $__started = $__rest[$i + 1]; $i += 2 }
        '--proceed-sentinel' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--proceed-sentinel requires a value' }; $__proceed = $__rest[$i + 1]; $i += 2 }
        '--key' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--key requires a value' }; $__key = $__rest[$i + 1]; $i += 2 }
        '--reason' { if ($i + 1 -ge $__rest.Count) { Usage-Error '--reason requires a value' }; $__reason = $__rest[$i + 1]; $i += 2 }
        '--allow-fixture' { $__allowFixture = $true; $i += 1 }
        '--help' { Write-Output 'verify-recurrence.ps1 — validate factory-review verdict evidence, append live-head observations to the recurrence ledger.'; Write-Output 'usage: verify-recurrence.ps1 {run|ingest|aggregate|retire|recurrence-view} ...'; exit 0 }
        '-h' { Write-Output 'usage: verify-recurrence.ps1 {run|ingest|aggregate|retire|recurrence-view} ...'; exit 0 }
        '--fixture-comments' { Usage-Error '--fixture-comments was removed; use --fixture-payloads <dir> with aggregate --allow-fixture' }
        '--fixture-reviews' { Usage-Error '--fixture-reviews was removed; use --fixture-payloads <dir> with aggregate --allow-fixture' }
        '--fixture-pr' { Usage-Error '--fixture-pr was removed; use --fixture-payloads <dir> with aggregate --allow-fixture' }
        default { Usage-Error "unknown argument '$a'" }
    }
}

switch ($__cmd) {
    'run' {
        if (-not $__repo) { Usage-Error '--repo required for run' }
        if (-not $__pr) { Usage-Error '--pr required for run' }
        if (-not $__runRoot) { Usage-Error '--run-root required for run' }
        if (-not $__ledger) { Usage-Error '--ledger required for run' }
        Invoke-IngestOrRun 'run' $__repo $__pr $__runRoot $__ledger $__rejectLog
    }
    'ingest' {
        if (-not $__repo) { Usage-Error '--repo required for ingest' }
        if (-not $__pr) { Usage-Error '--pr required for ingest' }
        if (-not $__runRoot) { Usage-Error '--run-root required for ingest' }
        Invoke-IngestOrRun 'ingest' $__repo $__pr $__runRoot '' ''
    }
    'aggregate' {
        if (-not $__allowFixture) { Usage-Error 'aggregate is fixture-only; pass --allow-fixture' }
        if (-not $__ledger) { Usage-Error '--ledger required for aggregate' }
        if (-not $__candidates) { Usage-Error '--candidates required for aggregate' }
        if (-not $__fixturePayloads) { Usage-Error '--fixture-payloads <dir> required for aggregate' }
        if (-not $__repo) { Usage-Error '--repo required for aggregate' }
        if (-not $__pr) { Usage-Error '--pr required for aggregate' }
        if (-not $__runRoot) { Usage-Error '--run-root required for aggregate' }
        Invoke-Aggregate $__ledger $__candidates $__fixturePayloads $__repo $__pr $__runRoot $__started $__proceed
    }
    'retire' {
        if (-not $__ledger) { Usage-Error '--ledger required for retire' }
        if (-not $__key) { Usage-Error '--key required for retire' }
        if (($__key.Split("`t")).Count -ne 4) { Usage-Error '--key must be TAB-separated PR,pass,check-item,iter' }
        if (-not $__reason) { Usage-Error '--reason required for retire' }
        Invoke-Retire $__ledger $__key $__reason
    }
    'recurrence-view' {
        if (-not $__ledger) { Usage-Error '--ledger required for recurrence-view' }
        Invoke-RecurrenceView $__ledger
    }
}

