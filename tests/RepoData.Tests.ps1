BeforeAll {
    . (Join-Path $PSScriptRoot 'LeaderPacks.Fixture.ps1')
}

Describe 'Workshop descriptions' {
    It 'says nothing about AI in the Workshop description of any pack, in its source or its generated file' {
        $descriptionFiles = @(Get-ChildItem -Path (Join-Path $script:LpRepoRoot 'source') -Filter 'workshop-intro.bbcode' -Recurse -File) + @(Get-ChildItem -Path (Join-Path $script:LpRepoRoot 'packs') -Filter 'WORKSHOP_DESCRIPTION_GUIDELINES.md' -Recurse -File)
        $descriptionFiles.Count | Should -BeGreaterThan 0
        foreach ($descriptionFile in $descriptionFiles) {
            [System.IO.File]::ReadAllText($descriptionFile.FullName) | Should -Not -Match '\bAI\b|AI-assisted|image model|artificial intelligence|ComfyUI' -Because "$($descriptionFile.FullName) is a Workshop description"
        }
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

    It 'every bundle passes the check and holds every pack as a member' {
        $bundleNames = @(Get-LpBundleNames -RepoRoot $script:LpRepoRoot)
        $bundleNames.Count | Should -BeGreaterThan 0
        foreach ($bundleName in $bundleNames) {
            @(Test-LpBundle -RepoRoot $script:LpRepoRoot -Bundle $bundleName | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { "$($_.Where): $($_.Message)" }) | Should -BeNullOrEmpty -Because "bundle '$bundleName' must pass build.ps1 -Check"
        }
        foreach ($packName in @(Get-LpPackNames -RepoRoot $script:LpRepoRoot)) {
            @(Get-LpBundleNames -RepoRoot $script:LpRepoRoot -Member $packName).Count | Should -BeGreaterThan 0 -Because "pack '$packName' must be a member of a bundle"
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
            @(@($startTraits.army) + @($startTraits.navy) | Where-Object { $_ -cmatch '^(JAP|POL|BALTIC|INS|IRQ|PRC)_' -and $_ -cnotmatch ('^' + [regex]::Escape([string]$packData.Tag) + '_') }) | Should -BeNullOrEmpty -Because 'traits of other countries stay out of a pack; the pack''s own tag keeps its own'
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

    It 'every pack passes the showcase check' {
        . (Join-Path $script:LpRepoRoot 'tools\LeaderPacks.Showcase.ps1')
        foreach ($packName in @(Get-LpPackNames -RepoRoot $script:LpRepoRoot)) {
            @(Test-LpShowcaseSource -RepoRoot $script:LpRepoRoot -Pack $packName | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { "$($_.Where): $($_.Message)" }) | Should -BeNullOrEmpty
        }
    }
}
