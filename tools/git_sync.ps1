# ==========================================
# Codex Design GitHub 安全同步工具
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

$ErrorActionPreference = "Stop"

function Stop-Sync {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )

    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""
    [void](Read-Host "按 Enter 键关闭窗口")
    exit $ExitCode
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git 命令执行失败：git $($Arguments -join ' ')"
    }
}

function Get-ConfiguredProxy {
    $ProxyCandidates = @(
        (& git config --get https.proxy 2>$null),
        (& git config --get http.proxy 2>$null),
        $env:HTTPS_PROXY,
        $env:HTTP_PROXY
    )

    foreach ($ProxyCandidate in $ProxyCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($ProxyCandidate)) {
            return $ProxyCandidate.Trim()
        }
    }

    return $null
}

function Test-ConfiguredProxy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProxyAddress
    )

    try {
        $ProxyUri = [Uri]$ProxyAddress
        $ProxyPort = $ProxyUri.Port

        if ([string]::IsNullOrWhiteSpace($ProxyUri.Host) -or $ProxyPort -le 0) {
            return $false
        }

        Write-Host ("代理服务器：{0}://{1}:{2}" -f $ProxyUri.Scheme, $ProxyUri.Host, $ProxyPort)

        return [bool](Test-NetConnection `
            -ComputerName $ProxyUri.Host `
            -Port $ProxyPort `
            -InformationLevel Quiet `
            -WarningAction SilentlyContinue)
    }
    catch {
        return $false
    }
}

try {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host " Codex Design GitHub 安全同步"
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""

    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    Set-Location -LiteralPath $ProjectPath

    Write-Host "项目目录：$ProjectPath"
    Write-Host ""

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Stop-Sync "未找到 Git，未执行任何同步操作。"
    }

    & git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        Stop-Sync "当前目录不是 Git 仓库，未执行任何同步操作。"
    }

    $RepositoryRoot = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        Stop-Sync "无法确认 Git 仓库根目录。"
    }

    if ([IO.Path]::GetFullPath($RepositoryRoot) -ne [IO.Path]::GetFullPath($ProjectPath)) {
        Stop-Sync "脚本所在项目与 Git 仓库根目录不一致，已停止。"
    }

    Write-Host "[1/5] 检查当前状态..." -ForegroundColor Yellow
    Invoke-Git -Arguments @("status", "--short", "--branch")

    $WorkingTreeChanges = @(& git status --porcelain --untracked-files=normal)
    if ($LASTEXITCODE -ne 0) {
        throw "无法检查工作区状态。"
    }

    $HasWorkingTreeChanges = ($WorkingTreeChanges.Count -gt 0)
    if ($HasWorkingTreeChanges) {
        Write-Host "检测到未提交修改：允许只读式 fetch 以更新远程状态，但将阻止 pull。" -ForegroundColor Yellow
    }

    $CurrentBranch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $CurrentBranch -ne "main") {
        Stop-Sync "当前分支不是 main（当前：$CurrentBranch），为避免同步错误分支，已停止。"
    }

    & git remote get-url origin *> $null
    if ($LASTEXITCODE -ne 0) {
        Stop-Sync "未找到 origin 远程仓库，已停止。"
    }

    Write-Host ""
    Write-Host "[2/5] 验证 GitHub 代理..." -ForegroundColor Yellow
    $ConfiguredProxy = Get-ConfiguredProxy
    if ([string]::IsNullOrWhiteSpace($ConfiguredProxy)) {
        Stop-Sync "未检测到 Git/HTTPS 代理配置。按项目规则不尝试直连 GitHub。"
    }

    if (-not (Test-ConfiguredProxy -ProxyAddress $ConfiguredProxy)) {
        Stop-Sync "当前代理服务器不可用或配置无法解析。已停止，不会绕过代理直连。"
    }

    Write-Host ""
    Write-Host "[3/5] 获取 origin 最新状态..." -ForegroundColor Yellow
    Invoke-Git -Arguments @("fetch", "origin")

    & git show-ref --verify --quiet refs/remotes/origin/main
    if ($LASTEXITCODE -ne 0) {
        Stop-Sync "远程分支 origin/main 不存在，已停止。"
    }

    Write-Host ""
    Write-Host "[4/5] 判断分支关系..." -ForegroundColor Yellow
    $Counts = ((& git rev-list --left-right --count HEAD...origin/main) -join " ").Trim() -split "\s+"
    if ($LASTEXITCODE -ne 0 -or $Counts.Count -ne 2) {
        throw "无法判断本地与 origin/main 的分支关系。"
    }

    $Ahead = [int]$Counts[0]
    $Behind = [int]$Counts[1]
    Write-Host "本地领先：$Ahead；本地落后：$Behind"

    if ($HasWorkingTreeChanges) {
        Stop-Sync "工作区不干净。已更新 origin 状态并阻止 pull；请先处理未提交修改。"
    }

    if ($Ahead -gt 0 -and $Behind -gt 0) {
        Stop-Sync "本地 main 与 origin/main 已分叉。未执行 pull；请人工检查后处理。"
    }

    if ($Ahead -gt 0) {
        Stop-Sync "本地 main 领先 origin/main。未执行 pull；请确认本地提交是否需要发布。" 0
    }

    if ($Behind -eq 0) {
        Stop-Sync "本地 main 已与 origin/main 同步，无需更新。" 0
    }

    Write-Host ""
    Write-Host "[5/5] 执行安全快进同步..." -ForegroundColor Yellow
    Invoke-Git -Arguments @("pull", "--ff-only", "origin", "main")

    Write-Host ""
    Invoke-Git -Arguments @("status", "--short", "--branch")
    Write-Host ""
    Write-Host "GitHub 同步完成。" -ForegroundColor Green
    Write-Host ""
    [void](Read-Host "按 Enter 键关闭窗口")
}
catch {
    Stop-Sync "同步失败：$($_.Exception.Message)"
}
