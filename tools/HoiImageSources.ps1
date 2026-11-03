function Get-HoiImageProperty {
    param($Object, [string]$Name, $Default = $null)

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name) -and $null -ne $Object[$Name]) {
            return $Object[$Name]
        }
        return $Default
    }
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name] -and $null -ne $Object.$Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-HoiImageArray {
    param($Value)

    $items = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $Value -and $Value.PSObject.Properties['value'] -and $Value.PSObject.Properties['Count'] -and @($Value.PSObject.Properties).Count -eq 2) {
        $Value = $Value.value
    }
    foreach ($item in @($Value)) {
        if ($null -ne $item) {
            $items.Add($item)
        }
    }
    return $items.ToArray()
}

function Get-HoiImageToday {
    return (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-HoiImageSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($fullPath)
    try {
        return ([System.BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '')).ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $hasher.Dispose()
    }
}

function Get-HoiTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')).ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
}

function ConvertFrom-HoiImageHtml {
    param([AllowEmptyString()][string]$Html)

    $scriptlessHtml = [regex]::Replace([string]$Html, '(?is)<(script|style|noscript)\b[^>]*>.*?</\1\s*>', ' ')
    $visibleHtml = [regex]::Replace($scriptlessHtml, '(?is)<(\w+)[^>]*display:\s*none[^>]*>.*?</\1>', '')
    $plainText = [regex]::Replace($visibleHtml, '<[^>]+>', '')
    return ([System.Net.WebUtility]::HtmlDecode($plainText) -replace '\s+', ' ').Trim()
}

function Get-HoiShareAlikePortraitLicence {
    return [PSCustomObject]@{ ShortName = 'CC BY-SA 4.0'; Url = 'https://creativecommons.org/licenses/by-sa/4.0/' }
}

function Get-HoiImageSourceText {
    param([AllowEmptyCollection()]$Records)

    $sourceNames = [System.Collections.Generic.List[string]]::new()
    foreach ($record in @($Records)) {
        $source = [string](Get-HoiImageProperty -Object $record -Name 'source' -Default 'commons')
        $sourceName = if ($source -eq 'manual') { [string](Get-HoiImageProperty -Object $record -Name 'institution' -Default 'an archive') } else { (Get-HoiImageSourceRules -Source $source).Label }
        if ($sourceName -and -not $sourceNames.Contains($sourceName)) {
            $sourceNames.Add($sourceName)
        }
    }
    if ($sourceNames.Count -eq 0) {
        return 'Wikimedia Commons'
    }
    if ($sourceNames.Count -eq 1) {
        return $sourceNames[0]
    }
    return ((($sourceNames.ToArray())[0..($sourceNames.Count - 2)] -join ', ') + ' and ' + $sourceNames[$sourceNames.Count - 1])
}

function Get-HoiImageCategories {
    return @('PD', 'CC0', 'CC BY', 'CC BY-SA')
}

function Get-HoiImageSourceNames {
    return @('commons', 'finna', 'europeana', 'manual')
}

function Get-HoiOwnWorkCutoffYear {
    return 1960
}

function New-HoiImagePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string[]]$AcceptedCategories,
        [Parameter(Mandatory = $true)][string[]]$AcceptedSources,
        [int]$MinShorterSide = 0,
        [int]$MinWidth = 0,
        [int]$MinHeight = 0,
        [Parameter(Mandatory = $true)][string]$MinSizeText,
        [int]$OwnWorkCutoffYear = (Get-HoiOwnWorkCutoffYear),
        [switch]$InstitutionCredit,
        [Parameter(Mandatory = $true)][string]$BotName,
        [Parameter(Mandatory = $true)][string]$ContactUrl,
        [Parameter(Mandatory = $true)][string]$FetchCommand,
        [Parameter(Mandatory = $true)][string]$ItemNounPlural
    )

    foreach ($category in $AcceptedCategories) {
        if ((Get-HoiImageCategories) -cnotcontains $category) {
            throw "unknown licence category '$category'; the categories are: $((Get-HoiImageCategories) -join ', ')"
        }
    }
    foreach ($source in $AcceptedSources) {
        if ((Get-HoiImageSourceNames) -cnotcontains $source) {
            throw "unknown image source '$source'; the sources are: $((Get-HoiImageSourceNames) -join ', ')"
        }
    }
    if ($MinShorterSide -le 0 -and ($MinWidth -le 0 -or $MinHeight -le 0)) {
        throw 'a policy needs -MinShorterSide or both -MinWidth and -MinHeight'
    }
    return [PSCustomObject]@{
        AcceptedCategories = @($AcceptedCategories)
        AcceptedSources    = @($AcceptedSources)
        MinShorterSide     = $MinShorterSide
        MinWidth           = $MinWidth
        MinHeight          = $MinHeight
        MinSizeText        = $MinSizeText
        OwnWorkCutoffYear  = $OwnWorkCutoffYear
        InstitutionCredit  = [bool]$InstitutionCredit
        BotName            = $BotName
        ContactUrl         = $ContactUrl
        FetchCommand       = $FetchCommand
        ItemNounPlural     = $ItemNounPlural
    }
}

function Get-HoiImagePolicyCategoryText {
    param([Parameter(Mandatory = $true)]$Policy)

    $categoryNames = @($Policy.AcceptedCategories | ForEach-Object { if ($_ -eq 'PD') { 'public domain' } else { $_ } })
    if ($categoryNames.Count -le 1) {
        return ($categoryNames -join '')
    }
    return (($categoryNames[0..($categoryNames.Count - 2)] -join ', ') + ' or ' + $categoryNames[-1])
}

function Get-HoiImageSourceRules {
    param([Parameter(Mandatory = $true)][string]$Source)

    $apiReasonPattern = '^(PDM|NoC-US) \(.+\)$'
    switch ($Source) {
        'commons' {
            return [PSCustomObject]@{ Label = 'Wikimedia Commons'; ShortLabel = 'Commons'; PagePattern = '^https://commons\.wikimedia\.org/wiki/File:'; PageText = 'a Wikimedia Commons file page'; DownloadPattern = '^https://(upload|thumb)\.wikimedia\.org/wikipedia/commons/'; DownloadText = "Wikimedia's upload servers"; ReasonPattern = '^PD-[^,]+(, PD-[^,]+)*$'; ReasonText = 'the reason Commons gives (a PD- licence template)'; MissingReasonText = 'a PD- licence template on Commons that states why' }
        }
        'finna' {
            return [PSCustomObject]@{ Label = 'Finna'; ShortLabel = 'Finna'; PagePattern = '^https://www\.finna\.fi/Record/'; PageText = 'a Finna record page'; DownloadPattern = '^https://(api\.)?finna\.fi/'; DownloadText = "Finna's servers"; ReasonPattern = $apiReasonPattern; ReasonText = 'the rights statement Finna gives'; MissingReasonText = 'a rights statement on Finna that states why' }
        }
        'europeana' {
            return [PSCustomObject]@{ Label = 'Europeana'; ShortLabel = 'Europeana'; PagePattern = '^https://www\.europeana\.eu/item/'; PageText = 'a Europeana item page'; DownloadPattern = '^https?://'; DownloadText = 'a web server'; ReasonPattern = $apiReasonPattern; ReasonText = 'the rights statement Europeana gives'; MissingReasonText = 'a rights statement on Europeana that states why' }
        }
        'manual' {
            return [PSCustomObject]@{ Label = 'the archive page'; ShortLabel = 'the archive page'; PagePattern = '^https://'; PageText = 'an https archive record page'; DownloadPattern = '^https://'; DownloadText = 'an https server'; ReasonPattern = '\S'; ReasonText = 'a stated reason'; MissingReasonText = 'a stated reason' }
        }
    }
    throw "unknown image source '$Source'; the sources are: $((Get-HoiImageSourceNames) -join ', ')"
}

function ConvertTo-HoiLicence {
    param([AllowEmptyString()][string]$Text)

    $licenceText = ([string]$Text).Trim()
    $creativeCommonsMatch = [regex]::Match($licenceText, '(?i)creativecommons\.org/licenses/([a-z-]+)/(\d(?:\.\d)?)(?:/([a-z]{2,}))?')
    if (-not $creativeCommonsMatch.Success) {
        $creativeCommonsMatch = [regex]::Match($licenceText, '(?i)^cc[ -]((?:by)(?:-nc)?(?:-sa|-nd)?)[ -](\d(?:\.\d)?)(?:[ -]([a-z]{2,}))?$')
    }
    if ($creativeCommonsMatch.Success) {
        $licenceType = $creativeCommonsMatch.Groups[1].Value.ToLowerInvariant()
        $licenceVersion = $creativeCommonsMatch.Groups[2].Value
        $licencePort = $creativeCommonsMatch.Groups[3].Value.ToLowerInvariant()
        $portSuffix = if ($licencePort) { '-' + $licencePort } else { '' }
        $portPath = if ($licencePort) { $licencePort + '/' } else { '' }
        $portName = if ($licencePort) { ' ' + $licencePort.ToUpperInvariant() } else { '' }
        return [PSCustomObject]@{
            Code      = "cc-$licenceType-$licenceVersion$portSuffix"
            ShortName = ('CC ' + $licenceType.ToUpperInvariant() + ' ' + $licenceVersion + $portName)
            Url       = "https://creativecommons.org/licenses/$licenceType/$licenceVersion/$portPath"
        }
    }
    if ($licenceText -match '(?i)creativecommons\.org/publicdomain/zero/' -or $licenceText -match '(?i)^cc[ -]?0\b' -or $licenceText -match '(?i)^cc-zero\b') {
        return [PSCustomObject]@{ Code = 'cc0'; ShortName = 'CC0'; Url = 'https://creativecommons.org/publicdomain/zero/1.0/' }
    }
    if ($licenceText -match '(?i)creativecommons\.org/publicdomain/mark/' -or $licenceText -match '(?i)^(pd|pdm|public domain( mark)?( 1\.0)?)$') {
        return [PSCustomObject]@{ Code = 'pd'; ShortName = 'Public Domain Mark'; Url = 'https://creativecommons.org/publicdomain/mark/1.0/' }
    }
    $rightsStatementMatch = [regex]::Match($licenceText, '(?i)rightsstatements\.org/(?:vocab|page)/([A-Za-z]+(?:-[A-Za-z]+)*)/')
    if ($rightsStatementMatch.Success) {
        $statementName = $rightsStatementMatch.Groups[1].Value
        return [PSCustomObject]@{ Code = $statementName.ToLowerInvariant(); ShortName = $statementName; Url = "http://rightsstatements.org/vocab/$statementName/1.0/" }
    }
    return [PSCustomObject]@{ Code = ''; ShortName = $licenceText; Url = '' }
}

function Get-HoiLicenceCategory {
    param([AllowEmptyString()][string]$LicenseCode)

    $normalizedCode = ([string]$LicenseCode).ToLowerInvariant()
    if ($normalizedCode -match '^(pd|public domain|noc-us$)') {
        return 'PD'
    }
    if ($normalizedCode -match '^(cc0|cc-zero)') {
        return 'CC0'
    }
    if ($normalizedCode -match '^cc-by-sa-\d') {
        return 'CC BY-SA'
    }
    if ($normalizedCode -match '^cc-by-\d') {
        return 'CC BY'
    }
    return ''
}

function Test-HoiShareAlikeVersion {
    param([AllowEmptyString()][string]$LicenseCode)

    $versionMatch = [regex]::Match(([string]$LicenseCode).ToLowerInvariant(), '^cc-by-sa-(\d+(?:\.\d+)?)(?:-(.+))?$')
    if (-not $versionMatch.Success) {
        return [PSCustomObject]@{ Allowed = $false; Reason = "'$LicenseCode' is not a CC BY-SA licence code" }
    }
    $licenceVersion = [double]::Parse($versionMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    if ($licenceVersion -lt 2.0) {
        return [PSCustomObject]@{ Allowed = $false; Reason = "CC BY-SA $($versionMatch.Groups[1].Value) has no clause allowing an adaptation under a later version, so the portrait cannot be licensed CC BY-SA 4.0" }
    }
    $licencePort = $versionMatch.Groups[2].Value
    if ($licencePort -and $licencePort -notmatch '^([a-z]{2}|migrated(-with-disclaimers)?)$') {
        return [PSCustomObject]@{ Allowed = $false; Reason = "CC BY-SA $($versionMatch.Groups[1].Value) '$licencePort' is a port the tool does not know to allow an adaptation under CC BY-SA 4.0" }
    }
    return [PSCustomObject]@{ Allowed = $true; Reason = '' }
}

function Test-HoiNamedAuthor {
    param([AllowEmptyString()][string]$Author)

    return ([bool]([string]$Author).Trim() -and ([string]$Author).Trim() -notmatch '(?i)^(unknown|anonymous|unknown author|author unknown|unknown photographer|photographer unknown|tuntematon|inconnu|unbekannt|ok.nd|ukjent|ukendt|onbekend|nieznany|anonyme|anonym)$')
}

function Get-HoiImageAttribution {
    param([Parameter(Mandatory = $true)]$Record, [Parameter(Mandatory = $true)]$Policy)

    $author = [string](Get-HoiImageProperty -Object $Record -Name 'author' -Default '')
    $authorIsNamed = Test-HoiNamedAuthor -Author $author
    if (-not $authorIsNamed -and -not $Policy.InstitutionCredit) {
        return ''
    }
    $givenAttribution = [string](Get-HoiImageProperty -Object $Record -Name 'attribution' -Default '')
    if ((Test-HoiNamedAuthor -Author $givenAttribution) -and $givenAttribution.Trim().Length -le 200) {
        return $givenAttribution.Trim()
    }
    if ($authorIsNamed) {
        return $author.Trim()
    }
    $credit = [string](Get-HoiImageProperty -Object $Record -Name 'credit' -Default '')
    $creditIsInstitution = $credit.Trim().Length -le 200 -and $credit -notmatch '^\s*https?://\S+\s*$' -and $credit -notmatch '(?i)\b(own|self|my|myself|me|i|uploader|flickr|wikipedia|wikimedia|commons|internet|google)\b'
    if ((Test-HoiNamedAuthor -Author $credit) -and $creditIsInstitution) {
        return $credit.Trim()
    }
    $institution = [string](Get-HoiImageProperty -Object $Record -Name 'institution' -Default '')
    if (Test-HoiNamedAuthor -Author $institution) {
        return $institution.Trim()
    }
    return ''
}

function Get-HoiPictureYear {
    param([AllowEmptyCollection()][AllowEmptyString()][string[]]$Texts)

    $years = @(foreach ($text in @($Texts)) {
            foreach ($yearMatch in [regex]::Matches([string]$text, '(?<!\d)(1[89]\d\d|20\d\d)(?!\d)')) {
                [int]$yearMatch.Value
            }
        })
    if ($years.Count -eq 0) {
        return $null
    }
    return [int]($years | Measure-Object -Minimum).Minimum
}

function Test-HoiOwnWorkClaim {
    param(
        [AllowEmptyCollection()][string[]]$Templates,
        [AllowEmptyString()][string]$PublicDomainReason,
        [AllowEmptyString()][string]$AttributionText
    )

    if (@($Templates) -contains 'Template:PD-self' -or @($Templates) -contains 'Template:Own' -or @($Templates) -contains 'Template:Self') {
        return $true
    }
    if (@(([string]$PublicDomainReason) -split ',\s*') -contains 'PD-self') {
        return $true
    }
    return ([string]$AttributionText -match '(?i)\bown (work|photo|photograph|picture|scan)\b|\bmy own\b|\bself[- ]?made\b')
}

function Get-HoiCommonsDeletionTemplates {
    return @('Template:Delete', 'Template:Speedydelete', 'Template:Copyvio', 'Template:No license since', 'Template:No permission since', 'Template:No source since', 'Template:Dw no source since', 'Template:Npd', 'Template:Disputed', 'Template:Disputed copyright')
}

function Test-HoiCommonsDownloadUrl {
    param([AllowEmptyString()][string]$Url)

    return ([string]$Url -match (Get-HoiImageSourceRules -Source 'commons').DownloadPattern)
}

function Get-HoiCommonsQueryUrl {
    param([Parameter(Mandatory = $true)][string]$FileTitle)

    $queryParts = @(
        'action=query', 'format=json', 'formatversion=2',
        ('titles=' + [uri]::EscapeDataString($FileTitle)),
        'prop=imageinfo%7Ctemplates',
        'iiprop=url%7Csize%7Cmime%7Cextmetadata',
        'iiurlwidth=1600',
        'tlnamespace=10',
        'tllimit=max'
    )
    return 'https://commons.wikimedia.org/w/api.php?' + ($queryParts -join '&')
}

function New-HoiImageRecord {
    param([Parameter(Mandatory = $true)][string]$Source, [AllowEmptyString()][string]$SourceId = '')

    return [PSCustomObject][ordered]@{
        key                = ''
        source             = $Source
        sourceId           = $SourceId
        commonsTitle       = $(if ($Source -eq 'commons') { $SourceId } else { '' })
        title              = $(if ($Source -eq 'commons') { $SourceId -replace '^File:', '' } else { '' })
        pageUrl            = ''
        downloadUrl        = ''
        downloadSha256     = ''
        institution        = ''
        author             = ''
        credit             = ''
        attribution        = ''
        licenseShortName   = ''
        license            = ''
        licenseCategory    = ''
        licenseUrl         = ''
        rightsUri          = ''
        usageTerms         = ''
        restrictions       = ''
        dateOriginal       = ''
        pictureYear        = $null
        ownWorkClaim       = $false
        width              = 0
        height             = 0
        fetched            = ''
        publicDomainReason = ''
    }
}

function New-HoiImageCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        $Record,
        [AllowEmptyString()][string]$Missing = '',
        [AllowEmptyString()][string]$Refusal = '',
        [AllowEmptyCollection()][string[]]$Templates = @(),
        [AllowEmptyCollection()][string[]]$DeletionTags = @(),
        [AllowEmptyString()][string]$MimeType = '',
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$YearTexts = @(),
        [bool]$SizeKnown = $true
    )

    return [PSCustomObject]@{
        Source       = $Source
        Record       = $Record
        Missing      = $Missing
        Refusal      = $Refusal
        Templates    = @($Templates)
        DeletionTags = @($DeletionTags)
        MimeType     = $MimeType
        YearTexts    = @($YearTexts)
        SizeKnown    = $SizeKnown
    }
}

function Get-HoiCommonsMetadataText {
    param($Metadata, [Parameter(Mandatory = $true)][string]$Name)

    return ConvertFrom-HoiImageHtml ([string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $Metadata -Name $Name) -Name 'value' -Default ''))
}

function ConvertFrom-HoiCommonsResponse {
    param([Parameter(Mandatory = $true)]$Response)

    $page = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $Response -Name 'query') -Name 'pages')) | Select-Object -First 1
    if ($null -eq $page -or (Get-HoiImageProperty -Object $page -Name 'missing' -Default $false) -or $null -eq (Get-HoiImageProperty -Object $page -Name 'imageinfo')) {
        return New-HoiImageCandidate -Source 'commons' -Missing 'no such file on Wikimedia Commons'
    }
    $imageInfo = @($page.imageinfo)[0]
    $metadata = $imageInfo.extmetadata
    $record = New-HoiImageRecord -Source 'commons' -SourceId ([string]$page.title)
    $record.pageUrl = [string]$imageInfo.descriptionurl
    $record.downloadUrl = [string](Get-HoiImageProperty -Object $imageInfo -Name 'thumburl' -Default $imageInfo.url)
    $record.author = Get-HoiCommonsMetadataText -Metadata $metadata -Name 'Artist'
    $record.credit = Get-HoiCommonsMetadataText -Metadata $metadata -Name 'Credit'
    $record.attribution = Get-HoiCommonsMetadataText -Metadata $metadata -Name 'Attribution'
    $record.licenseShortName = Get-HoiCommonsMetadataText -Metadata $metadata -Name 'LicenseShortName'
    $record.license = ([string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $metadata -Name 'License') -Name 'value' -Default '')).ToLowerInvariant()
    $record.licenseCategory = Get-HoiLicenceCategory -LicenseCode $record.license
    $record.licenseUrl = [string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $metadata -Name 'LicenseUrl') -Name 'value' -Default '')
    $record.usageTerms = Get-HoiCommonsMetadataText -Metadata $metadata -Name 'UsageTerms'
    $record.restrictions = [string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $metadata -Name 'Restrictions') -Name 'value' -Default '')
    $record.dateOriginal = Get-HoiCommonsMetadataText -Metadata $metadata -Name 'DateTimeOriginal'
    $record.width = [int]$imageInfo.width
    $record.height = [int]$imageInfo.height
    $pageTemplates = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $page -Name 'templates') | ForEach-Object { [string]$_.title })
    $record.publicDomainReason = (@($pageTemplates | Where-Object { $_ -match '^Template:PD-[^/]+$' -and $_ -ne 'Template:PD-Layout' } | ForEach-Object { $_.Substring(9) }) -join ', ')
    $yearTexts = @($record.dateOriginal, (Get-HoiCommonsMetadataText -Metadata $metadata -Name 'ObjectName'), (Get-HoiCommonsMetadataText -Metadata $metadata -Name 'ImageDescription'), $record.commonsTitle)
    return New-HoiImageCandidate -Source 'commons' -Record $record -Templates $pageTemplates -DeletionTags @($pageTemplates | Where-Object { (Get-HoiCommonsDeletionTemplates) -contains $_ }) -MimeType ([string](Get-HoiImageProperty -Object $imageInfo -Name 'mime' -Default '')) -YearTexts $yearTexts
}

function Get-HoiFinnaRecordUrl {
    param([Parameter(Mandatory = $true)][string]$Id)

    $fieldParts = @('id', 'title', 'imageRights', 'images', 'imagesExtended', 'buildings', 'authors', 'nonPresenterAuthors', 'year', 'recordPage', 'summary') | ForEach-Object { 'field%5B%5D=' + $_ }
    return 'https://api.finna.fi/api/v1/record?id=' + [uri]::EscapeDataString($Id) + '&' + ($fieldParts -join '&')
}

function Get-HoiFinnaAuthor {
    param($FinnaRecord)

    foreach ($nonPresenterAuthor in @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $FinnaRecord -Name 'nonPresenterAuthors'))) {
        $authorName = [string](Get-HoiImageProperty -Object $nonPresenterAuthor -Name 'name' -Default '')
        if ($authorName) {
            return $authorName.Trim()
        }
    }
    $primaryAuthors = Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $FinnaRecord -Name 'authors') -Name 'primary'
    if ($null -ne $primaryAuthors) {
        foreach ($authorProperty in $primaryAuthors.PSObject.Properties) {
            return ($authorProperty.Name -replace ',\s*[^,]+$', '').Trim()
        }
    }
    return ''
}

function ConvertFrom-HoiFinnaResponse {
    param([Parameter(Mandatory = $true)]$Response)

    $finnaRecord = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $Response -Name 'records')) | Select-Object -First 1
    if ($null -eq $finnaRecord) {
        return New-HoiImageCandidate -Source 'finna' -Missing 'no such record on Finna'
    }
    $record = New-HoiImageRecord -Source 'finna' -SourceId ([string]$finnaRecord.id)
    $record.title = [string](Get-HoiImageProperty -Object $finnaRecord -Name 'title' -Default '')
    $record.pageUrl = 'https://www.finna.fi' + [string](Get-HoiImageProperty -Object $finnaRecord -Name 'recordPage' -Default ('/Record/' + [uri]::EscapeDataString([string]$finnaRecord.id)))
    $buildingNames = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $finnaRecord -Name 'buildings') | ForEach-Object { [string](Get-HoiImageProperty -Object $_ -Name 'translated' -Default '') } | Where-Object { $_ })
    $record.institution = if ($buildingNames.Count -gt 0) { $buildingNames[-1] } else { '' }
    $record.author = Get-HoiFinnaAuthor -FinnaRecord $finnaRecord
    $imageRights = Get-HoiImageProperty -Object $finnaRecord -Name 'imageRights'
    $rightsText = [string](Get-HoiImageProperty -Object $imageRights -Name 'copyright' -Default '')
    $record.rightsUri = $rightsText
    $record.usageTerms = (@(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $imageRights -Name 'description')) | ForEach-Object { [string]$_ }) -join ' '
    $licence = ConvertTo-HoiLicence -Text $rightsText
    $record.license = $licence.Code
    $record.licenseShortName = $(if ($licence.Code) { $licence.ShortName } else { $rightsText })
    $record.licenseUrl = $licence.Url
    $record.licenseCategory = Get-HoiLicenceCategory -LicenseCode $licence.Code
    if ($record.licenseCategory -eq 'PD') {
        $record.publicDomainReason = $(if ($licence.Code -eq 'noc-us') { 'NoC-US' } else { 'PDM' }) + ' (' + $(if ($record.institution) { $record.institution } else { 'Finna' }) + ')'
    }
    $record.dateOriginal = [string](Get-HoiImageProperty -Object $finnaRecord -Name 'year' -Default '')
    $firstImage = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $finnaRecord -Name 'imagesExtended')) | Select-Object -First 1
    $imagePath = [string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $firstImage -Name 'urls') -Name 'large' -Default '')
    if (-not $imagePath) {
        $imagePath = [string](@(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $finnaRecord -Name 'images')) | Select-Object -First 1)
    }
    $refusal = ''
    if (-not $imagePath) {
        $refusal = 'the Finna record has no image'
    } else {
        $record.downloadUrl = 'https://api.finna.fi' + $imagePath
    }
    $imageCopyright = [string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $firstImage -Name 'rights') -Name 'copyright' -Default '')
    if (-not $refusal -and $imageCopyright -and $imageCopyright -ne $rightsText) {
        $refusal = "the record's rights ($rightsText) and its image's rights ($imageCopyright) differ on Finna"
    }
    if (-not $refusal -and -not $rightsText) {
        $refusal = 'the Finna record states no rights for its image'
    }
    $summaryText = (@(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $finnaRecord -Name 'summary')) | ForEach-Object { [string]$_ }) -join ' '
    return New-HoiImageCandidate -Source 'finna' -Record $record -Refusal $refusal -YearTexts @($record.dateOriginal, $record.title, $summaryText) -SizeKnown $false
}

function Get-HoiEuropeanaRecordUrl {
    param([Parameter(Mandatory = $true)][string]$Id)

    $recordId = '/' + $Id.Trim('/')
    return 'https://api.europeana.eu/record/v2' + (@($recordId.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/') + '.json'
}

function Get-HoiEuropeanaHeaders {
    param([Parameter(Mandatory = $true)][string]$ApiKey)

    return @{ 'X-Api-Key' = $ApiKey }
}

function Get-HoiLanguageValue {
    param($LanguageMap)

    if ($null -eq $LanguageMap) {
        return ''
    }
    foreach ($languageName in @('en', 'def')) {
        $values = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $LanguageMap -Name $languageName) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -notmatch '^https?://' })
        if ($values.Count -gt 0) {
            return $values[0]
        }
    }
    foreach ($languageProperty in $LanguageMap.PSObject.Properties) {
        $values = @(ConvertTo-HoiImageArray $languageProperty.Value | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -notmatch '^https?://' })
        if ($values.Count -gt 0) {
            return $values[0]
        }
    }
    return ''
}

function ConvertFrom-HoiEuropeanaResponse {
    param([Parameter(Mandatory = $true)]$Response)

    $europeanaObject = Get-HoiImageProperty -Object $Response -Name 'object'
    if ($null -eq $europeanaObject -or -not [bool](Get-HoiImageProperty -Object $Response -Name 'success' -Default $true)) {
        return New-HoiImageCandidate -Source 'europeana' -Missing 'no such record on Europeana'
    }
    $recordId = [string](Get-HoiImageProperty -Object $europeanaObject -Name 'about' -Default '')
    $record = New-HoiImageRecord -Source 'europeana' -SourceId $recordId
    $record.pageUrl = 'https://www.europeana.eu/item' + $recordId
    $proxies = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $europeanaObject -Name 'proxies'))
    $record.title = [string](@($proxies | ForEach-Object { Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $_ -Name 'dcTitle') } | Where-Object { $_ }) | Select-Object -First 1)
    $record.author = [string](@($proxies | ForEach-Object { Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $_ -Name 'dcCreator') } | Where-Object { $_ }) | Select-Object -First 1)
    $dateTexts = @($proxies | ForEach-Object { Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $_ -Name 'dctermsCreated'); Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $_ -Name 'dcDate') } | Where-Object { $_ })
    $record.dateOriginal = [string](@($dateTexts) | Select-Object -First 1)
    $aggregation = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $europeanaObject -Name 'aggregations')) | Select-Object -First 1
    $dataProviderId = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $aggregation -Name 'edmDataProvider') -Name 'def')) | Select-Object -First 1
    $dataProvider = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $europeanaObject -Name 'organizations') | Where-Object { [string]$_.about -eq [string]$dataProviderId }) | Select-Object -First 1
    $record.institution = if ($null -ne $dataProvider) { Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $dataProvider -Name 'prefLabel') } else { Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $aggregation -Name 'edmDataProvider') }
    $rightsUri = [string](@(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $aggregation -Name 'edmRights') -Name 'def')) | Select-Object -First 1)
    $record.rightsUri = $rightsUri
    $licence = ConvertTo-HoiLicence -Text $rightsUri
    $record.license = $licence.Code
    $record.licenseShortName = $(if ($licence.Code) { $licence.ShortName } else { $rightsUri })
    $record.licenseUrl = $licence.Url
    $record.licenseCategory = Get-HoiLicenceCategory -LicenseCode $licence.Code
    if ($record.licenseCategory -eq 'PD') {
        $record.publicDomainReason = $(if ($licence.Code -eq 'noc-us') { 'NoC-US' } else { 'PDM' }) + ' (' + $(if ($record.institution) { $record.institution } else { 'Europeana' }) + ')'
    }
    $record.downloadUrl = [string](Get-HoiImageProperty -Object $aggregation -Name 'edmIsShownBy' -Default '')
    $refusal = ''
    $mimeType = ''
    $sizeKnown = $false
    if (-not $record.downloadUrl) {
        $refusal = 'the Europeana record links no image (edmIsShownBy)'
    } else {
        $webResource = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $aggregation -Name 'webResources') | Where-Object { [string]$_.about -eq $record.downloadUrl }) | Select-Object -First 1
        $mimeType = [string](Get-HoiImageProperty -Object $webResource -Name 'ebucoreHasMimeType' -Default '')
        $record.width = [int](Get-HoiImageProperty -Object $webResource -Name 'ebucoreWidth' -Default 0)
        $record.height = [int](Get-HoiImageProperty -Object $webResource -Name 'ebucoreHeight' -Default 0)
        $sizeKnown = ($record.width -gt 0 -and $record.height -gt 0)
        $imageRightsUri = [string](@(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $webResource -Name 'webResourceEdmRights') -Name 'def')) | Select-Object -First 1)
        if ($imageRightsUri -and (ConvertTo-HoiLicence -Text $imageRightsUri).Code -ne $licence.Code) {
            $refusal = "the record's rights ($rightsUri) and its image's rights ($imageRightsUri) differ on Europeana"
        }
    }
    $descriptionTexts = @($proxies | ForEach-Object { Get-HoiLanguageValue -LanguageMap (Get-HoiImageProperty -Object $_ -Name 'dcDescription') } | Where-Object { $_ })
    return New-HoiImageCandidate -Source 'europeana' -Record $record -Refusal $refusal -MimeType $mimeType -YearTexts (@($dateTexts) + @($record.title) + $descriptionTexts) -SizeKnown $sizeKnown
}

function Get-HoiImageCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Policy,
        [AllowEmptyString()][string]$ManagerRoot = ''
    )

    switch ($Source) {
        'commons' {
            $fileTitle = if ($Id -like 'File:*') { $Id } else { 'File:' + $Id }
            return ConvertFrom-HoiCommonsResponse -Response (Invoke-HoiImageRequest -Uri (Get-HoiCommonsQueryUrl -FileTitle $fileTitle) -Policy $Policy)
        }
        'finna' {
            return ConvertFrom-HoiFinnaResponse -Response (Invoke-HoiImageRequest -Uri (Get-HoiFinnaRecordUrl -Id $Id) -Policy $Policy)
        }
        'europeana' {
            $apiKey = Get-HoiImageSourceKey -Source 'europeana' -ManagerRoot $ManagerRoot
            return ConvertFrom-HoiEuropeanaResponse -Response (Invoke-HoiImageRequest -Uri (Get-HoiEuropeanaRecordUrl -Id $Id) -Policy $Policy -Headers (Get-HoiEuropeanaHeaders -ApiKey $apiKey))
        }
    }
    throw "the source '$Source' has no API to read: the sources with one are commons, finna and europeana"
}

function ConvertTo-HoiComparableText {
    param([AllowEmptyString()][string]$Text)

    $comparableText = [string]$Text
    foreach ($apostrophe in @([char]0x2018, [char]0x2019, [char]0x201A, [char]0x2032, [char]0x00B4)) {
        $comparableText = $comparableText.Replace([string]$apostrophe, "'")
    }
    foreach ($quotationMark in @([char]0x201C, [char]0x201D, [char]0x201E, [char]0x00AB, [char]0x00BB, [char]0x2033)) {
        $comparableText = $comparableText.Replace([string]$quotationMark, '"')
    }
    foreach ($dash in @([char]0x2010, [char]0x2011, [char]0x2012, [char]0x2013, [char]0x2014, [char]0x2212)) {
        $comparableText = $comparableText.Replace([string]$dash, '-')
    }
    $comparableText = $comparableText.Replace([string][char]0x2026, '...')
    foreach ($space in @([char]0x00A0, [char]0x2007, [char]0x202F, [char]0x2009, [char]0x200B)) {
        $comparableText = $comparableText.Replace([string]$space, ' ')
    }
    return ($comparableText -replace '\s+', ' ').Trim()
}

function Get-HoiEvidenceSha256 {
    param([Parameter(Mandatory = $true)]$Record)

    $evidence = Get-HoiImageProperty -Object $Record -Name 'evidence'
    $evidenceParts = @(
        [string](Get-HoiImageProperty -Object $evidence -Name 'recordTextSha256' -Default ''),
        [string](Get-HoiImageProperty -Object $evidence -Name 'rightsTextSha256' -Default ''),
        [string](Get-HoiImageProperty -Object $evidence -Name 'rightsQuote' -Default ''),
        [string](Get-HoiImageProperty -Object $Record -Name 'downloadSha256' -Default ''),
        [string](Get-HoiImageProperty -Object $Record -Name 'license' -Default ''),
        [string](Get-HoiImageProperty -Object $Record -Name 'publicDomainReason' -Default '')
    )
    return Get-HoiTextSha256 -Text ($evidenceParts -join '|')
}

function Get-HoiEvidenceTextPaths {
    param([Parameter(Mandatory = $true)][string]$EvidenceDir, [Parameter(Mandatory = $true)][string]$Key)

    return [PSCustomObject]@{ Record = (Join-Path $EvidenceDir "$Key.record.txt"); Rights = (Join-Path $EvidenceDir "$Key.rights.txt") }
}

function Get-HoiManualSpecProblems {
    param([Parameter(Mandatory = $true)]$Spec)

    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($urlField in @('recordUrl', 'imageUrl', 'rightsUrl')) {
        if ([string](Get-HoiImageProperty -Object $Spec -Name $urlField -Default '') -notmatch '^https://\S+$') {
            $problems.Add("$urlField must be an https address")
        }
    }
    $rightsQuote = ConvertTo-HoiComparableText -Text ([string](Get-HoiImageProperty -Object $Spec -Name 'rightsQuote' -Default ''))
    if ($rightsQuote.Length -lt 40) {
        $problems.Add('rightsQuote must be the rights sentence copied word for word from the page, at least 40 characters')
    }
    if (-not (ConvertTo-HoiLicence -Text ([string](Get-HoiImageProperty -Object $Spec -Name 'license' -Default ''))).Code) {
        $problems.Add('license must be a licence code such as pd, cc0, cc-by-4.0 or cc-by-sa-4.0')
    }
    return $problems.ToArray()
}

function Get-HoiManualCandidate {
    param([Parameter(Mandatory = $true)]$Spec, [Parameter(Mandatory = $true)]$Policy)

    $specProblems = @(Get-HoiManualSpecProblems -Spec $Spec)
    if ($specProblems.Count -gt 0) {
        return New-HoiImageCandidate -Source 'manual' -Missing ('the evidence file is incomplete: ' + ($specProblems -join '; '))
    }
    $recordUrl = [string]$Spec.recordUrl
    $rightsUrl = [string]$Spec.rightsUrl
    $record = New-HoiImageRecord -Source 'manual' -SourceId $recordUrl
    $record.title = [string](Get-HoiImageProperty -Object $Spec -Name 'title' -Default '')
    $record.pageUrl = $recordUrl
    $record.downloadUrl = [string]$Spec.imageUrl
    $record.institution = [string](Get-HoiImageProperty -Object $Spec -Name 'institution' -Default '')
    $record.author = [string](Get-HoiImageProperty -Object $Spec -Name 'author' -Default '')
    $record.credit = [string](Get-HoiImageProperty -Object $Spec -Name 'credit' -Default '')
    $record.dateOriginal = [string](Get-HoiImageProperty -Object $Spec -Name 'dateOriginal' -Default '')
    $licence = ConvertTo-HoiLicence -Text ([string]$Spec.license)
    $record.license = $licence.Code
    $record.licenseShortName = $licence.ShortName
    $record.licenseUrl = $licence.Url
    $record.licenseCategory = Get-HoiLicenceCategory -LicenseCode $licence.Code
    $record.rightsUri = $rightsUrl
    if ($record.licenseCategory -eq 'PD') {
        $record.publicDomainReason = [string](Get-HoiImageProperty -Object $Spec -Name 'publicDomainReason' -Default '')
    }
    $recordText = ConvertTo-HoiComparableText -Text (ConvertFrom-HoiImageHtml -Html ([string](Invoke-HoiImageRequest -Uri $recordUrl -Policy $Policy)))
    $rightsText = if ($rightsUrl -eq $recordUrl) { $recordText } else { ConvertTo-HoiComparableText -Text (ConvertFrom-HoiImageHtml -Html ([string](Invoke-HoiImageRequest -Uri $rightsUrl -Policy $Policy))) }
    $rightsQuote = ConvertTo-HoiComparableText -Text ([string]$Spec.rightsQuote)
    $quoteFoundIn = ''
    if ($rightsText.IndexOf($rightsQuote, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $quoteFoundIn = 'rights'
    } elseif ($recordText.IndexOf($rightsQuote, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $quoteFoundIn = 'record'
    }
    $record | Add-Member -NotePropertyName 'evidence' -NotePropertyValue ([PSCustomObject][ordered]@{
            recordUrl        = $recordUrl
            imageUrl         = [string]$Spec.imageUrl
            rightsUrl        = $rightsUrl
            rightsQuote      = $rightsQuote
            quoteFoundIn     = $quoteFoundIn
            recordTextSha256 = Get-HoiTextSha256 -Text $recordText
            rightsTextSha256 = Get-HoiTextSha256 -Text $rightsText
            captured         = Get-HoiImageToday
        })
    $record | Add-Member -NotePropertyName 'ownerConfirmed' -NotePropertyValue ''
    $refusal = if (-not $quoteFoundIn) { 'the quoted rights sentence is on neither the rights page nor the record page: copy it word for word from a page the tool can read' } else { '' }
    $candidate = New-HoiImageCandidate -Source 'manual' -Record $record -Refusal $refusal -YearTexts @($record.dateOriginal, $record.title) -SizeKnown $false
    $candidate | Add-Member -NotePropertyName 'EvidenceTexts' -NotePropertyValue ([PSCustomObject]@{ Record = $recordText; Rights = $rightsText })
    return $candidate
}

function Save-HoiManualEvidence {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)][string]$EvidenceDir,
        [Parameter(Mandatory = $true)][string]$Key
    )

    if (-not (Test-Path -LiteralPath $EvidenceDir)) {
        New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    }
    $evidencePaths = Get-HoiEvidenceTextPaths -EvidenceDir $EvidenceDir -Key $Key
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($evidencePaths.Record, $Candidate.EvidenceTexts.Record, $utf8WithoutBom)
    [System.IO.File]::WriteAllText($evidencePaths.Rights, $Candidate.EvidenceTexts.Rights, $utf8WithoutBom)
}

function Test-HoiManualEvidence {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][string]$EvidenceDir
    )

    $problems = [System.Collections.Generic.List[string]]::new()
    $evidence = Get-HoiImageProperty -Object $Record -Name 'evidence'
    if ($null -eq $evidence) {
        $problems.Add('a manual row without its evidence: fetch it again with -Evidence')
        return $problems.ToArray()
    }
    $evidencePaths = Get-HoiEvidenceTextPaths -EvidenceDir $EvidenceDir -Key ([string]$Record.key)
    foreach ($evidencePart in @(@{ Path = $evidencePaths.Record; Hash = 'recordTextSha256'; Name = 'record' }, @{ Path = $evidencePaths.Rights; Hash = 'rightsTextSha256'; Name = 'rights' })) {
        if (-not (Test-Path -LiteralPath $evidencePart.Path)) {
            $problems.Add("the $($evidencePart.Name) page capture $([System.IO.Path]::GetFileName($evidencePart.Path)) is missing: fetch it again with -Evidence")
            continue
        }
        $capturedText = [System.IO.File]::ReadAllText($evidencePart.Path, [System.Text.Encoding]::UTF8)
        if ((Get-HoiTextSha256 -Text $capturedText) -ne [string](Get-HoiImageProperty -Object $evidence -Name $evidencePart.Hash -Default '')) {
            $problems.Add("the $($evidencePart.Name) page capture $([System.IO.Path]::GetFileName($evidencePart.Path)) differs from the one recorded at fetch time")
        } elseif ($evidencePart.Name -eq [string]$evidence.quoteFoundIn -and $capturedText.IndexOf([string]$evidence.rightsQuote, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $problems.Add("the $($evidencePart.Name) page capture does not hold the quoted rights sentence")
        }
    }
    if ([string]$Record.pageUrl -ne [string]$evidence.recordUrl -or [string]$Record.downloadUrl -ne [string]$evidence.imageUrl) {
        $problems.Add('the page or download address differs from the evidence: fetch it again with -Evidence')
    }
    return $problems.ToArray()
}

function Test-HoiOwnerConfirmation {
    param([Parameter(Mandatory = $true)]$Record)

    $ownerConfirmed = Get-HoiImageProperty -Object $Record -Name 'ownerConfirmed'
    if ($null -eq $ownerConfirmed -or $ownerConfirmed -is [string]) {
        return $false
    }
    return ([string](Get-HoiImageProperty -Object $ownerConfirmed -Name 'evidenceSha256' -Default '') -eq (Get-HoiEvidenceSha256 -Record $Record))
}

function Confirm-HoiManualRecord {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][string]$EvidenceDir
    )

    if ([string](Get-HoiImageProperty -Object $Record -Name 'source' -Default 'commons') -ne 'manual') {
        throw "photo '$($Record.key)' comes from $([string](Get-HoiImageProperty -Object $Record -Name 'source' -Default 'commons')), whose licence the tool read itself: only a manual row needs the owner's confirmation"
    }
    $evidenceProblems = @(Test-HoiManualEvidence -Record $Record -EvidenceDir $EvidenceDir)
    if ($evidenceProblems.Count -gt 0) {
        throw ("photo '$($Record.key)' cannot be confirmed: " + ($evidenceProblems -join '; '))
    }
    $Record.ownerConfirmed = [PSCustomObject][ordered]@{ date = Get-HoiImageToday; evidenceSha256 = Get-HoiEvidenceSha256 -Record $Record }
    return $Record
}

function Test-HoiManualQuoteOnline {
    param([Parameter(Mandatory = $true)]$Record, [Parameter(Mandatory = $true)]$Policy)

    $evidence = Get-HoiImageProperty -Object $Record -Name 'evidence'
    $pageUrl = if ([string]$evidence.quoteFoundIn -eq 'record') { [string]$evidence.recordUrl } else { [string]$evidence.rightsUrl }
    $pageText = ConvertTo-HoiComparableText -Text (ConvertFrom-HoiImageHtml -Html ([string](Invoke-HoiImageRequest -Uri $pageUrl -Policy $Policy)))
    return ($pageText.IndexOf([string]$evidence.rightsQuote, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Get-HoiCommonsSearchUrl {
    param([Parameter(Mandatory = $true)][string]$Query, [int]$Limit = 10)

    $queryParts = @(
        'action=query', 'format=json', 'formatversion=2',
        'generator=search', 'gsrnamespace=6',
        ('gsrsearch=' + [uri]::EscapeDataString($Query + ' filetype:bitmap')),
        ('gsrlimit=' + $Limit),
        'prop=imageinfo%7Ctemplates',
        'iiprop=url%7Csize%7Cmime%7Cextmetadata',
        'iiurlwidth=1600',
        'tlnamespace=10',
        'tllimit=max'
    )
    return 'https://commons.wikimedia.org/w/api.php?' + ($queryParts -join '&')
}

function Get-HoiFinnaSearchUrl {
    param([Parameter(Mandatory = $true)][string]$Query, [int]$Limit = 10)

    $fieldParts = @('id', 'title', 'imageRights', 'images', 'imagesExtended', 'buildings', 'authors', 'nonPresenterAuthors', 'year', 'recordPage', 'summary') | ForEach-Object { 'field%5B%5D=' + $_ }
    $filterParts = @('format:"0/Image/"', 'online_boolean:1') | ForEach-Object { 'filter%5B%5D=' + [uri]::EscapeDataString($_) }
    return 'https://api.finna.fi/api/v1/search?lookfor=' + [uri]::EscapeDataString($Query) + '&limit=' + $Limit + '&' + (@($filterParts) + @($fieldParts) -join '&')
}

function Get-HoiEuropeanaSearchUrl {
    param([Parameter(Mandatory = $true)][string]$Query, [int]$Limit = 10)

    return 'https://api.europeana.eu/record/v2/search.json?query=' + [uri]::EscapeDataString($Query) + '&qf=TYPE%3AIMAGE&reusability=open&profile=minimal&rows=' + $Limit
}

function New-HoiSearchRow {
    param([Parameter(Mandatory = $true)]$Candidate, [Parameter(Mandatory = $true)]$Policy)

    $verdict = Get-HoiImageVerdict -Candidate $Candidate -Policy $Policy
    $record = $verdict.Record
    $verdictText = if (-not $verdict.Accepted) { 'REFUSED: ' + $verdict.Reason } elseif ($Candidate.SizeKnown) { 'ACCEPTABLE' } else { 'ACCEPTABLE, size checked at download' }
    return [PSCustomObject][ordered]@{
        Source      = $Candidate.Source
        Id          = $(if ($null -ne $record) { [string]$record.sourceId } else { '' })
        Title       = $(if ($null -ne $record) { [string]$record.title } else { '' })
        Institution = $(if ($null -ne $record) { [string]$record.institution } else { '' })
        Year        = $(if ($null -ne $record -and $null -ne $record.pictureYear) { [string]$record.pictureYear } else { '' })
        Size        = $(if ($null -ne $record -and $Candidate.SizeKnown) { '{0}x{1}' -f $record.width, $record.height } else { '' })
        Licence     = $(if ($null -ne $record) { [string]$record.licenseShortName } else { '' })
        Accepted    = $verdict.Accepted
        Verdict     = $verdictText
        Page        = $(if ($null -ne $record) { [string]$record.pageUrl } else { '' })
    }
}

function Find-HoiImageCandidates {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [Parameter(Mandatory = $true)][string[]]$Sources,
        [Parameter(Mandatory = $true)]$Policy,
        [int]$Limit = 10,
        [AllowEmptyString()][string]$ManagerRoot = ''
    )

    $searchRows = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($source in $Sources) {
        switch ($source) {
            'commons' {
                $searchResponse = Invoke-HoiImageRequest -Uri (Get-HoiCommonsSearchUrl -Query $Query -Limit $Limit) -Policy $Policy
                $foundPages = @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $searchResponse -Name 'query') -Name 'pages') | Sort-Object { [int](Get-HoiImageProperty -Object $_ -Name 'index' -Default 0) })
                foreach ($foundPage in $foundPages) {
                    $searchRows.Add((New-HoiSearchRow -Candidate (ConvertFrom-HoiCommonsResponse -Response ([PSCustomObject]@{ query = [PSCustomObject]@{ pages = @($foundPage) } })) -Policy $Policy))
                }
            }
            'finna' {
                $searchResponse = Invoke-HoiImageRequest -Uri (Get-HoiFinnaSearchUrl -Query $Query -Limit $Limit) -Policy $Policy
                foreach ($finnaRecord in @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $searchResponse -Name 'records'))) {
                    $searchRows.Add((New-HoiSearchRow -Candidate (ConvertFrom-HoiFinnaResponse -Response ([PSCustomObject]@{ records = @($finnaRecord) })) -Policy $Policy))
                }
            }
            'europeana' {
                $apiHeaders = Get-HoiEuropeanaHeaders -ApiKey (Get-HoiImageSourceKey -Source 'europeana' -ManagerRoot $ManagerRoot)
                $searchResponse = Invoke-HoiImageRequest -Uri (Get-HoiEuropeanaSearchUrl -Query $Query -Limit $Limit) -Policy $Policy -Headers $apiHeaders
                foreach ($foundItem in @(ConvertTo-HoiImageArray (Get-HoiImageProperty -Object $searchResponse -Name 'items'))) {
                    $recordResponse = Invoke-HoiImageRequest -Uri (Get-HoiEuropeanaRecordUrl -Id ([string]$foundItem.id)) -Policy $Policy -Headers $apiHeaders
                    $searchRows.Add((New-HoiSearchRow -Candidate (ConvertFrom-HoiEuropeanaResponse -Response $recordResponse) -Policy $Policy))
                }
            }
            default {
                throw "the source '$source' cannot be searched: the searchable sources are commons, finna and europeana"
            }
        }
    }
    return $searchRows.ToArray()
}

function Measure-HoiImageFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    Add-Type -AssemblyName System.Drawing
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    try {
        $image = [System.Drawing.Image]::FromFile($fullPath)
    } catch {
        return $null
    }
    try {
        $formatMimeTypes = @{
            ([System.Drawing.Imaging.ImageFormat]::Jpeg.Guid) = 'image/jpeg'
            ([System.Drawing.Imaging.ImageFormat]::Png.Guid)  = 'image/png'
            ([System.Drawing.Imaging.ImageFormat]::Tiff.Guid) = 'image/tiff'
            ([System.Drawing.Imaging.ImageFormat]::Gif.Guid)  = 'image/gif'
        }
        $mimeType = $formatMimeTypes[$image.RawFormat.Guid]
        if (-not $mimeType) {
            return $null
        }
        return [PSCustomObject]@{ Width = [int]$image.Width; Height = [int]$image.Height; MimeType = $mimeType }
    } finally {
        $image.Dispose()
    }
}

function New-HoiImageFetchResult {
    param([bool]$Accepted, [string]$Reason, $Record, [string]$CachePath = '')

    return [PSCustomObject]@{ Accepted = $Accepted; Reason = $Reason; Record = $Record; CachePath = $CachePath }
}

function Invoke-HoiImageFetch {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)]$Policy,
        [Parameter(Mandatory = $true)][string]$CacheDir,
        [Parameter(Mandatory = $true)][string]$Key,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$KnownYears = @(),
        [switch]$DryRun
    )

    $Candidate.YearTexts = @($Candidate.YearTexts) + @($KnownYears | Where-Object { $_ })
    $verdict = Get-HoiImageVerdict -Candidate $Candidate -Policy $Policy
    if (-not $verdict.Accepted) {
        return New-HoiImageFetchResult -Accepted $false -Reason $verdict.Reason -Record $verdict.Record
    }
    $record = $verdict.Record
    $record.key = $Key
    $record.fetched = Get-HoiImageToday
    if ($DryRun -and $Candidate.SizeKnown) {
        return New-HoiImageFetchResult -Accepted $true -Reason $verdict.Reason -Record $record
    }
    if (-not (Test-Path -LiteralPath $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
    }
    $downloadPath = Join-Path $CacheDir ($Key + '.download')
    try {
        Invoke-HoiImageRequest -Uri ([string]$record.downloadUrl) -Policy $Policy -OutFile $downloadPath
        if (-not $Candidate.SizeKnown) {
            $measuredImage = Measure-HoiImageFile -Path $downloadPath
            if ($null -eq $measuredImage) {
                return New-HoiImageFetchResult -Accepted $false -Reason 'the download is not a JPEG, PNG, TIFF or GIF picture the tool can measure' -Record $record
            }
            $record.width = $measuredImage.Width
            $record.height = $measuredImage.Height
            $Candidate.MimeType = $measuredImage.MimeType
            $Candidate.SizeKnown = $true
            $verdict = Get-HoiImageVerdict -Candidate $Candidate -Policy $Policy
            if (-not $verdict.Accepted) {
                return New-HoiImageFetchResult -Accepted $false -Reason $verdict.Reason -Record $record
            }
        }
        if ($DryRun) {
            return New-HoiImageFetchResult -Accepted $true -Reason $verdict.Reason -Record $record
        }
        $cachePath = Get-HoiImageCachePath -CacheDir $CacheDir -Record $record
        Move-Item -LiteralPath $downloadPath -Destination $cachePath -Force
        $record.downloadSha256 = Get-HoiImageSha256 -Path $cachePath
        return New-HoiImageFetchResult -Accepted $true -Reason $verdict.Reason -Record $record -CachePath $cachePath
    } finally {
        if (Test-Path -LiteralPath $downloadPath) {
            Remove-Item -LiteralPath $downloadPath -Force
        }
    }
}

function Get-HoiImageSizeProblem {
    param([Parameter(Mandatory = $true)]$Policy, [int]$Width, [int]$Height)

    if ($Policy.MinShorterSide -gt 0 -and [Math]::Min($Width, $Height) -lt $Policy.MinShorterSide) {
        return "${Width}x${Height} is under $($Policy.MinShorterSide) px on its shorter side, too small for $($Policy.MinSizeText)"
    }
    if ($Policy.MinWidth -gt 0 -and ($Width -lt $Policy.MinWidth -or $Height -lt $Policy.MinHeight)) {
        return "${Width}x${Height} is smaller than $($Policy.MinSizeText)"
    }
    return ''
}

function New-HoiImageVerdict {
    param([bool]$Accepted, [string]$Reason, $Record)

    return [PSCustomObject]@{ Accepted = $Accepted; Reason = $Reason; Record = $Record }
}

function Get-HoiImageVerdict {
    param([Parameter(Mandatory = $true)]$Candidate, [Parameter(Mandatory = $true)]$Policy)

    $record = $Candidate.Record
    $rules = Get-HoiImageSourceRules -Source $Candidate.Source
    if ($Candidate.Missing) {
        return New-HoiImageVerdict -Accepted $false -Reason $Candidate.Missing -Record $record
    }
    if (@($Policy.AcceptedSources) -notcontains $Candidate.Source) {
        return New-HoiImageVerdict -Accepted $false -Reason "the source $($rules.Label) is outside the policy: $((@($Policy.AcceptedSources)) -join ', ') only" -Record $record
    }
    if ($Candidate.Refusal) {
        return New-HoiImageVerdict -Accepted $false -Reason $Candidate.Refusal -Record $record
    }
    if (@($Candidate.DeletionTags).Count -gt 0) {
        return New-HoiImageVerdict -Accepted $false -Reason ("tagged on $($rules.ShortLabel): " + (@($Candidate.DeletionTags) -join ', ')) -Record $record
    }
    $category = [string]$record.licenseCategory
    if ($category -eq 'PD' -and -not [string]$record.publicDomainReason) {
        return New-HoiImageVerdict -Accepted $false -Reason "public domain without $($rules.MissingReasonText)" -Record $record
    }
    if (-not $category -or @($Policy.AcceptedCategories) -notcontains $category) {
        return New-HoiImageVerdict -Accepted $false -Reason "licence '$($record.licenseShortName)' ($($record.license)) is outside the policy: $(Get-HoiImagePolicyCategoryText -Policy $Policy) only" -Record $record
    }
    if ($category -eq 'CC BY-SA') {
        $shareAlike = Test-HoiShareAlikeVersion -LicenseCode ([string]$record.license)
        if (-not $shareAlike.Allowed) {
            return New-HoiImageVerdict -Accepted $false -Reason $shareAlike.Reason -Record $record
        }
    }
    $record.ownWorkClaim = [bool](Test-HoiOwnWorkClaim -Templates $Candidate.Templates -PublicDomainReason ([string]$record.publicDomainReason) -AttributionText ([string]$record.credit))
    $record.pictureYear = Get-HoiPictureYear -Texts $Candidate.YearTexts
    if ($record.ownWorkClaim -and $null -ne $record.pictureYear -and $record.pictureYear -lt $Policy.OwnWorkCutoffYear) {
        return New-HoiImageVerdict -Accepted $false -Reason "own work on a picture dated $($record.pictureYear): the uploader cannot be its author, so the licence cannot be trusted; find the picture's original source and its licence" -Record $record
    }
    $record.attribution = Get-HoiImageAttribution -Record $record -Policy $Policy
    if (@('CC BY', 'CC BY-SA') -contains $category -and -not $record.attribution) {
        $creditWords = if ($Policy.InstitutionCredit) { 'a named author or an institution credit' } else { 'a named author' }
        return New-HoiImageVerdict -Accepted $false -Reason "$category without $creditWords on $($rules.ShortLabel): the credit cannot be written" -Record $record
    }
    if ($Candidate.MimeType -and $Candidate.MimeType -notmatch '^image/(jpeg|png|tiff|gif|webp)$') {
        return New-HoiImageVerdict -Accepted $false -Reason "file type '$($Candidate.MimeType)' is not a picture" -Record $record
    }
    if ([string]$record.downloadUrl -notmatch $rules.DownloadPattern) {
        return New-HoiImageVerdict -Accepted $false -Reason "download URL '$($record.downloadUrl)' is not on $($rules.DownloadText)" -Record $record
    }
    if ($Candidate.SizeKnown) {
        $sizeProblem = Get-HoiImageSizeProblem -Policy $Policy -Width ([int]$record.width) -Height ([int]$record.height)
        if ($sizeProblem) {
            return New-HoiImageVerdict -Accepted $false -Reason $sizeProblem -Record $record
        }
    }
    return New-HoiImageVerdict -Accepted $true -Reason "$category ($($record.licenseShortName))" -Record $record
}

function Get-HoiImageWebHeaders {
    param([Parameter(Mandatory = $true)]$Policy)

    $powerShellVersion = '{0}.{1}' -f $PSVersionTable.PSVersion.Major, $PSVersionTable.PSVersion.Minor
    return @{ 'User-Agent' = "$($Policy.BotName)/1.0 ($($Policy.ContactUrl); Hearts of Iron IV mod build tool, one request at a time) PowerShell/$powerShellVersion" }
}

function Get-HoiWebErrorText {
    param([Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    $text = if ($null -ne $ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { $ErrorRecord.ErrorDetails.Message } else { $ErrorRecord.Exception.Message }
    $text = ([regex]::Replace([string]$text, '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
    if ($text.Length -gt 300) {
        $text = $text.Substring(0, 300) + '...'
    }
    return $text
}

function Get-HoiRetryDelaySeconds {
    param($Response, [Parameter(Mandatory = $true)][int]$Attempt)

    $backoffSeconds = 5 * [Math]::Pow(2, $Attempt - 1)
    $retryAfterSeconds = 0
    $headers = Get-HoiImageProperty -Object $Response -Name 'Headers'
    if ($null -ne $headers -and -not [int]::TryParse([string]$headers['Retry-After'], [ref]$retryAfterSeconds)) {
        $retryAfterSeconds = 0
    }
    return [int][Math]::Min(120, [Math]::Max($retryAfterSeconds, $backoffSeconds))
}

function Get-HoiRequestServerName {
    param([Parameter(Mandatory = $true)][string]$Uri)

    $hostName = ''
    try {
        $hostName = ([uri]$Uri).Host
    } catch {
        $hostName = ''
    }
    if ($hostName -match '(^|\.)(wikimedia|wikipedia)\.org$') {
        return 'Wikimedia'
    }
    if ($hostName) {
        return $hostName
    }
    return 'The server'
}

function Invoke-HoiImageRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)]$Policy,
        [string]$OutFile,
        [hashtable]$Headers = @{},
        [int]$MaxAttempts = 5
    )

    $requestHeaders = Get-HoiImageWebHeaders -Policy $Policy
    foreach ($headerName in $Headers.Keys) {
        $requestHeaders[$headerName] = $Headers[$headerName]
    }
    for ($attempt = 1; ; $attempt++) {
        try {
            if ($OutFile) {
                Invoke-WebRequest -Uri $Uri -Headers $requestHeaders -OutFile $OutFile -UseBasicParsing
                return
            }
            return (Invoke-RestMethod -Uri $Uri -Headers $requestHeaders -UseBasicParsing)
        } catch {
            $response = Get-HoiImageProperty -Object $_.Exception -Name 'Response'
            $statusCode = if ($null -ne $response) { [int]$response.StatusCode } else { 0 }
            if ($statusCode -notin @(429, 503)) {
                throw
            }
            Write-Host "  $(Get-HoiRequestServerName -Uri $Uri) answered $statusCode`: $(Get-HoiWebErrorText -ErrorRecord $_)" -ForegroundColor Yellow
            if ($attempt -ge $MaxAttempts) {
                Write-Host "  giving up after $MaxAttempts attempts" -ForegroundColor Yellow
                throw
            }
            $delaySeconds = Get-HoiRetryDelaySeconds -Response $response -Attempt $attempt
            Write-Host "  trying again in $delaySeconds s (attempt $($attempt + 1) of $MaxAttempts)" -ForegroundColor Yellow
            Start-Sleep -Seconds $delaySeconds
        }
    }
}

function Get-HoiImageCachePath {
    param([Parameter(Mandatory = $true)][string]$CacheDir, [Parameter(Mandatory = $true)]$Record)

    $extension = ''
    try {
        $extension = [System.IO.Path]::GetExtension(([uri][string]$Record.downloadUrl).AbsolutePath)
    } catch {
        $extension = ''
    }
    if ($extension -notmatch '^\.(jpe?g|png|tiff?|gif|webp)$') {
        $extension = '.jpg'
    }
    return (Join-Path $CacheDir ([string]$Record.key + $extension.ToLowerInvariant()))
}

function Get-HoiImageSourceKeyVariable {
    param([Parameter(Mandatory = $true)][string]$Source)

    $keyVariables = @{ europeana = 'HOI_EUROPEANA_WSKEY'; smithsonian = 'HOI_SMITHSONIAN_API_KEY'; nara = 'HOI_NARA_API_KEY' }
    if (-not $keyVariables.ContainsKey($Source)) {
        throw "the image source '$Source' needs no key"
    }
    return $keyVariables[$Source]
}

function Get-HoiImageSourceKey {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [AllowEmptyString()][string]$ManagerRoot = ''
    )

    $variableName = Get-HoiImageSourceKeyVariable -Source $Source
    $environmentKey = [Environment]::GetEnvironmentVariable($variableName)
    if ($environmentKey) {
        return $environmentKey.Trim()
    }
    $keyFilePath = ''
    if ($ManagerRoot) {
        $keyFilePath = Join-Path $ManagerRoot 'Config\image-sources.local.json'
        if (Test-Path -LiteralPath $keyFilePath) {
            $keyFile = [System.IO.File]::ReadAllText($keyFilePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $fileKey = [string](Get-HoiImageProperty -Object (Get-HoiImageProperty -Object $keyFile -Name 'keys') -Name $Source -Default '')
            if ($fileKey.Trim()) {
                return $fileKey.Trim()
            }
        }
    }
    $fileHint = if ($keyFilePath) { $keyFilePath } else { 'Config\image-sources.local.json of the Modding Manager' }
    throw "no API key for ${Source}: set the environment variable $variableName, or put { `"keys`": { `"$Source`": `"<key>`" } } in $fileHint"
}

function New-HoiImageProblem {
    param([Parameter(Mandatory = $true)][string]$Level, [Parameter(Mandatory = $true)][string]$Message)

    return [PSCustomObject]@{ Level = $Level; Message = $Message }
}

function Test-HoiImageRecord {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)]$Policy,
        [bool]$Used = $true,
        [AllowEmptyString()][string]$CacheDir = '',
        [AllowEmptyString()][string]$KnownYear = '',
        [AllowEmptyString()][string]$EvidenceDir = ''
    )

    $problems = [System.Collections.Generic.List[PSObject]]::new()
    $fetchHint = "$($Policy.ItemNounPlural) come only through $($Policy.FetchCommand)"
    $source = [string](Get-HoiImageProperty -Object $Record -Name 'source' -Default 'commons')
    if ((Get-HoiImageSourceNames) -notcontains $source -or @($Policy.AcceptedSources) -notcontains $source) {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "source '$source' is outside the policy: $((@($Policy.AcceptedSources)) -join ', ') only"))
        return $problems.ToArray()
    }
    $rules = Get-HoiImageSourceRules -Source $source
    $recordedCategory = [string](Get-HoiImageProperty -Object $Record -Name 'licenseCategory' -Default '')
    $derivedCategory = Get-HoiLicenceCategory -LicenseCode ([string](Get-HoiImageProperty -Object $Record -Name 'license' -Default ''))
    if (@($Policy.AcceptedCategories) -notcontains $recordedCategory -or $derivedCategory -ne $recordedCategory) {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "licence '$($Record.licenseShortName)' (code '$($Record.license)', category '$recordedCategory') is outside the policy ($(@($Policy.AcceptedCategories | ForEach-Object { if ($_ -eq 'PD') { 'public domain' } else { $_ } }) -join ', ')) or does not match its $($rules.ShortLabel) code: fetch it again"))
    }
    $publicDomainReason = [string](Get-HoiImageProperty -Object $Record -Name 'publicDomainReason' -Default '')
    if ($recordedCategory -eq 'PD' -and $publicDomainReason -notmatch $rules.ReasonPattern) {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "public domain without $($rules.ReasonText): fetch it again"))
    }
    if ($recordedCategory -eq 'CC BY-SA' -and -not (Test-HoiShareAlikeVersion -LicenseCode ([string]$Record.license)).Allowed) {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message (Test-HoiShareAlikeVersion -LicenseCode ([string]$Record.license)).Reason))
    }
    $licenceUrlPatterns = @{ 'CC BY' = '^https?://creativecommons\.org/licenses/by/'; 'CC BY-SA' = '^https?://creativecommons\.org/licenses/by-sa/' }
    if ($licenceUrlPatterns.ContainsKey($recordedCategory) -and (-not (Get-HoiImageAttribution -Record $Record -Policy $Policy) -or [string]$Record.licenseUrl -notmatch $licenceUrlPatterns[$recordedCategory])) {
        $creditWords = if ($Policy.InstitutionCredit) { 'a named author or an institution credit' } else { 'a named author' }
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "$recordedCategory needs $creditWords and the Creative Commons $($recordedCategory.Substring(3)) licence URL for the credit"))
    }
    $pageIsValid = [string]$Record.pageUrl -match $rules.PagePattern
    if ($source -eq 'commons') {
        $pageIsValid = $pageIsValid -and [string](Get-HoiImageProperty -Object $Record -Name 'commonsTitle' -Default '') -match '^File:'
    }
    if (-not $pageIsValid) {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "not $($rules.PageText): $fetchHint"))
    }
    if ([string]$Record.downloadUrl -notmatch $rules.DownloadPattern) {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "download URL '$($Record.downloadUrl)' is not on $($rules.DownloadText)"))
    }
    foreach ($requiredField in @('licenseShortName', 'downloadSha256', 'fetched')) {
        if (-not [string](Get-HoiImageProperty -Object $Record -Name $requiredField -Default '')) {
            $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "no ${requiredField}: $fetchHint"))
        }
    }
    if ([string]$Record.downloadSha256 -and [string]$Record.downloadSha256 -notmatch '^[0-9a-f]{64}$') {
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "downloadSha256 is not a SHA-256: $fetchHint"))
    }
    $recordWidth = [int](Get-HoiImageProperty -Object $Record -Name 'width' -Default 0)
    $recordHeight = [int](Get-HoiImageProperty -Object $Record -Name 'height' -Default 0)
    if (Get-HoiImageSizeProblem -Policy $Policy -Width $recordWidth -Height $recordHeight) {
        $sizeNeed = if ($Policy.MinShorterSide -gt 0) { "at least $($Policy.MinShorterSide) px on its shorter side" } else { "at least $($Policy.MinWidth)x$($Policy.MinHeight)" }
        $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "the original is ${recordWidth}x${recordHeight}; $($Policy.MinSizeText) needs $sizeNeed"))
    }
    $publicDomainReasons = @($publicDomainReason -split ',\s*' | Where-Object { $_ })
    if ($recordedCategory -eq 'PD' -and $publicDomainReasons.Count -gt 0 -and @($publicDomainReasons | Where-Object { $_ -notmatch '^(PD-US|NoC-US)' }).Count -eq 0) {
        $problems.Add((New-HoiImageProblem -Level 'WARN' -Message "public domain in the United States only ($($publicDomainReasons -join ', ')); the owner decides before a release"))
    }
    if ($CacheDir -and [string]$Record.downloadSha256 -and [string]$Record.downloadUrl -match $rules.DownloadPattern) {
        $cachePath = Get-HoiImageCachePath -CacheDir $CacheDir -Record $Record
        if ((Test-Path -LiteralPath $cachePath) -and (Get-HoiImageSha256 -Path $cachePath) -ne [string]$Record.downloadSha256) {
            $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message 'the downloaded file in sources-cache does not match the SHA-256 recorded at fetch time'))
        }
    }
    if ([string](Get-HoiImageProperty -Object $Record -Name 'restrictions' -Default '')) {
        $problems.Add((New-HoiImageProblem -Level 'WARN' -Message "$($rules.Label) lists restrictions: $($Record.restrictions); the owner reviews it before a release"))
    }
    if ($source -eq 'manual') {
        $manualLevel = if ($Used) { 'ERROR' } else { 'WARN' }
        if ($EvidenceDir) {
            foreach ($evidenceProblem in @(Test-HoiManualEvidence -Record $Record -EvidenceDir $EvidenceDir)) {
                $problems.Add((New-HoiImageProblem -Level $manualLevel -Message $evidenceProblem))
            }
        }
        if (-not (Test-HoiOwnerConfirmation -Record $Record)) {
            $problems.Add((New-HoiImageProblem -Level $manualLevel -Message "the owner has not confirmed this manual licence, or its evidence changed since: show the owner the quote and the pages, and on the owner's word run build.ps1 -ConfirmLicence -Key $($Record.key)"))
        }
    }
    if ($Used) {
        $ownWorkClaim = [bool](Get-HoiImageProperty -Object $Record -Name 'ownWorkClaim' -Default $false) -or (Test-HoiOwnWorkClaim -Templates @() -PublicDomainReason $publicDomainReason -AttributionText ([string](Get-HoiImageProperty -Object $Record -Name 'credit' -Default '')))
        if ($ownWorkClaim) {
            $recordedYear = Get-HoiPictureYear -Texts @($KnownYear, [string](Get-HoiImageProperty -Object $Record -Name 'pictureYear' -Default ''), [string](Get-HoiImageProperty -Object $Record -Name 'dateOriginal' -Default ''), [string](Get-HoiImageProperty -Object $Record -Name 'commonsTitle' -Default ''))
            if ($null -eq $recordedYear) {
                $problems.Add((New-HoiImageProblem -Level 'WARN' -Message "own work without a date in the record: fetch it again, which refuses own work on a picture dated before $($Policy.OwnWorkCutoffYear)"))
            } elseif ([int]$recordedYear -lt $Policy.OwnWorkCutoffYear) {
                $problems.Add((New-HoiImageProblem -Level 'ERROR' -Message "own work on a picture dated ${recordedYear}: the uploader cannot be its author, so the licence cannot be trusted; replace it"))
            }
        }
    }
    return $problems.ToArray()
}
