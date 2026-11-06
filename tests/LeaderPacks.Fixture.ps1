$script:LpRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script:LpFixtureDir = Join-Path $PSScriptRoot 'fixtures\leader-pack'
$script:LpCommonsFixtureDir = Join-Path $PSScriptRoot 'fixtures\image-sources\commons'
. (Join-Path $script:LpRepoRoot 'tools\LeaderPacks.ps1')
Add-Type -AssemblyName Microsoft.VisualBasic
$script:LpFixtureTemplates = @{}

function Copy-LpFixtureTemplate {
    param([Parameter(Mandatory = $true)][string]$Key, [Parameter(Mandatory = $true)][scriptblock]$NewTemplate)

    $templateRoot = $script:LpFixtureTemplates[$Key]
    if (-not $templateRoot -or -not (Test-Path -LiteralPath $templateRoot)) {
        $templateRoot = & $NewTemplate
        $script:LpFixtureTemplates[$Key] = $templateRoot
    }
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
    [Microsoft.VisualBasic.FileIO.FileSystem]::CopyDirectory($templateRoot, $fixtureRoot)
    foreach ($recordsFile in @(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'source') -Filter 'portraits.json' -Recurse -File)) {
        $recordsText = [System.IO.File]::ReadAllText($recordsFile.FullName)
        Write-LpText -Path $recordsFile.FullName -Text $recordsText.Replace($templateRoot.Replace('\', '\\'), $fixtureRoot.Replace('\', '\\'))
        if ([System.IO.File]::ReadAllText($recordsFile.FullName).Contains($templateRoot.Replace('\', '\\'))) {
            throw "Copy-LpFixtureTemplate: $($recordsFile.FullName) still points into the template $templateRoot"
        }
    }
    return $fixtureRoot
}

function Get-LpCommonsFixture {
    param([Parameter(Mandatory = $true)][string]$Name)

    return ([System.IO.File]::ReadAllText((Join-Path $script:LpCommonsFixtureDir "$Name.json"), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Get-LpSourceFixture {
    param([Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Name)

    return ([System.IO.File]::ReadAllText((Join-Path (Split-Path -Parent $script:LpCommonsFixtureDir) "$Source\$Name.json"), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Write-LpFixtureJpeg {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$Width = 400, [int]$Height = 520)

    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
    try {
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    } finally {
        $bitmap.Dispose()
    }
}

function Write-LpFixtureDds {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$Width, [int]$Height)

    $ddsBytes = New-Object byte[] (128 + $Width * $Height * 4)
    [System.Text.Encoding]::ASCII.GetBytes('DDS ').CopyTo($ddsBytes, 0)
    [System.BitConverter]::GetBytes([int]124).CopyTo($ddsBytes, 4)
    [System.BitConverter]::GetBytes($Height).CopyTo($ddsBytes, 12)
    [System.BitConverter]::GetBytes($Width).CopyTo($ddsBytes, 16)
    $parentPath = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }
    [System.IO.File]::WriteAllBytes($Path, $ddsBytes)
}

function New-LpFixturePhoto {
    param([Parameter(Mandatory = $true)][string]$Key, [Parameter(Mandatory = $true)][string]$Fixture)

    $photo = (Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name $Fixture)).Photo
    $photo.key = $Key
    $photo.fetched = '2026-10-31'
    $photo.downloadSha256 = '0' * 64
    return $photo
}

function Get-LpFixturePackIdentity {
    param([int]$Index)

    $tags = @('TST', 'TSU', 'TSV')
    $names = @('Testland', 'Otherland', 'Thirdland')
    return [PSCustomObject]@{ Tag = $tags[$Index]; Prefix = 'lp_' + $tags[$Index].ToLowerInvariant(); DisplayName = $names[$Index] }
}

function ConvertTo-LpFixtureText {
    param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Pack, $Identity)

    return $Text.Replace('lp_tst', $Identity.Prefix).Replace('TST', $Identity.Tag).Replace('"testland"', '"' + $Pack + '"').Replace('Testland', $Identity.DisplayName)
}

function Add-LpFixturePortraits {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Pack)

    $packData = Get-LpPack -RepoRoot $Root -Pack $Pack
    $leaderRecords = [ordered]@{}
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $packData)) {
        $leaderKey = [string]$leader.key
        $candidateDir = Join-Path $Root ("candidates\$Pack\$leaderKey")
        New-Item -ItemType Directory -Path $candidateDir -Force | Out-Null
        $candidates = [System.Collections.Generic.List[object]]::new()
        foreach ($seed in 1..4) {
            $candidatePath = Join-Path $candidateDir "A3_s$seed.png"
            [System.IO.File]::WriteAllText($candidatePath, "candidate $Pack $leaderKey $seed")
            $candidates.Add([ordered]@{ seed = $seed; file = $candidatePath; sha256 = (Get-LpSha256 -Path $candidatePath); likeness = 0.4 })
        }
        $chosenPath = Join-Path $packData.PortraitDir ($leaderKey + '.png')
        if (-not (Test-Path -LiteralPath $packData.PortraitDir)) {
            New-Item -ItemType Directory -Path $packData.PortraitDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $candidates[1].file -Destination $chosenPath
        $roundRecord = [ordered]@{
            round      = 1
            date       = '2026-11-01'
            seeds      = [object[]]@(1, 2, 3, 4)
            settings   = Get-LpPortraitSettings -Leader $leader
            run        = Join-Path $candidateDir 'portrait-run.json'
            recipe     = [ordered]@{ steps = [object[]]@([ordered]@{ template = 'A3'; sha256 = ('0' * 64) }); gradeStrength = 0.6; facePass = $true }
            candidates = $candidates.ToArray()
            decision   = [ordered]@{ pick = 2 }
        }
        $leaderRecords[$leaderKey] = [ordered]@{
            rounds = [object[]]@($roundRecord)
            chosen = [ordered]@{ round = 1; seed = 2; file = (Get-LpChosenRelativePath -Pack $packData -LeaderKey $leaderKey); sha256 = (Get-LpSha256 -Path $chosenPath) }
        }
    }
    Write-LpJson -Path (Join-Path $packData.SourceDir 'portraits.json') -Value ([ordered]@{ leaders = $leaderRecords })
    $conversionEntries = [ordered]@{}
    $cardSha = Get-LpCardSha -Pack $packData
    foreach ($expectedFile in (Get-LpExpectedPortraitFiles -Pack $packData)) {
        $ddsPath = Join-Path $packData.PackRoot $expectedFile.RelativePath.Replace('/', '\')
        Write-LpFixtureDds -Path $ddsPath -Width $expectedFile.Width -Height $expectedFile.Height
        $conversionEntries[$expectedFile.RelativePath] = [ordered]@{ leader = [string]$expectedFile.Leader.key; kind = $expectedFile.Kind; chosenSha256 = [string]$leaderRecords[[string]$expectedFile.Leader.key].chosen.sha256; cardSha256 = $(if ($expectedFile.Kind -eq 'small') { $cardSha } else { '' }); ddsSha256 = (Get-LpSha256 -Path $ddsPath) }
    }
    Write-LpJson -Path (Join-Path $packData.SourceDir 'converted.json') -Value ([ordered]@{ portraits = $conversionEntries })
}

function New-LpFixtureRepo {
    param([string[]]$Packs = @('testland'), [switch]$NoPortraits)

    if ($NoPortraits) {
        return (New-LpFreshFixtureRepo -Packs $Packs -NoPortraits)
    }
    return (Copy-LpFixtureTemplate -Key ('repo|' + ($Packs -join ',')) -NewTemplate { New-LpFreshFixtureRepo -Packs $Packs })
}

function New-LpFreshFixtureRepo {
    param([string[]]$Packs = @('testland'), [switch]$NoPortraits)

    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'data') -Force | Out-Null
    foreach ($dataFile in @('workshop.json', 'stat-bands.json', 'portrait-card.json')) {
        Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot "data\$dataFile") -Destination (Join-Path $fixtureRoot "data\$dataFile")
    }
    $packageSettings = [ordered]@{}
    foreach ($packName in $Packs) {
        $packageSettings[$packName] = [ordered]@{ root = "packs/$packName"; modFolderName = "commanders_pack_$packName" }
    }
    Write-LpJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json') -Value ([ordered]@{ packages = $packageSettings })
    for ($packIndex = 0; $packIndex -lt $Packs.Count; $packIndex++) {
        $packName = $Packs[$packIndex]
        $identity = Get-LpFixturePackIdentity -Index $packIndex
        foreach ($fixtureFile in @(@{ From = 'leaders.json'; To = "source\$packName\leaders.json" }, @{ From = 'fact-sheets.md'; To = "source\$packName\fact-sheets.md" }, @{ From = 'workshop-intro.bbcode'; To = "source\$packName\workshop-intro.bbcode" }, @{ From = 'game-characters.json'; To = "data\$packName\game-characters.json" }, @{ From = 'start-traits.json'; To = "data\$packName\start-traits.json" })) {
            $fixtureText = [System.IO.File]::ReadAllText((Join-Path $script:LpFixtureDir $fixtureFile.From), [System.Text.Encoding]::UTF8)
            Write-LpText -Path (Join-Path $fixtureRoot $fixtureFile.To) -Text (ConvertTo-LpFixtureText -Text $fixtureText -Pack $packName -Identity $identity)
        }
        $photos = @(
            (New-LpFixturePhoto -Key 'alpha' -Fixture 'cc-by'),
            (New-LpFixturePhoto -Key 'bravo' -Fixture 'pd'),
            (New-LpFixturePhoto -Key 'charlie' -Fixture 'cc0'),
            (New-LpFixturePhoto -Key 'delta' -Fixture 'pd'),
            (New-LpFixturePhoto -Key 'echo' -Fixture 'cc0')
        )
        Write-LpJson -Path (Join-Path $fixtureRoot "source\$packName\photos.json") -Value ([PSCustomObject]@{ photos = $photos }) -Depth 5
        Write-LpText -Path (Join-Path $fixtureRoot "packs\$packName\descriptor.mod") -Text ("version=`"1.0`"`r`nname=`"Commanders Pack: $($identity.DisplayName)`"`r`npicture=`"thumbnail.png`"`r`nsupported_version=`"1.19.*`"`r`n")
        Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'assets\thumbnail_master.png') -Destination (Join-Path $fixtureRoot "packs\$packName\thumbnail.png")
        if (-not $NoPortraits) {
            Add-LpFixturePortraits -Root $fixtureRoot -Pack $packName
        }
    }
    return $fixtureRoot
}

function Set-LpFixtureJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][scriptblock]$Change)

    $value = Read-LpJson -Path $Path
    & $Change $value
    Write-LpJson -Path $Path -Value $value
}

function Get-LpFixtureErrors {
    param([Parameter(Mandatory = $true)][string]$Root, [string]$Pack = 'testland')

    return @(Test-LpPack -RepoRoot $Root -Pack $Pack | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { "$($_.Where): $($_.Message)" })
}

function Get-LpGoldenPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    return (Join-Path $script:LpFixtureDir ('golden\' + ($RelativePath -replace '^packs/testland/', 'pack/').Replace('/', '\')))
}

function Get-LpTestCapabilities {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $pillowPython = $null
        $pythonExecutable = Get-LpPythonExecutable
        if ($pythonExecutable) {
            & $pythonExecutable -I -c 'import PIL' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $pillowPython = $pythonExecutable
            }
        }
        $managerRoot = Get-LpManagerRoot
        $savedConfig = $env:HOI_COMFYUI_CONFIG
        Remove-Item -Path Env:\HOI_COMFYUI_CONFIG -ErrorAction SilentlyContinue
        $comfyConfig = Get-LpComfyConfig -ManagerRoot $managerRoot
        if ($savedConfig) {
            $env:HOI_COMFYUI_CONFIG = $savedConfig
        }
        $gameRoot = $null
        if ($managerRoot) {
            try {
                $gameInfo = @(& (Join-Path $managerRoot 'Scripts\Vanilla\Get-HoiGameInfo.ps1') -PassThru) | Select-Object -Last 1
                if ($null -ne $gameInfo -and $gameInfo.GameRoot) {
                    $gameRoot = [string]$gameInfo.GameRoot
                }
            } catch {
                $gameRoot = $null
            }
        }
        $vanillaPortrait = if ($gameRoot) { Join-Path $gameRoot 'gfx\leaders\FIN\portrait_FIN_aksel_airo.dds' } else { '' }
        $standInServer = if ($managerRoot) { Join-Path $managerRoot 'tests\fixtures\portraits\FakeComfyServer.py' } else { '' }
        $venvPython = if ($null -ne $comfyConfig) { [string]$comfyConfig.python } else { '' }
        return [PSCustomObject]@{
            PillowPython    = $pillowPython
            ManagerRoot     = $managerRoot
            VenvPython      = $venvPython
            VanillaPortrait = $(if ($vanillaPortrait -and (Test-Path -LiteralPath $vanillaPortrait)) { $vanillaPortrait } else { '' })
            StandInServer   = $(if ($standInServer -and (Test-Path -LiteralPath $standInServer)) { $standInServer } else { '' })
            Prototype       = $(if (Test-Path -LiteralPath (Join-Path $script:LpRepoRoot 'scratch\reference\card_prototype.py')) { Join-Path $script:LpRepoRoot 'scratch\reference\card_prototype.py' } else { '' })
        }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Invoke-LpTestPython {
    param([Parameter(Mandatory = $true)][string]$Python, [Parameter(Mandatory = $true)][string]$Code, [string[]]$Arguments = @())

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $outputLines = @(& $Python -I -c $Code @Arguments 2>&1 | ForEach-Object { [string]$_ })
        if ($LASTEXITCODE -ne 0) {
            throw "python failed: $($outputLines -join ' ')"
        }
        return $outputLines
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Set-LpFixtureCache {
    param([Parameter(Mandatory = $true)][string]$Root, [string]$Pack = 'testland')

    $packData = Get-LpPack -RepoRoot $Root -Pack $Pack
    $photos = [System.Collections.Generic.List[object]]::new()
    foreach ($photo in $packData.Photos) {
        $cachePath = Get-LpCacheFilePath -Pack $packData -Photo $photo
        Write-LpText -Path $cachePath -Text ('photo ' + $photo.key)
        $photo.downloadSha256 = Get-LpSha256 -Path $cachePath
        $photos.Add($photo)
    }
    Save-LpPhotos -Pack $packData -Photos $photos
}

function Set-LpFixtureLeaders {
    param([string]$Root, [scriptblock]$Change, [string]$Pack = 'testland')

    Set-LpFixtureJson -Path (Join-Path $Root "source\$Pack\leaders.json") -Change $Change
}

function Set-LpFixturePhotos {
    param([string]$Root, [scriptblock]$Change, [string]$Pack = 'testland')

    Set-LpFixtureJson -Path (Join-Path $Root "source\$Pack\photos.json") -Change $Change
}

function Set-LpFixtureRecords {
    param([string]$Root, [scriptblock]$Change)

    Set-LpFixtureJson -Path (Join-Path $Root 'source\testland\portraits.json') -Change $Change
}

function New-LpGeneratedFixture {
    param([string[]]$Packs = @('testland'))

    return (Copy-LpFixtureTemplate -Key ('generated|' + ($Packs -join ',')) -NewTemplate {
            $templateRoot = New-LpFixtureRepo -Packs $Packs
            foreach ($packName in $Packs) {
                Invoke-LpGenerate -RepoRoot $templateRoot -Pack $packName 6>$null | Out-Null
            }
            $templateRoot
        })
}

function Add-LpUndecidedRound {
    param([string]$Root, [string]$Leader, [int]$Round = 1)

    $candidateDir = Join-Path $Root "review\$Leader\round-$Round"
    New-Item -ItemType Directory -Path $candidateDir -Force | Out-Null
    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($seed in (Get-LpRoundSeeds -Round $Round)) {
        $candidatePath = Join-Path $candidateDir "A3_s$seed.png"
        [System.IO.File]::WriteAllText($candidatePath, "review $Leader $seed")
        $candidates.Add([ordered]@{ seed = $seed; file = $candidatePath; sha256 = (Get-LpSha256 -Path $candidatePath); likeness = 0.3 })
    }
    $packData = Get-LpPack -RepoRoot $Root -Pack 'testland'
    $records = Read-LpPortraitRecords -Pack $packData
    $entry = $records['leaders'][$Leader]
    if ($null -eq $entry) {
        $entry = [ordered]@{ rounds = @(); chosen = $null }
        $records['leaders'][$Leader] = $entry
    }
    $rounds = Get-LpRecordRounds -Entry $entry
    $rounds.Add([ordered]@{ round = $Round; date = '2026-11-01'; seeds = [object[]]@(Get-LpRoundSeeds -Round $Round); settings = [ordered]@{}; run = ''; recipe = [ordered]@{}; candidates = $candidates.ToArray(); decision = $null })
    $entry['rounds'] = $rounds.ToArray()
    Save-LpPortraitRecords -Pack $packData -Records $records
}

function Add-LpFinishedRound {
    param([string]$Root, [string]$Leader, [int]$Seed = 2, [switch]$NoFacePass)

    $roundFolder = Join-Path $Root "review\$Leader\round-1"
    $candidateFolder = if ($NoFacePass) { 'paint' } else { 'face-pasted' }
    New-Item -ItemType Directory -Path (Join-Path $roundFolder $candidateFolder), (Join-Path $roundFolder 'mask'), (Join-Path $roundFolder 'final') -Force | Out-Null
    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($roundSeed in (Get-LpRoundSeeds -Round 1)) {
        [System.IO.File]::WriteAllText((Join-Path $roundFolder "$candidateFolder\A4_s$roundSeed.png"), "pasted $Leader $roundSeed")
        $finalPath = Join-Path $roundFolder "final\A4_s$roundSeed.png"
        [System.IO.File]::WriteAllText($finalPath, "final $Leader $roundSeed")
        $candidates.Add([ordered]@{ seed = $roundSeed; file = $finalPath; sha256 = (Get-LpSha256 -Path $finalPath); likeness = 0.5 })
    }
    [System.IO.File]::WriteAllText((Join-Path $roundFolder 'photo.png'), "photo $Leader")
    [System.IO.File]::WriteAllText((Join-Path $roundFolder 'mask\M1_s1.png'), "mask $Leader")
    $runPath = Join-Path $roundFolder 'portrait-run.json'
    [System.IO.File]::WriteAllText($runPath, '{}')
    $packData = Get-LpPack -RepoRoot $Root -Pack 'testland'
    $chosenPath = Join-Path $packData.PortraitDir "$Leader.png"
    if (-not (Test-Path -LiteralPath $packData.PortraitDir)) {
        New-Item -ItemType Directory -Path $packData.PortraitDir -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $roundFolder "final\A4_s$Seed.png") -Destination $chosenPath -Force
    $records = Read-LpPortraitRecords -Pack $packData
    $records['leaders'][$Leader] = [ordered]@{
        rounds = @([ordered]@{ round = 1; date = '2026-11-01'; seeds = [object[]]@(Get-LpRoundSeeds -Round 1); settings = [ordered]@{}; run = $runPath; recipe = [ordered]@{ steps = @(); facePass = (-not $NoFacePass) }; candidates = $candidates.ToArray(); decision = [ordered]@{ pick = $Seed } })
        chosen = [ordered]@{ round = 1; seed = $Seed; file = (Get-LpChosenRelativePath -Pack $packData -LeaderKey $Leader); sha256 = (Get-LpSha256 -Path $chosenPath) }
    }
    Save-LpPortraitRecords -Pack $packData -Records $records
    return $roundFolder
}

function New-LpStubManager {
    $managerRoot = Join-Path $TestDrive ('manager-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $portraitFolder = Join-Path $managerRoot 'Scripts\Portraits'
    New-Item -ItemType Directory -Path $portraitFolder -Force | Out-Null
    $newPortraitStub = @'
[CmdletBinding()]
param(
    [string]$Photo,
    [string]$Name,
    [string]$Tag,
    [string]$Role = 'military officer',
    [string]$Headwear,
    [string]$Uniform,
    [string]$AvoidHeadwear,
    [string]$Notes,
    [string]$Seeds,
    [int]$ColourSeed = 1,
    [switch]$NoFacePass,
    [string]$UniformColour,
    [switch]$Refinish,
    [string]$Candidate,
    [string]$Mask,
    [string]$Before,
    [switch]$StartComfyUI,
    [int]$Age = -1,
    [switch]$PassThru
)
$managerRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$call = [ordered]@{ Photo = $Photo; Name = $Name; Tag = $Tag; Role = $Role; Headwear = $Headwear; Uniform = $Uniform; AvoidHeadwear = $AvoidHeadwear; Notes = $Notes; Seeds = $Seeds; ColourSeed = $ColourSeed; NoFacePass = [bool]$NoFacePass; UniformColour = $UniformColour; Refinish = [bool]$Refinish; Candidate = $Candidate; Age = $Age }
Add-Content -LiteralPath (Join-Path $managerRoot 'calls.jsonl') -Value (ConvertTo-Json -InputObject $call -Compress)
if ($env:LP_STUB_FAIL -and (($Name -and $Name -like ('*' + $env:LP_STUB_FAIL)) -or ($Candidate -and $Candidate -like ('*' + $env:LP_STUB_FAIL + '*')))) {
    throw 'TOOL FAILURE: stand-in failure'
}
if ($Refinish) {
    $roundFolder = Split-Path -Parent (Split-Path -Parent $Candidate)
    $number = @(Get-ChildItem -LiteralPath $roundFolder -Directory -Filter 'refinish-*' -ErrorAction SilentlyContinue).Count + 1
    $workFolder = Join-Path $roundFolder ('refinish-' + $number)
    New-Item -ItemType Directory -Path (Join-Path $workFolder 'final') -Force | Out-Null
    $finalPath = Join-Path $workFolder ('final\' + (Split-Path -Leaf $Candidate))
    [System.IO.File]::WriteAllText($finalPath, ('refinished ' + [System.IO.File]::ReadAllText($Candidate)))
    $refinishCandidates = @(
        [PSCustomObject]@{ label = 'before'; file = $Before; likeness = 0.5; finish = [PSCustomObject]@{ skinAfter = @(70.0, 16.0, 19.0); median = 60.0 } },
        [PSCustomObject]@{ label = 'refinished'; file = ('final/' + (Split-Path -Leaf $Candidate)); likeness = 0.55; finish = [PSCustomObject]@{ skinAfter = @(55.0, 12.0, 16.0); median = 45.0 } }
    )
    $refinishRunPath = Join-Path $workFolder 'refinish-run.json'
    [System.IO.File]::WriteAllText($refinishRunPath, (ConvertTo-Json -InputObject ([ordered]@{ template = 'refinish'; candidates = $refinishCandidates }) -Depth 6))
    return [PSCustomObject]@{ OutDir = $workFolder; Number = $number; Run = $refinishRunPath; Sheet = (Join-Path $workFolder 'sheet.png'); Final = $finalPath; MaskSource = $(if ($env:LP_STUB_RUNNING -or $env:LP_STUB_MASKED) { 'candidate' } else { 'photo' }); Candidates = $refinishCandidates; ServerMessages = @() }
}
$nameFolder = Join-Path $managerRoot ('work\' + $Name)
$round = @(Get-ChildItem -LiteralPath $nameFolder -Directory -ErrorAction SilentlyContinue).Count + 1
$outDir = Join-Path $nameFolder ('round-' + $round)
New-Item -ItemType Directory -Path (Join-Path $outDir 'final') -Force | Out-Null
$candidates = [System.Collections.Generic.List[object]]::new()
foreach ($seed in @($Seeds -split ',')) {
    $candidateFile = 'final/A4_s' + $seed + '.png'
    $candidatePath = Join-Path $outDir $candidateFile.Replace('/', '\')
    [System.IO.File]::WriteAllText($candidatePath, ('stub ' + $Name + ' ' + $seed))
    $candidates.Add([PSCustomObject]@{ seed = [int]$seed; file = $candidateFile; sha256 = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToLowerInvariant(); likeness = 0.5; seconds = 0 })
}
$runPath = Join-Path $outDir 'portrait-run.json'
$run = [ordered]@{ round = $round; recipe = [ordered]@{ steps = @([ordered]@{ template = 'K1'; sha256 = 'k1' }, [ordered]@{ template = 'A4'; sha256 = 'a4' }); facePass = (-not $NoFacePass); finish = [ordered]@{ style = 'style-TST.json'; detailStrength = 0.25 }; framing = [ordered]@{ centreBlend = 0.5; faceHeight = 0.5 }; uniformColour = $(if ($UniformColour) { [ordered]@{ key = $UniformColour; default = $false } } else { $null }) } }
[System.IO.File]::WriteAllText($runPath, (ConvertTo-Json -InputObject $run -Depth 6))
[PSCustomObject]@{ OutDir = $outDir; Round = $round; Run = $runPath; Sheet = (Join-Path $outDir 'sheet.png'); Candidates = $candidates.ToArray(); ServerMessages = @() }
'@
    $statusStub = @'
[CmdletBinding()]
param([switch]$Start, [switch]$Stop)
$managerRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$action = if ($Start) { 'start' } elseif ($Stop) { 'stop' } else { 'status' }
Add-Content -LiteralPath (Join-Path $managerRoot 'status.log') -Value $action
if ($Start -and $env:LP_STUB_RUNNING) {
    'ComfyUI is already running at http://127.0.0.1:1.'
} elseif ($Start) {
    'ComfyUI started at http://127.0.0.1:1 in 1 s (process 1).'
} elseif ($Stop) {
    'ComfyUI stopped (process 1); http://127.0.0.1:1 is free.'
}
exit 0
'@
    [System.IO.File]::WriteAllText((Join-Path $portraitFolder 'New-HoiPortrait.ps1'), ($newPortraitStub -replace "`r?`n", "`r`n"))
    [System.IO.File]::WriteAllText((Join-Path $portraitFolder 'Get-HoiComfyStatus.ps1'), ($statusStub -replace "`r?`n", "`r`n"))
    return $managerRoot
}

function Get-LpStubCalls {
    param([string]$ManagerRoot)

    $callsPath = Join-Path $ManagerRoot 'calls.jsonl'
    if (-not (Test-Path -LiteralPath $callsPath)) {
        return @()
    }
    return @(Get-Content -LiteralPath $callsPath | ForEach-Object { $_ | ConvertFrom-Json })
}

function Get-LpRecordEntry {
    param([string]$Root, [string]$Leader)

    return (Get-LpPortraitEntry -Pack (Get-LpPack -RepoRoot $Root -Pack 'testland') -LeaderKey $Leader)
}
