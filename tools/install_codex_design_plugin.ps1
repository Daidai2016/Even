# ==========================================
# Codex Design Local Plugin Installer V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

param(
    [switch]$CheckOnly,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$MarketplaceName = "codex-design"
$PluginId = "codex-design-workflows@codex-design"
$PluginManifestPath = Join-Path `
    $ProjectPath `
    "plugins\codex-design-workflows\.codex-plugin\plugin.json"


function Get-CodexJson {
    param([string[]]$Arguments)

    $Output = @(& $script:CodexExe @Arguments 2>$null)
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        throw "Codex 命令执行失败：$($Arguments -join ' ')"
    }

    return (($Output -join [Environment]::NewLine) | ConvertFrom-Json)
}


try {
    $CodexCommand = Get-Command "codex.cmd" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $CodexCommand) {
        throw "未检测到 codex.cmd。"
    }

    $script:CodexExe = $CodexCommand.Source

    if (-not (Test-Path -LiteralPath $PluginManifestPath -PathType Leaf)) {
        throw "缺少 Codex Design 工作流插件 manifest。"
    }

    $PluginManifest = Get-Content `
        -LiteralPath $PluginManifestPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    $ExpectedVersion = [string]$PluginManifest.version

    $MarketplaceData = Get-CodexJson -Arguments @(
        "plugin", "marketplace", "list", "--json"
    )

    $MarketplaceInstalled = @(
        $MarketplaceData.marketplaces |
            Where-Object { $_.name -eq $MarketplaceName }
    ).Count -gt 0

    if (-not $MarketplaceInstalled -and -not $CheckOnly) {
        & $script:CodexExe `
            plugin marketplace add $ProjectPath --json

        if ($LASTEXITCODE -ne 0) {
            throw "无法添加本地插件市场。"
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
        Write-Host "工作流插件：$(if ($PluginCurrent) { "已安装 V$ExpectedVersion" } elseif ($PluginInstalled) { '需要更新' } else { '未安装' })"

        if (-not $MarketplaceInstalled -or -not $PluginCurrent) {
            exit 1
        }

        exit 0
    }

    if ($PluginInstalled -and -not $PluginCurrent) {
        & $script:CodexExe plugin remove $PluginId --json

        if ($LASTEXITCODE -ne 0) {
            throw "无法移除旧版 Codex Design 工作流插件。"
        }

        $PluginInstalled = $false
    }

    if (-not $PluginInstalled) {
        & $script:CodexExe plugin add $PluginId --json

        if ($LASTEXITCODE -ne 0) {
            throw "无法安装 Codex Design 工作流插件。"
        }
    }

    Write-Host "Codex Design 工作流插件已安装。" -ForegroundColor Green
    Write-Host "重新打开 Codex 会话后即可使用 promote-creative-workflow skill。"
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
