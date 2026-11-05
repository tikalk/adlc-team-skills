# paths.ps1 — shared layout constants (single definition).
#
# Dot-sourced, never executed. PowerShell mirror of paths.sh: defines the
# .adlc/ + docs/adlc/ path roots and the R7 gitignore allowlist consumed by
# the setup scripts (workspace, boot, architect/product/change families).

$ADLC_DIR = ".adlc"
$DOCS_ADLC_DIR = "docs/adlc"
$DOCS_ADLC_MEMORY = "docs/adlc/memory"
$DOCS_ADLC_PRODUCT = "docs/adlc/product"
$DOCS_ADLC_ARCHITECT = "docs/adlc/architect"
$ADLC_DRAFTS = ".adlc/drafts"

# Gitignore allowlist (layout allowlist, verbatim). Replaces the legacy wholesale
# `.adlc/` ignore. Order matters: negations must follow the `.adlc/*` blanket
# ignore. The report pair `.adlc/team-learn-report.md` AND
# `.adlc/team-levelup-report.md` keeps the legacy name ignored during the
# team-levelup rename transition.
$GITIGNORE_RULES_ALLOWLIST = @(
    # ADLC — agent-install surface (regenerated)
    ".agents/"
    ".opencode/"
    ".claude/"
    ".cursor/"
    ".codex/"
    ".gemini/"
    ".qwen/"
    ".devin/"
    ".tabnine/"
    "skills-lock.json"
    ".skills.json"
    # .mcp.json is deliberately ABSENT: it is committed project source (human-edited,
    # never generated), so it must not be gitignored. Only the agent dirs above are derived.
    ".events.json"
    ".pytest_cache/"
    ".ruff_cache/"
    # ADLC — machine pipeline + runtime state (tracked exceptions follow)
    ".adlc/*"
    "!.adlc/init-options.json"
    "!.adlc/workspace.yml"
    "!.adlc/drafts/"
    "!.adlc/evals/"
    ".adlc/evals/results/"
    "!.adlc/memory/"
    ".adlc/memory/*"
    "!.adlc/memory/evals/"
    "!.adlc/memory/evals/holdout.json"
    # ADLC — generated reports (post team-levelup rename; legacy name kept during transition)
    ".adlc/team-learn-report.md"
    ".adlc/team-levelup-report.md"
    # Knowledge graph (generated)
    "graphify-out/"
)

# --- Ledger base staleness -----------------------------------------------
# A slot number computed from a stale base is still wrong even when the
# helper computes it correctly. Run BEFORE allocating any ledger slot.
# Reports ONE number: `git rev-list --left-right --count A...B` reports
# "left right" and the columns are trivial to transpose.
function Get-LedgerBaseBehind {
    param([string]$Target = "origin/main")
    $n = git rev-list --count "HEAD..$Target" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not ($n -match '^\d+$')) { return -1 }
    return [int]$n
}

# Assert-CurrentBase [TARGET] - refuse to proceed on a stale base.
function Assert-CurrentBase {
    param([string]$Target = "origin/main")
    $behind = Get-LedgerBaseBehind $Target
    if ($behind -lt 0) {
        Write-Warning "cannot read $Target to check the base; continuing unverified."
        return $true
    }
    if ($behind -gt 0) {
        [Console]::Error.WriteLine("ERROR: this checkout is $behind commit(s) behind $Target.")
        [Console]::Error.WriteLine("       A slot number read from this base may already be taken.")
        [Console]::Error.WriteLine("       Rebase or merge $Target before claiming ledger slots.")
        return $false
    }
    return $true
}
