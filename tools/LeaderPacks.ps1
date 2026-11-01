function Get-LpUtf8 {
    param([switch]$Bom)

    return [System.Text.UTF8Encoding]::new([bool]$Bom)
}

function Get-LpLanguages {
    return @('braz_por', 'english', 'french', 'german', 'japanese', 'korean', 'polish', 'russian', 'simp_chinese', 'spanish')
}

function Get-LpRoleKinds {
    return [ordered]@{ corps_commander = 'army'; field_marshal = 'army'; navy_leader = 'navy' }
}

function Get-LpRoleTitle {
    param([string]$Role)

    switch ($Role) {
        'corps_commander' { return 'general' }
        'field_marshal' { return 'field marshal' }
        'navy_leader' { return 'admiral' }
    }
    return $Role
}

function Get-LpRoleEffect {
    param([string]$Role)

    switch ($Role) {
        'corps_commander' { return 'add_corps_commander_role' }
        'field_marshal' { return 'add_field_marshal_role' }
        'navy_leader' { return 'add_naval_commander_role' }
    }
    return ''
}

function Get-LpRoleGuard {
    param([string]$Role)

    if ((Get-LpRoleKinds)[$Role] -eq 'navy') {
        return 'is_navy_leader'
    }
    return 'is_army_leader'
}

function ConvertTo-LpArray {
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

function Get-LpProperty {
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

function Read-LpJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Write-LpText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [switch]$Bom
    )

    $parentPath = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, (Get-LpUtf8 -Bom:$Bom))
}

function Format-LpJson {
    param([Parameter(Mandatory = $true)][string]$Json)

    $builder = [System.Text.StringBuilder]::new()
    $depth = 0
    $insideString = $false
    $escapeNext = $false
    $newLine = "`r`n"
    for ($index = 0; $index -lt $Json.Length; $index++) {
        $character = $Json[$index]
        if ($insideString) {
            [void]$builder.Append($character)
            if ($escapeNext) {
                $escapeNext = $false
            } elseif ($character -eq [char]'\') {
                $escapeNext = $true
            } elseif ($character -eq [char]'"') {
                $insideString = $false
            }
            continue
        }
        if ([char]::IsWhiteSpace($character)) {
            continue
        }
        if ($character -eq [char]'"') {
            $insideString = $true
            [void]$builder.Append($character)
        } elseif ($character -eq [char]'{' -or $character -eq [char]'[') {
            $closing = if ($character -eq [char]'{') { [char]'}' } else { [char]']' }
            $nextIndex = $index + 1
            while ($nextIndex -lt $Json.Length -and [char]::IsWhiteSpace($Json[$nextIndex])) { $nextIndex++ }
            if ($nextIndex -lt $Json.Length -and $Json[$nextIndex] -eq $closing) {
                [void]$builder.Append($character).Append($closing)
                $index = $nextIndex
                continue
            }
            $depth++
            [void]$builder.Append($character).Append($newLine).Append(' ' * (4 * $depth))
        } elseif ($character -eq [char]'}' -or $character -eq [char]']') {
            $depth--
            [void]$builder.Append($newLine).Append(' ' * (4 * $depth)).Append($character)
        } elseif ($character -eq [char]',') {
            [void]$builder.Append(',').Append($newLine).Append(' ' * (4 * $depth))
        } elseif ($character -eq [char]':') {
            [void]$builder.Append(': ')
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString()
}

function Write-LpJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value,
        [int]$Depth = 12
    )

    Write-LpText -Path $Path -Text ((Format-LpJson -Json (ConvertTo-Json -InputObject $Value -Depth $Depth -Compress)) + "`r`n")
}

function Format-LpNumber {
    param([Parameter(Mandatory = $true)]$Value)

    return ([double]$Value).ToString('0.####', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-LpToday {
    return (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-LpSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-LpWholeNumber {
    param($Value)

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte]) {
        return [int]$Value
    }
    if (($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) -and [double]$Value -eq [Math]::Floor([double]$Value)) {
        return [int]$Value
    }
    return $null
}

function ConvertTo-LpComparableName {
    param([AllowEmptyString()][string]$Name)

    $decomposed = ([string]$Name).Normalize([System.Text.NormalizationForm]::FormD)
    $plain = [regex]::Replace($decomposed, '\p{Mn}', '')
    return (($plain.ToLowerInvariant() -replace '[^a-z0-9]+', ' ').Trim())
}

function ConvertTo-LpOrdered {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [string] -or $Value -is [ValueType]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $dictionary = [ordered]@{}
        foreach ($entryKey in @($Value.Keys)) {
            $dictionary[[string]$entryKey] = ConvertTo-LpOrdered -Value $Value[$entryKey]
        }
        return $dictionary
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $items.Add((ConvertTo-LpOrdered -Value $item))
        }
        return , $items.ToArray()
    }
    $ordered = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
        $ordered[$property.Name] = ConvertTo-LpOrdered -Value $property.Value
    }
    return $ordered
}

function Get-LpPackNames {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $settingsPath = Join-Path $RepoRoot 'tools\HoiModBuild.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return @()
    }
    $packages = Get-LpProperty -Object (Read-LpJson -Path $settingsPath) -Name 'packages'
    if ($null -eq $packages) {
        return @()
    }
    return @($packages.PSObject.Properties | ForEach-Object { $_.Name })
}

function Read-LpOptionalJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return (Read-LpJson -Path $Path)
    }
    return $null
}

function Get-LpPack {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack
    )

    $RepoRoot = (Get-Item -LiteralPath $RepoRoot).FullName.TrimEnd('\')
    $sourceDir = Join-Path $RepoRoot ('source\' + $Pack)
    $leadersPath = Join-Path $sourceDir 'leaders.json'
    if (-not (Test-Path -LiteralPath $leadersPath)) {
        throw "source\$Pack\leaders.json not found: create the pack with build.ps1 -NewPack"
    }
    $leaderSource = Read-LpJson -Path $leadersPath
    $photoSource = Read-LpOptionalJson -Path (Join-Path $sourceDir 'photos.json')
    $factSheetPath = Join-Path $sourceDir 'fact-sheets.md'
    $introPath = Join-Path $sourceDir 'workshop-intro.bbcode'
    $dataDir = Join-Path $RepoRoot 'data'
    $tag = [string](Get-LpProperty -Object $leaderSource -Name 'tag' -Default '')
    return [PSCustomObject]@{
        Name            = $Pack
        RepoRoot        = $RepoRoot
        SourceDir       = $sourceDir
        PackRoot        = Join-Path $RepoRoot ('packs\' + $Pack)
        CacheDir        = Join-Path $RepoRoot ('sources-cache\' + $Pack)
        PortraitDir     = Join-Path $sourceDir 'portraits'
        DataDir         = $dataDir
        SourcePack      = [string](Get-LpProperty -Object $leaderSource -Name 'pack' -Default '')
        Tag             = $tag
        Prefix          = [string](Get-LpProperty -Object $leaderSource -Name 'prefix' -Default '')
        DisplayName     = [string](Get-LpProperty -Object $leaderSource -Name 'displayName' -Default $Pack)
        Leaders         = @(ConvertTo-LpArray (Get-LpProperty -Object $leaderSource -Name 'leaders'))
        Photos          = @(ConvertTo-LpArray (Get-LpProperty -Object $photoSource -Name 'photos'))
        PortraitRecords = Read-LpOptionalJson -Path (Join-Path $sourceDir 'portraits.json')
        ConversionRecord = Read-LpOptionalJson -Path (Join-Path $sourceDir 'converted.json')
        FactSheetText   = $(if (Test-Path -LiteralPath $factSheetPath) { [System.IO.File]::ReadAllText($factSheetPath, [System.Text.Encoding]::UTF8) } else { '' })
        WorkshopIntro   = $(if (Test-Path -LiteralPath $introPath) { [System.IO.File]::ReadAllText($introPath, [System.Text.Encoding]::UTF8).Trim() } else { '' })
        Workshop        = Read-LpJson -Path (Join-Path $dataDir 'workshop.json')
        Snapshot        = Read-LpOptionalJson -Path (Join-Path $dataDir ($Pack + '\game-characters.json'))
        StartTraits     = Read-LpOptionalJson -Path (Join-Path $dataDir ($Pack + '\start-traits.json'))
        StatBands       = Read-LpOptionalJson -Path (Join-Path $dataDir 'stat-bands.json')
    }
}

function Get-LpWikiPageName {
    param($Pack)

    return 'Commanders-Pack-' + ($Pack.DisplayName -replace '\s+', '-')
}

function Get-LpMode {
    param($Leader)

    return [string](Get-LpProperty -Object $Leader -Name 'mode' -Default '')
}

function Get-LpGeneratedLeaders {
    param($Pack, [string[]]$Mode = @('new', 'addRole'))

    return @($Pack.Leaders | Where-Object { $Mode -contains (Get-LpMode -Leader $_) })
}

function Get-LpCharacterId {
    param($Pack, $Leader)

    if ((Get-LpMode -Leader $Leader) -eq 'addRole') {
        return [string](Get-LpProperty -Object $Leader -Name 'target' -Default '')
    }
    return $Pack.Prefix + '_' + [string]$Leader.key
}

function Get-LpLargeSprite {
    param($Pack, $Leader)

    return 'GFX_portrait_' + $Pack.Prefix + '_' + [string]$Leader.key
}

function Get-LpSmallSprite {
    param($Pack, $Leader)

    return (Get-LpLargeSprite -Pack $Pack -Leader $Leader) + '_small'
}

function Get-LpLargeRelativePath {
    param($Pack, $Leader)

    return 'gfx/leaders/' + $Pack.Tag + '/' + $Pack.Prefix + '_' + [string]$Leader.key + '.dds'
}

function Get-LpSmallRelativePath {
    param($Pack, $Leader)

    return 'gfx/interface/ideas/' + $Pack.Prefix + '_' + [string]$Leader.key + '_small.dds'
}

function Get-LpStatBand {
    param($Pack, [string]$Role)

    $roleKind = (Get-LpRoleKinds)[$Role]
    if (-not $roleKind -or $null -eq $Pack.StatBands) {
        return $null
    }
    return (Get-LpProperty -Object $Pack.StatBands -Name $roleKind)
}

function Get-LpStatNames {
    param($Pack, [string]$Role)

    $band = Get-LpStatBand -Pack $Pack -Role $Role
    if ($null -eq $band) {
        return @()
    }
    return @($band.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-LpStatScriptKey {
    param([string]$StatName)

    if ($StatName -eq 'skill') {
        return 'skill'
    }
    return $StatName + '_skill'
}

function Get-LpTraits {
    param($Leader)

    return @(ConvertTo-LpArray (Get-LpProperty -Object $Leader -Name 'traits') | ForEach-Object { [string]$_ })
}

function Get-LpSameAs {
    param($Leader)

    return @(ConvertTo-LpArray (Get-LpProperty -Object $Leader -Name 'sameAs') | ForEach-Object { [string]$_ })
}

function Add-LpRoleBody {
    param(
        [Parameter(Mandatory = $true)]$Lines,
        $Pack,
        $Leader,
        [Parameter(Mandatory = $true)][string]$Indent
    )

    $traits = @(Get-LpTraits -Leader $Leader)
    if ($traits.Count -gt 0) {
        $Lines.Add($Indent + 'traits = { ' + ($traits -join ' ') + ' }')
    }
    $role = [string]$Leader.role
    foreach ($statName in (Get-LpStatNames -Pack $Pack -Role $role)) {
        $Lines.Add($Indent + (Get-LpStatScriptKey -StatName $statName) + ' = ' + (Format-LpNumber (Get-LpProperty -Object $Leader -Name $statName -Default 0)))
    }
}

function Get-LpPortraitKeys {
    param([string]$Role)

    if ((Get-LpRoleKinds)[$Role] -eq 'navy') {
        return @('army', 'navy')
    }
    return @('army')
}

function New-LpCharactersText {
    param($Pack)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('characters = {')
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack -Mode @('new'))) {
        $characterId = Get-LpCharacterId -Pack $Pack -Leader $leader
        $lines.Add("`t" + $characterId + ' = {')
        $lines.Add("`t`tname = " + $characterId)
        $lines.Add("`t`tportraits = {")
        foreach ($portraitKey in (Get-LpPortraitKeys -Role ([string]$leader.role))) {
            $lines.Add("`t`t`t" + $portraitKey + ' = {')
            $lines.Add("`t`t`t`tlarge = " + (Get-LpLargeSprite -Pack $Pack -Leader $leader))
            $lines.Add("`t`t`t`tsmall = " + (Get-LpSmallSprite -Pack $Pack -Leader $leader))
            $lines.Add("`t`t`t}")
        }
        $lines.Add("`t`t}")
        $lines.Add("`t`t" + [string]$leader.role + ' = {')
        Add-LpRoleBody -Lines $lines -Pack $Pack -Leader $leader -Indent "`t`t`t"
        $lines.Add("`t`t}")
        $lines.Add("`t}")
    }
    $lines.Add('}')
    return (($lines -join "`r`n") + "`r`n")
}

function New-LpOnActionsText {
    param($Pack)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('on_actions = {')
    $lines.Add("`ton_startup = {")
    $lines.Add("`t`teffect = {")
    $lines.Add("`t`t`t" + $Pack.Tag + ' = {')
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack)) {
        $characterId = Get-LpCharacterId -Pack $Pack -Leader $leader
        if ((Get-LpMode -Leader $leader) -eq 'new') {
            $sameAsIds = @(Get-LpSameAs -Leader $leader)
            if ($sameAsIds.Count -eq 0) {
                $lines.Add("`t`t`t`trecruit_character = " + $characterId)
                continue
            }
            $lines.Add("`t`t`t`tif = {")
            $lines.Add("`t`t`t`t`tlimit = {")
            foreach ($sameAsId in $sameAsIds) {
                $lines.Add("`t`t`t`t`t`tNOT = { has_character = " + $sameAsId + ' }')
            }
            $lines.Add("`t`t`t`t`t}")
            $lines.Add("`t`t`t`t`trecruit_character = " + $characterId)
            $lines.Add("`t`t`t`t}")
            continue
        }
        $role = [string]$leader.role
        $lines.Add("`t`t`t`tif = {")
        $lines.Add("`t`t`t`t`tlimit = { has_character = " + $characterId + ' }')
        $lines.Add("`t`t`t`t`t" + $characterId + ' = {')
        $lines.Add("`t`t`t`t`t`tif = {")
        $lines.Add("`t`t`t`t`t`t`tlimit = { NOT = { " + (Get-LpRoleGuard -Role $role) + ' = yes } }')
        $lines.Add("`t`t`t`t`t`t`t" + (Get-LpRoleEffect -Role $role) + ' = {')
        Add-LpRoleBody -Lines $lines -Pack $Pack -Leader $leader -Indent "`t`t`t`t`t`t`t`t"
        $lines.Add("`t`t`t`t`t`t`t}")
        $lines.Add("`t`t`t`t`t`t`tset_portraits = {")
        foreach ($portraitKey in (Get-LpPortraitKeys -Role $role)) {
            $lines.Add("`t`t`t`t`t`t`t`t" + $portraitKey + ' = { large = ' + (Get-LpLargeSprite -Pack $Pack -Leader $leader) + ' }')
        }
        $lines.Add("`t`t`t`t`t`t`t}")
        $lines.Add("`t`t`t`t`t`t}")
        $lines.Add("`t`t`t`t`t}")
        $lines.Add("`t`t`t`t}")
    }
    $lines.Add("`t`t`t}")
    $lines.Add("`t`t}")
    $lines.Add("`t}")
    $lines.Add('}')
    return (($lines -join "`r`n") + "`r`n")
}

function New-LpSpritesText {
    param($Pack)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('spriteTypes = {')
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack)) {
        $lines.Add("`tspriteType = {")
        $lines.Add("`t`tname = `"" + (Get-LpLargeSprite -Pack $Pack -Leader $leader) + '"')
        $lines.Add("`t`ttexturefile = `"" + (Get-LpLargeRelativePath -Pack $Pack -Leader $leader) + '"')
        $lines.Add("`t}")
        if ((Get-LpMode -Leader $leader) -eq 'new') {
            $lines.Add("`tspriteType = {")
            $lines.Add("`t`tname = `"" + (Get-LpSmallSprite -Pack $Pack -Leader $leader) + '"')
            $lines.Add("`t`ttexturefile = `"" + (Get-LpSmallRelativePath -Pack $Pack -Leader $leader) + '"')
            $lines.Add("`t}")
        }
    }
    $lines.Add('}')
    return (($lines -join "`r`n") + "`r`n")
}

function New-LpLocalisationText {
    param($Pack, [Parameter(Mandatory = $true)][string]$Language)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('l_' + $Language + ':')
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack -Mode @('new'))) {
        $lines.Add(' ' + (Get-LpCharacterId -Pack $Pack -Leader $leader) + ':0 "' + ([string]$leader.name).Trim() + '"')
    }
    return (($lines -join "`r`n") + "`r`n")
}

function Get-LpPhotoByKey {
    param($Pack, [string]$PhotoKey)

    return @($Pack.Photos | Where-Object { [string]$_.key -eq $PhotoKey }) | Select-Object -First 1
}

function Get-LpLeaderPhotoKey {
    param($Leader)

    return [string](Get-LpProperty -Object (Get-LpProperty -Object $Leader -Name 'portrait') -Name 'photo' -Default '')
}

function Get-LpLicenceLabel {
    param($Photo)

    $category = [string](Get-LpProperty -Object $Photo -Name 'licenseCategory' -Default '')
    if ($category -eq 'PD') {
        $publicDomainReason = [string](Get-LpProperty -Object $Photo -Name 'publicDomainReason' -Default '')
        if ($publicDomainReason) {
            return 'Public domain (' + $publicDomainReason + ')'
        }
        return 'Public domain'
    }
    return [string](Get-LpProperty -Object $Photo -Name 'licenseShortName' -Default $category)
}

function Get-LpUsedPhotos {
    param($Pack)

    $usedPhotos = [System.Collections.Generic.List[object]]::new()
    foreach ($photoKey in @(Get-LpGeneratedLeaders -Pack $Pack | ForEach-Object { Get-LpLeaderPhotoKey -Leader $_ } | Where-Object { $_ } | Sort-Object -Unique)) {
        $photo = Get-LpPhotoByKey -Pack $Pack -PhotoKey $photoKey
        if ($null -ne $photo) {
            $usedPhotos.Add($photo)
        }
    }
    return $usedPhotos.ToArray()
}

function Get-LpLeaderLabel {
    param($Leader)

    $label = ([string]$Leader.name).Trim() + ', ' + (Get-LpRoleTitle -Role ([string]$Leader.role))
    if ((Get-LpMode -Leader $Leader) -eq 'addRole') {
        $label += ' (an advisor in the base game, now also in command)'
    }
    return $label
}

function New-LpWorkshopText {
    param($Pack)

    $bbcodeLines = [System.Collections.Generic.List[string]]::new()
    if ($Pack.WorkshopIntro) {
        $bbcodeLines.Add($Pack.WorkshopIntro)
        $bbcodeLines.Add('')
    }
    $generatedLeaders = @(Get-LpGeneratedLeaders -Pack $Pack)
    if ($generatedLeaders.Count -gt 0) {
        $bbcodeLines.Add('[h1]Commanders[/h1]')
        $bbcodeLines.Add('[list]')
        foreach ($leader in $generatedLeaders) {
            $bbcodeLines.Add('[*]' + (Get-LpLeaderLabel -Leader $leader))
        }
        $bbcodeLines.Add('[/list]')
        $bbcodeLines.Add('')
    }
    $wikiPageUrl = ([string]$Pack.Workshop.wikiUrl).TrimEnd('/') + '/' + (Get-LpWikiPageName -Pack $Pack)
    $licenceNames = @(Get-LpUsedPhotos -Pack $Pack | ForEach-Object { ([string]$_.licenseShortName) -replace '^Public domain$', 'public domain' } | Where-Object { $_ } | Sort-Object -Unique -Descending)
    $licenceText = ''
    if ($licenceNames.Count -gt 1) {
        $licenceText = ' (' + ((($licenceNames[0..($licenceNames.Count - 2)]) -join ', ') + ' and ' + $licenceNames[-1]) + ')'
    } elseif ($licenceNames.Count -eq 1) {
        $licenceText = ' (' + $licenceNames[0] + ')'
    }
    $bbcodeLines.Add('[h1]Portraits[/h1]')
    $bbcodeLines.Add('The portraits are AI-assisted repaints of period photographs from Wikimedia Commons, used under licences that allow it' + $licenceText + '. Each photograph was coloured and repainted in the style of the game with a local image model, then cropped and resized for the game. The source, author and licence of each photograph are on the [url=' + $wikiPageUrl + ']wiki page of this pack[/url].')
    $otherMods = @(ConvertTo-LpArray (Get-LpProperty -Object $Pack.Workshop -Name 'otherMods'))
    if ($otherMods.Count -gt 0) {
        $bbcodeLines.Add('')
        $bbcodeLines.Add('[h1]More from the author[/h1]')
        $bbcodeLines.Add('[list]')
        foreach ($otherMod in $otherMods) {
            $bbcodeLines.Add('[*][url=https://steamcommunity.com/sharedfiles/filedetails/?id=' + $otherMod.workshopId + ']' + $otherMod.name + '[/url]')
        }
        $bbcodeLines.Add('[/list]')
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Commanders Pack: ' + $Pack.DisplayName + ' - Workshop description')
    $lines.Add('')
    $lines.Add('Generated by `build.ps1 -Generate` from `source/' + $Pack.Name + '/workshop-intro.bbcode`, `leaders.json` and `photos.json`. Do not edit this file: change the sources and generate again.')
    $lines.Add('')
    $lines.Add('```bbcode')
    foreach ($bbcodeLine in $bbcodeLines) {
        $lines.Add($bbcodeLine)
    }
    $lines.Add('```')
    return (($lines -join "`r`n") + "`r`n")
}

function New-LpWikiText {
    param($Pack)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Commanders Pack: ' + $Pack.DisplayName)
    $lines.Add('')
    $lines.Add('Generated by `build.ps1 -Generate` from `source/' + $Pack.Name + '/`. Do not edit: change the sources and generate again.')
    $lines.Add('')
    $lines.Add('Every portrait is an AI-assisted repaint of a period photograph from Wikimedia Commons: the photograph was coloured and repainted with a local image model, then cropped and resized for the game. The Photo column links the Commons page of each photograph; the Licence column names its licence and author.')
    $lines.Add('')
    $lines.Add('| Leader | Character | Role | Photo | Licence | Portrait |')
    $lines.Add('|---|---|---|---|---|---|')
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack)) {
        $photoCell = 'not fetched yet'
        $licenceCell = '-'
        $photo = Get-LpPhotoByKey -Pack $Pack -PhotoKey (Get-LpLeaderPhotoKey -Leader $leader)
        if ($null -ne $photo) {
            $photoCell = '[' + (([string]$photo.commonsTitle) -replace '^File:', '') + '](' + [string]$photo.pageUrl + ')'
            $licenceCell = Get-LpLicenceLabel -Photo $photo
            if ([string]$photo.licenseCategory -eq 'CC BY' -and [string]$photo.licenseUrl) {
                $licenceCell = '[' + $licenceCell + '](' + [string]$photo.licenseUrl + ')'
            }
            if ([string]$photo.author) {
                $licenceCell += ', ' + [string]$photo.author
            }
        }
        $lines.Add('| ' + ([string]$leader.name).Trim() + ' | `' + (Get-LpCharacterId -Pack $Pack -Leader $leader) + '` | ' + (Get-LpRoleTitle -Role ([string]$leader.role)) + ' | ' + $photoCell + ' | ' + $licenceCell + ' | AI-assisted repaint |')
    }
    return (($lines -join "`r`n") + "`r`n")
}

function Get-LpGeneratedFiles {
    param($Pack)

    $generatedFiles = [ordered]@{}
    $packPrefix = 'packs/' + $Pack.Name + '/'
    $newLeaders = @(Get-LpGeneratedLeaders -Pack $Pack -Mode @('new'))
    $generatedLeaders = @(Get-LpGeneratedLeaders -Pack $Pack)
    if ($newLeaders.Count -gt 0) {
        $generatedFiles[$packPrefix + 'common/characters/' + $Pack.Prefix + '_characters.txt'] = @{ Text = (New-LpCharactersText -Pack $Pack); Bom = $false }
    }
    if ($generatedLeaders.Count -gt 0) {
        $generatedFiles[$packPrefix + 'common/on_actions/' + $Pack.Prefix + '_on_actions.txt'] = @{ Text = (New-LpOnActionsText -Pack $Pack); Bom = $false }
        $generatedFiles[$packPrefix + 'interface/' + $Pack.Prefix + '_portraits.gfx'] = @{ Text = (New-LpSpritesText -Pack $Pack); Bom = $false }
    }
    if ($newLeaders.Count -gt 0) {
        foreach ($language in (Get-LpLanguages)) {
            $generatedFiles[$packPrefix + 'localisation/' + $language + '/' + $Pack.Prefix + '_l_' + $language + '.yml'] = @{ Text = (New-LpLocalisationText -Pack $Pack -Language $language); Bom = $true }
        }
    }
    $generatedFiles[$packPrefix + 'WORKSHOP_DESCRIPTION_GUIDELINES.md'] = @{ Text = (New-LpWorkshopText -Pack $Pack); Bom = $false }
    $generatedFiles['wiki/' + (Get-LpWikiPageName -Pack $Pack) + '.md'] = @{ Text = (New-LpWikiText -Pack $Pack); Bom = $false }
    return $generatedFiles
}

function Get-LpManagedFiles {
    param($Pack)

    $packRoot = $Pack.PackRoot
    $managedFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($managedFolder in @('common\characters', 'common\on_actions', 'interface', 'localisation')) {
        $folderPath = Join-Path $packRoot $managedFolder
        if (Test-Path -LiteralPath $folderPath) {
            foreach ($managedFile in @(Get-ChildItem -LiteralPath $folderPath -Recurse -File)) {
                $managedFiles.Add(('packs/' + $Pack.Name + '/' + $managedFile.FullName.Substring($packRoot.Length + 1)).Replace('\', '/'))
            }
        }
    }
    $workshopPath = Join-Path $packRoot 'WORKSHOP_DESCRIPTION_GUIDELINES.md'
    if (Test-Path -LiteralPath $workshopPath) {
        $managedFiles.Add('packs/' + $Pack.Name + '/WORKSHOP_DESCRIPTION_GUIDELINES.md')
    }
    return , $managedFiles
}

function Get-LpGenerationDelta {
    param($Pack)

    $generatedFiles = Get-LpGeneratedFiles -Pack $Pack
    $changedPaths = [System.Collections.Generic.List[string]]::new()
    $stalePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($relativePath in @($generatedFiles.Keys)) {
        $fullPath = Join-Path $Pack.RepoRoot $relativePath
        $expected = $generatedFiles[$relativePath]
        if (-not (Test-Path -LiteralPath $fullPath)) {
            $changedPaths.Add($relativePath)
            continue
        }
        $expectedBytes = [byte[]]@((Get-LpUtf8 -Bom:$expected.Bom).GetPreamble()) + (Get-LpUtf8).GetBytes($expected.Text)
        $actualBytes = [System.IO.File]::ReadAllBytes($fullPath)
        if ([System.Convert]::ToBase64String($expectedBytes) -cne [System.Convert]::ToBase64String($actualBytes)) {
            $changedPaths.Add($relativePath)
        }
    }
    foreach ($managedPath in (Get-LpManagedFiles -Pack $Pack)) {
        if (-not $generatedFiles.Contains($managedPath)) {
            $stalePaths.Add($managedPath)
        }
    }
    return [PSCustomObject]@{ Files = $generatedFiles; Changed = $changedPaths; Stale = $stalePaths }
}

function Invoke-LpGenerate {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [switch]$DryRun
    )

    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $problems = @(Test-LpPackSource -Pack $packData)
    $errors = @($problems | Where-Object { $_.Level -eq 'ERROR' })
    Write-LpProblems -Problems $problems
    if ($errors.Count -gt 0) {
        Write-Host "Generate refused: $($errors.Count) error(s) in source\$Pack." -ForegroundColor Red
        return 1
    }
    $delta = Get-LpGenerationDelta -Pack $packData
    $leaderCount = @(Get-LpGeneratedLeaders -Pack $packData).Count
    if ($DryRun) {
        foreach ($changedPath in $delta.Changed) {
            Write-Host "  would write $changedPath" -ForegroundColor Gray
        }
        foreach ($stalePath in $delta.Stale) {
            Write-Host "  would remove $stalePath" -ForegroundColor Gray
        }
        Write-Host "Dry run OK: $leaderCount leader(s), $($delta.Changed.Count) file(s) to write, $($delta.Stale.Count) to remove." -ForegroundColor Green
        return 0
    }
    foreach ($changedPath in $delta.Changed) {
        $generatedFile = $delta.Files[$changedPath]
        Write-LpText -Path (Join-Path $packData.RepoRoot $changedPath) -Text $generatedFile.Text -Bom:$generatedFile.Bom
        Write-Host "  wrote $changedPath" -ForegroundColor Gray
    }
    foreach ($stalePath in $delta.Stale) {
        Remove-Item -LiteralPath (Join-Path $packData.RepoRoot $stalePath) -Force
        Write-Host "  removed $stalePath" -ForegroundColor Gray
    }
    Write-Host "Generated pack '$Pack': $leaderCount leader(s), $($delta.Changed.Count) file(s) written, $($delta.Stale.Count) removed." -ForegroundColor Green
    return 0
}

function New-LpProblem {
    param([string]$Level, [string]$Where, [string]$Message)

    return [PSCustomObject]@{ Level = $Level; Where = $Where; Message = $Message }
}

function Write-LpProblems {
    param([AllowEmptyCollection()]$Problems)

    foreach ($problem in @($Problems)) {
        $color = if ($problem.Level -eq 'ERROR') { 'Red' } else { 'Yellow' }
        Write-Host ('  [{0}] {1}: {2}' -f $problem.Level, $problem.Where, $problem.Message) -ForegroundColor $color
    }
}

function Get-LpSnapshotIndex {
    param($Snapshot)

    $byId = @{}
    $byName = @{}
    foreach ($characterSet in @(ConvertTo-LpArray (Get-LpProperty -Object $Snapshot -Name 'sets'))) {
        $setName = [string]$characterSet.name
        foreach ($character in @(ConvertTo-LpArray (Get-LpProperty -Object $characterSet -Name 'characters'))) {
            $roleKinds = @(ConvertTo-LpArray (Get-LpProperty -Object $character -Name 'roles') | ForEach-Object { [string]$_.kind })
            $entry = [PSCustomObject]@{ Set = $setName; Id = [string]$character.id; Name = [string]$character.name; Roles = $roleKinds }
            if (-not $byId.ContainsKey($entry.Id)) {
                $byId[$entry.Id] = [System.Collections.Generic.List[object]]::new()
            }
            $byId[$entry.Id].Add($entry)
            $comparableName = ConvertTo-LpComparableName -Name $entry.Name
            if ($comparableName) {
                if (-not $byName.ContainsKey($comparableName)) {
                    $byName[$comparableName] = [System.Collections.Generic.List[object]]::new()
                }
                $byName[$comparableName].Add($entry)
            }
        }
    }
    return [PSCustomObject]@{ ById = $byId; ByName = $byName }
}

function Test-LpUnitLeaderEntry {
    param($Entry, [string]$Kind)

    $unitRoles = @((Get-LpRoleKinds).Keys | Where-Object { -not $Kind -or (Get-LpRoleKinds)[$_] -eq $Kind })
    return (@($Entry.Roles | Where-Object { $unitRoles -contains $_ }).Count -gt 0)
}

function Test-LpPackSource {
    param($Pack)

    $problems = [System.Collections.Generic.List[PSObject]]::new()
    $leadersWhere = 'source/' + $Pack.Name + '/leaders.json'
    $roleKinds = Get-LpRoleKinds

    if ($Pack.SourcePack -ne $Pack.Name) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where $leadersWhere -Message "pack '$($Pack.SourcePack)' is not the folder name '$($Pack.Name)'"))
    }
    if ($Pack.Tag -cnotmatch '^[A-Z][A-Z0-9]{2}$') {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where $leadersWhere -Message "tag '$($Pack.Tag)' is not a country tag"))
    } elseif ($Pack.Prefix -cne ('lp_' + $Pack.Tag.ToLowerInvariant())) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where $leadersWhere -Message "prefix '$($Pack.Prefix)' must be lp_$($Pack.Tag.ToLowerInvariant())"))
    }
    if (-not $Pack.DisplayName.Trim() -or $Pack.DisplayName -notmatch '^[\x20-\x7E]+$') {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where $leadersWhere -Message 'displayName must be plain ASCII text'))
    }
    if ($Pack.Leaders.Count -eq 0) {
        return $problems.ToArray()
    }
    if ($null -eq $Pack.Snapshot) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where ('data/' + $Pack.Name + '/game-characters.json') -Message ('missing: run build.ps1 -RefreshGameData -Pack ' + $Pack.Name)))
    }
    if ($null -eq $Pack.StartTraits) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where ('data/' + $Pack.Name + '/start-traits.json') -Message ('missing: run build.ps1 -RefreshGameData -Pack ' + $Pack.Name)))
    }
    if ($null -eq $Pack.StatBands) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where 'data/stat-bands.json' -Message 'missing'))
    }
    $snapshotIndex = if ($null -ne $Pack.Snapshot) { Get-LpSnapshotIndex -Snapshot $Pack.Snapshot } else { $null }
    $allStatNames = @('skill', 'attack', 'defense', 'planning', 'logistics', 'maneuvering', 'coordination')
    if ($null -ne $Pack.StatBands) {
        foreach ($bandKind in @('army', 'navy')) {
            $kindBand = Get-LpProperty -Object $Pack.StatBands -Name $bandKind
            if ($null -ne $kindBand) {
                $allStatNames = @(@($allStatNames) + @($kindBand.PSObject.Properties | ForEach-Object { $_.Name }) | Sort-Object -Unique)
            }
        }
    }

    $seenKeys = @{}
    $seenTargets = @{}
    foreach ($leader in $Pack.Leaders) {
        $leaderKey = [string](Get-LpProperty -Object $leader -Name 'key' -Default '')
        $leaderWhere = 'leader ' + $leaderKey
        if ($leaderKey -cnotmatch '^[a-z0-9_]+$') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "key '$leaderKey' must be lower-case letters, digits and underscores"))
        } elseif ($seenKeys.ContainsKey($leaderKey)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "key '$leaderKey' used twice"))
        }
        $seenKeys[$leaderKey] = $true

        $leaderName = [string](Get-LpProperty -Object $leader -Name 'name' -Default '')
        if (-not $leaderName.Trim()) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'no name'))
        } elseif ($leaderName -cnotmatch '^[\x20-\x7E]+$') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "name '$leaderName' must be in English letters with plain ASCII punctuation"))
        } elseif ($leaderName -match '["\[\]$#|]') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "name '$leaderName' contains a double quote, a square bracket, a dollar sign, a hash sign (localisation markup) or a vertical bar (the wiki table)"))
        } elseif ($leaderName -notmatch '[A-Za-z]') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "name '$leaderName' has no letter"))
        }

        $mode = Get-LpMode -Leader $leader
        if (@('new', 'addRole', 'skip') -cnotcontains $mode) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "mode '$mode' is not new, addRole or skip"))
            continue
        }
        if ($mode -eq 'skip') {
            $reason = [string](Get-LpProperty -Object $leader -Name 'reason' -Default '')
            if (-not $reason.Trim()) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'skip without a reason'))
            } elseif ($null -ne $snapshotIndex) {
                $namedIds = @([regex]::Matches($reason, '[A-Za-z0-9]+_[A-Za-z0-9_]+') | ForEach-Object { $_.Value } | Where-Object { $snapshotIndex.ById.ContainsKey($_) })
                if ($namedIds.Count -eq 0) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'the skip reason names no character id of the snapshot that already covers him'))
                }
            }
            continue
        }

        $role = [string](Get-LpProperty -Object $leader -Name 'role' -Default '')
        if (-not $roleKinds.Contains($role)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "role '$role' is not corps_commander, field_marshal or navy_leader"))
        } elseif ($null -ne $Pack.StatBands) {
            $band = Get-LpStatBand -Pack $Pack -Role $role
            $statNames = @(Get-LpStatNames -Pack $Pack -Role $role)
            foreach ($statName in $statNames) {
                $range = @(ConvertTo-LpArray (Get-LpProperty -Object $band -Name $statName))
                $statValue = Get-LpWholeNumber -Value (Get-LpProperty -Object $leader -Name $statName)
                if ($null -eq $statValue) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "$statName missing or not a whole number"))
                } elseif ($range.Count -eq 2 -and ($statValue -lt [int]$range[0] -or $statValue -gt [int]$range[1])) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "$statName $statValue is outside the start band $($range[0]) to $($range[1]) of data/stat-bands.json"))
                }
            }
            foreach ($otherStat in @($allStatNames | Where-Object { $statNames -notcontains $_ })) {
                if ($null -ne (Get-LpProperty -Object $leader -Name $otherStat)) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "$otherStat is not a stat of a $($roleKinds[$role]) leader"))
                }
            }
        }

        $traits = @(Get-LpTraits -Leader $leader)
        if (@($traits | Sort-Object -Unique).Count -ne $traits.Count) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'a trait is listed twice'))
        }
        if ($null -ne $Pack.StartTraits -and $roleKinds.Contains($role)) {
            $allowedTraits = @(ConvertTo-LpArray (Get-LpProperty -Object $Pack.StartTraits -Name $roleKinds[$role]) | ForEach-Object { [string]$_ })
            foreach ($trait in $traits) {
                if ($allowedTraits -cnotcontains $trait) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "trait '$trait' is not a trait a vanilla $($roleKinds[$role]) leader has at the start, shared or of $($Pack.Tag) (data/$($Pack.Name)/start-traits.json)"))
                }
            }
        }

        $factSheetKey = [string](Get-LpProperty -Object $leader -Name 'factSheet' -Default $leaderKey)
        $factSheetMatch = [regex]::Match($Pack.FactSheetText, '(?ms)^##\s+' + [regex]::Escape($factSheetKey) + '\s*$(.*?)(?=^##\s|\z)')
        if (-not $factSheetMatch.Success) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "no section '## $factSheetKey' in source/$($Pack.Name)/fact-sheets.md"))
        } elseif ($factSheetMatch.Groups[1].Value -notmatch 'https?://') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "fact sheet '$factSheetKey' cites no source URL"))
        }

        $portrait = Get-LpProperty -Object $leader -Name 'portrait'
        if ($null -eq $portrait) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'no portrait block'))
        } else {
            if ((Get-LpLeaderPhotoKey -Leader $leader) -cnotmatch '^[a-z0-9_]+$') {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'portrait.photo must be a photo key: lower-case letters, digits and underscores'))
            }
            if (-not ([string](Get-LpProperty -Object $portrait -Name 'headwear' -Default '')).Trim()) {
                $problems.Add((New-LpProblem -Level 'WARN' -Where $leaderWhere -Message 'portrait.headwear is empty: name the headwear (or "bareheaded"), or the repaint may put a peaked cap on'))
            }
            foreach ($optionProblem in (Get-LpPortraitOptionProblems -Portrait $portrait)) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message $optionProblem))
            }
        }

        $sameAsProperty = $leader.PSObject.Properties['sameAs']
        if ($null -eq $sameAsProperty -or $null -eq $sameAsProperty.Value) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'no sameAs list: write [] when the person has no other id'))
        }
        $sameAsIds = @(Get-LpSameAs -Leader $leader)
        foreach ($sameAsId in $sameAsIds) {
            if ($sameAsId -cnotmatch '^[A-Za-z0-9_.\-]+$') {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "sameAs id '$sameAsId' is not a character id"))
            } elseif ($null -ne $snapshotIndex -and -not $snapshotIndex.ById.ContainsKey($sameAsId)) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "sameAs id '$sameAsId' is in neither vanilla nor Road to 56 (data/$($Pack.Name)/game-characters.json)"))
            }
        }

        if ($mode -eq 'new') {
            if ($null -ne $snapshotIndex) {
                foreach ($sameAsId in @($sameAsIds | Where-Object { $snapshotIndex.ById.ContainsKey($_) })) {
                    foreach ($entry in $snapshotIndex.ById[$sameAsId]) {
                        if (Test-LpUnitLeaderEntry -Entry $entry) {
                            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "sameAs id '$sameAsId' is a unit leader in $($entry.Set) already: the leader is skip, not new"))
                        }
                    }
                }
                $comparableName = ConvertTo-LpComparableName -Name $leaderName
                if ($comparableName -and $snapshotIndex.ByName.ContainsKey($comparableName)) {
                    foreach ($entry in $snapshotIndex.ByName[$comparableName]) {
                        if (Test-LpUnitLeaderEntry -Entry $entry) {
                            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "name '$leaderName' belongs to the unit leader $($entry.Id) in $($entry.Set): the leader is skip, not new"))
                        } elseif ($sameAsIds -notcontains $entry.Id) {
                            $problems.Add((New-LpProblem -Level 'WARN' -Where $leaderWhere -Message "name '$leaderName' matches $($entry.Id) in $($entry.Set): list it in sameAs, or use addRole"))
                        }
                    }
                }
            }
            continue
        }

        $target = [string](Get-LpProperty -Object $leader -Name 'target' -Default '')
        if ($target -cnotmatch '^[A-Za-z0-9_.\-]+$') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'addRole needs a target: the existing character id'))
            continue
        }
        if ($seenTargets.ContainsKey($target)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "target '$target' is given a role by two leaders"))
        }
        $seenTargets[$target] = $true
        if ($null -eq $snapshotIndex) {
            continue
        }
        if (-not $snapshotIndex.ById.ContainsKey($target)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "target '$target' is in neither vanilla nor Road to 56 (data/$($Pack.Name)/game-characters.json)"))
            continue
        }
        $vanillaEntries = @($snapshotIndex.ById[$target] | Where-Object { $_.Set -eq 'vanilla' })
        if ($vanillaEntries.Count -eq 0) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "target '$target' does not exist in vanilla"))
            continue
        }
        if (@($vanillaEntries | Where-Object { $_.Roles -contains 'advisor' }).Count -eq 0) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "target '$target' has no advisor role in vanilla"))
        }
        if ($roleKinds.Contains($role) -and @($vanillaEntries | Where-Object { Test-LpUnitLeaderEntry -Entry $_ -Kind $roleKinds[$role] }).Count -gt 0) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "target '$target' is already a unit leader of the $($roleKinds[$role]) in vanilla: the leader is skip"))
        }
    }

    foreach ($photoProblem in @(Test-LpPhotos -Pack $Pack)) {
        $problems.Add($photoProblem)
    }
    return $problems.ToArray()
}

function Test-LpPhotos {
    param($Pack)

    $problems = [System.Collections.Generic.List[PSObject]]::new()
    $usedPhotoKeys = @(Get-LpGeneratedLeaders -Pack $Pack | ForEach-Object { Get-LpLeaderPhotoKey -Leader $_ })
    $seenPhotoKeys = @{}
    foreach ($photo in $Pack.Photos) {
        $photoWhere = 'photo ' + [string]$photo.key
        if ([string]$photo.key -cnotmatch '^[a-z0-9_]+$' -or $seenPhotoKeys.ContainsKey([string]$photo.key)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message 'key missing, used twice or not lower-case letters, digits and underscores'))
        }
        $seenPhotoKeys[[string]$photo.key] = $true
        $recordedCategory = [string](Get-LpProperty -Object $photo -Name 'licenseCategory' -Default '')
        $derivedCategory = Get-LpLicenceCategory -LicenseCode ([string](Get-LpProperty -Object $photo -Name 'license' -Default ''))
        if (@('PD', 'CC0', 'CC BY') -notcontains $recordedCategory -or $derivedCategory -ne $recordedCategory) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message "licence '$($photo.licenseShortName)' (code '$($photo.license)', category '$recordedCategory') is outside the policy (public domain, CC0, CC BY) or does not match its Commons code: fetch it again"))
        }
        if ($recordedCategory -eq 'PD' -and [string](Get-LpProperty -Object $photo -Name 'publicDomainReason' -Default '') -notmatch '^PD-[^,]+(, PD-[^,]+)*$') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message 'public domain without the reason Commons gives (a PD- licence template): fetch it again'))
        }
        if ($recordedCategory -eq 'CC BY' -and (-not (Test-LpNamedAuthor -Author ([string]$photo.author)) -or [string]$photo.licenseUrl -notmatch '^https?://creativecommons\.org/licenses/by/')) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message 'CC BY needs a named author and the Creative Commons BY licence URL for the credit'))
        }
        if ([string]$photo.commonsTitle -notmatch '^File:' -or [string]$photo.pageUrl -notmatch '^https://commons\.wikimedia\.org/wiki/File:') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message 'not a Wikimedia Commons file page: photos come only through build.ps1 -FetchPhoto'))
        }
        if (-not (Test-LpCommonsDownloadUrl -Url ([string]$photo.downloadUrl))) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message "download URL '$($photo.downloadUrl)' is not on Wikimedia's upload servers"))
        }
        foreach ($requiredField in @('licenseShortName', 'downloadSha256', 'fetched')) {
            if (-not [string](Get-LpProperty -Object $photo -Name $requiredField -Default '')) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message "no ${requiredField}: photos come only through build.ps1 -FetchPhoto"))
            }
        }
        if ([string]$photo.downloadSha256 -and [string]$photo.downloadSha256 -notmatch '^[0-9a-f]{64}$') {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message 'downloadSha256 is not a SHA-256: photos come only through build.ps1 -FetchPhoto'))
        }
        $shorterSide = [Math]::Min([int](Get-LpProperty -Object $photo -Name 'width' -Default 0), [int](Get-LpProperty -Object $photo -Name 'height' -Default 0))
        if ($shorterSide -lt 300) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message "the original is $($photo.width)x$($photo.height); a portrait source needs at least 300 px on its shorter side"))
        }
        $publicDomainReasons = @(([string](Get-LpProperty -Object $photo -Name 'publicDomainReason' -Default '')) -split ',\s*' | Where-Object { $_ })
        if ($recordedCategory -eq 'PD' -and $publicDomainReasons.Count -gt 0 -and @($publicDomainReasons | Where-Object { $_ -notmatch '^PD-US' }).Count -eq 0) {
            $problems.Add((New-LpProblem -Level 'WARN' -Where $photoWhere -Message "public domain in the United States only ($($publicDomainReasons -join ', ')); the owner decides before a release"))
        }
        if ($photo.downloadSha256 -and (Test-LpCommonsDownloadUrl -Url ([string]$photo.downloadUrl))) {
            $cachePath = Get-LpCacheFilePath -Pack $Pack -Photo $photo
            if ((Test-Path -LiteralPath $cachePath) -and (Get-LpSha256 -Path $cachePath) -ne [string]$photo.downloadSha256) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message 'the downloaded file in sources-cache does not match the SHA-256 recorded at fetch time'))
            }
        }
        if ([string](Get-LpProperty -Object $photo -Name 'restrictions' -Default '')) {
            $problems.Add((New-LpProblem -Level 'WARN' -Where $photoWhere -Message "Commons lists restrictions: $($photo.restrictions); the owner reviews it before a release"))
        }
        if ($usedPhotoKeys -notcontains [string]$photo.key) {
            $problems.Add((New-LpProblem -Level 'WARN' -Where $photoWhere -Message 'no leader uses this photo'))
        }
    }
    return $problems.ToArray()
}

function Get-LpPortraitEntry {
    param($Pack, [string]$LeaderKey)

    $leaderEntries = Get-LpProperty -Object $Pack.PortraitRecords -Name 'leaders'
    return (Get-LpProperty -Object $leaderEntries -Name $LeaderKey)
}

function Get-LpRoundSeeds {
    param([Parameter(Mandatory = $true)][int]$Round)

    return @((4 * $Round - 3)..(4 * $Round))
}

function Get-LpChosenRelativePath {
    param($Pack, [string]$LeaderKey)

    return 'source/' + $Pack.Name + '/portraits/' + $LeaderKey + '.png'
}

function Test-LpPortraitRecords {
    param($Pack)

    $problems = [System.Collections.Generic.List[PSObject]]::new()
    $recordsWhere = 'source/' + $Pack.Name + '/portraits.json'
    $leaderKeys = @($Pack.Leaders | ForEach-Object { [string]$_.key })
    $chosenFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $leaderEntries = Get-LpProperty -Object $Pack.PortraitRecords -Name 'leaders'
    if ($null -ne $leaderEntries) {
        foreach ($entryProperty in @($leaderEntries.PSObject.Properties)) {
            $leaderKey = $entryProperty.Name
            $entry = $entryProperty.Value
            $entryWhere = $recordsWhere + ' ' + $leaderKey
            if ($leaderKeys -notcontains $leaderKey) {
                $problems.Add((New-LpProblem -Level 'WARN' -Where $entryWhere -Message 'no leader of leaders.json has this key'))
            }
            $rounds = @(ConvertTo-LpArray (Get-LpProperty -Object $entry -Name 'rounds'))
            for ($roundIndex = 0; $roundIndex -lt $rounds.Count; $roundIndex++) {
                $roundRecord = $rounds[$roundIndex]
                $roundNumber = $roundIndex + 1
                $roundWhere = $entryWhere + ' round ' + $roundNumber
                if ((Get-LpWholeNumber -Value (Get-LpProperty -Object $roundRecord -Name 'round')) -ne $roundNumber) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $roundWhere -Message 'rounds are not numbered 1, 2, 3 in order'))
                }
                $seeds = @(ConvertTo-LpArray (Get-LpProperty -Object $roundRecord -Name 'seeds') | ForEach-Object { Get-LpWholeNumber -Value $_ })
                if (($seeds -join ',') -ne ((Get-LpRoundSeeds -Round $roundNumber) -join ',')) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $roundWhere -Message "seeds $($seeds -join ',') are not $((Get-LpRoundSeeds -Round $roundNumber) -join ',')"))
                }
                $candidateSeeds = @(ConvertTo-LpArray (Get-LpProperty -Object $roundRecord -Name 'candidates') | ForEach-Object { Get-LpWholeNumber -Value $_.seed })
                foreach ($candidateSeed in $candidateSeeds) {
                    if ($seeds -notcontains $candidateSeed) {
                        $problems.Add((New-LpProblem -Level 'ERROR' -Where $roundWhere -Message "candidate seed $candidateSeed is not a seed of the round"))
                    }
                }
                $decision = Get-LpProperty -Object $roundRecord -Name 'decision'
                if ($null -eq $decision) {
                    if ($roundNumber -lt $rounds.Count) {
                        $problems.Add((New-LpProblem -Level 'ERROR' -Where $roundWhere -Message 'has no decision, but a later round exists'))
                    }
                    continue
                }
                $pickedSeed = Get-LpProperty -Object $decision -Name 'pick'
                $rejectReason = [string](Get-LpProperty -Object $decision -Name 'reject' -Default '')
                if ($null -ne $pickedSeed) {
                    if ($candidateSeeds -notcontains (Get-LpWholeNumber -Value $pickedSeed)) {
                        $problems.Add((New-LpProblem -Level 'ERROR' -Where $roundWhere -Message "the pick $pickedSeed is not a candidate of the round"))
                    }
                } elseif (-not $rejectReason.Trim()) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $roundWhere -Message 'the decision is neither a pick nor a rejection with a reason'))
                }
            }
            $chosen = Get-LpProperty -Object $entry -Name 'chosen'
            if ($null -eq $chosen) {
                continue
            }
            $expectedFile = Get-LpChosenRelativePath -Pack $Pack -LeaderKey $leaderKey
            if ([string](Get-LpProperty -Object $chosen -Name 'file' -Default '') -ne $expectedFile) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $entryWhere -Message "the chosen file must be $expectedFile"))
            }
            [void]$chosenFiles.Add($expectedFile)
            $chosenPath = Join-Path $Pack.RepoRoot $expectedFile.Replace('/', '\')
            if (-not (Test-Path -LiteralPath $chosenPath)) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $entryWhere -Message "the chosen portrait $expectedFile is missing"))
            } elseif ((Get-LpSha256 -Path $chosenPath) -ne [string](Get-LpProperty -Object $chosen -Name 'sha256' -Default '')) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $entryWhere -Message "the SHA-256 of $expectedFile differs from the one recorded when it was chosen: pick it again with build.ps1 -ApplyPortraitReview"))
            }
            $chosenRound = Get-LpWholeNumber -Value (Get-LpProperty -Object $chosen -Name 'round')
            $chosenSeed = Get-LpWholeNumber -Value (Get-LpProperty -Object $chosen -Name 'seed')
            $pickRound = if ($null -ne $chosenRound -and $chosenRound -ge 1 -and $chosenRound -le $rounds.Count) { $rounds[$chosenRound - 1] } else { $null }
            $pickDecision = Get-LpProperty -Object $pickRound -Name 'decision'
            if ($null -eq $pickRound -or (Get-LpWholeNumber -Value (Get-LpProperty -Object $pickDecision -Name 'pick')) -ne $chosenSeed) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $entryWhere -Message "the chosen portrait (round $chosenRound, seed $chosenSeed) is not the pick recorded in that round"))
            } else {
                $pickedCandidate = @(ConvertTo-LpArray (Get-LpProperty -Object $pickRound -Name 'candidates') | Where-Object { (Get-LpWholeNumber -Value $_.seed) -eq $chosenSeed }) | Select-Object -First 1
                if ($null -eq $pickedCandidate -or [string]$pickedCandidate.sha256 -ne [string](Get-LpProperty -Object $chosen -Name 'sha256' -Default '')) {
                    $problems.Add((New-LpProblem -Level 'ERROR' -Where $entryWhere -Message 'the chosen portrait is not the candidate recorded in its round (SHA-256)'))
                }
            }
        }
    }
    if (Test-Path -LiteralPath $Pack.PortraitDir) {
        foreach ($portraitFile in @(Get-ChildItem -LiteralPath $Pack.PortraitDir -File -Force)) {
            $relativePath = 'source/' + $Pack.Name + '/portraits/' + $portraitFile.Name
            if (-not $chosenFiles.Contains($relativePath)) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $relativePath -Message 'is no chosen portrait of portraits.json: remove it'))
            }
        }
    }
    return $problems.ToArray()
}

function Get-LpDdsSize {
    param([Parameter(Mandatory = $true)][string]$Path)

    $headerBytes = New-Object byte[] 20
    $fileStream = [System.IO.File]::OpenRead($Path)
    try {
        [void]$fileStream.Read($headerBytes, 0, 20)
    } finally {
        $fileStream.Dispose()
    }
    if ([System.Text.Encoding]::ASCII.GetString($headerBytes, 0, 4) -ne 'DDS ') {
        return $null
    }
    return [PSCustomObject]@{ Height = [System.BitConverter]::ToInt32($headerBytes, 12); Width = [System.BitConverter]::ToInt32($headerBytes, 16) }
}

function Get-LpCardSha {
    param($Pack)

    $cardPath = Join-Path $Pack.DataDir 'portrait-card.json'
    if (-not (Test-Path -LiteralPath $cardPath)) {
        return ''
    }
    $cardText = [System.IO.File]::ReadAllText($cardPath, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash((Get-LpUtf8).GetBytes($cardText))
    } finally {
        $sha.Dispose()
    }
    return (-join @($hashBytes | ForEach-Object { $_.ToString('x2') }))
}

function Get-LpConversionPaths {
    param($Pack)

    $portraitEntries = Get-LpProperty -Object $Pack.ConversionRecord -Name 'portraits'
    if ($null -eq $portraitEntries) {
        return @()
    }
    return @($portraitEntries.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-LpConversionEntry {
    param($Pack, [string]$RelativePath)

    return (Get-LpProperty -Object (Get-LpProperty -Object $Pack.ConversionRecord -Name 'portraits') -Name $RelativePath)
}

function Get-LpExpectedPortraitFiles {
    param($Pack)

    $expectedFiles = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack)) {
        $expectedFiles.Add([PSCustomObject]@{ Leader = $leader; Kind = 'large'; RelativePath = (Get-LpLargeRelativePath -Pack $Pack -Leader $leader); Width = 156; Height = 210 })
        if ((Get-LpMode -Leader $leader) -eq 'new') {
            $expectedFiles.Add([PSCustomObject]@{ Leader = $leader; Kind = 'small'; RelativePath = (Get-LpSmallRelativePath -Pack $Pack -Leader $leader); Width = 65; Height = 67 })
        }
    }
    return $expectedFiles.ToArray()
}

function Get-LpOtherPrefixes {
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [string]$Pack)

    return @(Get-LpPackNames -RepoRoot $RepoRoot | Where-Object { $_ -ne $Pack } | ForEach-Object {
            $otherLeadersPath = Join-Path $RepoRoot ('source\' + $_ + '\leaders.json')
            if (Test-Path -LiteralPath $otherLeadersPath) { [string](Get-LpProperty -Object (Read-LpJson -Path $otherLeadersPath) -Name 'prefix' -Default '') }
        } | Where-Object { $_ })
}

function Test-LpPack {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack
    )

    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $problems = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($sourceProblem in @(Test-LpPackSource -Pack $packData)) {
        $problems.Add($sourceProblem)
    }
    foreach ($recordProblem in @(Test-LpPortraitRecords -Pack $packData)) {
        $problems.Add($recordProblem)
    }
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $packData)) {
        $leaderWhere = 'leader ' + [string]$leader.key
        $photoKey = Get-LpLeaderPhotoKey -Leader $leader
        if ($photoKey -and $null -eq (Get-LpPhotoByKey -Pack $packData -PhotoKey $photoKey)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message "photo '$photoKey' is not in source/$Pack/photos.json: fetch it with build.ps1 -FetchPhoto"))
        }
        if ($null -eq (Get-LpProperty -Object (Get-LpPortraitEntry -Pack $packData -LeaderKey ([string]$leader.key)) -Name 'chosen')) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $leaderWhere -Message 'no chosen portrait: build.ps1 -MakePortraits, the owner''s review, then -ApplyPortraitReview'))
        }
    }
    foreach ($expectedFile in (Get-LpExpectedPortraitFiles -Pack $packData)) {
        $ddsPath = Join-Path $packData.PackRoot $expectedFile.RelativePath.Replace('/', '\')
        $fileWhere = 'packs/' + $Pack + '/' + $expectedFile.RelativePath
        if (-not (Test-Path -LiteralPath $ddsPath)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $fileWhere -Message "no $($expectedFile.Kind) portrait in the pack: run build.ps1 -ConvertPortraits"))
            continue
        }
        $ddsSize = Get-LpDdsSize -Path $ddsPath
        if ($null -eq $ddsSize -or $ddsSize.Width -ne $expectedFile.Width -or $ddsSize.Height -ne $expectedFile.Height) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $fileWhere -Message "the DDS is not $($expectedFile.Width)x$($expectedFile.Height)"))
        }
        $conversionEntry = Get-LpConversionEntry -Pack $packData -RelativePath $expectedFile.RelativePath
        if ($null -eq $conversionEntry) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $fileWhere -Message "has no record in source/$Pack/converted.json: run build.ps1 -ConvertPortraits"))
            continue
        }
        if ([string](Get-LpProperty -Object $conversionEntry -Name 'ddsSha256' -Default '') -ne (Get-LpSha256 -Path $ddsPath)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $fileWhere -Message 'differs from the DDS build.ps1 -ConvertPortraits wrote (SHA-256 in converted.json): run build.ps1 -ConvertPortraits -Force'))
        }
        $chosen = Get-LpProperty -Object (Get-LpPortraitEntry -Pack $packData -LeaderKey ([string]$expectedFile.Leader.key)) -Name 'chosen'
        if ($null -ne $chosen -and [string](Get-LpProperty -Object $conversionEntry -Name 'chosenSha256' -Default '') -ne [string]$chosen.sha256) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $fileWhere -Message 'was built from another chosen portrait than the one in portraits.json: run build.ps1 -ConvertPortraits'))
        }
        if ($expectedFile.Kind -eq 'small' -and [string](Get-LpProperty -Object $conversionEntry -Name 'cardSha256' -Default '') -ne (Get-LpCardSha -Pack $packData)) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $fileWhere -Message 'was built with another data/portrait-card.json: run build.ps1 -ConvertPortraits'))
        }
    }
    $expectedRelativePaths = @(Get-LpExpectedPortraitFiles -Pack $packData | ForEach-Object { $_.RelativePath })
    foreach ($recordedPath in @(Get-LpConversionPaths -Pack $packData)) {
        if ($expectedRelativePaths -notcontains $recordedPath) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where "source/$Pack/converted.json" -Message "records $recordedPath, which no leader has: run build.ps1 -ConvertPortraits"))
        }
    }
    $delta = Get-LpGenerationDelta -Pack $packData
    foreach ($changedPath in $delta.Changed) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where $changedPath -Message 'differs from what the source generates: run build.ps1 -Generate (never edit it by hand)'))
    }
    foreach ($stalePath in $delta.Stale) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where $stalePath -Message 'not generated from the source: run build.ps1 -Generate to remove it'))
    }
    $packPrefix = 'packs/' + $Pack + '/'
    $knownPackFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($knownPath in @(@($delta.Files.Keys) + @($delta.Stale) + @(($packPrefix + 'descriptor.mod'), ($packPrefix + 'thumbnail.png')))) {
        [void]$knownPackFiles.Add([string]$knownPath)
    }
    foreach ($expectedFile in (Get-LpExpectedPortraitFiles -Pack $packData)) {
        [void]$knownPackFiles.Add($packPrefix + $expectedFile.RelativePath)
    }
    if (Test-Path -LiteralPath $packData.PackRoot) {
        foreach ($packFile in @(Get-ChildItem -LiteralPath $packData.PackRoot -Recurse -File -Force)) {
            $packRelativePath = $packPrefix + $packFile.FullName.Substring($packData.PackRoot.Length + 1).Replace('\', '/')
            if (-not $knownPackFiles.Contains($packRelativePath)) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $packRelativePath -Message 'is not generated from the source nor a portrait of a leader, so it would ship unchecked: remove it (build.ps1 -ConvertPortraits removes unused portraits)'))
            }
        }
    }
    $otherPrefixes = @(Get-LpOtherPrefixes -RepoRoot $RepoRoot -Pack $Pack)
    if ($otherPrefixes -contains $packData.Prefix) {
        $problems.Add((New-LpProblem -Level 'ERROR' -Where "source/$Pack/leaders.json" -Message "prefix '$($packData.Prefix)' is used by another pack"))
    }
    foreach ($relativePath in @($delta.Files.Keys | Where-Object { $_ -like 'packs/*' })) {
        foreach ($otherPrefix in $otherPrefixes) {
            if ($otherPrefix -ne $packData.Prefix -and [regex]::IsMatch($delta.Files[$relativePath].Text, '\b' + [regex]::Escape($otherPrefix) + '_')) {
                $problems.Add((New-LpProblem -Level 'ERROR' -Where $relativePath -Message "names '$otherPrefix' of another pack: every pack stands alone"))
            }
        }
    }
    return $problems.ToArray()
}

function Invoke-LpCheck {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string[]]$Pack
    )

    $packNames = if ($Pack) { @($Pack) } else { @(Get-LpPackNames -RepoRoot $RepoRoot) }
    $errorCount = 0
    $warningCount = 0
    foreach ($packName in $packNames) {
        $problems = @(Test-LpPack -RepoRoot $RepoRoot -Pack $packName)
        Write-LpProblems -Problems $problems
        $packErrors = @($problems | Where-Object { $_.Level -eq 'ERROR' }).Count
        $errorCount += $packErrors
        $warningCount += @($problems | Where-Object { $_.Level -eq 'WARN' }).Count
        $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $packName
        Write-Host ("Pack '{0}': {1} leader(s), {2} photo(s), {3} error(s)" -f $packName, $packData.Leaders.Count, $packData.Photos.Count, $packErrors) -ForegroundColor $(if ($packErrors -gt 0) { 'Red' } else { 'Green' })
    }
    if ($errorCount -gt 0) {
        Write-Host "Check FAILED: $errorCount error(s), $warningCount warning(s)." -ForegroundColor Red
        return 1
    }
    Write-Host "Check OK: $($packNames.Count) pack(s), $warningCount warning(s)." -ForegroundColor Green
    return 0
}

function Get-LpPortraitState {
    param($Pack, $Leader)

    $entry = Get-LpPortraitEntry -Pack $Pack -LeaderKey ([string]$Leader.key)
    $chosen = Get-LpProperty -Object $entry -Name 'chosen'
    if ($null -ne $chosen) {
        return 'chosen (round ' + $chosen.round + ', seed ' + $chosen.seed + ')'
    }
    $rounds = @(ConvertTo-LpArray (Get-LpProperty -Object $entry -Name 'rounds'))
    if ($rounds.Count -eq 0) {
        return 'no round yet'
    }
    $lastDecision = Get-LpProperty -Object $rounds[-1] -Name 'decision'
    if ($null -eq $lastDecision) {
        return 'round ' + $rounds.Count + ' waits for review'
    }
    return 'round ' + $rounds.Count + ' rejected'
}

function Invoke-LpAudit {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack
    )

    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $problems = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($packProblem in @(Test-LpPack -RepoRoot $RepoRoot -Pack $Pack)) {
        $problems.Add($packProblem)
    }
    Write-Host "Audit of pack '$Pack' ($($packData.Tag), prefix $($packData.Prefix))" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '| Leader | Mode | Role | Character | Skills | Traits | Photo licence | Portrait |'
    Write-Host '|---|---|---|---|---|---|---|---|'
    foreach ($leader in $packData.Leaders) {
        $mode = Get-LpMode -Leader $leader
        if ($mode -eq 'skip') {
            Write-Host ('| {0} | skip | - | - | - | - | - | {1} |' -f $leader.name, (Get-LpProperty -Object $leader -Name 'reason' -Default ''))
            continue
        }
        $skills = @(Get-LpStatNames -Pack $packData -Role ([string]$leader.role) | ForEach-Object { [string](Get-LpProperty -Object $leader -Name $_ -Default '?') }) -join '/'
        $photo = Get-LpPhotoByKey -Pack $packData -PhotoKey (Get-LpLeaderPhotoKey -Leader $leader)
        $licence = if ($null -ne $photo) { Get-LpLicenceLabel -Photo $photo } else { 'missing' }
        Write-Host ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |' -f $leader.name, $mode, (Get-LpRoleTitle -Role ([string]$leader.role)), (Get-LpCharacterId -Pack $packData -Leader $leader), $skills, ((Get-LpTraits -Leader $leader) -join ' '), $licence, (Get-LpPortraitState -Pack $packData -Leader $leader))
    }
    Write-Host ''
    $refreshCutoff = (Get-Date).AddDays(-180).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    foreach ($photo in $packData.Photos) {
        $photoWhere = 'photo ' + [string]$photo.key
        if ([string]$photo.fetched -and [string]$photo.fetched -lt $refreshCutoff) {
            $problems.Add((New-LpProblem -Level 'WARN' -Where $photoWhere -Message "licence recorded from Commons on $($photo.fetched), over 180 days ago: fetch it again with build.ps1 -FetchPhoto"))
        }
        try {
            $response = Invoke-RestMethod -Uri (Get-LpCommonsQueryUrl -FileTitle ([string]$photo.commonsTitle)) -Headers (Get-LpWebHeaders) -UseBasicParsing
        } catch {
            $problems.Add((New-LpProblem -Level 'WARN' -Where $photoWhere -Message "Commons could not be read: $($_.Exception.Message)"))
            continue
        }
        $verdict = Get-LpCommonsVerdict -Response $response
        if (-not $verdict.Accepted) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message "Commons now refuses it: $($verdict.Reason)"))
            continue
        }
        if ([string]$verdict.Photo.license -ne [string]$photo.license -or [string]$verdict.Photo.licenseCategory -ne [string]$photo.licenseCategory) {
            $problems.Add((New-LpProblem -Level 'ERROR' -Where $photoWhere -Message "the licence on Commons is now '$($verdict.Photo.licenseShortName)' ($($verdict.Photo.license)), recorded '$($photo.licenseShortName)' ($($photo.license)): fetch it again"))
        } elseif ([string]$verdict.Photo.author -ne [string]$photo.author) {
            $problems.Add((New-LpProblem -Level 'WARN' -Where $photoWhere -Message "the author on Commons is now '$($verdict.Photo.author)', recorded '$($photo.author)': fetch it again"))
        } else {
            Write-Host "  $photoWhere : Commons still gives $($verdict.Reason)" -ForegroundColor Gray
        }
    }
    Write-Host ''
    Write-LpProblems -Problems $problems
    $errorCount = @($problems | Where-Object { $_.Level -eq 'ERROR' }).Count
    Write-Host ("Audit: {0} error(s), {1} warning(s)" -f $errorCount, @($problems | Where-Object { $_.Level -eq 'WARN' }).Count) -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
    return $(if ($errorCount -gt 0) { 1 } else { 0 })
}

function Get-LpCommonsDeletionTemplates {
    return @('Template:Delete', 'Template:Speedydelete', 'Template:Copyvio', 'Template:No license since', 'Template:No permission since', 'Template:No source since', 'Template:Dw no source since', 'Template:Npd', 'Template:Disputed', 'Template:Disputed copyright')
}

function Get-LpLicenceCategory {
    param([AllowEmptyString()][string]$LicenseCode)

    $normalizedCode = ([string]$LicenseCode).ToLowerInvariant()
    if ($normalizedCode -match '^(pd|public domain)') {
        return 'PD'
    }
    if ($normalizedCode -match '^(cc0|cc-zero)') {
        return 'CC0'
    }
    if ($normalizedCode -match '^cc-by-\d') {
        return 'CC BY'
    }
    return ''
}

function Test-LpNamedAuthor {
    param([AllowEmptyString()][string]$Author)

    return ([bool]([string]$Author).Trim() -and $Author -notmatch '^(unknown|anonymous|unknown author|author unknown)$')
}

function Test-LpCommonsDownloadUrl {
    param([AllowEmptyString()][string]$Url)

    return ([string]$Url -match '^https://(upload|thumb)\.wikimedia\.org/wikipedia/commons/')
}

function Get-LpCommonsQueryUrl {
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

function ConvertFrom-LpHtml {
    param([AllowEmptyString()][string]$Html)

    $visibleHtml = [regex]::Replace([string]$Html, '(?is)<(\w+)[^>]*display:\s*none[^>]*>.*?</\1>', '')
    $plainText = [regex]::Replace($visibleHtml, '<[^>]+>', '')
    return ([System.Net.WebUtility]::HtmlDecode($plainText) -replace '\s+', ' ').Trim()
}

function Get-LpCommonsVerdict {
    param([Parameter(Mandatory = $true)]$Response)

    $page = @(ConvertTo-LpArray (Get-LpProperty -Object (Get-LpProperty -Object $Response -Name 'query') -Name 'pages')) | Select-Object -First 1
    if ($null -eq $page -or (Get-LpProperty -Object $page -Name 'missing' -Default $false) -or $null -eq (Get-LpProperty -Object $page -Name 'imageinfo')) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'no such file on Wikimedia Commons'; Photo = $null }
    }
    $imageInfo = @($page.imageinfo)[0]
    $metadata = $imageInfo.extmetadata
    $licenseCode = ([string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'License') -Name 'value' -Default '')).ToLowerInvariant()
    $licenseShortName = ConvertFrom-LpHtml ([string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'LicenseShortName') -Name 'value' -Default ''))
    $licenseCategory = Get-LpLicenceCategory -LicenseCode $licenseCode
    $photo = [PSCustomObject][ordered]@{
        key                = ''
        commonsTitle       = [string]$page.title
        pageUrl            = [string]$imageInfo.descriptionurl
        downloadUrl        = [string](Get-LpProperty -Object $imageInfo -Name 'thumburl' -Default $imageInfo.url)
        downloadSha256     = ''
        author             = ConvertFrom-LpHtml ([string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'Artist') -Name 'value' -Default ''))
        credit             = ConvertFrom-LpHtml ([string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'Credit') -Name 'value' -Default ''))
        licenseShortName   = $licenseShortName
        license            = $licenseCode
        licenseCategory    = $(if ($licenseCategory) { $licenseCategory } else { '' })
        licenseUrl         = [string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'LicenseUrl') -Name 'value' -Default '')
        usageTerms         = ConvertFrom-LpHtml ([string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'UsageTerms') -Name 'value' -Default ''))
        restrictions       = [string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'Restrictions') -Name 'value' -Default '')
        dateOriginal       = ConvertFrom-LpHtml ([string](Get-LpProperty -Object (Get-LpProperty -Object $metadata -Name 'DateTimeOriginal') -Name 'value' -Default ''))
        width              = [int]$imageInfo.width
        height             = [int]$imageInfo.height
        fetched            = ''
        publicDomainReason = ''
    }
    $pageTemplates = @(ConvertTo-LpArray (Get-LpProperty -Object $page -Name 'templates') | ForEach-Object { [string]$_.title })
    $deletionTemplates = @($pageTemplates | Where-Object { (Get-LpCommonsDeletionTemplates) -contains $_ })
    $photo.publicDomainReason = (@($pageTemplates | Where-Object { $_ -match '^Template:PD-[^/]+$' -and $_ -ne 'Template:PD-Layout' } | ForEach-Object { $_.Substring(9) }) -join ', ')
    if ($deletionTemplates.Count -gt 0) {
        return [PSCustomObject]@{ Accepted = $false; Reason = ('tagged on Commons: ' + ($deletionTemplates -join ', ')); Photo = $photo }
    }
    if ($licenseCategory -eq 'PD' -and -not $photo.publicDomainReason) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'public domain without a PD- licence template on Commons that states why'; Photo = $photo }
    }
    if (-not $licenseCategory) {
        return [PSCustomObject]@{ Accepted = $false; Reason = "licence '$licenseShortName' ($licenseCode) is outside the policy: public domain, CC0 or CC BY only"; Photo = $photo }
    }
    if ($licenseCategory -eq 'CC BY' -and -not (Test-LpNamedAuthor -Author $photo.author)) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'CC BY without a named author on Commons: the credit cannot be written'; Photo = $photo }
    }
    if ([string](Get-LpProperty -Object $imageInfo -Name 'mime' -Default '') -notmatch '^image/(jpeg|png|tiff|gif|webp)$') {
        return [PSCustomObject]@{ Accepted = $false; Reason = "file type '$($imageInfo.mime)' is not a picture"; Photo = $photo }
    }
    if (-not (Test-LpCommonsDownloadUrl -Url $photo.downloadUrl)) {
        return [PSCustomObject]@{ Accepted = $false; Reason = "download URL '$($photo.downloadUrl)' is not on Wikimedia's upload servers"; Photo = $photo }
    }
    if ([Math]::Min($photo.width, $photo.height) -lt 300) {
        return [PSCustomObject]@{ Accepted = $false; Reason = "$($photo.width)x$($photo.height) is under 300 px on its shorter side, too small for a portrait source"; Photo = $photo }
    }
    return [PSCustomObject]@{ Accepted = $true; Reason = "$licenseCategory ($licenseShortName)"; Photo = $photo }
}

function Get-LpWebHeaders {
    return @{ 'User-Agent' = 'LeaderPacksModTools/1.0 (Hearts of Iron IV mod build tool; one request per photo)' }
}

function Get-LpCacheFilePath {
    param($Pack, $Photo)

    $extension = [System.IO.Path]::GetExtension(([uri][string]$Photo.downloadUrl).AbsolutePath)
    if (-not $extension) {
        $extension = '.jpg'
    }
    return (Join-Path $Pack.CacheDir ([string]$Photo.key + $extension.ToLowerInvariant()))
}

function Save-LpPhotos {
    param($Pack, [Parameter(Mandatory = $true)][AllowEmptyCollection()]$Photos)

    $sortedPhotos = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($photo in @($Photos | Sort-Object { [string]$_.key })) {
        $sortedPhotos.Add($photo)
    }
    Write-LpJson -Path (Join-Path $Pack.SourceDir 'photos.json') -Value ([PSCustomObject]@{ photos = @($sortedPhotos) }) -Depth 5
}

function Invoke-LpFetchPhoto {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Key,
        [switch]$DryRun
    )

    if ($Key -cnotmatch '^[a-z0-9_]+$') {
        Write-Host "-Key '$Key' must be lower-case letters, digits and underscores" -ForegroundColor Red
        return 1
    }
    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $fileTitle = if ($File -like 'File:*') { $File } else { 'File:' + $File }
    $response = Invoke-RestMethod -Uri (Get-LpCommonsQueryUrl -FileTitle $fileTitle) -Headers (Get-LpWebHeaders) -UseBasicParsing
    $verdict = Get-LpCommonsVerdict -Response $response
    if (-not $verdict.Accepted) {
        Write-Host "REJECTED $fileTitle : $($verdict.Reason)" -ForegroundColor Red
        return 1
    }
    $photo = $verdict.Photo
    $photo.key = $Key
    $photo.fetched = Get-LpToday
    Write-Host "ACCEPTED $fileTitle : $($verdict.Reason), $($photo.width)x$($photo.height), author: $(if ($photo.author) { $photo.author } else { 'not given' })" -ForegroundColor Green
    if ($photo.restrictions) {
        Write-Host "  Commons lists restrictions: $($photo.restrictions)" -ForegroundColor Yellow
    }
    if ($DryRun) {
        Write-Host '  Dry run: nothing downloaded or recorded.' -ForegroundColor Gray
        return 0
    }
    $cachePath = Get-LpCacheFilePath -Pack $packData -Photo $photo
    if (-not (Test-Path -LiteralPath $packData.CacheDir)) {
        New-Item -ItemType Directory -Path $packData.CacheDir -Force | Out-Null
    }
    Invoke-WebRequest -Uri $photo.downloadUrl -Headers (Get-LpWebHeaders) -OutFile $cachePath -UseBasicParsing
    $photo.downloadSha256 = Get-LpSha256 -Path $cachePath
    $keptPhotos = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($existingPhoto in $packData.Photos) {
        if ([string]$existingPhoto.key -ne $Key) {
            $keptPhotos.Add($existingPhoto)
        }
    }
    $keptPhotos.Add($photo)
    Save-LpPhotos -Pack $packData -Photos $keptPhotos
    Write-Host "  recorded '$Key' in source\$Pack\photos.json; downloaded to $cachePath" -ForegroundColor Gray
    return 0
}

function Get-LpCachedPhoto {
    param($Pack, $Photo)

    if (-not (Test-LpCommonsDownloadUrl -Url ([string]$Photo.downloadUrl))) {
        throw "photo '$($Photo.key)' has a download URL outside Wikimedia's upload servers: fetch it again with build.ps1 -FetchPhoto"
    }
    $cachePath = Get-LpCacheFilePath -Pack $Pack -Photo $Photo
    if (-not (Test-Path -LiteralPath $cachePath)) {
        if (-not (Test-Path -LiteralPath $Pack.CacheDir)) {
            New-Item -ItemType Directory -Path $Pack.CacheDir -Force | Out-Null
        }
        Invoke-WebRequest -Uri ([string]$Photo.downloadUrl) -Headers (Get-LpWebHeaders) -OutFile $cachePath -UseBasicParsing
    }
    if ((Get-LpSha256 -Path $cachePath) -ne [string]$Photo.downloadSha256) {
        throw "photo '$($Photo.key)': $cachePath does not match the SHA-256 recorded at fetch time; fetch it again with build.ps1 -FetchPhoto"
    }
    return $cachePath
}

function Get-LpManagerRoot {
    if (-not (Get-Command -Name 'Get-ModManagerRoot' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'HoiModBuild.ps1')
    }
    return (Get-ModManagerRoot)
}

function Get-LpComfyConfig {
    param([AllowEmptyString()][string]$ManagerRoot)

    $configPath = if ($env:HOI_COMFYUI_CONFIG) { $env:HOI_COMFYUI_CONFIG } elseif ($ManagerRoot) { Join-Path $ManagerRoot 'Config\comfyui.json' } else { '' }
    if (-not $configPath -or -not (Test-Path -LiteralPath $configPath)) {
        return $null
    }
    $config = Read-LpJson -Path $configPath
    $pythonPath = [string](Get-LpProperty -Object $config -Name 'python' -Default '')
    if (-not $pythonPath -or -not (Test-Path -LiteralPath $pythonPath)) {
        return $null
    }
    return $config
}

function Read-LpPortraitRecords {
    param($Pack)

    $records = ConvertTo-LpOrdered -Value $Pack.PortraitRecords
    if ($null -eq $records) {
        $records = [ordered]@{}
    }
    if (-not $records.Contains('leaders') -or $null -eq $records['leaders']) {
        $records['leaders'] = [ordered]@{}
    }
    return $records
}

function Save-LpPortraitRecords {
    param($Pack, [Parameter(Mandatory = $true)]$Records)

    $sortedLeaders = [ordered]@{}
    foreach ($leaderKey in @($Records['leaders'].Keys | Sort-Object)) {
        $sortedLeaders[$leaderKey] = $Records['leaders'][$leaderKey]
    }
    Write-LpJson -Path (Join-Path $Pack.SourceDir 'portraits.json') -Value ([ordered]@{ leaders = $sortedLeaders }) -Depth 12
}

function Get-LpRecordRounds {
    param($Entry)

    $rounds = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $Entry -and $Entry.Contains('rounds')) {
        foreach ($roundRecord in @(ConvertTo-LpArray $Entry['rounds'])) {
            $rounds.Add($roundRecord)
        }
    }
    return , $rounds
}

function Test-LpColourSeedValue {
    param($Value)

    return (($Value -is [int] -or $Value -is [long]) -and $Value -ge 0 -and $Value -le [int]::MaxValue)
}

function Get-LpPortraitOptionProblems {
    param($Portrait)

    $messages = [System.Collections.Generic.List[string]]::new()
    $colourSeed = Get-LpProperty -Object $Portrait -Name 'colourSeed'
    if ($null -ne $colourSeed -and -not (Test-LpColourSeedValue -Value $colourSeed)) {
        $messages.Add('portrait.colourSeed must be a whole number from 0 up')
    }
    $facePass = Get-LpProperty -Object $Portrait -Name 'facePass'
    if ($null -ne $facePass -and $facePass -isnot [bool]) {
        $messages.Add('portrait.facePass must be true or false')
    }
    return , $messages
}

function Get-LpPortraitSettings {
    param($Leader)

    $portrait = Get-LpProperty -Object $Leader -Name 'portrait'
    $settings = [ordered]@{}
    foreach ($fieldName in @('role', 'headwear', 'uniform', 'avoidHeadwear', 'notes')) {
        $settings[$fieldName] = [string](Get-LpProperty -Object $portrait -Name $fieldName -Default '')
    }
    $colourSeed = Get-LpProperty -Object $portrait -Name 'colourSeed'
    $settings['colourSeed'] = $(if (Test-LpColourSeedValue -Value $colourSeed) { [int]$colourSeed } else { 1 })
    $facePass = Get-LpProperty -Object $portrait -Name 'facePass'
    $settings['facePass'] = $(if ($facePass -is [bool]) { $facePass } else { $true })
    return $settings
}

function Invoke-LpComfyStatus {
    param([Parameter(Mandatory = $true)][string]$ManagerRoot, [Parameter(Mandatory = $true)][string]$Action)

    $statusScript = Join-Path $ManagerRoot 'Scripts\Portraits\Get-HoiComfyStatus.ps1'
    $powerShellExecutable = if (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $outputLines = @(& $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $statusScript ('-' + $Action) 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    foreach ($outputLine in $outputLines) {
        Write-Host "  $outputLine" -ForegroundColor Gray
    }
    return [PSCustomObject]@{ ExitCode = $exitCode; Lines = $outputLines; Started = (@($outputLines | Where-Object { $_ -like 'ComfyUI started at *' }).Count -gt 0) }
}

function Invoke-LpMakePortraits {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [string]$Leader,
        [switch]$StartComfyUI,
        [AllowEmptyString()][string]$ManagerRoot = (Get-LpManagerRoot)
    )

    if (-not $ManagerRoot -or -not (Test-Path -LiteralPath (Join-Path $ManagerRoot 'Scripts\Portraits\New-HoiPortrait.ps1'))) {
        Write-Host 'The Modding Manager with Scripts\Portraits\New-HoiPortrait.ps1 is not on this machine: portraits are made only where the Manager and its ComfyUI are.' -ForegroundColor Red
        return 1
    }
    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $generatedLeaders = @(Get-LpGeneratedLeaders -Pack $packData)
    if ($Leader) {
        $generatedLeaders = @($generatedLeaders | Where-Object { [string]$_.key -eq $Leader })
        if ($generatedLeaders.Count -eq 0) {
            Write-Host "No new or addRole leader '$Leader' in source\$Pack\leaders.json." -ForegroundColor Red
            return 1
        }
    }
    $records = Read-LpPortraitRecords -Pack $packData
    $openLeaders = [System.Collections.Generic.List[object]]::new()
    $exitCode = 0
    foreach ($candidateLeader in $generatedLeaders) {
        $leaderKey = [string]$candidateLeader.key
        $entry = $records['leaders'][$leaderKey]
        if (-not $Leader -and $null -ne $entry -and $null -ne $entry['chosen']) {
            continue
        }
        $rounds = Get-LpRecordRounds -Entry $entry
        if ($rounds.Count -gt 0 -and $null -eq (Get-LpProperty -Object $rounds[$rounds.Count - 1] -Name 'decision')) {
            Write-Host "  [SKIP] ${leaderKey}: round $($rounds.Count) waits for the owner's review (build.ps1 -ApplyPortraitReview)" -ForegroundColor Yellow
            if ($Leader) {
                $exitCode = 1
            }
            continue
        }
        $photo = Get-LpPhotoByKey -Pack $packData -PhotoKey (Get-LpLeaderPhotoKey -Leader $candidateLeader)
        if ($null -eq $photo) {
            Write-Host "  [ERROR] ${leaderKey}: photo '$(Get-LpLeaderPhotoKey -Leader $candidateLeader)' is not in photos.json: fetch it with build.ps1 -FetchPhoto" -ForegroundColor Red
            $exitCode = 1
            continue
        }
        $optionProblems = Get-LpPortraitOptionProblems -Portrait (Get-LpProperty -Object $candidateLeader -Name 'portrait')
        if ($optionProblems.Count -gt 0) {
            Write-Host "  [ERROR] ${leaderKey}: $($optionProblems -join '; ')" -ForegroundColor Red
            $exitCode = 1
            continue
        }
        $openLeaders.Add([PSCustomObject]@{ Leader = $candidateLeader; Photo = $photo; Round = ($rounds.Count + 1) })
    }
    if ($openLeaders.Count -eq 0) {
        Write-Host "No open portrait in pack '$Pack'." -ForegroundColor Green
        return $exitCode
    }
    $newPortraitScript = Join-Path $ManagerRoot 'Scripts\Portraits\New-HoiPortrait.ps1'
    $startedHere = $false
    try {
        if ($StartComfyUI) {
            $startResult = Invoke-LpComfyStatus -ManagerRoot $ManagerRoot -Action 'Start'
            if ($startResult.ExitCode -ne 0) {
                Write-Host 'ComfyUI did not start; no portrait was made.' -ForegroundColor Red
                return $(if ($startResult.ExitCode -eq 2) { 2 } else { 1 })
            }
            $startedHere = $startResult.Started
        }
        foreach ($openLeader in $openLeaders) {
            $leaderKey = [string]$openLeader.Leader.key
            $roundNumber = [int]$openLeader.Round
            $seeds = @(Get-LpRoundSeeds -Round $roundNumber)
            try {
                $photoPath = Get-LpCachedPhoto -Pack $packData -Photo $openLeader.Photo
            } catch {
                Write-Host "  [ERROR] ${leaderKey}: $($_.Exception.Message)" -ForegroundColor Red
                $exitCode = 1
                continue
            }
            $settings = Get-LpPortraitSettings -Leader $openLeader.Leader
            $portraitArguments = @{
                Photo    = $photoPath
                Name     = $packData.Prefix + '_' + $leaderKey
                Tag      = $packData.Tag
                Seeds    = ($seeds -join ',')
                PassThru = $true
            }
            $argumentNames = [ordered]@{ role = 'Role'; headwear = 'Headwear'; uniform = 'Uniform'; avoidHeadwear = 'AvoidHeadwear'; notes = 'Notes' }
            foreach ($settingName in @($argumentNames.Keys)) {
                if (([string]$settings[$settingName]).Trim()) {
                    $portraitArguments[$argumentNames[$settingName]] = [string]$settings[$settingName]
                }
            }
            $portraitArguments['ColourSeed'] = [int]$settings['colourSeed']
            if (-not $settings['facePass']) {
                $portraitArguments['NoFacePass'] = $true
            }
            Write-Host "Portraits of $leaderKey, round $roundNumber, seeds $($seeds -join ', ')" -ForegroundColor Cyan
            $global:LASTEXITCODE = 0
            try {
                $portraitResult = @(& $newPortraitScript @portraitArguments) | Where-Object { $null -ne $_ -and $_.PSObject.Properties['Candidates'] } | Select-Object -Last 1
            } catch {
                Write-Host "  [ERROR] ${leaderKey}: New-HoiPortrait.ps1 failed: $($_.Exception.Message)" -ForegroundColor Red
                if ($_.Exception.Message -match 'TOOL FAILURE') {
                    $exitCode = 2
                } elseif ($exitCode -eq 0) {
                    $exitCode = 1
                }
                continue
            }
            if ($LASTEXITCODE -ne 0 -or $null -eq $portraitResult) {
                Write-Host "  [ERROR] ${leaderKey}: New-HoiPortrait.ps1 ended with exit code $LASTEXITCODE" -ForegroundColor Red
                if ($exitCode -eq 0) {
                    $exitCode = $(if ($LASTEXITCODE -eq 2) { 2 } else { 1 })
                }
                continue
            }
            $runRecord = Read-LpJson -Path ([string]$portraitResult.Run)
            $recipe = Get-LpProperty -Object $runRecord -Name 'recipe'
            $steps = [System.Collections.Generic.List[object]]::new()
            foreach ($step in @(ConvertTo-LpArray (Get-LpProperty -Object $recipe -Name 'steps'))) {
                $steps.Add([ordered]@{ template = [string]$step.template; sha256 = [string](Get-LpProperty -Object $step -Name 'sha256' -Default '') })
            }
            $candidates = [System.Collections.Generic.List[object]]::new()
            foreach ($candidate in @(ConvertTo-LpArray $portraitResult.Candidates)) {
                $candidatePath = [System.IO.Path]::GetFullPath((Join-Path ([string]$portraitResult.OutDir) ([string]$candidate.file).Replace('/', '\')))
                $likeness = Get-LpProperty -Object $candidate -Name 'likeness'
                $candidates.Add([ordered]@{
                        seed     = [int]$candidate.seed
                        file     = $candidatePath
                        sha256   = $(if (Test-Path -LiteralPath $candidatePath) { Get-LpSha256 -Path $candidatePath } else { '' })
                        likeness = $(if ($likeness -is [ValueType] -and $likeness -isnot [bool]) { [double]$likeness } else { $null })
                    })
            }
            $roundRecord = [ordered]@{
                round      = $roundNumber
                date       = Get-LpToday
                seeds      = [object[]]$seeds
                settings   = $settings
                run        = [string]$portraitResult.Run
                recipe     = [ordered]@{
                    steps         = $steps.ToArray()
                    gradeStrength = Get-LpProperty -Object $recipe -Name 'gradeStrength'
                    facePass      = Get-LpProperty -Object $recipe -Name 'facePass'
                }
                candidates = $candidates.ToArray()
                decision   = $null
            }
            $entry = $records['leaders'][$leaderKey]
            if ($null -eq $entry) {
                $entry = [ordered]@{ rounds = @(); chosen = $null }
                $records['leaders'][$leaderKey] = $entry
            }
            $rounds = Get-LpRecordRounds -Entry $entry
            $rounds.Add($roundRecord)
            $entry['rounds'] = $rounds.ToArray()
            if (-not $entry.Contains('chosen')) {
                $entry['chosen'] = $null
            }
            Save-LpPortraitRecords -Pack $packData -Records $records
            foreach ($candidate in $candidates) {
                $likenessText = if ($null -ne $candidate.likeness) { Format-LpNumber $candidate.likeness } else { 'no face found' }
                Write-Host ("  seed {0}: likeness {1}, {2}" -f $candidate.seed, $likenessText, $candidate.file) -ForegroundColor Gray
            }
            Write-Host "  recorded round $roundNumber of $leaderKey in source\$Pack\portraits.json; sheet: $($portraitResult.Sheet)" -ForegroundColor Gray
        }
    } finally {
        if ($startedHere) {
            Invoke-LpComfyStatus -ManagerRoot $ManagerRoot -Action 'Stop' | Out-Null
        }
    }
    Write-Host ("Made portraits for {0} leader(s) of pack '{1}'." -f $openLeaders.Count, $Pack) -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Yellow' })
    return $exitCode
}

function Invoke-LpApplyPortraitReview {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [Parameter(Mandatory = $true)][string]$Leader,
        [Nullable[int]]$Pick,
        [string]$Reject
    )

    if (($null -eq $Pick) -eq (-not $Reject)) {
        Write-Host '-ApplyPortraitReview takes either -Pick <seed> or -Reject "<reason>".' -ForegroundColor Red
        return 1
    }
    if ($null -eq $Pick -and -not $Reject.Trim()) {
        Write-Host '-Reject needs the reason: what the next round must change.' -ForegroundColor Red
        return 1
    }
    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $records = Read-LpPortraitRecords -Pack $packData
    $entry = $records['leaders'][$Leader]
    $rounds = Get-LpRecordRounds -Entry $entry
    if ($rounds.Count -eq 0) {
        Write-Host "No portrait round for '$Leader' in source\$Pack\portraits.json: run build.ps1 -MakePortraits first." -ForegroundColor Red
        return 1
    }
    $latestRound = $rounds[$rounds.Count - 1]
    if ($null -ne $latestRound['decision']) {
        Write-Host "Round $($latestRound['round']) of '$Leader' is decided already; make a new round with build.ps1 -MakePortraits -Leader $Leader." -ForegroundColor Red
        return 1
    }
    if ($null -eq $Pick) {
        $latestRound['decision'] = [ordered]@{ reject = $Reject.Trim() }
        $entry['rounds'] = $rounds.ToArray()
        Save-LpPortraitRecords -Pack $packData -Records $records
        Write-Host "Recorded the rejection of round $($latestRound['round']) of '$Leader': $($Reject.Trim())" -ForegroundColor Green
        return 0
    }
    $pickedCandidate = @(ConvertTo-LpArray $latestRound['candidates'] | Where-Object { [int]$_['seed'] -eq [int]$Pick }) | Select-Object -First 1
    if ($null -eq $pickedCandidate) {
        Write-Host "Seed $Pick is not a candidate of round $($latestRound['round']) of '$Leader' (seeds: $((@(ConvertTo-LpArray $latestRound['candidates']) | ForEach-Object { $_['seed'] }) -join ', '))." -ForegroundColor Red
        return 1
    }
    $candidatePath = [string]$pickedCandidate['file']
    if (-not (Test-Path -LiteralPath $candidatePath)) {
        Write-Host "The candidate file $candidatePath is gone: make a new round." -ForegroundColor Red
        return 1
    }
    if ((Get-LpSha256 -Path $candidatePath) -ne [string]$pickedCandidate['sha256']) {
        Write-Host "The candidate file $candidatePath differs from the one recorded in the round (SHA-256): make a new round." -ForegroundColor Red
        return 1
    }
    $chosenRelativePath = Get-LpChosenRelativePath -Pack $packData -LeaderKey $Leader
    $chosenPath = Join-Path $packData.RepoRoot $chosenRelativePath.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $packData.PortraitDir)) {
        New-Item -ItemType Directory -Path $packData.PortraitDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $candidatePath -Destination $chosenPath -Force
    $latestRound['decision'] = [ordered]@{ pick = [int]$Pick }
    $entry['rounds'] = $rounds.ToArray()
    $entry['chosen'] = [ordered]@{ round = [int]$latestRound['round']; seed = [int]$Pick; file = $chosenRelativePath; sha256 = (Get-LpSha256 -Path $chosenPath) }
    Save-LpPortraitRecords -Pack $packData -Records $records
    Write-Host "Recorded the pick of seed $Pick in round $($latestRound['round']) of '$Leader'; copied to $chosenRelativePath. Next: build.ps1 -ConvertPortraits -Pack $Pack" -ForegroundColor Green
    return 0
}

function Get-LpReviewLeaders {
    param($Pack)

    $records = Read-LpPortraitRecords -Pack $Pack
    $reviewLeaders = [System.Collections.Generic.List[object]]::new()
    foreach ($leader in (Get-LpGeneratedLeaders -Pack $Pack)) {
        $leaderKey = [string]$leader.key
        $rounds = Get-LpRecordRounds -Entry $records['leaders'][$leaderKey]
        if ($rounds.Count -eq 0) {
            continue
        }
        $latestRound = $rounds[$rounds.Count - 1]
        if ($null -ne $latestRound['decision']) {
            continue
        }
        $runFolder = ''
        if ($latestRound['run']) {
            $runFolder = Split-Path -Parent ([string]$latestRound['run'])
        }
        $previousText = $null
        if ($rounds.Count -gt 1) {
            $previousDecision = $rounds[$rounds.Count - 2]['decision']
            if ($null -ne $previousDecision -and $previousDecision.Contains('reject')) {
                $previousText = 'rejected, "' + [string]$previousDecision['reject'] + '"'
            } elseif ($null -ne $previousDecision -and $previousDecision.Contains('pick')) {
                $previousText = 'picked seed ' + [string]$previousDecision['pick']
            }
        }
        $creditText = ''
        $creditUrl = ''
        $photo = Get-LpPhotoByKey -Pack $Pack -PhotoKey (Get-LpLeaderPhotoKey -Leader $leader)
        if ($null -ne $photo) {
            $creditText = 'Photo: ' + (([string]$photo.commonsTitle) -replace '^File:', '') + ', ' + (Get-LpLicenceLabel -Photo $photo)
            if ([string]$photo.author) {
                $creditText += ', ' + [string]$photo.author
            }
            $creditUrl = [string]$photo.pageUrl
        }
        $reviewLeaders.Add([ordered]@{
                key        = $leaderKey
                name       = [string]$leader.name
                role       = Get-LpRoleTitle -Role ([string]$leader.role)
                round      = [int]$latestRound['round']
                seeds      = [object[]]@(ConvertTo-LpArray $latestRound['seeds'])
                previous   = $previousText
                credit     = $creditText
                creditUrl  = $creditUrl
                photo      = $(if ($runFolder) { Join-Path $runFolder 'photo.png' } else { '' })
                colour     = $(if ($runFolder) { Join-Path $runFolder 'photo-colour.png' } else { '' })
                candidates = [object[]]@(ConvertTo-LpArray $latestRound['candidates'] | ForEach-Object { [ordered]@{ seed = [int]$_['seed']; file = [string]$_['file']; likeness = $_['likeness'] } })
            })
    }
    return , $reviewLeaders
}

function Invoke-LpReviewPage {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [string]$PageUrl
    )

    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $reviewRecordPath = Join-Path $packData.SourceDir 'review.json'
    if ($PageUrl) {
        if ($PageUrl -cnotmatch '^https://claude\.ai/(code/)?artifact/[A-Za-z0-9-]+\z') {
            Write-Host "-PageUrl takes the review page's claude.ai artifact address, not '$PageUrl'." -ForegroundColor Red
            return 1
        }
        Write-LpJson -Path $reviewRecordPath -Value ([ordered]@{ pageUrl = $PageUrl; recorded = (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) })
        Write-Host "Recorded the review page of '$Pack': $PageUrl" -ForegroundColor Green
        return 0
    }
    $reviewLeaders = Get-LpReviewLeaders -Pack $packData
    if ($reviewLeaders.Count -eq 0) {
        Write-Host "No leader of '$Pack' has a round waiting for review: run build.ps1 -MakePortraits first." -ForegroundColor Yellow
        return 0
    }
    $pythonExecutable = Get-LpPythonExecutable
    if (-not $pythonExecutable) {
        Write-Host 'Python 3 with Pillow is needed to build the review page.' -ForegroundColor Red
        return 1
    }
    $reviewFolder = Join-Path $packData.RepoRoot ('scratch\review\' + $Pack)
    $dataPath = Join-Path $reviewFolder 'review-data.json'
    $pagePath = Join-Path $reviewFolder 'portrait-review.html'
    Write-LpJson -Path $dataPath -Value ([ordered]@{ pack = $Pack; displayName = $packData.DisplayName; leaders = $reviewLeaders.ToArray() })
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $builderLines = @(& $pythonExecutable -I (Join-Path $PSScriptRoot 'review_page.py') --data $dataPath --template (Join-Path $PSScriptRoot 'review-page-template.html') --out $pagePath 2>$null)
        $builderExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $answerLine = @($builderLines | Where-Object { $_ -match '^\s*\{' } | Select-Object -Last 1)
    $answer = if ($answerLine.Count) { $answerLine[0] | ConvertFrom-Json } else { $null }
    if ($builderExitCode -ne 0 -or $null -eq $answer) {
        $reason = if ($null -eq $answer) { 'no answer' } elseif ($answer.error) { [string]$answer.error } else { [string]$answer.failure }
        Write-Host "Could not build the review page: $reason" -ForegroundColor Red
        return $(if ($builderExitCode -eq 1) { 1 } else { 2 })
    }
    foreach ($missingFile in @($answer.missing)) {
        Write-Host "  missing candidate image: $missingFile" -ForegroundColor Yellow
    }
    Write-Host ("Review page of '{0}': {1} leader(s), {2} candidate(s), {3} MB" -f $Pack, $answer.leaders, $answer.candidates, (Format-LpNumber -Value ([math]::Round([double]$answer.bytes / 1MB, 1)))) -ForegroundColor Green
    if ([double]$answer.bytes -gt 15MB) {
        Write-Host '  The page is over 15 MB, close to the 16 MB limit of a published page: review fewer leaders at a time with -MakePortraits -Leader.' -ForegroundColor Yellow
    }
    Write-Host "  Page: $pagePath"
    $reviewRecord = Read-LpOptionalJson -Path $reviewRecordPath
    $knownUrl = [string](Get-LpProperty -Object $reviewRecord -Name 'pageUrl' -Default '')
    if ($knownUrl) {
        Write-Host "  Publish it to the same address: $knownUrl"
    } else {
        Write-Host '  Publish it as a new page, then record the address with build.ps1 -ReviewPage -Pack <pack> -PageUrl <url>.'
    }
    Write-Host '  Capabilities: {"db": {"rules": [{"path": "reviews", "read": "view", "write": "owner"}]}, "user": {}}'
    Write-Host "  The owner's decisions are documents in the collection 'reviews', id <leader key>-r<round>: leader, round, decision (pick or reject), seed, reason, decidedAt."
    return 0
}

function Get-LpPythonExecutable {
    foreach ($pythonName in @('python', 'py')) {
        if (Get-Command -Name $pythonName -ErrorAction SilentlyContinue) {
            return $pythonName
        }
    }
    return $null
}

function Get-LpCardWindow {
    param([Parameter(Mandatory = $true)]$Card)

    $scale = [int]$Card.scale
    $box = @(ConvertTo-LpArray $Card.card.box | ForEach-Object { [int]$_ })
    $inset = [int]$Card.card.photoInset
    return [PSCustomObject]@{
        Width  = ($box[2] - $box[0] - 2 * $inset) * $scale
        Height = ($box[3] - $box[1] - 2 * $inset) * $scale
    }
}

function Invoke-LpPortraitCrop {
    param(
        [Parameter(Mandatory = $true)]$ComfyConfig,
        [Parameter(Mandatory = $true)][string]$MeasureScript,
        [Parameter(Mandatory = $true)]$Card,
        [Parameter(Mandatory = $true)][string]$Photo,
        [Parameter(Mandatory = $true)][string]$Out
    )

    $window = Get-LpCardWindow -Card $Card
    $outFolder = Split-Path -Parent $Out
    if (-not (Test-Path -LiteralPath $outFolder)) {
        New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
    }
    $cropArguments = @(
        '-I', $MeasureScript,
        '--insightface-root', [string]$ComfyConfig.insightfaceRoot,
        'crop',
        '--photo', $Photo,
        '--out', $Out,
        '--width', [string]$window.Width,
        '--height', [string]$window.Height,
        '--face-height', (Format-LpNumber $Card.face.heightFraction),
        '--eye-line', (Format-LpNumber $Card.face.eyeLine),
        '--centre-x', (Format-LpNumber $Card.face.centreX)
    )
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $outputLines = @(& ([string]$ComfyConfig.python) @cropArguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $Out)) {
        $answerLine = @($outputLines | Where-Object { $_ -match '^\s*\{' } | Select-Object -Last 1)
        $detail = if ($answerLine.Count -gt 0) { $answerLine[0] } else { ($outputLines | Select-Object -Last 3) -join ' ' }
        throw "Measure-PortraitFaces.py crop failed (exit $exitCode): $detail"
    }
}

function Invoke-LpConvertPortraits {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [switch]$Force,
        [AllowEmptyString()][string]$ManagerRoot = (Get-LpManagerRoot)
    )

    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $cardPath = Join-Path $packData.DataDir 'portrait-card.json'
    $card = Read-LpJson -Path $cardPath
    $cardSha = Get-LpCardSha -Pack $packData
    $artifactsDir = Join-Path $packData.RepoRoot 'artifacts'
    $recordPath = Join-Path $packData.SourceDir 'converted.json'
    $expectedFiles = @(Get-LpExpectedPortraitFiles -Pack $packData)
    $expectedRelativePaths = @($expectedFiles | ForEach-Object { $_.RelativePath })
    $conversionEntries = [ordered]@{}
    foreach ($recordedPath in @(Get-LpConversionPaths -Pack $packData | Sort-Object)) {
        if ($expectedRelativePaths -contains $recordedPath) {
            $conversionEntries[$recordedPath] = ConvertTo-LpOrdered -Value (Get-LpConversionEntry -Pack $packData -RelativePath $recordedPath)
        }
    }
    $exitCode = 0
    $jobs = [System.Collections.Generic.List[PSObject]]::new()
    $currentCount = 0
    foreach ($expectedFile in $expectedFiles) {
        $leaderKey = [string]$expectedFile.Leader.key
        $chosen = Get-LpProperty -Object (Get-LpPortraitEntry -Pack $packData -LeaderKey $leaderKey) -Name 'chosen'
        if ($null -eq $chosen) {
            if ($expectedFile.Kind -eq 'large') {
                Write-Host "  [WARN] ${leaderKey}: no chosen portrait yet, nothing to convert" -ForegroundColor Yellow
            }
            continue
        }
        $chosenPath = Join-Path $packData.RepoRoot (Get-LpChosenRelativePath -Pack $packData -LeaderKey $leaderKey).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $chosenPath) -or (Get-LpSha256 -Path $chosenPath) -ne [string]$chosen.sha256) {
            Write-Host "  [ERROR] ${leaderKey}: the chosen portrait is missing or differs from its recorded SHA-256" -ForegroundColor Red
            $exitCode = 1
            continue
        }
        $destination = Join-Path $packData.PackRoot $expectedFile.RelativePath.Replace('/', '\')
        $entryCardSha = if ($expectedFile.Kind -eq 'small') { $cardSha } else { '' }
        $existingEntry = $conversionEntries[$expectedFile.RelativePath]
        $isCurrent = (-not $Force) -and (Test-Path -LiteralPath $destination) -and $null -ne $existingEntry -and
            [string]$existingEntry['chosenSha256'] -eq [string]$chosen.sha256 -and
            [string]$existingEntry['cardSha256'] -eq $entryCardSha -and
            [string]$existingEntry['ddsSha256'] -eq (Get-LpSha256 -Path $destination)
        if ($isCurrent) {
            $currentCount++
            continue
        }
        $jobs.Add([PSCustomObject]@{ Key = $leaderKey; Kind = $expectedFile.Kind; RelativePath = $expectedFile.RelativePath; Chosen = $chosenPath; ChosenSha = [string]$chosen.sha256; CardSha = $entryCardSha; Source = $chosenPath; Destination = $destination })
    }
    $smallJobs = @($jobs | Where-Object { $_.Kind -eq 'small' })
    if ($smallJobs.Count -gt 0) {
        $comfyConfig = Get-LpComfyConfig -ManagerRoot $ManagerRoot
        $measureScript = if ($ManagerRoot) { Join-Path $ManagerRoot 'Scripts\Portraits\Measure-PortraitFaces.py' } else { '' }
        if ($null -eq $comfyConfig -or -not $measureScript -or -not (Test-Path -LiteralPath $measureScript)) {
            Write-Host "  [ERROR] $($smallJobs.Count) small card(s) cannot be made: the card's crop needs the Modding Manager's Scripts\Portraits\Measure-PortraitFaces.py and the ComfyUI venv of Config\comfyui.json, and this machine has not both." -ForegroundColor Red
            $exitCode = 1
            foreach ($smallJob in $smallJobs) {
                [void]$jobs.Remove($smallJob)
            }
        } else {
            foreach ($smallJob in $smallJobs) {
                $cropPath = Join-Path $artifactsDir ("portrait-crops\$Pack\" + $smallJob.Key + '.png')
                try {
                    Invoke-LpPortraitCrop -ComfyConfig $comfyConfig -MeasureScript $measureScript -Card $card -Photo $smallJob.Chosen -Out $cropPath
                    $smallJob.Source = $cropPath
                } catch {
                    Write-Host "  [ERROR] $($smallJob.Key): $($_.Exception.Message)" -ForegroundColor Red
                    $exitCode = 1
                    [void]$jobs.Remove($smallJob)
                }
            }
        }
    }
    $convertedCount = 0
    if ($jobs.Count -gt 0) {
        $pythonExecutable = Get-LpPythonExecutable
        if (-not $pythonExecutable) {
            Write-Host 'Python 3 with Pillow is needed to convert portraits.' -ForegroundColor Red
            return 1
        }
        foreach ($job in $jobs) {
            if (Test-Path -LiteralPath $job.Destination) {
                Remove-Item -LiteralPath $job.Destination -Force
            }
        }
        $manifestPath = Join-Path $artifactsDir "portrait-manifest-$Pack.tsv"
        Write-LpText -Path $manifestPath -Text ((@($jobs | ForEach-Object { ($_.Kind, $_.Source, $_.Destination) -join "`t" }) -join "`n") + "`n")
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $pythonExecutable -I (Join-Path $PSScriptRoot 'convert_portraits.py') --manifest $manifestPath --card $cardPath 2>&1 | ForEach-Object { Write-Host "  $_" }
            $converterExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($converterExitCode -ne 0) {
            $exitCode = 1
        }
        foreach ($job in $jobs) {
            if (Test-Path -LiteralPath $job.Destination) {
                $conversionEntries[$job.RelativePath] = [ordered]@{ leader = $job.Key; kind = $job.Kind; chosenSha256 = $job.ChosenSha; cardSha256 = $job.CardSha; ddsSha256 = (Get-LpSha256 -Path $job.Destination) }
                $convertedCount++
            } else {
                [void]$conversionEntries.Remove($job.RelativePath)
            }
        }
    }
    $expectedPaths = @($expectedFiles | ForEach-Object { Join-Path $packData.PackRoot $_.RelativePath.Replace('/', '\') })
    foreach ($portraitFolder in @((Join-Path $packData.PackRoot ('gfx\leaders\' + $packData.Tag)), (Join-Path $packData.PackRoot 'gfx\interface\ideas'))) {
        if (Test-Path -LiteralPath $portraitFolder) {
            foreach ($existingDds in @(Get-ChildItem -LiteralPath $portraitFolder -Filter '*.dds' -File)) {
                if ($expectedPaths -notcontains $existingDds.FullName) {
                    Remove-Item -LiteralPath $existingDds.FullName -Force
                    Write-Host "  removed unused $($existingDds.Name)" -ForegroundColor Gray
                }
            }
        }
    }
    if ($conversionEntries.Count -gt 0 -or (Test-Path -LiteralPath $recordPath)) {
        $sortedEntries = [ordered]@{}
        foreach ($entryPath in @($conversionEntries.Keys | Sort-Object)) {
            if (Test-Path -LiteralPath (Join-Path $packData.PackRoot $entryPath.Replace('/', '\'))) {
                $sortedEntries[$entryPath] = $conversionEntries[$entryPath]
            }
        }
        Write-LpJson -Path $recordPath -Value ([ordered]@{ portraits = $sortedEntries }) -Depth 6
    }
    Write-Host ("Pack '{0}': {1} portrait file(s) converted, {2} up to date." -f $Pack, $convertedCount, $currentCount) -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
    return $exitCode
}

function Read-LpDdsBitmap {
    param([Parameter(Mandatory = $true)][string]$Path)

    $ddsSize = Get-LpDdsSize -Path $Path
    if ($null -eq $ddsSize) {
        return $null
    }
    $ddsBytes = [System.IO.File]::ReadAllBytes($Path)
    $bitmap = New-Object System.Drawing.Bitmap($ddsSize.Width, $ddsSize.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmapData = $bitmap.LockBits((New-Object System.Drawing.Rectangle(0, 0, $ddsSize.Width, $ddsSize.Height)), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $bitmap.PixelFormat)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy($ddsBytes, 128, $bitmapData.Scan0, $ddsSize.Width * $ddsSize.Height * 4)
    } finally {
        $bitmap.UnlockBits($bitmapData)
    }
    return $bitmap
}

function Export-LpPortraitPreviews {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack
    )

    Add-Type -AssemblyName System.Drawing
    $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $Pack
    $previewDir = Join-Path $packData.RepoRoot ('scratch\preview\' + $Pack)
    if (-not (Test-Path -LiteralPath $previewDir)) {
        New-Item -ItemType Directory -Path $previewDir -Force | Out-Null
    }
    $sheetEntries = [System.Collections.Generic.List[PSObject]]::new()
    $writtenCount = 0
    try {
        foreach ($leader in (Get-LpGeneratedLeaders -Pack $packData)) {
            $entry = [PSCustomObject]@{ Key = [string]$leader.key; Large = $null; Small = $null }
            foreach ($expectedFile in @(Get-LpExpectedPortraitFiles -Pack $packData | Where-Object { [string]$_.Leader.key -eq [string]$leader.key })) {
                $ddsPath = Join-Path $packData.PackRoot $expectedFile.RelativePath.Replace('/', '\')
                $bitmap = if (Test-Path -LiteralPath $ddsPath) { Read-LpDdsBitmap -Path $ddsPath } else { $null }
                if ($null -eq $bitmap) {
                    Write-Host "  [WARN] no readable $($expectedFile.Kind) DDS for '$($leader.key)': run build.ps1 -ConvertPortraits" -ForegroundColor Yellow
                    continue
                }
                $previewName = if ($expectedFile.Kind -eq 'small') { [string]$leader.key + '_small.png' } else { [string]$leader.key + '.png' }
                $bitmap.Save((Join-Path $previewDir $previewName), [System.Drawing.Imaging.ImageFormat]::Png)
                $writtenCount++
                if ($expectedFile.Kind -eq 'small') { $entry.Small = $bitmap } else { $entry.Large = $bitmap }
            }
            if ($null -ne $entry.Large -or $null -ne $entry.Small) {
                $sheetEntries.Add($entry)
            }
        }
        if ($sheetEntries.Count -gt 0) {
            $cellWidth = 176
            $cellHeight = 320
            $sheet = New-Object System.Drawing.Bitmap(($cellWidth * $sheetEntries.Count), $cellHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($sheet)
            $font = New-Object System.Drawing.Font('Segoe UI', 8)
            try {
                $graphics.Clear([System.Drawing.Color]::FromArgb(255, 46, 50, 56))
                for ($entryIndex = 0; $entryIndex -lt $sheetEntries.Count; $entryIndex++) {
                    $left = $entryIndex * $cellWidth + 10
                    if ($null -ne $sheetEntries[$entryIndex].Large) {
                        $graphics.DrawImageUnscaled($sheetEntries[$entryIndex].Large, $left, 10)
                    }
                    if ($null -ne $sheetEntries[$entryIndex].Small) {
                        $graphics.DrawImageUnscaled($sheetEntries[$entryIndex].Small, $left, 228)
                    }
                    $graphics.DrawString($sheetEntries[$entryIndex].Key, $font, [System.Drawing.Brushes]::White, [single]$left, [single]300)
                }
                $sheet.Save((Join-Path $previewDir 'sheet.png'), [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $font.Dispose()
                $graphics.Dispose()
                $sheet.Dispose()
            }
        }
    } finally {
        foreach ($sheetEntry in $sheetEntries) {
            if ($null -ne $sheetEntry.Large) { $sheetEntry.Large.Dispose() }
            if ($null -ne $sheetEntry.Small) { $sheetEntry.Small.Dispose() }
        }
    }
    $sheetText = if ($sheetEntries.Count -gt 0) { ' and sheet.png' } else { '' }
    Write-Host "Wrote $writtenCount preview(s)$sheetText of pack '$Pack' to $previewDir" -ForegroundColor Green
    return 0
}

function ConvertTo-LpSnapshotCharacter {
    param([Parameter(Mandatory = $true)]$Character)

    $roles = [System.Collections.Generic.List[object]]::new()
    $seenRoles = @{}
    foreach ($variant in @(ConvertTo-LpArray (Get-LpProperty -Object $Character -Name 'Variants'))) {
        foreach ($role in @(ConvertTo-LpArray (Get-LpProperty -Object $variant -Name 'Roles'))) {
            $roleKind = [string](Get-LpProperty -Object $role -Name 'Kind' -Default '')
            $roleSlot = [string](Get-LpProperty -Object $role -Name 'Slot' -Default '')
            $roleKey = $roleKind + '/' + $roleSlot
            if ($roleKind -and -not $seenRoles.ContainsKey($roleKey)) {
                $seenRoles[$roleKey] = $true
                $roles.Add([ordered]@{ kind = $roleKind; slot = $roleSlot })
            }
        }
    }
    return [ordered]@{ id = [string]$Character.Id; name = [string]$Character.Name; roles = $roles.ToArray() }
}

function Test-LpCountryTrait {
    param([AllowEmptyString()][string]$Trait)

    return ($Trait -cmatch '^[A-Z][A-Z0-9]*_')
}

function Select-LpStartTraits {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$TraitUses,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    $traitsByKind = @{ army = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal); navy = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal) }
    $roleKinds = Get-LpRoleKinds
    foreach ($traitUse in $TraitUses) {
        $fields = ([string]$traitUse) -split "`t"
        if ($fields.Count -ne 3 -or -not $roleKinds.Contains($fields[0]) -or -not $fields[2]) {
            continue
        }
        if (-not (Test-LpCountryTrait -Trait $fields[2]) -or $fields[1] -ceq $Tag) {
            [void]$traitsByKind[$roleKinds[$fields[0]]].Add($fields[2])
        }
    }
    return [ordered]@{ army = [object[]]@($traitsByKind.army); navy = [object[]]@($traitsByKind.navy) }
}

function Invoke-LpVanillaLookup {
    param([Parameter(Mandatory = $true)][string]$Script, [Parameter(Mandatory = $true)][hashtable]$Arguments)

    $global:LASTEXITCODE = 0
    $lookupResult = @(& $Script @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "$(Split-Path -Leaf $Script) $(@($Arguments.Keys | ForEach-Object { '-' + $_ + ' ' + $Arguments[$_] }) -join ' ') ended with exit code $LASTEXITCODE"
    }
    return $lookupResult
}

function Invoke-LpRefreshGameData {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string[]]$Pack,
        [AllowEmptyString()][string]$ManagerRoot = (Get-LpManagerRoot),
        [string]$RoadTo56 = 'The Road to 56',
        [int]$ParallelJobs = 4
    )

    if (-not $ManagerRoot -or -not (Test-Path -LiteralPath (Join-Path $ManagerRoot 'Scripts\Vanilla\Get-HoiCharacter.ps1'))) {
        Write-Host 'The Modding Manager with Scripts\Vanilla is not on this machine: the snapshot is refreshed only where the Manager and the game are.' -ForegroundColor Red
        return 1
    }
    $characterScript = Join-Path $ManagerRoot 'Scripts\Vanilla\Get-HoiCharacter.ps1'
    $countryScript = Join-Path $ManagerRoot 'Scripts\Vanilla\Get-HoiCountry.ps1'
    $gameInfoScript = Join-Path $ManagerRoot 'Scripts\Vanilla\Get-HoiGameInfo.ps1'
    $packNames = if ($Pack) { @($Pack) } else { @(Get-LpPackNames -RepoRoot $RepoRoot) }
    try {
        $gameInfo = @(Invoke-LpVanillaLookup -Script $gameInfoScript -Arguments @{ PassThru = $true }) | Select-Object -Last 1
        $today = Get-LpToday
        foreach ($packName in $packNames) {
            $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $packName
            $characterSets = [System.Collections.Generic.List[object]]::new()
            foreach ($setDefinition in @(@{ Name = 'vanilla'; Mod = '' }, @{ Name = 'rt56'; Mod = $RoadTo56 })) {
                $lookupArguments = @{ Tag = $packData.Tag; Limit = 5000; PassThru = $true }
                if ($setDefinition.Mod) {
                    $lookupArguments['Mod'] = $setDefinition.Mod
                }
                $characters = [System.Collections.Generic.List[object]]::new()
                foreach ($character in @(Invoke-LpVanillaLookup -Script $characterScript -Arguments $lookupArguments | Sort-Object { [string]$_.Id })) {
                    $characters.Add((ConvertTo-LpSnapshotCharacter -Character $character))
                }
                $characterSets.Add([ordered]@{ name = $setDefinition.Name; mod = $setDefinition.Mod; characters = $characters.ToArray() })
                Write-Host "  $packName $($setDefinition.Name): $($characters.Count) character(s) of $($packData.Tag)" -ForegroundColor Gray
            }
            $snapshot = [ordered]@{ tag = $packData.Tag; refreshed = $today; game = [string]$gameInfo.RawVersion; sets = $characterSets.ToArray() }
            Write-LpJson -Path (Join-Path $packData.DataDir ($packName + '\game-characters.json')) -Value $snapshot -Depth 8
            Write-Host "Wrote data\$packName\game-characters.json" -ForegroundColor Green
        }
        $tags = @(Invoke-LpVanillaLookup -Script $countryScript -Arguments @{ List = $true; Limit = 5000; PassThru = $true } | ForEach-Object { [string]$_.Tag } | Where-Object { $_ })
        Write-Host "  reading the unit leaders of $($tags.Count) tag(s) for the start traits ..." -ForegroundColor Gray
        $jobScript = {
            param([string]$Script, [string[]]$JobTags)
            foreach ($jobTag in $JobTags) {
                foreach ($character in @(& $Script -Tag $jobTag -Limit 5000 -PassThru)) {
                    foreach ($variant in @($character.Variants)) {
                        foreach ($role in @($variant.Roles)) {
                            foreach ($trait in @($role.Traits)) {
                                if ($trait) { [string]$role.Kind + "`t" + $jobTag + "`t" + [string]$trait }
                            }
                        }
                    }
                }
            }
        }
        $runningJobs = [System.Collections.Generic.List[object]]::new()
        $chunkSize = [int][Math]::Ceiling($tags.Count / [double][Math]::Max(1, $ParallelJobs))
        for ($chunkStart = 0; $chunkStart -lt $tags.Count; $chunkStart += $chunkSize) {
            $chunkEnd = [Math]::Min($tags.Count, $chunkStart + $chunkSize) - 1
            $chunkTags = [string[]]@($tags[$chunkStart..$chunkEnd])
            $runningJobs.Add((Start-Job -ScriptBlock $jobScript -ArgumentList $characterScript, $chunkTags))
        }
        $traitUses = [string[]]@($runningJobs | Wait-Job | Receive-Job | ForEach-Object { [string]$_ })
        $failedJobs = @($runningJobs | Where-Object { $_.State -ne 'Completed' })
        $runningJobs | Remove-Job -Force
        if ($failedJobs.Count -gt 0) {
            throw "$($failedJobs.Count) trait lookup job(s) failed"
        }
        foreach ($packName in $packNames) {
            $packData = Get-LpPack -RepoRoot $RepoRoot -Pack $packName
            $packTraits = Select-LpStartTraits -TraitUses $traitUses -Tag $packData.Tag
            if (@($packTraits.army).Count -eq 0 -or @($packTraits.navy).Count -eq 0) {
                throw 'the lookups gave no unit leader traits'
            }
            $startTraits = [ordered]@{
                about     = 'Written by build.ps1 -RefreshGameData: every trait a vanilla unit leader of each kind has at the start, read from the characters of every country tag; a trait named after a country (an upper-case prefix such as JAP_) only when the pack''s own tag uses it.'
                tag       = $packData.Tag
                refreshed = $today
                game      = [string]$gameInfo.RawVersion
                army      = $packTraits.army
                navy      = $packTraits.navy
            }
            Write-LpJson -Path (Join-Path $packData.DataDir ($packName + '\start-traits.json')) -Value $startTraits -Depth 4
            Write-Host "Wrote data\$packName\start-traits.json: $(@($packTraits.army).Count) army and $(@($packTraits.navy).Count) navy trait(s)." -ForegroundColor Green
        }
    } catch {
        Write-Host "RefreshGameData failed: $($_.Exception.Message)" -ForegroundColor Red
        return 1
    }
    return 0
}

function Invoke-LpNewPack {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [string]$SupportedVersion = '1.19.*'
    )

    if ($Pack -cnotmatch '^[a-z][a-z0-9_]*$') {
        Write-Host "-Pack '$Pack' must be lower-case letters, digits and underscores, such as finland" -ForegroundColor Red
        return 1
    }
    if ($Tag -cnotmatch '^[A-Z][A-Z0-9]{2}$') {
        Write-Host "-Tag '$Tag' is not a country tag" -ForegroundColor Red
        return 1
    }
    if ($DisplayName -notmatch '^[A-Za-z][\x20-\x7E]*$' -or $DisplayName -match '"') {
        Write-Host "-DisplayName '$DisplayName' must be plain ASCII text without a double quote" -ForegroundColor Red
        return 1
    }
    if (@(Get-LpPackNames -RepoRoot $RepoRoot) -contains $Pack) {
        Write-Host "Pack '$Pack' exists already." -ForegroundColor Red
        return 1
    }
    $prefix = 'lp_' + $Tag.ToLowerInvariant()
    if (@(Get-LpOtherPrefixes -RepoRoot $RepoRoot -Pack $Pack) -contains $prefix) {
        Write-Host "Another pack uses the prefix $prefix already." -ForegroundColor Red
        return 1
    }
    $sourceDir = Join-Path $RepoRoot ('source\' + $Pack)
    $packRoot = Join-Path $RepoRoot ('packs\' + $Pack)
    $leaderSourceText = @('{', "    `"pack`": `"$Pack`",", "    `"tag`": `"$Tag`",", "    `"prefix`": `"$prefix`",", "    `"displayName`": `"$DisplayName`",", '    "leaders": []', '}') -join "`r`n"
    Write-LpText -Path (Join-Path $sourceDir 'leaders.json') -Text ($leaderSourceText + "`r`n")
    Write-LpText -Path (Join-Path $sourceDir 'fact-sheets.md') -Text ("# Fact sheets: $DisplayName`r`n`r`nOne section per leader, headed ``## <leader key>``, written by the historical researcher: the facts behind the leader, his role and his stats, each with its source URL.`r`n")
    Write-LpText -Path (Join-Path $sourceDir 'workshop-intro.bbcode') -Text ("Historical generals, field marshals and admirals for $DisplayName that the base game leaves out, each with a portrait painted from a period photograph.`r`n`r`n[h1]Info:[/h1]`r`n- Works alone and beside any other Commanders Pack.`r`n- Adds characters, so it changes the game checksum: not Ironman compatible.`r`n- Needs a new game.`r`n")
    $descriptorText = @('version="1.0"', 'tags={', "`t`"Historical`"", "`t`"Military`"", "`t`"Gameplay`"", '}', "name=`"Commanders Pack: $DisplayName`"", 'picture="thumbnail.png"', "supported_version=`"$SupportedVersion`"") -join "`r`n"
    Write-LpText -Path (Join-Path $packRoot 'descriptor.mod') -Text ($descriptorText + "`r`n")
    $masterThumbnail = Join-Path $RepoRoot 'assets\thumbnail_master.png'
    if (Test-Path -LiteralPath $masterThumbnail) {
        Copy-Item -LiteralPath $masterThumbnail -Destination (Join-Path $packRoot 'thumbnail.png')
    }
    $settingsPath = Join-Path $RepoRoot 'tools\HoiModBuild.json'
    $settings = if (Test-Path -LiteralPath $settingsPath) { Read-LpJson -Path $settingsPath } else { [PSCustomObject]@{} }
    if ($null -eq (Get-LpProperty -Object $settings -Name 'packages')) {
        $settings | Add-Member -NotePropertyName 'packages' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $settings.packages | Add-Member -NotePropertyName $Pack -NotePropertyValue ([PSCustomObject][ordered]@{ root = "packs/$Pack"; modFolderName = "commanders_pack_$Pack" })
    Write-LpJson -Path $settingsPath -Value $settings -Depth 6
    Write-Host "Created pack '$Pack' ($Tag, prefix $prefix): source\$Pack and packs\$Pack; registered in tools\HoiModBuild.json." -ForegroundColor Green
    Write-Host ('  Next: build.ps1 -RefreshGameData -Pack ' + $Pack + ', then the leader-pack-create skill; replace packs\' + $Pack + '\thumbnail.png with the mod-thumbnail-generator.') -ForegroundColor Gray
    return (Invoke-LpGenerate -RepoRoot $RepoRoot -Pack $Pack)
}

function Invoke-LpValidation {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    Write-Host "`n==> Checking the leader pack sources and generated files..." -ForegroundColor Cyan
    return ((Invoke-LpCheck -RepoRoot $RepoRoot) -eq 0)
}
