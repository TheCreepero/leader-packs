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
} catch {
    exit 0
}

$ErrorActionPreference = 'Continue'
$powerShellExecutable = if (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$syncOutput = @(& $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'build.ps1') -SyncMirrors *>&1 | ForEach-Object { "$_" })
if ($LASTEXITCODE -eq 0) {
    exit 0
}
[Console]::Error.WriteLine("build.ps1 -SyncMirrors failed after editing $filePath; the .agents/skills mirror is stale:")
foreach ($syncLine in @($syncOutput | Select-Object -Last 20)) {
    [Console]::Error.WriteLine($syncLine.Trim())
}
exit 2
