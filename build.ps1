[CmdletBinding(DefaultParameterSetName = 'Deploy')]
param(
    [Parameter(ParameterSetName = 'Deploy')]
    [switch]$Deploy,

    [Parameter(ParameterSetName = 'DevLink')]
    [switch]$DevLink,

    [Parameter(ParameterSetName = 'Package')]
    [switch]$Package,

    [Parameter(ParameterSetName = 'PublishSteam')]
    [switch]$PublishSteam,

    [Parameter(ParameterSetName = 'InstallSteamCmd')]
    [switch]$InstallSteamCmd,

    [Parameter(ParameterSetName = 'ValidateOnly')]
    [switch]$ValidateOnly,

    [Parameter(ParameterSetName = 'Test')]
    [switch]$Test,

    [Parameter(ParameterSetName = 'NewPack', Mandatory = $true)]
    [switch]$NewPack,

    [Parameter(ParameterSetName = 'NewPack', Mandatory = $true)]
    [string]$Tag,

    [Parameter(ParameterSetName = 'NewPack', Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(ParameterSetName = 'Generate', Mandatory = $true)]
    [switch]$Generate,

    [Parameter(ParameterSetName = 'FetchPhoto', Mandatory = $true)]
    [switch]$FetchPhoto,

    [Parameter(ParameterSetName = 'FetchPhoto', Mandatory = $true)]
    [string]$File,

    [Parameter(ParameterSetName = 'FetchPhoto', Mandatory = $true)]
    [string]$Key,

    [Parameter(ParameterSetName = 'MakePortraits', Mandatory = $true)]
    [switch]$MakePortraits,

    [Parameter(ParameterSetName = 'MakePortraits')]
    [switch]$StartComfyUI,

    [Parameter(ParameterSetName = 'ReviewPick', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReviewReject', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReviewWithdraw', Mandatory = $true)]
    [switch]$ApplyPortraitReview,

    [Parameter(ParameterSetName = 'MakePortraits')]
    [Parameter(ParameterSetName = 'ReviewPick', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReviewReject', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReviewWithdraw', Mandatory = $true)]
    [string]$Leader,

    [Parameter(ParameterSetName = 'ReviewPick', Mandatory = $true)]
    [int]$Pick,

    [Parameter(ParameterSetName = 'ReviewReject', Mandatory = $true)]
    [string]$Reject,

    [Parameter(ParameterSetName = 'ReviewWithdraw', Mandatory = $true)]
    [string]$Withdraw,

    [Parameter(ParameterSetName = 'ConvertPortraits', Mandatory = $true)]
    [switch]$ConvertPortraits,

    [Parameter(ParameterSetName = 'PreviewPortraits', Mandatory = $true)]
    [switch]$PreviewPortraits,

    [Parameter(ParameterSetName = 'RefreshGameData', Mandatory = $true)]
    [switch]$RefreshGameData,

    [Parameter(ParameterSetName = 'Check', Mandatory = $true)]
    [switch]$Check,

    [Parameter(ParameterSetName = 'Audit', Mandatory = $true)]
    [switch]$Audit,

    [Parameter(ParameterSetName = 'SyncMirrors', Mandatory = $true)]
    [switch]$SyncMirrors,

    [Parameter(ParameterSetName = 'ReviewPage', Mandatory = $true)]
    [switch]$ReviewPage,

    [Parameter(ParameterSetName = 'ReviewPage')]
    [string]$PageUrl,

    [Parameter(ParameterSetName = 'RenderShowcase', Mandatory = $true)]
    [switch]$RenderShowcase,

    [switch]$Validate,
    [switch]$NoValidate,
    [switch]$Clean,
    [switch]$Force,

    [string]$ModDir,
    [string]$ZipOutput,
    [string]$SteamUser,
    [string]$ChangeNote,
    [string]$SteamCmdPath,
    [switch]$DryRun,
    [switch]$UpdateDescription,
    [string]$Pack
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\HoiModBuild.ps1')
. (Join-Path $PSScriptRoot 'tools\LeaderPacks.ps1')
. (Join-Path $PSScriptRoot 'tools\LeaderPacks.Showcase.ps1')

function Get-SelectedPackNames {
    if ($Pack) {
        return @($Pack)
    }
    return @(Get-LpPackNames -RepoRoot $PSScriptRoot)
}

function Invoke-ForEachSelectedPack {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)

    $worstExitCode = 0
    foreach ($packName in (Get-SelectedPackNames)) {
        $packExitCode = [int](@(& $Action $packName)[-1])
        if ($packExitCode -ne 0 -and $worstExitCode -eq 0) { $worstExitCode = $packExitCode }
    }
    return $worstExitCode
}

function Sync-SkillMirrors {
    $sourceRoot = Join-Path $PSScriptRoot '.claude\skills'
    $mirrorRoot = Join-Path $PSScriptRoot '.agents\skills'
    if (-not (Test-Path -LiteralPath $sourceRoot)) {
        Write-Host 'No skills under .claude\skills.' -ForegroundColor Yellow
        return 0
    }
    if (Test-Path -LiteralPath $mirrorRoot) {
        Remove-Item -LiteralPath $mirrorRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $mirrorRoot -Force | Out-Null
    foreach ($skillFolder in @(Get-ChildItem -LiteralPath $sourceRoot -Directory)) {
        Copy-Item -LiteralPath $skillFolder.FullName -Destination (Join-Path $mirrorRoot $skillFolder.Name) -Recurse -Force
    }
    Write-Host "Mirrored $(@(Get-ChildItem -LiteralPath $sourceRoot -Directory).Count) skill(s) to .agents\skills." -ForegroundColor Green
    return 0
}

function Assert-PackGiven {
    param([Parameter(Mandatory = $true)][string]$SwitchName)

    if (-not $Pack) {
        Write-Host "$SwitchName needs -Pack <key>, such as -Pack finland" -ForegroundColor Red
        exit 1
    }
}

switch ($PSCmdlet.ParameterSetName) {
    'NewPack' {
        Assert-PackGiven -SwitchName '-NewPack'
        exit ([int](@(Invoke-LpNewPack -RepoRoot $PSScriptRoot -Pack $Pack -Tag $Tag -DisplayName $DisplayName)[-1]))
    }
    'Generate' {
        exit (Invoke-ForEachSelectedPack -Action { param($packName) Invoke-LpGenerate -RepoRoot $PSScriptRoot -Pack $packName -DryRun:$DryRun })
    }
    'FetchPhoto' {
        Assert-PackGiven -SwitchName '-FetchPhoto'
        exit ([int](@(Invoke-LpFetchPhoto -RepoRoot $PSScriptRoot -Pack $Pack -File $File -Key $Key -DryRun:$DryRun)[-1]))
    }
    'MakePortraits' {
        Assert-PackGiven -SwitchName '-MakePortraits'
        exit ([int](@(Invoke-LpMakePortraits -RepoRoot $PSScriptRoot -Pack $Pack -Leader $Leader -StartComfyUI:$StartComfyUI)[-1]))
    }
    'ReviewPick' {
        Assert-PackGiven -SwitchName '-ApplyPortraitReview'
        exit ([int](@(Invoke-LpApplyPortraitReview -RepoRoot $PSScriptRoot -Pack $Pack -Leader $Leader -Pick $Pick)[-1]))
    }
    'ReviewReject' {
        Assert-PackGiven -SwitchName '-ApplyPortraitReview'
        exit ([int](@(Invoke-LpApplyPortraitReview -RepoRoot $PSScriptRoot -Pack $Pack -Leader $Leader -Reject $Reject)[-1]))
    }
    'ReviewWithdraw' {
        Assert-PackGiven -SwitchName '-ApplyPortraitReview'
        exit ([int](@(Invoke-LpApplyPortraitReview -RepoRoot $PSScriptRoot -Pack $Pack -Leader $Leader -Withdraw $Withdraw)[-1]))
    }
    'ConvertPortraits' {
        exit (Invoke-ForEachSelectedPack -Action { param($packName) Invoke-LpConvertPortraits -RepoRoot $PSScriptRoot -Pack $packName -Force:$Force })
    }
    'PreviewPortraits' {
        exit (Invoke-ForEachSelectedPack -Action { param($packName) Export-LpPortraitPreviews -RepoRoot $PSScriptRoot -Pack $packName })
    }
    'RefreshGameData' {
        exit ([int](@(Invoke-LpRefreshGameData -RepoRoot $PSScriptRoot -Pack (Get-SelectedPackNames))[-1]))
    }
    'Check' {
        $checkExitCode = [int](@(Invoke-LpCheck -RepoRoot $PSScriptRoot -Pack (Get-SelectedPackNames))[-1])
        $showcaseExitCode = [int](@(Invoke-LpShowcaseCheck -RepoRoot $PSScriptRoot -Pack (Get-SelectedPackNames))[-1])
        exit ([math]::Max($checkExitCode, $showcaseExitCode))
    }
    'Audit' {
        Assert-PackGiven -SwitchName '-Audit'
        exit ([int](@(Invoke-LpAudit -RepoRoot $PSScriptRoot -Pack $Pack)[-1]))
    }
    'SyncMirrors' {
        exit (Sync-SkillMirrors)
    }
    'ReviewPage' {
        Assert-PackGiven -SwitchName '-ReviewPage'
        exit ([int](@(Invoke-LpReviewPage -RepoRoot $PSScriptRoot -Pack $Pack -PageUrl $PageUrl)[-1]))
    }
    'RenderShowcase' {
        exit (Invoke-ForEachSelectedPack -Action { param($packName) Invoke-LpRenderShowcase -RepoRoot $PSScriptRoot -Pack $packName })
    }
}

$buildConfig = Get-ModBuildConfig -RepoDir $PSScriptRoot -ModDir $ModDir
$buildParameters = Select-ModBuildParameters -BoundParameters $PSBoundParameters
exit (Invoke-ModBuild -Config $buildConfig -ExtraValidation { Invoke-LpValidation -RepoRoot $PSScriptRoot } @buildParameters)
