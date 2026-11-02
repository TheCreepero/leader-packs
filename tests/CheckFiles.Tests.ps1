BeforeAll {
    . (Join-Path $PSScriptRoot 'LeaderPacks.Fixture.ps1')
}

Describe 'Check rules' {
    It 'the fixture pack passes the check' {
        $fixtureRoot = New-LpGeneratedFixture
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
        Invoke-LpCheck -RepoRoot $fixtureRoot 6>$null | Select-Object -Last 1 | Should -Be 0
    }

    It 'fails on <Name>' -TestCases @(
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
        $checkOutput = @(Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        $checkOutput[-1] | Should -Be '1'
        (@($checkOutput | Where-Object { $_.StartsWith('  [ERROR] ') }) -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'warns about a new leader whose name matches an advisor not listed in sameAs' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].name = 'Hotel Minister' }
        $warnings = @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' } | ForEach-Object { $_.Message })
        ($warnings -join "`n") | Should -Match "name 'Hotel Minister' matches TST_hotel_minister in vanilla: list it in sameAs"
    }

    It 'warns about a trait Road to 56 does not define and names its counterpart' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].traits = @('trait_engineer') }
        $warnings = @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' } | ForEach-Object { $_.Message })
        ($warnings -join "`n") | Should -Match ([regex]::Escape("trait 'trait_engineer' is not defined on Road to 56, where the leader loses it without an error.log line [CHR-017]: Road to 56 defines 'engineer_trait', whose name holds it: if its definition is the same trait, list both names"))
    }

    It 'warns about a trait Road to 56 does not define and has no counterpart for' {
        $fixtureRoot = New-LpGeneratedFixture
        $seawolfWarnings = @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' -and $_.Message -like "trait 'seawolf'*" })
        $seawolfWarnings.Count | Should -Be 1
        $seawolfWarnings[0].Where | Should -Be 'leader echo_admiral'
        $seawolfWarnings[0].Message | Should -Match 'choose another trait, or accept that the leader lacks it on Road to 56'
    }

    It 'accepts Road to 56''s name for a trait beside the vanilla name, and writes both' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].traits = @('trait_engineer', 'engineer_trait') }
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'ERROR' -or $_.Message -like "*trait_engineer*" -or $_.Message -like "*engineer_trait*" } | ForEach-Object { $_.Message }) | Should -BeNullOrEmpty
        [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\testland\common\characters\lp_tst_characters.txt')) | Should -Match 'traits = \{ trait_engineer engineer_trait \}'
    }

    It 'refuses Road to 56''s name for a trait without the vanilla name' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].traits = @('engineer_trait') }
        (Get-LpFixtureErrors -Root $fixtureRoot) -join "`n" | Should -Match ([regex]::Escape("trait 'engineer_trait' is Road to 56's name for 'trait_engineer': list it only beside 'trait_engineer'"))
    }

    It 'warns when the start traits predate the Road to 56 trait list' {
        $fixtureRoot = New-LpGeneratedFixture
        Set-LpFixtureJson -Path (Join-Path $fixtureRoot 'data\testland\start-traits.json') -Change { param($s) $s.PSObject.Properties.Remove('rt56') }
        $warnings = @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' } | ForEach-Object { "$($_.Where): $($_.Message)" })
        ($warnings -join "`n") | Should -Match ([regex]::Escape('data/testland/start-traits.json: has no Road to 56 trait list'))
        Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
    }

    It 'compares names without accents and case' {
        ConvertTo-LpComparableName -Name ('Hugo ' + [char]0x00D6 + 'sterman') | Should -Be 'hugo osterman'
        ConvertTo-LpComparableName -Name 'Carl-Gustaf  MANNERHEIM' | Should -Be 'carl gustaf mannerheim'
    }
}
