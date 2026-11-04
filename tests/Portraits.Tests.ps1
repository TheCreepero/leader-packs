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

    It 'withdraws the record of a leader who left the pack: keeps the rounds, clears the pick and its PNG, and -Check passes without the warning' {
        $fixtureRoot = New-LpGeneratedFixture
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'zulu_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Pick 1 6>$null | Select-Object -Last 1 | Should -Be 0
        $chosenPath = Join-Path $fixtureRoot 'source\testland\portraits\zulu_leader.png'
        $checkOutput = @(Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        $checkOutput[-1] | Should -Be '0'
        (@($checkOutput | Where-Object { $_.StartsWith('  [WARN] ') }) -join "`n") | Should -Match ([regex]::Escape('portraits.json zulu_leader: no leader of leaders.json has this key: withdraw the record with build.ps1 -ApplyPortraitReview -Pack testland -Leader zulu_leader -Withdraw "<reason>"'))
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw ' photo licence refused ' 6>$null | Select-Object -Last 1 | Should -Be 0
        Test-Path -LiteralPath $chosenPath | Should -BeFalse
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'zulu_leader'
        $entry.chosen | Should -BeNullOrEmpty
        @($entry.rounds).Count | Should -Be 1
        $entry.rounds[0].decision.pick | Should -Be 1
        @($entry.rounds[0].candidates).Count | Should -Be 4
        $entry.rounds[0].withdrawn.reason | Should -Be 'photo licence refused'
        $entry.rounds[0].withdrawn.date | Should -Match '^\d{4}-\d{2}-\d{2}$'
        $checkOutput = @(Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        $checkOutput[-1] | Should -Be '0'
        @($checkOutput | Where-Object { $_ -like '*zulu_leader*' }) | Should -BeNullOrEmpty
    }

    It 'refuses to withdraw a leader still in leaders.json, an undecided round, a blank reason, a second withdrawal and two decisions at once' {
        $fixtureRoot = New-LpGeneratedFixture
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Withdraw 'dropped' 6>$null | Select-Object -Last 1 | Should -Be 1
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'source\testland\portraits\alpha_leader.png') | Should -BeTrue
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').chosen.seed | Should -Be 2
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw 'dropped' 6>$null | Select-Object -Last 1 | Should -Be 1
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'zulu_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw 'dropped' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Reject 'stains on the photo' 6>$null | Select-Object -Last 1 | Should -Be 0
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw '  ' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Reject 'no' -Withdraw 'dropped' 6>$null | Select-Object -Last 1 | Should -Be 1
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'zulu_leader').rounds[0].withdrawn | Should -BeNullOrEmpty
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw 'swapped out' 6>$null | Select-Object -Last 1 | Should -Be 0
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw 'again' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Pick 2 6>$null | Select-Object -Last 1 | Should -Be 1
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'zulu_leader'
        $entry.rounds[0].decision.reject | Should -Be 'stains on the photo'
        $entry.rounds[0].withdrawn.reason | Should -Be 'swapped out'
    }

    It 'keeps a withdrawal as history when the leader returns with a new round and a pick' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'zulu_leader'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Pick 1 6>$null | Out-Null
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Withdraw 'photo licence refused' 6>$null | Out-Null
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $returning = $s.leaders[0] | ConvertTo-Json -Depth 8 | ConvertFrom-Json; $returning.key = 'zulu_leader'; $s.leaders += $returning }
        $returningLeader = @((Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland').Leaders | Where-Object { $_.key -eq 'zulu_leader' })[0]
        Get-LpPortraitState -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') -Leader $returningLeader | Should -Be 'round 1 withdrawn'
        Add-LpUndecidedRound -Root $fixtureRoot -Leader 'zulu_leader' -Round 2
        $reviewLeaders = Get-LpReviewLeaders -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        $reviewLeader = @($reviewLeaders | Where-Object { $_['key'] -eq 'zulu_leader' })[0]
        $reviewLeader['previous'] | Should -Be 'withdrawn, "photo licence refused"'
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'zulu_leader' -Pick 6 6>$null | Select-Object -Last 1 | Should -Be 0
        $entry = Get-LpRecordEntry -Root $fixtureRoot -Leader 'zulu_leader'
        $entry.rounds[0].withdrawn.reason | Should -Be 'photo licence refused'
        $entry.chosen.round | Should -Be 2
        $entry.chosen.seed | Should -Be 6
        @(Test-LpPortraitRecords -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') | Where-Object { $_.Where -like '*zulu_leader*' }) | Should -BeNullOrEmpty
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
        @($entry.rounds[0].recipe.steps | ForEach-Object { $_.template }) | Should -Be @('K1', 'A4')
        $entry.rounds[0].recipe.finish.style | Should -Be 'style-TST.json'
        $entry.rounds[0].recipe.framing.centreBlend | Should -Be 0.5
        $entry.rounds[0].recipe.PSObject.Properties['uniformColour'] | Should -Not -BeNullOrEmpty
        $entry.rounds[0].recipe.uniformColour | Should -BeNullOrEmpty
        $entry.rounds[0].settings.uniformColour | Should -Be ''
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

    It 'passes a leader''s uniformColour to New-HoiPortrait, records it, and refuses one that is not a palette key' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Set-LpFixtureCache -Root $fixtureRoot
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].portrait | Add-Member -NotePropertyName 'uniformColour' -NotePropertyValue 'fra_army_horizon_blue' }
        $managerRoot = New-LpStubManager
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        $calls[0].UniformColour | Should -Be 'fra_army_horizon_blue'
        $calls[1].UniformColour | Should -Be ''
        $alpha = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        $alpha.rounds[0].settings.uniformColour | Should -Be 'fra_army_horizon_blue'
        $alpha.rounds[0].recipe.uniformColour.key | Should -Be 'fra_army_horizon_blue'
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader').rounds[0].recipe.uniformColour | Should -BeNullOrEmpty
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[2].portrait | Add-Member -NotePropertyName 'uniformColour' -NotePropertyValue 'Horizon Blue' }
        ((Get-LpFixtureErrors -Root $fixtureRoot) -join "`n") | Should -Match 'portrait\.uniformColour must be a palette key'
        Invoke-LpMakePortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'charlie_leader' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 1
        @(Get-LpStubCalls -ManagerRoot $managerRoot | Where-Object { $_.Name -eq 'lp_tst_charlie_leader' }).Count | Should -Be 1 -Because 'the first batch made his round; the bad key stops the second'
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

Describe 'RefinishPortraits with a stand-in New-HoiPortrait' {
    BeforeEach {
        Remove-Item -Path Env:\LP_STUB_FAIL, Env:\LP_STUB_RUNNING -ErrorAction SilentlyContinue
    }

    It 'refinishes every chosen portrait from its saved round, writes the plan and changes nothing until -Apply' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        $alphaRound = Add-LpFinishedRound -Root $fixtureRoot -Leader 'alpha_leader' -Seed 2
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'bravo_leader' -Seed 3 -NoFacePass | Out-Null
        $managerRoot = New-LpStubManager
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        $chosenBefore = Get-LpSha256 -Path (Join-Path $packData.PortraitDir 'alpha_leader.png')
        $output = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $output[-1] | Should -Be '0'
        ($output -join "`n") | Should -Match 'charlie_leader: no chosen portrait'
        $calls = @(Get-LpStubCalls -ManagerRoot $managerRoot)
        $calls.Count | Should -Be 2
        $calls[0].Refinish | Should -BeTrue
        $calls[0].Candidate | Should -Be (Join-Path $alphaRound 'face-pasted\A4_s2.png')
        $calls[1].Candidate | Should -BeLike '*\bravo_leader\round-1\paint\A4_s3.png' -Because 'a round without the face pass keeps its candidates under paint'
        $plan = Read-LpJson -Path (Join-Path $fixtureRoot 'scratch\refinish\testland\refinish.json')
        @($plan.portraits | ForEach-Object { $_.leader }) | Should -Be @('alpha_leader', 'bravo_leader')
        $plan.portraits[0].final | Should -Be (Join-Path $alphaRound 'refinish-1\final\A4_s2.png')
        $plan.portraits[0].fromSha256 | Should -Be $chosenBefore
        $plan.portraits[0].sha256 | Should -Be (Get-LpSha256 -Path $plan.portraits[0].final)
        $plan.portraits[0].finishAfter.median | Should -Be 45
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'scratch\refinish\testland\after-run.json') | Should -BeTrue
        (Get-LpSha256 -Path (Join-Path $packData.PortraitDir 'alpha_leader.png')) | Should -Be $chosenBefore
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').chosen.refinished | Should -BeNullOrEmpty
        $applyOutput = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $applyOutput[-1] | Should -Be '0'
        [System.IO.File]::ReadAllText((Join-Path $packData.PortraitDir 'alpha_leader.png')) | Should -Be 'refinished pasted alpha_leader 2'
        $alpha = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        $alpha.chosen.sha256 | Should -Be (Get-LpSha256 -Path (Join-Path $packData.PortraitDir 'alpha_leader.png'))
        $alpha.chosen.refinished.candidateSha256 | Should -Be $chosenBefore
        $alpha.chosen.refinished.run | Should -Be (Join-Path $alphaRound 'refinish-1\refinish-run.json')
        $alpha.chosen.refinished.date | Should -Match '^\d{4}-\d{2}-\d{2}$'
        $alpha.chosen.round | Should -Be 1
        $alpha.chosen.seed | Should -Be 2
        @(Test-LpPortraitRecords -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') | Where-Object { $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty -Because 'the check compares the round''s candidate with the SHA-256 as picked'
        $secondApply = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $secondApply[-1] | Should -Be '1'
        ($secondApply -join "`n") | Should -Match 'changed since the refinish was made'
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Apply -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $alphaAgain = Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader'
        $alphaAgain.chosen.refinished.candidateSha256 | Should -Be $chosenBefore -Because 'a second refinish keeps the SHA-256 of the candidate as picked'
        $alphaAgain.chosen.refinished.run | Should -Be (Join-Path $alphaRound 'refinish-2\refinish-run.json')
        @(Test-LpPortraitRecords -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') | Where-Object { $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
    }

    It '-Check refuses a refinished record whose candidate hash, run or date is wrong' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'alpha_leader' | Out-Null
        $managerRoot = New-LpStubManager
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Out-Null
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        @(Get-LpFixtureErrors -Root $fixtureRoot | Where-Object { $_ -match 'portraits\.json' }) | Should -BeNullOrEmpty
        Set-LpFixtureRecords -Root $fixtureRoot -Change { param($s) $s.leaders.alpha_leader.chosen.refinished.candidateSha256 = 'deadbeef' }
        ((Get-LpFixtureErrors -Root $fixtureRoot) -join "`n") | Should -Match 'alpha_leader: the chosen portrait is not the candidate recorded in its round'
        Set-LpFixtureRecords -Root $fixtureRoot -Change { param($s) $s.leaders.alpha_leader.chosen.refinished.candidateSha256 = (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').rounds[0].candidates[1].sha256; $s.leaders.alpha_leader.chosen.refinished.run = '' }
        ((Get-LpFixtureErrors -Root $fixtureRoot) -join "`n") | Should -Match 'alpha_leader: the refinish record names no run'
        Set-LpFixtureRecords -Root $fixtureRoot -Change { param($s) $s.leaders.alpha_leader.chosen.refinished.run = 'C:\somewhere\refinish-run.json'; $s.leaders.alpha_leader.chosen.refinished.date = 'yesterday' }
        ((Get-LpFixtureErrors -Root $fixtureRoot) -join "`n") | Should -Match 'alpha_leader: the refinish record has no yyyy-MM-dd date'
        Set-LpFixtureRecords -Root $fixtureRoot -Change { param($s) $s.leaders.alpha_leader.chosen.refinished.date = '2026-11-03' }
        @(Get-LpFixtureErrors -Root $fixtureRoot | Where-Object { $_ -match 'portraits\.json' }) | Should -BeNullOrEmpty
    }

    It '-Apply refuses a refinished file that changed and applies only the named leader' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'alpha_leader' | Out-Null
        $bravoRound = Add-LpFinishedRound -Root $fixtureRoot -Leader 'bravo_leader'
        $managerRoot = New-LpStubManager
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        $bravoBefore = Get-LpSha256 -Path (Join-Path $packData.PortraitDir 'bravo_leader.png')
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -Leader 'alpha_leader' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').chosen.refinished | Should -Not -BeNullOrEmpty
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader').chosen.refinished | Should -BeNullOrEmpty
        (Get-LpSha256 -Path (Join-Path $packData.PortraitDir 'bravo_leader.png')) | Should -Be $bravoBefore
        [System.IO.File]::WriteAllText((Join-Path $bravoRound 'refinish-1\final\A4_s2.png'), 'tampered')
        $output = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -Leader 'bravo_leader' -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $output[-1] | Should -Be '1'
        ($output -join "`n") | Should -Match 'bravo_leader: the refinished file .* is gone or changed'
        (Get-LpSha256 -Path (Join-Path $packData.PortraitDir 'bravo_leader.png')) | Should -Be $bravoBefore
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'bravo_leader').chosen.refinished | Should -BeNullOrEmpty
    }

    It 'skips a leader whose round folder is gone, refuses a changed chosen portrait, and refuses to apply without a plan' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        $alphaRound = Add-LpFinishedRound -Root $fixtureRoot -Leader 'alpha_leader'
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'bravo_leader' | Out-Null
        $managerRoot = New-LpStubManager
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 1
        Remove-Item -LiteralPath (Join-Path $alphaRound 'photo.png')
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        [System.IO.File]::WriteAllText((Join-Path $packData.PortraitDir 'bravo_leader.png'), 'edited by hand')
        $output = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $output[-1] | Should -Be '1'
        ($output -join "`n") | Should -Match 'alpha_leader: .*photo\.png is gone'
        ($output -join "`n") | Should -Match 'bravo_leader: the chosen portrait is missing or differs'
        @(Get-LpStubCalls -ManagerRoot $managerRoot).Count | Should -Be 0
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot '' 6>$null | Select-Object -Last 1 | Should -Be 1
    }

    It 'with -StartComfyUI starts ComfyUI once for the batch and stops it, and warns when a mask came from the photo' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'alpha_leader' | Out-Null
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'bravo_leader' | Out-Null
        $managerRoot = New-LpStubManager
        $output = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $output[-1] | Should -Be '0'
        ($output -join "`n") | Should -Match '\[WARN\] the person mask came from the photo for alpha_leader, bravo_leader'
        (Read-LpJson -Path (Join-Path $fixtureRoot 'scratch\refinish\testland\refinish.json')).portraits[0].maskSource | Should -Be 'photo'
        Test-Path -LiteralPath (Join-Path $managerRoot 'status.log') | Should -BeFalse
        $applyOutput = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -Apply -Leader 'bravo_leader' -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        $applyOutput[-1] | Should -Be '0'
        ($applyOutput -join "`n") | Should -Match "\[WARN\] bravo_leader: this refinish composited behind the photo's mask"
        Remove-Item -LiteralPath (Join-Path $fixtureRoot 'review\alpha_leader\round-1\mask\M1_s1.png')
        $env:LP_STUB_RUNNING = '1'
        try {
            $output = @(Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -StartComfyUI -ManagerRoot $managerRoot 6>&1 | ForEach-Object { [string]$_ })
        } finally {
            Remove-Item -Path Env:\LP_STUB_RUNNING -ErrorAction SilentlyContinue
        }
        $output[-1] | Should -Be '0'
        ($output -join "`n") | Should -Not -Match 'mask came from the photo'
        @(Get-Content -LiteralPath (Join-Path $managerRoot 'status.log')) | Should -Be @('start') -Because 'a ComfyUI it did not start is left running'
        (Read-LpJson -Path (Join-Path $fixtureRoot 'scratch\refinish\testland\refinish.json')).portraits[0].maskSource | Should -Be 'candidate'
        Remove-Item -LiteralPath (Join-Path $managerRoot 'status.log')
        $env:LP_STUB_MASKED = '1'
        try {
            Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -StartComfyUI -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 0
        } finally {
            Remove-Item -Path Env:\LP_STUB_MASKED -ErrorAction SilentlyContinue
        }
        @(Get-Content -LiteralPath (Join-Path $managerRoot 'status.log')) | Should -Be @('start', 'stop')
    }

    It 'reports a TOOL FAILURE of the Manager with exit 2 and goes on with the next leader' {
        $fixtureRoot = New-LpFixtureRepo -NoPortraits
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'alpha_leader' | Out-Null
        Add-LpFinishedRound -Root $fixtureRoot -Leader 'bravo_leader' | Out-Null
        $managerRoot = New-LpStubManager
        $env:LP_STUB_FAIL = 'alpha_leader'
        Invoke-LpRefinishPortraits -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null | Select-Object -Last 1 | Should -Be 2
        $plan = Read-LpJson -Path (Join-Path $fixtureRoot 'scratch\refinish\testland\refinish.json')
        @($plan.portraits | ForEach-Object { $_.leader }) | Should -Be @('bravo_leader')
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

    It 'sharpens the large portrait at the game''s size, so an edge differs from a plain downscale' {
        $edged = Join-Path $script:Work 'edged.png'
        Invoke-LpTestPython -Python $script:Python -Code 'import sys; from PIL import Image; i = Image.new(''RGB'', (768, 1032), (60, 60, 60)); i.paste((200, 200, 200), (384, 0, 768, 1032)); i.save(sys.argv[1])' -Arguments @($edged) | Out-Null
        $largePng = Join-Path $script:Work 'large-check.png'
        Invoke-LpConverter -ManifestLines @("large`t$edged`t$largePng") | Should -Be 0
        $difference = Invoke-LpTestPython -Python $script:Python -Code 'import sys; from PIL import Image, ImageChops; src = Image.open(sys.argv[1]).convert(''RGB''); w, h = src.size; kept = round(h * 156 / 210); left = round((w - kept) / 2); plain = src.crop((left, 0, left + kept, h)).resize((156, 210), Image.LANCZOS); ours = Image.open(sys.argv[2]).convert(''RGB''); print(ours.size == plain.size, max(ImageChops.difference(ours, plain).getextrema(), key=lambda e: e[1])[1], ours.getpixel((10, 10)) == plain.getpixel((10, 10)))' -Arguments @($edged, $largePng)
        $values = @((($difference -join '').Trim() -split ' '))
        $values[0] | Should -Be 'True'
        [int]$values[1] | Should -BeGreaterThan 3 -Because 'the unsharp mask lifts the edge'
        [int]$values[1] | Should -BeLessThan 60 -Because 'and only mildly'
        $values[2] | Should -Be 'True' -Because 'a flat area stays as it was'
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

        function Use-LpStandInFaces {
            $standInRoot = Join-Path $TestDrive 'stand-in-faces'
            $insightfaceRoot = Join-Path $standInRoot 'insightface'
            New-Item -ItemType Directory -Path $insightfaceRoot -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:Capabilities.ManagerRoot 'tests\fixtures\portraits\StandInFaceAnalysis.py') -Destination (Join-Path $insightfaceRoot 'stand-in-analysis.py') -Force
            $configPath = Join-Path $standInRoot 'comfyui.json'
            Write-LpJson -Path $configPath -Value ([ordered]@{ python = $script:Capabilities.VenvPython; insightfaceRoot = $insightfaceRoot })
            $env:HOI_COMFYUI_CONFIG = $configPath
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
        Use-LpStandInFaces
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
