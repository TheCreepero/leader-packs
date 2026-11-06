BeforeAll {
    . (Join-Path $PSScriptRoot 'LeaderPacks.Fixture.ps1')
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

    It 'says nothing about AI in the Workshop description of any pack, in its source or its generated file' {
        $descriptionFiles = @(Get-ChildItem -Path (Join-Path $script:LpRepoRoot 'source') -Filter 'workshop-intro.bbcode' -Recurse -File) + @(Get-ChildItem -Path (Join-Path $script:LpRepoRoot 'packs') -Filter 'WORKSHOP_DESCRIPTION_GUIDELINES.md' -Recurse -File)
        $descriptionFiles.Count | Should -BeGreaterThan 0
        foreach ($descriptionFile in $descriptionFiles) {
            [System.IO.File]::ReadAllText($descriptionFile.FullName) | Should -Not -Match '\bAI\b|AI-assisted|image model|artificial intelligence|ComfyUI' -Because "$($descriptionFile.FullName) is a Workshop description"
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
            [regex]::Matches([System.Text.Encoding]::GetEncoding(28591).GetString([byte[]]$bodyBytes), '[\x7F-\xFF\x00-\x08\x0B\x0C\x0E-\x1F]').Count | Should -Be 0 -Because "$relativePath is ASCII"
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

    It 'carries the cross-link block between the markers over when it generates again' {
        $fixtureRoot = New-LpGeneratedFixture
        $descriptionPath = Join-Path $fixtureRoot 'packs\testland\WORKSHOP_DESCRIPTION_GUIDELINES.md'
        $emptyText = [System.IO.File]::ReadAllText($descriptionPath)
        $emptyText | Should -Match '<!-- cross-links:begin -->\r\n<!-- cross-links:end -->'
        $emptyText | Should -Not -Match 'More from the author'
        $filledText = $emptyText.Replace("<!-- cross-links:begin -->`r`n<!-- cross-links:end -->", "<!-- cross-links:begin -->`r`n[b]More[/b] block line one`r`nblock line two`r`n<!-- cross-links:end -->")
        [System.IO.File]::WriteAllText($descriptionPath, $filledText, [System.Text.UTF8Encoding]::new($false))
        $delta = Get-LpGenerationDelta -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        $delta.Changed.Count | Should -Be 0
        $delta.Stale.Count | Should -Be 0
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        [System.IO.File]::ReadAllText($descriptionPath) | Should -Be $filledText
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
    }

    It 'writes the strip regions, no buttons region, and carries what a region holds over when it generates again' {
        $fixtureRoot = New-LpGeneratedFixture
        $introPath = Join-Path $fixtureRoot 'source\testland\workshop-intro.bbcode'
        [System.IO.File]::WriteAllText($introPath, "<!-- region:image:hero -->`r`n<!-- /region -->`r`nFixture commanders for Testland.`r`n`r`n[h1]Info:[/h1]`r`n<!-- region:info:game-version -->`r`n<!-- /region -->`r`n", [System.Text.UTF8Encoding]::new($false))
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        $descriptionPath = Join-Path $fixtureRoot 'packs\testland\WORKSHOP_DESCRIPTION_GUIDELINES.md'
        $emptyText = [System.IO.File]::ReadAllText($descriptionPath)
        $emptyText | Should -Match '(?m)^<!-- region:image:hero -->\r\n<!-- /region -->\r\nFixture commanders'
        $emptyText | Should -Match '(?m)^<!-- region:image:strip-commanders -->\r\n<!-- /region -->\r\n\[h1\]Commanders\[/h1\]'
        $emptyText | Should -Match '(?m)^<!-- region:image:strip-portraits -->\r\n<!-- /region -->\r\n\[h1\]Portraits\[/h1\]'
        $emptyText | Should -Not -Match 'region:buttons'
        $emptyText | Should -Match '(?m)\r\n\r\n<!-- cross-links:begin -->'
        $filledText = $emptyText.Replace("<!-- region:info:game-version -->`r`n<!-- /region -->", "<!-- region:info:game-version -->`r`n- Built for game version 1.19.`r`n<!-- /region -->").Replace("<!-- region:image:strip-portraits -->`r`n<!-- /region -->", "<!-- region:image:strip-portraits -->`r`n[img]https://images.example/strip.png[/img]`r`n<!-- /region -->")
        $filledText | Should -Not -Be $emptyText
        [System.IO.File]::WriteAllText($descriptionPath, $filledText, [System.Text.UTF8Encoding]::new($false))
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        [System.IO.File]::ReadAllText($descriptionPath) | Should -Be $filledText
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
    }

    It 'finds the cross-link markers with spaces or a tab around them and writes them again without' {
        $fixtureRoot = New-LpGeneratedFixture
        $descriptionPath = Join-Path $fixtureRoot 'packs\testland\WORKSHOP_DESCRIPTION_GUIDELINES.md'
        $emptyText = [System.IO.File]::ReadAllText($descriptionPath)
        $paddedText = $emptyText.Replace("<!-- cross-links:begin -->`r`n<!-- cross-links:end -->", "  <!-- cross-links:begin -->  `r`n[b]More[/b] padded block line`r`n`t<!-- cross-links:end -->`t")
        $paddedText | Should -Not -Be $emptyText
        [System.IO.File]::WriteAllText($descriptionPath, $paddedText, [System.Text.UTF8Encoding]::new($false))
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Out-Null
        [System.IO.File]::ReadAllText($descriptionPath) | Should -Match '(?m)^<!-- cross-links:begin -->\r\n\[b\]More\[/b\] padded block line\r\n<!-- cross-links:end -->\r\n```'
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

    It 'accepts CC BY-SA with the licensor''s attribution, and refuses an own-work upload of an old photo in any licence' {
        $shareAlike = Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'cc-by-sa-3.0-de')
        $shareAlike.Accepted | Should -BeTrue -Because $shareAlike.Reason
        $shareAlike.Photo.attribution | Should -Be 'Bundesarchiv, Bild 183-S37772 / CC-BY-SA 3.0'
        (Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'cc-by-sa')).Reason | Should -Match 'own work on a picture dated 1939'
        (Get-LpCommonsVerdict -Response (Get-LpCommonsFixture -Name 'own-cc0-old')).Reason | Should -Match 'own work on a picture dated 1944'
    }

    It 'rejects a missing file, a file tagged for deletion, a public domain without its reason and a picture under 300 px' {
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

    It 'waits and tries again when Wikimedia answers 429 or 503, as long as Retry-After asks' {
        $fixtureRoot = New-LpGeneratedFixture
        $script:DownloadAttempts = 0
        Mock Start-Sleep { }
        Mock Invoke-RestMethod { Get-LpCommonsFixture -Name 'cc-by' }
        Mock Invoke-WebRequest {
            $script:DownloadAttempts++
            if ($script:DownloadAttempts -le 2) {
                $statusCode = if ($script:DownloadAttempts -eq 1) { 429 } else { 503 }
                $exception = [System.Exception]::new('Too many requests')
                Add-Member -InputObject $exception -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = $statusCode; Headers = @{ 'Retry-After' = '30' } })
                throw $exception
            }
            [System.IO.File]::WriteAllText($OutFile, 'photo bytes')
        }
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'x.jpg' -Key 'zulu' 6>$null | Select-Object -Last 1 | Should -Be 0
        $script:DownloadAttempts | Should -Be 3
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 30 }
        Get-LpPhotoByKey -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland') -PhotoKey 'zulu' | Should -Not -BeNullOrEmpty
    }

    It 'gives up after the last attempt and never retries another failure' {
        Mock Start-Sleep { }
        Mock Invoke-RestMethod {
            $exception = [System.Exception]::new('Too many requests')
            Add-Member -InputObject $exception -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = 429; Headers = @{} })
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'WebCmdletWebResponseException', 'InvalidOperation', $null)
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new("<html><body><p>Too many requests -</p>`n<p>use thumbnail steps</p></body></html>")
            throw $errorRecord
        }
        $script:RequestOutput = [System.Collections.Generic.List[string]]::new()
        { Invoke-LpCommonsRequest -Uri 'https://commons.wikimedia.org/w/api.php' -MaxAttempts 3 6>&1 | ForEach-Object { $script:RequestOutput.Add([string]$_) } } | Should -Throw
        Should -Invoke Invoke-RestMethod -Times 3 -Exactly
        @($script:RequestOutput | Where-Object { $_ -eq '  Wikimedia answered 429: Too many requests - use thumbnail steps' }).Count | Should -Be 3
        $script:RequestOutput[-1] | Should -Be '  giving up after 3 attempts'
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 5 }
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 10 }
        Mock Invoke-RestMethod { throw 'not found' }
        { Invoke-LpCommonsRequest -Uri 'https://commons.wikimedia.org/w/api.php' 6>$null } | Should -Throw 'not found'
        Should -Invoke Start-Sleep -Times 2 -Exactly
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

    It 'dates an own-work photo by the photoYear of the leader who uses it, in -FetchPhoto and in -Audit' {
        $fixtureRoot = New-LpGeneratedFixture
        $script:ReshotPrint = Get-LpCommonsFixture -Name 'pd-self-old'
        $script:ReshotPrint.query.pages[0].imageinfo[0].extmetadata.ImageDescription.value = 'A general, photographed from a print in 2008.'
        $script:ReshotPrint.query.pages[0].title = 'File:General portrait.jpg'
        Mock Invoke-RestMethod { $script:ReshotPrint }
        Mock Invoke-WebRequest { throw 'a refused photo is not downloaded' }
        $fetchOutput = @(Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'General portrait.jpg' -Key 'alpha' -DryRun 6>&1 | ForEach-Object { [string]$_ })
        $fetchOutput[-1] | Should -Be '1'
        ($fetchOutput -join "`n") | Should -Match 'own work on a picture dated 1943'
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -File 'General portrait.jpg' -Key 'zulu' -DryRun 6>$null | Select-Object -Last 1 | Should -Be 0
        $auditText = (@(Invoke-LpAudit -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ }) -join "`n")
        $auditText | Should -Match 'photo alpha: Commons now refuses it: own work on a picture dated 1943'
    }

    It 'searches the sources, skips Europeana without a key, and prints the verdicts' {
        $savedKey = [Environment]::GetEnvironmentVariable('HOI_EUROPEANA_WSKEY')
        [Environment]::SetEnvironmentVariable('HOI_EUROPEANA_WSKEY', $null)
        try {
            Mock Get-LpManagerRootText { '' }
            Mock Invoke-RestMethod {
                if ($Uri.AbsoluteUri -like 'https://commons.wikimedia.org/*') {
                    return [PSCustomObject]@{ query = [PSCustomObject]@{ pages = @((Get-LpCommonsFixture -Name 'cc-by-sa-3.0-de').query.pages[0]) } }
                }
                return [PSCustomObject]@{ resultCount = 1; records = @((Get-LpSourceFixture -Source 'finna' -Name 'sa-kuva-cc-by').records[0]) }
            }
            $searchOutput = @(Invoke-LpFindPhoto -Query 'Rundstedt' -Source @('commons', 'finna', 'europeana') -Limit 3 6>&1 | ForEach-Object { [string]$_ })
            $searchOutput[-1] | Should -Be '0'
            ($searchOutput -join "`n") | Should -Match 'Skipping Europeana: no API key for europeana'
            ($searchOutput -join "`n") | Should -Match "Search 'Rundstedt' in commons, finna: 2 acceptable of 2"
            ($searchOutput -join "`n") | Should -Match '\| commons \| File:Bundesarchiv Bild 183-S37772, Gerd v\. Rundstedt\.jpg \|.*\| ACCEPTABLE \|'
            ($searchOutput -join "`n") | Should -Match '\| finna \| sa-kuva\.sa-kuva/111307 \|.*\| ACCEPTABLE, size checked at download \|'
        } finally {
            [Environment]::SetEnvironmentVariable('HOI_EUROPEANA_WSKEY', $savedKey)
        }
    }

    It 'records a Finna photo measured at download, credited to the archive' {
        $fixtureRoot = New-LpGeneratedFixture
        Mock Invoke-RestMethod { Get-LpSourceFixture -Source 'finna' -Name 'sa-kuva-cc-by' }
        Mock Invoke-WebRequest { Write-LpFixtureJpeg -Path $OutFile -Width 400 -Height 520 }
        Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -Source 'finna' -Id 'sa-kuva.sa-kuva/111307' -Key 'zulu' 6>$null | Select-Object -Last 1 | Should -Be 0
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        $photo = Get-LpPhotoByKey -Pack $packData -PhotoKey 'zulu'
        $photo.source | Should -Be 'finna'
        "$($photo.width)x$($photo.height)" | Should -Be '400x520'
        $photo.attribution | Should -Be 'SA-kuva-arkisto'
        $photo.downloadSha256 | Should -Be (Get-LpSha256 -Path (Get-LpCacheFilePath -Pack $packData -Photo $photo))
        @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Where -eq 'photo zulu' -and $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri.AbsoluteUri -match '^https://api\.finna\.fi/api/v1/record\?id=sa-kuva\.sa-kuva%2F111307' }
    }

    It 'records a manual photo with its page captures, and blocks portraits and the check until the owner confirms its licence' {
        $fixtureRoot = New-LpGeneratedFixture
        $script:RightsPageHtml = '<html><body><p>Photographs taken by the army before 1945 are in the public domain and free to reuse.</p></body></html>'
        Mock Invoke-RestMethod {
            if ($Uri.AbsoluteUri -like 'https://commons.wikimedia.org/*') {
                $fixtureName = if ($Uri.AbsoluteUri -match 'Calling') { 'cc-by' } elseif ($Uri.AbsoluteUri -match 'Abatis') { 'pd' } else { 'cc0' }
                return Get-LpCommonsFixture -Name $fixtureName
            }
            if ($Uri.AbsoluteUri -like '*terms*') {
                return $script:RightsPageHtml
            }
            return '<html><body><h1>General X at the front</h1></body></html>'
        }
        Mock Invoke-WebRequest { Write-LpFixtureJpeg -Path $OutFile }
        $evidencePath = Join-Path $fixtureRoot 'scratch\evidence-zulu.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $evidencePath) -Force | Out-Null
        Write-LpJson -Path $evidencePath -Value ([ordered]@{ recordUrl = 'https://archive.example.org/record/42'; imageUrl = 'https://archive.example.org/image/42.jpg'; rightsUrl = 'https://archive.example.org/terms'; rightsQuote = 'Photographs taken by the army before 1945 are in the public domain and free to reuse.'; license = 'pd'; publicDomainReason = 'Army photograph before 1945, archive terms'; author = ''; institution = 'Example Army Archive'; credit = ''; dateOriginal = '1943'; title = 'General X at the front' }) -Depth 3
        $fetchOutput = @(Invoke-LpFetchPhoto -RepoRoot $fixtureRoot -Pack 'testland' -Evidence $evidencePath -Key 'zulu' 6>&1 | ForEach-Object { [string]$_ })
        $fetchOutput[-1] | Should -Be '0'
        ($fetchOutput -join "`n") | Should -Match 'NEEDS OWNER CONFIRMATION'
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'source\testland\evidence\zulu.rights.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $fixtureRoot 'source\testland\evidence\zulu.record.txt') | Should -BeTrue
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].portrait.photo = 'zulu' }
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Where -eq 'photo zulu' -and $_.Level -eq 'ERROR' -and $_.Message -match 'has not confirmed' }).Count | Should -Be 1
        { Get-LpCachedPhoto -Pack $packData -Photo (Get-LpPhotoByKey -Pack $packData -PhotoKey 'zulu') } | Should -Throw '*has not confirmed its licence*'
        Invoke-LpConfirmLicence -RepoRoot $fixtureRoot -Pack 'testland' -Key 'bravo' 6>$null | Select-Object -Last 1 | Should -Be 1
        Invoke-LpConfirmLicence -RepoRoot $fixtureRoot -Pack 'testland' -Key 'zulu' 6>$null | Select-Object -Last 1 | Should -Be 0
        $packData = Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'
        @(Test-LpPack -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Where -eq 'photo zulu' -and $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
        Get-LpCachedPhoto -Pack $packData -Photo (Get-LpPhotoByKey -Pack $packData -PhotoKey 'zulu') | Should -Be (Join-Path $fixtureRoot 'sources-cache\testland\zulu.jpg')
        $auditText = (@(Invoke-LpAudit -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ }) -join "`n")
        $auditText | Should -Match 'photo zulu : the archive page still holds the quoted rights sentence'
        $script:RightsPageHtml = '<html><body>All rights reserved.</body></html>'
        $auditOutput = @(Invoke-LpAudit -RepoRoot $fixtureRoot -Pack 'testland' 6>&1 | ForEach-Object { [string]$_ })
        ($auditOutput -join "`n") | Should -Match 'photo zulu: the quoted rights sentence is gone from https://archive\.example\.org/terms'
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

Describe 'CC BY-SA photos' {
    It 'credits the licensor''s attribution and licenses the portrait CC BY-SA 4.0 on the wiki, the Workshop page and the showcase' {
        . (Join-Path $script:LpRepoRoot 'tools\LeaderPacks.Showcase.ps1')
        $fixtureRoot = New-LpGeneratedFixture
        $shareAlikePhoto = New-LpFixturePhoto -Key 'alpha' -Fixture 'cc-by-sa-3.0-de'
        Set-LpFixturePhotos -Root $fixtureRoot -Change { param($s) $shareAlikePhoto.downloadSha256 = $s.photos[0].downloadSha256; $s.photos[0] = $shareAlikePhoto }
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        $wikiText = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'wiki\Commanders-Pack-Testland.md'))
        $wikiText | Should -Match ([regex]::Escape('| [Bundesarchiv Bild 183-S37772, Gerd v. Rundstedt.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_183-S37772,_Gerd_v._Rundstedt.jpg) | [CC BY-SA 3.0 de](https://creativecommons.org/licenses/by-sa/3.0/de/deed.en), Bundesarchiv, Bild 183-S37772 / CC-BY-SA 3.0 | AI-assisted repaint, licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |'))
        $wikiText | Should -Match ([regex]::Escape('is itself licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), as its row says.'))
        $wikiText | Should -Match ([regex]::Escape('| [Abatis at Taipale.jpg]'))
        $workshopText = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\testland\WORKSHOP_DESCRIPTION_GUIDELINES.md'))
        $workshopText | Should -Match ([regex]::Escape('from Wikimedia Commons, used under licences that allow it'))
        $workshopText | Should -Match ([regex]::Escape('The portraits of Alpha Leader adapt photographs licensed CC BY-SA and are themselves licensed [url=https://creativecommons.org/licenses/by-sa/4.0/]CC BY-SA 4.0[/url].'))
        Get-LpFixtureErrors -Root $fixtureRoot | Should -BeNullOrEmpty
        $alphaCard = @((New-LpShowcaseSpec -RepoRoot $fixtureRoot -Pack 'testland').Spec.pages)[1]
        $alphaCard.note | Should -Be 'Portrait (CC BY-SA 4.0) adapted from a photograph by Bundesarchiv, Bild 183-S37772 / CC-BY-SA 3.0 (CC BY-SA 3.0 de)'
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
        Mock Get-LpManagerRoot { '' }
        $fixtureRoot = New-LpGeneratedFixture
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'assets') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'assets\thumbnail_master.png') -Destination (Join-Path $fixtureRoot 'assets\thumbnail_master.png')
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'newland' -Tag 'NEW' -DisplayName 'New Land' 6>$null | Select-Object -Last 1 | Should -Be 0
        (Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'packs\newland\thumbnail.png')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'assets\thumbnail_master.png')).Hash
        $leaderSource = Read-LpJson -Path (Join-Path $fixtureRoot 'source\newland\leaders.json')
        $leaderSource.prefix | Should -Be 'lp_new'
        @($leaderSource.leaders).Count | Should -Be 0
        [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'source\newland\workshop-intro.bbcode')) | Should -Not -Match '\bAI\b|AI-assisted|image model|artificial intelligence|ComfyUI'
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

    It 'renders a new pack''s thumbnail with the Manager''s New-HoiThumbnail.ps1, and keeps the master when the call fails' {
        $fixtureRoot = New-LpGeneratedFixture
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'assets') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'assets\thumbnail_master.png') -Destination (Join-Path $fixtureRoot 'assets\thumbnail_master.png')
        $script:StubManagerRoot = Join-Path $fixtureRoot 'stub-manager'
        $stubScriptPath = Join-Path $script:StubManagerRoot 'Scripts\Showcase\New-HoiThumbnail.ps1'
        New-Item -ItemType Directory -Path (Split-Path -Parent $stubScriptPath) -Force | Out-Null
        $stubScript = @(
            'param([string]$Path, [string]$Pack, [switch]$Apply, [switch]$PassThru)',
            'if ($Pack -eq ''brokenland'') { throw ''no game'' }',
            '[System.IO.File]::WriteAllText((Join-Path $Path "packs\$Pack\thumbnail.png"), ("rendered " + $Pack + " " + $Apply.IsPresent + " " + $PassThru.IsPresent))',
            '[PSCustomObject]@{ status = ''ok'' }'
        ) -join "`r`n"
        [System.IO.File]::WriteAllText($stubScriptPath, $stubScript + "`r`n")
        Mock Get-LpManagerRoot { $script:StubManagerRoot }
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'newland' -Tag 'NEW' -DisplayName 'New Land' 6>$null | Select-Object -Last 1 | Should -Be 0
        [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\newland\thumbnail.png')) | Should -Be 'rendered newland True True'
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'brokenland' -Tag 'BRK' -DisplayName 'Broken Land' 6>$null | Select-Object -Last 1 | Should -Be 0
        (Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'packs\brokenland\thumbnail.png')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path $fixtureRoot 'assets\thumbnail_master.png')).Hash
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

    It 'lists the start traits vanilla defines and Road to 56 does not, with the one Road to 56 trait named after each' {
        $rt56Traits = Select-LpRt56Traits -StartTraits @('jaeger', 'infantry_officer', 'seawolf', 'trait_cautious', 'never_defined') -VanillaTraits @('jaeger', 'infantry_officer', 'seawolf', 'trait_cautious', 'CHI_watched_officer') -Rt56Traits @('jaeger_trait', 'infantry_officer', 'seawolf_one', 'seawolf_two', 'cautious_planner', 'lucky') -Rt56UnitLeaderTraits @('jaeger_trait', 'infantry_officer', 'seawolf_one', 'seawolf_two', 'cautious_planner', 'lucky')
        @($rt56Traits.undefined) | Should -Be @('jaeger', 'seawolf', 'trait_cautious')
        @($rt56Traits.counterparts.Keys) | Should -Be @('jaeger')
        $rt56Traits.counterparts['jaeger'] | Should -Be 'jaeger_trait'
    }

    It 'takes a counterpart only from the traits vanilla does not define' {
        $rt56Traits = Select-LpRt56Traits -StartTraits @('ranger') -VanillaTraits @('ranger', 'ranger_elite') -Rt56Traits @('ranger_elite', 'ranger_trait') -Rt56UnitLeaderTraits @('ranger_elite', 'ranger_trait')
        @($rt56Traits.undefined) | Should -Be @('ranger')
        $rt56Traits.counterparts['ranger'] | Should -Be 'ranger_trait'
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

Describe 'Workshop showcase' {
    BeforeAll {
        . (Join-Path $script:LpRepoRoot 'tools\LeaderPacks.Showcase.ps1')

        function Set-LpFixtureShowcase {
            param([string]$Root, $Value)

            Write-LpJson -Path (Join-Path $Root 'source\testland\showcase.json') -Value $Value
        }

        function New-LpStubShowcaseManager {
            param([int]$ExitCode = 0)

            $managerRoot = Join-Path $TestDrive ('showcase-manager-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
            $showcaseFolder = Join-Path $managerRoot 'Scripts\Showcase'
            New-Item -ItemType Directory -Path $showcaseFolder -Force | Out-Null
            $rendererStub = @'
[CmdletBinding()]
param([string]$SpecPath, [string]$OutputDir)
$managerRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Copy-Item -LiteralPath $SpecPath -Destination (Join-Path $managerRoot 'received-spec.json')
[System.IO.File]::WriteAllText((Join-Path $managerRoot 'received-output.txt'), $OutputDir)
'Rendered 0 image(s) to ' + $OutputDir
exit 0
'@
            $rendererStub = $rendererStub.Replace('exit 0', "exit $ExitCode")
            [System.IO.File]::WriteAllText((Join-Path $showcaseFolder 'New-HoiShowcaseImage.ps1'), ($rendererStub -replace "`r?`n", "`r`n"))
            return $managerRoot
        }

        function Get-LpShowcaseErrors {
            param([string]$Root)

            return @(Test-LpShowcaseSource -RepoRoot $Root -Pack 'testland' | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { "$($_.Where): $($_.Message)" })
        }
    }

    It 'builds a roster and a card for every leader that is not skip, with the role labels, colours and stats' {
        $fixtureRoot = New-LpFixtureRepo
        $spec = (New-LpShowcaseSpec -RepoRoot $fixtureRoot -Pack 'testland').Spec
        $pages = @($spec.pages)
        $spec.brand.label | Should -Be 'Commanders Pack: Testland'
        $spec.brand.flag.tag | Should -Be 'TST'
        $pages[0].layout | Should -Be 'roster'
        @($pages[0].items | ForEach-Object { $_.caption }) | Should -Be @('General', 'Field marshal', 'Admiral', 'General', 'Admiral')
        @($pages[0].items | ForEach-Object { $_.accent }) | Should -Be @('#7FA35B', '#C9A866', '#5B93D6', '#7FA35B', '#5B93D6')
        @($pages | Select-Object -Skip 1 | ForEach-Object { $_.file }) | Should -Be @('01-alpha_leader', '02-bravo_leader', '03-charlie_leader', '04-delta_advisor', '05-echo_admiral')
        @($pages[1].stats | ForEach-Object { $_.label }) | Should -Be @('Skill', 'Attack', 'Defense', 'Planning', 'Logistics')
        @($pages[3].stats | ForEach-Object { $_.label }) | Should -Be @('Skill', 'Attack', 'Defense', 'Maneuvering', 'Coordination')
        @($pages[3].stats | ForEach-Object { $_.value }) | Should -Be @(2, 1, 3, 2, 2)
        $pages[3].stats[1].icon | Should -Be 'GFX_trait_attack'
        $pages[3].roleAccent | Should -Be '#5B93D6'
    }

    It 'drops the Road to 56 counterpart of a trait and gives every trait its game name and icon' {
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureLeaders -Root $fixtureRoot -Change { param($s) $s.leaders[0].traits = @('infantry_officer', 'engineer_trait') }
        $alphaCard = @((New-LpShowcaseSpec -RepoRoot $fixtureRoot -Pack 'testland').Spec.pages)[1]
        @($alphaCard.traits | ForEach-Object { $_.name.locKey }) | Should -Be @('infantry_officer')
        $alphaCard.traits[0].name.fallback | Should -Be 'Infantry Officer'
        $alphaCard.traits[0].icon | Should -Be 'GFX_trait_infantry_officer'
    }

    It 'credits a CC BY photo with its author and licence, and puts no note on a public domain portrait or AI wording on any image' {
        $fixtureRoot = New-LpFixtureRepo
        $pages = @((New-LpShowcaseSpec -RepoRoot $fixtureRoot -Pack 'testland').Spec.pages)
        $photos = Read-LpJson -Path (Join-Path $fixtureRoot 'source\testland\photos.json')
        $alphaPhoto = @($photos.photos | Where-Object { $_.key -eq 'alpha' })[0]
        $pages[1].note | Should -Be ('Portrait adapted from a photograph by {0} ({1})' -f $alphaPhoto.author, $alphaPhoto.licenseShortName)
        $pages[2].Contains('note') | Should -BeFalse
        $pages[0].subtitle | Should -Be '5 leaders for Testland'
        ($pages | ConvertTo-Json -Depth 10) | Should -Not -Match 'AI-assisted'
    }

    It 'takes the card lines and years from showcase.json, and the birth year alone without them' {
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureShowcase -Root $fixtureRoot -Value ([ordered]@{ leaders = [ordered]@{ alpha_leader = [ordered]@{ card = @('First line.', 'Second line.'); years = @(1894, 1960) } } })
        $built = New-LpShowcaseSpec -RepoRoot $fixtureRoot -Pack 'testland'
        $pages = @($built.Spec.pages)
        @($pages[1].lines) | Should -Be @('First line.', 'Second line.')
        @($pages[1].years) | Should -Be @(1894, 1960)
        @($pages[2].lines).Count | Should -Be 0
        @($pages[2].years) | Should -Be @(1892)
        $built.CardlessLeaders | Should -Contain 'Bravo Leader'
        $built.CardlessLeaders | Should -Not -Contain 'Alpha Leader'
        Get-LpShowcaseErrors -Root $fixtureRoot | Should -BeNullOrEmpty
    }

    It 'rejects an unknown or skip leader, an unknown field, a fifth or empty line, and warns about a birth year that differs' {
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureShowcase -Root $fixtureRoot -Value ([ordered]@{
                leaders = [ordered]@{
                    nobody          = [ordered]@{ card = @('x') }
                    foxtrot_marshal = [ordered]@{ card = @('x') }
                    alpha_leader    = [ordered]@{ card = @('1', '2', '3', '4', '5'); bio = 'x' }
                    bravo_leader    = [ordered]@{ card = @(' '); years = @(1893) }
                }
            })
        $errors = Get-LpShowcaseErrors -Root $fixtureRoot
        $errors | Should -Contain 'source/testland/showcase.json leaders.nobody: no leader with this key in leaders.json'
        $errors | Should -Contain 'source/testland/showcase.json leaders.foxtrot_marshal: the leader is skip and gets no showcase card'
        $errors | Should -Contain "source/testland/showcase.json leaders.alpha_leader: unknown field 'bio'; a leader has 'card' and 'years'"
        $errors | Should -Contain 'source/testland/showcase.json leaders.alpha_leader: card has 5 lines; at most 4 fit'
        $errors | Should -Contain 'source/testland/showcase.json leaders.bravo_leader: a card line is empty'
        $warnings = @(Test-LpShowcaseSource -RepoRoot $fixtureRoot -Pack 'testland' | Where-Object { $_.Level -eq 'WARN' } | ForEach-Object { $_.Message })
        $warnings | Should -Contain 'born 1893 here but 1892 in leaders.json portrait.born'
        Invoke-LpShowcaseCheck -RepoRoot $fixtureRoot -Pack @('testland') 6>$null | Should -Be 1
    }

    It 'accepts a card of 4 lines with a line of 160 characters and a birth year that matches, without a finding' {
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureShowcase -Root $fixtureRoot -Value ([ordered]@{ leaders = [ordered]@{ bravo_leader = [ordered]@{ card = @('One.', 'Two.', 'Three.', ('x' * 160)); years = @(1892, 1950) } } })
        @(Test-LpShowcaseSource -RepoRoot $fixtureRoot -Pack 'testland') | Should -BeNullOrEmpty
        Invoke-LpShowcaseCheck -RepoRoot $fixtureRoot -Pack @('testland') 6>$null | Should -Be 0
    }

    It 'rejects a line over 160 characters, a line break, three years, a year that is not whole, a leader without card lines and an unknown top-level field' {
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureShowcase -Root $fixtureRoot -Value ([ordered]@{
                leaders = [ordered]@{
                    alpha_leader   = [ordered]@{ card = @(('x' * 161)) }
                    bravo_leader   = [ordered]@{ card = @("One`nTwo") }
                    charlie_leader = [ordered]@{ card = @('x'); years = @(1890, 1950, 1960) }
                    delta_advisor  = [ordered]@{ card = @('x'); years = @(1890.5) }
                    echo_admiral   = [ordered]@{ years = @(1890) }
                }
                extra   = 'x'
            })
        Get-LpShowcaseErrors -Root $fixtureRoot | Should -Be @(
            "source/testland/showcase.json: unknown field 'extra'; only 'leaders' is read",
            'source/testland/showcase.json leaders.alpha_leader: a card line has 161 characters; at most 160 fit',
            'source/testland/showcase.json leaders.bravo_leader: a card line holds a line break',
            'source/testland/showcase.json leaders.charlie_leader: years is [born] or [born, died], whole numbers',
            'source/testland/showcase.json leaders.delta_advisor: years is [born] or [born, died], whole numbers',
            'source/testland/showcase.json leaders.echo_admiral: card needs 1 to 4 lines'
        )
    }

    It 'wires the showcase check into build.ps1 -Check and -RenderShowcase' {
        $fixtureRoot = New-LpFixtureRepo
        Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'build.ps1') -Destination $fixtureRoot
        foreach ($toolFile in @(Get-ChildItem -LiteralPath (Join-Path $script:LpRepoRoot 'tools') -File | Where-Object { $_.Name -ne 'HoiModBuild.json' })) {
            Copy-Item -LiteralPath $toolFile.FullName -Destination (Join-Path $fixtureRoot 'tools')
        }
        $fixtureBuild = Join-Path $fixtureRoot 'build.ps1'
        $generateOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureBuild -Generate -Pack testland)
        $LASTEXITCODE | Should -Be 0 -Because ($generateOutput -join "`n")
        $cleanOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureBuild -Check -Pack testland)
        $LASTEXITCODE | Should -Be 0 -Because ($cleanOutput -join "`n")
        Set-LpFixtureShowcase -Root $fixtureRoot -Value ([ordered]@{ leaders = [ordered]@{ nobody = [ordered]@{ card = @('x') } } })
        $checkOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureBuild -Check -Pack testland)
        $LASTEXITCODE | Should -Be 1
        ($checkOutput -join "`n") | Should -Match 'leaders\.nobody: no leader with this key in leaders\.json'
        $renderOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureBuild -RenderShowcase -Pack testland)
        $LASTEXITCODE | Should -Be 1
        ($renderOutput -join "`n") | Should -Match 'RenderShowcase: source/testland/showcase\.json has errors; nothing rendered\.'
    }

    It 'hands the spec to the Manager renderer and writes it under artifacts/workshop-images/<pack>' {
        $fixtureRoot = New-LpFixtureRepo
        $managerRoot = New-LpStubShowcaseManager
        $exitCode = @(Invoke-LpRenderShowcase -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null)[-1]
        $exitCode | Should -Be 0
        $outputDir = Join-Path $fixtureRoot 'artifacts\workshop-images\testland'
        [System.IO.File]::ReadAllText((Join-Path $managerRoot 'received-output.txt')) | Should -Be $outputDir
        $received = Read-LpJson -Path (Join-Path $managerRoot 'received-spec.json')
        @($received.pages).Count | Should -Be 6
        Test-Path -LiteralPath (Join-Path $outputDir 'showcase-spec.json') | Should -BeTrue
    }

    It 'passes the exit code of the renderer back' {
        $managerRoot = New-LpStubShowcaseManager -ExitCode 2
        @(Invoke-LpRenderShowcase -RepoRoot (New-LpFixtureRepo) -Pack 'testland' -ManagerRoot $managerRoot 6>$null)[-1] | Should -Be 2
    }

    It 'stops before the renderer on a showcase error, a missing portrait or a missing Manager' {
        $managerRoot = New-LpStubShowcaseManager
        $fixtureRoot = New-LpFixtureRepo
        Set-LpFixtureShowcase -Root $fixtureRoot -Value ([ordered]@{ leaders = [ordered]@{ nobody = [ordered]@{ card = @('x') } } })
        @(Invoke-LpRenderShowcase -RepoRoot $fixtureRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null)[-1] | Should -Be 1
        $noPortraitRoot = New-LpFixtureRepo -NoPortraits
        @(Invoke-LpRenderShowcase -RepoRoot $noPortraitRoot -Pack 'testland' -ManagerRoot $managerRoot 6>$null)[-1] | Should -Be 1
        @(Invoke-LpRenderShowcase -RepoRoot (New-LpFixtureRepo) -Pack 'testland' -ManagerRoot '' 6>$null)[-1] | Should -Be 1
        Test-Path -LiteralPath (Join-Path $managerRoot 'received-spec.json') | Should -BeFalse
    }
}

Describe 'Bundle' {
    BeforeAll {
        function New-LpBundleFixtureRepo {
            $fixtureRoot = New-LpFixtureRepo -Packs @('testland', 'otherland') -NoPortraits
            $packageSettings = [ordered]@{
                all       = [ordered]@{ root = 'packs/all'; modFolderName = 'immersive_commanders_expanded'; members = @('testland', 'otherland') }
                testland  = [ordered]@{ root = 'packs/testland'; modFolderName = 'commanders_pack_testland' }
                otherland = [ordered]@{ root = 'packs/otherland'; modFolderName = 'commanders_pack_otherland' }
            }
            Write-LpJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json') -Value ([ordered]@{ packages = $packageSettings })
            Write-LpText -Path (Join-Path $fixtureRoot 'packs\all\descriptor.mod') -Text ("version=`"1.0`"`r`nname=`"Immersive Commanders Expanded`"`r`npicture=`"thumbnail.png`"`r`nsupported_version=`"1.19.*`"`r`n")
            Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'assets\thumbnail_master.png') -Destination (Join-Path $fixtureRoot 'packs\all\thumbnail.png')
            New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'assets') -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:LpRepoRoot 'assets\thumbnail_master.png') -Destination (Join-Path $fixtureRoot 'assets\thumbnail_master.png')
            Write-LpText -Path (Join-Path $fixtureRoot 'source\all\workshop-intro.bbcode') -Text "<!-- region:image:hero -->`r`n<!-- /region -->`r`nHistorical generals for Testland and Otherland in one item.`r`n"
            return $fixtureRoot
        }

        function Get-LpBundleErrors {
            param([string]$Root)

            return @(Test-LpBundle -RepoRoot $Root -Bundle 'all' | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { "$($_.Where): $($_.Message)" })
        }
    }

    It 'keeps the bundle out of the pack names, and finds the bundle that holds a member' {
        $fixtureRoot = New-LpBundleFixtureRepo
        @(Get-LpPackNames -RepoRoot $fixtureRoot) | Should -Be @('testland', 'otherland')
        @(Get-LpBundleNames -RepoRoot $fixtureRoot) | Should -Be @('all')
        @(Get-LpBundleNames -RepoRoot $fixtureRoot -Member 'otherland') | Should -Be @('all')
        @(Get-LpBundleNames -RepoRoot $fixtureRoot -Member 'elsewhere').Count | Should -Be 0
    }

    It 'writes the bundle page: the intro, a country list with the commander counts, the portrait licences and the link markers' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Select-Object -Last 1 | Should -Be 0
        $pageText = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\all\WORKSHOP_DESCRIPTION_GUIDELINES.md'), [System.Text.Encoding]::UTF8)
        $pageText | Should -Match '(?m)^# Immersive Commanders Expanded - Workshop description'
        $pageText | Should -Match 'Historical generals for Testland and Otherland in one item\.'
        $testlandCount = @(Get-LpGeneratedLeaders -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')).Count
        $otherlandCount = @(Get-LpGeneratedLeaders -Pack (Get-LpPack -RepoRoot $fixtureRoot -Pack 'otherland')).Count
        $testlandCount | Should -BeGreaterThan 1
        $pageText | Should -Match ('\[\*\]Testland: ' + $testlandCount + ' commanders\r?\n\[\*\]Otherland: ' + $otherlandCount + ' commanders\r?\n')
        $pageText | Should -Match '<!-- region:image:strip-countries -->'
        $pageText | Should -Match '\[h1\]Portraits\[/h1\]\r?\nThe portraits are repaints of historical photographs from '
        $pageText | Should -Match '<!-- cross-links:begin -->\r?\n<!-- cross-links:end -->'
        $pageText | Should -Not -Match '\bAI\b|AI-assisted|image model|artificial intelligence|ComfyUI'
        Get-LpBundleErrors -Root $fixtureRoot | Should -BeNullOrEmpty
    }

    It 'writes the portraits paragraph of a single pack as before' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        $packText = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\testland\WORKSHOP_DESCRIPTION_GUIDELINES.md'), [System.Text.Encoding]::UTF8)
        $packParagraph = Get-LpPortraitsParagraph -Packs @(Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        $packText | Should -Match ([regex]::Escape($packParagraph))
    }

    It 'names the share-alike portraits of every member on the bundle page, not only the first' {
        $fixtureRoot = New-LpBundleFixtureRepo
        $shareAlikePhoto = New-LpFixturePhoto -Key 'alpha' -Fixture 'cc-by-sa-3.0-de'
        Set-LpFixturePhotos -Root $fixtureRoot -Pack 'otherland' -Change { param($s) $shareAlikePhoto.downloadSha256 = $s.photos[0].downloadSha256; $s.photos[0] = $shareAlikePhoto }
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Select-Object -Last 1 | Should -Be 0
        $pageText = [System.IO.File]::ReadAllText((Join-Path $fixtureRoot 'packs\all\WORKSHOP_DESCRIPTION_GUIDELINES.md'), [System.Text.Encoding]::UTF8)
        $otherlandPack = Get-LpPack -RepoRoot $fixtureRoot -Pack 'otherland'
        $expectedParagraph = Get-LpPortraitsParagraph -Packs @((Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland'), $otherlandPack)
        $expectedParagraph | Should -Match 'licensed CC BY-SA and are themselves licensed'
        $pageText | Should -Match ([regex]::Escape($expectedParagraph))
        $firstPackParagraph = Get-LpPortraitsParagraph -Packs @(Get-LpPack -RepoRoot $fixtureRoot -Pack 'testland')
        $firstPackParagraph | Should -Not -Be $expectedParagraph
    }

    It 'writes the bundle page again when a member pack is generated, and keeps what the Manager wrote in it' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Out-Null
        $pagePath = Join-Path $fixtureRoot 'packs\all\WORKSHOP_DESCRIPTION_GUIDELINES.md'
        $carriedText = ([System.IO.File]::ReadAllText($pagePath, [System.Text.Encoding]::UTF8)).Replace("<!-- cross-links:begin -->`r`n<!-- cross-links:end -->", "<!-- cross-links:begin -->`r`n[b]More from the author[/b]`r`n<!-- cross-links:end -->")
        Write-LpText -Path $pagePath -Text $carriedText
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'testland' 6>$null | Select-Object -Last 1 | Should -Be 0
        [System.IO.File]::ReadAllText($pagePath, [System.Text.Encoding]::UTF8) | Should -Match '\[b\]More from the author\[/b\]'
        Remove-Item -LiteralPath $pagePath
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'otherland' 6>$null | Select-Object -Last 1 | Should -Be 0
        Test-Path -LiteralPath $pagePath | Should -BeTrue
    }

    It 'fails the check when a pack is not a member of the bundle' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Out-Null
        Set-LpFixtureJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json') -Change { param($settings) $settings.packages.all.members = @('testland') }
        Get-LpBundleErrors -Root $fixtureRoot | Should -Contain "tools/HoiModBuild.json: pack 'otherland' is not a member of bundle 'all': add it to the members list, or its release would leave it out of the bundle"
    }

    It 'lists a member that is not a pack as a problem instead of stopping' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Set-LpFixtureJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json') -Change { param($settings) $settings.packages.all.members = @('testland', 'otherland', 'ghostland') }
        @(Get-LpBundleErrors -Root $fixtureRoot | Where-Object { $_ -like "*member 'ghostland' of bundle 'all' is not a commanders pack*" }).Count | Should -Be 1
    }

    It 'fails the check for an intro that does not name a member' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Write-LpText -Path (Join-Path $fixtureRoot 'source\all\workshop-intro.bbcode') -Text "<!-- region:image:hero -->`r`n<!-- /region -->`r`nHistorical generals for Testland in one item.`r`n"
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Out-Null
        @(Get-LpBundleErrors -Root $fixtureRoot | Where-Object { $_ -like "*does not name 'Otherland'*" }).Count | Should -Be 1
    }

    It 'fails the check for a page edited by hand, a file in the bundle root and a different supported version' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Out-Null
        $pagePath = Join-Path $fixtureRoot 'packs\all\WORKSHOP_DESCRIPTION_GUIDELINES.md'
        Write-LpText -Path $pagePath -Text (([System.IO.File]::ReadAllText($pagePath, [System.Text.Encoding]::UTF8)) + 'by hand')
        Write-LpText -Path (Join-Path $fixtureRoot 'packs\all\common\extra.txt') -Text 'x'
        Write-LpText -Path (Join-Path $fixtureRoot 'packs\all\descriptor.mod') -Text ("version=`"1.0`"`r`nname=`"Immersive Commanders Expanded`"`r`nsupported_version=`"1.18.*`"`r`n")
        $bundleErrors = Get-LpBundleErrors -Root $fixtureRoot
        @($bundleErrors | Where-Object { $_ -like '*differs from what the source generates*' }).Count | Should -Be 1
        @($bundleErrors | Where-Object { $_ -like '*a bundle holds only its descriptor*' }).Count | Should -Be 1
        @($bundleErrors | Where-Object { $_ -like "*supported_version '1.18.*' differs from '1.19.*'*" }).Count | Should -Be 2
    }

    It 'checks the bundle with the packs it holds' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Out-Null
        $checkOutput = @(Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'all' 6>&1 | ForEach-Object { [string]$_ })
        ($checkOutput -join "`n") | Should -Match "Bundle 'all': 2 member"
    }

    It 'returns a failing exit code from the check for a bundle error, and 0 without one' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpGenerate -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Out-Null
        Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Select-Object -Last 1 | Should -Be 0
        Set-LpFixtureJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json') -Change { param($settings) $settings.packages.all.members = @('testland') }
        Invoke-LpCheck -RepoRoot $fixtureRoot -Pack 'all' 6>$null | Select-Object -Last 1 | Should -Be 1
    }

    It 'adds a new pack to the members of the bundle' {
        $fixtureRoot = New-LpBundleFixtureRepo
        Invoke-LpNewPack -RepoRoot $fixtureRoot -Pack 'newland' -Tag 'NEW' -DisplayName 'New Land' 6>$null | Select-Object -Last 1 | Should -Be 0
        $settings = Read-LpJson -Path (Join-Path $fixtureRoot 'tools\HoiModBuild.json')
        @($settings.packages.all.members) | Should -Be @('testland', 'otherland', 'newland')
        $settings.packages.newland.root | Should -BeExactly 'packs/newland'
        @(Get-LpPackNames -RepoRoot $fixtureRoot) | Should -Be @('testland', 'otherland', 'newland')
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

    It 'keeps the PowerShell tools in ASCII' {
        foreach ($toolPath in @('tools\LeaderPacks.ps1', 'tools\LeaderPacks.Showcase.ps1', 'build.ps1', 'tests\LeaderPacks.Fixture.ps1', '.claude\hooks\Protect-ProjectFiles.ps1')) {
            $toolBytes = [System.IO.File]::ReadAllBytes((Join-Path $script:LpRepoRoot $toolPath))
            [regex]::Matches([System.Text.Encoding]::GetEncoding(28591).GetString($toolBytes), '[\x7F-\xFF]').Count | Should -Be 0 -Because $toolPath
        }
    }
}
