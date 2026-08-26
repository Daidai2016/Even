# ==================================================
# Codex Workstation One-click Sync V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==================================================

param(
    [switch]$CheckOnly,
    [switch]$SkipRepositoryUpdate,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$GitSyncPath = Join-Path $ProjectPath "tools\git_sync.ps1"
$CapabilitySyncPath = Join-Path $ProjectPath "tools\sync_codex_capabilities.ps1"


function Get-WindowsPowerShell {
    $Candidate = Join-Path `
        $env:SystemRoot `
        "System32\WindowsPowerShell\v1.0\powershell.exe"

    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        return $Candidate
    }

    $Command = Get-Command "powershell.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $Command) {
        throw "未检测到 Windows PowerShell。"
    }

    return $Command.Source
}


function Invoke-SyncScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "缺少同步脚本：$ScriptPath"
    }

    & $script:PowerShellExe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $ScriptPath `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "同步步骤失败：$(Split-Path -Leaf $ScriptPath)"
    }
}


try {
    $script:PowerShellExe = Get-WindowsPowerShell

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Skills 与插件一键同步" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "项目目录：$ProjectPath"

    if ($CheckOnly) {
        Write-Host "模式：只读检查（不会更新仓库）"
    }
    elseif ($SkipRepositoryUpdate) {
        Write-Host "模式：仅同步本机能力"
    }
    else {
        Write-Host "模式：安全更新仓库后同步本机能力"
    }

    if (-not $CheckOnly -and -not $SkipRepositoryUpdate) {
        Write-Host ""
        Write-Host "[1/2] 安全更新 Codex Design 仓库" -ForegroundColor Cyan
        Invoke-SyncScript `
            -ScriptPath $GitSyncPath `
            -Arguments @("-NoPause")

        $CapabilitySyncPath = Join-Path `
            $ProjectPath `
            "tools\sync_codex_capabilities.ps1"
    }
    else {
        Write-Host ""
        Write-Host "[1/2] 已跳过仓库更新" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "[2/2] 同步 Skills、插件与本机代理环境" `
        -ForegroundColor Cyan
    $Arguments = @("-NoPause")

    if ($CheckOnly) {
        $Arguments += "-CheckOnly"
    }

    Invoke-SyncScript `
        -ScriptPath $CapabilitySyncPath `
        -Arguments $Arguments

    Write-Host ""
    Write-Host "一键同步完成。" -ForegroundColor Green
    Write-Host "如果安装了新能力，请重新打开 Codex。" `
        -ForegroundColor DarkGray
}
catch {
    Write-Host ""
    Write-Host "一键同步失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
