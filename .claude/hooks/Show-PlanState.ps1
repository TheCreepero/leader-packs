[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot
)

try {
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $planFiles = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'docs\plans') -Filter '*.md' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'TEMPLATE-*' })
    $planStates = [System.Collections.Generic.List[string]]::new()
    foreach ($planFile in $planFiles) {
        $statusMatch = @(Select-String -LiteralPath $planFile.FullName -Pattern '^Status:' | Select-Object -First 1)
        if ($statusMatch.Count -gt 0) { $planStates.Add(('docs/plans/{0}: {1}' -f $planFile.Name, $statusMatch[0].Line)) }
    }
    'Plans in docs/plans (archive not listed):'
    if ($planStates.Count -gt 0) { $planStates } else { '  none' }
    'Uncommitted files (git status --short):'
    $changedFiles = @(& git -C $RepoRoot status --short 2>$null)
    if ($changedFiles.Count -gt 0) { $changedFiles | Select-Object -First 30 } else { '  none' }
    exit 0
} catch {
    exit 0
}
