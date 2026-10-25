# mermaid-lint.ps1 — Mermaid syntax validator (the mermaid detection pass) —
# flag + suggest, never write. PowerShell twin of bash/mermaid-lint.sh; one
# behavior, two platform scripts; keep in lockstep.
#
# Scans a markdown artifact for ```mermaid fenced blocks and reports one
# finding per broken block: location (file + line + fence index), severity,
# the rule violated, the offending line, and a minimal suggested patch.
#
# Read-only by contract (the lifecycle write scope): this script never
# writes, moves or reformats an artifact. Remediation stays with
# implement/human.
#
# Severity (the mermaid detection pass):
#   HIGH   = syntax-break — the block cannot render
#   MEDIUM = style         — renderable but non-mandated form, a body that
#                            carries no statement at all, or a type this rule
#                            set cannot vouch for (never a false HIGH)
#
# Comments and directives:
#   `%% …` is a mermaid comment and `%%{ … }%%` is a mermaid directive. Both
#   are legal anywhere inside a block and carry no diagram content — mermaid
#   strips them before it parses the block. This validator therefore skips
#   them wherever it reads a block: they are never the block's type
#   declaration and never one of its statements.
#
# Usage:
#   mermaid-lint.ps1 [--tsv] <file> [file...]
#
# Output:
#   default — one readable block per finding (severity, rule, location,
#             offending line, suggested patch)
#   --tsv  — one tab-separated line per finding, for machine consumption:
#             severity \t rule \t file \t line \t fence \t message \t
#             offending \t suggestion
#             (no JSON: this script builds no JSON by hand, and pulls in no
#             runtime dependency — runtime independence)
#
# Exit codes:
#   0 = no findings
#   1 = at least one HIGH (syntax-break) finding
#   2 = only MEDIUM (style) findings
#   3 = usage error (missing file)

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Show-Help {
    Write-Output @'
Mermaid syntax validator (the mermaid detection pass) — flag + suggest, never write.

Scans a markdown artifact for ```mermaid fenced blocks and reports one
finding per broken block: location (file + line + fence index), severity,
the rule violated, the offending line, and a minimal suggested patch.

Usage:
  mermaid-lint.ps1 [--tsv] <file> [file...]

Output:
  default — one readable block per finding (severity, rule, location,
            offending line, suggested patch)
  --tsv  — one tab-separated line per finding, for machine consumption:
            severity <TAB> rule <TAB> file <TAB> line <TAB> fence <TAB> message <TAB>
            offending <TAB> suggestion
            (no JSON: this script builds no JSON by hand, and pulls in no
            runtime dependency — runtime independence)

Exit codes:
  0 = no findings
  1 = at least one HIGH (syntax-break) finding
  2 = only MEDIUM (style) findings
  3 = usage error (missing file)
'@
}

$TSV = $false
$FILES = [System.Collections.Generic.List[string]]::new()
foreach ($arg in $args) {
    switch ([string]$arg) {
        '--tsv' { $TSV = $true }
        '--help' { Show-Help; exit 0 }
        '-h' { Show-Help; exit 0 }
        default {
            if ([string]$arg -like '-*') {
                [Console]::Error.WriteLine("mermaid-lint: unknown option '$arg'")
                exit 3
            }
            $FILES.Add([string]$arg)
        }
    }
}

if ($FILES.Count -eq 0) {
    [Console]::Error.WriteLine('Usage: mermaid-lint.ps1 [--tsv] <file> [file...]')
    exit 3
}

# ── rule tables ────────────────────────────────────────────────────────────
# Known mermaid diagram keywords. A block whose first content line is not in
# this set is MEDIUM (unknown-but-plausible -> review prompt), never HIGH.
# `flow` and `chart` are NOT keywords: mermaid spells it `flowchart` (one
# word) or the legacy `graph`. A block opening with `chart TD` (or
# `flow chart TD`) therefore falls through to the MEDIUM M002 branch.
$KNOWN_TYPES = ' flowchart graph gantt journey erDiagram sequenceDiagram classDiagram stateDiagram stateDiagram-v2 pie mindmap timeline quadrantChart gitGraph requirementDiagram C4Context C4Container C4Component C4Dynamic C4Deployment zenuml block-beta sankey-beta packet-beta kanban architecture-beta xychart-beta treemap-beta radar-beta '

# The product mandate (product-implement) requires `flowchart`, not `graph`.
# `graph` still renders, so it is a style finding, not a syntax break.
$MANDATED_FLOWCHART_TYPES = ' flowchart graph '

# gantt statements that are structurally meaningful.
$GANTT_KEYS = ' dateFormat axisFormat excludes includes section todayMarker tickInterval weekday weekend title '

# A gantt task line: "<name> : <id>, <start>[, <end|duration>]". The
# `dateFormat` key is optional in mermaid, so a task line is a valid first
# statement — recognised separately from the keys above.
$GANTT_TASK_RE = '^[^:]+:[^,]+,\s*[^,]+'

# A task-line-shaped statement that is not a complete task line ("<name> :"
# with no id/start): ambiguous, so it is reported MEDIUM, never a false HIGH.
$GANTT_TASK_LOOSE_RE = '^[^:]+:'

# sequenceDiagram statement heads.
#
# The keyword table must track mermaid's own grammar, not an impression of it:
# every head here was checked against `mermaid.parse()` (12.2.0) as a first
# statement. `title`, `autonumber`, `box`, `critical` and `break` are
# documented statements mermaid accepts, so leaving them out turned valid
# blocks into HIGH findings. `done` is deliberately absent — mermaid rejects
# it as a first statement.
$SEQ_KEYS = ' participant actor boundary control entity database collections queue alt else opt loop par and rect activate deactivate note link links over right left of title autonumber box critical break end '

$script:HIGH = 0
$script:MEDIUM = 0
$script:FINDINGS = 0

# Collapse tabs and newlines so a field can never break the line format.
function Flatten([string]$S) {
    return ((($S -replace "[`r`n`t]", ' ') -replace ' {2,}', ' ').Trim())
}

# emit <severity> <rule> <file> <line> <fence_index> <message> <offending> <patch>
# Writes to the console stream (not the pipeline) so the caller's return
# value stays a clean status code.
function Emit {
    param([string]$Sev, [string]$Rule, [string]$File, [string]$Line, [string]$Idx,
          [string]$Msg, [string]$Offending, [string]$Patch)
    $script:FINDINGS++
    if ($Sev -eq 'HIGH') { $script:HIGH++ } else { $script:MEDIUM++ }
    if ($TSV) {
        [Console]::Out.WriteLine(($Sev, $Rule, (Flatten $File), $Line, $Idx, (Flatten $Msg), (Flatten $Offending), (Flatten $Patch)) -join "`t")
    } else {
        [Console]::Out.WriteLine(('{0}  {1}  {2}:{3} (fence #{4})' -f $Sev, $Rule, $File, $Line, $Idx))
        [Console]::Out.WriteLine(('      {0}' -f $Msg))
        [Console]::Out.WriteLine(('      offending: {0}' -f $Offending))
        [Console]::Out.WriteLine(('      suggestion: {0}' -f $Patch))
    }
}

# A known keyword check: " word " membership in a space-delimited table.
function Test-Word([string]$Table, [string]$Word) {
    return (' ' + $Table + ' ').Contains(' ' + $Word + ' ')
}

# The first whitespace-delimited token of a line, leading whitespace ignored.
function Get-FirstWord([string]$Line) {
    $t = $Line.TrimStart()
    if ($t -eq '') { return '' }
    return ($t -split '\s+')[0]
}

# Is this line a mermaid comment (`%% …`) or directive (`%%{ … }%%`)?
# The check is on the line's first non-space content: only a line whose own
# first non-space characters are `%%` is a comment. A `%%` *inside* a
# statement (`A --> B %% note`) is not a comment — mermaid rejects that form
# (it is a parse error, not a trailing comment). This rule set does not
# model it: such a line is still read as a statement, and no rule is raised
# for it here.
function Test-Comment([string]$Line) {
    return $Line.TrimStart().StartsWith('%%')
}

function Lint-File {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        [Console]::Error.WriteLine("mermaid-lint: file not found: $File")
        return 1
    }

    $lineno = 0; $fenceIndex = 0; $inBlock = $false
    $blockStart = 0; $blockHeader = ''; $blockHeaderLine = 0
    # content_lines counts only the lines that carry diagram content — the
    # type declaration and its statements; comment_lines counts the stripped
    # comments/directives. A block's verdict is driven by content_lines: a
    # blank line and a comment carry no content, so neither of them changes
    # the count.
    $contentLines = 0; $commentLines = 0; $bodyFirst = ''; $bodyFirstLine = 0

    foreach ($rawLine in (Get-Content -LiteralPath $File)) {
        $lineno++
        $line = [string]$rawLine

        if (-not $inBlock) {
            # Opening fence: a line whose first non-space content is ```mermaid
            if ($line.TrimStart().StartsWith('```mermaid')) {
                $inBlock = $true
                $fenceIndex++
                $blockStart = $lineno
                $blockHeader = ''; $blockHeaderLine = 0
                $contentLines = 0; $commentLines = 0
                $bodyFirst = ''; $bodyFirstLine = 0
            }
            continue
        }

        # Inside a block: a bare closing fence ends it.
        if ($line.TrimStart() -eq '```') {
            # ── classify the block that just closed ──────────────────
            if ($contentLines -eq 0) {
                # The block carries no diagram content — mermaid strips
                # comments and directives before it parses, so a block
                # holding only those is, to mermaid, an empty block: its
                # own parser refuses it with "No diagram type detected".
                # HIGH stays the honest severity (HIGH = the block cannot
                # render) — this is a real syntax break, not a false one.
                $emptyMsg = 'mermaid block has no content'
                if ($commentLines -gt 0) {
                    $emptyMsg = 'mermaid block holds only comments or directives — no diagram content to render'
                }
                Emit 'HIGH' 'M004-empty-block' $File "$blockStart" "$fenceIndex" `
                    "$emptyMsg" `
                    '```mermaid' `
                    'add the diagram body, e.g. ```mermaid / flowchart TD / A[Start] --> B[End] / ```'
            } else {
                $typeKw = Get-FirstWord $blockHeader
                if ($typeKw -eq '') {
                    Emit 'HIGH' 'M003-missing-diagram-type' $File "$blockHeaderLine" "$fenceIndex" `
                        'mermaid block declares no diagram type' `
                        "$blockHeader" `
                        'start the block with a type keyword, e.g. `flowchart TD`'
                } elseif (-not (Test-Word $KNOWN_TYPES $typeKw)) {
                    Emit 'MEDIUM' 'M002-unknown-diagram-type' $File "$blockHeaderLine" "$fenceIndex" `
                        "unrecognised diagram type '$typeKw' — not verifiable by this rule set" `
                        "$blockHeader" `
                        'confirm the type is valid mermaid; this rule set cannot vouch for it'
                } else {
                    if ((Test-Word $MANDATED_FLOWCHART_TYPES $typeKw) -and $typeKw -eq 'graph') {
                        Emit 'MEDIUM' 'M009-non-mandated-keyword' $File "$blockHeaderLine" "$fenceIndex" `
                            "'graph' renders but the product mandate requires 'flowchart'" `
                            "$blockHeader" `
                            ("use ``flowchart" + $blockHeader.Substring(5) + "`` instead")
                    }
                    if ($contentLines -le 1) {
                        # A declared type and nothing else: the block carries
                        # no statement at all. mermaid renders it (an empty
                        # chart), so it is NOT a syntax break — MEDIUM, never
                        # HIGH. The count is driven by the *content* lines,
                        # so a trailing blank line or a trailing comment
                        # cannot change the verdict.
                        Emit 'MEDIUM' 'M005-empty-body' $File "$blockHeaderLine" "$fenceIndex" `
                            "the block declares the '$typeKw' type but carries no statement" `
                            "$blockHeader" `
                            'add at least one statement for this type, e.g. `A[Start] --> B[End]`, `Task : a1, 2026-01-01, 3d`, `participant A`, `CUSTOMER ||--o{ ORDER : places`'
                    } else {
                        # A first statement exists: the per-type rules judge
                        # whether it is well-formed. A malformed first
                        # statement is a real syntax break (HIGH).
                        switch ($typeKw) {
                            'gantt' {
                                $ganttHead = Get-FirstWord $bodyFirst
                                if (Test-Word $GANTT_KEYS $ganttHead) {
                                } elseif ($bodyFirst -match $GANTT_TASK_RE) {
                                } elseif ($bodyFirst -match $GANTT_TASK_LOOSE_RE) {
                                    Emit 'MEDIUM' 'M006-malformed-gantt-header' $File "$bodyFirstLine" "$fenceIndex" `
                                        "gantt block's first statement looks like a task line but is incomplete" `
                                        "$bodyFirst" `
                                        'write the task as `<name> : <id>, <start>[, <end|duration>]`'
                                } else {
                                    Emit 'HIGH' 'M006-malformed-gantt-header' $File "$bodyFirstLine" "$fenceIndex" `
                                        "gantt block's first statement is neither a gantt key nor a task line" `
                                        "$bodyFirst" `
                                        'start with a gantt key (e.g. `dateFormat YYYY-MM-DD`) or a task line (e.g. `Task : a1, 2024-01-01, 3d`)'
                                }
                            }
                            'sequenceDiagram' {
                                $ok = $false
                                $head = Get-FirstWord $bodyFirst
                                if ((Test-Word $SEQ_KEYS $head) -or ($bodyFirst -match '^[A-Za-z0-9_]+\s*(->>|-->>|->|-->|-\)|--)')) {
                                    $ok = $true
                                }
                                if (-not $ok) {
                                    Emit 'HIGH' 'M007-malformed-sequence-diagram' $File "$bodyFirstLine" "$fenceIndex" `
                                        'sequenceDiagram block has no participant or message statement' `
                                        "$bodyFirst" `
                                        'add a participant or message, e.g. `participant A` or `A->>B: hello`'
                                }
                            }
                            'erDiagram' {
                                # A relation, an attribute block, or a bare
                                # entity list. mermaid parses a bare
                                # identifier list as isolated entities and
                                # renders it, so "the first statement is not
                                # a relation" is NOT a syntax break — that
                                # false HIGH is what made this rule
                                # untrustworthy. What genuinely breaks the
                                # parse is a name carrying characters
                                # outside mermaid's entity-name grammar.
                                if ($bodyFirst -match '[{}]|\}\||\|o|o\{|\}\|--|\.\.') {
                                    # relation / attribute block — valid
                                } elseif ($bodyFirst -match '[#@!?%():;,+=~|<>`''"]') {
                                    Emit 'HIGH' 'M008-malformed-entity-diagram' $File "$bodyFirstLine" "$fenceIndex" `
                                        'erDiagram entity name carries a character mermaid rejects' `
                                        "$bodyFirst" `
                                        'entity names take letters, digits, `_`, `-`, `.` and spaces — write a relation as `CUSTOMER ||--o{ ORDER : places`'
                                }
                            }
                        }
                    }
                }
            }
            $inBlock = $false
            continue
        }

        # Content line inside the block.
        if (Test-Comment $line) {
            # A comment (`%% …`) or a directive (`%%{ … }%%`) is not content:
            # mermaid strips it before it parses, so it is neither the
            # block's type declaration nor one of its statements.
            $commentLines++
            continue
        }
        if (($line -replace '\s', '') -ne '') {
            $contentLines++
            if ($blockHeaderLine -eq 0) {
                # First content line is the type declaration — a comment
                # ahead of it is skipped, so a leading comment never reads
                # as the diagram's type.
                $blockHeaderLine = $lineno
                $blockHeader = $line
            } elseif ($bodyFirst -eq '') {
                # First statement after the type declaration — comments in
                # between are skipped, so the first *statement* is read, not
                # the first line that happens to follow the type.
                $bodyFirst = $line
                $bodyFirstLine = $lineno
            }
        }
    }

    # ── unterminated block ───────────────────────────────────────────────
    if ($inBlock) {
        Emit 'HIGH' 'M001-fence-not-closed' $File "$blockStart" "$fenceIndex" `
            "mermaid block opened at line $blockStart is never closed" `
            '```mermaid' `
            'close the block with a bare ``` fence'
    }
    return 0
}

foreach ($f in $FILES) {
    $rc = Lint-File $f
    if ($rc -ne 0) { exit 3 }
}

if (-not $TSV) {
    if ($script:FINDINGS -eq 0) {
        Write-Output "mermaid-lint: no findings in $($FILES.Count) file(s)"
    } else {
        Write-Output "mermaid-lint: $($script:FINDINGS) finding(s) — HIGH=$($script:HIGH) MEDIUM=$($script:MEDIUM)"
    }
}

if ($script:HIGH -gt 0) { exit 1 }
if ($script:MEDIUM -gt 0) { exit 2 }
exit 0
