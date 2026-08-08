# ==========================================
# Codex Design GitHub Sync Tool V2.2.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

param(
    [switch]$CheckOnly,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ProxyGuardScript = Join-Path $PSScriptRoot "lib\github_proxy_guard.ps1"

function Stop-Sync {
    param([string]$Message)

    Write-Host ""
    Write-Host $Message -ForegroundColor Red

    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }

    exit 1
}

try {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host " Codex Design GitHub 安全同步 V2.2.0" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Get-Command "git.exe" -ErrorAction SilentlyContinue)) {
        Stop-Sync -Message "错误：未检测到 Git。"
    }

    if (-not (Test-Path -LiteralPath $ProxyGuardScript -PathType Leaf)) {
        Stop-Sync -Message "错误：缺少 GitHub 代理门禁。"
    }

    . $ProxyGuardScript

    $InsideRepository = @(
        & git.exe -C $ProjectPath rev-parse --is-inside-work-tree 2>$null
    )

    if (
        $LASTEXITCODE -ne 0 -or
        $InsideRepository.Count -eq 0 -or
        ([string]$InsideRepository[0]).Trim() -ne "true"
    ) {
        Stop-Sync -Message "错误：当前项目不是有效 Git 仓库。"
    }

    $CurrentBranch = @(
        & git.exe -C $ProjectPath branch --show-current 2>$null
    )

    if (
        $LASTEXITCODE -ne 0 -or
        $CurrentBranch.Count -eq 0 -or
        ([string]$CurrentBranch[0]).Trim() -ne "main"
    ) {
        Stop-Sync -Message "同步已停止：当前分支不是 main。"
    }

    $Status = @(& git.exe -C $ProjectPath status --porcelain)

    if ($LASTEXITCODE -ne 0) {
        Stop-Sync -Message "无法读取 Git 工作区状态。"
    }

    if ($Status.Count -gt 0) {
        Stop-Sync -Message "同步已停止：检测到未提交修改。"
    }

    $GuardResult = Assert-GitHubProxy -ProjectPath $ProjectPath

    if (-not $GuardResult.Success) {
        Stop-Sync -Message $GuardResult.Message
    }

    $PreviousGitPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = "0"

    try {
        if ($CheckOnly) {
            Write-Host "正在通过已确认代理验证 GitHub 远程……" `
                -ForegroundColor Yellow

            & git.exe -C $ProjectPath `
                ls-remote --exit-code origin refs/heads/main |
                Out-Null

            if ($LASTEXITCODE -ne 0) {
                Stop-Sync -Message "GitHub 远程 main 当前不可访问。"
            }

            Write-Host "GitHub 代理与远程 main 验证通过。" `
                -ForegroundColor Green
            exit 0
        }

        Write-Host "正在获取远程 main……" -ForegroundColor Yellow
        & git.exe -C $ProjectPath fetch origin main

        if ($LASTEXITCODE -ne 0) {
            Stop-Sync -Message "获取远程 main 失败。"
        }

        $Divergence = @(
            & git.exe -C $ProjectPath `
                rev-list --left-right --count main...origin/main 2>$null
        )

        if ($LASTEXITCODE -ne 0 -or $Divergence.Count -eq 0) {
            Stop-Sync -Message "无法比较本地 main 与 origin/main。"
        }

        $CountParts = ([string]$Divergence[0]).Trim() -split "\s+"

        if ($CountParts.Count -ne 2) {
            Stop-Sync -Message "远程分支差异格式无法识别。"
        }

        $AheadCount = [int]$CountParts[0]
        $BehindCount = [int]$CountParts[1]

        if ($AheadCount -gt 0 -and $BehindCount -gt 0) {
            Stop-Sync -Message "同步已停止：本地与远程 main 已分叉。"
        }

        if ($AheadCount -gt 0) {
            Stop-Sync -Message "同步已停止：本地 main 领先 origin/main。"
        }

        if ($BehindCount -eq 0) {
            Write-Host "本地 main 已是最新版本。" -ForegroundColor Green
        }
        else {
            Write-Host "正在执行仅快进同步……" -ForegroundColor Yellow
            & git.exe -C $ProjectPath pull --ff-only origin main

            if ($LASTEXITCODE -ne 0) {
                Stop-Sync -Message "同步失败：仅快进更新未完成。"
            }
        }
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $PreviousGitPrompt
    }

    Write-Host ""
    & git.exe -C $ProjectPath status --short --branch

    if ($LASTEXITCODE -ne 0) {
        Stop-Sync -Message "同步后 Git 状态验证失败。"
    }

    Write-Host ""
    Write-Host "GitHub 同步完成。" -ForegroundColor Green
}
catch {
    Stop-Sync -Message "同步工具发生异常：$($_.Exception.Message)"
}

if (-not $NoPause) {
    Write-Host ""
    [void](Read-Host "按 Enter 键关闭窗口")
}
