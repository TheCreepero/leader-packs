BeforeDiscovery {
    . (Join-Path $PSScriptRoot 'LeaderPacks.Fixture.ps1')
    $script:Capabilities = Get-LpTestCapabilities
    $script:HasPillow = [bool]$script:Capabilities.PillowPython
    $script:HasStandIn = [bool]($script:Capabilities.VenvPython -and $script:Capabilities.VanillaPortrait -and $script:Capabilities.StandInServer)
    $script:HasCardCrop = [bool]($script:HasPillow -and $script:Capabilities.VenvPython -and $script:Capabilities.VanillaPortrait)
    $script:HasNode = [bool](Get-Command -Name 'node' -ErrorAction SilentlyContinue)
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'LeaderPacks.Fixture.ps1')
    $script:Capabilities = Get-LpTestCapabilities

    function Set-LpFixtureLeaders {
        param([string]$Root, [scriptblock]$Change, [string]$Pack = 'testland')

        Set-LpFixtureJson -Path (Join-Path $Root "source\$Pack\leaders.json") -Change $Change
    }

    function Set-LpFixturePhotos {
        param([string]$Root, [scriptblock]$Change)

        Set-LpFixtureJson -Path (Join-Path $Root 'source\testland\photos.json') -Change $Change
    }

    function Set-LpFixtureRecords {
        param([string]$Root, [scriptblock]$Change)

        Set-LpFixtureJson -Path (Join-Path $Root 'source\testland\portraits.json') -Change $Change
    }

    function New-LpGeneratedFixture {
        param([string[]]$Packs = @('testland'))

        $fixtureRoot = New-LpFixtureRepo -Packs $Packs
        foreach ($packName in $Packs) {
            Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack $packName 6>$null | Out-Null
        }
        return $fixtureRoot
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
    [int]$Age = -1,
    [switch]$PassThru
)
$managerRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$call = [ordered]@{ Photo = $Photo; Name = $Name; Tag = $Tag; Role = $Role; Headwear = $Headwear; Uniform = $Uniform; AvoidHeadwear = $AvoidHeadwear; Notes = $Notes; Seeds = $Seeds; ColourSeed = $ColourSeed; NoFacePass = [bool]$NoFacePass; Age = $Age }
Add-Content -LiteralPath (Join-Path $managerRoot 'calls.jsonl') -Value (ConvertTo-Json -InputObject $call -Compress)
if ($env:LP_STUB_FAIL -and $Name -like ('*' + $env:LP_STUB_FAIL)) {
    throw 'TOOL FAILURE: stand-in failure'
}
$nameFolder = Join-Path $managerRoot ('work\' + $Name)
$round = @(Get-ChildItem -LiteralPath $nameFolder -Directory -ErrorAction SilentlyContinue).Count + 1
$outDir = Join-Path $nameFolder ('round-' + $round)
New-Item -ItemType Directory -Path (Join-Path $outDir 'final') -Force | Out-Null
$candidates = [System.Collections.Generic.List[object]]::new()
foreach ($seed in @($Seeds -split ',')) {
    $candidateFile = 'final/A3_s' + $seed + '.png'
    $candidatePath = Join-Path $outDir $candidateFile.Replace('/', '\')
    [System.IO.File]::WriteAllText($candidatePath, ('stub ' + $Name + ' ' + $seed))
    $candidates.Add([PSCustomObject]@{ seed = [int]$seed; file = $candidateFile; sha256 = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToLowerInvariant(); likeness = 0.5; seconds = 0 })
}
$runPath = Join-Path $outDir 'portrait-run.json'
$run = [ordered]@{ round = $round; recipe = [ordered]@{ steps = @([ordered]@{ template = 'K1'; sha256 = 'k1' }, [ordered]@{ template = 'A3'; sha256 = 'a3' }); facePass = (-not $NoFacePass); gradeStrength = 0.6 } }
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
}

Describe 'Generation' {
    It 'writes every generated file exactly as the golden copy of the fixture pack' {
        $fixtureRoot = New-LpFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        $delta = Get-LpGenerationDelta -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        @($delta.Files.Keys).Count | Should -Be 15
        $englishGolden = [System.IO.File]::ReadAllBytes((Get-LpGoldenPath -RelativePath 'packs/testland/localisation/english/lp_tst_l_english.yml'))
        foreach ($relativePath in @($delta.Files.Keys)) {
            $actualBytes = [System.IO.File]::ReadAllBytes((Join-Path $fixtureRoot $relativePath))
            if ($relativePath -match '/localisation/(\w+)/' -and $Matches[1] -ne 'english') {
                $language = $Matches[1]
                $expectedText = [System.Text.Encoding]::UTF8.GetString($englishGolden, 3, $englishGolden.Length - 3).Replace('l_english:', "l_${language}:")
                $expectedBytes = [byte[]]@(0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes($expectedText)
            } else {
                $expectedBytes = [System.IO.File]::ReadAllBytes((Get-LpGoldenPath -RelativePath $relativePath))
            }
            [System.Convert]::ToBase64String($actualBytes) | Should -BeExactly ([System.Convert]::ToBase64String($expectedBytes)) -Because "$relativePath must equal its golden copy"
        }
    }

    It 'writes ASCII script with no empty NOT block, and localisation with a BOM' {
        $fixtureRoot = New-LpGeneratedFixture
        $delta = Get-LpGenerationDelta -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        foreach ($relativePath in @($delta.Files.Keys | Where-Object { $_ -match '\.(txt|gfx|yml)$' })) {
            $fileBytes = [System.IO.File]::ReadAllBytes((Join-Path $fixtureRoot $relativePath))
            $hasBom = $fileBytes.Length -ge 3 -and $fileBytes[0] -eq 0xEF -and $fileBytes[1] -eq 0xBB -and $fileBytes[2] -eq 0xBF
            $hasBom | Should -Be ($relativePath -match '\.yml$') -Because $relativePath
            $bodyBytes = if ($hasBom) { $fileBytes[3..($fileBytes.Length - 1)] } else { $fileBytes }
            @($bodyBytes | Where-Object { $_ -gt 0x7E -or ($_ -lt 0x20 -and $_ -ne 9 -and $_ -ne 10 -and $_ -ne 13) }).Count | Should -Be 0 -Because "$relativePath is ASCII"
            [System.Text.Encoding]::ASCII.GetString($bodyBytes) | Should -Not -Match 'NOT\s*=\s*\{\s*\}'
        }
    }

    It 'recruits a leader with an empty sameAs without a guard and guards the others on each of their ids' {
        $fixtureRoot = New-LpGeneratedFixture
        $onActions = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\testland\common\on_actions\lp_tst_on_actions.txt'))
        $onActions | Should -Match "(?m)^\t{4}recruit_character = lp_tst_alpha_leader\r$"
        $onActions | Should -Match "(?s)if = \{\s+limit = \{\s+NOT = \{ has_character = TST_bravo_old \}\s+NOT = \{ has_character = TST_bravo_renamed \}\s+\}\s+recruit_character = lp_tst_bravo_leader"
        $onActions | Should -Match '(?s)limit = \{ has_character = TST_delta_advisor \}\s+TST_delta_advisor = \{\s+if = \{\s+limit = \{ NOT = \{ is_army_leader = yes \} \}\s+add_corps_commander_role = \{'
        $onActions | Should -Match '(?s)limit = \{ NOT = \{ is_navy_leader = yes \} \}\s+add_naval_commander_role = \{\s+traits = \{ seawolf \}'
        $characters = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\testland\common\characters\lp_tst_characters.txt'))
        $characters | Should -Match '(?s)lp_tst_charlie_leader = \{.*army = \{\s+large = GFX_portrait_lp_tst_charlie_leader\s+small = GFX_portrait_lp_tst_charlie_leader_small\s+\}\s+navy = \{'
        $characters | Should -Not -Match 'delta_advisor'
    }

    It 'writes nothing the second time and then finds no error' {
        $fixtureRoot = New-LpGeneratedFixture
        $delta = Get-LpGenerationDelta -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        $delta.Changed.Count | Should -Be 0
        $delta.Stale.Count | Should -Be 0
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
    }

    It 'reports a generated file edited by hand and a file the source does not generate, and generating repairs both' {
        $fixtureRoot = New-LpGeneratedFixture
        Add-Content -LiteralPath (Join-Path $fixtureRoot 'packs\testland\common\on_actions\lp_tst_on_actions.txt') -Value '# hand edit'
        Write-LpText -Path (Join-Path $fixtureRoot 'packs\testland\common\characters\stray_characters.txt') -Text 'characters = { }'
        $errorMessages = Get-LpFixtureErrors -Root $fixtureRoot
        @($errorMessages | Where-Object { $_ -like 'packs/testland/common/on_actions/lp_tst_on_actions.txt: differs*' }).Count | Should -Be 1
        @($errorMessages | Where-Object { $_ -like 'packs/testland/common/characters/stray_characters.txt: not generated*' }).Count | Should -Be 1
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
    }

    It 'refuses to generate from a source with errors' {
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($leaderSource) $leaderSource.leaders[0].skill = 9 }
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 1
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'packs\testland\common') | Should -BeFalse
    }

    It 'with -DryRun writes nothing' {
        $fixtureRoot = New-LpFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' -DryRun 6>$null | Select-Object -Last 1 | Should -Be 0
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'packs\testland\common') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'wiki') | Should -BeFalse
    }

    It 'writes only the Workshop description and the wiki page for a pack without leaders, and removes what the leaders left' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($leaderSource) $leaderSource.leaders = @() }
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        $delta = Get-LpGenerationDelta -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        @($delta.Files.Keys) | Should -Be @('packs/testland/WORKSHOP_DESCRIPTION_GUIDELINES.md', 'wiki/Commanders-Pack-Testland.md')
        @(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'packs\testland') -Recurse -File | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @('descriptor.mod', 'thumbnail.png', 'WORKSHOP_DESCRIPTION_GUIDELINES.md')
    }
}

Describe 'Check rules' {
    It 'the fixture pack passes the check' {
        $fixtureRoot = New-LpGeneratedFixture
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
        Invoke-LpCheck -RepoRoot $fixtureRoot 6>$null | Select-Object -Last 1 | Should -Be 0
    }

    It 'fails on <Name>' -TestCases @(
        @{ Name = 'a tag that is no country tag'; Expected = "tag 'tst' is not a country tag"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.tag = 'tst' } } }
        @{ Name = 'a prefix that does not follow the tag'; Expected = 'must be lp_tst'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.prefix = 'lp_other' } } }
        @{ Name = 'a pack field that is not the folder'; Expected = 'is not the folder name'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.pack = 'other' } } }
        @{ Name = 'a key used twice'; Expected = "key 'alpha_leader' used twice"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[1].key = 'alpha_leader' } } }
        @{ Name = 'a key with capitals'; Expected = "key 'Alpha' must be lower-case"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].key = 'Alpha' } } }
        @{ Name = 'a name with localisation markup'; Expected = 'contains a double quote, a square bracket'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].name = 'Alpha [Leader]' } } }
        @{ Name = 'a name with a letter outside ASCII'; Expected = 'must be in English letters'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].name = 'Alpha L' + [char]0x00E4 + 'der' } } }
        @{ Name = 'a name with a vertical bar'; Expected = 'or a vertical bar (the wiki table)'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].name = 'Alpha | Leader' } } }
        @{ Name = 'an unknown mode'; Expected = "mode 'recruit' is not new, addRole or skip"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].mode = 'recruit' } } }
        @{ Name = 'an unknown role'; Expected = "role 'general' is not corps_commander"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].role = 'general' } } }
        @{ Name = 'a skill outside its band'; Expected = 'skill 6 is outside the start band 1 to 5'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].skill = 6 } } }
        @{ Name = 'a navy skill outside its band'; Expected = 'maneuvering 5 is outside the start band 1 to 4'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[2].maneuvering = 5 } } }
        @{ Name = 'a missing attribute skill'; Expected = 'planning missing or not a whole number'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].PSObject.Properties.Remove('planning') } } }
        @{ Name = 'a skill that is not a whole number'; Expected = 'attack missing or not a whole number'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].attack = 2.5 } } }
        @{ Name = 'an army skill on an admiral'; Expected = 'planning is not a stat of a navy leader'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[2] | Add-Member -NotePropertyName 'planning' -NotePropertyValue 2 } } }
        @{ Name = 'an army trait on an admiral'; Expected = "trait 'infantry_officer' is not a trait a vanilla navy leader has"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[2].traits = @('infantry_officer') } } }
        @{ Name = 'a trait of another country'; Expected = "trait 'JAP_samurai_lineage' is not a trait a vanilla army leader has at the start, shared or of TST"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].traits = @('JAP_samurai_lineage') } } }
        @{ Name = 'a trait listed twice'; Expected = 'a trait is listed twice'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].traits = @('infantry_officer', 'infantry_officer') } } }
        @{ Name = 'a missing fact sheet section'; Expected = "no section '## nothing_here'"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].factSheet = 'nothing_here' } } }
        @{ Name = 'a fact sheet without a source'; Expected = "fact sheet 'alpha_leader' cites no source URL"; Change = { param($root) $path = Join-Path $root 'source\testland\fact-sheets.md'; Write-LpText -Path $path -Text ([System.IO.File]::ReadAllText($path).Replace('Source: https://example.org/alpha', 'No source.')) } }
        @{ Name = 'a leader without a sameAs list'; Expected = 'no sameAs list'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].PSObject.Properties.Remove('sameAs') } } }
        @{ Name = 'a sameAs id the snapshot does not know'; Expected = "sameAs id 'TST_nobody' is in neither vanilla nor Road to 56"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].sameAs = @('TST_nobody') } } }
        @{ Name = 'a new leader whose other id is a unit leader'; Expected = "sameAs id 'TST_india_admiral' is a unit leader in rt56 already"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].sameAs = @('TST_india_admiral') } } }
        @{ Name = 'a new leader with the name of a unit leader'; Expected = "name 'Golf General' belongs to the unit leader TST_golf_general"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].name = 'Golf General' } } }
        @{ Name = 'an addRole target the snapshot does not know'; Expected = "target 'TST_nobody' is in neither vanilla nor Road to 56"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[3].target = 'TST_nobody' } } }
        @{ Name = 'an addRole target that is not in vanilla'; Expected = "target 'TST_india_admiral' does not exist in vanilla"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[3].target = 'TST_india_admiral' } } }
        @{ Name = 'an addRole target without an advisor role'; Expected = "target 'TST_golf_general' has no advisor role in vanilla"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[3].target = 'TST_golf_general' } } }
        @{ Name = 'an addRole target that already leads in the army'; Expected = "target 'TST_delta_advisor' is already a unit leader of the army in vanilla"; Change = { param($root) Set-LpFixtureJson -Path (Join-Path $root 'data\testland\game-characters.json') -Change { param($s) $s.sets[0].characters[1].roles += [PSCustomObject]@{ kind = 'corps_commander'; slot = '' } } } }
        @{ Name = 'an addRole target given a role twice'; Expected = "target 'TST_delta_advisor' is given a role by two leaders"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[4].target = 'TST_delta_advisor' } } }
        @{ Name = 'an addRole without a target'; Expected = 'addRole needs a target'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[3].PSObject.Properties.Remove('target') } } }
        @{ Name = 'a skip without a reason'; Expected = 'skip without a reason'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[5].reason = '' } } }
        @{ Name = 'a skip reason that names no id'; Expected = 'the skip reason names no character id'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[5].reason = 'Already covered elsewhere.' } } }
        @{ Name = 'a leader without a portrait block'; Expected = 'no portrait block'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].PSObject.Properties.Remove('portrait') } } }
        @{ Name = 'a colourSeed that is not a whole number'; Expected = 'portrait.colourSeed must be a whole number from 0 up'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait | Add-Member -NotePropertyName 'colourSeed' -NotePropertyValue 1.5 } } }
        @{ Name = 'a negative colourSeed'; Expected = 'portrait.colourSeed must be a whole number from 0 up'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait | Add-Member -NotePropertyName 'colourSeed' -NotePropertyValue -1 } } }
        @{ Name = 'a facePass that is not true or false'; Expected = 'portrait.facePass must be true or false'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait | Add-Member -NotePropertyName 'facePass' -NotePropertyValue 'no' } } }
        @{ Name = 'a born that is not a year'; Expected = 'portrait.born must be a four-digit year'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait.born = '1894' } } }
        @{ Name = 'a photoYear that is not a year'; Expected = 'portrait.photoYear must be a four-digit year'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait.photoYear = 43 } } }
        @{ Name = 'a photo taken before the birth year'; Expected = 'portrait.photoYear must not be before portrait.born'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait.photoYear = 1890 } } }
        @{ Name = 'years that give a childhood age'; Expected = 'portrait.photoYear - portrait.born must give an age of 15 to 100'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait.photoYear = 1904 } } }
        @{ Name = 'years that give an age over 100'; Expected = 'portrait.photoYear - portrait.born must give an age of 15 to 100'; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait.born = 1794 } } }
        @{ Name = 'a photo key that was never fetched'; Expected = "photo 'zulu' is not in source/testland/photos.json"; Change = { param($root) Set-LpFixtureLeaders -Root $root -Change { param($s) $s.leaders[0].portrait.photo = 'zulu' } } }
        @{ Name = 'a photo licence outside the policy'; Expected = 'outside the policy'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].licenseCategory = 'CC BY-SA' } } }
        @{ Name = 'a photo category that the Commons code does not give'; Expected = 'does not match its Commons code'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].license = 'cc-by-sa-4.0' } } }
        @{ Name = 'public domain without its reason'; Expected = 'public domain without the reason'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[1].publicDomainReason = 'trust me' } } }
        @{ Name = 'CC BY without an author'; Expected = 'CC BY needs a named author'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].author = '' } } }
        @{ Name = 'a photo page off Commons'; Expected = 'not a Wikimedia Commons file page'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].pageUrl = 'https://example.com/page' } } }
        @{ Name = 'a download off the Wikimedia servers'; Expected = "is not on Wikimedia's upload servers"; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].downloadUrl = 'https://example.com/a.jpg' } } }
        @{ Name = 'a photo record without its hash'; Expected = 'no downloadSha256'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].downloadSha256 = '' } } }
        @{ Name = 'a photo record without its fetch date'; Expected = 'no fetched'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].fetched = '' } } }
        @{ Name = 'a photo under 300 px'; Expected = 'at least 300 px on its shorter side'; Change = { param($root) Set-LpFixturePhotos -Root $root -Change { param($s) $s.photos[0].height = 280 } } }
        @{ Name = 'a cached download that differs from the record'; Expected = 'does not match the SHA-256 recorded at fetch time'; Change = { param($root) $packData = Get-LpPack -RepoRoot $root -Pack 'testland'; Write-LpText -Path (Get-LpCacheFilePath -Pack $packData -Photo $packData.Photos[0]) -Text 'other bytes' } }
        @{ Name = 'a chosen portrait changed after the pick'; Expected = 'differs from the one recorded when it was chosen'; Change = { param($root) [System.IO.File]::WriteAllText((Join-Path $root 'source\testland\portraits\alpha_leader.png'), 'edited') } }
        @{ Name = 'a chosen portrait that is gone'; Expected = 'the chosen portrait source/testland/portraits/alpha_leader.png is missing'; Change = { param($root) Remove-Item -LiteralPath (Join-Path $root 'source\testland\portraits\alpha_leader.png') } }
        @{ Name = 'a portrait PNG nobody chose'; Expected = 'source/testland/portraits/zulu.png: is no chosen portrait'; Change = { param($root) [System.IO.File]::WriteAllText((Join-Path $root 'source\testland\portraits\zulu.png'), 'stray') } }
        @{ Name = 'round seeds that are not 4n-3 to 4n'; Expected = 'seeds 5,6,7,8 are not 1,2,3,4'; Change = { param($root) Set-LpFixtureRecords -Root $root -Change { param($s) $s.leaders.alpha_leader.rounds[0].seeds = @(5, 6, 7, 8) } } }
        @{ Name = 'an earlier round without a decision'; Expected = 'round 1: has no decision, but a later round exists'; Change = { param($root) Set-LpFixtureRecords -Root $root -Change { param($s) $first = $s.leaders.alpha_leader.rounds[0]; $second = $first | ConvertTo-Json -Depth 8 | ConvertFrom-Json; $second.round = 2; $second.seeds = @(5, 6, 7, 8); $second.candidates = @(); $first.decision = $null; $s.leaders.alpha_leader.rounds = @($first, $second) } } }
        @{ Name = 'a pick that is not a candidate'; Expected = 'the pick 9 is not a candidate of the round'; Change = { param($root) Set-LpFixtureRecords -Root $root -Change { param($s) $s.leaders.alpha_leader.rounds[0].decision.pick = 9 } } }
        @{ Name = 'a chosen portrait that is not the recorded pick'; Expected = 'is not the pick recorded in that round'; Change = { param($root) Set-LpFixtureRecords -Root $root -Change { param($s) $s.leaders.alpha_leader.chosen.seed = 3 } } }
        @{ Name = 'a leader without a chosen portrait'; Expected = 'leader alpha_leader: no chosen portrait'; Change = { param($root) Set-LpFixtureRecords -Root $root -Change { param($s) $s.leaders.alpha_leader.chosen = $null }; Remove-Item -LiteralPath (Join-Path $root 'source\testland\portraits\alpha_leader.png') } }
        @{ Name = 'a missing large portrait'; Expected = 'packs/testland/gfx/leaders/TST/lp_tst_alpha_leader.dds: no large portrait in the pack'; Change = { param($root) Remove-Item -LiteralPath (Join-Path $root 'packs\testland\gfx\leaders\TST\lp_tst_alpha_leader.dds') } }
        @{ Name = 'a small portrait of the wrong size'; Expected = 'lp_tst_alpha_leader_small.dds: the DDS is not 65x67'; Change = { param($root) Write-LpFixtureDds -Path (Join-Path $root 'packs\testland\gfx\interface\ideas\lp_tst_alpha_leader_small.dds') -Width 60 -Height 68 } }
        @{ Name = 'a small portrait for an addRole leader'; Expected = 'lp_tst_delta_advisor_small.dds: is not generated from the source nor a portrait'; Change = { param($root) Write-LpFixtureDds -Path (Join-Path $root 'packs\testland\gfx\interface\ideas\lp_tst_delta_advisor_small.dds') -Width 65 -Height 67 } }
        @{ Name = 'a chosen portrait swapped together with its hash'; Expected = 'lp_tst_alpha_leader.dds: was built from another chosen portrait'; Change = { param($root) $chosenPath = Join-Path $root 'source\testland\portraits\alpha_leader.png'; [System.IO.File]::WriteAllText($chosenPath, 'another pick'); $newSha = Get-LpSha256 -Path $chosenPath; Set-LpFixtureRecords -Root $root -Change { param($s) $s.leaders.alpha_leader.chosen.sha256 = $newSha; $s.leaders.alpha_leader.rounds[0].candidates[1].sha256 = $newSha } } }
        @{ Name = 'a changed card geometry'; Expected = 'lp_tst_alpha_leader_small.dds: was built with another data/portrait-card.json'; Change = { param($root) Set-LpFixtureJson -Path (Join-Path $root 'data\portrait-card.json') -Change { param($s) $s.card.angle = 6 } } }
        @{ Name = 'a DDS replaced by hand'; Expected = 'lp_tst_bravo_leader.dds: differs from the DDS build.ps1 -ConvertPortraits wrote'; Change = { param($root) $ddsPath = Join-Path $root 'packs\testland\gfx\leaders\TST\lp_tst_bravo_leader.dds'; $ddsBytes = [System.IO.File]::ReadAllBytes($ddsPath); $ddsBytes[200] = 7; [System.IO.File]::WriteAllBytes($ddsPath, $ddsBytes) } }
        @{ Name = 'a DDS without a conversion record'; Expected = 'lp_tst_charlie_leader.dds: has no record in source/testland/converted.json'; Change = { param($root) Set-LpFixtureJson -Path (Join-Path $root 'source\testland\converted.json') -Change { param($s) $s.portraits.PSObject.Properties.Remove('gfx/leaders/TST/lp_tst_charlie_leader.dds') } } }
        @{ Name = 'a conversion record of a portrait no leader has'; Expected = 'records gfx/leaders/TST/lp_tst_zulu.dds, which no leader has'; Change = { param($root) Set-LpFixtureJson -Path (Join-Path $root 'source\testland\converted.json') -Change { param($s) $s.portraits | Add-Member -NotePropertyName 'gfx/leaders/TST/lp_tst_zulu.dds' -NotePropertyValue ([PSCustomObject]@{ leader = 'zulu'; kind = 'large'; chosenSha256 = ''; cardSha256 = ''; ddsSha256 = '' }) } } }
        @{ Name = 'a generated file edited by hand'; Expected = 'lp_tst_characters.txt: differs from what the source generates'; Change = { param($root) Add-Content -LiteralPath (Join-Path $root 'packs\testland\common\characters\lp_tst_characters.txt') -Value '# edit' } }
        @{ Name = 'a stray file in the pack'; Expected = 'packs/testland/history/countries/TST.txt: is not generated from the source'; Change = { param($root) Write-LpText -Path (Join-Path $root 'packs\testland\history\countries\TST.txt') -Text 'capital = 1' } }
        @{ Name = 'a missing snapshot'; Expected = 'game-characters.json: missing: run build.ps1 -RefreshGameData -Pack testland'; Change = { param($root) Remove-Item -LiteralPath (Join-Path $root 'data\testland\game-characters.json') } }
        @{ Name = 'missing start traits'; Expected = 'data/testland/start-traits.json: missing: run build.ps1 -RefreshGameData -Pack testland'; Change = { param($root) Remove-Item -LiteralPath (Join-Path $root 'data\testland\start-traits.json') } }
        @{ Name = 'missing stat bands'; Expected = 'data/stat-bands.json: missing'; Change = { param($root) Remove-Item -LiteralPath (Join-Path $root 'data\stat-bands.json') } }
    ) {
        $fixtureRoot = New-LpGeneratedFixture
        & ([scriptblock]::Create($Change.ToString())) $fixtureRoot
        $errorText = (Get-LpFixtureErrors -Root $fixtureRoot) -join "`n"
        $errorText | Should -Match ([regex]::Escape($Expected))
        Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 1
    }

    It 'warns about a new leader whose name matches an advisor not listed in sameAs' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].name = 'Hotel Minister' }
        $warnings = @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' } | ForEach-Object { $_.Message })
        ($warnings -join "`n") | Should -Match "name 'Hotel Minister' matches TST_hotel_minister in vanilla: list it in sameAs"
    }

    It 'compares names without accents and case' {
        ConvertTo-LpComparableName -Name ('Hugo ' + [char]0x00D6 + 'sterman') | Should -Be 'hugo osterman'
        ConvertTo-LpComparableName -Name 'Carl-Gustaf  MANNERHEIM' | Should -Be 'carl gustaf mannerheim'
    }
}

Describe 'Commons licence verdict' {
    It 'accepts public domain, CC0 and CC BY files, with the licence and the author, and no crop or tone' {
        $publicDomain = Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'pd')
        $publicDomain.Accepted | Should -BeTrue
        $publicDomain.Photo.licenseCategory | Should -Be 'PD'
        $publicDomain.Photo.publicDomainReason | Should -Be 'PD-Finland50'
        Get-LpLicenceLabel -Photo $publicDomain.Photo | Should -Be 'Public domain (PD-Finland50)'
        $publicDomain.Photo.pageUrl | Should -Match '^https://commons\.wikimedia\.org/wiki/File:'
        @($publicDomain.Photo.PSObject.Properties.Name) | Should -Not -Contain 'crop'
        @($publicDomain.Photo.PSObject.Properties.Name) | Should -Not -Contain 'tone'
        (Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'cc0')).Photo.licenseCategory | Should -Be 'CC0'
        $attribution = Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'cc-by')
        $attribution.Accepted | Should -BeTrue
        $attribution.Photo.licenseCategory | Should -Be 'CC BY'
        $attribution.Photo.licenseUrl | Should -Be 'https://creativecommons.org/licenses/by/4.0'
        $attribution.Photo.author | Should -Match '^Hugo Sundstr'
    }

    It 'rejects CC BY-SA, a missing file, a file tagged for deletion, a public domain without its reason and a picture under 300 px' {
        $shareAlike = Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'cc-by-sa')
        $shareAlike.Accepted | Should -BeFalse
        $shareAlike.Reason | Should -Match 'outside the policy'
        (Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'missing')).Accepted | Should -BeFalse
        $tagged = Get-LpCommonsFixture -Name 'pd'
        $tagged.query.pages[0] | Add-Member -NotePropertyName 'templates' -NotePropertyValue @([PSCustomObject]@{ ns = 10; title = 'Template:Delete' }) -Force
        (Get-LpCommonsVerdict -Response $tagged).Reason | Should -Match 'Template:Delete'
        $noReason = Get-LpCommonsFixture -Name 'pd'
        $noReason.query.pages[0].templates = @($noReason.query.pages[0].templates | Where-Object { $_.title -notmatch '^Template:PD-' })
        (Get-LpCommonsVerdict -Response $noReason).Reason | Should -Match 'without a PD- licence template'
        $small = Get-LpCommonsFixture -Name 'cc0'
        $small.query.pages[0].imageinfo[0].width = 299
        (Get-LpCommonsVerdict -Response $small).Reason | Should -Match 'under 300 px on its shorter side'
        $enough = Get-LpCommonsFixture -Name 'cc0'
        $enough.query.pages[0].imageinfo[0].width = 300
        (Get-LpCommonsVerdict -Response $enough).Accepted | Should -BeTrue
    }

    It 'rejects CC BY without a named author, a file that is not a picture and a download off the Wikimedia servers' {
        $unnamed = Get-LpCommonsFixture -Name 'cc-by'
        $unnamed.query.pages[0].imageinfo[0].extmetadata.Artist.value = 'Unknown author'
        (Get-LpCommonsVerdict -Response $unnamed).Reason | Should -Match 'without a named author'
        $document = Get-LpCommonsFixture -Name 'pd'
        $document.query.pages[0].imageinfo[0].mime = 'application/pdf'
        (Get-LpCommonsVerdict -Response $document).Reason | Should -Match 'not a picture'
        $elsewhere = Get-LpCommonsFixture -Name 'pd'
        $elsewhere.query.pages[0].imageinfo[0].thumburl = 'https://example.com/abatis.jpg'
        (Get-LpCommonsVerdict -Response $elsewhere).Reason | Should -Match 'not on Wikimedia'
    }

    It 'asks Commons for the licence metadata and the deletion templates in one query' {
        $queryUrl = Get-LpCommonsQueryUrl -FileTitle 'File:Abatis at Taipale.jpg'
        $queryUrl | Should -Match 'titles=File%3AAbatis%20at%20Taipale\.jpg'
        $queryUrl | Should -Match 'iiprop=url%7Csize%7Cmime%7Cextmetadata'
        $queryUrl | Should -Match 'prop=imageinfo%7Ctemplates'
    }
}

Describe 'FetchPhoto and Audit' {
    It 'records an accepted photo with its hash and keeps the other photos' {
        $fixtureRoot = New-LpGeneratedFixture
        Mock Invoke-RestMethod { Get-LpCommonsFixture -Name 'cc-by' }
        Mock Invoke-WebRequest { [System.IO.File]::WriteAllText($OutFile, 'photo bytes') }
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'Calling of reservists 1939 (Numeroimaton; JOKAHBL3B J06-1).tif' -Key 'zulu' 6>$null | Select-Object -Last 1 | Should -Be 0
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        $packData.Photos.Count | Should -Be 6
        $photo = Get-LpPhotoByKey -Pack $packData -PhotoKey 'zulu'
        $photo.fetched | Should -Match '^\d{4}-\d{2}-\d{2}$'
        $photo.downloadSha256 | Should -Be (Get-LpSha256 -Path (Get-LpCacheFilePath -Pack $packData -Photo $photo))
        $photo.commonsTitle | Should -Be 'File:Calling of reservists 1939 (Numeroimaton; JOKAHBL3B J06-1).tif'
    }

    It 'records nothing for a dry run, a refused licence or a bad key' {
        $fixtureRoot = New-LpGeneratedFixture
        $photosPath = Join-Path $fixtureRoot 'source\testland\photos.json'
        $before = [System.IO.File]::ReadAllText($photosPath)
        Mock Invoke-RestMethod { Get-LpCommonsFixture -Name 'cc-by' }
        Mock Invoke-WebRequest { throw 'no download in a dry run' }
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'x.jpg' -Key 'zulu' -DryRun 6>$null | Select-Object -Last 1 | Should -Be 0
        Mock Invoke-RestMethod { Get-LpCommonsFixture -Name 'cc-by-sa' }
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'x.jpg' -Key 'zulu' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'x.jpg' -Key 'Zulu' 6>$null | Select-Object -Last 1 | Should -Be 1
        [System.IO.File]::ReadAllText($photosPath) | Should -BeExactly $before
    }

    It 'the audit reads every licence from Commons again and fails on a licence that changed' {
        $fixtureRoot = New-LpGeneratedFixture
        Mock Invoke-RestMethod {
            $fixtureName = if ($Uri -match 'Calling') { 'cc-by' } elseif ($Uri -match 'Abatis') { 'pd' } else { 'cc0' }
            Get-LpCommonsFixture -Name $fixtureName
        }
        Invoke-LpAudit -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        Should -Invoke Invoke-RestMethod -Times 5 -Exactly
        Mock Invoke-RestMethod { Get-LpCommonsFixture -Name 'cc-by-sa' }
        $auditOutput = @(Invoke-LpAudit -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        $auditOutput[-1] | Should -Be '1'
        ($auditOutput -join "`n") | Should -Match 'Commons now refuses it'
    }

    It 'the audit warns about a licence read more than 180 days ago' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixturePhotos -Root $fixtureRoot -Change { param($s) $s.photos[0].fetched = '2020-01-01' }
        Mock Invoke-RestMethod {
            $fixtureName = if ($Uri -match 'Calling') { 'cc-by' } elseif ($Uri -match 'Abatis') { 'pd' } else { 'cc0' }
            Get-LpCommonsFixture -Name $fixtureName
        }
        $auditOutput = @(Invoke-LpAudit -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        $auditOutput[-1] | Should -Be '0'
        ($auditOutput -join "`n") | Should -Match 'photo alpha: licence recorded from Commons on 2020-01-01, over 180 days ago'
    }
}

Describe 'Portrait rounds and the owner''s review, without ComfyUI' {
    It 'gives round n the seeds 4n-3 to 4n' {
        Get-LpRoundSeeds -Round 1 | Should -Be @(1, 2, 3, 4)
        Get-LpRoundSeeds -Round 3 | Should -Be @(9, 10, 11, 12)
    }

    It 'records a pick on the latest round and copies that candidate with its hash' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'alpha_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Pick 3 6>$null | Select-Object -Last 1 | Should -Be 0
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        $entry.rounds[0].decision.pick | Should -Be 3
        $entry.chosen.round | Should -Be 1
        $entry.chosen.seed | Should -Be 3
        $entry.chosen.file | Should -Be 'source/testland/portraits/alpha_leader.png'
        $chosenPath = Join-Path $fixtureRoot 'source\testland\portraits\alpha_leader.png'
        [System.IO.File]::ReadAllText($chosenPath) | Should -Be 'review alpha_leader 3'
        $entry.chosen.sha256 | Should -Be (Get-LpSha256 -Path $chosenPath)
        @(Test-LpPortraitRecords -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') | Where-Object { $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
    }

    It 'records a rejection with its reason and refuses a second decision on the same round' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'bravo_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'bravo_leader' -Reject ' wrong cap: he wore a field cap ' 6>$null | Select-Object -Last 1 | Should -Be 0
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader'
        $entry.rounds[0].decision.reject | Should -Be 'wrong cap: he wore a field cap'
        $entry.chosen | Should -BeNullOrEmpty
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'bravo_leader' -Pick 2 6>$null | Select-Object -Last 1 | Should -Be 1
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'source\testland\portraits\bravo_leader.png') | Should -BeFalse
    }

    It 'refuses an unknown seed, a changed candidate, both or neither decision, and a leader without rounds' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'alpha_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Pick 9 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Pick 2 -Reject 'no' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'charlie_leader' -Pick 1 6>$null | Select-Object -Last 1 | Should -Be 1
        [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'review\alpha_leader\round-1\A3_s2.png'), 'changed')
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Pick 2 6>$null | Select-Object -Last 1 | Should -Be 1
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').rounds[0].decision | Should -BeNullOrEmpty
    }

    It 'refuses to make portraits where the Manager is missing' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot '' 6>$null | Select-Object -Last 1 | Should -Be 1
    }
}

Describe 'MakePortraits with a stand-in New-HoiPortrait' {
    BeforeEach {
        Remove-Item -Path Env:\LP_STUB_FAIL, Env:\LP_STUB_RUNNING -ErrorAction SilentlyContinue
    }

    AfterAll {
        Remove-Item -Path Env:\LP_STUB_FAIL, Env:\LP_STUB_RUNNING -ErrorAction SilentlyContinue
    }

    It 'makes round 1 with seeds 1 to 4 for every open leader, with the portrait fields and the cached photo' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        @($calls | ForEach-Object { $_.Name }) | Should -Be @('lp_tst_alpha_leader', 'lp_tst_bravo_leader', 'lp_tst_charlie_leader', 'lp_tst_delta_advisor', 'lp_tst_echo_admiral')
        $calls[0].Seeds | Should -Be '1,2,3,4'
        $calls[0].Tag | Should -Be 'TST'
        $calls[0].Headwear | Should -Be 'wearing a soft grey field cap'
        $calls[0].AvoidHeadwear | Should -Be 'peaked cap, helmet'
        $calls[0].Role | Should -Be 'Testland general'
        $calls[0].Photo | Should -Be (Get-LpCacheFilePath -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') -Photo (Get-LpPhotoByKey -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') -PhotoKey 'alpha'))
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        @($entry.rounds).Count | Should -Be 1
        $entry.rounds[0].round | Should -Be 1
        @($entry.rounds[0].seeds) | Should -Be @(1, 2, 3, 4)
        $entry.rounds[0].settings.headwear | Should -Be 'wearing a soft grey field cap'
        @($entry.rounds[0].recipe.steps | ForEach-Object { $_.template }) | Should -Be @('K1', 'A3')
        $entry.rounds[0].recipe.gradeStrength | Should -Be 0.6
        @($entry.rounds[0].candidates).Count | Should -Be 4
        foreach ($candidate in @($entry.rounds[0].candidates)) {
            $candidate.sha256 | Should -Be (Get-LpSha256 -Path $candidate.file)
        }
        $entry.rounds[0].decision | Should -BeNullOrEmpty
        $entry.chosen | Should -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $managerRoot 'status.log') | Should -BeFalse
    }

    It 'passes a leader''s colourSeed and facePass to New-HoiPortrait and records them with the round' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].portrait | Add-Member -NotePropertyName 'colourSeed' -NotePropertyValue 7; $s.leaders[0].portrait | Add-Member -NotePropertyName 'facePass' -NotePropertyValue $false }
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        $calls[0].ColourSeed | Should -Be 7
        $calls[0].NoFacePass | Should -BeTrue
        $calls[1].ColourSeed | Should -Be 1
        $calls[1].NoFacePass | Should -BeFalse
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        $entry.rounds[0].settings.colourSeed | Should -Be 7
        $entry.rounds[0].settings.facePass | Should -BeFalse
        $entry.rounds[0].recipe.facePass | Should -BeFalse
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader').rounds[0].settings.facePass | Should -BeTrue
    }

    It 'passes the age from born and photoYear to New-HoiPortrait, records it, and passes none for a leader without the years' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[1].portrait.PSObject.Properties.Remove('born'); $s.leaders[1].portrait.PSObject.Properties.Remove('photoYear') }
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        $calls[0].Age | Should -Be 49
        $calls[1].Age | Should -Be -1
        $alpha = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        $alpha.rounds[0].settings.born | Should -Be 1894
        $alpha.rounds[0].settings.photoYear | Should -Be 1943
        $alpha.rounds[0].settings.age | Should -Be 49
        $alpha.rounds[0].settings.ageSent | Should -BeTrue
        $bravo = Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader'
        foreach ($fieldName in @('born', 'photoYear', 'age')) {
            $bravo.rounds[0].settings.PSObject.Properties[$fieldName] | Should -Not -BeNullOrEmpty
            $bravo.rounds[0].settings.$fieldName | Should -BeNullOrEmpty
        }
        $bravo.rounds[0].settings.ageSent | Should -BeFalse
        $yearWarnings = @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' -and $_.Message -match 'portrait.born or portrait.photoYear is missing' })
        $yearWarnings.Count | Should -Be 1
        ($yearWarnings[0].Where + ' ' + $yearWarnings[0].Message) | Should -Match 'bravo_leader'
    }

    It 'passes no age to a New-HoiPortrait that takes none' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        $managerRoot = New-LpStubManager
        $stubPath = Join-Path $managerRoot 'Scripts\Portraits\New-HoiPortrait.ps1'
        $stubText = [System.IO.File]::ReadAllText($stubPath)
        $stubText = $stubText.Replace("    [int]`$Age = -1,`r`n", '').Replace("    [int]`$Age = -1,`n", '').Replace('; Age = $Age }', ' }')
        [System.IO.File]::WriteAllText($stubPath, $stubText)
        $output = @(Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>&1)
        $output | Select-Object -Last 1 | Should -Be 0
        ($output -join "`n") | Should -Match 'takes no -Age'
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        $calls.Count | Should -BeGreaterThan 0
        $calls[0].PSObject.Properties['Age'] | Should -BeNullOrEmpty
        $settings = (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').rounds[0].settings
        $settings.age | Should -Be 49
        $settings.ageSent | Should -BeFalse
    }

    It 'makes no round for a leader whose colourSeed, facePass, born or photoYear is not valid' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].portrait | Add-Member -NotePropertyName 'colourSeed' -NotePropertyValue 'two'; $s.leaders[1].portrait.born = 'about 1892' }
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 1
        $called = @(Get-LpStubCalls -ManagerRoot $managerRoot | ForEach-Object { $_.Name })
        $called | Should -Not -Contain 'lp_tst_alpha_leader'
        $called | Should -Not -Contain 'lp_tst_bravo_leader'
        $called | Should -Contain 'lp_tst_charlie_leader'
    }

    It 'skips leaders waiting for review, makes round 2 with seeds 5 to 8 after a rejection, and leaves a chosen leader alone' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Out-Null
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Reject 'too young' 6>$null | Out-Null
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'bravo_leader' -Pick 4 6>$null | Out-Null
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        $calls.Count | Should -Be 6
        $calls[5].Name | Should -Be 'lp_tst_alpha_leader'
        $calls[5].Seeds | Should -Be '5,6,7,8'
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        @($entry.rounds | ForEach-Object { $_.round }) | Should -Be @(1, 2)
        $entry.rounds[0].decision.reject | Should -Be 'too young'
        @($entry.rounds[1].candidates | ForEach-Object { $_.seed }) | Should -Be @(5, 6, 7, 8)
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'charlie_leader' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 1
        @(Get-LpStubCalls -ManagerRoot $managerRoot).Count | Should -Be 6
        @(Test-LpPortraitRecords -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') | Where-Object { $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
    }

    It 'with -StartComfyUI starts ComfyUI once for the batch and stops it after an error' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        $managerRoot = New-LpStubManager
        $env:LP_STUB_FAIL = 'bravo_leader'
        $exitCode = Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -StartComfyUI -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1
        $exitCode | Should -Be 2
        @(Get-Content -LiteralPath (Join-Path $managerRoot 'status.log')) | Should -Be @('start', 'stop')
        @(Get-LpStubCalls -ManagerRoot $managerRoot).Count | Should -Be 5
        Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader' | Should -BeNullOrEmpty
        @((Get-LpRecordEntry -Root $fixtureRoot -Leader 'charlie_leader').rounds).Count | Should -Be 1
    }

    It 'with -StartComfyUI leaves a ComfyUI it did not start running' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        $managerRoot = New-LpStubManager
        $env:LP_STUB_RUNNING = '1'
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -StartComfyUI -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        @(Get-Content -LiteralPath (Join-Path $managerRoot 'status.log')) | Should -Be @('start')
    }

    It 'refuses a cached photo whose hash differs from the record' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        Write-LpText -Path (Get-LpCacheFilePath -Pack $packData -Photo (Get-LpPhotoByKey -Pack $packData -PhotoKey 'alpha')) -Text 'changed'
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 1
        @(Get-LpStubCalls -ManagerRoot $managerRoot).Count | Should -Be 0
    }
}

Describe 'MakePortraits against the Manager with its stand-in ComfyUI server' -Skip:(-not $script:HasStandIn) {
    BeforeAll {
        $script:ManagerRoot = $script:Capabilities.ManagerRoot
        $script:StandInRoot = Join-Path $TestDrive 'standin'
        $comfyFolder = Join-Path $script:StandInRoot 'comfy'
        New-Item -ItemType Directory -Path (Join-Path $comfyFolder 'models\RMBG\RMBG-2.0') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $comfyFolder 'models\RMBG\RMBG-2.0\model.safetensors'), 'stand-in')
        $fakeServer = $script:Capabilities.StandInServer
        [System.IO.File]::WriteAllText((Join-Path $comfyFolder 'main.py'), "import runpy, sys`nsys.argv = [r'$fakeServer'] + sys.argv[1:]`nrunpy.run_path(r'$fakeServer', run_name='__main__')`n")
        $nodes = [System.Collections.Generic.List[string]]::new()
        $models = [ordered]@{}
        foreach ($templateName in @('K1', 'M1', 'A3', 'F1')) {
            $template = Read-LpJson -Path (Join-Path $script:ManagerRoot "Scripts\Portraits\workflows\$templateName.json")
            foreach ($node in @($template.requires.nodes)) {
                if (-not $nodes.Contains([string]$node)) { $nodes.Add([string]$node) }
            }
            foreach ($folder in @($template.requires.models.PSObject.Properties.Name | Where-Object { $_ })) {
                if (-not $models.Contains($folder)) { $models[$folder] = [System.Collections.Generic.List[string]]::new() }
                foreach ($modelFile in @($template.requires.models.$folder)) {
                    if (-not $models[$folder].Contains([string]$modelFile)) { $models[$folder].Add([string]$modelFile) }
                }
            }
        }
        $modelLists = [ordered]@{}
        foreach ($folder in $models.Keys) { $modelLists[$folder] = $models[$folder].ToArray() }
        $cataloguePath = Join-Path $script:StandInRoot 'catalogue.json'
        Write-LpJson -Path $cataloguePath -Value ([ordered]@{ nodes = $nodes.ToArray(); models = $modelLists })
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $script:Port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        $listener.Stop()
        $script:Url = "http://127.0.0.1:$($script:Port)"
        $realConfig = Read-LpJson -Path (Join-Path $script:ManagerRoot 'Config\comfyui.json')
        $config = [ordered]@{
            url             = $script:Url
            comfyFolder     = $comfyFolder
            python          = $script:Capabilities.VenvPython
            insightfaceRoot = [string]$realConfig.insightfaceRoot
            launchArguments = [object[]]@('--port', [string]$script:Port, '--catalogue', $cataloguePath, '--log', (Join-Path $script:StandInRoot 'requests.jsonl'))
            workFolder      = Join-Path $script:StandInRoot 'work'
        }
        $script:ConfigPath = Join-Path $script:StandInRoot 'comfyui.json'
        Write-LpJson -Path $script:ConfigPath -Value $config
        $env:HOI_COMFYUI_CONFIG = $script:ConfigPath
    }

    AfterAll {
        foreach ($leftOver in @(Get-CimInstance -ClassName Win32_Process -Filter "Name='python.exe' OR Name='cmd.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('main.py') -and $_.CommandLine -match "--port $($script:Port)(\s|$)" })) {
            Stop-Process -Id $leftOver.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -Path Env:\HOI_COMFYUI_CONFIG -ErrorAction SilentlyContinue
    }

    It 'starts the stand-in server, records round 1 of four candidates from the whole recipe, stops the server, and takes the owner''s pick' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.tag = 'FIN'; $s.prefix = 'lp_fin' }
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        $alphaPhoto = Get-LpPhotoByKey -Pack $packData -PhotoKey 'alpha'
        $cachePath = Get-LpCacheFilePath -Pack $packData -Photo $alphaPhoto
        New-Item -ItemType Directory -Path (Split-Path -Parent $cachePath) -Force | Out-Null
        Invoke-LpTestPython -Python $script:Capabilities.VenvPython -Code 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert(''RGB'').save(sys.argv[2], ''JPEG'', quality=95)' -Arguments @($script:Capabilities.VanillaPortrait, $cachePath) | Out-Null
        Set-LpFixturePhotos -Root $fixtureRoot -Change { param($s) $s.photos[0].downloadSha256 = (Get-LpSha256 -Path $cachePath) }
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -StartComfyUI -ManagerRoot $script:ManagerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        @($entry.rounds).Count | Should -Be 1
        @($entry.rounds[0].candidates | ForEach-Object { $_.seed }) | Should -Be @(1, 2, 3, 4)
        foreach ($candidate in @($entry.rounds[0].candidates)) {
            Test-Path -LiteralPath $candidate.file | Should -BeTrue
            $candidate.sha256 | Should -Be (Get-LpSha256 -Path $candidate.file)
        }
        @($entry.rounds[0].recipe.steps | ForEach-Object { $_.template }) | Should -Be @('K1', 'M1', 'A3', 'F1')
        $entry.rounds[0].recipe.facePass | Should -BeTrue
        Test-Path -LiteralPath $entry.rounds[0].run | Should -BeTrue
        { Invoke-WebRequest -Uri "$($script:Url)/system_stats" -UseBasicParsing -TimeoutSec 2 } | Should -Throw
        $requests = @(Get-Content -LiteralPath (Join-Path $script:StandInRoot 'requests.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
        @($requests | Where-Object { $_.path -eq '/prompt' -and $_.body.prompt.'3'.inputs.text -match 'wearing a soft grey field cap' }).Count | Should -BeGreaterThan 0
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Pick 3 6>$null | Select-Object -Last 1 | Should -Be 0
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').chosen.seed | Should -Be 3
    }
}

Describe 'Portrait review page' -Skip:(-not $script:HasPillow) {
    BeforeAll {
        $script:Python = $script:Capabilities.PillowPython

        function Set-LpRealCandidateImages {
            param([string]$Root, [string]$Leader, [int]$Round = 1)

            $files = @(Get-ChildItem -LiteralPath (Join-Path $Root "review\$Leader\round-$Round") -Filter 'A3_s*.png' | ForEach-Object FullName)
            Invoke-LpTestPython -Python $script:Python -Code 'import sys; from PIL import Image; [Image.new(''RGB'', (784, 1056), (40 * i % 255, 90, 160)).save(p) for i, p in enumerate(sys.argv[1:])]' -Arguments $files | Out-Null
        }

        function Get-LpPageData {
            param([string]$PagePath)

            $text = [System.IO.File]::ReadAllText($PagePath, [System.Text.Encoding]::UTF8)
            $start = $text.IndexOf('const DATA = ') + 'const DATA = '.Length
            $end = $text.IndexOf(";`nconst COLLECTION", $start)
            return [PSCustomObject]@{ Text = $text; Data = ($text.Substring($start, $end - $start) | ConvertFrom-Json) }
        }
    }

    It 'writes one page with each leader whose latest round awaits review, its candidates as images, and the pack in its title' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'alpha_leader'
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'bravo_leader'
        Set-LpRealCandidateImages -Root $fixtureRoot -Leader 'alpha_leader'
        Set-LpRealCandidateImages -Root $fixtureRoot -Leader 'bravo_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'bravo_leader' -Reject 'wrong cap' 6>$null | Out-Null
        @(Invoke-LpReviewPage -RepoRoot $fixtureRoot -Pack 'testland' 6>$null)[-1] | Should -Be 0
        $page = Get-LpPageData -PagePath (Join-Path $fixtureRoot 'scratch\review\testland\portrait-review.html')
        $page.Text | Should -Match ([regex]::Escape('<title>Portrait Review: Testland</title>'))
        @($page.Data.leaders).Count | Should -Be 1
        $page.Data.leaders[0].key | Should -Be 'alpha_leader'
        $page.Data.leaders[0].round | Should -Be 1
        $page.Data.leaders[0].credit | Should -BeLike 'Photo: *'
        $page.Data.leaders[0].creditUrl | Should -BeLike 'https://commons.wikimedia.org/wiki/File:*'
        @($page.Data.leaders[0].candidates | ForEach-Object { $_.seed }) | Should -Be @(1, 2, 3, 4)
        foreach ($candidate in @($page.Data.leaders[0].candidates)) {
            $candidate.game | Should -Match '^data:image/png;base64,'
            $candidate.view | Should -Match '^data:image/jpeg;base64,'
        }
    }

    It 'shows the previous round''s rejection beside the new round' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'alpha_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Reject 'face too young </script>' 6>$null | Out-Null
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'alpha_leader' -Round 2
        Set-LpRealCandidateImages -Root $fixtureRoot -Leader 'alpha_leader' -Round 2
        @(Invoke-LpReviewPage -RepoRoot $fixtureRoot -Pack 'testland' 6>$null)[-1] | Should -Be 0
        $page = Get-LpPageData -PagePath (Join-Path $fixtureRoot 'scratch\review\testland\portrait-review.html')
        $page.Data.leaders[0].round | Should -Be 2
        @($page.Data.leaders[0].candidates | ForEach-Object { $_.seed }) | Should -Be @(5, 6, 7, 8)
        $page.Data.leaders[0].previous | Should -Be 'rejected, "face too young </script>"'
        $page.Text | Should -Not -Match ([regex]::Escape('too young </script>'))
    }

    It 'writes no page when no round awaits review' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        @(Invoke-LpReviewPage -RepoRoot $fixtureRoot -Pack 'testland' 6>$null)[-1] | Should -Be 0
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'scratch\review\testland\portrait-review.html') | Should -BeFalse
    }

    It 'records the published page address and refuses an address that is not a claude.ai artifact' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        foreach ($badUrl in @('https://example.com/page', 'https://example.com/artifact/abc', 'https://claude.ai.example.com/artifact/abc', 'http://claude.ai/artifact/abc', 'https://claude.ai/artifact/abc/extra', "https://claude.ai/artifact/abc`n", 'https://claude.ai/chat/abc', 'HTTPS://CLAUDE.AI/artifact/abc')) {
            @(Invoke-LpReviewPage -RepoRoot $fixtureRoot -Pack 'testland' -PageUrl $badUrl 6>$null)[-1] | Should -Be 1 -Because $badUrl
        }
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'source\testland\review.json') | Should -BeFalse
        @(Invoke-LpReviewPage -RepoRoot $fixtureRoot -Pack 'testland' -PageUrl 'https://claude.ai/code/artifact/0b6f2c1e-4d7a-4e3b-9a51-2f8c7d6e5a40' 6>$null)[-1] | Should -Be 0
        @(Invoke-LpReviewPage -RepoRoot $fixtureRoot -Pack 'testland' -PageUrl 'https://claude.ai/artifact/Ft7qidFCUXJ99yTiMX4f1K' 6>$null)[-1] | Should -Be 0
        (Read-LpJson -Path (Join-Path $fixtureRoot 'source\testland\review.json')).pageUrl | Should -Be 'https://claude.ai/artifact/Ft7qidFCUXJ99yTiMX4f1K'
    }

    It 'names each decision document by leader key and round in the reviews collection, as the skills read them' {
        $template = [System.IO.File]::ReadAllText((Join-Path $script:LpRepoRoot 'tools\review-page-template.html'), [System.Text.Encoding]::UTF8)
        $template | Should -Match ([regex]::Escape('const COLLECTION = "reviews";'))
        $template | Should -Match ([regex]::Escape('const docId = leader => `${leader.key}-r${leader.round}`;'))
        $template | Should -Match ([regex]::Escape('leader: leader.key, round: leader.round, decision: choice.decision, seed: choice.seed, reason: choice.reason, decidedAt:'))
    }
}

Describe 'Review page script with a stand-in store' -Skip:(-not $script:HasNode) {
    It 'lets the owner decide when the store <Mode>' -TestCases @(
        @{ Mode = 'answers'; Argument = 'ok'; Store = 'Connected. Decisions are saved as you make them.' }
        @{ Mode = 'refuses the read'; Argument = 'error'; Store = 'The review store stopped answering: decide, then use Copy decisions.' }
        @{ Mode = 'never answers'; Argument = 'silent'; Store = 'The review store does not answer: decide, then use Copy decisions.' }
    ) {
        param($Mode, $Argument, $Store)

        $checkScript = Join-Path $script:LpRepoRoot 'tests\fixtures\review-page\store-check.mjs'
        $template = Join-Path $script:LpRepoRoot 'tools\review-page-template.html'
        $result = (@(& node $checkScript $template $Argument) -join '') | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 0
        $result.store | Should -Be $Store
        $result.pickEnabled | Should -BeTrue
    }
}

Describe 'Portrait converter' -Skip:(-not $script:HasPillow) {
    BeforeAll {
        $script:Python = $script:Capabilities.PillowPython
        $script:Converter = Join-Path $script:LpRepoRoot 'tools\convert_portraits.py'
        $script:CardPath = Join-Path $script:LpRepoRoot 'data\portrait-card.json'
        $script:Work = Join-Path $TestDrive 'converter'
        New-Item -ItemType Directory -Path $script:Work -Force | Out-Null
        $script:Chosen = Join-Path $script:Work 'chosen.png'
        $script:Window = Join-Path $script:Work 'window.png'
        Invoke-LpTestPython -Python $script:Python -Code 'import sys; from PIL import Image; w, h = 768, 1032; i = Image.new(''RGB'', (w, h)); i.putdata([(x * 255 // w, y * 255 // h, 128) for y in range(h) for x in range(w)]); i.save(sys.argv[1]); j = Image.new(''RGB'', (136, 200)); j.putdata([(x * 255 // 136, 90, y * 255 // 200) for y in range(200) for x in range(136)]); j.save(sys.argv[2])' -Arguments @($script:Chosen, $script:Window) | Out-Null

        function Invoke-LpConverter {
            param([string[]]$ManifestLines)

            $manifestPath = Join-Path $script:Work ([guid]::NewGuid().ToString('N') + '.tsv')
            [System.IO.File]::WriteAllText($manifestPath, (($ManifestLines -join "`n") + "`n"))
            $previousPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $null = & $script:Python -I $script:Converter --manifest $manifestPath --card $script:CardPath 2>&1
                return $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $previousPreference
            }
        }
    }

    It 'writes the large portrait as a 156x210 uncompressed 32-bit DDS' {
        $largePath = Join-Path $script:Work 'large.dds'
        Invoke-LpConverter -ManifestLines @("large`t$($script:Chosen)`t$largePath") | Should -Be 0
        $ddsSize = Get-LpDdsSize -Path $largePath
        $ddsSize.Width | Should -Be 156
        $ddsSize.Height | Should -Be 210
        (Get-Item -LiteralPath $largePath).Length | Should -Be (128 + 156 * 210 * 4)
        $ddsBytes = [System.IO.File]::ReadAllBytes($largePath)
        [System.BitConverter]::ToInt32($ddsBytes, 80) | Should -Be 0x41
        [System.BitConverter]::ToInt32($ddsBytes, 88) | Should -Be 32
    }

    It 'draws the small card as a 65x67 DDS with a transparent corner and an opaque card' {
        $smallPath = Join-Path $script:Work 'small.dds'
        Invoke-LpConverter -ManifestLines @("small`t$($script:Window)`t$smallPath") | Should -Be 0
        $ddsSize = Get-LpDdsSize -Path $smallPath
        $ddsSize.Width | Should -Be 65
        $ddsSize.Height | Should -Be 67
        $ddsBytes = [System.IO.File]::ReadAllBytes($smallPath)
        $ddsBytes[128 + 3] | Should -Be 0 -Because 'the top-left corner is outside the card'
        $ddsBytes[128 + (30 * 65 + 20) * 4 + 3] | Should -Be 255 -Because 'the middle of the photo window is opaque'
    }

    It 'fails a manifest line it cannot convert' {
        Invoke-LpConverter -ManifestLines @("small`t$(Join-Path $script:Work 'missing.png')`t$(Join-Path $script:Work 'x.dds')") | Should -Be 1
    }

    It 'draws the card pixel for pixel like the prototype the owner approved' -Skip:(-not $script:Capabilities.Prototype) {
        $oursPath = Join-Path $script:Work 'ours.png'
        $prototypePath = Join-Path $script:Work 'prototype.png'
        Invoke-LpConverter -ManifestLines @("small`t$($script:Window)`t$oursPath") | Should -Be 0
        Invoke-LpTestPython -Python $script:Python -Code 'import runpy, sys; runpy.run_path(sys.argv[1])[''compose''](sys.argv[2], sys.argv[3])' -Arguments @($script:Capabilities.Prototype, $script:Window, $prototypePath) | Out-Null
        $same = Invoke-LpTestPython -Python $script:Python -Code 'import sys; from PIL import Image; a = Image.open(sys.argv[1]).convert(''RGBA''); b = Image.open(sys.argv[2]).convert(''RGBA''); print(a.size == b.size and a.tobytes() == b.tobytes())' -Arguments @($oursPath, $prototypePath)
        ($same -join '').Trim() | Should -Be 'True'
    }
}

Describe 'ConvertPortraits' -Skip:(-not $script:HasPillow) {
    BeforeAll {
        function New-LpConvertFixture {
            $fixtureRoot = New-LpGeneratedFixture
            $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
            Get-ChildItem -LiteralPath (Join-Path $packData.PackRoot 'gfx') -Recurse -File | Remove-Item
            $chosenSource = Join-Path $fixtureRoot 'chosen-source.png'
            if ($script:Capabilities.VanillaPortrait -and $script:Capabilities.VenvPython) {
                Invoke-LpTestPython -Python $script:Capabilities.VenvPython -Code 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert(''RGB'').resize((768, 1032)).save(sys.argv[2])' -Arguments @($script:Capabilities.VanillaPortrait, $chosenSource) | Out-Null
            } else {
                Invoke-LpTestPython -Python $script:Capabilities.PillowPython -Code 'import sys; from PIL import Image; Image.new(''RGB'', (768, 1032), (120, 100, 80)).save(sys.argv[1])' -Arguments @($chosenSource) | Out-Null
            }
            foreach ($leader in (Get-LpGeneratedLeaders -Pack $packData)) {
                Copy-Item -LiteralPath $chosenSource -Destination (Join-Path $packData.PortraitDir ([string]$leader.key + '.png')) -Force
            }
            $chosenSha = Get-LpSha256 -Path $chosenSource
            Set-LpFixtureRecords -Root $fixtureRoot -Change { param($s) foreach ($property in @($s.leaders.PSObject.Properties)) { $property.Value.chosen.sha256 = $chosenSha } }
            return $fixtureRoot
        }
    }

    AfterEach {
        Remove-Item -Path Env:\HOI_COMFYUI_CONFIG -ErrorAction SilentlyContinue
    }

    It 'without the Manager converts the large portraits and refuses the small cards with exit 1' {
        Remove-Item -Path Env:\HOI_COMFYUI_CONFIG -ErrorAction SilentlyContinue
        $fixtureRoot = New-LpConvertFixture
        $output = @(Invoke-LpConvertPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot '' 6>&1 | ForEach-Object { [string]$_ })
        $output[-1] | Should -Be '1'
        ($output -join "`n") | Should -Match '3 small card\(s\) cannot be made'
        (Get-LpDdsSize -Path (Join-Path $fixtureRoot 'packs\testland\gfx\leaders\TST\lp_tst_echo_admiral.dds')).Width | Should -Be 156
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'packs\testland\gfx\interface\ideas\lp_tst_alpha_leader_small.dds') | Should -BeFalse
        $record = Read-LpJson -Path (Join-Path $fixtureRoot 'source\testland\converted.json')
        @($record.portraits.PSObject.Properties.Name | Sort-Object) | Should -Be @('gfx/leaders/TST/lp_tst_alpha_leader.dds', 'gfx/leaders/TST/lp_tst_bravo_leader.dds', 'gfx/leaders/TST/lp_tst_charlie_leader.dds', 'gfx/leaders/TST/lp_tst_delta_advisor.dds', 'gfx/leaders/TST/lp_tst_echo_admiral.dds')
        $echoEntry = $record.portraits.'gfx/leaders/TST/lp_tst_echo_admiral.dds'
        $echoEntry.ddsSha256 | Should -Be (Get-LpSha256 -Path (Join-Path $fixtureRoot 'packs\testland\gfx\leaders\TST\lp_tst_echo_admiral.dds'))
        $echoEntry.chosenSha256 | Should -Be (Get-LpSha256 -Path (Join-Path $fixtureRoot 'source\testland\portraits\echo_admiral.png'))
        $echoEntry.cardSha256 | Should -Be ''
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'artifacts\portrait-applied-testland.tsv') | Should -BeFalse
        $largePath = Join-Path $fixtureRoot 'packs\testland\gfx\leaders\TST\lp_tst_echo_admiral.dds'
        $firstWrite = (Get-Item -LiteralPath $largePath).LastWriteTimeUtc
        $output = @(Invoke-LpConvertPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot '' 6>&1 | ForEach-Object { [string]$_ })
        ($output -join "`n") | Should -Match '0 portrait file\(s\) converted, 5 up to date'
        (Get-Item -LiteralPath $largePath).LastWriteTimeUtc | Should -Be $firstWrite
        Start-Sleep -Milliseconds 1100
        $output = @(Invoke-LpConvertPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot '' -Force 6>&1 | ForEach-Object { [string]$_ })
        ($output -join "`n") | Should -Match '5 portrait file\(s\) converted, 0 up to date'
        (Get-Item -LiteralPath $largePath).LastWriteTimeUtc | Should -BeGreaterThan $firstWrite
    }

    It 'converts every portrait, skips what is current, converts a card again after a card change, and removes a portrait no leader has' -Skip:(-not $script:HasCardCrop) {
        $fixtureRoot = New-LpConvertFixture
        Write-LpFixtureDds -Path (Join-Path $fixtureRoot 'packs\testland\gfx\leaders\TST\lp_tst_old_leader.dds') -Width 156 -Height 210
        Invoke-LpConvertPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $script:Capabilities.ManagerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        foreach ($expectedFile in (Get-LpExpectedPortraitFiles -Pack $packData)) {
            $ddsSize = Get-LpDdsSize -Path (Join-Path $packData.PackRoot $expectedFile.RelativePath.Replace('/', '\'))
            "$($ddsSize.Width)x$($ddsSize.Height)" | Should -Be "$($expectedFile.Width)x$($expectedFile.Height)" -Because $expectedFile.RelativePath
        }
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'packs\testland\gfx\leaders\TST\lp_tst_old_leader.dds') | Should -BeFalse
        $smallPath = Join-Path $fixtureRoot 'packs\testland\gfx\interface\ideas\lp_tst_alpha_leader_small.dds'
        $firstWrite = (Get-Item -LiteralPath $smallPath).LastWriteTimeUtc
        $output = @(Invoke-LpConvertPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $script:Capabilities.ManagerRoot 6>&1 | ForEach-Object { [string]$_ })
        $output[-1] | Should -Be '0'
        ($output -join "`n") | Should -Match '0 portrait file\(s\) converted, 8 up to date'
        (Get-Item -LiteralPath $smallPath).LastWriteTimeUtc | Should -Be $firstWrite
        @(Get-LpFixtureErrors -Root $fixtureRoot | Where-Object { $_ -match '\.dds|converted\.json' }) | Should -BeNullOrEmpty
        $smallEntry = (Read-LpJson -Path (Join-Path $fixtureRoot 'source\testland\converted.json')).portraits.'gfx/interface/ideas/lp_tst_alpha_leader_small.dds'
        $smallEntry.cardSha256 | Should -Be (Get-LpCardSha -Pack $packData)
        $smallEntry.ddsSha256 | Should -Be (Get-LpSha256 -Path $smallPath)
        Set-LpFixtureJson -Path (Join-Path $fixtureRoot 'data\portrait-card.json') -Change { param($s) $s.note.seed = 8 }
        ((Get-LpFixtureErrors -Root $fixtureRoot) -join "`n") | Should -Match 'lp_tst_alpha_leader_small\.dds: was built with another data/portrait-card\.json'
        $output = @(Invoke-LpConvertPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $script:Capabilities.ManagerRoot 6>&1 | ForEach-Object { [string]$_ })
        ($output -join "`n") | Should -Match '3 portrait file\(s\) converted, 5 up to date'
        @(Get-LpFixtureErrors -Root $fixtureRoot | Where-Object { $_ -match '\.dds|converted\.json' }) | Should -BeNullOrEmpty
    }

    It 'writes PNG previews and a sheet of the converted portraits' {
        $fixtureRoot = New-LpGeneratedFixture
        Export-LpPortraitPreviews -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        $previewDir = Join-Path $fixtureRoot 'scratch\preview\testland'
        @(Get-ChildItem -LiteralPath $previewDir -Filter '*.png' | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @('alpha_leader.png', 'alpha_leader_small.png', 'bravo_leader.png', 'bravo_leader_small.png', 'charlie_leader.png', 'charlie_leader_small.png', 'delta_advisor.png', 'echo_admiral.png', 'sheet.png')
    }
}

Describe 'Packs stand alone' {
    It 'generates two packs side by side with no error and no shared file name' {
        $fixtureRoot = New-LpGeneratedFixture -Packs @('testland', 'otherland')
        Get-LpFixtureErrors -Root $fixtureRoot -Pack 'testland' | Should -BeNullOrEmpty
        Get-LpFixtureErrors -Root $fixtureRoot -Pack 'otherland' | Should -BeNullOrEmpty
        $testlandFiles = @(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'packs\testland') -Recurse -File | Where-Object { $_.Name -notin @('descriptor.mod', 'thumbnail.png', 'WORKSHOP_DESCRIPTION_GUIDELINES.md') })
        $otherlandFiles = @(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'packs\otherland') -Recurse -File | Where-Object { $_.Name -notin @('descriptor.mod', 'thumbnail.png', 'WORKSHOP_DESCRIPTION_GUIDELINES.md') })
        $testlandFiles.Count | Should -BeGreaterThan 10
        foreach ($testlandFile in $testlandFiles) {
            $testlandFile.Name | Should -Match '^lp_tst_'
            [System.IO.File]::ReadAllText($testlandFile.FullName) | Should -Not -Match 'lp_tsu'
        }
        foreach ($otherlandFile in $otherlandFiles) {
            $otherlandFile.Name | Should -Match '^lp_tsu_'
            [System.IO.File]::ReadAllText($otherlandFile.FullName) | Should -Not -Match 'lp_tst'
        }
    }

    It "rejects a pack that names another pack's ids, and a prefix two packs share" {
        $fixtureRoot = New-LpGeneratedFixture -Packs @('testland', 'otherland')
        Set-LpFixtureLeaders -Root $fixtureRoot -Pack 'otherland' -Change { param($s) $s.leaders[0].sameAs = @('lp_tst_alpha_leader') }
        ((Get-LpFixtureErrors -Root $fixtureRoot -Pack 'otherland') -join "`n") | Should -Match "names 'lp_tst' of another pack"
        Set-LpFixtureLeaders -Root $fixtureRoot -Pack 'otherland' -Change { param($s) $s.prefix = 'lp_tst'; $s.leaders[0].sameAs = @() }
        ((Get-LpFixtureErrors -Root $fixtureRoot -Pack 'otherland') -join "`n") | Should -Match "prefix 'lp_tst' is used by another pack"
    }

    It 'creates a new pack beside another, refuses it twice, and refuses a tag another pack has' {
        $fixtureRoot = New-LpGeneratedFixture
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'assets') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'assets\thumbnail_master.png') -Destination (Join-Path $fixtureRoot 'assets\thumbnail_master.png')
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'newland' -Tag 'NEW' -DisplayName 'New Land' 6>$null | Select-Object -Last 1 | Should -Be 0
        $leaderSource = Read-LpJson -Path (Join-Path $fixtureRoot 'source\newland\leaders.json')
        $leaderSource.prefix | Should -Be 'lp_new'
        @($leaderSource.leaders).Count | Should -Be 0
        [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\newland\descriptor.mod')) | Should -Match '(?m)^name="Commanders Pack: New Land"\r?$'
        (Read-LpJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json')).packages.newland.modFolderName | Should -Be 'commanders_pack_newland'
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'packs\newland\thumbnail.png') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'wiki\Commanders-Pack-New-Land.md') | Should -BeTrue
        Get-LpFixtureErrors -Root $fixtureRoot -Pack 'newland' | Should -BeNullOrEmpty
        Get-LpFixtureErrors -Root $fixtureRoot -Pack 'testland' | Should -BeNullOrEmpty
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'newland' -Tag 'NEW' -DisplayName 'New Land' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'twinland' -Tag 'TST' -DisplayName 'Twin' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'badland' -Tag 'bad' -DisplayName 'Bad' 6>$null | Select-Object -Last 1 | Should -Be 1
    }
}

Describe 'Game data snapshot' {
    It 'keeps each character id, name and every role with its slot once' {
        $character = [PSCustomObject]@{
            Id       = 'FIN_test_person'
            Name     = 'Test Person'
            Variants = @(
                [PSCustomObject]@{ Roles = @([PSCustomObject]@{ Kind = 'advisor'; Slot = 'army_chief'; Traits = @('army_chief_defensive_2') }, [PSCustomObject]@{ Kind = 'field_marshal'; Slot = $null; Traits = @('brilliant_strategist') }) },
                [PSCustomObject]@{ Roles = @([PSCustomObject]@{ Kind = 'field_marshal'; Slot = $null; Traits = @('infantry_officer') }) }
            )
        }
        $snapshotCharacter = ConvertTo-LpSnapshotCharacter -Character $character
        $snapshotCharacter.id | Should -Be 'FIN_test_person'
        @($snapshotCharacter.roles | ForEach-Object { $_.kind + '/' + $_.slot }) | Should -Be @('advisor/army_chief', 'field_marshal/')
    }

    It 'keeps the shared start traits and the country traits of the pack''s own tag only' {
        $traitUses = [string[]]@("corps_commander`tGER`tinfantry_officer", "field_marshal`tJAP`tJAP_samurai_lineage", "corps_commander`tFIN`tFIN_winter_war_hero", "navy_leader`tENG`tspotter", "navy_leader`tFIN`tFIN_archipelago_sailor", "advisor`tFIN`tarmy_entrenchment_2", "corps_commander`tEST`tBALTIC_anti_bolshevik")
        $finland = Select-LpStartTraits -TraitUses $traitUses -Tag 'FIN'
        @($finland.army) | Should -Be @('FIN_winter_war_hero', 'infantry_officer')
        @($finland.navy) | Should -Be @('FIN_archipelago_sailor', 'spotter')
        @((Select-LpStartTraits -TraitUses $traitUses -Tag 'EST').army) | Should -Be @('BALTIC_anti_bolshevik', 'infantry_officer')
    }

    It 'refuses to refresh where the Manager is missing' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Invoke-LpRefreshGameData -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot '' 6>$null | Select-Object -Last 1 | Should -Be 1
    }

    It 'writes JSON with four-space indents, empty arrays and strings that hold JSON punctuation' {
        $json = Format-LpJson -Json (ConvertTo-Json -InputObject ([ordered]@{ a = @(); b = [ordered]@{ c = 'x, {y}: [z] "q"' }; d = @(1, 2) }) -Compress -Depth 4)
        $json | Should -Be ("{`r`n    `"a`": [],`r`n    `"b`": {`r`n        `"c`": `"x, {y}: [z] \`"q\`"`"`r`n    },`r`n    `"d`": [`r`n        1,`r`n        2`r`n    ]`r`n}")
        ($json | ConvertFrom-Json).b.c | Should -Be 'x, {y}: [z] "q"'
    }
}

Describe 'This repository' {
    It 'every pack passes the check' {
        $packNames = @(Get-LpPackNames -RepoRoot $script:LpRepoRoot)
        $packNames.Count | Should -BeGreaterThan 0
        foreach ($packName in $packNames) {
            @(Test-LpPack -RepoRoot $script:LpRepoRoot -Pack $packName | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { "$($_.Where): $($_.Message)" }) | Should -BeNullOrEmpty -Because "pack '$packName' must pass build.ps1 -Check"
        }
    }

    It 'every pack has its game snapshot with the vanilla and the Road to 56 characters' {
        foreach ($packName in @(Get-LpPackNames -RepoRoot $script:LpRepoRoot)) {
            $snapshot = Read-LpJson -Path (Join-Path $script:LpRepoRoot "data\$packName\game-characters.json")
            @($snapshot.sets | ForEach-Object { $_.name }) | Should -Be @('vanilla', 'rt56')
            @($snapshot.sets[0].characters).Count | Should -BeGreaterThan 0
        }
    }

    It 'has start traits of its own country for both role kinds in every pack, and a band for every attribute skill' {
        foreach ($packName in @(Get-LpPackNames -RepoRoot $script:LpRepoRoot)) {
            $packData = Get-LpPack -RepoRoot $script:LpRepoRoot -Pack $packName
            $startTraits = Read-LpJson -Path (Join-Path $script:LpRepoRoot "data\$packName\start-traits.json")
            $startTraits.tag | Should -Be $packData.Tag
            @($startTraits.army).Count | Should -BeGreaterThan 10
            @($startTraits.navy).Count | Should -BeGreaterThan 5
            @(@($startTraits.army) + @($startTraits.navy) | Where-Object { $_ -cmatch '^(JAP|POL|BALTIC|INS|IRQ|PRC)_' }) | Should -BeNullOrEmpty -Because 'traits of other countries stay out of a pack'
        }
        Test-Path -LiteralPath (Join-Path $script:LpRepoRoot 'data\start-traits.json') | Should -BeFalse
        $statBands = Read-LpJson -Path (Join-Path $script:LpRepoRoot 'data\stat-bands.json')
        @($statBands.army.PSObject.Properties.Name) | Should -Be @('skill', 'attack', 'defense', 'planning', 'logistics')
        @($statBands.navy.PSObject.Properties.Name) | Should -Be @('skill', 'attack', 'defense', 'maneuvering', 'coordination')
        foreach ($bandProperty in @($statBands.army.PSObject.Properties) + @($statBands.navy.PSObject.Properties)) {
            $band = @($bandProperty.Value)
            @($band).Count | Should -Be 2
            [int]$band[0] | Should -BeLessOrEqual ([int]$band[1])
        }
    }

    It 'keeps the PowerShell tools in ASCII' {
        foreach ($toolPath in @('tools\LeaderPacks.ps1', 'build.ps1', 'tests\LeaderPacks.Fixture.ps1', '.claude\hooks\Protect-ProjectFiles.ps1')) {
            $toolBytes = [System.IO.File]::ReadAllBytes((Join-Path $script:LpRepoRoot $toolPath))
            @($toolBytes | Where-Object { $_ -gt 0x7E }).Count | Should -Be 0 -Because $toolPath
        }
    }
}
