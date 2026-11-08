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
    [Parameter(ParameterSetName = 'FetchPhotoSource', Mandatory = $true)]
    [Parameter(ParameterSetName = 'FetchPhotoEvidence', Mandatory = $true)]
    [switch]$FetchPhoto,

    [Parameter(ParameterSetName = 'FetchPhoto', Mandatory = $true)]
    [string]$File,

    [Parameter(ParameterSetName = 'FetchPhotoSource', Mandatory = $true)]
    [Parameter(ParameterSetName = 'FindPhoto')]
    [string[]]$Source,

    [Parameter(ParameterSetName = 'FetchPhotoSource', Mandatory = $true)]
    [string]$Id,

    [Parameter(ParameterSetName = 'FetchPhotoEvidence', Mandatory = $true)]
    [string]$Evidence,

    [Parameter(ParameterSetName = 'FetchPhoto', Mandatory = $true)]
    [Parameter(ParameterSetName = 'FetchPhotoSource', Mandatory = $true)]
    [Parameter(ParameterSetName = 'FetchPhotoEvidence', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ConfirmLicence', Mandatory = $true)]
    [string]$Key,

    [Parameter(ParameterSetName = 'ConfirmLicence', Mandatory = $true)]
    [switch]$ConfirmLicence,

    [Parameter(ParameterSetName = 'FindPhoto', Mandatory = $true)]
    [switch]$FindPhoto,

    [Parameter(ParameterSetName = 'FindPhoto', Mandatory = $true)]
    [string[]]$Query,

    [Parameter(ParameterSetName = 'FindPhoto')]
    [ValidateRange(1, 50)]
    [int]$Limit = 10,

    [Parameter(ParameterSetName = 'ListCharacters', Mandatory = $true)]
    [switch]$ListCharacters,

    [Parameter(ParameterSetName = 'ListCharacters')]
    [string[]]$Name,

    [Parameter(ParameterSetName = 'ApplyPlan', Mandatory = $true)]
    [switch]$ApplyPlan,

    [Parameter(ParameterSetName = 'RehearsePlan', Mandatory = $true)]
    [switch]$RehearsePlan,

    [Parameter(ParameterSetName = 'ApplyPlan', Mandatory = $true)]
    [Parameter(ParameterSetName = 'RehearsePlan', Mandatory = $true)]
    [string]$Plan,

    [Parameter(ParameterSetName = 'MakePortraits', Mandatory = $true)]
    [switch]$MakePortraits,

    [Parameter(ParameterSetName = 'MakePortraits')]
    [Parameter(ParameterSetName = 'RefinishPortraits')]
    [switch]$StartComfyUI,

    [Parameter(ParameterSetName = 'ReviewPick', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReviewReject', Mandatory = $true)]
    [Parameter(ParameterSetName = 'ReviewWithdraw', Mandatory = $true)]
    [switch]$ApplyPortraitReview,

    [Parameter(ParameterSetName = 'RefinishPortraits', Mandatory = $true)]
    [switch]$RefinishPortraits,

    [Parameter(ParameterSetName = 'RefinishPortraits')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'MakePortraits')]
    [Parameter(ParameterSetName = 'RefinishPortraits')]
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
    [string]$Pack,
    [string]$IncludeMembers,
    [switch]$CheckLinks
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
    'FetchPhotoSource' {
        Assert-PackGiven -SwitchName '-FetchPhoto'
        $fetchSources = Resolve-LpSourceNames -Source $Source
        if (@($fetchSources.Invalid).Count -gt 0) {
            Write-Host "-Source takes commons, finna or europeana, not '$(@($fetchSources.Invalid) -join ', ')'" -ForegroundColor Red
            exit 1
        }
        if (@($fetchSources.Sources).Count -ne 1) {
            Write-Host '-FetchPhoto takes one -Source' -ForegroundColor Red
            exit 1
        }
        exit ([int](@(Invoke-LpFetchPhoto -RepoRoot $PSScriptRoot -Pack $Pack -Source $fetchSources.Sources[0] -Id $Id -Key $Key -DryRun:$DryRun)[-1]))
    }
    'FetchPhotoEvidence' {
        Assert-PackGiven -SwitchName '-FetchPhoto'
        exit ([int](@(Invoke-LpFetchPhoto -RepoRoot $PSScriptRoot -Pack $Pack -Evidence $Evidence -Key $Key -DryRun:$DryRun)[-1]))
    }
    'ConfirmLicence' {
        Assert-PackGiven -SwitchName '-ConfirmLicence'
        exit ([int](@(Invoke-LpConfirmLicence -RepoRoot $PSScriptRoot -Pack $Pack -Key $Key)[-1]))
    }
    'FindPhoto' {
        $searchSources = @('commons', 'finna', 'europeana')
        if ($PSBoundParameters.ContainsKey('Source')) {
            $givenSources = Resolve-LpSourceNames -Source $Source
            if (@($givenSources.Invalid).Count -gt 0 -or @($givenSources.Sources).Count -eq 0) {
                Write-Host "-Source takes commons, finna or europeana, comma-separated, not '$(@($Source) -join ',')'" -ForegroundColor Red
                exit 1
            }
            $searchSources = @($givenSources.Sources)
        }
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        exit ([int](@(Invoke-LpFindPhoto -Query $Query -Source $searchSources -Limit $Limit)[-1]))
    }
    'ListCharacters' {
        Assert-PackGiven -SwitchName '-ListCharacters'
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        exit ([int](@(Invoke-LpListCharacters -RepoRoot $PSScriptRoot -Pack $Pack -Name $Name)[-1]))
    }
    'ApplyPlan' {
        exit ([int](@(Invoke-LpApplyPlan -RepoRoot $PSScriptRoot -PlanPath $Plan -Pack $Pack -DryRun:$DryRun)[-1]))
    }
    'RehearsePlan' {
        if ($DryRun) {
            Write-Host '-RehearsePlan takes no -DryRun: it already writes only a copy under scratch\ and removes it; use -ApplyPlan -DryRun to see what a plan would write' -ForegroundColor Red
            exit 1
        }
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        exit ([int](@(Invoke-LpRehearsePlan -RepoRoot $PSScriptRoot -PlanPath $Plan -Pack $Pack)[-1]))
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
    'RefinishPortraits' {
        Assert-PackGiven -SwitchName '-RefinishPortraits'
        exit ([int](@(Invoke-LpRefinishPortraits -RepoRoot $PSScriptRoot -Pack $Pack -Leader $Leader -Apply:$Apply -StartComfyUI:$StartComfyUI)[-1]))
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
        exit (Sync-ModSkillMirrors -RepoPath $PSScriptRoot)
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
