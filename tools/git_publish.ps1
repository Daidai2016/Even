# ==========================================
# Codex Design GitHub 安全发布 V2.0.3
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
# 安全原则：
# - 禁止 Git 使用分页器
# - 兼容 Windows PowerShell 5.1
# - 不执行 force push
# - 不执行 reset、clean 或 checkout 覆盖
# - 远程有新提交时停止发布
# - 检测到冲突时停止发布
# - 检测到格式错误时停止发布
# - 检测到删除文件时要求二次确认
# - 提交说明不能为空
# ==========================================

$ErrorActionPreference = "Stop"


# ==========================================
# 禁止 Git 使用分页器
#
# 防止 git diff、git log 等命令进入 less，
# 导致 VS Code 任务停留在“:”页面。
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
    Write-Host "[$Number/7] $Title" -ForegroundColor Cyan
    Write-Host "----------------------------------------------"
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
    Write-Host "发布已停止。" -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""

    exit $ExitCode
}


# ==========================================
# 执行 Git 命令
#
# Windows PowerShell 5.1 兼容说明：
#
# Git 的 fetch、push 等命令即使执行成功，
# 也会把 From、进度等普通信息写入标准错误流。
#
# 全局 ErrorActionPreference 为 Stop 时，
# Windows PowerShell 5.1 可能把这些普通信息
# 转换成 PowerShell 异常。
#
# 因此，本函数执行 Git 时临时使用 Continue，
# 最终仍根据 Git 的退出代码判断是否成功。
#
# 每条命令还会自动添加 --no-pager，
# 防止 Git 打开 less 分页器。
# ==========================================

function Invoke-Git {
    param(
        [string[]]$Arguments = @()
    )

    $ActualArguments = @(
        "--no-pager"
    ) + $Arguments

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
        $ErrorActionPreference = "Continue"

        if ($HasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $false
        }

        $Output = @(
            & $script:GitPath @ActualArguments 2>&1
        )

        $ExitCode = $LASTEXITCODE

        if ($null -eq $ExitCode) {
            $ExitCode = 0
        }

        return [PSCustomObject]@{
            Output   = $Output
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
# 读取本地领先和落后数量
#
# 返回：
# Ahead  = 本地领先远程的提交数
# Behind = 本地落后远程的提交数
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

    $CountText = (
        [string](
            $Result.Output |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Select-Object -First 1
        )
    ).Trim()

    $Parts = @(
        $CountText -split "\s+"
    )

    if ($Parts.Count -lt 2) {
        return $null
    }

    $Ahead = 0
    $Behind = 0

    $AheadParsed = [int]::TryParse(
        [string]$Parts[0],
        [ref]$Ahead
    )

    $BehindParsed = [int]::TryParse(
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
    # --------------------------------------
    # 动态计算项目路径
    # --------------------------------------

    $ProjectPath = (
        Resolve-Path `
            -LiteralPath (
                Join-Path $PSScriptRoot ".."
            )
    ).Path

    Set-Location -LiteralPath $ProjectPath


    # --------------------------------------
    # 检查 Git
    # --------------------------------------

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

    $script:GitPath = [string]$GitCommand.Source


    # --------------------------------------
    # 检查是否为 Git 仓库
    # --------------------------------------

    $RepositoryResult = Invoke-Git `
        -Arguments @(
            "rev-parse",
            "--is-inside-work-tree"
        )

    $RepositoryText = (
        [string](
            $RepositoryResult.Output |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Select-Object -First 1
        )
    ).Trim()

    if (
        $RepositoryResult.ExitCode -ne 0 -or
        $RepositoryText -ne "true"
    ) {
        Stop-Publish `
            -Message "当前目录不是有效的 Git 仓库：$ProjectPath"
    }


    # --------------------------------------
    # 获取当前分支
    # --------------------------------------

    $BranchResult = Invoke-Git `
        -Arguments @(
            "branch",
            "--show-current"
        )

    $CurrentBranch = (
        [string](
            $BranchResult.Output |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Select-Object -First 1
        )
    ).Trim()

    if (
        $BranchResult.ExitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace(
            $CurrentBranch
        )
    ) {
        Stop-Publish `
            -Message "无法读取当前 Git 分支。"
    }


    # --------------------------------------
    # 获取 origin 地址
    # --------------------------------------

    $RemoteResult = Invoke-Git `
        -Arguments @(
            "remote",
            "get-url",
            "origin"
        )

    $RemoteUrl = (
        [string](
            $RemoteResult.Output |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Select-Object -First 1
        )
    ).Trim()

    if (
        $RemoteResult.ExitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace(
            $RemoteUrl
        )
    ) {
        Stop-Publish `
            -Message "未检测到 origin 远程仓库。"
    }


    # --------------------------------------
    # 标题
    # --------------------------------------

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Design GitHub 安全发布 V2.0.3" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "项目目录：$ProjectPath"
    Write-Host "当前分支：$CurrentBranch"
    Write-Host "远程仓库：$RemoteUrl"


    # ======================================
    # 1/7 获取远程状态
    # ======================================

    Write-Step `
        -Number 1 `
        -Title "获取远程状态"

    $FetchResult = Invoke-Git `
        -Arguments @(
            "fetch",
            "origin",
            $CurrentBranch
        )

    Show-GitOutput `
        -Result $FetchResult

    if ($FetchResult.ExitCode -ne 0) {
        Stop-Publish `
            -Message "获取远程分支失败，请检查网络、代理或 GitHub 登录状态。"
    }


    # --------------------------------------
    # 检查远程分支是否存在
    # --------------------------------------

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


    # --------------------------------------
    # 读取领先和落后数量
    # --------------------------------------

    $InitialSyncState = Get-AheadBehind `
        -BranchName $CurrentBranch

    if ($null -eq $InitialSyncState) {
        Stop-Publish `
            -Message "无法计算本地与远程的提交差异。"
    }

    Write-Host "本地领先远程：$($InitialSyncState.Ahead) 个提交"
    Write-Host "本地落后远程：$($InitialSyncState.Behind) 个提交"

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
        $StatusResult.Output |
            ForEach-Object {
                [string]$_
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace(
                    $_
                )
            }
    )

    $HasWorkingChanges =
        $StatusLines.Count -gt 0

    if (-not $HasWorkingChanges) {
        Write-Host "没有发现未提交的文件变化。" -ForegroundColor Green

        if ($InitialSyncState.Ahead -eq 0) {
            Write-Host ""
            Write-Host "本地工作区与 GitHub 已经一致，无需发布。" -ForegroundColor Green
            Write-Host ""

            exit 0
        }

        Write-Host ""
        Write-Host "检测到本地已有 $($InitialSyncState.Ahead) 个提交尚未推送。" -ForegroundColor Yellow
    }
    else {
        Write-Host "发现 $($StatusLines.Count) 个变化文件："

        foreach ($StatusLine in $StatusLines) {
            if ($StatusLine.Length -ge 4) {
                $DisplayPath =
                    $StatusLine.Substring(3)
            }
            else {
                $DisplayPath = $StatusLine
            }

            Write-Host "  $DisplayPath"
        }

        Write-Host ""

        foreach ($StatusLine in $StatusLines) {
            Write-Host $StatusLine
        }


        # ----------------------------------
        # 显示未暂存修改统计
        # ----------------------------------

        $UnstagedStatResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--stat"
            )

        $UnstagedStatLines = @(
            $UnstagedStatResult.Output |
                ForEach-Object {
                    [string]$_
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                }
        )

        if ($UnstagedStatLines.Count -gt 0) {
            Write-Host ""
            Write-Host "未暂存修改统计："

            Show-GitOutput `
                -Result $UnstagedStatResult
        }


        # ----------------------------------
        # 显示已暂存修改统计
        # ----------------------------------

        $StagedStatResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--stat"
            )

        $StagedStatLines = @(
            $StagedStatResult.Output |
                ForEach-Object {
                    [string]$_
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                }
        )

        if ($StagedStatLines.Count -gt 0) {
            Write-Host ""
            Write-Host "已暂存修改统计："

            Show-GitOutput `
                -Result $StagedStatResult
        }


        # ----------------------------------
        # 检查删除文件
        # ----------------------------------

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
            $UnstagedDeletedResult.Output |
                ForEach-Object {
                    [string]$_
                }
        )

        $DeletedFiles += @(
            $StagedDeletedResult.Output |
                ForEach-Object {
                    [string]$_
                }
        )

        $DeletedFiles = @(
            $DeletedFiles |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                } |
                Sort-Object -Unique
        )

        if ($DeletedFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "检测到以下文件将从仓库中删除：" -ForegroundColor Yellow

            foreach ($DeletedFile in $DeletedFiles) {
                Write-Host "  $DeletedFile" -ForegroundColor Yellow
            }

            Write-Host ""

            $DeletionConfirmation = Read-Host `
                "确认这些删除都是预期操作吗？输入 YES 继续"

            if (
                ([string]$DeletionConfirmation).
                    Trim().
                    ToUpperInvariant() -ne "YES"
            ) {
                Stop-Publish `
                    -Message "用户未确认删除文件，没有执行暂存、提交或推送。"
            }
        }


        # ----------------------------------
        # 总体确认
        # ----------------------------------

        Write-Host ""

        $PublishConfirmation = Read-Host `
            "确认上述所有变化都需要发布吗？输入 YES 继续"

        if (
            ([string]$PublishConfirmation).
                Trim().
                ToUpperInvariant() -ne "YES"
        ) {
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
        # ----------------------------------
        # 检查未解决冲突
        # ----------------------------------

        $ConflictResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--name-only",
                "--diff-filter=U"
            )

        $ConflictFiles = @(
            $ConflictResult.Output |
                ForEach-Object {
                    [string]$_
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                }
        )

        if ($ConflictFiles.Count -gt 0) {
            Write-Host "检测到未解决的冲突文件：" -ForegroundColor Red

            foreach ($ConflictFile in $ConflictFiles) {
                Write-Host "  $ConflictFile" -ForegroundColor Red
            }

            Stop-Publish `
                -Message "请先解决 Git 冲突，再重新发布。"
        }

        Write-Host "✓ 未发现 Git 冲突" -ForegroundColor Green


        # ----------------------------------
        # 检查未暂存内容格式
        # ----------------------------------

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

        Write-Host "✓ 未暂存修改格式检查通过" -ForegroundColor Green


        # ----------------------------------
        # 检查已暂存内容格式
        # ----------------------------------

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

        Write-Host "✓ 已暂存修改格式检查通过" -ForegroundColor Green
    }
    else {
        Write-Host "没有新的文件变化，跳过文件格式预检。"
        Write-Host "将继续推送现有本地提交。"
    }


    # ======================================
    # 4/7 暂存修改
    # ======================================

    Write-Step `
        -Number 4 `
        -Title "暂存确认过的修改"

    if ($HasWorkingChanges) {
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


        # ----------------------------------
        # 暂存后再次检查格式
        # ----------------------------------

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


        # ----------------------------------
        # 检查是否确实有暂存内容
        # ----------------------------------

        $StagedNameResult = Invoke-Git `
            -Arguments @(
                "diff",
                "--cached",
                "--name-only"
            )

        $StagedFiles = @(
            $StagedNameResult.Output |
                ForEach-Object {
                    [string]$_
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                }
        )

        if ($StagedFiles.Count -eq 0) {
            Stop-Publish `
                -Message "暂存后没有发现可提交内容。"
        }

        Write-Host "已暂存 $($StagedFiles.Count) 个文件。" -ForegroundColor Green


        # ----------------------------------
        # 显示最终暂存状态
        # ----------------------------------

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
        Write-Host "没有新的文件变化，跳过 git add。"
    }


    # ======================================
    # 5/7 创建提交
    # ======================================

    Write-Step `
        -Number 5 `
        -Title "创建 Git 提交"

    if ($HasWorkingChanges) {
        Write-Host ""
        Write-Host "提交说明示例：" -ForegroundColor DarkGray
        Write-Host "  Optimize workspace icons and improve Git publishing" -ForegroundColor DarkGray
        Write-Host ""

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

        $CommitMessage =
            ([string]$CommitMessage).Trim()

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
        Write-Host "✓ Git 提交创建成功" -ForegroundColor Green
    }
    else {
        Write-Host "没有新的文件变化，跳过创建提交。"
        Write-Host "将推送现有的本地提交。"
    }


    # ======================================
    # 6/7 推送到 GitHub
    # ======================================

    Write-Step `
        -Number 6 `
        -Title "推送到 GitHub"

    Write-Host "推送前再次获取远程状态。"

    $FinalFetchResult = Invoke-Git `
        -Arguments @(
            "fetch",
            "origin",
            $CurrentBranch
        )

    Show-GitOutput `
        -Result $FinalFetchResult

    if ($FinalFetchResult.ExitCode -ne 0) {
        Stop-Publish `
            -Message "推送前无法获取远程状态。本地提交已经安全保留，尚未推送。"
    }

    $PrePushSyncState = Get-AheadBehind `
        -BranchName $CurrentBranch

    if ($null -eq $PrePushSyncState) {
        Stop-Publish `
            -Message "推送前无法计算本地与远程差异。本地提交已经安全保留。"
    }

    Write-Host "本地领先远程：$($PrePushSyncState.Ahead) 个提交"
    Write-Host "本地落后远程：$($PrePushSyncState.Behind) 个提交"

    if ($PrePushSyncState.Behind -gt 0) {
        Stop-Publish `
            -Message "发布期间远程仓库出现了新提交。请先同步 GitHub；本地提交已经安全保留。"
    }

    if ($PrePushSyncState.Ahead -eq 0) {
        Write-Host "没有需要推送的本地提交。" -ForegroundColor Green
    }
    else {
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
        Write-Host "✓ GitHub 推送成功" -ForegroundColor Green
    }


    # ======================================
    # 7/7 最终验证
    # ======================================

    Write-Step `
        -Number 7 `
        -Title "验证发布结果"

    $VerifyFetchResult = Invoke-Git `
        -Arguments @(
            "fetch",
            "origin",
            $CurrentBranch
        )

    if ($VerifyFetchResult.ExitCode -ne 0) {
        Write-Host "无法执行最终远程验证，但刚才的推送命令已成功。" -ForegroundColor Yellow
    }

    $FinalSyncState = Get-AheadBehind `
        -BranchName $CurrentBranch

    if ($null -ne $FinalSyncState) {
        Write-Host "本地领先远程：$($FinalSyncState.Ahead) 个提交"
        Write-Host "本地落后远程：$($FinalSyncState.Behind) 个提交"

        if (
            $FinalSyncState.Ahead -eq 0 -and
            $FinalSyncState.Behind -eq 0
        ) {
            Write-Host "✓ 本地分支与 GitHub 完全同步" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ 本地与远程仍存在提交差异，请检查。" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠ 无法计算最终同步状态。" -ForegroundColor Yellow
    }


    # --------------------------------------
    # 查看最新提交
    # --------------------------------------

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


    # --------------------------------------
    # 查看最终工作区
    # --------------------------------------

    $FinalStatusResult = Invoke-Git `
        -Arguments @(
            "status",
            "--short",
            "--untracked-files=all"
        )

    $FinalStatusLines = @(
        $FinalStatusResult.Output |
            ForEach-Object {
                [string]$_
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace(
                    $_
                )
            }
    )

    Write-Host ""

    if ($FinalStatusLines.Count -eq 0) {
        Write-Host "✓ Git 工作区干净" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ 发布完成后仍有本地变化：" -ForegroundColor Yellow

        foreach ($FinalStatusLine in $FinalStatusLines) {
            Write-Host $FinalStatusLine
        }
    }


    # --------------------------------------
    # 完成
    # --------------------------------------

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " Codex Design GitHub 发布完成" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "GitHub 发布工具发生异常：" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "本地文件和本地提交不会被自动删除。" -ForegroundColor Yellow
    Write-Host ""

    exit 1
}