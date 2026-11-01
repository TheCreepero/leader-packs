[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot
)

try {
    if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $filePath = [string]$hookInput.tool_input.file_path
    if (-not $filePath -or ($filePath.Replace('\', '/') -notmatch '/\.claude/skills/')) { exit 0 }
    $powerShellExecutable = if (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'build.ps1') -SyncMirrors | Out-Null
    exit 0
} catch {
    exit 0
}
