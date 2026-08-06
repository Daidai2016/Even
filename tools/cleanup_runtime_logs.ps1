# ==========================================
# Codex Design 运行日志清理工具 V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# 功能：
# - 清理本地运行日志
# - 每类日志只保留最近指定数量
# - 默认每类保留最近 30 份
#
# 当前管理：
# - environment_check_*.txt
# - bootstrap_workspace_*.txt
#
# 安全原则：
# - 只操作项目根目录 logs 文件夹
# - 只删除符合指定命名规则的日志
# - 不删除目录
# - 不操作仓库中的其他文件
# ==========================================

[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Keep = 30,

    [switch]$Quiet
)

$ErrorActionPreference = "Stop"


# ==========================================
# 计算项目路径
# ==========================================

$ProjectPath = (
    Resolve-Path `
        -LiteralPath (
            Join-Path $PSScriptRoot ".."
        )
).Path

$LogsPath = Join-Path `
    $ProjectPath `
    "logs"


# ==========================================
# 日志目录不存在时直接结束
# ==========================================

if (
    -not (
        Test-Path `
            -LiteralPath $LogsPath `
            -PathType Container
    )
) {
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "日志目录不存在，无需清理。" -ForegroundColor Yellow
        Write-Host "目录：$LogsPath"
    }

    return
}


# ==========================================
# 日志保留规则
#
# 每个类型分别保留最近 Keep 份，
# 而不是所有类型合计保留 Keep 份。
# ==========================================

$CleanupRules = @(
    [PSCustomObject]@{
        Name   = "环境检查日志"
        Filter = "environment_check_*.txt"
        Keep   = $Keep
    },
    [PSCustomObject]@{
        Name   = "工作区恢复日志"
        Filter = "bootstrap_workspace_*.txt"
        Keep   = $Keep
    }
)


# ==========================================
# 安全路径基准
# ==========================================

$LogsRoot = (
    [System.IO.Path]::GetFullPath(
        $LogsPath
    )
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar


# ==========================================
# 执行清理
# ==========================================

$TotalRemoved = 0
$TotalRemaining = 0

if (-not $Quiet) {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Design 运行日志清理 V1.0.0" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "日志目录：$LogsPath"
    Write-Host "每类保留：最近 $Keep 份"
}

foreach ($Rule in $CleanupRules) {
    $LogFiles = @(
        Get-ChildItem `
            -LiteralPath $LogsPath `
            -Filter $Rule.Filter `
            -File `
            -ErrorAction SilentlyContinue |
            Sort-Object `
                -Property @(
                    @{
                        Expression = {
                            $_.LastWriteTimeUtc
                        }
                        Descending = $true
                    },
                    @{
                        Expression = {
                            $_.Name
                        }
                        Descending = $true
                    }
                )
    )

    $FilesToRemove = @(
        $LogFiles |
            Select-Object `
                -Skip $Rule.Keep
    )

    $RemovedForRule = 0

    foreach ($LogFile in $FilesToRemove) {
        $FullLogPath = [System.IO.Path]::GetFullPath(
            $LogFile.FullName
        )

        # 再次确认目标文件位于项目 logs 目录内。

        if (
            -not $FullLogPath.StartsWith(
                $LogsRoot,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        ) {
            throw "拒绝删除 logs 目录之外的文件：$FullLogPath"
        }

        # 再次确认文件名符合当前清理规则。

        if ($LogFile.Name -notlike $Rule.Filter) {
            throw "拒绝删除不符合日志规则的文件：$($LogFile.Name)"
        }

        Remove-Item `
            -LiteralPath $FullLogPath `
            -Force

        $RemovedForRule++
        $TotalRemoved++
    }

    $RemainingForRule = (
        $LogFiles.Count -
        $RemovedForRule
    )

    $TotalRemaining += $RemainingForRule

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "$($Rule.Name)" -ForegroundColor Yellow
        Write-Host "  找到：$($LogFiles.Count) 份"
        Write-Host "  删除：$RemovedForRule 份"
        Write-Host "  保留：$RemainingForRule 份"
    }
}


# ==========================================
# 输出摘要
# ==========================================

if (-not $Quiet) {
    Write-Host ""
    Write-Host "----------------------------------------------"
    Write-Host "清理完成。" -ForegroundColor Green
    Write-Host "共删除：$TotalRemoved 份"
    Write-Host "现保留：$TotalRemaining 份"
    Write-Host ""
}