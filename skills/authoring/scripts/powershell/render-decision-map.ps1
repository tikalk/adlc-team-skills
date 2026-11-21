function Trunc-Field {
    param([string]$Value, [int]$Max)
    if ($Value.Length -gt $Max) { return $Value.Substring(0, $Max - 1) + [char]0x2026 }
    return $Value
}

function Write-Bar {
    '+' + ('-' * 73) + '+'
}

function Write-Row {
    param([string]$Label, [string]$Value)
    $avail = 75 - $Label.Length - 6
    $Value = Trunc-Field $Value $avail
    '| {0}: {1} |' -f $Label, $Value.PadRight($avail)
}

function Render-StatusBox {
    param([string]$Id, [string]$Title, [string]$Gap)
    Write-Bar
    Write-Row "CLARIFICATION" "$Id - $Title"
    Write-Bar
    Write-Row "Gap" $Gap
    Write-Row "Ask" "Choose an option for $Id."
    Write-Bar
}

function Render-DecisionMap {
    param(
        [string]$Id,
        [string]$Title,
        [string]$WhatWhy,
        [string]$Boundaries,
        [string]$Reach,
        [string[]]$Options,
        [string]$IfUndecided
    )
    Write-Bar
    Write-Row "DECISION MAP" "$Id - $Title"
    Write-Row "WHAT/WHY" $WhatWhy
    Write-Row "BOUNDARIES" $Boundaries
    Write-Bar
    '| {0} |' -f "REACH FAN-OUT:".PadRight(71)
    foreach ($pair in ($Reach -split ';')) {
        if ($pair -match '^(.*?)=(.*)$') { $key = $Matches[1]; $val = $Matches[2] }
        else { $key = $pair; $val = '?' }
        '|   +-[{0}] --> {1} |' -f $key.PadRight(8).Substring(0,8), (Trunc-Field $val 51).PadRight(51)
    }
    Write-Bar
    '| {0} |' -f "CANDIDATES & TRADEOFFS:".PadRight(71)
    '| {0} |' -f "".PadRight(71)
    foreach ($opt in $Options) {
        $f = $opt -split '\|', 8
        '| Option {0}: {1} |' -f $f[0], (Trunc-Field $f[1] 61).PadRight(61)
        '|   {0} {1} |' -f $f[2], (Trunc-Field $f[3] 67).PadRight(67)
        '|   {0} {1} |' -f $f[4], (Trunc-Field $f[5] 67).PadRight(67)
        '|   {0} Cross-boundary:{1}|' -f $f[6], (' ' + (Trunc-Field $f[7] 52)).PadRight(53)
        '| {0} |' -f "".PadRight(71)
    }
    Write-Bar
    Write-Row "IF-UNDECIDED" $IfUndecided
    Write-Bar
}
