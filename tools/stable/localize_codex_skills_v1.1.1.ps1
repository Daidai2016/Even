# ==============================================
# Codex Skills and Plugins Chinese UI Localizer V1.1.1
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==============================================

param(
    [switch]$CheckOnly,
    [string]$RestoreFrom,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$CatalogPath = Join-Path $PSScriptRoot "config\codex_skills_zh-CN.json"
$UserProfilePath = [Environment]::GetFolderPath("UserProfile")
$BackupRoot = Join-Path `
    $UserProfilePath `
    ".codex\backups\skill-localization"
$SkillsRoot = Join-Path $UserProfilePath ".codex\skills"
$SystemSkillsRoot = Join-Path $SkillsRoot ".system"
$AgentsSkillsRoot = Join-Path $UserProfilePath ".agents\skills"
$PluginCacheRoot = Join-Path $UserProfilePath ".codex\plugins\cache"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)


function Get-Sha256 {
    param([byte[]]$Bytes)

    $Hasher = [Security.Cryptography.SHA256]::Create()

    try {
        return ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace("-", "")
    }
    finally {
        $Hasher.Dispose()
    }
}


function ConvertTo-YamlQuoted {
    param([string]$Value)

    $Escaped = $Value.Replace("\", "\\").Replace('"', '\"')
    $Escaped = $Escaped.Replace("`r", "\r").Replace("`n", "\n")
    return '"' + $Escaped + '"'
}


function Get-SkillName {
    param([string]$SkillPath)

    $SkillFile = Join-Path $SkillPath "SKILL.md"

    if (-not (Test-Path -LiteralPath $SkillFile -PathType Leaf)) {
        return $null
    }

    $Text = [IO.File]::ReadAllText($SkillFile)
    $Match = [regex]::Match(
        $Text,
        '(?m)^name:\s*["'']?([^"''\r\n]+)'
    )

    if (-not $Match.Success) {
        return $null
    }

    return $Match.Groups[1].Value.Trim()
}


function Get-CurrentSkillTargets {
    $Targets = @()

    if (Test-Path -LiteralPath $SystemSkillsRoot -PathType Container) {
        foreach ($Directory in Get-ChildItem -LiteralPath $SystemSkillsRoot -Directory) {
            $SkillName = Get-SkillName -SkillPath $Directory.FullName

            if ($null -ne $SkillName) {
                $Targets += [pscustomobject]@{
                    Scope = "system"
                    Owner = "Codex"
                    SkillName = $SkillName
                    SkillPath = $Directory.FullName
                    UiPath = Join-Path $Directory.FullName "agents\openai.yaml"
                }
            }
        }
    }

    if (Test-Path -LiteralPath $SkillsRoot -PathType Container) {
        foreach ($Directory in Get-ChildItem -LiteralPath $SkillsRoot -Directory) {
            if ($Directory.Name -eq ".system") {
                continue
            }

            $SkillName = Get-SkillName -SkillPath $Directory.FullName

            if ($null -ne $SkillName) {
                $Targets += [pscustomobject]@{
                    Scope = "user"
                    Owner = "user"
                    SkillName = $SkillName
                    SkillPath = $Directory.FullName
                    UiPath = Join-Path $Directory.FullName "agents\openai.yaml"
                }
            }
        }
    }

    if (Test-Path -LiteralPath $AgentsSkillsRoot -PathType Container) {
        foreach ($Directory in (Get-ChildItem -LiteralPath $AgentsSkillsRoot -Filter "SKILL.md" -File -Recurse | ForEach-Object { $_.Directory })) {
            $SkillName = Get-SkillName -SkillPath $Directory.FullName

            if ($null -ne $SkillName) {
                $Targets += [pscustomobject]@{
                    Scope = "agents-user"
                    Owner = "agents-user"
                    SkillName = $SkillName
                    SkillPath = $Directory.FullName
                    UiPath = Join-Path $Directory.FullName "agents\openai.yaml"
                }
            }
        }
    }

    if (Test-Path -LiteralPath $PluginCacheRoot -PathType Container) {
        $SkillFiles = Get-ChildItem `
            -LiteralPath $PluginCacheRoot `
            -Filter "SKILL.md" `
            -File `
            -Recurse |
            Where-Object { $_.FullName -match '[\\/]skills[\\/]' }

        foreach ($SkillFile in $SkillFiles) {
            $Directory = $SkillFile.Directory
            $SkillName = Get-SkillName -SkillPath $Directory.FullName

            if ($null -eq $SkillName) {
                continue
            }

            $PluginPath = $Directory.Parent.Parent.FullName
            $Ancestor = $Directory.Parent
            while ($null -ne $Ancestor -and $Ancestor.FullName -ne $PluginCacheRoot) {
                if (Test-Path -LiteralPath (Join-Path $Ancestor.FullName ".codex-plugin\plugin.json") -PathType Leaf) {
                    $PluginPath = $Ancestor.FullName
                    break
                }
                $Ancestor = $Ancestor.Parent
            }
            $PluginManifestPath = Join-Path `
                $PluginPath `
                ".codex-plugin\plugin.json"
            $Owner = Split-Path $PluginPath -Leaf

            if (Test-Path -LiteralPath $PluginManifestPath -PathType Leaf) {
                $PluginManifest = Get-Content `
                    -LiteralPath $PluginManifestPath `
                    -Raw `
                    -Encoding UTF8 |
                    ConvertFrom-Json
                $Owner = [string]$PluginManifest.name
            }

            $Targets += [pscustomobject]@{
                Scope = "plugin"
                Owner = $Owner
                SkillName = $SkillName
                SkillPath = $Directory.FullName
                UiPath = Join-Path $Directory.FullName "agents\openai.yaml"
            }
        }
    }

    return @($Targets | Sort-Object UiPath -Unique)
}


function Get-CurrentPluginTargets {
    $Targets = @()

    if (-not (Test-Path -LiteralPath $PluginCacheRoot -PathType Container)) {
        return $Targets
    }

    $ManifestFiles = Get-ChildItem `
        -LiteralPath $PluginCacheRoot `
        -Filter "plugin.json" `
        -File `
        -Recurse |
        Where-Object { $_.Directory.Name -eq ".codex-plugin" }

    foreach ($ManifestFile in $ManifestFiles) {
        $Manifest = Get-Content `
            -LiteralPath $ManifestFile.FullName `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        if ($null -eq $Manifest.interface) {
            continue
        }

        $Targets += [pscustomobject]@{
            PluginName = [string]$Manifest.name
            UiPath = $ManifestFile.FullName
        }
    }

    return @($Targets | Sort-Object UiPath -Unique)
}


function Assert-TrustedLocalizationPath {
    param([string]$Path)

    $FullPath = [IO.Path]::GetFullPath($Path)
    $SkillsAllowedRoot = (
        [IO.Path]::GetFullPath($SkillsRoot).TrimEnd("\") + "\"
    )
    $AgentsSkillsAllowedRoot = (
        [IO.Path]::GetFullPath($AgentsSkillsRoot).TrimEnd("\") + "\"
    )
    $PluginAllowedRoot = (
        [IO.Path]::GetFullPath($PluginCacheRoot).TrimEnd("\") + "\"
    )
    $AllowedRoots = @(
        $SkillsAllowedRoot,
        $AgentsSkillsAllowedRoot,
        $PluginAllowedRoot
    )
    $Allowed = $false

    foreach ($Root in $AllowedRoots) {
        if ($FullPath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
            $Allowed = $true
            break
        }
    }

    $Leaf = Split-Path $FullPath -Leaf
    $IsSkillUi = $Leaf -eq "openai.yaml"
    $IsPluginUi = (
        $Leaf -eq "plugin.json" -and
        (Split-Path (Split-Path $FullPath -Parent) -Leaf) -eq ".codex-plugin" -and
        $FullPath.StartsWith(
            $PluginAllowedRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    )

    if (-not $Allowed -or (-not $IsSkillUi -and -not $IsPluginUi)) {
        throw "拒绝修改不受信任的路径：$FullPath"
    }
}


function Get-LocalizedYaml {
    param(
        [string]$Original,
        [object]$Translation,
        [string]$NewLine
    )

    $Normalized = $Original.Replace("`r`n", "`n").Replace("`r", "`n")
    $HadTrailingNewLine = $Normalized.EndsWith("`n")
    $Lines = New-Object "System.Collections.Generic.List[string]"

    if ($Normalized.Length -gt 0) {
        foreach ($Line in $Normalized.Split("`n")) {
            [void]$Lines.Add($Line)
        }

        if ($HadTrailingNewLine -and $Lines.Count -gt 0) {
            $Lines.RemoveAt($Lines.Count - 1)
        }
    }

    $InterfaceStart = -1

    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        if ($Lines[$Index] -match '^interface:\s*(?:#.*)?$') {
            $InterfaceStart = $Index
            break
        }
    }

    if ($InterfaceStart -lt 0) {
        $Prefix = @(
            "interface:",
            "  display_name: $(ConvertTo-YamlQuoted $Translation.displayName)",
            "  short_description: $(ConvertTo-YamlQuoted $Translation.shortDescription)",
            "  default_prompt: $(ConvertTo-YamlQuoted $Translation.defaultPrompt)"
        )
        $Combined = New-Object "System.Collections.Generic.List[string]"

        foreach ($Line in $Prefix) {
            [void]$Combined.Add($Line)
        }

        if ($Lines.Count -gt 0) {
            [void]$Combined.Add("")

            foreach ($Line in $Lines) {
                [void]$Combined.Add($Line)
            }
        }

        $Lines = $Combined
    }
    else {
        $InterfaceEnd = $Lines.Count

        for ($Index = $InterfaceStart + 1; $Index -lt $Lines.Count; $Index++) {
            if ($Lines[$Index] -match '^[A-Za-z_][A-Za-z0-9_-]*:\s*(?:#.*)?$') {
                $InterfaceEnd = $Index
                break
            }
        }

        $Fields = @(
            [pscustomobject]@{
                Key = "display_name"
                Value = [string]$Translation.displayName
            },
            [pscustomobject]@{
                Key = "short_description"
                Value = [string]$Translation.shortDescription
            },
            [pscustomobject]@{
                Key = "default_prompt"
                Value = [string]$Translation.defaultPrompt
            }
        )

        foreach ($Field in $Fields) {
            $FieldIndex = -1

            for ($Index = $InterfaceStart + 1; $Index -lt $InterfaceEnd; $Index++) {
                if ($Lines[$Index] -match "^\s{2}$([regex]::Escape($Field.Key)):\s*") {
                    $FieldIndex = $Index
                    break
                }
            }

            $NewLineText = "  $($Field.Key): $(ConvertTo-YamlQuoted $Field.Value)"

            if ($FieldIndex -ge 0) {
                $Lines[$FieldIndex] = $NewLineText
            }
            else {
                $Lines.Insert($InterfaceEnd, $NewLineText)
                $InterfaceEnd++
            }
        }
    }

    $Result = [string]::Join("`n", $Lines)

    if ($HadTrailingNewLine -or $Original.Length -eq 0) {
        $Result += "`n"
    }

    return $Result.Replace("`n", $NewLine)
}


function Set-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($null -ne $Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member `
            -MemberType NoteProperty `
            -Name $Name `
            -Value $Value
    }
}


function Get-LocalizedPluginJson {
    param(
        [string]$Original,
        [object]$Translation,
        [string]$NewLine
    )

    $Plugin = $Original | ConvertFrom-Json

    if ($null -eq $Plugin.interface) {
        throw "插件缺少 interface 展示配置：$($Plugin.name)"
    }

    Set-ObjectProperty `
        -Object $Plugin.interface `
        -Name "displayName" `
        -Value ([string]$Translation.displayName)
    Set-ObjectProperty `
        -Object $Plugin.interface `
        -Name "shortDescription" `
        -Value ([string]$Translation.shortDescription)
    Set-ObjectProperty `
        -Object $Plugin.interface `
        -Name "longDescription" `
        -Value ([string]$Translation.longDescription)
    Set-ObjectProperty `
        -Object $Plugin.interface `
        -Name "defaultPrompt" `
        -Value @($Translation.defaultPrompts | ForEach-Object { [string]$_ })

    $Result = $Plugin | ConvertTo-Json -Depth 30
    $Result = $Result.Replace("`r`n", "`n").Replace("`r", "`n")

    if ($Original.EndsWith("`n") -or $Original.EndsWith("`r")) {
        $Result += "`n"
    }

    return $Result.Replace("`n", $NewLine)
}


function Get-EncodedBytes {
    param(
        [string]$Text,
        [bool]$WithBom
    )

    $Encoding = New-Object System.Text.UTF8Encoding($WithBom)
    $Body = $Encoding.GetBytes($Text)

    if (-not $WithBom) {
        return $Body
    }

    $Preamble = $Encoding.GetPreamble()
    $Bytes = New-Object byte[] ($Preamble.Length + $Body.Length)
    [Array]::Copy($Preamble, 0, $Bytes, 0, $Preamble.Length)
    [Array]::Copy($Body, 0, $Bytes, $Preamble.Length, $Body.Length)
    return $Bytes
}


function Restore-Localization {
    param([string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "找不到恢复清单：$ManifestPath"
    }

    $ResolvedManifest = (Resolve-Path -LiteralPath $ManifestPath).Path
    $ResolvedBackupRoot = [IO.Path]::GetFullPath($BackupRoot).TrimEnd("\") + "\"

    if (-not $ResolvedManifest.StartsWith(
        $ResolvedBackupRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "恢复清单必须位于：$BackupRoot"
    }

    $Manifest = Get-Content `
        -LiteralPath $ResolvedManifest `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    $Restored = 0

    foreach ($Item in $Manifest.items) {
        $UiPath = [string]$Item.path
        Assert-TrustedLocalizationPath -Path $UiPath

        if (Test-Path -LiteralPath $UiPath -PathType Leaf) {
            $CurrentBytes = [IO.File]::ReadAllBytes($UiPath)
            $CurrentHash = Get-Sha256 -Bytes $CurrentBytes

            if ($CurrentHash -ne [string]$Item.afterSha256) {
                throw "文件在中文化后又发生变化，拒绝覆盖：$UiPath"
            }
        }

        if ([bool]$Item.existed) {
            $OriginalBytes = [Convert]::FromBase64String(
                [string]$Item.beforeContentBase64
            )
            [IO.File]::WriteAllBytes($UiPath, $OriginalBytes)
        }
        elseif (Test-Path -LiteralPath $UiPath -PathType Leaf) {
            Remove-Item -LiteralPath $UiPath -Force
        }

        $Restored++
    }

    Write-Host "已恢复 $Restored 个 Skill 或插件界面配置。" -ForegroundColor Green
}


try {
    if (-not [string]::IsNullOrWhiteSpace($RestoreFrom)) {
        Restore-Localization -ManifestPath $RestoreFrom
        exit 0
    }

    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "找不到中文化映射：$CatalogPath"
    }

    $Catalog = Get-Content `
        -LiteralPath $CatalogPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    $SkillTranslations = @{}

    foreach ($Translation in $Catalog.skills) {
        $Owner = "*"

        if ($null -ne $Translation.PSObject.Properties["owner"] -and
            -not [string]::IsNullOrWhiteSpace([string]$Translation.owner)) {
            $Owner = [string]$Translation.owner
        }

        $Key = [string]::Concat($Owner, "::", [string]$Translation.name)

        if ($SkillTranslations.ContainsKey($Key)) {
            throw "Skill 中文映射重复：$Key"
        }

        $SkillTranslations[$Key] = $Translation
    }

    $MatchedSkillTargets = @()
    $FoundSkillKeys = @{}

    foreach ($Target in @(Get-CurrentSkillTargets)) {
        $ExactKey = [string]::Concat(
            [string]$Target.Owner,
            "::",
            [string]$Target.SkillName
        )
        $GenericKey = [string]::Concat("*::", [string]$Target.SkillName)
        $MatchedKey = $null

        if ($SkillTranslations.ContainsKey($ExactKey)) {
            $MatchedKey = $ExactKey
        }
        elseif ($SkillTranslations.ContainsKey($GenericKey)) {
            $MatchedKey = $GenericKey
        }

        if ($null -eq $MatchedKey) {
            continue
        }

        $FoundSkillKeys[$MatchedKey] = $true
        $MatchedSkillTargets += [pscustomobject]@{
            Target = $Target
            Translation = $SkillTranslations[$MatchedKey]
        }
    }

    $MissingSkillKeys = @(
        $SkillTranslations.Keys |
            Where-Object { -not $FoundSkillKeys.ContainsKey($_) } |
            Sort-Object
    )

    if ($MissingSkillKeys.Count -gt 0) {
        Write-Host "当前未安装，保留翻译供以后使用：$($MissingSkillKeys -join ', ')"
    }

    $PluginTranslations = @{}

    foreach ($Translation in $Catalog.plugins) {
        $Name = [string]$Translation.name

        if ($PluginTranslations.ContainsKey($Name)) {
            throw "插件中文映射重复：$Name"
        }

        $PluginTranslations[$Name] = $Translation
    }

    $MatchedPluginTargets = @(
        Get-CurrentPluginTargets |
            Where-Object { $PluginTranslations.ContainsKey($_.PluginName) }
    )
    $FoundPluginNames = @(
        $MatchedPluginTargets |
            ForEach-Object { $_.PluginName } |
            Select-Object -Unique
    )
    $MissingPluginNames = @(
        $Catalog.plugins |
            Where-Object { $FoundPluginNames -notcontains [string]$_.name } |
            ForEach-Object { [string]$_.name }
    )

    if ($MissingPluginNames.Count -gt 0) {
        Write-Host "当前未安装，保留插件翻译供以后使用：$($MissingPluginNames -join ', ')"
    }

    $Updates = @()

    foreach ($Match in $MatchedSkillTargets) {
        $Target = $Match.Target
        $Translation = $Match.Translation
        Assert-TrustedLocalizationPath -Path $Target.UiPath
        $Existed = Test-Path -LiteralPath $Target.UiPath -PathType Leaf
        $BeforeBytes = if ($Existed) {
            [IO.File]::ReadAllBytes($Target.UiPath)
        }
        else {
            New-Object byte[] 0
        }
        $Original = if ($Existed) {
            [IO.File]::ReadAllText($Target.UiPath)
        }
        else {
            ""
        }
        $WithBom = (
            $BeforeBytes.Length -ge 3 -and
            $BeforeBytes[0] -eq 239 -and
            $BeforeBytes[1] -eq 187 -and
            $BeforeBytes[2] -eq 191
        )
        $LineEnding = if ($Original.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Localized = Get-LocalizedYaml `
            -Original $Original `
            -Translation $Translation `
            -NewLine $LineEnding
        $AfterBytes = Get-EncodedBytes -Text $Localized -WithBom $WithBom
        $Changed = (Get-Sha256 -Bytes $BeforeBytes) -ne (
            Get-Sha256 -Bytes $AfterBytes
        )

        Write-Host "[$(if ($Changed) { '需更新' } else { '已中文' })] $($Target.SkillName) -> $($Translation.displayName)"

        if ($Changed) {
            $Updates += [pscustomobject]@{
                Kind = "skill"
                Name = [string]$Target.SkillName
                Owner = [string]$Target.Owner
                Path = [string]$Target.UiPath
                Existed = $Existed
                BeforeBytes = $BeforeBytes
                AfterBytes = $AfterBytes
            }
        }
    }

    $SkillUpdateCount = $Updates.Count

    foreach ($Target in $MatchedPluginTargets) {
        $Translation = $PluginTranslations[$Target.PluginName]
        Assert-TrustedLocalizationPath -Path $Target.UiPath
        $BeforeBytes = [IO.File]::ReadAllBytes($Target.UiPath)
        $Original = [IO.File]::ReadAllText($Target.UiPath)
        $WithBom = (
            $BeforeBytes.Length -ge 3 -and
            $BeforeBytes[0] -eq 239 -and
            $BeforeBytes[1] -eq 187 -and
            $BeforeBytes[2] -eq 191
        )
        $LineEnding = if ($Original.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Localized = Get-LocalizedPluginJson `
            -Original $Original `
            -Translation $Translation `
            -NewLine $LineEnding
        $AfterBytes = Get-EncodedBytes -Text $Localized -WithBom $WithBom
        $Changed = (Get-Sha256 -Bytes $BeforeBytes) -ne (
            Get-Sha256 -Bytes $AfterBytes
        )

        Write-Host "[$(if ($Changed) { '需更新' } else { '已中文' })] 插件 $($Target.PluginName) -> $($Translation.displayName)"

        if ($Changed) {
            $Updates += [pscustomobject]@{
                Kind = "plugin"
                Name = [string]$Target.PluginName
                Owner = [string]$Target.PluginName
                Path = [string]$Target.UiPath
                Existed = $true
                BeforeBytes = $BeforeBytes
                AfterBytes = $AfterBytes
            }
        }
    }

    $PluginUpdateCount = $Updates.Count - $SkillUpdateCount
    Write-Host "Skill 已发现：$($MatchedSkillTargets.Count)；需要更新：$SkillUpdateCount。"
    Write-Host "插件已发现：$($MatchedPluginTargets.Count)；需要更新：$PluginUpdateCount。"

    if ($CheckOnly) {
        if ($Updates.Count -gt 0) {
            exit 1
        }

        exit 0
    }

    if ($Updates.Count -eq 0) {
        Write-Host "所有已登记 Skill 与插件均已使用中文界面。" -ForegroundColor Green
        exit 0
    }

    $BackupDirectory = Join-Path `
        $BackupRoot `
        (Get-Date -Format "yyyyMMdd-HHmmss")
    New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
    $ManifestPath = Join-Path $BackupDirectory "manifest.json"
    $ManifestItems = @()

    foreach ($Update in $Updates) {
        $ManifestItems += [pscustomobject]@{
            kind = [string]$Update.Kind
            name = [string]$Update.Name
            owner = [string]$Update.Owner
            path = [string]$Update.Path
            existed = [bool]$Update.Existed
            beforeSha256 = Get-Sha256 -Bytes $Update.BeforeBytes
            afterSha256 = Get-Sha256 -Bytes $Update.AfterBytes
            beforeContentBase64 = [Convert]::ToBase64String($Update.BeforeBytes)
        }
    }

    $Manifest = [pscustomobject]@{
        schemaVersion = 2
        locale = [string]$Catalog.locale
        createdAt = (Get-Date).ToString("o")
        items = $ManifestItems
    }
    $ManifestText = $Manifest | ConvertTo-Json -Depth 6
    $ManifestText = $ManifestText.Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($ManifestPath, $ManifestText, $Utf8NoBom)

    foreach ($Update in $Updates) {
        $Parent = Split-Path $Update.Path -Parent
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
        [IO.File]::WriteAllBytes($Update.Path, $Update.AfterBytes)
    }

    Write-Host "中文化完成：$SkillUpdateCount 个 Skill，$PluginUpdateCount 个插件。" -ForegroundColor Green
    Write-Host "恢复清单：$ManifestPath"
    Write-Host "重新打开 Codex 会话后显示新名称。"
}
catch {
    Write-Host "Skill 或插件中文化失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
