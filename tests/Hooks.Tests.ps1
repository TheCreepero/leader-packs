BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $script:ProtectHook = Join-Path $script:RepoRoot '.claude\hooks\Protect-ProjectFiles.ps1'
    $script:PowerShellExe = (Get-Process -Id $PID).Path

    function Invoke-ProtectHook {
        param([string]$ToolName, [hashtable]$ToolInput)

        $hookJson = ConvertTo-Json -InputObject @{ tool_name = $ToolName; tool_input = $ToolInput } -Depth 4 -Compress
        $previousIn = [Console]::In
        $previousError = [Console]::Error
        $errorWriter = [System.IO.StringWriter]::new()
        try {
            [Console]::SetIn([System.IO.StringReader]::new($hookJson))
            [Console]::SetError($errorWriter)
            $global:LASTEXITCODE = 0
            $null = & $script:ProtectHook -RepoRoot $script:RepoRoot
            $hookExitCode = $global:LASTEXITCODE
            $script:LastHookMessage = $errorWriter.ToString()
        } finally {
            [Console]::SetIn($previousIn)
            [Console]::SetError($previousError)
        }
        return $hookExitCode
    }
}

Describe 'Protect-ProjectFiles hook as Claude Code starts it' {
    It 'refuses a protected edit and allows a plain one from a fresh powershell -File' {
        foreach ($case in @(@{ Path = 'source\finland\photos.json'; Expected = 2 }, @{ Path = 'source\finland\leaders.json'; Expected = 0 })) {
            $hookJson = ConvertTo-Json -InputObject @{ tool_name = 'Write'; tool_input = @{ file_path = (Join-Path $script:RepoRoot $case.Path) } } -Compress
            $previousErrorAction = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $null = $hookJson | & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $script:ProtectHook -RepoRoot $script:RepoRoot 2>&1
                $LASTEXITCODE | Should -Be $case.Expected -Because $case.Path
            } finally {
                $ErrorActionPreference = $previousErrorAction
            }
        }
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
        @{ Path = 'packs\finland\thumbnail.png' },
        @{ Path = 'packs\all\WORKSHOP_DESCRIPTION_GUIDELINES.md' },
        @{ Path = 'packs\all\thumbnail.png' },
        @{ Path = 'packs\all\common\characters\x.txt' },
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
        @{ Path = 'tools\HoiImageSources.ps1' },
        @{ Path = 'source\finland\evidence\svensson.rights.txt' },
        @{ Path = 'tests\ImageSources.Tests.ps1' },
        @{ Path = 'tests\fixtures\image-sources\commons\pd.json' },
        @{ Path = '.agents\skills\leader-pack-create\SKILL.md' }
    ) {
        param($Path)
        Invoke-ProtectHook -ToolName 'Write' -ToolInput @{ file_path = (Join-Path $script:RepoRoot $Path) } | Should -Be 2
    }

    It 'allows an edit of <Path>' -TestCases @(
        @{ Path = 'packs\finland\descriptor.mod' },
        @{ Path = 'packs\all\descriptor.mod' },
        @{ Path = 'source\finland\leaders.json' },
        @{ Path = 'source\finland\fact-sheets.md' },
        @{ Path = 'source\finland\workshop-intro.bbcode' },
        @{ Path = 'source\all\workshop-intro.bbcode' },
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
        @{ Command = 'Set-Content packs\all\WORKSHOP_DESCRIPTION_GUIDELINES.md "a"' },
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
        @{ Command = 'Set-Content tools\HoiImageSources.ps1 x' },
        @{ Command = 'Set-Content source\finland\evidence\svensson.rights.txt x' },
        @{ Command = 'Remove-Item tests\fixtures\image-sources\commons\pd.json' },
        @{ Command = 'Set-Content .agents\skills\leader-pack-create\SKILL.md x' },
        @{ Command = 'Copy-Item scratch\thumbnail\finland\thumbnail.png packs\finland\descriptor.mod' },
        @{ Command = 'Copy-Item scratch\thumbnail\finland\thumbnail.png packs\finland\thumbnail.png' },
        @{ Command = 'Copy-Item -LiteralPath "C:\dev\Hearts of Iron IV Modding Manager\Artifacts\thumbnails\leader-packs\finland\thumbnail.png" -Destination packs\finland\thumbnail.png -Force' },
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

    It 'tells a refused <Tool> statement how to read the file' -TestCases @(
        @{ Tool = 'PowerShell'; Command = 'Set-Content source\finland\photos.json "{}"' },
        @{ Tool = 'Bash'; Command = 'echo x > packs/finland/sound/x.wav' },
        @{ Tool = 'Bash'; Command = "python - <<EOF`nopen('source/finland/portraits.json','w')`nEOF" }
    ) {
        param($Tool, $Command)
        $script:LastHookMessage = ''
        Invoke-ProtectHook -ToolName $Tool -ToolInput @{ command = $Command } | Should -Be 2
        $script:LastHookMessage | Should -BeLike '*writes to a protected path*'
        $script:LastHookMessage.Contains('To read one of these files, use the Read or Grep tool, or `build.ps1 -ListCharacters`.') | Should -BeTrue -Because $script:LastHookMessage
    }

    It 'still refuses a Python read, or a read in a command that also writes: <Command>' -TestCases @(
        @{ Command = 'python -I -c "import json; print(len(json.load(open(''source/finland/photos.json''))))"' },
        @{ Command = 'Get-Content source\finland\photos.json -Raw | ConvertFrom-Json | Export-Csv scratch\x.csv' }
    ) {
        param($Command)
        $script:LastHookMessage = ''
        Invoke-ProtectHook -ToolName 'PowerShell' -ToolInput @{ command = $Command } | Should -Be 2
        $script:LastHookMessage | Should -BeLike '*use the Read or Grep tool*'
    }

    It 'keeps the edit refusal message free of the read hint' {
        $script:LastHookMessage = ''
        Invoke-ProtectHook -ToolName 'Write' -ToolInput @{ file_path = (Join-Path $script:RepoRoot 'source\finland\photos.json') } | Should -Be 2
        $script:LastHookMessage | Should -BeLike 'source/finland/photos.json is written only by build.ps1 -FetchPhoto*'
        $script:LastHookMessage | Should -Not -BeLike '*ListCharacters*'
    }

    It 'allows the command <Command>' -TestCases @(
        @{ Command = 'powershell -File .\build.ps1 -Generate -Pack finland' },
        @{ Command = 'powershell -File .\build.ps1 -FetchPhoto -Pack finland -File "File:Einar Vihma.jpg" -Key vihma' },
        @{ Command = 'powershell -File .\build.ps1 -MakePortraits -Pack finland -StartComfyUI' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPortraitReview -Pack finland -Leader einar_vihma -Reject "wrong cap: he wore a field cap"' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPortraitReview -Pack finland -Leader einar_vihma -Pick 2' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPortraitReview -Pack finland -Leader einar_vihma -Withdraw "photo licence refused: a re-shot print under PD-self"' },
        @{ Command = 'powershell -File .\build.ps1 -ConvertPortraits -Pack finland -Force' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPlan -Plan docs\plans\2026-11-08-poland-fixes.md' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPlan -Plan docs\plans\2026-11-08-poland-fixes.md -DryRun' },
        @{ Command = 'powershell -File .\build.ps1 -RehearsePlan -Plan docs\plans\2026-11-08-poland-fixes.md' },
        @{ Command = 'powershell -File .\build.ps1 -ApplyPlan -Plan "docs\plans\2026-11-08-packs-portraits.json-review.md" -DryRun' },
        @{ Command = 'powershell -File .\build.ps1 -RehearsePlan -Plan docs\plans\2026-11-08-packs\poland-photos.json.md' },
        @{ Command = '.\build.ps1 -Check' },
        @{ Command = 'git status --short -- packs/finland' },
        @{ Command = 'git diff -- source/finland/portraits.json' },
        @{ Command = 'Get-Content source\finland\portraits.json' },
        @{ Command = 'Get-Content data\portrait-card.json' },
        @{ Command = 'Get-Content source\finland\photos.json -Raw | ConvertFrom-Json | Select-Object -First 1' },
        @{ Command = 'powershell -File .\build.ps1 -RefreshGameData -Pack finland' },
        @{ Command = 'git diff -- data/finland/start-traits.json data/finland/game-characters.json source/finland/converted.json' },
        @{ Command = 'Get-ChildItem packs\finland -Recurse 2>$null' },
        @{ Command = 'git add packs/finland source/finland && git commit -m "feat(finland): ten leaders"' },
        @{ Command = 'Copy-Item "C:\dev\Hearts of Iron IV Modding Manager\Artifacts\portraits\lp_fin_x\round-1\sheet.png" scratch\review\x.png' },
        @{ Command = '& "C:\dev\Hearts of Iron IV Modding Manager\Scripts\Showcase\New-HoiThumbnail.ps1" "Leader Packs" -Pack finland -Apply' },
        @{ Command = 'powershell -File "C:\dev\Hearts of Iron IV Modding Manager\Scripts\Showcase\New-HoiThumbnail.ps1" -Path "C:\dev\Hearts of Iron IV Modding Manager\mods\leader-packs" -Pack finland -Apply' }
    ) {
        param($Command)
        Invoke-ProtectHook -ToolName 'PowerShell' -ToolInput @{ command = $Command } | Should -Be 0
    }
}

Describe 'Project settings' {
    It 'asks before an agent reads the pack tools' {
        $settings = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.claude\settings.json') -Raw | ConvertFrom-Json
        @($settings.permissions.ask) | Should -Contain 'Read(tools/LeaderPacks.ps1)'
        @($settings.permissions.ask) | Should -Contain 'Read(tools/HoiModBuild.ps1)'
        @($settings.permissions.ask) | Should -Contain 'Read(tools/HoiImageSources.ps1)'
        @($settings.permissions.ask) | Should -Contain 'PowerShell(*build.ps1*-ConfirmLicence*)'
        @($settings.permissions.ask) | Should -Contain 'Bash(*build.ps1*-ConfirmLicence*)'
    }

    It 'allows every build switch of a pack in both shells' {
        $settings = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.claude\settings.json') -Raw | ConvertFrom-Json
        foreach ($switchName in @('Generate', 'FetchPhoto', 'MakePortraits', 'ReviewPage', 'ApplyPortraitReview', 'ConvertPortraits', 'PreviewPortraits', 'RefreshGameData', 'Check', 'Audit', 'SyncMirrors', 'RenderShowcase', 'ListCharacters', 'ApplyPlan', 'RehearsePlan')) {
            @($settings.permissions.allow) | Should -Contain "PowerShell(powershell -File .\build.ps1 -$switchName*)"
        }
        foreach ($switchName in @('ListCharacters', 'ApplyPlan', 'RehearsePlan')) {
            @($settings.permissions.allow) | Should -Contain "Bash(powershell*build.ps1 -$switchName*)"
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

    It 'prints the Pack and Review page lines of an open plan under its Status line, and skips the template' {
        $fakeRoot = Join-Path $TestDrive 'plan-state-repo'
        $plansDirectory = Join-Path $fakeRoot 'docs\plans'
        New-Item -ItemType Directory -Path $plansDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $plansDirectory '2026-01-01-demo.md') -Value @('# Demo', '', 'Status: IN PROGRESS', 'Pack: demo (DMO, prefix lp_dmo)', 'Kind: new pack', 'Review page: https://example.invalid/review/demo/')
        Set-Content -LiteralPath (Join-Path $plansDirectory '2026-01-02-bare.md') -Value @('# Bare', '', 'Status: READY')
        Set-Content -LiteralPath (Join-Path $plansDirectory 'TEMPLATE-pack.md') -Value @('# Template', '', 'Status: PLANNING', 'Pack: <pack>', 'Review page: <url>')
        $planStateHook = Join-Path $script:RepoRoot '.claude\hooks\Show-PlanState.ps1'
        $hookOutput = @('{}' | & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $planStateHook -RepoRoot $fakeRoot)
        $LASTEXITCODE | Should -Be 0
        $statusIndex = [array]::IndexOf($hookOutput, 'docs/plans/2026-01-01-demo.md: Status: IN PROGRESS')
        $statusIndex | Should -BeGreaterThan -1
        $hookOutput[$statusIndex + 1] | Should -Be '  Pack: demo (DMO, prefix lp_dmo)'
        $hookOutput[$statusIndex + 2] | Should -Be '  Review page: https://example.invalid/review/demo/'
        $bareIndex = [array]::IndexOf($hookOutput, 'docs/plans/2026-01-02-bare.md: Status: READY')
        $bareIndex | Should -BeGreaterThan -1
        $hookOutput[$bareIndex + 1] | Should -Not -BeLike '  Pack:*'
        ($hookOutput -join "`n") | Should -Not -BeLike '*TEMPLATE*'
    }
}
