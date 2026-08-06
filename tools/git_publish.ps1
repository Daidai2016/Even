# ==========================================
# Codex Design GitHub 安全发布工具 V2.0.1
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# 安全原则：
# 1. 只允许发布 main 分支
# 2. 不执行 force push
# 3. 不执行 reset、clean 或自动 stash
# 4. 不自动丢弃本地修改
# 5. 远程领先或分支分叉时停止
# 6. 发布前检查语法、配置、密钥和 Git LFS
# 7. 工作区干净但存在未推送提交时，允许安全推送
# ==========================================

$ErrorActionPreference = "Stop"


# ==========================================
# 基础输出函数
# ==========================================

function Write-Title {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Design GitHub 安全发布 V2.0.1" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
}


function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "----------------------------------------------"
}


function Stop-Publish {
    param(
        [string]$Message
    )

    throw $Message
}


function Pause-AndExit {
    param(
        [int]$ExitCode
    )

    Write-Host ""
    [void](Read-Host "按 Enter 键关闭窗口")
    exit $ExitCode
}


# ==========================================
# 获取项目中的全部变化文件
# ==========================================

function Get-ChangedFiles {
    $Files = @()

    $Files += @(
        & $script:GitExe `
            -c "core.quotepath=false" `
            diff `
            --name-only
    )

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法读取未暂存文件列表。"
    }

    $Files += @(
        & $script:GitExe `
            -c "core.quotepath=false" `
            diff `
            --cached `
            --name-only
    )

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法读取暂存区文件列表。"
    }

    $Files += @(
        & $script:GitExe `
            -c "core.quotepath=false" `
            ls-files `
            --others `
            --exclude-standard
    )

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法读取未跟踪文件列表。"
    }

    return @(
        $Files |
            ForEach-Object {
                ([string]$_).Trim()
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )
}


# ==========================================
# 获取尚未推送到 origin/main 的提交
# ==========================================

function Get-UnpushedCommits {
    $Commits = @(
        & $script:GitExe `
            -c "core.quotepath=false" `
            log `
            --oneline `
            "origin/main..HEAD"
    )

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法读取尚未推送的本地提交。"
    }

    return @(
        $Commits |
            ForEach-Object {
                ([string]$_).Trim()
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
    )
}


# ==========================================
# 安全执行普通 Git Push
#
# 只执行：
# git push origin main
#
# 不包含 force、reset、clean 或其他破坏性参数。
# ==========================================

function Invoke-SafePush {
    $PreviousGitPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = "0"

    [int]$PushExitCode = 1

    try {
        & $script:GitExe push origin main
        $PushExitCode = $LASTEXITCODE
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $PreviousGitPrompt
    }

    return $PushExitCode
}


# ==========================================
# 检查敏感文件名
# ==========================================

function Test-SensitiveFileNames {
    param(
        [string[]]$Files
    )

    $BlockedFiles = @()

    foreach ($File in $Files) {
        $NormalizedPath = $File.Replace("\", "/")
        $BaseName = [System.IO.Path]::GetFileName($NormalizedPath)

        $IsBlocked = $false

        if (
            $BaseName -match "^\.env($|\.)" -and
            $BaseName -notmatch "^\.env\.(example|sample|template)$"
        ) {
            $IsBlocked = $true
        }

        if (
            $BaseName -match "^(id_rsa|id_ed25519)(\.pub)?$"
        ) {
            $IsBlocked = $true
        }

        if (
            $BaseName -match "\.(pem|pfx|p12|key)$"
        ) {
            $IsBlocked = $true
        }

        if (
            $BaseName -match "^(credentials|secrets|token|auth)\.json$"
        ) {
            $IsBlocked = $true
        }

        if (
            $NormalizedPath -match "(^|/)\.codex/"
        ) {
            $IsBlocked = $true
        }

        if ($IsBlocked) {
            $BlockedFiles += $File
        }
    }

    if ($BlockedFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "检测到禁止发布的敏感文件：" -ForegroundColor Red

        foreach ($BlockedFile in $BlockedFiles) {
            Write-Host "  $BlockedFile" -ForegroundColor Red
        }

        Stop-Publish "请移除敏感文件，或把它们加入 .gitignore。"
    }

    Write-Host "敏感文件名检查：通过" -ForegroundColor Green
}


# ==========================================
# 检查文件内容中的疑似密钥
# ==========================================

function Test-SecretContent {
    param(
        [string[]]$Files
    )

    $TextExtensions = @(
        ".ps1",
        ".psm1",
        ".psd1",
        ".cmd",
        ".bat",
        ".md",
        ".txt",
        ".json",
        ".jsonc",
        ".js",
        ".jsx",
        ".jsxinc",
        ".svg",
        ".xml",
        ".yml",
        ".yaml",
        ".toml",
        ".ini",
        ".html",
        ".htm",
        ".css"
    )

    $TextBaseNames = @(
        ".editorconfig",
        ".gitattributes",
        ".gitignore"
    )

    $SecretPatterns = @(
        'sk-proj-[A-Za-z0-9_-]{20,}',
        'sk-[A-Za-z0-9_-]{20,}',
        'ilst_[A-Za-z0-9]{20,}',
        'ghp_[A-Za-z0-9]{20,}',
        'github_pat_[A-Za-z0-9_]{20,}',
        '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
        'ADOBE_ILLUSTRATOR_MCP_BEARER_TOKEN\s*=\s*[''"]?ilst_',
        '(?i)bearer\s+[A-Za-z0-9._-]{24,}'
    )

    $SuspiciousFiles = @()

    foreach ($File in $Files) {
        $FullPath = Join-Path $script:ProjectPath $File

        if (
            -not (
                Test-Path `
                    -LiteralPath $FullPath `
                    -PathType Leaf
            )
        ) {
            continue
        }

        $Extension = [System.IO.Path]::GetExtension(
            $FullPath
        ).ToLowerInvariant()

        $BaseName = [System.IO.Path]::GetFileName(
            $FullPath
        )

        $IsTextFile = (
            $TextExtensions -contains $Extension -or
            $TextBaseNames -contains $BaseName
        )

        if (-not $IsTextFile) {
            continue
        }

        try {
            $Content = Get-Content `
                -LiteralPath $FullPath `
                -Raw `
                -Encoding UTF8

            foreach ($Pattern in $SecretPatterns) {
                if ($Content -match $Pattern) {
                    $SuspiciousFiles += $File
                    break
                }
            }
        }
        catch {
            Stop-Publish "无法安全读取文件进行凭据检查：$File"
        }
    }

    $SuspiciousFiles = @(
        $SuspiciousFiles |
            Sort-Object -Unique
    )

    if ($SuspiciousFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "检测到疑似密钥、令牌或私钥内容：" -ForegroundColor Red

        foreach ($SuspiciousFile in $SuspiciousFiles) {
            Write-Host "  $SuspiciousFile" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "为避免泄露，脚本不会显示具体匹配内容。" -ForegroundColor Yellow

        Stop-Publish "请删除或脱敏敏感内容后再发布。"
    }

    Write-Host "敏感内容检查：通过" -ForegroundColor Green
}


# ==========================================
# 检查 PowerShell 文件语法
# ==========================================

function Test-PowerShellSyntax {
    param(
        [string[]]$Files
    )

    $PowerShellFiles = @(
        $Files |
            Where-Object {
                $_ -match "\.(ps1|psm1|psd1)$"
            }
    )

    if ($PowerShellFiles.Count -eq 0) {
        Write-Host "PowerShell语法检查：无相关修改，跳过"
        return
    }

    $AllErrors = @()

    foreach ($File in $PowerShellFiles) {
        $FullPath = Join-Path $script:ProjectPath $File

        if (
            -not (
                Test-Path `
                    -LiteralPath $FullPath `
                    -PathType Leaf
            )
        ) {
            continue
        }

        $ParseTokens = $null
        $ParseErrors = $null

        [System.Management.Automation.Language.Parser]::ParseFile(
            $FullPath,
            [ref]$ParseTokens,
            [ref]$ParseErrors
        ) | Out-Null

        if (
            $null -ne $ParseErrors -and
            $ParseErrors.Count -gt 0
        ) {
            foreach ($ParseError in $ParseErrors) {
                $LineNumber = $ParseError.Extent.StartLineNumber
                $Message = $ParseError.Message

                $AllErrors += "$File，第 $LineNumber 行：$Message"
            }
        }
    }

    if ($AllErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "PowerShell语法检查失败：" -ForegroundColor Red

        foreach ($ErrorText in $AllErrors) {
            Write-Host "  $ErrorText" -ForegroundColor Red
        }

        Stop-Publish "请修复 PowerShell 语法错误后再发布。"
    }

    Write-Host "PowerShell语法检查：通过" -ForegroundColor Green
}


# ==========================================
# 检查关键严格 JSON 文件
#
# settings.json 属于 JSONC，可以包含注释，
# 因此不使用 ConvertFrom-Json 检查。
# ==========================================

function Test-StrictJsonFiles {
    param(
        [string[]]$Files
    )

    $StrictJsonFiles = @(
        ".vscode/extensions.json",
        ".vscode/tasks.json",
        "tools/config/shortcut_config.json",
        "package.json",
        "package-lock.json"
    )

    $InvalidFiles = @()

    foreach ($File in $Files) {
        $NormalizedFile = $File.Replace("\", "/")

        if ($StrictJsonFiles -notcontains $NormalizedFile) {
            continue
        }

        $FullPath = Join-Path $script:ProjectPath $File

        if (
            -not (
                Test-Path `
                    -LiteralPath $FullPath `
                    -PathType Leaf
            )
        ) {
            continue
        }

        try {
            Get-Content `
                -LiteralPath $FullPath `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json |
                Out-Null
        }
        catch {
            $InvalidFiles += $File
        }
    }

    if ($InvalidFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "JSON格式检查失败：" -ForegroundColor Red

        foreach ($InvalidFile in $InvalidFiles) {
            Write-Host "  $InvalidFile" -ForegroundColor Red
        }

        Stop-Publish "请修复 JSON 格式错误后再发布。"
    }

    Write-Host "关键JSON配置检查：通过" -ForegroundColor Green
}


# ==========================================
# 检查 Git LFS 和大型文件
# ==========================================

function Test-LfsAndLargeFiles {
    param(
        [string[]]$Files
    )

    [int64]$LargeFileThreshold = 50MB

    $LfsFiles = @()
    $UnmanagedLargeFiles = @()

    foreach ($File in $Files) {
        $FullPath = Join-Path $script:ProjectPath $File

        if (
            -not (
                Test-Path `
                    -LiteralPath $FullPath `
                    -PathType Leaf
            )
        ) {
            continue
        }

        $AttributeOutput = @(
            & $script:GitExe `
                check-attr `
                filter `
                -- `
                $File
        )

        if ($LASTEXITCODE -ne 0) {
            Stop-Publish "Git 属性检查失败：$File"
        }

        $AttributeText = [string](
            $AttributeOutput |
                Select-Object -First 1
        )

        $UsesLfs = $AttributeText -match ":\s*filter:\s*lfs\s*$"

        if ($UsesLfs) {
            $LfsFiles += $File
        }

        $FileInfo = Get-Item `
            -LiteralPath $FullPath `
            -ErrorAction Stop

        if (
            $FileInfo.Length -ge $LargeFileThreshold -and
            -not $UsesLfs
        ) {
            $SizeMB = [math]::Round(
                $FileInfo.Length / 1MB,
                2
            )

            $UnmanagedLargeFiles += "$File（$SizeMB MB）"
        }
    }

    if ($UnmanagedLargeFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "检测到未使用 Git LFS 管理的大型文件：" -ForegroundColor Red

        foreach ($LargeFile in $UnmanagedLargeFiles) {
            Write-Host "  $LargeFile" -ForegroundColor Red
        }

        Stop-Publish "请先配置 Git LFS，再发布大型文件。"
    }

    if ($LfsFiles.Count -gt 0) {
        & $script:GitExe lfs version | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Stop-Publish "当前修改包含 Git LFS 文件，但未检测到可用的 Git LFS。"
        }

        Write-Host "Git LFS检查：通过，涉及 $($LfsFiles.Count) 个文件" -ForegroundColor Green
    }
    else {
        Write-Host "Git LFS检查：无相关修改"
    }
}


# ==========================================
# 主程序
# ==========================================

try {
    Write-Title

    # --------------------------------------
    # 动态确定仓库根目录
    # --------------------------------------

    $script:ProjectPath = (
        Resolve-Path `
            -LiteralPath (
                Join-Path $PSScriptRoot ".."
            )
    ).Path

    Set-Location -LiteralPath $script:ProjectPath

    Write-Host "项目目录：$script:ProjectPath"


    # --------------------------------------
    # 检查 Git
    # --------------------------------------

    $GitCommand = Get-Command `
        "git" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        Stop-Publish "未检测到 Git，请检查安装和 PATH。"
    }

    $script:GitExe = $GitCommand.Source


    # --------------------------------------
    # 检查仓库
    # --------------------------------------

    $RepositoryCheck = @(
        & $script:GitExe `
            rev-parse `
            --is-inside-work-tree `
            2>&1
    )

    $RepositoryExitCode = $LASTEXITCODE

    if (
        $RepositoryExitCode -ne 0 -or
        $RepositoryCheck.Count -eq 0 -or
        ([string]$RepositoryCheck[0]).Trim() -ne "true"
    ) {
        Stop-Publish "当前目录不是有效的 Git 仓库：$script:ProjectPath"
    }


    # --------------------------------------
    # 检查分支
    # --------------------------------------

    $CurrentBranchOutput = @(
        & $script:GitExe `
            rev-parse `
            --abbrev-ref `
            HEAD
    )

    $BranchExitCode = $LASTEXITCODE

    if (
        $BranchExitCode -ne 0 -or
        $CurrentBranchOutput.Count -eq 0
    ) {
        Stop-Publish "无法读取当前 Git 分支。"
    }

    $CurrentBranch = (
        [string](
            $CurrentBranchOutput |
                Select-Object -First 1
        )
    ).Trim()

    Write-Host "当前分支：$CurrentBranch"

    if ($CurrentBranch -ne "main") {
        Stop-Publish "安全发布工具只允许从 main 分支发布。当前分支：$CurrentBranch"
    }


    # --------------------------------------
    # 检查 origin
    # --------------------------------------

    $RemoteOutput = @(
        & $script:GitExe `
            remote `
            get-url `
            origin
    )

    $RemoteExitCode = $LASTEXITCODE

    if (
        $RemoteExitCode -ne 0 -or
        $RemoteOutput.Count -eq 0
    ) {
        Stop-Publish "未找到 Git 远程仓库 origin。"
    }

    $RemoteUrl = (
        [string](
            $RemoteOutput |
                Select-Object -First 1
        )
    ).Trim()

    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
        Stop-Publish "远程仓库 origin 地址为空。"
    }

    $SafeRemoteUrl = $RemoteUrl -replace "://[^/@]+@", "://***@"

    Write-Host "远程仓库：$SafeRemoteUrl"


    # ======================================
    # 第 1 步：获取远程状态
    # ======================================

    Write-Section "[1/7] 获取远程状态"

    $PreviousGitPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = "0"

    [int]$FetchExitCode = 1

    try {
        & $script:GitExe fetch origin main
        $FetchExitCode = $LASTEXITCODE
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $PreviousGitPrompt
    }

    if ($FetchExitCode -ne 0) {
        Stop-Publish "无法连接 GitHub 或获取 origin/main。请检查网络代理。"
    }

    $OriginCheck = @(
        & $script:GitExe `
            rev-parse `
            --verify `
            origin/main `
            2>&1
    )

    $OriginExitCode = $LASTEXITCODE

    if ($OriginExitCode -ne 0) {
        Stop-Publish "未找到远程分支 origin/main。"
    }

    $AheadBehindOutput = @(
        & $script:GitExe `
            rev-list `
            --left-right `
            --count `
            "HEAD...origin/main"
    )

    $AheadBehindExitCode = $LASTEXITCODE

    if (
        $AheadBehindExitCode -ne 0 -or
        $AheadBehindOutput.Count -eq 0
    ) {
        Stop-Publish "无法比较本地 main 与 origin/main。"
    }

    $AheadBehindText = (
        [string](
            $AheadBehindOutput |
                Select-Object -First 1
        )
    ).Trim()

    $AheadBehindParts = $AheadBehindText -split "\s+"

    if ($AheadBehindParts.Count -lt 2) {
        Stop-Publish "无法解析本地与远程分支差异。"
    }

    [int]$AheadCount = $AheadBehindParts[0]
    [int]$BehindCount = $AheadBehindParts[1]

    Write-Host "本地领先远程：$AheadCount 个提交"
    Write-Host "本地落后远程：$BehindCount 个提交"

    if ($BehindCount -gt 0) {
        if ($AheadCount -gt 0) {
            Stop-Publish "本地和远程已经分叉。脚本不会自动合并、reset 或 force push。"
        }

        Stop-Publish "远程 main 有新提交。请先运行同步工具，再发布本地修改。"
    }


    # ======================================
    # 第 2 步：检查本地变化
    # ======================================

    Write-Section "[2/7] 检查本地变化"

    $ChangedFiles = @(Get-ChangedFiles)

    if ($AheadCount -gt 0) {
        $ExistingUnpushedCommits = @(Get-UnpushedCommits)

        Write-Host "发现尚未推送到 GitHub 的本地提交：" -ForegroundColor Yellow

        foreach ($Commit in $ExistingUnpushedCommits) {
            Write-Host "  $Commit"
        }

        Write-Host ""
    }


    # ======================================
    # 核心修复：
    # 工作区没有文件变化，但本地存在未推送提交
    # ======================================

    if ($ChangedFiles.Count -eq 0) {
        if ($AheadCount -eq 0) {
            Write-Host "工作区干净，本地与 GitHub 已同步。" -ForegroundColor Green
            Write-Host "没有需要提交或推送的内容。" -ForegroundColor Green

            Pause-AndExit 0
        }

        Write-Host "工作区当前没有未提交修改。" -ForegroundColor Green
        Write-Host "但本地仍有 $AheadCount 个提交尚未推送到 GitHub。" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "脚本将只执行：" -ForegroundColor Cyan
        Write-Host "git push origin main"
        Write-Host ""
        Write-Host "不会创建新提交，也不会执行 force push、reset 或 clean。" -ForegroundColor Yellow

        $PushOnlyConfirm = Read-Host "确认推送以上本地提交？请输入 PUSH"

        if ($PushOnlyConfirm -cne "PUSH") {
            Write-Host ""
            Write-Host "已取消推送。" -ForegroundColor Yellow
            Write-Host "本地提交仍然保留，没有发生任何修改。" -ForegroundColor Yellow

            Pause-AndExit 0
        }

        Write-Section "[3/3] 推送已有本地提交"

        $PushOnlyExitCode = Invoke-SafePush

        if ($PushOnlyExitCode -ne 0) {
            Write-Host ""
            Write-Host "GitHub推送失败。" -ForegroundColor Red
            Write-Host "已有本地提交仍然保留，没有自动撤销或重置。" -ForegroundColor Yellow
            Write-Host "请检查网络、远程更新或 GitHub 权限后重新运行发布工具。" -ForegroundColor Yellow

            Pause-AndExit 1
        }

        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Green
        Write-Host " 已有本地提交成功推送到 GitHub" -ForegroundColor Green
        Write-Host "==============================================" -ForegroundColor Green
        Write-Host ""

        & $script:GitExe log -1 --oneline

        Write-Host ""
        & $script:GitExe status

        Pause-AndExit 0
    }


    # ======================================
    # 显示本地文件变化
    # ======================================

    Write-Host "发现 $($ChangedFiles.Count) 个变化文件："

    foreach ($ChangedFile in $ChangedFiles) {
        Write-Host "  $ChangedFile"
    }

    Write-Host ""
    & $script:GitExe status --short

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法读取 Git 简要状态。"
    }

    Write-Host ""
    Write-Host "未暂存修改统计："

    & $script:GitExe diff --stat

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法生成未暂存修改统计。"
    }

    Write-Host ""
    Write-Host "已暂存修改统计："

    & $script:GitExe diff --cached --stat

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "无法生成暂存区修改统计。"
    }


    # ======================================
    # 第 3 步：安全预检
    # ======================================

    Write-Section "[3/7] 执行安全预检"

    Test-SensitiveFileNames `
        -Files $ChangedFiles

    Test-SecretContent `
        -Files $ChangedFiles

    Test-PowerShellSyntax `
        -Files $ChangedFiles

    Test-StrictJsonFiles `
        -Files $ChangedFiles

    Test-LfsAndLargeFiles `
        -Files $ChangedFiles

    & $script:GitExe diff --check

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "Git diff 检测到尾随空格、冲突标记或格式问题。"
    }

    & $script:GitExe diff --cached --check

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "暂存区检测到尾随空格、冲突标记或格式问题。"
    }

    Write-Host "Git差异检查：通过" -ForegroundColor Green


    # ======================================
    # 第 4 步：输入提交说明
    # ======================================

    Write-Section "[4/7] 输入提交说明"

    Write-Host "提交说明应清楚描述本次修改。"
    Write-Host "示例：Fix publishing of existing local commits"
    Write-Host "示例：Update documented local automation environment"
    Write-Host ""

    $CommitMessage = (
        Read-Host "请输入提交说明"
    ).Trim()

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        Stop-Publish "提交说明不能为空。"
    }

    if ($CommitMessage.Length -lt 6) {
        Stop-Publish "提交说明过短，请写清楚具体修改内容。"
    }

    $GenericMessages = @(
        "test",
        "update",
        "change",
        "changes",
        "fix",
        "sync",
        "修改",
        "更新",
        "提交"
    )

    if (
        $GenericMessages -contains
        $CommitMessage.ToLowerInvariant()
    ) {
        Stop-Publish "提交说明过于模糊，请描述实际修改内容。"
    }


    # ======================================
    # 第 5 步：暂存文件
    # ======================================

    Write-Section "[5/7] 暂存文件"

    $StageConfirm = Read-Host "确认暂存全部显示的修改？输入 Y 继续"

    if ($StageConfirm -notmatch "^[Yy]$") {
        Write-Host ""
        Write-Host "已取消发布，没有执行提交或推送。" -ForegroundColor Yellow

        Pause-AndExit 0
    }

    & $script:GitExe add --all

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "git add 执行失败。"
    }

    $StagedFiles = @(
        & $script:GitExe `
            -c "core.quotepath=false" `
            diff `
            --cached `
            --name-only
    )

    $StagedExitCode = $LASTEXITCODE

    if (
        $StagedExitCode -ne 0 -or
        $StagedFiles.Count -eq 0
    ) {
        Stop-Publish "暂存区为空，没有可提交内容。"
    }

    & $script:GitExe diff --cached --check

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "暂存后的内容存在格式问题，已停止提交。"
    }

    Write-Host "暂存完成。" -ForegroundColor Green


    # ======================================
    # 第 6 步：最终确认
    # ======================================

    Write-Section "[6/7] 最终确认"

    Write-Host "即将提交以下文件：" -ForegroundColor Cyan

    foreach ($StagedFile in $StagedFiles) {
        Write-Host "  $StagedFile"
    }

    Write-Host ""
    & $script:GitExe diff --cached --stat

    Write-Host ""
    Write-Host "提交说明：$CommitMessage"
    Write-Host "目标分支：origin/main"

    if ($AheadCount -gt 0) {
        Write-Host ""
        Write-Host "注意：提交前已有 $AheadCount 个本地提交尚未推送。" -ForegroundColor Yellow
        Write-Host "本次推送会同时发布这些已有提交和即将创建的新提交。" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "脚本不会执行 force push、reset、clean 或自动丢弃修改。" -ForegroundColor Yellow

    $FinalConfirm = Read-Host "确认提交并推送？请输入 PUBLISH"

    if ($FinalConfirm -cne "PUBLISH") {
        Write-Host ""
        Write-Host "已取消提交和推送。" -ForegroundColor Yellow
        Write-Host "文件仍保留在暂存区，没有丢失。" -ForegroundColor Yellow

        Pause-AndExit 0
    }


    # ======================================
    # 第 7 步：提交与推送
    # ======================================

    Write-Section "[7/7] 提交并推送 GitHub"

    & $script:GitExe commit -m $CommitMessage

    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "git commit 执行失败。"
    }

    Write-Host ""
    Write-Host "本地提交成功，正在推送 GitHub……" -ForegroundColor Cyan

    $PushExitCode = Invoke-SafePush

    if ($PushExitCode -ne 0) {
        Write-Host ""
        Write-Host "GitHub推送失败。" -ForegroundColor Red
        Write-Host "本地提交已经保留，不会自动撤销或重置。" -ForegroundColor Yellow
        Write-Host "请检查网络、远程更新或 GitHub 权限后重新运行发布工具。" -ForegroundColor Yellow

        Pause-AndExit 1
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " GitHub发布完成" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""

    & $script:GitExe log -1 --oneline

    Write-Host ""
    & $script:GitExe status

    Pause-AndExit 0
}
catch {
    Write-Host ""
    Write-Host "发布已停止：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "未执行 force push、reset、clean 或自动丢弃修改。" -ForegroundColor Yellow

    Pause-AndExit 1
}