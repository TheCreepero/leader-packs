BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $script:ProtectHook = Join-Path $script:RepoRoot '.claude\hooks\Protect-ProjectFiles.ps1'
    $script:PowerShellExe = (Get-Process -Id $PID).Path

    function Invoke-ProtectHook {
        param([string]$ToolName, [hashtable]$ToolInput)

        $hookJson = ConvertTo-Json -InputObject @{ tool_name = $ToolName; tool_input = $ToolInput } -Depth 4 -Compress
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $null = $hookJson | & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $script:ProtectHook -RepoRoot $script:RepoRoot 2>&1
            $hookExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        return $hookExitCode
    }
}

Describe 'Protect-ProjectFiles hook' {
    It 'refuses an edit of <Path>' -TestCases @(
        @{ Path = 'packs\finland\common\characters\lp_fin_characters.txt' },
        @{ Path = 'packs\finland\common\on_actions\lp_fin_on_actions.txt' },
        @{ Path = 'packs\finland\localisation\english\lp_fin_l_english.yml' },
        @{ Path = 'packs\finland\gfx\leaders\FIN\lp_fin_einar_vihma.dds' },
        @{ Path = 'packs\finland\gfx\interface\ideas\lp_fin_einar_vihma_small.dds' },
        @{ Path = 'packs\finland\interface\lp_fin_portraits.gfx' },
        @{ Path = 'packs\finland\history\x.txt' },
        @{ Path = 'packs\finland\WORKSHOP_DESCRIPTION_GUIDELINES.md' },
        @{ Path = 'source\finland\photos.json' },
        @{ Path = 'source\finland\portraits.json' },
        @{ Path = 'source\finland\portraits\einar_vihma.png' },
        @{ Path = 'source\finland\converted.json' },
        @{ Path = 'source\finland\review.json' },
        @{ Path = 'data\finland\game-characters.json' },
        @{ Path = 'data\finland\start-traits.json' },
        @{ Path = 'data\portrait-card.json' },
        @{ Path = 'wiki\Commanders-Pack-Finland.md' },
        @{ Path = 'tools\HoiModBuild.ps1' },
        @{ Path = 'tests\Run-Tests.ps1' },
        @{ Path = '.agents\skills\leader-pack-create\SKILL.md' }
    ) {
        param($Path)
        Invoke-ProtectHook -ToolName 'Write' -ToolInput @{ file_path = (Join-Path $script:RepoRoot $Path) } | Should -Be 2
    }

    It 'allows an edit of <Path>' -TestCases @(
        @{ Path = 'packs\finland\descriptor.mod' },
        @{ Path = 'packs\finland\thumbnail.png' },
        @{ Path = 'source\finland\leaders.json' },
        @{ Path = 'source\finland\fact-sheets.md' },
        @{ Path = 'source\finland\workshop-intro.bbcode' },
        @{ Path = 'data\stat-bands.json' },
        @{ Path = 'tools\LeaderPacks.ps1' },
        @{ Path = 'docs\plans\2026-11-01-finland-pack.md' },
        @{ Path = 'scratch\rehearsal\packs\finland\common\characters\lp_fin_characters.txt' },
        @{ Path = 'scratch\rehearsal\source\finland\portraits.json' }
    ) {
        param($Path)
        Invoke-ProtectHook -ToolName 'Edit' -ToolInput @{ file_path = (Join-Path $script:RepoRoot $Path) } | Should -Be 0
    }

    It 'refuses the shell write <Command>' -TestCases @(
        @{ Command = 'Set-Content packs\finland\localisation\english\x.yml "a"' },
        @{ Command = 'Set-Content source\finland\photos.json "{}"' },
        @{ Command = 'Set-Content source\finland\portraits.json "{}"' },
        @{ Command = 'Copy-Item "C:\dev\Hearts of Iron IV Modding Manager\Artifacts\portraits\lp_fin_x\round-1\final\A3_s2.png" source\finland\portraits\x.png' },
        @{ Command = 'Set-Location source\finland; Copy-Item a.png portraits\x.png' },
        @{ Command = 'Set-Location packs\finland; Set-Content common\x.txt "x"' },
        @{ Command = '$p="packs\finland"; Set-Content "$p\common\x.txt" x' },
        @{ Command = "python -c `"open('packs/finland/common/x.txt','w').write('x')`"" },
        @{ Command = 'powershell -File .\build.ps1 -Generate; Remove-Item packs\finland\common\on_actions\lp_fin_on_actions.txt' },
        @{ Command = 'echo x > packs/finland/sound/x.wav' },
        @{ Command = 'cp other.json source/finland/photos.json' },
        @{ Command = 'Set-Content source\finland\converted.json "{}"' },
        @{ Command = 'Set-Content source\finland\review.json "{}"' },
        @{ Command = 'Copy-Item scratch\x.json data\finland\game-characters.json' },
        @{ Command = 'Set-Content data\finland\start-traits.json "{}"' },
        @{ Command = '(Get-Content data\portrait-card.json) -replace "4.5", "6" | Set-Content data\portrait-card.json' },
        @{ Command = 'cd packs/finland && rm common/x.txt' },
        @{ Command = 'Copy-Item x.md wiki\Commanders-Pack-Finland.md' },
        @{ Command = 'Set-Content tools\HoiModBuild.ps1 x' },
        @{ Command = 'Remove-Item tests\Run-Tests.ps1' },
        @{ Command = 'Set-Content .agents\skills\leader-pack-create\SKILL.md x' },
        @{ Command = 'Copy-Item scratch\thumbnail\finland\thumbnail.png packs\finland\descriptor.mod' },
        @{ Command = 'Copy-Item scratch\thumbnail\finland\thumbnail.png packs\finland\thumbnail.png; Remove-Item packs\finland\common\x.txt' },
        @{ Command = 'git status $(Remove-Item packs\finland\common\x.txt)' }
    ) {
        param($Command)
        Invoke-ProtectHook -ToolName 'PowerShell' -ToolInput @{ command = $Command } | Should -Be 2
    }

    It 'refuses the Bash write <Command>' -TestCases @(
        @{ Command = '(cd packs/finland && rm common/x.txt)' },
        @{ Command = 'git status & rm source/finland/portraits/x.png' },
        @{ Command = "python - <<EOF`nopen('source/finland/portraits.json','w')`nEOF" }
    ) {
        param($Command)
        Invoke-ProtectHook -ToolName 'Bash' -ToolInput @{ command = $Command } | Should -Be 2
    }

    It 'allows the command <Command>' -TestCases @(
        @{ Command = 'powershell -File .\build.ps1 -Generate -Pack finland' },
        @{ Command = 'powershell -File .\build.ps1 -FetchPhoto -Pack finland -File "File:Einar Vihma.jpg" -Key vihma' },
        @{ Command = 'powershell -File .\build.ps1 -MakePortraits -Pack finland -StartComfyUI' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPortraitReview -Pack finland -Leader einar_vihma -Reject "wrong cap: he wore a field cap"' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPortraitReview -Pack finland -Leader einar_vihma -Pick 2' },
        @{ Command = 'powershell -File .\build.ps1 -ConvertPortraits -Pack finland -Force' },
        @{ Command = '.\build.ps1 -Check' },
        @{ Command = 'git status --short -- packs/finland' },
        @{ Command = 'git diff -- source/finland/portraits.json' },
        @{ Command = 'Get-Content source\finland\portraits.json' },
        @{ Command = 'Get-Content data\portrait-card.json' },
        @{ Command = 'powershell -File .\build.ps1 -RefreshGameData -Pack finland' },
        @{ Command = 'git diff -- data/finland/start-traits.json data/finland/game-characters.json source/finland/converted.json' },
        @{ Command = 'Get-ChildItem packs\finland -Recurse 2>$null' },
        @{ Command = 'git add packs/finland source/finland && git commit -m "feat(finland): ten leaders"' },
        @{ Command = 'Copy-Item "C:\dev\Hearts of Iron IV Modding Manager\Artifacts\portraits\lp_fin_x\round-1\sheet.png" scratch\review\x.png' },
        @{ Command = 'Copy-Item scratch\thumbnail\finland\thumbnail.png packs\finland\thumbnail.png' }
    ) {
        param($Command)
        Invoke-ProtectHook -ToolName 'PowerShell' -ToolInput @{ command = $Command } | Should -Be 0
    }
}

Describe 'Project settings' {
    It 'asks before an agent reads the pack tools and allows every build switch of a pack' {
        $settings = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.claude\settings.json') -Raw | ConvertFrom-Json
        @($settings.permissions.ask) | Should -Contain 'Read(tools/LeaderPacks.ps1)'
        @($settings.permissions.ask) | Should -Contain 'Read(tools/HoiModBuild.ps1)'
        foreach ($switchName in @('Generate', 'FetchPhoto', 'MakePortraits', 'ReviewPage', 'ApplyPortraitReview', 'ConvertPortraits', 'PreviewPortraits', 'RefreshGameData', 'Check', 'Audit', 'SyncMirrors', 'RenderShowcase')) {
            @($settings.permissions.allow) | Should -Contain "PowerShell(powershell -File .\build.ps1 -$switchName*)"
        }
    }
}

Describe 'Show-PlanState hook' {
    It 'prints the plan states and the uncommitted files and exits 0' {
        $planStateHook = Join-Path $script:RepoRoot '.claude\hooks\Show-PlanState.ps1'
        $hookOutput = @('{}' | & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $planStateHook -RepoRoot $script:RepoRoot)
        $LASTEXITCODE | Should -Be 0
        $hookOutput[0] | Should -BeLike 'Plans in docs/plans*'
        $hookOutput | Should -Contain 'Uncommitted files (git status --short):'
    }
}
