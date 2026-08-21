# ==========================================
# Codex Design Repository Git Setup V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

param(
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path


function Stop-Setup {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red

    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }

    exit 1
}


try {
    $GitCommand = Get-Command "git" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        Stop-Setup -Message "未检测到 Git。"
    }

    Set-Location -LiteralPath $ProjectPath

    & $GitCommand.Source rev-parse --is-inside-work-tree 2>$null |
        Out-Null

    if ($LASTEXITCODE -ne 0) {
        Stop-Setup -Message "当前项目目录不是有效 Git 仓库。"
    }

    $Settings = @(
        @("core.autocrlf", "false"),
        @("core.eol", "lf"),
        @("core.safecrlf", "true")
    )

    foreach ($Setting in $Settings) {
        & $GitCommand.Source config --local $Setting[0] $Setting[1]

        if ($LASTEXITCODE -ne 0) {
            Stop-Setup -Message "无法写入仓库级 Git 设置：$($Setting[0])"
        }
    }

    Write-Host ""
    Write-Host "Codex Design 仓库级 Git 设置已完成。" -ForegroundColor Green
    Write-Host "core.autocrlf=false"
    Write-Host "core.eol=lf"
    Write-Host "core.safecrlf=true"
    Write-Host ""
    Write-Host "设置只作用于当前仓库，不修改系统或其他项目。" `
        -ForegroundColor DarkGray
}
catch {
    Stop-Setup -Message "仓库级 Git 设置失败：$($_.Exception.Message)"
}

if (-not $NoPause) {
    Write-Host ""
    [void](Read-Host "按 Enter 键关闭窗口")
}
