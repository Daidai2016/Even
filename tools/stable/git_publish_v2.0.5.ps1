# ==========================================
# Codex Design GitHub 安全发布 V2.0.5
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# 功能：
# 1. 获取远程仓库状态
# 2. 检查本地修改
# 3. 执行安全预检
# 4. 暂存全部确认过的修改
# 5. 创建 Git 提交
# 6. 推送到 GitHub
# 7. 验证本地与远程状态
#
# V2.0.5：
# - 修复 Windows PowerShell 5.1 单元素数组自动展开问题
# - 修复 Git 仓库被错误识别为无效仓库的问题
# - 修复 main、origin、单行 Git 输出可能被取成首字符的问题
# - 保留 UTF-8 中文 Git 输出支持
# - 保留 Windows PowerShell 5.1 原生命令兼容修复
# - 保留 Git 分页器禁用
#
# 安全原则：
# - 禁止 Git 使用分页器
# - 不执行 force push
# - 不执行 reset
# - 不执行 clean
# - 不执行 checkout 覆盖
# - 远程有新提交时停止发布
# - 检测到冲突时停止发布
# - 检测到格式错误时停止发布
# - 检测到删除文件时要求二次确认
# - 提交说明不能为空
# - 发布前后都会检查远程状态
# ==========================================


# ==========================================
# 严格错误处理
# ==========================================

$ErrorActionPreference = "Stop"


# ==========================================
# UTF-8 控制台环境
#
# Windows PowerShell 5.1 默认控制台编码
# 可能不是 UTF-8。
#
# Git 提交信息和 Git 日志默认使用 UTF-8，
# 如果 PowerShell 使用旧代码页解释，
# 中文可能出现乱码。
#
# 本设置只影响当前脚本运行过程：
# - 不修改 Windows 区域设置
# - 不修改注册表
# - 不修改 PowerShell Profile
# ==========================================

$script:Utf8Encoding = New-Object `
    System.Text.UTF8Encoding(
        $false
    )

try {
    [Console]::InputEncoding =
        $script:Utf8Encoding
}
catch {
    # 某些终端宿主不允许修改输入编码。
}

try {
    [Console]::OutputEncoding =
        $script:Utf8Encoding
}
catch {
    # 某些终端宿主不允许修改输出编码。
}

$OutputEncoding =
    $script:Utf8Encoding


# ==========================================
# 尝试将当前 Windows 控制台切换到 UTF-8
#
# 仅影响当前终端控制台。
# ==========================================

try {
    & chcp.com 65001 |
        Out-Null
}
catch {
    # chcp 失败不影响 Git 发布主流程。
}


# ==========================================
# 禁止 Git 使用分页器
#
# 防止：
# git diff
# git log
# git show
#
# 等命令进入 less 分页器，
# 导致 VS Code 任务停留在：
#
# :
#
# 页面。
# ==========================================

$env:GIT_PAGER = "cat"
$env:PAGER = "cat"


# ==========================================
# 输出步骤标题
# ==========================================

function Write-Step {
    param(
        [ValidateRange(1, 7)]
        [int]$Number,

        [string]$Title
    )

    Write-Host ""

    Write-Host `
        "[$Number/7] $Title" `
        -ForegroundColor Cyan

    Write-Host `
        "----------------------------------------------"
}


# ==========================================
# 安全停止发布
# ==========================================

function Stop-Publish {
    param(
        [string]$Message,

        [int]$ExitCode = 1
    )

    Write-Host ""

    Write-Host `
        "发布已停止。" `
        -ForegroundColor Yellow

    Write-Host `
        $Message `
        -ForegroundColor Yellow

    Write-Host ""

    exit $ExitCode
}


# ==========================================
# 执行 Git 命令
#
# Windows PowerShell 5.1 兼容说明：
#
# Git 的 fetch、push 等命令即使成功，
# 也可能把以下普通信息写到标准错误流：
#
# From https://github.com/...
# To https://github.com/...
#
# 当：
#
# $ErrorActionPreference = "Stop"
#
# 时，Windows PowerShell 5.1 可能把这些
# 普通信息转换成 PowerShell 异常。
#
# 因此：
#
# 1. Git 执行期间临时使用 Continue
# 2. 最终仍以 Git ExitCode 判断成功或失败
# 3. Git 日志输出使用 UTF-8
# 4. 中文路径关闭 quotePath 转义
# 5. 每条命令自动使用 --no-pager
# ==========================================

function Invoke-Git {
    param(
        [string[]]$Arguments = @()
    )

    # --------------------------------------
    # Git 临时配置
    #
    # 这些 -c 参数只影响当前 Git 命令，
    # 不修改用户的全局 Git 配置。
    # --------------------------------------

    $ActualArguments = @(
        "-c",
        "i18n.commitEncoding=utf-8",

        "-c",
        "i18n.logOutputEncoding=utf-8",

        "-c",
        "core.quotepath=false",

        "--no-pager"
    ) + $Arguments


    # --------------------------------------
    # PowerShell 7 兼容
    #
    # Windows PowerShell 5.1 通常没有：
    # PSNativeCommandUseErrorActionPreference
    #
    # 但保留检测可兼容以后升级。
    # --------------------------------------

    $HasNativePreference = $false
    $PreviousNativePreference = $null

    $NativePreferenceVariable = Get-Variable `
        -Name "PSNativeCommandUseErrorActionPreference" `
        -ErrorAction SilentlyContinue

    if ($null -ne $NativePreferenceVariable) {
        $HasNativePreference = $true

        $PreviousNativePreference =
            $PSNativeCommandUseErrorActionPreference
    }


    try {
        # ----------------------------------
        # 防止 Git 正常 stderr 输出
        # 被 PowerShell 5.1 当成终止异常。
        # ----------------------------------

        $ErrorActionPreference = "Continue"

        if ($HasNativePreference) {
            $PSNativeCommandUseErrorActionPreference =
                $false
        }


        # ----------------------------------
        # 执行 Git
        # ----------------------------------

        $Output = @(
            & $script:GitPath `
                @ActualArguments `
                2>&1
        )

        $ExitCode = $LASTEXITCODE

        if ($null -eq $ExitCode) {
            $ExitCode = 0
        }


        # ----------------------------------
        # 返回统一对象
        # ----------------------------------

        return [PSCustomObject]@{
            Output   = @($Output)
            ExitCode = [int]$ExitCode
            Threw    = $false
        }
    }
    catch {
        return [PSCustomObject]@{
            Output = @(
                [string]$_.Exception.Message
            )

            ExitCode = -1
            Threw    = $true
        }
    }
    finally {
        if ($HasNativePreference) {
            $PSNativeCommandUseErrorActionPreference =
                $PreviousNativePreference
        }
    }
}


# ==========================================
# 输出 Git 命令返回内容
# ==========================================

function Show-GitOutput {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Result
    )

    foreach ($Line in @($Result.Output)) {
        $LineText = [string]$Line

        if (
            -not [string]::IsNullOrWhiteSpace(
                $LineText
            )
        ) {
            Write-Host $LineText
        }
    }
}


# ==========================================
# 获取 Git 有效输出行
#
# 重要：
#
# Windows PowerShell 5.1 会自动展开
# 只有一个元素的数组。
#
# 因此调用本函数时必须使用：
#
# @(Get-NonEmptyGitOutput ...)
#
# 确保即使只有一行：
#
# true
# main
# origin-url
#
# 也始终得到数组，而不是字符串。
# ==========================================

function Get-NonEmptyGitOutput {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Result
    )

    $Lines = @(
        @($Result.Output) |
            ForEach-Object {
                [string]$_
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace(
                    $_
                )
            }
    )

    foreach ($Line in $Lines) {
        Write-Output $Line
    }
}


# ==========================================
# 获取 Git 输出的第一行
#
# 专门解决 PowerShell 5.1：
#
# 单行输出被当成字符串后，
# 使用 [0] 会得到第一个字符的问题。
#
# 例如：
#
# true
#
# 错误：
# $Value[0]
# → t
#
# 正确：
# 本函数始终先用 @() 强制数组化。
# ==========================================

function Get-FirstGitOutputLine {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Result
    )

    $Lines = @(
        Get-NonEmptyGitOutput `
            -Result $Result
    )

    if ($Lines.Count -eq 0) {
        return ""
    }

    return (
        [string]$Lines[0]
    ).Trim()
}


# ==========================================
# 读取本地领先和落后数量
#
# Ahead：
# 本地领先 origin 的提交数量
#
# Behind：
# 本地落后 origin 的提交数量
# ==========================================

function Get-AheadBehind {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    $Result = Invoke-Git `
        -Arguments @(
            "rev-list",
            "--left-right",
            "--count",
            "$BranchName...origin/$BranchName"
        )

    if ($Result.ExitCode -ne 0) {
        return $null
    }

    $OutputLines = @(
        Get-NonEmptyGitOutput `
            -Result $Result
    )

    if ($OutputLines.Count -eq 0) {
        return $null
    }

    $CountText = (
        [string]$OutputLines[0]
    ).Trim()

    $Parts = @(
        $CountText -split "\s+"
    )

    if ($Parts.Count -lt 2) {
        return $null
    }

    $Ahead = 0
    $Behind = 0

    $AheadParsed =
        [int]::TryParse(
            [string]$Parts[0],
            [ref]$Ahead
        )

    $BehindParsed =
        [int]::TryParse(
            [string]$Parts[1],
            [ref]$Behind
        )

    if (
        -not $AheadParsed -or
        -not $BehindParsed
    ) {
        return $null
    }

    return [PSCustomObject]@{
        Ahead  = $Ahead
        Behind = $Behind
    }
}


# ==========================================
# 主程序
# ==========================================

try {
    # ======================================
    # 动态计算项目路径
    #
    # 当前脚本：
    # tools\git_publish.ps1
    #
    # 项目根目录：
    # tools 的上一级目录
    # ======================================

    $ProjectPath = (
        Resolve-Path `
            -LiteralPath (
                Join-Path `
                    $PSScriptRoot `
                    ".."
            )
    ).Path

    Set-Location `
        -LiteralPath $ProjectPath


    # ======================================
    # 检查 Git
    # ======================================

    $GitCommand = Get-Command `
        "git.exe" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        $GitCommand = Get-Command `
            "git" `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    if ($null -eq $GitCommand) {
        Stop-Publish `
            -Message "未检测到 Git，请先安装或修复 Git。"
    }

    $script:GitPath =
        [string]$GitCommand.Source


    # ======================================
    # 检查是否为 Git 仓库
    # ======================================

    $RepositoryResult = Invoke-Git `
        -Arguments @(
            "rev-parse",
            "--is-inside-work-tree"
        )

    $RepositoryText =
        Get-FirstGitOutputLine `
            -Result $RepositoryResult

    if (
        $RepositoryResult.ExitCode -ne 0 -or
        $RepositoryText -ne "true"
    ) {
        Stop-Publish `
            -Message "当前目录不是有效的 Git 仓库：$ProjectPath"
    }


    # ======================================
    # 获取 Git 仓库根目录
    # ======================================

    $TopLevelResult = Invoke-Git `
        -Arguments @(
            "rev-parse",
            "--show-toplevel"
        )

    $GitTopLevel =
        Get-FirstGitOutputLine `
            -Result $TopLevelResult

    if (
        $TopLevelResult.ExitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace(
            $GitTopLevel
        )
    ) {
        Stop-Publish `
            -Message "无法读取 Git 仓库根目录。"
    }


    # ======================================
    # 获取当前分支
    # ======================================

    $BranchResult = Invoke-Git `
        -Arguments @(
            "branch",
            "--show-current"
        )

    $CurrentBranch =
        Get-FirstGitOutputLine `
            -Result $BranchResult

    if (
        $BranchResult.ExitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace(
            $CurrentBranch
        )
    ) {
        Stop-Publish `
            -Message "无法读取当前 Git 分支。"
    }


    # ======================================
    # 获取 origin 地址
    # ======================================

    $RemoteResult = Invoke-Git `
        -Arguments @(
            "remote",
            "get-url",
            "origin"
        )

    $RemoteUrl =
        Get-FirstGitOutputLine `
            -Result $RemoteResult

    if (
        $RemoteResult.ExitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace(
            $RemoteUrl
        )
    ) {
        Stop-Publish `
            -Message "未检测到 origin 远程仓库。"
    }


    # ======================================
    # 标题
    # ======================================

    Write-Host ""

    Write-Host `
        "==============================================" `
        -ForegroundColor Cyan

    Write-Host `
        " Codex Design GitHub 安全发布 V2.0.5" `
        -ForegroundColor Cyan

    Write-Host `
        "==============================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "项目目录：$ProjectPath"
    Write-Host "Git根目录：$GitTopLevel"
    Write-Host "当前分支：$CurrentBranch"
    Write-Host "远程仓库：$RemoteUrl"
    Write-Host "终端编码：UTF-8"


    # ======================================
    # 1/7 获取远程状态
    # ======================================

    Write-Step `
        -Number 1 `
        -Title "获取远程状态"


    # --------------------------------------
    # 禁止 Git 在终端中等待交互式账号输入。
    #
    # Windows Credential Manager
    # 已有凭据时仍可正常使用。
    # --------------------------------------

    $PreviousGitPrompt =
        $env:GIT_TERMINAL_PROMPT

    $env:GIT_TERMINAL_PROMPT = "0"

    try {
        $FetchResult = Invoke-Git `
            -Arguments @(
                "fetch",
                "origin",
                $CurrentBranch
            )
    }
    finally {
        $env:GIT_TERMINAL_PROMPT =
            $PreviousGitPrompt
    }

    Show-GitOutput `
        -Result $FetchResult

    if ($FetchResult.ExitCode -ne 0) {
        Stop-Publish `
            -Message "获取远程分支失败，请检查网络、代理或 GitHub 登录状态。"
    }


    # ======================================
    # 检查远程分支是否存在
    # ======================================

    $RemoteBranchResult = Invoke-Git `
        -Arguments @(
            "rev-parse",
            "--verify",
            "origin/$CurrentBranch"
        )

    if ($RemoteBranchResult.ExitCode -ne 0) {
        Stop-Publish `
            -Message "远程分支 origin/$CurrentBranch 不存在。"
    }


    # ======================================
    # 读取领先和落后数量
    # ======================================

    $InitialSyncState =
        Get-AheadBehind `
            -BranchName $CurrentBranch

    if ($null -eq $InitialSyncState) {
        Stop-Publish `
            -Message "无法计算本地与远程的提交差异。"
    }

    Write-Host `
        "本地领先远程：$($InitialSyncState.Ahead) 个提交"

    Write-Host `
        "本地落后远程：$($InitialSyncState.Behind) 个提交"

    if ($InitialSyncState.Behind -gt 0) {
        Stop-Publish `
            -Message "远程仓库已有新提交。请先运行“Codex Design 同步GitHub”，确认同步后再发布。"
    }


    # ======================================
    # 2/7 检查本地变化
    # ======================================

    Write-Step `
        -Number 2 `
        -Title "检查本地变化"

    $StatusResult = Invoke-Git `
        -Arguments @(
            "status",
            "--short",
            "--untracked-files=all"
        )

    if ($StatusResult.ExitCode -ne 0) {
        Stop-Publish `
            -Message "无法读取 Git 工作区状态。"
    }

    $StatusLines = @(
        Get-NonEmptyGitOutput `
            -Result $StatusResult
    )

    $HasWorkingChanges =
        $StatusLines.Count -gt 0


    # ======================================
    # 没有工作区修改
    # ======================================

    if (-not $HasWorkingChanges) {
        Write-Host `
            "没有发现未提交的文件变化。" `
            -ForegroundColor Green

        if ($InitialSyncState.Ahead -eq 0) {
            Write-Host ""

            Write-Host `
                "本地工作区与 GitHub 已经一致，无需发布。" `
                -ForegroundColor Green

            Write-Host ""

            exit 0
        }

        Write-Host ""

        Write-Host `
            "检测到本地已有 $($InitialSyncState.Ahead) 个提交尚未推送。" `
            -ForegroundColor Yellow
    }


    # ======================================
    # 有工作区修改
    # ======================================

    if ($HasWorkingChanges) {
        Write-Host `
            "发现 $($StatusLines.Count) 个变化文件："

        foreach ($StatusLine in $StatusLines) {
            $StatusText =
                [string]$StatusLine

            if ($StatusText.Length -ge 4) {
                $DisplayPath =
                    $StatusText.Substring(3)
            }
            else {
                $DisplayPath =
                    $StatusText
            }

            Write-Host `
                "  $DisplayPath"
        }

        Write-Host ""


        # ----------------------------------
        # 完整状态
        # ----------------------------------

        foreach ($StatusLine in $StatusLines) {
            Write-Host `
                ([string]$StatusLine)
        }


        # ==================================
        # 显示未暂存修改统计
        # ==================================

        $UnstagedStatResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--stat"
            )

        $UnstagedStatLines = @(
            Get-NonEmptyGitOutput `
                -Result $UnstagedStatResult
        )

        if ($UnstagedStatLines.Count -gt 0) {
            Write-Host ""
            Write-Host "未暂存修改统计："

            Show-GitOutput `
                -Result $UnstagedStatResult
        }


        # ==================================
        # 显示已暂存修改统计
        # ==================================

        $StagedStatResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--stat"
            )

        $StagedStatLines = @(
            Get-NonEmptyGitOutput `
                -Result $StagedStatResult
        )

        if ($StagedStatLines.Count -gt 0) {
            Write-Host ""
            Write-Host "已暂存修改统计："

            Show-GitOutput `
                -Result $StagedStatResult
        }


        # ==================================
        # 检查删除文件
        # ==================================

        $UnstagedDeletedResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--name-only",
                "--diff-filter=D"
            )

        $StagedDeletedResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--name-only",
                "--diff-filter=D"
            )

        $DeletedFiles = @()

        $DeletedFiles += @(
            Get-NonEmptyGitOutput `
                -Result $UnstagedDeletedResult
        )

        $DeletedFiles += @(
            Get-NonEmptyGitOutput `
                -Result $StagedDeletedResult
        )

        $DeletedFiles = @(
            $DeletedFiles |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Sort-Object -Unique
        )


        # ==================================
        # 删除文件二次确认
        # ==================================

        if ($DeletedFiles.Count -gt 0) {
            Write-Host ""

            Write-Host `
                "检测到以下文件将从仓库中删除：" `
                -ForegroundColor Yellow

            foreach ($DeletedFile in $DeletedFiles) {
                Write-Host `
                    "  $DeletedFile" `
                    -ForegroundColor Yellow
            }

            Write-Host ""

            $DeletionConfirmation = Read-Host `
                "确认这些删除都是预期操作吗？输入 YES 继续"

            $DeletionConfirmationText = (
                [string]$DeletionConfirmation
            ).Trim().ToUpperInvariant()

            if ($DeletionConfirmationText -ne "YES") {
                Stop-Publish `
                    -Message "用户未确认删除文件，没有执行暂存、提交或推送。"
            }
        }


        # ==================================
        # 总体发布确认
        # ==================================

        Write-Host ""

        $PublishConfirmation = Read-Host `
            "确认上述所有变化都需要发布吗？输入 YES 继续"

        $PublishConfirmationText = (
            [string]$PublishConfirmation
        ).Trim().ToUpperInvariant()

        if ($PublishConfirmationText -ne "YES") {
            Stop-Publish `
                -Message "用户取消发布，没有执行暂存、提交或推送。"
        }
    }


    # ======================================
    # 3/7 安全预检
    # ======================================

    Write-Step `
        -Number 3 `
        -Title "执行安全预检"

    if ($HasWorkingChanges) {
        # ==================================
        # 检查未解决冲突
        # ==================================

        $ConflictResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--name-only",
                "--diff-filter=U"
            )

        $ConflictFiles = @(
            Get-NonEmptyGitOutput `
                -Result $ConflictResult
        )

        if ($ConflictFiles.Count -gt 0) {
            Write-Host `
                "检测到未解决的冲突文件：" `
                -ForegroundColor Red

            foreach ($ConflictFile in $ConflictFiles) {
                Write-Host `
                    "  $ConflictFile" `
                    -ForegroundColor Red
            }

            Stop-Publish `
                -Message "请先解决 Git 冲突，再重新发布。"
        }

        Write-Host `
            "✓ 未发现 Git 冲突" `
            -ForegroundColor Green


        # ==================================
        # 检查未暂存内容格式
        # ==================================

        $WorkingTreeCheckResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--check"
            )

        if ($WorkingTreeCheckResult.ExitCode -ne 0) {
            Show-GitOutput `
                -Result $WorkingTreeCheckResult

            Stop-Publish `
                -Message "未暂存修改存在尾随空格或其他格式问题。"
        }

        Write-Host `
            "✓ 未暂存修改格式检查通过" `
            -ForegroundColor Green


        # ==================================
        # 检查已暂存内容格式
        # ==================================

        $IndexCheckResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--check"
            )

        if ($IndexCheckResult.ExitCode -ne 0) {
            Show-GitOutput `
                -Result $IndexCheckResult

            Stop-Publish `
                -Message "已暂存修改存在尾随空格或其他格式问题。"
        }

        Write-Host `
            "✓ 已暂存修改格式检查通过" `
            -ForegroundColor Green
    }
    else {
        Write-Host `
            "没有新的文件变化，跳过文件格式预检。"

        Write-Host `
            "将继续推送现有本地提交。"
    }


    # ======================================
    # 4/7 暂存修改
    # ======================================

    Write-Step `
        -Number 4 `
        -Title "暂存确认过的修改"

    if ($HasWorkingChanges) {
        # ==================================
        # git add --all
        # ==================================

        $AddResult = Invoke-Git `
            -Arguments @(
                "add",
                "--all"
            )

        Show-GitOutput `
            -Result $AddResult

        if ($AddResult.ExitCode -ne 0) {
            Stop-Publish `
                -Message "git add 执行失败，没有创建提交。"
        }


        # ==================================
        # 暂存后再次检查格式
        # ==================================

        $StagedCheckResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--check"
            )

        if ($StagedCheckResult.ExitCode -ne 0) {
            Show-GitOutput `
                -Result $StagedCheckResult

            Stop-Publish `
                -Message "暂存后的修改存在格式问题，没有创建提交。"
        }


        # ==================================
        # 检查是否确实有暂存内容
        # ==================================

        $StagedNameResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--name-only"
            )

        $StagedFiles = @(
            Get-NonEmptyGitOutput `
                -Result $StagedNameResult
        )

        if ($StagedFiles.Count -eq 0) {
            Stop-Publish `
                -Message "暂存后没有发现可提交内容。"
        }

        Write-Host `
            "已暂存 $($StagedFiles.Count) 个文件。" `
            -ForegroundColor Green


        # ==================================
        # 显示最终暂存状态
        # ==================================

        $StagedStatusResult = Invoke-Git `
            -Arguments @(
                "status",
                "--short"
            )

        Show-GitOutput `
            -Result $StagedStatusResult

        Write-Host ""
        Write-Host "最终提交统计："

        $FinalStatResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--stat"
            )

        Show-GitOutput `
            -Result $FinalStatResult
    }
    else {
        Write-Host `
            "没有新的文件变化，跳过 git add。"
    }


    # ======================================
    # 5/7 创建提交
    # ======================================

    Write-Step `
        -Number 5 `
        -Title "创建 Git 提交"

    if ($HasWorkingChanges) {
        Write-Host ""

        Write-Host `
            "提交说明支持中文，例如：" `
            -ForegroundColor DarkGray

        Write-Host `
            "  图标更新" `
            -ForegroundColor DarkGray

        Write-Host `
            "  优化 GitHub 发布工具" `
            -ForegroundColor DarkGray

        Write-Host `
            "  更新工作区配置" `
            -ForegroundColor DarkGray

        Write-Host ""


        # ==================================
        # 输入提交说明
        # ==================================

        $CommitMessage = Read-Host `
            "请输入本次提交说明"

        if (
            [string]::IsNullOrWhiteSpace(
                [string]$CommitMessage
            )
        ) {
            Stop-Publish `
                -Message "提交说明不能为空。修改仍然保持暂存状态，没有创建提交。"
        }

        $CommitMessage = (
            [string]$CommitMessage
        ).Trim()


        # ==================================
        # 创建提交
        # ==================================

        $CommitResult = Invoke-Git `
            -Arguments @(
                "commit",
                "-m",
                $CommitMessage
            )

        Show-GitOutput `
            -Result $CommitResult

        if ($CommitResult.ExitCode -ne 0) {
            Stop-Publish `
                -Message "Git 提交失败。文件仍保留在本地，请检查终端输出。"
        }

        Write-Host ""

        Write-Host `
            "✓ Git 提交创建成功" `
            -ForegroundColor Green


        # ==================================
        # 验证提交说明
        # ==================================

        $CommitSubjectResult = Invoke-Git `
            -Arguments @(
                "log",
                "-1",
                "--pretty=format:%s"
            )

        $CommitSubjectLines = @(
            Get-NonEmptyGitOutput `
                -Result $CommitSubjectResult
        )

        if (
            $CommitSubjectResult.ExitCode -eq 0 -and
            $CommitSubjectLines.Count -gt 0
        ) {
            Write-Host `
                "提交说明：$([string]$CommitSubjectLines[0])"
        }
    }
    else {
        Write-Host `
            "没有新的文件变化，跳过创建提交。"

        Write-Host `
            "将推送现有的本地提交。"
    }


    # ======================================
    # 6/7 推送到 GitHub
    # ======================================

    Write-Step `
        -Number 6 `
        -Title "推送到 GitHub"

    Write-Host `
        "推送前再次获取远程状态。"


    # ======================================
    # 再次 fetch
    # ======================================

    $PreviousGitPrompt =
        $env:GIT_TERMINAL_PROMPT

    $env:GIT_TERMINAL_PROMPT = "0"

    try {
        $FinalFetchResult = Invoke-Git `
            -Arguments @(
                "fetch",
                "origin",
                $CurrentBranch
            )
    }
    finally {
        $env:GIT_TERMINAL_PROMPT =
            $PreviousGitPrompt
    }

    Show-GitOutput `
        -Result $FinalFetchResult

    if ($FinalFetchResult.ExitCode -ne 0) {
        Stop-Publish `
            -Message "推送前无法获取远程状态。本地提交已经安全保留，尚未推送。"
    }


    # ======================================
    # 再次比较提交差异
    # ======================================

    $PrePushSyncState =
        Get-AheadBehind `
            -BranchName $CurrentBranch

    if ($null -eq $PrePushSyncState) {
        Stop-Publish `
            -Message "推送前无法计算本地与远程差异。本地提交已经安全保留。"
    }

    Write-Host `
        "本地领先远程：$($PrePushSyncState.Ahead) 个提交"

    Write-Host `
        "本地落后远程：$($PrePushSyncState.Behind) 个提交"


    # ======================================
    # 发布期间远程出现新提交
    # ======================================

    if ($PrePushSyncState.Behind -gt 0) {
        Stop-Publish `
            -Message "发布期间远程仓库出现了新提交。请先同步 GitHub；本地提交已经安全保留。"
    }


    # ======================================
    # 没有待推送提交
    # ======================================

    if ($PrePushSyncState.Ahead -eq 0) {
        Write-Host `
            "没有需要推送的本地提交。" `
            -ForegroundColor Green
    }


    # ======================================
    # 推送
    # ======================================

    if ($PrePushSyncState.Ahead -gt 0) {
        $PushResult = Invoke-Git `
            -Arguments @(
                "push",
                "origin",
                $CurrentBranch
            )

        Show-GitOutput `
            -Result $PushResult

        if ($PushResult.ExitCode -ne 0) {
            Stop-Publish `
                -Message "推送失败。本地提交已经安全保留，没有丢失。"
        }

        Write-Host ""

        Write-Host `
            "✓ GitHub 推送成功" `
            -ForegroundColor Green
    }


    # ======================================
    # 7/7 最终验证
    # ======================================

    Write-Step `
        -Number 7 `
        -Title "验证发布结果"


    # ======================================
    # 最终 fetch
    # ======================================

    $PreviousGitPrompt =
        $env:GIT_TERMINAL_PROMPT

    $env:GIT_TERMINAL_PROMPT = "0"

    try {
        $VerifyFetchResult = Invoke-Git `
            -Arguments @(
                "fetch",
                "origin",
                $CurrentBranch
            )
    }
    finally {
        $env:GIT_TERMINAL_PROMPT =
            $PreviousGitPrompt
    }

    if ($VerifyFetchResult.ExitCode -ne 0) {
        Write-Host `
            "无法执行最终远程验证，但刚才的推送命令已成功。" `
            -ForegroundColor Yellow
    }


    # ======================================
    # 最终同步状态
    # ======================================

    $FinalSyncState =
        Get-AheadBehind `
            -BranchName $CurrentBranch

    if ($null -ne $FinalSyncState) {
        Write-Host `
            "本地领先远程：$($FinalSyncState.Ahead) 个提交"

        Write-Host `
            "本地落后远程：$($FinalSyncState.Behind) 个提交"

        if (
            $FinalSyncState.Ahead -eq 0 -and
            $FinalSyncState.Behind -eq 0
        ) {
            Write-Host `
                "✓ 本地分支与 GitHub 完全同步" `
                -ForegroundColor Green
        }
        else {
            Write-Host `
                "⚠ 本地与远程仍存在提交差异，请检查。" `
                -ForegroundColor Yellow
        }
    }
    else {
        Write-Host `
            "⚠ 无法计算最终同步状态。" `
            -ForegroundColor Yellow
    }


    # ======================================
    # 查看最新提交
    # ======================================

    Write-Host ""
    Write-Host "最新提交："

    $LatestCommitResult = Invoke-Git `
        -Arguments @(
            "log",
            "-1",
            "--oneline"
        )

    Show-GitOutput `
        -Result $LatestCommitResult


    # ======================================
    # 查看最终工作区状态
    # ======================================

    $FinalStatusResult = Invoke-Git `
        -Arguments @(
            "status",
            "--short",
            "--untracked-files=all"
        )

    $FinalStatusLines = @(
        Get-NonEmptyGitOutput `
            -Result $FinalStatusResult
    )

    Write-Host ""

    if ($FinalStatusLines.Count -eq 0) {
        Write-Host `
            "✓ Git 工作区干净" `
            -ForegroundColor Green
    }
    else {
        Write-Host `
            "⚠ 发布完成后仍有本地变化：" `
            -ForegroundColor Yellow

        foreach ($FinalStatusLine in $FinalStatusLines) {
            Write-Host `
                ([string]$FinalStatusLine)
        }
    }


    # ======================================
    # 完成
    # ======================================

    Write-Host ""

    Write-Host `
        "==============================================" `
        -ForegroundColor Green

    Write-Host `
        " Codex Design GitHub 发布完成" `
        -ForegroundColor Green

    Write-Host `
        "==============================================" `
        -ForegroundColor Green

    Write-Host ""
}
catch {
    Write-Host ""

    Write-Host `
        "GitHub 发布工具发生异常：" `
        -ForegroundColor Red

    Write-Host `
        $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""

    Write-Host `
        "本地文件和本地提交不会被自动删除。" `
        -ForegroundColor Yellow

    Write-Host ""

    exit 1
}