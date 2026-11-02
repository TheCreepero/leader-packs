BeforeAll {
    . (Join-Path $PSScriptRoot 'LeaderPacks.Fixture.ps1')
}

Describe 'Check rules' {
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
    ) {
        $fixtureRoot = New-LpGeneratedFixture
        & ([scriptblock]::Create($Change.ToString())) $fixtureRoot
        $checkOutput = @(Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        $checkOutput[-1] | Should -Be '1'
        (@($checkOutput | Where-Object { $_.StartsWith('  [ERROR] ') }) -join "`n") | Should -Match ([regex]::Escape($Expected))
    }
}
