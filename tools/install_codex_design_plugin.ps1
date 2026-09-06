# ==========================================
# Codex Design Local Plugin Installer V1.1.2
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

param(
    [ValidatePattern("^[A-Za-z0-9_-]+$")]
    [string]$PluginName = "codex-design-workflows",
    [switch]$CheckOnly,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\codex_cli.ps1")
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$MarketplaceName = "codex-design"
$PluginId = "$PluginName@$MarketplaceName"
$PluginManifestPath = Join-Path `
    $ProjectPath `
    "plugins\$PluginName\.codex-plugin\plugin.json"


function Invoke-CodexCommand {
    param([string[]]$Arguments)

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {
        # Windows PowerShell 5.1 会把原生命令写入 stderr 的普通警告
        # 包装成 ErrorRecord。这里仍以真实退出码判断成功与否。
        $ErrorActionPreference = "Continue"
        $Output = @(& $script:CodexExe @Arguments 2>$null)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return [pscustomobject]@{
        Output = $Output
        ExitCode = $ExitCode
    }
}


function Get-CodexJson {
    param([string[]]$Arguments)

    $Result = Invoke-CodexCommand -Arguments $Arguments

    if ($Result.ExitCode -ne 0) {
        throw "Codex 命令执行失败：$($Arguments -join ' ')"
    }

    return (($Result.Output -join [Environment]::NewLine) | ConvertFrom-Json)
}


try {
    $CodexVersion = Get-CodexVersionResult

    if (-not $CodexVersion.Success) {
        throw "Codex：$($CodexVersion.Value)"
    }

    $script:CodexExe = $CodexVersion.Path

    if (-not (Test-Path -LiteralPath $PluginManifestPath -PathType Leaf)) {
        throw "缺少插件 manifest：$PluginName"
    }

    $PluginManifest = Get-Content `
        -LiteralPath $PluginManifestPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    $ExpectedVersion = [string]$PluginManifest.version
    $PluginDisplayName = [string]$PluginManifest.interface.displayName

    if ([string]::IsNullOrWhiteSpace($PluginDisplayName)) {
        $PluginDisplayName = $PluginName
    }

    $MarketplaceData = Get-CodexJson -Arguments @(
        "plugin", "marketplace", "list", "--json"
    )

    $MarketplaceInstalled = @(
        $MarketplaceData.marketplaces |
            Where-Object { $_.name -eq $MarketplaceName }
    ).Count -gt 0

    if (-not $MarketplaceInstalled -and -not $CheckOnly) {
        $AddMarketplaceResult = Invoke-CodexCommand -Arguments @(
            "plugin", "marketplace", "add", $ProjectPath, "--json"
        )

        if ($AddMarketplaceResult.ExitCode -ne 0) {
            throw "无法添加本地插件市场。"
        }

        if ($AddMarketplaceResult.Output.Count -gt 0) {
            Write-Host ($AddMarketplaceResult.Output -join [Environment]::NewLine)
        }

        $MarketplaceInstalled = $true
    }

    $InstalledPlugin = $null

    if ($MarketplaceInstalled) {
        $PluginData = Get-CodexJson -Arguments @(
            "plugin", "list", "--available", "--json"
        )

        $InstalledPlugin = @(
            $PluginData.installed |
                Where-Object { $_.pluginId -eq $PluginId }
        ) | Select-Object -First 1
    }

    $PluginInstalled = $null -ne $InstalledPlugin
    $PluginCurrent = (
        $PluginInstalled -and
        [string]$InstalledPlugin.version -eq $ExpectedVersion
    )

    if ($CheckOnly) {
        Write-Host "本地插件市场：$(if ($MarketplaceInstalled) { '已配置' } else { '未配置' })"
        Write-Host "$PluginDisplayName：$(if ($PluginCurrent) { "已安装 V$ExpectedVersion" } elseif ($PluginInstalled) { '需要更新' } else { '未安装' })"

        if (-not $MarketplaceInstalled -or -not $PluginCurrent) {
            exit 1
        }

        exit 0
    }

    if ($PluginInstalled -and -not $PluginCurrent) {
        $RemoveResult = Invoke-CodexCommand -Arguments @(
            "plugin", "remove", $PluginId, "--json"
        )

        if ($RemoveResult.ExitCode -ne 0) {
            throw "无法移除旧版插件：$PluginDisplayName"
        }

        if ($RemoveResult.Output.Count -gt 0) {
            Write-Host ($RemoveResult.Output -join [Environment]::NewLine)
        }

        $PluginInstalled = $false
    }

    if (-not $PluginInstalled) {
        $AddPluginResult = Invoke-CodexCommand -Arguments @(
            "plugin", "add", $PluginId, "--json"
        )

        if ($AddPluginResult.ExitCode -ne 0) {
            throw "无法安装插件：$PluginDisplayName"
        }

        if ($AddPluginResult.Output.Count -gt 0) {
            Write-Host ($AddPluginResult.Output -join [Environment]::NewLine)
        }
    }

    Write-Host "$PluginDisplayName 已安装。" -ForegroundColor Green
    Write-Host "重新打开 Codex 会话后即可使用插件内的 Skills。"
}
catch {
    Write-Host "插件安装失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
