BeforeAll {
    $moduleCandidates = @((Join-Path $PSScriptRoot 'HoiImageSources.ps1'), (Join-Path $PSScriptRoot '..\tools\HoiImageSources.ps1'))
    $modulePath = @($moduleCandidates | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
    . $modulePath
    $fixtureCandidates = @((Join-Path $PSScriptRoot 'fixtures'), (Join-Path $PSScriptRoot 'fixtures\image-sources'))
    $script:ImageFixtureRoot = @($fixtureCandidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'commons\pd.json') }) | Select-Object -First 1

    function Get-ImageFixture {
        param([Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Name)

        return ([System.IO.File]::ReadAllText((Join-Path $script:ImageFixtureRoot "$Source\$Name.json"), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
    }

    function Get-CommonsFixtureVerdict {
        param([Parameter(Mandatory = $true)]$Response, [Parameter(Mandatory = $true)]$Policy)

        return Get-HoiImageVerdict -Candidate (ConvertFrom-HoiCommonsResponse -Response $Response) -Policy $Policy
    }

    function New-PortraitPolicy {
        return New-HoiImagePolicy -AcceptedCategories @('PD', 'CC0', 'CC BY', 'CC BY-SA') -AcceptedSources @('commons', 'finna', 'europeana', 'manual') -MinShorterSide 300 -MinSizeText 'a portrait source' -InstitutionCredit -BotName 'TestBot' -ContactUrl 'https://example.com/test' -FetchCommand 'build.ps1 -FetchPhoto' -ItemNounPlural 'photos'
    }

    function New-EventPolicy {
        return New-HoiImagePolicy -AcceptedCategories @('PD', 'CC0', 'CC BY') -AcceptedSources @('commons') -MinWidth 210 -MinHeight 176 -MinSizeText 'the 210x176 event picture [SPR-028]' -BotName 'TestBot' -ContactUrl 'https://example.com/test' -FetchCommand 'build.ps1 -FetchPicture' -ItemNounPlural 'pictures'
    }

    function Write-TestJpeg {
        param([Parameter(Mandatory = $true)][string]$Path, [int]$Width, [int]$Height)

        Add-Type -AssemblyName System.Drawing
        $bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
        try {
            $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        } finally {
            $bitmap.Dispose()
        }
    }

    function New-ManualSpec {
        return [PSCustomObject]@{
            recordUrl          = 'https://archive.example.org/record/42'
            imageUrl           = 'https://archive.example.org/image/42.jpg'
            rightsUrl          = 'https://archive.example.org/terms'
            rightsQuote        = 'Photographs taken by the army before 1945 are in the public domain and free to re-use.'
            license            = 'pd'
            publicDomainReason = 'Army photograph before 1945, archive terms'
            author             = ''
            institution        = 'Example Army Archive'
            credit             = ''
            dateOriginal       = '1943'
            title              = 'General X at the front'
        }
    }

    function New-AcceptedRecord {
        param([Parameter(Mandatory = $true)][string]$FixtureName)

        $verdict = Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name $FixtureName) -Policy (New-PortraitPolicy)
        $record = $verdict.Record
        $record.key = 'alpha'
        $record.downloadSha256 = 'a' * 64
        $record.fetched = '2026-11-03'
        return $record
    }
}

Describe 'Commons verdict' {
    It 'accepts public domain with its reason, CC0 and CC BY with the author' {
        $publicDomain = Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name 'pd') -Policy (New-EventPolicy)
        $publicDomain.Accepted | Should -BeTrue
        $publicDomain.Record.licenseCategory | Should -Be 'PD'
        $publicDomain.Record.publicDomainReason | Should -Be 'PD-Finland50'
        $publicDomain.Record.source | Should -Be 'commons'
        $publicDomain.Record.sourceId | Should -Be $publicDomain.Record.commonsTitle
        (Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name 'cc0') -Policy (New-EventPolicy)).Record.licenseCategory | Should -Be 'CC0'
        $attribution = Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name 'cc-by') -Policy (New-EventPolicy)
        $attribution.Accepted | Should -BeTrue
        $attribution.Record.licenseUrl | Should -Be 'https://creativecommons.org/licenses/by/4.0'
        $attribution.Record.attribution | Should -Match '^Hugo Sundstr'
    }

    It 'refuses a missing file, a deletion tag, public domain without its reason, a non-picture and a download off Wikimedia' {
        (Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name 'missing') -Policy (New-EventPolicy)).Reason | Should -Be 'no such file on Wikimedia Commons'
        $tagged = Get-ImageFixture -Source 'commons' -Name 'pd'
        $tagged.query.pages[0] | Add-Member -NotePropertyName 'templates' -NotePropertyValue @([PSCustomObject]@{ ns = 10; title = 'Template:Delete' }) -Force
        (Get-CommonsFixtureVerdict -Response $tagged -Policy (New-EventPolicy)).Reason | Should -Be 'tagged on Commons: Template:Delete'
        $noReason = Get-ImageFixture -Source 'commons' -Name 'pd'
        $noReason.query.pages[0].templates = @($noReason.query.pages[0].templates | Where-Object { $_.title -notmatch '^Template:PD-' })
        (Get-CommonsFixtureVerdict -Response $noReason -Policy (New-EventPolicy)).Reason | Should -Match 'without a PD- licence template'
        $document = Get-ImageFixture -Source 'commons' -Name 'pd'
        $document.query.pages[0].imageinfo[0].mime = 'application/pdf'
        (Get-CommonsFixtureVerdict -Response $document -Policy (New-EventPolicy)).Reason | Should -Match 'not a picture'
        $elsewhere = Get-ImageFixture -Source 'commons' -Name 'pd'
        $elsewhere.query.pages[0].imageinfo[0].thumburl = 'https://example.com/abatis.jpg'
        (Get-CommonsFixtureVerdict -Response $elsewhere -Policy (New-EventPolicy)).Reason | Should -Match "not on Wikimedia's upload servers"
    }

    It 'measures size by the policy: the shorter side for a portrait, width and height for an event picture' {
        $small = Get-ImageFixture -Source 'commons' -Name 'cc0'
        $small.query.pages[0].imageinfo[0].width = 299
        (Get-CommonsFixtureVerdict -Response $small -Policy (New-PortraitPolicy)).Reason | Should -Be "299x$($small.query.pages[0].imageinfo[0].height) is under 300 px on its shorter side, too small for a portrait source"
        $small.query.pages[0].imageinfo[0].width = 300
        (Get-CommonsFixtureVerdict -Response $small -Policy (New-PortraitPolicy)).Accepted | Should -BeTrue
        $narrow = Get-ImageFixture -Source 'commons' -Name 'cc0'
        $narrow.query.pages[0].imageinfo[0].width = 200
        (Get-CommonsFixtureVerdict -Response $narrow -Policy (New-EventPolicy)).Reason | Should -Match 'smaller than the 210x176 event picture'
    }

    It 'asks Commons for the licence metadata and the templates in one query' {
        $queryUrl = Get-HoiCommonsQueryUrl -FileTitle 'File:Abatis at Taipale.jpg'
        $queryUrl | Should -Match 'titles=File%3AAbatis%20at%20Taipale\.jpg'
        $queryUrl | Should -Match 'iiprop=url%7Csize%7Cmime%7Cextmetadata'
        $queryUrl | Should -Match 'prop=imageinfo%7Ctemplates'
    }
}

Describe 'CC BY-SA' {
    It 'accepts BY-SA <Name> under a policy that allows it, and credits the licensor''s attribution' -TestCases @(
        @{ Name = '3.0 de'; Fixture = 'cc-by-sa-3.0-de'; Attribution = 'Bundesarchiv, Bild 183-S37772 / CC-BY-SA 3.0' }
        @{ Name = '2.0'; Fixture = 'cc-by-sa-2.0'; Attribution = 'Matias Garabedian from Montreal, Canada' }
    ) {
        $verdict = Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name $Fixture) -Policy (New-PortraitPolicy)
        $verdict.Accepted | Should -BeTrue -Because $verdict.Reason
        $verdict.Record.licenseCategory | Should -Be 'CC BY-SA'
        $verdict.Record.attribution | Should -Be $Attribution
    }

    It 'refuses BY-SA under a policy without it' {
        $verdict = Get-CommonsFixtureVerdict -Response (Get-ImageFixture -Source 'commons' -Name 'cc-by-sa-3.0-de') -Policy (New-EventPolicy)
        $verdict.Accepted | Should -BeFalse
        $verdict.Reason | Should -Be "licence 'CC BY-SA 3.0 de' (cc-by-sa-3.0-de) is outside the policy: public domain, CC0 or CC BY only"
    }

    It 'refuses BY-SA 1.0, which has no later-version clause, and an IGO or unknown port' {
        $versionOne = Get-ImageFixture -Source 'commons' -Name 'cc-by-sa-2.0'
        $versionOne.query.pages[0].imageinfo[0].extmetadata.License.value = 'cc-by-sa-1.0'
        (Get-CommonsFixtureVerdict -Response $versionOne -Policy (New-PortraitPolicy)).Reason | Should -Match 'CC BY-SA 1\.0 has no clause allowing an adaptation under a later version'
        (Test-HoiShareAlikeVersion -LicenseCode 'cc-by-sa-3.0-igo').Allowed | Should -BeFalse
        (Test-HoiShareAlikeVersion -LicenseCode 'cc-by-sa-2.5-nl').Allowed | Should -BeTrue
        (Test-HoiShareAlikeVersion -LicenseCode 'cc-by-sa-3.0-migrated').Allowed | Should -BeTrue
        (Test-HoiShareAlikeVersion -LicenseCode 'cc-by-sa-4.0').Allowed | Should -BeTrue
    }

    It 'refuses BY-SA with neither a named author nor an institution credit, and with no institution credit allowed' {
        $unnamed = Get-ImageFixture -Source 'commons' -Name 'cc-by-sa-3.0-de'
        $unnamed.query.pages[0].imageinfo[0].extmetadata.Attribution.value = ''
        (Get-CommonsFixtureVerdict -Response $unnamed -Policy (New-PortraitPolicy)).Reason | Should -Be 'CC BY-SA without a named author or an institution credit on Commons: the credit cannot be written'
        $byOnly = Get-ImageFixture -Source 'commons' -Name 'cc-by'
        $byOnly.query.pages[0].imageinfo[0].extmetadata.Artist.value = 'Unknown author'
        (Get-CommonsFixtureVerdict -Response $byOnly -Policy (New-EventPolicy)).Reason | Should -Be 'CC BY without a named author on Commons: the credit cannot be written'
    }
}

Describe 'Finna' {
    It 'accepts an SA-kuva photo as CC BY credited to the archive, with its size left to the download' {
        $candidate = ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by')
        $verdict = Get-HoiImageVerdict -Candidate $candidate -Policy (New-PortraitPolicy)
        $verdict.Accepted | Should -BeTrue -Because $verdict.Reason
        $candidate.SizeKnown | Should -BeFalse
        $verdict.Record.source | Should -Be 'finna'
        $verdict.Record.sourceId | Should -Be 'sa-kuva.sa-kuva/111307'
        $verdict.Record.licenseCategory | Should -Be 'CC BY'
        $verdict.Record.licenseUrl | Should -Be 'https://creativecommons.org/licenses/by/4.0/'
        $verdict.Record.author | Should -Be 'Tuntematon'
        $verdict.Record.attribution | Should -Be 'SA-kuva-arkisto'
        $verdict.Record.pageUrl | Should -Be 'https://www.finna.fi/Record/sa-kuva.sa-kuva%2F111307'
        $verdict.Record.downloadUrl | Should -Match '^https://api\.finna\.fi/Cover/Show\?'
        @(Test-HoiImageRecord -Record ($verdict.Record | Add-Member -NotePropertyName 'unused' -NotePropertyValue $null -PassThru) -Policy (New-PortraitPolicy) | Where-Object { $_.Message -match 'outside|not a Finna' }) | Should -BeNullOrEmpty
    }

    It 'reads a public domain mark as PD with the institution as its reason, and refuses a non-commercial licence' {
        $publicDomain = Get-HoiImageVerdict -Candidate (ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'pdm')) -Policy (New-PortraitPolicy)
        $publicDomain.Accepted | Should -BeTrue
        $publicDomain.Record.publicDomainReason | Should -Be 'PDM (Helsingin kaupunginmuseo)'
        $publicDomain.Record.author | Should -Be 'Atelier Rembrandt'
        (Get-HoiImageVerdict -Candidate (ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'by-nc-nd')) -Policy (New-PortraitPolicy)).Reason | Should -Match "licence 'CC BY-NC-ND 4.0' \(cc-by-nc-nd-4.0\) is outside the policy"
    }

    It 'refuses a record whose image rights differ from its own, a record with no rights and a missing record' {
        $mismatch = Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by'
        $mismatch.records[0].imagesExtended[0].rights.copyright = 'CC BY-NC 4.0'
        (Get-HoiImageVerdict -Candidate (ConvertFrom-HoiFinnaResponse -Response $mismatch) -Policy (New-PortraitPolicy)).Reason | Should -Match 'differ on Finna'
        $noRights = Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by'
        $noRights.records[0].imageRights.copyright = ''
        $noRights.records[0].imagesExtended[0].rights.copyright = ''
        (Get-HoiImageVerdict -Candidate (ConvertFrom-HoiFinnaResponse -Response $noRights) -Policy (New-PortraitPolicy)).Reason | Should -Match 'states no rights'
        (Get-HoiImageVerdict -Candidate (ConvertFrom-HoiFinnaResponse -Response ([PSCustomObject]@{ resultCount = 0; records = @() })) -Policy (New-PortraitPolicy)).Reason | Should -Be 'no such record on Finna'
    }

    It 'asks Finna for one record with its rights, images and holders' {
        $recordUrl = Get-HoiFinnaRecordUrl -Id 'sa-kuva.sa-kuva/111307'
        $recordUrl | Should -Match '^https://api\.finna\.fi/api/v1/record\?id=sa-kuva\.sa-kuva%2F111307&'
        $recordUrl | Should -Match 'field%5B%5D=imageRights'
        $recordUrl | Should -Match 'field%5B%5D=buildings'
    }
}

Describe 'Europeana' {
    It 'reads a public domain mark with its data provider, size and type' {
        $candidate = ConvertFrom-HoiEuropeanaResponse -Response (Get-ImageFixture -Source 'europeana' -Name 'pdm')
        $verdict = Get-HoiImageVerdict -Candidate $candidate -Policy (New-PortraitPolicy)
        $verdict.Accepted | Should -BeTrue -Because $verdict.Reason
        $verdict.Record.publicDomainReason | Should -Be 'PDM (Army Museum)'
        $verdict.Record.institution | Should -Be 'Army Museum'
        "$($verdict.Record.width)x$($verdict.Record.height)" | Should -Be '869x1200'
        $verdict.Record.pageUrl | Should -Be 'https://www.europeana.eu/item/91616/arme_photo_AMA0013571'
        $candidate.MimeType | Should -Be 'image/jpeg'
    }

    It 'accepts CC BY and CC BY-SA, and refuses In Copyright' {
        $attribution = Get-HoiImageVerdict -Candidate (ConvertFrom-HoiEuropeanaResponse -Response (Get-ImageFixture -Source 'europeana' -Name 'cc-by')) -Policy (New-PortraitPolicy)
        $attribution.Accepted | Should -BeTrue -Because $attribution.Reason
        $attribution.Record.attribution | Should -Match '^Kulturparken Sm.land$'
        $shareAlike = Get-HoiImageVerdict -Candidate (ConvertFrom-HoiEuropeanaResponse -Response (Get-ImageFixture -Source 'europeana' -Name 'cc-by-sa')) -Policy (New-PortraitPolicy)
        $shareAlike.Accepted | Should -BeTrue -Because $shareAlike.Reason
        $shareAlike.Record.licenseCategory | Should -Be 'CC BY-SA'
        (Get-HoiImageVerdict -Candidate (ConvertFrom-HoiEuropeanaResponse -Response (Get-ImageFixture -Source 'europeana' -Name 'in-copyright')) -Policy (New-PortraitPolicy)).Reason | Should -Match "licence 'InC' \(inc\) is outside the policy"
    }

    It 'reads No Copyright - United States as public domain there only, and refuses image rights that differ from the record''s' {
        $unitedStatesOnly = Get-ImageFixture -Source 'europeana' -Name 'pdm'
        $unitedStatesOnly.object.aggregations[0].edmRights.def = @('http://rightsstatements.org/vocab/NoC-US/1.0/')
        $verdict = Get-HoiImageVerdict -Candidate (ConvertFrom-HoiEuropeanaResponse -Response $unitedStatesOnly) -Policy (New-PortraitPolicy)
        $verdict.Accepted | Should -BeTrue
        $verdict.Record.publicDomainReason | Should -Be 'NoC-US (Army Museum)'
        $verdict.Record.key = 'alpha'
        $verdict.Record.downloadSha256 = 'a' * 64
        $verdict.Record.fetched = '2026-11-03'
        @(Test-HoiImageRecord -Record $verdict.Record -Policy (New-PortraitPolicy) | Where-Object { $_.Level -eq 'WARN' -and $_.Message -match 'United States only' }).Count | Should -Be 1
        $mismatch = Get-ImageFixture -Source 'europeana' -Name 'pdm'
        $shownBy = $mismatch.object.aggregations[0].edmIsShownBy
        $webResource = @($mismatch.object.aggregations[0].webResources | Where-Object { $_.about -eq $shownBy })[0]
        $webResource | Add-Member -NotePropertyName 'webResourceEdmRights' -NotePropertyValue ([PSCustomObject]@{ def = @('http://rightsstatements.org/vocab/InC/1.0/') }) -Force
        (Get-HoiImageVerdict -Candidate (ConvertFrom-HoiEuropeanaResponse -Response $mismatch) -Policy (New-PortraitPolicy)).Reason | Should -Match 'differ on Europeana'
    }

    It 'sends the key in a header, never in the address' {
        Get-HoiEuropeanaRecordUrl -Id '/91616/arme_photo_AMA0013571' | Should -Be 'https://api.europeana.eu/record/v2/91616/arme_photo_AMA0013571.json'
        (Get-HoiEuropeanaHeaders -ApiKey 'secret')['X-Api-Key'] | Should -Be 'secret'
        Get-HoiEuropeanaSearchUrl -Query 'general' | Should -Not -Match 'wskey|secret'
    }
}

Describe 'Fetching' {
    It 'measures a download whose size the source does not give, keeps it under the key and records its hash' {
        $cacheDir = Join-Path $TestDrive 'measured'
        Mock Invoke-WebRequest { Write-TestJpeg -Path $OutFile -Width 400 -Height 520 }
        $candidate = ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by')
        $fetched = Invoke-HoiImageFetch -Candidate $candidate -Policy (New-PortraitPolicy) -CacheDir $cacheDir -Key 'svensson'
        $fetched.Accepted | Should -BeTrue -Because $fetched.Reason
        "$($fetched.Record.width)x$($fetched.Record.height)" | Should -Be '400x520'
        $fetched.CachePath | Should -Be (Join-Path $cacheDir 'svensson.jpg')
        $fetched.Record.downloadSha256 | Should -Be (Get-HoiImageSha256 -Path $fetched.CachePath)
        @(Get-ChildItem -LiteralPath $cacheDir -Filter '*.download') | Should -BeNullOrEmpty
    }

    It 'refuses a measured download that is too small or not a picture, and keeps nothing' {
        $cacheDir = Join-Path $TestDrive 'refused'
        Mock Invoke-WebRequest { Write-TestJpeg -Path $OutFile -Width 200 -Height 260 }
        $small = Invoke-HoiImageFetch -Candidate (ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by')) -Policy (New-PortraitPolicy) -CacheDir $cacheDir -Key 'small'
        $small.Reason | Should -Match '200x260 is under 300 px on its shorter side'
        Mock Invoke-WebRequest { [System.IO.File]::WriteAllText($OutFile, '<html>not found</html>') }
        $page = Invoke-HoiImageFetch -Candidate (ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by')) -Policy (New-PortraitPolicy) -CacheDir $cacheDir -Key 'page'
        $page.Reason | Should -Match 'not a JPEG, PNG, TIFF or GIF picture'
        @(Get-ChildItem -LiteralPath $cacheDir -File) | Should -BeNullOrEmpty
    }

    It 'with -DryRun downloads only to measure, and keeps nothing; a Commons dry run downloads nothing' {
        $cacheDir = Join-Path $TestDrive 'dry'
        Mock Invoke-WebRequest { Write-TestJpeg -Path $OutFile -Width 400 -Height 520 }
        (Invoke-HoiImageFetch -Candidate (ConvertFrom-HoiFinnaResponse -Response (Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by')) -Policy (New-PortraitPolicy) -CacheDir $cacheDir -Key 'dry' -DryRun).Accepted | Should -BeTrue
        @(Get-ChildItem -LiteralPath $cacheDir -File) | Should -BeNullOrEmpty
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
        (Invoke-HoiImageFetch -Candidate (ConvertFrom-HoiCommonsResponse -Response (Get-ImageFixture -Source 'commons' -Name 'pd')) -Policy (New-PortraitPolicy) -CacheDir $cacheDir -Key 'commons' -DryRun).Accepted | Should -BeTrue
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }

    It 'refuses own work on a photo the caller knows was taken before 1960, even when the metadata dates only the scan' {
        $reshot = Get-ImageFixture -Source 'commons' -Name 'pd-self-old'
        $reshot.query.pages[0].imageinfo[0].extmetadata.ImageDescription.value = 'General X, photographed from a print in 2008.'
        $reshot.query.pages[0].title = 'File:General X.jpg'
        (Invoke-HoiImageFetch -Candidate (ConvertFrom-HoiCommonsResponse -Response $reshot) -Policy (New-PortraitPolicy) -CacheDir (Join-Path $TestDrive 'own') -Key 'x' -DryRun).Accepted | Should -BeTrue
        (Invoke-HoiImageFetch -Candidate (ConvertFrom-HoiCommonsResponse -Response $reshot) -Policy (New-PortraitPolicy) -CacheDir (Join-Path $TestDrive 'own') -Key 'x' -KnownYears @('1943') -DryRun).Reason | Should -Match 'own work on a picture dated 1943'
    }
}

Describe 'Manual evidence' {
    BeforeEach {
        $script:RecordHtml = '<html><head><title>Record 42</title><script>var x = "Photographs taken by the army";</script></head><body><h1>General X at the front</h1><p>Photographer unknown, 1943.</p></body></html>'
        $script:RightsHtml = '<html><body><div style="display: none">hidden</div><p>Terms:&nbsp;Photographs taken by the army before 1945 are in the public domain and free to re' + [string][char]0x2011 + 'use. Credit the archive.</p></body></html>'
        Mock Invoke-RestMethod { if ($Uri -like '*terms*') { $script:RightsHtml } else { $script:RecordHtml } }
    }

    It 'accepts a quote found on the rights page after normalising spaces and dashes, and records its evidence' {
        $candidate = Get-HoiManualCandidate -Spec (New-ManualSpec) -Policy (New-PortraitPolicy)
        $verdict = Get-HoiImageVerdict -Candidate $candidate -Policy (New-PortraitPolicy)
        $verdict.Accepted | Should -BeTrue -Because $verdict.Reason
        $candidate.SizeKnown | Should -BeFalse
        $verdict.Record.source | Should -Be 'manual'
        $verdict.Record.publicDomainReason | Should -Be 'Army photograph before 1945, archive terms'
        $verdict.Record.evidence.quoteFoundIn | Should -Be 'rights'
        $verdict.Record.evidence.rightsTextSha256 | Should -Be (Get-HoiTextSha256 -Text $candidate.EvidenceTexts.Rights)
        $candidate.EvidenceTexts.Rights | Should -Not -Match 'hidden'
        $verdict.Record.ownerConfirmed | Should -Be ''
    }

    It 'takes a quote from the record page, and refuses a quote on neither page' {
        $recordQuote = New-ManualSpec
        $recordQuote.rightsQuote = 'General X at the front Photographer unknown, 1943. and nothing else here'
        $script:RecordHtml = '<html><body>General X at the front Photographer unknown, 1943. and nothing else here</body></html>'
        (Get-HoiManualCandidate -Spec $recordQuote -Policy (New-PortraitPolicy)).Record.evidence.quoteFoundIn | Should -Be 'record'
        $invented = New-ManualSpec
        $invented.rightsQuote = 'All photographs on this site are free to use for any purpose whatsoever.'
        (Get-HoiImageVerdict -Candidate (Get-HoiManualCandidate -Spec $invented -Policy (New-PortraitPolicy)) -Policy (New-PortraitPolicy)).Reason | Should -Match 'on neither the rights page nor the record page'
    }

    It 'refuses an incomplete evidence file: <Name>' -TestCases @(
        @{ Name = 'a short quote'; Change = { param($s) $s.rightsQuote = 'Public domain.' }; Expected = 'at least 40 characters' }
        @{ Name = 'an http image'; Change = { param($s) $s.imageUrl = 'http://archive.example.org/image/42.jpg' }; Expected = 'imageUrl must be an https address' }
        @{ Name = 'no licence code'; Change = { param($s) $s.license = 'free to use' }; Expected = 'license must be a licence code' }
    ) {
        $spec = New-ManualSpec
        & $Change $spec
        (Get-HoiImageVerdict -Candidate (Get-HoiManualCandidate -Spec $spec -Policy (New-PortraitPolicy)) -Policy (New-PortraitPolicy)).Reason | Should -Match ([regex]::Escape($Expected))
    }

    It 'keeps a manual row unconfirmed until the owner confirms it, and breaks the confirmation when the evidence changes' {
        $evidenceDir = Join-Path $TestDrive 'evidence'
        $candidate = Get-HoiManualCandidate -Spec (New-ManualSpec) -Policy (New-PortraitPolicy)
        $record = (Get-HoiImageVerdict -Candidate $candidate -Policy (New-PortraitPolicy)).Record
        $record.key = 'general_x'
        $record.downloadSha256 = 'b' * 64
        $record.fetched = '2026-11-03'
        $record.width = 600
        $record.height = 800
        Save-HoiManualEvidence -Candidate $candidate -EvidenceDir $evidenceDir -Key 'general_x'
        @(Test-HoiManualEvidence -Record $record -EvidenceDir $evidenceDir) | Should -BeNullOrEmpty
        $usedErrors = @(Test-HoiImageRecord -Record $record -Policy (New-PortraitPolicy) -EvidenceDir $evidenceDir | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { $_.Message })
        ($usedErrors -join "`n") | Should -Match 'the owner has not confirmed this manual licence'
        @(Test-HoiImageRecord -Record $record -Policy (New-PortraitPolicy) -EvidenceDir $evidenceDir -Used $false | Where-Object { $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
        Test-HoiOwnerConfirmation -Record $record | Should -BeFalse
        $confirmed = Confirm-HoiManualRecord -Record $record -EvidenceDir $evidenceDir
        $confirmed.ownerConfirmed.date | Should -Match '^\d{4}-\d{2}-\d{2}$'
        Test-HoiOwnerConfirmation -Record $confirmed | Should -BeTrue
        @(Test-HoiImageRecord -Record $confirmed -Policy (New-PortraitPolicy) -EvidenceDir $evidenceDir | Where-Object { $_.Level -eq 'ERROR' }) | Should -BeNullOrEmpty
        $confirmed.license = 'cc0'
        Test-HoiOwnerConfirmation -Record $confirmed | Should -BeFalse
        $confirmed.license = 'pd'
        [System.IO.File]::AppendAllText((Join-Path $evidenceDir 'general_x.rights.txt'), ' edited')
        ((@(Test-HoiManualEvidence -Record $confirmed -EvidenceDir $evidenceDir)) -join "`n") | Should -Match 'differs from the one recorded at fetch time'
        { Confirm-HoiManualRecord -Record $confirmed -EvidenceDir $evidenceDir } | Should -Throw '*cannot be confirmed*'
    }

    It 'confirms only a manual row' {
        $commonsRecord = New-AcceptedRecord -FixtureName 'pd'
        { Confirm-HoiManualRecord -Record $commonsRecord -EvidenceDir $TestDrive } | Should -Throw '*only a manual row needs the owner*'
    }

    It 'finds the quote on the live page again for the audit' {
        $record = (Get-HoiImageVerdict -Candidate (Get-HoiManualCandidate -Spec (New-ManualSpec) -Policy (New-PortraitPolicy)) -Policy (New-PortraitPolicy)).Record
        Test-HoiManualQuoteOnline -Record $record -Policy (New-PortraitPolicy) | Should -BeTrue
        $script:RightsHtml = '<html><body>All rights reserved.</body></html>'
        Test-HoiManualQuoteOnline -Record $record -Policy (New-PortraitPolicy) | Should -BeFalse
    }
}

Describe 'Search' {
    It 'judges every Commons and Finna hit with the policy and keeps the search order' {
        Mock Invoke-RestMethod {
            if ($Uri -like 'https://commons.wikimedia.org/*') {
                $firstPage = (Get-ImageFixture -Source 'commons' -Name 'cc-by-sa-3.0-de').query.pages[0]
                $firstPage | Add-Member -NotePropertyName 'index' -NotePropertyValue 2 -Force
                $secondPage = (Get-ImageFixture -Source 'commons' -Name 'pd-self-old').query.pages[0]
                $secondPage | Add-Member -NotePropertyName 'index' -NotePropertyValue 1 -Force
                return [PSCustomObject]@{ query = [PSCustomObject]@{ pages = @($firstPage, $secondPage) } }
            }
            return [PSCustomObject]@{ resultCount = 2; records = @((Get-ImageFixture -Source 'finna' -Name 'sa-kuva-cc-by').records[0], (Get-ImageFixture -Source 'finna' -Name 'by-nc-nd').records[0]) }
        }
        $rows = @(Find-HoiImageCandidates -Query 'Rundstedt' -Sources @('commons', 'finna') -Policy (New-PortraitPolicy) -Limit 5)
        $rows.Count | Should -Be 4
        $rows[0].Verdict | Should -Match '^REFUSED: own work'
        $rows[1].Id | Should -Be 'File:Bundesarchiv Bild 183-S37772, Gerd v. Rundstedt.jpg'
        $rows[1].Verdict | Should -Be 'ACCEPTABLE'
        $rows[2].Verdict | Should -Be 'ACCEPTABLE, size checked at download'
        $rows[3].Accepted | Should -BeFalse
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri.AbsoluteUri -match 'generator=search' -and $Uri.AbsoluteUri -match 'gsrsearch=Rundstedt%20filetype%3Abitmap' -and $Uri.AbsoluteUri -match 'gsrlimit=5' }
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri.AbsoluteUri -match '^https://api\.finna\.fi/api/v1/search\?lookfor=Rundstedt&limit=5&' -and $Uri.AbsoluteUri -match 'online_boolean' }
    }

    It 'refuses a source it cannot search' {
        { Find-HoiImageCandidates -Query 'x' -Sources @('manual') -Policy (New-PortraitPolicy) } | Should -Throw '*cannot be searched*'
    }
}

Describe 'Credits' {
    It 'counts an institution credit only under a policy that allows it' {
        $institutionCredit = Get-ImageFixture -Source 'commons' -Name 'cc-by'
        $institutionCredit.query.pages[0].imageinfo[0].extmetadata.Artist.value = 'Unknown author'
        $institutionCredit.query.pages[0].imageinfo[0].extmetadata.Credit.value = 'Bundesarchiv, Bild 146-1970-050-13'
        (Get-CommonsFixtureVerdict -Response $institutionCredit -Policy (New-EventPolicy)).Reason | Should -Be 'CC BY without a named author on Commons: the credit cannot be written'
        $accepted = Get-CommonsFixtureVerdict -Response $institutionCredit -Policy (New-PortraitPolicy)
        $accepted.Accepted | Should -BeTrue -Because $accepted.Reason
        $accepted.Record.attribution | Should -Be 'Bundesarchiv, Bild 146-1970-050-13'
    }

    It 'never takes an uploader''s claim or a platform name as an institution credit: <Credit>' -TestCases @(
        @{ Credit = 'Own photo' }
        @{ Credit = 'I took this photo myself in 1944' }
        @{ Credit = 'Flickr' }
        @{ Credit = 'My own scan of a family album' }
    ) {
        $uploaderCredit = Get-ImageFixture -Source 'commons' -Name 'cc-by'
        $uploaderCredit.query.pages[0].imageinfo[0].extmetadata.Artist.value = 'Unknown author'
        $uploaderCredit.query.pages[0].imageinfo[0].extmetadata.Credit.value = $Credit
        (Get-CommonsFixtureVerdict -Response $uploaderCredit -Policy (New-PortraitPolicy)).Accepted | Should -BeFalse
    }

    It 'reads "own photo" and "my own scan" as own-work claims' {
        Test-HoiOwnWorkClaim -Templates @() -PublicDomainReason '' -AttributionText 'Own photo' | Should -BeTrue
        Test-HoiOwnWorkClaim -Templates @() -PublicDomainReason '' -AttributionText 'My own scan' | Should -BeTrue
        Test-HoiOwnWorkClaim -Templates @() -PublicDomainReason '' -AttributionText 'Bundesarchiv, Bild 146' | Should -BeFalse
    }
}

Describe 'Owner confirmation' {
    It 'accepts only a confirmation whose hash matches the evidence, never a hand-written value' {
        $record = New-AcceptedRecord -FixtureName 'pd'
        $record.source = 'manual'
        $record | Add-Member -NotePropertyName 'evidence' -NotePropertyValue ([PSCustomObject]@{ recordTextSha256 = 'a' * 64; rightsTextSha256 = 'b' * 64; rightsQuote = 'quote' }) -Force
        foreach ($handWritten in @('yes', 'confirmed', ([PSCustomObject]@{ date = '2026-11-03'; evidenceSha256 = 'c' * 64 }), ([PSCustomObject]@{ date = '2026-11-03' }))) {
            $record | Add-Member -NotePropertyName 'ownerConfirmed' -NotePropertyValue $handWritten -Force
            Test-HoiOwnerConfirmation -Record $record | Should -BeFalse -Because "ownerConfirmed = $handWritten"
        }
        $record.ownerConfirmed = [PSCustomObject]@{ date = '2026-11-03'; evidenceSha256 = (Get-HoiEvidenceSha256 -Record $record) }
        Test-HoiOwnerConfirmation -Record $record | Should -BeTrue
    }
}

Describe 'Own work on an old picture' {
    It 'refuses an own-work claim on a picture dated before 1960 in every category: <Category>' -TestCases @(
        @{ Category = 'PD'; Fixture = 'pd-self-old'; License = 'pd'; Year = 1936 }
        @{ Category = 'CC0'; Fixture = 'own-cc0-old'; License = 'cc0'; Year = 1944 }
        @{ Category = 'CC BY'; Fixture = 'own-cc0-old'; License = 'cc-by-4.0'; Year = 1944 }
        @{ Category = 'CC BY-SA'; Fixture = 'cc-by-sa'; License = 'cc-by-sa-4.0'; Year = 1939 }
    ) {
        $response = Get-ImageFixture -Source 'commons' -Name $Fixture
        $response.query.pages[0].imageinfo[0].extmetadata.License.value = $License
        $verdict = Get-CommonsFixtureVerdict -Response $response -Policy (New-PortraitPolicy)
        $verdict.Accepted | Should -BeFalse
        $verdict.Reason | Should -Match "own work on a picture dated $Year"
        $verdict.Record.ownWorkClaim | Should -BeTrue
        $verdict.Record.pictureYear | Should -Be $Year
    }

    It 'accepts own work on a recent picture' {
        $recent = Get-ImageFixture -Source 'commons' -Name 'pd-self-old'
        $recent.query.pages[0].imageinfo[0].extmetadata.ImageDescription.value = 'The treaty memorial in Paris, photographed in 1985.'
        (Get-CommonsFixtureVerdict -Response $recent -Policy (New-EventPolicy)).Accepted | Should -BeTrue
    }

    It 'takes the earliest year, so a scan or upload date does not hide the picture''s own' {
        $scanned = Get-ImageFixture -Source 'commons' -Name 'pd-self-old'
        $scanned.query.pages[0].imageinfo[0].extmetadata | Add-Member -NotePropertyName 'DateTimeOriginal' -NotePropertyValue ([PSCustomObject]@{ value = '2007-06-01' }) -Force
        (Get-CommonsFixtureVerdict -Response $scanned -Policy (New-EventPolicy)).Reason | Should -Match 'dated 1936'
        Get-HoiPictureYear -Texts @('2018-10-28', 'Magazine page of 1937', '') | Should -Be 1937
        Get-HoiPictureYear -Texts @('', 'no year here') | Should -BeNullOrEmpty
    }
}

Describe 'Licence codes' {
    It 'maps <Text> to <Code> and <Category>' -TestCases @(
        @{ Text = 'http://creativecommons.org/licenses/by/4.0/'; Code = 'cc-by-4.0'; Category = 'CC BY' }
        @{ Text = 'http://creativecommons.org/licenses/by-sa/3.0/de/'; Code = 'cc-by-sa-3.0-de'; Category = 'CC BY-SA' }
        @{ Text = 'http://creativecommons.org/licenses/by-nc/4.0/'; Code = 'cc-by-nc-4.0'; Category = '' }
        @{ Text = 'http://creativecommons.org/licenses/by-nd/4.0/'; Code = 'cc-by-nd-4.0'; Category = '' }
        @{ Text = 'http://creativecommons.org/publicdomain/zero/1.0/'; Code = 'cc0'; Category = 'CC0' }
        @{ Text = 'http://creativecommons.org/publicdomain/mark/1.0/'; Code = 'pd'; Category = 'PD' }
        @{ Text = 'http://rightsstatements.org/vocab/NoC-US/1.0/'; Code = 'noc-us'; Category = 'PD' }
        @{ Text = 'http://rightsstatements.org/vocab/InC/1.0/'; Code = 'inc'; Category = '' }
        @{ Text = 'http://rightsstatements.org/vocab/NoC-NC/1.0/'; Code = 'noc-nc'; Category = '' }
        @{ Text = 'http://www.europeana.eu/rights/rr-f/'; Code = ''; Category = '' }
        @{ Text = 'CC BY 4.0'; Code = 'cc-by-4.0'; Category = 'CC BY' }
        @{ Text = 'CC BY-SA 4.0'; Code = 'cc-by-sa-4.0'; Category = 'CC BY-SA' }
        @{ Text = 'CC BY-NC-ND 4.0'; Code = 'cc-by-nc-nd-4.0'; Category = '' }
        @{ Text = 'CC0'; Code = 'cc0'; Category = 'CC0' }
        @{ Text = 'PDM'; Code = 'pd'; Category = 'PD' }
        @{ Text = 'InC'; Code = ''; Category = '' }
    ) {
        $licence = ConvertTo-HoiLicence -Text $Text
        $licence.Code | Should -Be $Code
        Get-HoiLicenceCategory -LicenseCode $licence.Code | Should -Be $Category
    }

    It 'gives a ported licence its own URL and short name' {
        $licence = ConvertTo-HoiLicence -Text 'http://creativecommons.org/licenses/by-sa/3.0/de/'
        $licence.Url | Should -Be 'https://creativecommons.org/licenses/by-sa/3.0/de/'
        $licence.ShortName | Should -Be 'CC BY-SA 3.0 DE'
    }
}

Describe 'Policy' {
    It 'refuses an unknown category, an unknown source and a policy without a size' {
        { New-HoiImagePolicy -AcceptedCategories @('CC BY-NC') -AcceptedSources @('commons') -MinShorterSide 1 -MinSizeText 'x' -BotName 'b' -ContactUrl 'c' -FetchCommand 'f' -ItemNounPlural 'n' } | Should -Throw '*unknown licence category*'
        { New-HoiImagePolicy -AcceptedCategories @('PD') -AcceptedSources @('flickr') -MinShorterSide 1 -MinSizeText 'x' -BotName 'b' -ContactUrl 'c' -FetchCommand 'f' -ItemNounPlural 'n' } | Should -Throw '*unknown image source*'
        { New-HoiImagePolicy -AcceptedCategories @('PD') -AcceptedSources @('commons') -MinSizeText 'x' -BotName 'b' -ContactUrl 'c' -FetchCommand 'f' -ItemNounPlural 'n' } | Should -Throw '*needs -MinShorterSide*'
    }

    It 'refuses a source outside the policy' {
        $candidate = ConvertFrom-HoiCommonsResponse -Response (Get-ImageFixture -Source 'commons' -Name 'pd')
        $finnaOnly = New-HoiImagePolicy -AcceptedCategories @('PD') -AcceptedSources @('finna') -MinShorterSide 1 -MinSizeText 'x' -BotName 'b' -ContactUrl 'c' -FetchCommand 'f' -ItemNounPlural 'n'
        (Get-HoiImageVerdict -Candidate $candidate -Policy $finnaOnly).Reason | Should -Match 'the source Wikimedia Commons is outside the policy'
    }
}

Describe 'API keys' {
    BeforeEach {
        $script:SavedKey = [Environment]::GetEnvironmentVariable('HOI_EUROPEANA_WSKEY')
        [Environment]::SetEnvironmentVariable('HOI_EUROPEANA_WSKEY', $null)
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('HOI_EUROPEANA_WSKEY', $script:SavedKey)
    }

    It 'reads the environment first, then the local key file, and names both when neither has a key' {
        $managerRoot = Join-Path $TestDrive 'manager'
        New-Item -ItemType Directory -Path (Join-Path $managerRoot 'Config') -Force | Out-Null
        { Get-HoiImageSourceKey -Source 'europeana' -ManagerRoot $managerRoot } | Should -Throw '*HOI_EUROPEANA_WSKEY*image-sources.local.json*'
        [System.IO.File]::WriteAllText((Join-Path $managerRoot 'Config\image-sources.local.json'), '{ "keys": { "europeana": "from-file" } }')
        Get-HoiImageSourceKey -Source 'europeana' -ManagerRoot $managerRoot | Should -Be 'from-file'
        [Environment]::SetEnvironmentVariable('HOI_EUROPEANA_WSKEY', 'from-environment')
        Get-HoiImageSourceKey -Source 'europeana' -ManagerRoot $managerRoot | Should -Be 'from-environment'
        { Get-HoiImageSourceKey -Source 'commons' } | Should -Throw '*needs no key*'
    }

    It 'keeps no real key in any fixture' {
        $fixtureTexts = @(Get-ChildItem -LiteralPath $script:ImageFixtureRoot -Recurse -File -Filter '*.json' | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) })
        foreach ($fixtureText in $fixtureTexts) {
            foreach ($keyMatch in [regex]::Matches($fixtureText, '"(?:apikey|wskey|api_key)"\s*:\s*"([^"]*)"')) {
                $keyMatch.Groups[1].Value | Should -Be 'FIXTURE'
            }
            $fixtureText | Should -Not -Match 'api2demo'
        }
    }
}

Describe 'Requests' {
    It 'waits and tries again when the server answers 429 or 503, as long as Retry-After asks' {
        $script:Attempts = 0
        Mock Start-Sleep { }
        Mock Invoke-RestMethod {
            $script:Attempts++
            if ($script:Attempts -le 2) {
                $exception = [System.Exception]::new('Too many requests')
                Add-Member -InputObject $exception -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = $(if ($script:Attempts -eq 1) { 429 } else { 503 }); Headers = @{ 'Retry-After' = '30' } })
                throw $exception
            }
            'answer'
        }
        Invoke-HoiImageRequest -Uri 'https://api.finna.fi/api/v1/record' -Policy (New-PortraitPolicy) 6>$null | Should -Be 'answer'
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 30 }
    }

    It 'gives up after the last attempt, names the server, and never retries another failure' {
        Mock Start-Sleep { }
        Mock Invoke-RestMethod {
            $exception = [System.Exception]::new('Too many requests')
            Add-Member -InputObject $exception -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = 429; Headers = @{} })
            throw $exception
        }
        $requestOutput = [System.Collections.Generic.List[string]]::new()
        { Invoke-HoiImageRequest -Uri 'https://commons.wikimedia.org/w/api.php' -Policy (New-PortraitPolicy) -MaxAttempts 3 6>&1 | ForEach-Object { $requestOutput.Add([string]$_) } } | Should -Throw
        @($requestOutput | Where-Object { $_ -like '  Wikimedia answered 429:*' }).Count | Should -Be 3
        $requestOutput[-1] | Should -Be '  giving up after 3 attempts'
        $finnaOutput = [System.Collections.Generic.List[string]]::new()
        { Invoke-HoiImageRequest -Uri 'https://api.finna.fi/api/v1/record' -Policy (New-PortraitPolicy) -MaxAttempts 1 6>&1 | ForEach-Object { $finnaOutput.Add([string]$_) } } | Should -Throw
        $finnaOutput[0] | Should -BeLike '  api.finna.fi answered 429:*'
        Mock Invoke-RestMethod { throw 'not found' }
        { Invoke-HoiImageRequest -Uri 'https://commons.wikimedia.org/w/api.php' -Policy (New-PortraitPolicy) 6>$null } | Should -Throw 'not found'
    }

    It 'sends the policy''s bot name and any extra header' {
        Mock Invoke-RestMethod { $Headers }
        $sentHeaders = Invoke-HoiImageRequest -Uri 'https://example.com/' -Policy (New-PortraitPolicy) -Headers @{ 'X-Api-Key' = 'secret' }
        $sentHeaders['User-Agent'] | Should -Match '^TestBot/1\.0 \(https://example\.com/test; '
        $sentHeaders['X-Api-Key'] | Should -Be 'secret'
    }
}

Describe 'Recorded rows' {
    It 'passes an accepted record, including a legacy row without the new fields' {
        $record = New-AcceptedRecord -FixtureName 'cc-by'
        @(Test-HoiImageRecord -Record $record -Policy (New-PortraitPolicy)) | Should -BeNullOrEmpty
        $legacyRow = [PSCustomObject]@{ key = 'alpha'; commonsTitle = $record.commonsTitle; pageUrl = $record.pageUrl; downloadUrl = $record.downloadUrl; downloadSha256 = 'b' * 64; author = $record.author; credit = $record.credit; licenseShortName = $record.licenseShortName; license = $record.license; licenseCategory = $record.licenseCategory; licenseUrl = $record.licenseUrl; usageTerms = ''; restrictions = ''; dateOriginal = '1939'; width = 600; height = 800; fetched = '2026-11-01'; publicDomainReason = '' }
        @(Test-HoiImageRecord -Record $legacyRow -Policy (New-EventPolicy)) | Should -BeNullOrEmpty
    }

    It 'fails <Name>' -TestCases @(
        @{ Name = 'a category the code does not give'; Expected = 'does not match its Commons code'; Change = { param($r) $r.license = 'cc-by-sa-4.0' } }
        @{ Name = 'a BY-SA row under a policy without it'; Expected = 'is outside the policy (public domain, CC0, CC BY)'; Policy = 'event'; Change = { param($r) $r.license = 'cc-by-sa-4.0'; $r.licenseCategory = 'CC BY-SA' } }
        @{ Name = 'a BY-SA row with a BY licence URL'; Expected = 'CC BY-SA needs a named author or an institution credit and the Creative Commons BY-SA licence URL'; Change = { param($r) $r.license = 'cc-by-sa-4.0'; $r.licenseCategory = 'CC BY-SA' } }
        @{ Name = 'a BY-SA 1.0 row'; Expected = 'CC BY-SA 1.0 has no clause'; Change = { param($r) $r.license = 'cc-by-sa-1.0'; $r.licenseCategory = 'CC BY-SA'; $r.licenseUrl = 'https://creativecommons.org/licenses/by-sa/1.0/' } }
        @{ Name = 'a CC BY row without any credit'; Expected = 'CC BY needs a named author'; Change = { param($r) $r.author = ''; $r.attribution = ''; $r.credit = '' } }
        @{ Name = 'a page off Commons'; Expected = 'not a Wikimedia Commons file page: photos come only through build.ps1 -FetchPhoto'; Change = { param($r) $r.pageUrl = 'https://example.com/page' } }
        @{ Name = 'a download off Wikimedia'; Expected = "is not on Wikimedia's upload servers"; Change = { param($r) $r.downloadUrl = 'https://example.com/a.jpg' } }
        @{ Name = 'a row without its hash'; Expected = 'no downloadSha256'; Change = { param($r) $r.downloadSha256 = '' } }
        @{ Name = 'a row under the size'; Expected = 'a portrait source needs at least 300 px on its shorter side'; Change = { param($r) $r.height = 280 } }
        @{ Name = 'a source outside the policy'; Expected = "source 'finna' is outside the policy"; Policy = 'event'; Change = { param($r) $r.source = 'finna' } }
        @{ Name = 'an old own-work row that is used'; Expected = 'own work on a picture dated 1939'; Change = { param($r) $r.ownWorkClaim = $true; $r.pictureYear = 1944 } }
    ) {
        $record = New-AcceptedRecord -FixtureName 'cc-by'
        & $Change $record
        $policy = if ($Policy -eq 'event') { New-EventPolicy } else { New-PortraitPolicy }
        $errorMessages = @(Test-HoiImageRecord -Record $record -Policy $policy | Where-Object { $_.Level -eq 'ERROR' } | ForEach-Object { $_.Message })
        ($errorMessages -join "`n") | Should -Match ([regex]::Escape($Expected))
    }

    It 'warns about public domain in the United States only, and leaves an unused own-work row alone' {
        $record = New-AcceptedRecord -FixtureName 'pd'
        $record.publicDomainReason = 'PD-USGov-FSA'
        @(Test-HoiImageRecord -Record $record -Policy (New-PortraitPolicy) | Where-Object { $_.Level -eq 'WARN' -and $_.Message -match 'United States only' }).Count | Should -Be 1
        $record.ownWorkClaim = $true
        $record.pictureYear = 1940
        @(Test-HoiImageRecord -Record $record -Policy (New-PortraitPolicy) -Used $false | Where-Object { $_.Message -match 'own work' }) | Should -BeNullOrEmpty
    }

    It 'falls back to the credit and the date of a legacy row for the own-work check' {
        $legacyRow = New-AcceptedRecord -FixtureName 'pd'
        $legacyRow.PSObject.Properties.Remove('ownWorkClaim')
        $legacyRow.PSObject.Properties.Remove('pictureYear')
        $legacyRow.publicDomainReason = 'PD-self'
        $legacyRow.dateOriginal = '1937'
        (@(Test-HoiImageRecord -Record $legacyRow -Policy (New-PortraitPolicy) | ForEach-Object { $_.Message }) -join "`n") | Should -Match 'own work on a picture dated 1937'
    }

    It 'dates a re-shot print by the year the caller knows the picture shows' {
        $reshotPrint = New-AcceptedRecord -FixtureName 'pd'
        $reshotPrint.publicDomainReason = 'PD-self'
        $reshotPrint.dateOriginal = '2008-04-09 15:00:36'
        $reshotPrint.pictureYear = 2008
        $reshotPrint.commonsTitle = 'File:Jeantouzetduvigier.jpg'
        @(Test-HoiImageRecord -Record $reshotPrint -Policy (New-PortraitPolicy) | Where-Object { $_.Message -match 'own work' }) | Should -BeNullOrEmpty
        (@(Test-HoiImageRecord -Record $reshotPrint -Policy (New-PortraitPolicy) -KnownYear '1944' | ForEach-Object { $_.Message }) -join "`n") | Should -Match 'own work on a picture dated 1944'
    }

    It 'finds a cached download that differs from the record' {
        $record = New-AcceptedRecord -FixtureName 'pd'
        $cacheDir = Join-Path $TestDrive 'cache'
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Get-HoiImageCachePath -CacheDir $cacheDir -Record $record), 'other bytes')
        (@(Test-HoiImageRecord -Record $record -Policy (New-PortraitPolicy) -CacheDir $cacheDir | ForEach-Object { $_.Message }) -join "`n") | Should -Match 'does not match the SHA-256 recorded at fetch time'
    }
}
