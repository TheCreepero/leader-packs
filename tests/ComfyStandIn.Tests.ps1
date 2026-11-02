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
        foreach ($templateName in @('K1', 'M1', 'A4', 'F2')) {
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
        $insightfaceRoot = Join-Path $script:StandInRoot 'insightface'
        New-Item -ItemType Directory -Path $insightfaceRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $fakeServer) 'StandInFaceAnalysis.py') -Destination (Join-Path $insightfaceRoot 'stand-in-analysis.py')
        $config = [ordered]@{
            url             = $script:Url
            comfyFolder     = $comfyFolder
            python          = $script:Capabilities.VenvPython
            insightfaceRoot = $insightfaceRoot
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
        @($entry.rounds[0].recipe.steps | ForEach-Object { $_.template }) | Should -Be @('K1', 'M1', 'A4', 'F2')
        $entry.rounds[0].recipe.facePass | Should -BeTrue
        Test-Path -LiteralPath $entry.rounds[0].run | Should -BeTrue
        { Invoke-WebRequest -Uri "$($script:Url)/system_stats" -UseBasicParsing -TimeoutSec 2 } | Should -Throw
        $requests = @(Get-Content -LiteralPath (Join-Path $script:StandInRoot 'requests.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
        @($requests | Where-Object { $_.path -eq '/prompt' -and $_.body.prompt.'3'.inputs.text -match 'wearing a soft grey field cap' }).Count | Should -BeGreaterThan 0
        Invoke-LpApplyPortraitReview -RepoRoot $fixtureRoot -Pack 'testland' -Leader 'alpha_leader' -Pick 3 6>$null | Select-Object -Last 1 | Should -Be 0
        (Get-LpRecordEntry -Root $fixtureRoot -Leader 'alpha_leader').chosen.seed | Should -Be 3
    }
}
