# ==========================================
# Codex Global Configuration Hardening V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$UserProfilePath = [Environment]::GetFolderPath("UserProfile")

if ([string]::IsNullOrWhiteSpace($UserProfilePath)) {
    $UserProfilePath = [string]$env:USERPROFILE
}

if ([string]::IsNullOrWhiteSpace($UserProfilePath)) {
    throw "无法解析当前用户目录。"
}

$CodexHomePath = Join-Path $UserProfilePath ".codex"
$ConfigPath = Join-Path $CodexHomePath "config.toml"
$GlobalAgentsPath = Join-Path $CodexHomePath "AGENTS.md"
$GlobalAgentsTemplate = Join-Path `
    $PSScriptRoot `
    "templates\codex_global_AGENTS.md"


function Get-TomlSectionName {
    param([string]$Line)

    if ($Line -match "^\s*\[([^\]]+)\]\s*$") {
        return $Matches[1]
    }

    return ""
}


function Set-TopLevelTomlValue {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Key,
        [string]$Value
    )

    $SectionSeen = $false
    $Updated = $false

    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        if (-not [string]::IsNullOrWhiteSpace(
            (Get-TomlSectionName -Line $Lines[$Index])
        )) {
            $SectionSeen = $true
        }

        if (
            -not $SectionSeen -and
            $Lines[$Index] -match ("^\s*" + [regex]::Escape($Key) + "\s*=")
        ) {
            $Lines[$Index] = "$Key = $Value"
            $Updated = $true
            break
        }
    }

    if (-not $Updated) {
        $InsertIndex = 0

        while (
            $InsertIndex -lt $Lines.Count -and
            [string]::IsNullOrWhiteSpace(
                (Get-TomlSectionName -Line $Lines[$InsertIndex])
            )
        ) {
            $InsertIndex++
        }

        $Lines.Insert($InsertIndex, "$Key = $Value")
    }
}


function Remove-TomlSection {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$SectionName
    )

    $Output = New-Object "System.Collections.Generic.List[string]"
    $Skipping = $false

    foreach ($Line in $Lines) {
        $CurrentSection = Get-TomlSectionName -Line $Line

        if (-not [string]::IsNullOrWhiteSpace($CurrentSection)) {
            $Skipping = $CurrentSection.Equals(
                $SectionName,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }

        if (-not $Skipping) {
            [void]$Output.Add($Line)
        }
    }

    return ,$Output
}


function Set-WindowsSandboxUnelevated {
    param([System.Collections.Generic.List[string]]$Lines)

    $WindowsStart = -1
    $WindowsEnd = $Lines.Count

    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        $Section = Get-TomlSectionName -Line $Lines[$Index]

        if ($Section -eq "windows") {
            $WindowsStart = $Index
            continue
        }

        if ($WindowsStart -ge 0 -and -not [string]::IsNullOrWhiteSpace($Section)) {
            $WindowsEnd = $Index
            break
        }
    }

    if ($WindowsStart -lt 0) {
        [void]$Lines.Add("")
        [void]$Lines.Add("[windows]")
        [void]$Lines.Add('sandbox = "unelevated"')
        return
    }

    for ($Index = $WindowsStart + 1; $Index -lt $WindowsEnd; $Index++) {
        if ($Lines[$Index] -match "^\s*sandbox\s*=") {
            $Lines[$Index] = 'sandbox = "unelevated"'
            return
        }
    }

    $Lines.Insert($WindowsEnd, 'sandbox = "unelevated"')
}


try {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "未找到 Codex config.toml。"
    }

    if (-not (Test-Path -LiteralPath $GlobalAgentsTemplate -PathType Leaf)) {
        throw "缺少全局 AGENTS 模板。"
    }

    $Lines = New-Object "System.Collections.Generic.List[string]"

    foreach ($Line in Get-Content -LiteralPath $ConfigPath -Encoding UTF8) {
        [void]$Lines.Add([string]$Line)
    }

    $HomeProjectSection = "projects.'$($UserProfilePath.ToLowerInvariant())'"
    $Lines = Remove-TomlSection `
        -Lines $Lines `
        -SectionName $HomeProjectSection

    $Lines = Remove-TomlSection `
        -Lines $Lines `
        -SectionName "mcp_servers.adobe_illustrator"

    Set-TopLevelTomlValue `
        -Lines $Lines `
        -Key "approval_policy" `
        -Value '"on-request"'

    Set-TopLevelTomlValue `
        -Lines $Lines `
        -Key "approvals_reviewer" `
        -Value '"user"'

    Set-TopLevelTomlValue `
        -Lines $Lines `
        -Key "sandbox_mode" `
        -Value '"workspace-write"'

    Set-WindowsSandboxUnelevated -Lines $Lines

    $WorkspaceSection = "projects.'$($ProjectPath.ToLowerInvariant())'"
    $WorkspaceFound = $false

    foreach ($Line in $Lines) {
        $SectionName = [string](Get-TomlSectionName -Line $Line)

        if ($SectionName.Equals(
            $WorkspaceSection,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $WorkspaceFound = $true
            break
        }
    }

    if (-not $WorkspaceFound) {
        [void]$Lines.Add("")
        [void]$Lines.Add("[$WorkspaceSection]")
        [void]$Lines.Add('trust_level = "trusted"')
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupPath = Join-Path `
        $CodexHomePath `
        "config.toml.before_hardening_$Timestamp.bak"

    if ($PSCmdlet.ShouldProcess($ConfigPath, "收紧 Codex 全局配置")) {
        Copy-Item -LiteralPath $ConfigPath -Destination $BackupPath

        $TempPath = Join-Path `
            $CodexHomePath `
            "config.toml.hardening_$Timestamp.tmp"

        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $Content = ($Lines -join [Environment]::NewLine).TrimEnd() +
            [Environment]::NewLine

        [System.IO.File]::WriteAllText(
            $TempPath,
            $Content,
            $Utf8NoBom
        )

        Move-Item -LiteralPath $TempPath -Destination $ConfigPath -Force
    }

    $ShouldWriteGlobalAgents = $true

    if (Test-Path -LiteralPath $GlobalAgentsPath -PathType Leaf) {
        $ExistingAgentsText = Get-Content `
            -LiteralPath $GlobalAgentsPath `
            -Raw `
            -Encoding UTF8

        if (-not [string]::IsNullOrWhiteSpace($ExistingAgentsText)) {
            $ShouldWriteGlobalAgents = $false
        }
    }

    if (
        $ShouldWriteGlobalAgents -and
        $PSCmdlet.ShouldProcess($GlobalAgentsPath, "写入个人 Codex 安全规则")
    ) {
        Copy-Item `
            -LiteralPath $GlobalAgentsTemplate `
            -Destination $GlobalAgentsPath `
            -Force
    }

    if ($WhatIfPreference) {
        Write-Host "Codex 全局配置加固预检通过。" -ForegroundColor Green
        Write-Host "尚未写入配置或创建备份。"
    }
    else {
        Write-Host "Codex 全局配置加固完成。" -ForegroundColor Green
        Write-Host "已收紧：全用户目录信任、默认审批、默认沙箱、Windows 沙箱。"
        Write-Host "Adobe Illustrator MCP 已迁移到项目配置。"
        Write-Host "配置备份已保留在 Codex 本地目录中（路径不输出）。"
    }
}
catch {
    Write-Host "Codex 全局配置加固失败：$($_.Exception.Message)" `
        -ForegroundColor Red
    exit 1
}
