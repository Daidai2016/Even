# ==========================================
# Codex Design Git Status Tool V1.1
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

$ErrorActionPreference = "Stop"

try {
    # 根据当前脚本所在位置，动态计算仓库根目录。
    # 公司电脑：
    # D:\Codex_Design
    #
    # 家里电脑：
    # E:\AI_Workspace\Codex_Design

    $ProjectPath = (
        Resolve-Path `
            -LiteralPath (
                Join-Path $PSScriptRoot ".."
            )
    ).Path

    Write-Host ""
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host " Codex Design Git Status" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "当前项目：" -NoNewline
    Write-Host $ProjectPath -ForegroundColor Cyan
    Write-Host ""

    # 检查 Git 是否可用

    $GitCommand = Get-Command `
        "git" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        Write-Host "错误：未检测到 Git。" -ForegroundColor Red
        Write-Host "请先安装 Git，或检查 Git 是否已经加入 PATH。"
        exit 1
    }

    # 切换到项目根目录

    Set-Location -LiteralPath $ProjectPath

    # 检查当前目录是否为有效 Git 仓库

    $RepositoryCheck = @(
        & $GitCommand.Source `
            rev-parse `
            --is-inside-work-tree `
            2>&1
    )

    if (
        $LASTEXITCODE -ne 0 -or
        $RepositoryCheck.Count -eq 0 -or
        ([string]$RepositoryCheck[0]).Trim() -ne "true"
    ) {
        Write-Host "错误：当前项目目录不是有效的 Git 仓库。" -ForegroundColor Red
        Write-Host "检查目录：$ProjectPath"
        exit 1
    }

    Write-Host "Git状态：" -ForegroundColor Yellow

    & $GitCommand.Source status

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "错误：Git 状态检查失败。" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "Git 状态检查失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host ""
    [void](Read-Host "按 Enter 键继续...")
}