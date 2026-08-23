# ==============================================
# Codex Skills Chinese UI Localizer V1.0.2
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
$SystemSkillsRoot = Join-Path $UserProfilePath ".codex\skills\.system"
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

    $CodexCommand = Get-Command "codex.cmd" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $CodexCommand) {
        throw "未检测到 codex.cmd，无法读取当前插件版本。"
    }

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        # Windows PowerShell 5.1 会把原生命令写入 stderr 的普通警告
        # 包装成 ErrorRecord。插件发现仍以真实退出码为准。
        $ErrorActionPreference = "Continue"
        $Output = @(
            & $CodexCommand.Source plugin list --available --json 2>$null
        )
        $CodexExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($CodexExitCode -ne 0) {
        throw "无法读取当前已安装插件列表。"
    }

    $PluginData = ($Output -join [Environment]::NewLine) |
        ConvertFrom-Json

    foreach ($Plugin in $PluginData.installed) {
        if ([string]$Plugin.marketplaceName -eq "codex-design") {
            continue
        }

        $PluginPath = Join-Path `
            $PluginCacheRoot `
            "$($Plugin.marketplaceName)\$($Plugin.name)\$($Plugin.version)"
        $SkillsPath = Join-Path $PluginPath "skills"

        if (-not (Test-Path -LiteralPath $SkillsPath -PathType Container)) {
            continue
        }

        foreach ($Directory in Get-ChildItem -LiteralPath $SkillsPath -Directory) {
            $SkillName = Get-SkillName -SkillPath $Directory.FullName

            if ($null -ne $SkillName) {
                $Targets += [pscustomobject]@{
                    Scope = "plugin"
                    Owner = [string]$Plugin.pluginId
                    SkillName = $SkillName
                    SkillPath = $Directory.FullName
                    UiPath = Join-Path $Directory.FullName "agents\openai.yaml"
                }
            }
        }
    }

    return $Targets
}


function Assert-TrustedUiPath {
    param([string]$Path)

    $FullPath = [IO.Path]::GetFullPath($Path)
    $SystemAllowedRoot = (
        [IO.Path]::GetFullPath($SystemSkillsRoot).TrimEnd("\") + "\"
    )
    $PluginAllowedRoot = (
        [IO.Path]::GetFullPath($PluginCacheRoot).TrimEnd("\") + "\"
    )
    $AllowedRoots = @($SystemAllowedRoot, $PluginAllowedRoot)
    $Allowed = $false

    foreach ($Root in $AllowedRoots) {
        if ($FullPath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
            $Allowed = $true
            break
        }
    }

    if (-not $Allowed -or (Split-Path $FullPath -Leaf) -ne "openai.yaml") {
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
        Assert-TrustedUiPath -Path $UiPath

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

    Write-Host "已恢复 $Restored 个 Skill 界面配置。" -ForegroundColor Green
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
    $Translations = @{}

    foreach ($Translation in $Catalog.skills) {
        $Translations[[string]$Translation.name] = $Translation
    }

    $Targets = @(
        Get-CurrentSkillTargets |
            Where-Object { $Translations.ContainsKey($_.SkillName) }
    )
    $FoundNames = @($Targets | ForEach-Object { $_.SkillName } | Select-Object -Unique)
    $MissingNames = @(
        $Catalog.skills |
            Where-Object { $FoundNames -notcontains [string]$_.name } |
            ForEach-Object { [string]$_.name }
    )

    if ($MissingNames.Count -gt 0) {
        throw "未找到以下已登记 Skill：$($MissingNames -join ', ')"
    }

    $Updates = @()

    foreach ($Target in $Targets) {
        $Translation = $Translations[$Target.SkillName]
        Assert-TrustedUiPath -Path $Target.UiPath
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
                Target = $Target
                Existed = $Existed
                BeforeBytes = $BeforeBytes
                AfterBytes = $AfterBytes
            }
        }
    }

    Write-Host "已发现：$($Targets.Count)；需要更新：$($Updates.Count)。"

    if ($CheckOnly) {
        if ($Updates.Count -gt 0) {
            exit 1
        }

        exit 0
    }

    if ($Updates.Count -eq 0) {
        Write-Host "所有已登记 Skill 均已使用中文界面。" -ForegroundColor Green
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
            skillName = [string]$Update.Target.SkillName
            owner = [string]$Update.Target.Owner
            path = [string]$Update.Target.UiPath
            existed = [bool]$Update.Existed
            beforeSha256 = Get-Sha256 -Bytes $Update.BeforeBytes
            afterSha256 = Get-Sha256 -Bytes $Update.AfterBytes
            beforeContentBase64 = [Convert]::ToBase64String($Update.BeforeBytes)
        }
    }

    $Manifest = [pscustomobject]@{
        schemaVersion = 1
        locale = [string]$Catalog.locale
        createdAt = (Get-Date).ToString("o")
        items = $ManifestItems
    }
    $ManifestText = $Manifest | ConvertTo-Json -Depth 6
    $ManifestText = $ManifestText.Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($ManifestPath, $ManifestText, $Utf8NoBom)

    foreach ($Update in $Updates) {
        $Parent = Split-Path $Update.Target.UiPath -Parent
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
        [IO.File]::WriteAllBytes($Update.Target.UiPath, $Update.AfterBytes)
    }

    Write-Host "中文化完成：$($Updates.Count) 个 Skill。" -ForegroundColor Green
    Write-Host "恢复清单：$ManifestPath"
    Write-Host "重新打开 Codex 会话后显示新名称。"
}
catch {
    Write-Host "Skill 中文化失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
