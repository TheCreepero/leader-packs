function Get-LpShowcaseRoleStyle {
    param([Parameter(Mandatory = $true)][string]$Role)

    $armyStats = @(
        [PSCustomObject]@{ Label = 'Attack'; Field = 'attack'; Icon = 'GFX_trait_attack' },
        [PSCustomObject]@{ Label = 'Defense'; Field = 'defense'; Icon = 'GFX_trait_defense' },
        [PSCustomObject]@{ Label = 'Planning'; Field = 'planning'; Icon = 'GFX_trait_planning' },
        [PSCustomObject]@{ Label = 'Logistics'; Field = 'logistics'; Icon = 'GFX_trait_logistics' }
    )
    $navyStats = @(
        [PSCustomObject]@{ Label = 'Attack'; Field = 'attack'; Icon = 'GFX_trait_attack' },
        [PSCustomObject]@{ Label = 'Defense'; Field = 'defense'; Icon = 'GFX_trait_defense' },
        [PSCustomObject]@{ Label = 'Maneuvering'; Field = 'maneuvering'; Icon = 'GFX_trait_maneuvering' },
        [PSCustomObject]@{ Label = 'Coordination'; Field = 'coordination'; Icon = 'GFX_trait_coordination' }
    )
    switch ($Role) {
        'navy_leader' { return [PSCustomObject]@{ Label = 'Admiral'; Accent = '#5B93D6'; Stats = $navyStats } }
        'field_marshal' { return [PSCustomObject]@{ Label = 'Field marshal'; Accent = '#C9A866'; Stats = $armyStats } }
        default { return [PSCustomObject]@{ Label = 'General'; Accent = '#7FA35B'; Stats = $armyStats } }
    }
}

function Read-LpShowcaseJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function New-LpShowcaseFinding {
    param([string]$Level, [string]$Where, [string]$Message)

    return [PSCustomObject]@{ Level = $Level; Where = $Where; Message = $Message }
}

function Test-LpShowcaseSource {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack
    )

    $findings = [System.Collections.Generic.List[PSObject]]::new()
    $where = "source/$Pack/showcase.json"
    $showcasePath = Join-Path $RepoRoot "source\$Pack\showcase.json"
    if (-not (Test-Path -LiteralPath $showcasePath)) {
        return $findings.ToArray()
    }
    try {
        $showcase = Read-LpShowcaseJson -Path $showcasePath
    } catch {
        $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $where -Message "not valid JSON: $($_.Exception.Message)"))
        return $findings.ToArray()
    }
    $manifest = Read-LpShowcaseJson -Path (Join-Path $RepoRoot "source\$Pack\leaders.json")
    $leadersByKey = @{}
    foreach ($leader in @($manifest.leaders)) {
        $leadersByKey[[string]$leader.key] = $leader
    }
    foreach ($property in @($showcase.PSObject.Properties | Where-Object { $_.Name -ne 'leaders' })) {
        $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $where -Message "unknown field '$($property.Name)'; only 'leaders' is read"))
    }
    if ($null -eq $showcase.leaders) {
        return $findings.ToArray()
    }
    foreach ($entry in @($showcase.leaders.PSObject.Properties)) {
        $leaderWhere = "$where leaders.$($entry.Name)"
        $leader = $leadersByKey[$entry.Name]
        if ($null -eq $leader) {
            $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message 'no leader with this key in leaders.json'))
            continue
        }
        if ([string]$leader.mode -eq 'skip') {
            $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message 'the leader is skip and gets no showcase card'))
            continue
        }
        foreach ($field in @($entry.Value.PSObject.Properties | Where-Object { @('card', 'years') -notcontains $_.Name })) {
            $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message "unknown field '$($field.Name)'; a leader has 'card' and 'years'"))
        }
        $cardLines = @()
        if ($null -ne $entry.Value.card) {
            $cardLines = @($entry.Value.card)
        }
        if ($cardLines.Count -eq 0) {
            $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message 'card needs 1 to 4 lines'))
        } elseif ($cardLines.Count -gt 4) {
            $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message "card has $($cardLines.Count) lines; at most 4 fit"))
        }
        foreach ($cardLine in $cardLines) {
            $lineText = [string]$cardLine
            if (-not $lineText.Trim()) {
                $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message 'a card line is empty'))
            } elseif ($lineText -match "[`r`n]") {
                $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message 'a card line holds a line break'))
            } elseif ($lineText.Length -gt 160) {
                $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message "a card line has $($lineText.Length) characters; at most 160 fit"))
            }
        }
        if ($null -ne $entry.Value.years) {
            $years = @($entry.Value.years)
            $yearsValid = $years.Count -ge 1 -and $years.Count -le 2 -and @($years | Where-Object { $_ -isnot [int] -and $_ -isnot [long] }).Count -eq 0
            if (-not $yearsValid) {
                $findings.Add((New-LpShowcaseFinding -Level 'ERROR' -Where $leaderWhere -Message 'years is [born] or [born, died], whole numbers'))
            } elseif ($leader.portrait -and $leader.portrait.born -and [int]$years[0] -ne [int]$leader.portrait.born) {
                $findings.Add((New-LpShowcaseFinding -Level 'WARN' -Where $leaderWhere -Message "born $($years[0]) here but $($leader.portrait.born) in leaders.json portrait.born"))
            }
        }
    }
    return $findings.ToArray()
}

function Get-LpShowcaseCredit {
    param($Photo)

    if ($Photo -and ([string]$Photo.licenseCategory -match 'BY') -and ([string]$Photo.licenseCategory -notmatch 'CC0')) {
        return ('Portrait: AI-assisted repaint of a photograph by {0} ({1})' -f [string]$Photo.author, [string]$Photo.licenseShortName)
    }
    return 'Portrait: AI-assisted repaint of a period photograph'
}

function Invoke-LpShowcaseCheck {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string[]]$Pack
    )

    $errorCount = 0
    foreach ($packName in $Pack) {
        foreach ($finding in @(Test-LpShowcaseSource -RepoRoot $RepoRoot -Pack $packName)) {
            Write-Host ('[{0}] {1}: {2}' -f $finding.Level, $finding.Where, $finding.Message)
            if ($finding.Level -eq 'ERROR') {
                $errorCount++
            }
        }
    }
    if ($errorCount -gt 0) {
        Write-Host "Showcase check: $errorCount error(s)."
        return 1
    }
    return 0
}

function New-LpShowcaseSpec {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack
    )

    $sourceDir = Join-Path $RepoRoot "source\$Pack"
    $manifest = Read-LpShowcaseJson -Path (Join-Path $sourceDir 'leaders.json')
    $photoList = Read-LpShowcaseJson -Path (Join-Path $sourceDir 'photos.json')
    $showcase = Read-LpShowcaseJson -Path (Join-Path $sourceDir 'showcase.json')
    $startTraits = Read-LpShowcaseJson -Path (Join-Path $RepoRoot "data\$Pack\start-traits.json")
    $thumbnail = Read-LpShowcaseJson -Path (Join-Path $RepoRoot 'data\thumbnail.json')
    $photosByKey = @{}
    foreach ($photo in @($photoList.photos)) {
        $photosByKey[[string]$photo.key] = $photo
    }
    $counterpartTraits = @()
    if ($startTraits -and $startTraits.rt56 -and $startTraits.rt56.counterparts) {
        $counterpartTraits = @($startTraits.rt56.counterparts.PSObject.Properties | ForEach-Object { [string]$_.Value })
    }
    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    $displayName = [string]$manifest.displayName
    $leaders = @($manifest.leaders | Where-Object { [string]$_.mode -ne 'skip' })
    $rosterItems = [System.Collections.Generic.List[object]]::new()
    $profilePages = [System.Collections.Generic.List[object]]::new()
    $missingPortraits = [System.Collections.Generic.List[string]]::new()
    $leaderIndex = 0
    foreach ($leader in $leaders) {
        $leaderIndex++
        $leaderKey = [string]$leader.key
        $style = Get-LpShowcaseRoleStyle -Role ([string]$leader.role)
        $portraitPath = Join-Path $sourceDir "portraits\$leaderKey.png"
        if (-not (Test-Path -LiteralPath $portraitPath)) {
            $missingPortraits.Add($leaderKey)
        }
        $rosterItems.Add([ordered]@{ portrait = $portraitPath; name = [string]$leader.name; caption = $style.Label; accent = $style.Accent })
        $stats = [System.Collections.Generic.List[object]]::new()
        $stats.Add([ordered]@{ label = 'Skill'; value = [int]$leader.skill })
        foreach ($stat in $style.Stats) {
            $stats.Add([ordered]@{ label = $stat.Label; value = [int]$leader.($stat.Field); icon = $stat.Icon })
        }
        $traits = [System.Collections.Generic.List[object]]::new()
        foreach ($traitKey in @($leader.traits | Where-Object { $counterpartTraits -notcontains [string]$_ })) {
            $fallbackName = $textInfo.ToTitleCase(([string]$traitKey).Replace('_', ' '))
            $traits.Add([ordered]@{ name = [ordered]@{ locKey = [string]$traitKey; fallback = $fallbackName }; icon = ('GFX_trait_' + $traitKey) })
        }
        $entry = $null
        if ($showcase -and $showcase.leaders) {
            $entry = $showcase.leaders.PSObject.Properties | Where-Object { $_.Name -eq $leaderKey } | ForEach-Object { $_.Value } | Select-Object -First 1
        }
        $years = [object[]]@()
        if ($entry -and $entry.years) {
            $years = [object[]]@($entry.years)
        } elseif ($leader.portrait -and $leader.portrait.born) {
            $years = [object[]]@([int]$leader.portrait.born)
        }
        $lines = [object[]]@()
        if ($entry -and $entry.card) {
            $lines = [object[]]@($entry.card)
        }
        $photoKey = if ($leader.portrait) { [string]$leader.portrait.photo } else { '' }
        $profilePages.Add([ordered]@{
                layout     = 'profile'
                file       = ('{0:D2}-{1}' -f $leaderIndex, $leaderKey)
                portrait   = $portraitPath
                name       = [string]$leader.name
                role       = $style.Label
                roleAccent = $style.Accent
                years      = $years
                lines      = $lines
                stats      = $stats.ToArray()
                traits     = $traits.ToArray()
                note       = (Get-LpShowcaseCredit -Photo $photosByKey[$photoKey])
            })
    }
    $rosterPage = [ordered]@{
        layout   = 'roster'
        file     = '00-roster'
        title    = 'The commanders'
        subtitle = ('{0} leaders for {1}; portraits AI-assisted from period photographs' -f $leaders.Count, $displayName)
        items    = $rosterItems.ToArray()
    }
    $spec = [ordered]@{
        version = 1
        brand   = [ordered]@{ label = "Commanders Pack: $displayName"; flag = [ordered]@{ tag = [string]$manifest.tag } }
        pages   = [object[]](@($rosterPage) + $profilePages.ToArray())
    }
    if ($thumbnail -and $thumbnail.background) {
        $spec['background'] = [ordered]@{ gamePath = [string]$thumbnail.background; crop = $(if ($thumbnail.crop) { $thumbnail.crop } else { 'center' }); blur = $(if ($null -ne $thumbnail.blur) { $thumbnail.blur } else { 4 }) }
    }
    return [PSCustomObject]@{ Spec = $spec; MissingPortraits = $missingPortraits.ToArray(); CardlessLeaders = @($profilePages | Where-Object { $_.lines.Count -eq 0 } | ForEach-Object { $_.name }) }
}

function Invoke-LpRenderShowcase {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Pack,
        [AllowEmptyString()][string]$ManagerRoot = (Get-LpManagerRoot),
        [string]$OutputDir
    )

    $findings = @(Test-LpShowcaseSource -RepoRoot $RepoRoot -Pack $Pack)
    foreach ($finding in $findings) {
        Write-Host ('[{0}] {1}: {2}' -f $finding.Level, $finding.Where, $finding.Message)
    }
    if (@($findings | Where-Object { $_.Level -eq 'ERROR' }).Count -gt 0) {
        Write-Host "RenderShowcase: source/$Pack/showcase.json has errors; nothing rendered."
        return 1
    }
    if (-not $ManagerRoot) {
        Write-Host 'RenderShowcase: the Modding Manager was not found; the images are drawn by its Scripts\Showcase\New-HoiShowcaseImage.ps1.'
        return 1
    }
    $rendererPath = Join-Path $ManagerRoot 'Scripts\Showcase\New-HoiShowcaseImage.ps1'
    if (-not (Test-Path -LiteralPath $rendererPath)) {
        Write-Host "RenderShowcase: $rendererPath not found; update the Modding Manager."
        return 1
    }
    $built = New-LpShowcaseSpec -RepoRoot $RepoRoot -Pack $Pack
    if ($built.MissingPortraits.Count -gt 0) {
        Write-Host ("RenderShowcase: no chosen portrait for {0}; pick them on the review page first." -f ($built.MissingPortraits -join ', '))
        return 1
    }
    foreach ($leaderName in $built.CardlessLeaders) {
        Write-Host "[WARN] source/$Pack/showcase.json: no card lines for $leaderName; the card shows role, years, stats and traits only."
    }
    if (-not $OutputDir) {
        $OutputDir = Join-Path $RepoRoot "artifacts\workshop-images\$Pack"
    }
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $specPath = Join-Path $OutputDir 'showcase-spec.json'
    [System.IO.File]::WriteAllText($specPath, (ConvertTo-Json -InputObject $built.Spec -Depth 12), [System.Text.UTF8Encoding]::new($false))
    $powerShellExecutable = if (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    $rendererOutput = @(& $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $rendererPath -SpecPath $specPath -OutputDir $OutputDir)
    $rendererExitCode = $LASTEXITCODE
    foreach ($outputLine in $rendererOutput) {
        Write-Host $outputLine
    }
    return $rendererExitCode
}
