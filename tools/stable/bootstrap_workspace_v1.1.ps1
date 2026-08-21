# ==========================================
# Codex Design 工作区恢复工具 V1.1
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# 功能：
# 1. 检查仓库结构
# 2. 检查开发工具
# 3. 检查 VS Code 工作区
# 4. 检查 Adobe Beta
# 5. 检查 Illustrator MCP
# 6. 生成桌面工作台
# 7. 运行完整环境检查
# 8. 输出尚未完成的项目
#
# 安全原则：
# - 不自动安装软件
# - 不自动修改 Git 配置
# - 不自动提交或推送
# - 不执行 reset、clean 或 force push
# - 不显示或记录任何 Token 的真实值
# ==========================================

$ErrorActionPreference = "Stop"


# ==========================================
# 初始化全局状态
# ==========================================

$script:Report = New-Object "System.Collections.Generic.List[string]"
$script:RequiredActions = New-Object "System.Collections.Generic.List[string]"
$script:SuggestedActions = New-Object "System.Collections.Generic.List[string]"

$script:PassCount = 0
$script:WarningCount = 0
$script:FailCount = 0

$script:ProjectPath = ""
$script:LogFile = ""
$script:GitExe = ""
$script:CodeExe = ""
$script:CodexExe = ""


# ==========================================
# 报告与状态函数
# ==========================================

function Add-Report {
    param(
        [string]$Text
    )

    [void]$script:Report.Add($Text)
}


function Add-UniqueAction {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    if (-not $List.Contains($Text)) {
        [void]$List.Add($Text)
    }
}


function Write-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "----------------------------------------------"

    Add-Report ""
    Add-Report $Title
    Add-Report "----------------------------------------------"
}


function Add-Status {
    param(
        [string]$Name,
        [string]$Value,

        [ValidateSet(
            "Success",
            "Warning",
            "Failure"
        )]
        [string]$Status,

        [string]$Action = ""
    )

    $Line = ""
    $Color = "White"

    switch ($Status) {
        "Success" {
            $script:PassCount++
            $Line = "✓ $Name：$Value"
            $Color = "Green"
        }

        "Warning" {
            $script:WarningCount++
            $Line = "⚠ $Name：$Value"
            $Color = "Yellow"

            Add-UniqueAction `
                -List $script:SuggestedActions `
                -Text $Action
        }

        "Failure" {
            $script:FailCount++
            $Line = "❌ $Name：$Value"
            $Color = "Red"

            Add-UniqueAction `
                -List $script:RequiredActions `
                -Text $Action
        }
    }

    Write-Host $Line -ForegroundColor $Color
    Add-Report $Line
}


function New-CheckResult {
    param(
        [bool]$Success,
        [string]$Value
    )

    return [PSCustomObject]@{
        Success = $Success
        Value   = $Value
    }
}


# ==========================================
# 命令和版本检查
# ==========================================

function Get-FirstCommand {
    param(
        [string]$CommandName
    )

    return Get-Command `
        $CommandName `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}


function Get-CommandVersionResult {
    param(
        [string]$CommandName,
        [string[]]$Arguments = @("--version")
    )

    $Command = Get-FirstCommand `
        -CommandName $CommandName

    if ($null -eq $Command) {
        return New-CheckResult `
            -Success $false `
            -Value "未安装或未加入 PATH"
    }

    try {
        $Output = @(
            & $Command.Source @Arguments 2>&1
        )

        $ExitCode = $LASTEXITCODE

        if ($ExitCode -ne 0) {
            return New-CheckResult `
                -Success $false `
                -Value "命令存在，但无法正常执行"
        }

        $FirstLine = (
            [string](
                $Output |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Select-Object -First 1
            )
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($FirstLine)) {
            return New-CheckResult `
                -Success $false `
                -Value "命令存在，但没有返回版本信息"
        }

        return New-CheckResult `
            -Success $true `
            -Value $FirstLine
    }
    catch {
        return New-CheckResult `
            -Success $false `
            -Value "命令检测失败"
    }
}


# ==========================================
# 文件和目录检查
# ==========================================

function Test-RequiredDirectory {
    param(
        [string]$RelativePath
    )

    $FullPath = Join-Path `
        $script:ProjectPath `
        $RelativePath

    if (
        Test-Path `
            -LiteralPath $FullPath `
            -PathType Container
    ) {
        Add-Status `
            -Name "目录" `
            -Value "$RelativePath：存在" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "目录" `
            -Value "$RelativePath：缺失" `
            -Status "Failure" `
            -Action "恢复缺失目录：$RelativePath"
    }
}


function Test-RequiredFile {
    param(
        [string]$RelativePath
    )

    $FullPath = Join-Path `
        $script:ProjectPath `
        $RelativePath

    if (
        Test-Path `
            -LiteralPath $FullPath `
            -PathType Leaf
    ) {
        Add-Status `
            -Name "文件" `
            -Value "$RelativePath：存在" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "文件" `
            -Value "$RelativePath：缺失" `
            -Status "Failure" `
            -Action "从 GitHub 恢复缺失文件：$RelativePath"
    }
}


# ==========================================
# PowerShell 语法检查
# ==========================================

function Test-PowerShellFileSyntax {
    param(
        [string]$RelativePath
    )

    $FullPath = Join-Path `
        $script:ProjectPath `
        $RelativePath

    if (
        -not (
            Test-Path `
                -LiteralPath $FullPath `
                -PathType Leaf
        )
    ) {
        return New-CheckResult `
            -Success $false `
            -Value "文件不存在"
    }

    try {
        $Tokens = $null
        $Errors = $null

        [System.Management.Automation.Language.Parser]::ParseFile(
            $FullPath,
            [ref]$Tokens,
            [ref]$Errors
        ) | Out-Null

        if (
            $null -ne $Errors -and
            $Errors.Count -gt 0
        ) {
            $FirstError = $Errors |
                Select-Object -First 1

            return New-CheckResult `
                -Success $false `
                -Value "第 $($FirstError.Extent.StartLineNumber) 行：$($FirstError.Message)"
        }

        return New-CheckResult `
            -Success $true `
            -Value "语法通过"
    }
    catch {
        return New-CheckResult `
            -Success $false `
            -Value "无法完成语法检查"
    }
}


# ==========================================
# JSON 检查
# ==========================================

function Test-StrictJsonFile {
    param(
        [string]$RelativePath
    )

    $FullPath = Join-Path `
        $script:ProjectPath `
        $RelativePath

    if (
        -not (
            Test-Path `
                -LiteralPath $FullPath `
                -PathType Leaf
        )
    ) {
        return New-CheckResult `
            -Success $false `
            -Value "文件不存在"
    }

    try {
        $RawContent = Get-Content `
            -LiteralPath $FullPath `
            -Raw `
            -Encoding UTF8

        $RawContent |
            ConvertFrom-Json |
            Out-Null

        return New-CheckResult `
            -Success $true `
            -Value "格式正常"
    }
    catch {
        return New-CheckResult `
            -Success $false `
            -Value "JSON 格式无效"
    }
}


# ==========================================
# 查找 Adobe 安装目录
# ==========================================

function Find-FirstExistingPath {
    param(
        [string[]]$Candidates
    )

    foreach ($Candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            continue
        }

        if (Test-Path -LiteralPath $Candidate) {
            return (
                Resolve-Path `
                    -LiteralPath $Candidate
            ).Path
        }
    }

    return ""
}


# ==========================================
# TCP 端口检查
# ==========================================

function Test-TcpPort {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMilliseconds = 800
    )

    $Client = New-Object `
        System.Net.Sockets.TcpClient

    try {
        $AsyncResult = $Client.BeginConnect(
            $ComputerName,
            $Port,
            $null,
            $null
        )

        $ConnectedInTime = $AsyncResult.AsyncWaitHandle.WaitOne(
            $TimeoutMilliseconds,
            $false
        )

        if (-not $ConnectedInTime) {
            return $false
        }

        $Client.EndConnect($AsyncResult)

        return $Client.Connected
    }
    catch {
        return $false
    }
    finally {
        $Client.Close()
    }
}


# ==========================================
# 子 PowerShell 脚本执行
# ==========================================

function Invoke-ChildPowerShellScript {
    param(
        [string]$ScriptPath
    )

    $PowerShellExe = Join-Path `
        $env:SystemRoot `
        "System32\WindowsPowerShell\v1.0\powershell.exe"

    if (
        -not (
            Test-Path `
                -LiteralPath $PowerShellExe `
                -PathType Leaf
        )
    ) {
        $PowerShellCommand = Get-FirstCommand `
            -CommandName "powershell.exe"

        if ($null -eq $PowerShellCommand) {
            return 1
        }

        $PowerShellExe = $PowerShellCommand.Source
    }

    $ArgumentLine = (
        "-NoProfile " +
        "-ExecutionPolicy Bypass " +
        "-File `"$ScriptPath`""
    )

    try {
        $Process = Start-Process `
            -FilePath $PowerShellExe `
            -ArgumentList $ArgumentLine `
            -NoNewWindow `
            -Wait `
            -PassThru

        return $Process.ExitCode
    }
    catch {
        return 1
    }
}


# ==========================================
# 主程序
# ==========================================

try {
    # --------------------------------------
    # 动态计算项目根目录
    # --------------------------------------

    $script:ProjectPath = (
        Resolve-Path `
            -LiteralPath (
                Join-Path $PSScriptRoot ".."
            )
    ).Path

    Set-Location `
        -LiteralPath $script:ProjectPath

    $ProxyGuardPath = Join-Path `
        $script:ProjectPath `
        "tools\lib\github_proxy_guard.ps1"

    $ProxyGuardAvailable = Test-Path `
        -LiteralPath $ProxyGuardPath `
        -PathType Leaf

    if ($ProxyGuardAvailable) {
        . $ProxyGuardPath
    }


    # --------------------------------------
    # 日志目录
    # --------------------------------------

    $LogsPath = Join-Path `
        $script:ProjectPath `
        "logs"

    if (
        -not (
            Test-Path `
                -LiteralPath $LogsPath `
                -PathType Container
        )
    ) {
        New-Item `
            -ItemType Directory `
            -Path $LogsPath `
            -Force |
            Out-Null
    }

    $Timestamp = Get-Date `
        -Format "yyyyMMdd_HHmmss"

    $script:LogFile = Join-Path `
        $LogsPath `
        "bootstrap_workspace_$Timestamp.txt"


    # --------------------------------------
    # 标题
    # --------------------------------------

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Design 工作区恢复工具 V1.1" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "项目目录：$script:ProjectPath"
    Write-Host "开始时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    Add-Report "Codex Design 工作区恢复工具 V1.1"
    Add-Report "=============================================="
    Add-Report "项目目录：$script:ProjectPath"
    Add-Report "开始时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Report ""
    Add-Report "本工具只执行检测、入口恢复和报告生成。"
    Add-Report "本工具不会自动安装软件、修改 Git 历史或记录敏感凭据。"


    # ======================================
    # 1. 系统检查
    # ======================================

    Write-Section "[1/9] 检查系统环境"

    $OS = Get-CimInstance `
        Win32_OperatingSystem

    Add-Status `
        -Name "Windows" `
        -Value "$($OS.Caption) $($OS.Version)" `
        -Status "Success"

    $PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Add-Status `
            -Name "PowerShell" `
            -Value "$PowerShellVersion（符合 Windows PowerShell 5.1 兼容目标）" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "PowerShell" `
            -Value "$PowerShellVersion（建议使用 Windows PowerShell 5.1 验证）" `
            -Status "Warning" `
            -Action "使用 Windows PowerShell 5.1 再运行一次恢复和环境检查"
    }


    # ======================================
    # 2. 仓库结构检查
    # ======================================

    Write-Section "[2/9] 检查仓库结构"

    $RequiredDirectories = @(
        ".codex",
        ".codex\hooks",
        ".agents\plugins",
        ".vscode",
        "tools",
        "tools\lib",
        "tools\stable",
        "tools\docs",
        "scripts",
        "plugins\codex-design-workflows"
    )

    foreach ($Directory in $RequiredDirectories) {
        Test-RequiredDirectory `
            -RelativePath $Directory
    }

    $RequiredFiles = @(
        "README.md",
        "AGENTS.md",
        "CODING_RULES.md",
        ".editorconfig",
        ".gitattributes",
        ".gitignore",
        ".codex\config.toml",
        ".codex\hooks.json",
        ".codex\hooks\pre_tool_use_policy.ps1",
        ".codex\hooks\post_tool_use_validate.ps1",
        ".agents\plugins\marketplace.json",
        ".vscode\extensions.json",
        ".vscode\settings.json",
        ".vscode\tasks.json",
        "tools\git_status.ps1",
        "tools\git_sync.ps1",
        "tools\git_publish.ps1",
        "tools\environment_check.ps1",
        "tools\validate_repository.ps1",
        "tools\harden_codex_global_config.ps1",
        "tools\install_codex_design_plugin.ps1",
        "tools\lib\github_proxy_guard.ps1",
        "tools\create_desktop_shortcuts.ps1",
        "tools\bootstrap_workspace.ps1",
        "tools\docs\ENVIRONMENT.md",
        "tools\stable\README.md",
        "plugins\codex-design-workflows\.codex-plugin\plugin.json",
        "plugins\codex-design-workflows\skills\promote-creative-workflow\SKILL.md",
        "prompts\creative_experiment_review.md",
        "workflows\creative_capability_promotion.md",
        "experiments\creative_experiment_record_template.md"
    )

    foreach ($File in $RequiredFiles) {
        Test-RequiredFile `
            -RelativePath $File
    }


    # --------------------------------------
    # 检查核心 PowerShell 工具语法
    # --------------------------------------

    $PowerShellToolFiles = @(
        "tools\git_status.ps1",
        "tools\git_sync.ps1",
        "tools\git_publish.ps1",
        "tools\environment_check.ps1",
        "tools\validate_repository.ps1",
        "tools\harden_codex_global_config.ps1",
        "tools\install_codex_design_plugin.ps1",
        "tools\lib\github_proxy_guard.ps1",
        "tools\create_desktop_shortcuts.ps1",
        "tools\bootstrap_workspace.ps1",
        ".codex\hooks\pre_tool_use_policy.ps1",
        ".codex\hooks\post_tool_use_validate.ps1",
        "plugins\codex-design-workflows\skills\promote-creative-workflow\scripts\validate-promotion.ps1"
    )

    $SyntaxFailureCount = 0

    foreach ($PowerShellFile in $PowerShellToolFiles) {
        $SyntaxResult = Test-PowerShellFileSyntax `
            -RelativePath $PowerShellFile

        if ($SyntaxResult.Success) {
            Add-Status `
                -Name "PowerShell语法" `
                -Value "$PowerShellFile：通过" `
                -Status "Success"
        }
        else {
            $SyntaxFailureCount++

            Add-Status `
                -Name "PowerShell语法" `
                -Value "$PowerShellFile：$($SyntaxResult.Value)" `
                -Status "Failure" `
                -Action "修复 PowerShell 语法：$PowerShellFile"
        }
    }


    # ======================================
    # 3. 开发工具检查
    # ======================================

    Write-Section "[3/9] 检查开发工具"

    $GitVersion = Get-CommandVersionResult `
        -CommandName "git"

    if ($GitVersion.Success) {
        $GitCommand = Get-FirstCommand `
            -CommandName "git"

        $script:GitExe = $GitCommand.Source

        Add-Status `
            -Name "Git" `
            -Value $GitVersion.Value `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "Git" `
            -Value $GitVersion.Value `
            -Status "Failure" `
            -Action "安装 Git for Windows，并确认 git 命令已加入 PATH"
    }


    if (
        -not [string]::IsNullOrWhiteSpace(
            $script:GitExe
        )
    ) {
        $GitLfsVersion = Get-CommandVersionResult `
            -CommandName "git" `
            -Arguments @(
                "lfs",
                "version"
            )

        if ($GitLfsVersion.Success) {
            Add-Status `
                -Name "Git LFS" `
                -Value $GitLfsVersion.Value `
                -Status "Success"
        }
        else {
            Add-Status `
                -Name "Git LFS" `
                -Value $GitLfsVersion.Value `
                -Status "Failure" `
                -Action "安装或启用 Git LFS，然后运行 git lfs install"
        }
    }


    $NodeVersion = Get-CommandVersionResult `
        -CommandName "node"

    if ($NodeVersion.Success) {
        Add-Status `
            -Name "Node.js" `
            -Value $NodeVersion.Value `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "Node.js" `
            -Value $NodeVersion.Value `
            -Status "Failure" `
            -Action "安装 Node.js，并确认 node 命令已加入 PATH"
    }


    $NpmVersion = Get-CommandVersionResult `
        -CommandName "npm.cmd"

    if ($NpmVersion.Success) {
        Add-Status `
            -Name "npm" `
            -Value $NpmVersion.Value `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "npm" `
            -Value $NpmVersion.Value `
            -Status "Failure" `
            -Action "修复 Node.js/npm 安装"
    }


    $CodexVersion = Get-CommandVersionResult `
        -CommandName "codex.cmd"

    if ($CodexVersion.Success) {
        $CodexCommand = Get-FirstCommand `
            -CommandName "codex.cmd"

        $script:CodexExe = $CodexCommand.Source

        Add-Status `
            -Name "Codex" `
            -Value $CodexVersion.Value `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "Codex" `
            -Value $CodexVersion.Value `
            -Status "Failure" `
            -Action "安装 OpenAI Codex CLI，并完成 ChatGPT 登录"
    }


    $VSCodeVersion = Get-CommandVersionResult `
        -CommandName "code"

    if ($VSCodeVersion.Success) {
        $CodeCommand = Get-FirstCommand `
            -CommandName "code"

        $script:CodeExe = $CodeCommand.Source

        Add-Status `
            -Name "VS Code" `
            -Value $VSCodeVersion.Value `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "VS Code" `
            -Value $VSCodeVersion.Value `
            -Status "Failure" `
            -Action "安装 VS Code，并启用 code 命令"
    }


    # ======================================
    # 4. Git 仓库检查
    # ======================================

    Write-Section "[4/9] 检查 Git 仓库"

    if (
        [string]::IsNullOrWhiteSpace(
            $script:GitExe
        )
    ) {
        Add-Status `
            -Name "Git仓库" `
            -Value "无法检查：Git 不可用" `
            -Status "Failure" `
            -Action "先安装并修复 Git"
    }
    else {
        $RepositoryOutput = @(
            & $script:GitExe `
                rev-parse `
                --is-inside-work-tree `
                2>&1
        )

        $RepositoryExitCode = $LASTEXITCODE

        if (
            $RepositoryExitCode -eq 0 -and
            $RepositoryOutput.Count -gt 0 -and
            ([string]$RepositoryOutput[0]).Trim() -eq "true"
        ) {
            Add-Status `
                -Name "Git仓库" `
                -Value "有效" `
                -Status "Success"

            $BranchOutput = @(
                & $script:GitExe `
                    rev-parse `
                    --abbrev-ref `
                    HEAD `
                    2>&1
            )

            $BranchExitCode = $LASTEXITCODE

            if (
                $BranchExitCode -eq 0 -and
                $BranchOutput.Count -gt 0
            ) {
                $CurrentBranch = (
                    [string]$BranchOutput[0]
                ).Trim()

                if ($CurrentBranch -eq "main") {
                    Add-Status `
                        -Name "当前分支" `
                        -Value "main" `
                        -Status "Success"
                }
                else {
                    Add-Status `
                        -Name "当前分支" `
                        -Value $CurrentBranch `
                        -Status "Warning" `
                        -Action "确认是否需要切换回 main 分支"
                }
            }
            else {
                Add-Status `
                    -Name "当前分支" `
                    -Value "无法读取" `
                    -Status "Failure" `
                    -Action "检查 Git 仓库分支状态"
            }


            $RemoteOutput = @(
                & $script:GitExe `
                    remote `
                    get-url `
                    origin `
                    2>&1
            )

            $RemoteExitCode = $LASTEXITCODE

            if (
                $RemoteExitCode -eq 0 -and
                $RemoteOutput.Count -gt 0
            ) {
                $RemoteUrl = (
                    [string]$RemoteOutput[0]
                ).Trim()

                $SafeRemoteUrl = $RemoteUrl -replace `
                    "://[^/@]+@", `
                    "://***@"

                Add-Status `
                    -Name "远程仓库" `
                    -Value $SafeRemoteUrl `
                    -Status "Success"


                if (-not $ProxyGuardAvailable) {
                    Add-Status `
                        -Name "GitHub连接" `
                        -Value "已停止：缺少代理守卫" `
                        -Status "Failure" `
                        -Action "恢复 tools/lib/github_proxy_guard.ps1 后再检查"
                }
                else {
                    $ProxyGuardResult = Test-GitHubProxyGuard `
                        -ProjectPath $script:ProjectPath

                    Add-Status `
                        -Name "GitHub代理" `
                        -Value $ProxyGuardResult.Message `
                        -Status $(
                            if ($ProxyGuardResult.Success) {
                                "Success"
                            }
                            else {
                                "Failure"
                            }
                        ) `
                        -Action $(
                            if ($ProxyGuardResult.Success) {
                                ""
                            }
                            else {
                                "启用当前电脑正在使用的代理；禁止直连 GitHub"
                            }
                        )

                    if ($ProxyGuardResult.Success) {
                        $PreviousGitPrompt = $env:GIT_TERMINAL_PROMPT
                        $env:GIT_TERMINAL_PROMPT = "0"

                        try {
                            $RemoteRefs = @(
                                & $script:GitExe `
                                    ls-remote `
                                    origin `
                                    2>&1
                            )

                            $RemoteConnectionExitCode = $LASTEXITCODE
                        }
                        finally {
                            $env:GIT_TERMINAL_PROMPT = $PreviousGitPrompt
                        }

                        if ($RemoteConnectionExitCode -eq 0) {
                            Add-Status `
                                -Name "GitHub连接" `
                                -Value "正常" `
                                -Status "Success"
                        }
                        else {
                            Add-Status `
                                -Name "GitHub连接" `
                                -Value "代理已验证，但连接失败" `
                                -Status "Failure" `
                                -Action "检查 GitHub 登录和 origin 地址"
                        }
                    }
                }
            }
            else {
                Add-Status `
                    -Name "远程仓库" `
                    -Value "未配置 origin" `
                    -Status "Failure" `
                    -Action "配置 Git 远程仓库 origin"
            }


            $GitChanges = @(
                & $script:GitExe `
                    status `
                    --porcelain `
                    2>&1
            )

            $GitStatusExitCode = $LASTEXITCODE

            if ($GitStatusExitCode -ne 0) {
                Add-Status `
                    -Name "Git状态" `
                    -Value "检查失败" `
                    -Status "Failure" `
                    -Action "检查 Git 工作区状态"
            }
            elseif ($GitChanges.Count -gt 0) {
                Add-Status `
                    -Name "Git状态" `
                    -Value "存在本地修改，不会自动提交或丢弃" `
                    -Status "Warning" `
                    -Action "确认本地修改内容，测试后使用安全发布工具提交"
            }
            else {
                Add-Status `
                    -Name "Git状态" `
                    -Value "工作区干净" `
                    -Status "Success"
            }
        }
        else {
            Add-Status `
                -Name "Git仓库" `
                -Value "当前目录不是有效仓库" `
                -Status "Failure" `
                -Action "重新使用 git clone 获取完整仓库"
        }
    }


    # ======================================
    # 5. VS Code 工作区检查
    # ======================================

    Write-Section "[5/9] 检查 VS Code 工作区"

    $ExtensionsJsonResult = Test-StrictJsonFile `
        -RelativePath ".vscode\extensions.json"

    if ($ExtensionsJsonResult.Success) {
        Add-Status `
            -Name "extensions.json" `
            -Value "格式正常" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "extensions.json" `
            -Value $ExtensionsJsonResult.Value `
            -Status "Failure" `
            -Action "修复 .vscode/extensions.json"
    }


    $TasksJsonResult = Test-StrictJsonFile `
        -RelativePath ".vscode\tasks.json"

    if ($TasksJsonResult.Success) {
        Add-Status `
            -Name "tasks.json" `
            -Value "格式正常" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "tasks.json" `
            -Value $TasksJsonResult.Value `
            -Status "Failure" `
            -Action "修复 .vscode/tasks.json"
    }


    $SettingsPath = Join-Path `
        $script:ProjectPath `
        ".vscode\settings.json"

    if (
        Test-Path `
            -LiteralPath $SettingsPath `
            -PathType Leaf
    ) {
        Add-Status `
            -Name "settings.json" `
            -Value "存在（JSONC 配置不做严格 JSON 解析）" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "settings.json" `
            -Value "缺失" `
            -Status "Failure" `
            -Action "从 GitHub 恢复 .vscode/settings.json"
    }


    # --------------------------------------
    # 推荐扩展检查
    # --------------------------------------

    if (
        $ExtensionsJsonResult.Success -and
        -not [string]::IsNullOrWhiteSpace(
            $script:CodeExe
        )
    ) {
        try {
            $ExtensionsConfig = Get-Content `
                -LiteralPath (
                    Join-Path `
                        $script:ProjectPath `
                        ".vscode\extensions.json"
                ) `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json

            $Recommendations = @(
                $ExtensionsConfig.recommendations |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$_
                        )
                    }
            )

            $InstalledExtensions = @(
                & $script:CodeExe `
                    --list-extensions `
                    2>&1
            )

            $ExtensionExitCode = $LASTEXITCODE

            if ($ExtensionExitCode -ne 0) {
                Add-Status `
                    -Name "VS Code扩展" `
                    -Value "无法读取已安装扩展" `
                    -Status "Warning" `
                    -Action "打开 VS Code，安装工作区推荐扩展"
            }
            else {
                $InstalledLower = @(
                    $InstalledExtensions |
                        ForEach-Object {
                            ([string]$_).Trim().ToLowerInvariant()
                        }
                )

                $MissingExtensions = @()

                foreach ($Recommendation in $Recommendations) {
                    $ExtensionId = (
                        [string]$Recommendation
                    ).Trim()

                    if (
                        $InstalledLower -notcontains
                        $ExtensionId.ToLowerInvariant()
                    ) {
                        $MissingExtensions += $ExtensionId
                    }
                }

                if ($MissingExtensions.Count -eq 0) {
                    Add-Status `
                        -Name "VS Code扩展" `
                        -Value "全部推荐扩展已安装" `
                        -Status "Success"
                }
                else {
                    Add-Status `
                        -Name "VS Code扩展" `
                        -Value "缺少 $($MissingExtensions.Count) 个推荐扩展" `
                        -Status "Warning" `
                        -Action "在 VS Code 的“扩展”页面安装工作区推荐扩展"

                    foreach ($MissingExtension in $MissingExtensions) {
                        Write-Host "  缺少：$MissingExtension" -ForegroundColor Yellow
                        Add-Report "  缺少：$MissingExtension"
                    }
                }
            }
        }
        catch {
            Add-Status `
                -Name "VS Code扩展" `
                -Value "推荐扩展检查失败" `
                -Status "Warning" `
                -Action "在 VS Code 中检查工作区推荐扩展"
        }
    }


    # ======================================
    # 6. Adobe Beta 检查
    # ======================================

    Write-Section "[6/9] 检查 Adobe Beta"

    $ProgramFilesX86 = [Environment]::GetEnvironmentVariable(
        "ProgramFiles(x86)"
    )

    $PhotoshopCandidates = @(
        (
            Join-Path `
                $env:ProgramFiles `
                "Adobe\Adobe Photoshop (Beta)"
        )
    )

    $IllustratorCandidates = @(
        (
            Join-Path `
                $env:ProgramFiles `
                "Adobe\Adobe Illustrator (Beta)"
        )
    )

    if (
        -not [string]::IsNullOrWhiteSpace(
            $ProgramFilesX86
        )
    ) {
        $PhotoshopCandidates += Join-Path `
            $ProgramFilesX86 `
            "Adobe\Adobe Photoshop (Beta)"

        $IllustratorCandidates += Join-Path `
            $ProgramFilesX86 `
            "Adobe\Adobe Illustrator (Beta)"
    }

    $PhotoshopPath = Find-FirstExistingPath `
        -Candidates $PhotoshopCandidates

    $IllustratorPath = Find-FirstExistingPath `
        -Candidates $IllustratorCandidates

    if (
        -not [string]::IsNullOrWhiteSpace(
            $PhotoshopPath
        )
    ) {
        Add-Status `
            -Name "Photoshop Beta" `
            -Value $PhotoshopPath `
            -Status "Success"

        $PhotoshopScriptsPath = Join-Path `
            $PhotoshopPath `
            "Presets\Scripts"

        if (
            Test-Path `
                -LiteralPath $PhotoshopScriptsPath `
                -PathType Container
        ) {
            Add-Status `
                -Name "Photoshop脚本目录" `
                -Value $PhotoshopScriptsPath `
                -Status "Success"
        }
        else {
            Add-Status `
                -Name "Photoshop脚本目录" `
                -Value "未找到" `
                -Status "Warning" `
                -Action "检查 Photoshop Beta 安装和脚本目录"
        }
    }
    else {
        Add-Status `
            -Name "Photoshop Beta" `
            -Value "未安装或未在默认位置找到" `
            -Status "Warning" `
            -Action "安装 Adobe Photoshop Beta，或检查实际安装目录"
    }


    if (
        -not [string]::IsNullOrWhiteSpace(
            $IllustratorPath
        )
    ) {
        Add-Status `
            -Name "Illustrator Beta" `
            -Value $IllustratorPath `
            -Status "Success"

        $IllustratorScriptsPath = Join-Path `
            $IllustratorPath `
            "Presets\zh_CN\脚本"

        if (
            Test-Path `
                -LiteralPath $IllustratorScriptsPath `
                -PathType Container
        ) {
            Add-Status `
                -Name "Illustrator脚本目录" `
                -Value $IllustratorScriptsPath `
                -Status "Success"
        }
        else {
            Add-Status `
                -Name "Illustrator脚本目录" `
                -Value "未找到" `
                -Status "Warning" `
                -Action "检查 Illustrator Beta 中文脚本目录"
        }
    }
    else {
        Add-Status `
            -Name "Illustrator Beta" `
            -Value "未安装或未在默认位置找到" `
            -Status "Warning" `
            -Action "安装 Adobe Illustrator Beta，或检查实际安装目录"
    }


    # ======================================
    # 7. Illustrator MCP 检查
    # ======================================

    Write-Section "[7/9] 检查 Illustrator MCP"

    if (
        [string]::IsNullOrWhiteSpace(
            $script:CodexExe
        )
    ) {
        Add-Status `
            -Name "MCP配置" `
            -Value "无法检查：Codex CLI 不可用" `
            -Status "Warning" `
            -Action "安装 Codex CLI 后配置 adobe_illustrator MCP"
    }
    else {
        try {
            $McpOutput = @(
                & $script:CodexExe `
                    mcp `
                    list `
                    2>&1
            )

            $McpExitCode = $LASTEXITCODE

            $McpText = (
                (
                    $McpOutput |
                    ForEach-Object {
                        [string]$_
                    }
                ) -join "`n"
            )

            if ($McpExitCode -ne 0) {
                Add-Status `
                    -Name "MCP配置" `
                    -Value "codex mcp list 执行失败" `
                    -Status "Warning" `
                    -Action "检查 Codex 登录和 MCP 配置"
            }
            elseif (
                $McpText -match "adobe_illustrator" -and
                $McpText -match "enabled"
            ) {
                Add-Status `
                    -Name "MCP配置" `
                    -Value "adobe_illustrator 已配置并启用" `
                    -Status "Success"
            }
            elseif ($McpText -match "adobe_illustrator") {
                Add-Status `
                    -Name "MCP配置" `
                    -Value "adobe_illustrator 已配置，但未确认启用" `
                    -Status "Warning" `
                    -Action "启用 adobe_illustrator MCP 配置"
            }
            else {
                Add-Status `
                    -Name "MCP配置" `
                    -Value "未找到 adobe_illustrator" `
                    -Status "Warning" `
                    -Action "按照 ENVIRONMENT.md 配置 adobe_illustrator MCP"
            }
        }
        catch {
            Add-Status `
                -Name "MCP配置" `
                -Value "检查失败" `
                -Status "Warning" `
                -Action "检查 Codex MCP 配置"
        }
    }


    # --------------------------------------
    # 只检查环境变量是否存在
    # 不记录真实值
    # --------------------------------------

    $TokenName = "ADOBE_ILLUSTRATOR_MCP_BEARER_TOKEN"

    $ProcessToken = [Environment]::GetEnvironmentVariable(
        $TokenName,
        "Process"
    )

    $UserToken = [Environment]::GetEnvironmentVariable(
        $TokenName,
        "User"
    )

    $MachineToken = [Environment]::GetEnvironmentVariable(
        $TokenName,
        "Machine"
    )

    $TokenExists = $false

    if (
        -not [string]::IsNullOrWhiteSpace(
            $ProcessToken
        )
    ) {
        $TokenExists = $true
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $UserToken
        )
    ) {
        $TokenExists = $true
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $MachineToken
        )
    ) {
        $TokenExists = $true
    }

    if ($TokenExists) {
        Add-Status `
            -Name "MCP令牌变量" `
            -Value "$TokenName：已配置（值不显示）" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "MCP令牌变量" `
            -Value "$TokenName：未配置" `
            -Status "Warning" `
            -Action "在 Windows 用户环境变量中配置 $TokenName"
    }

    # 清除局部变量，避免后续误用
    $ProcessToken = $null
    $UserToken = $null
    $MachineToken = $null


    $McpPortOpen = Test-TcpPort `
        -ComputerName "127.0.0.1" `
        -Port 18412 `
        -TimeoutMilliseconds 800

    if ($McpPortOpen) {
        Add-Status `
            -Name "MCP本地端口" `
            -Value "127.0.0.1:18412 正在监听" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "MCP本地端口" `
            -Value "18412 当前未监听，Illustrator 可能尚未启动" `
            -Status "Warning" `
            -Action "需要使用 MCP 时，启动 Illustrator Beta 并确认 MCP 功能已开启"
    }


    # ======================================
    # 8. 生成桌面工作台
    # ======================================

    Write-Section "[8/9] 生成桌面工作台"

    $DesktopScript = Join-Path `
        $script:ProjectPath `
        "tools\create_desktop_shortcuts.ps1"

    if (
        Test-Path `
            -LiteralPath $DesktopScript `
            -PathType Leaf
    ) {
        $DesktopSyntaxResult = Test-PowerShellFileSyntax `
            -RelativePath "tools\create_desktop_shortcuts.ps1"

        if (-not $DesktopSyntaxResult.Success) {
            Add-Status `
                -Name "桌面工作台" `
                -Value "生成工具存在语法错误，未运行" `
                -Status "Failure" `
                -Action "修复 tools/create_desktop_shortcuts.ps1"
        }
        else {
            Write-Host "正在运行桌面工作台生成工具……" -ForegroundColor Cyan
            Write-Host "子工具出现提示时，请按提示完成。" -ForegroundColor Cyan
            Add-Report "正在运行桌面工作台生成工具。"

            $DesktopExitCode = Invoke-ChildPowerShellScript `
                -ScriptPath $DesktopScript

            if ($DesktopExitCode -eq 0) {
                Add-Status `
                    -Name "桌面工作台" `
                    -Value "生成或恢复完成" `
                    -Status "Success"
            }
            else {
                Add-Status `
                    -Name "桌面工作台" `
                    -Value "生成工具返回错误代码 $DesktopExitCode" `
                    -Status "Warning" `
                    -Action "单独运行 create_desktop_shortcuts.ps1 查看完整错误"
            }
        }
    }
    else {
        Add-Status `
            -Name "桌面工作台" `
            -Value "缺少 create_desktop_shortcuts.ps1" `
            -Status "Failure" `
            -Action "从 GitHub 恢复 tools/create_desktop_shortcuts.ps1"
    }


    # ======================================
    # 9. 运行完整环境检查
    # ======================================

    Write-Section "[9/9] 运行完整环境检查"

    $EnvironmentScript = Join-Path `
        $script:ProjectPath `
        "tools\environment_check.ps1"

    if (
        Test-Path `
            -LiteralPath $EnvironmentScript `
            -PathType Leaf
    ) {
        $EnvironmentSyntaxResult = Test-PowerShellFileSyntax `
            -RelativePath "tools\environment_check.ps1"

        if (-not $EnvironmentSyntaxResult.Success) {
            Add-Status `
                -Name "完整环境检查" `
                -Value "environment_check.ps1 存在语法错误" `
                -Status "Failure" `
                -Action "修复 tools/environment_check.ps1"
        }
        else {
            Write-Host "正在运行完整环境检查……" -ForegroundColor Cyan
            Write-Host "环境检查结束后，请按 Enter 返回恢复工具。" -ForegroundColor Cyan
            Add-Report "正在运行完整环境检查。"

            $EnvironmentExitCode = Invoke-ChildPowerShellScript `
                -ScriptPath $EnvironmentScript

            if ($EnvironmentExitCode -ne 0) {
                Add-Status `
                    -Name "完整环境检查" `
                    -Value "执行失败，错误代码 $EnvironmentExitCode" `
                    -Status "Failure" `
                    -Action "查看最新 environment_check 报告并修复失败项"
            }
            else {
                $LatestEnvironmentReport = Get-ChildItem `
                    -LiteralPath $LogsPath `
                    -Filter "environment_check_*.txt" `
                    -File `
                    -ErrorAction SilentlyContinue |
                    Sort-Object `
                        LastWriteTime `
                        -Descending |
                    Select-Object -First 1

                if ($null -eq $LatestEnvironmentReport) {
                    Add-Status `
                        -Name "完整环境检查" `
                        -Value "执行完成，但未找到报告文件" `
                        -Status "Warning" `
                        -Action "单独运行 environment_check.ps1 确认日志生成"
                }
                else {
                    $EnvironmentReportText = Get-Content `
                        -LiteralPath $LatestEnvironmentReport.FullName `
                        -Raw `
                        -Encoding UTF8

                    $FailMatch = [regex]::Match(
                        $EnvironmentReportText,
                        "失败：\s*(\d+)"
                    )

                    $WarningMatch = [regex]::Match(
                        $EnvironmentReportText,
                        "警告：\s*(\d+)"
                    )

                    [int]$EnvironmentFailCount = 0
                    [int]$EnvironmentWarningCount = 0

                    if ($FailMatch.Success) {
                        $EnvironmentFailCount = [int]$FailMatch.Groups[1].Value
                    }

                    if ($WarningMatch.Success) {
                        $EnvironmentWarningCount = [int]$WarningMatch.Groups[1].Value
                    }

                    if ($EnvironmentFailCount -gt 0) {
                        Add-Status `
                            -Name "完整环境检查" `
                            -Value "发现 $EnvironmentFailCount 个失败项；报告：$($LatestEnvironmentReport.Name)" `
                            -Status "Failure" `
                            -Action "打开 $($LatestEnvironmentReport.FullName) 修复失败项"
                    }
                    elseif ($EnvironmentWarningCount -gt 0) {
                        Add-Status `
                            -Name "完整环境检查" `
                            -Value "失败 0，警告 $EnvironmentWarningCount；报告：$($LatestEnvironmentReport.Name)" `
                            -Status "Warning" `
                            -Action "查看环境报告中的警告项，确认是否属于可选配置"
                    }
                    else {
                        Add-Status `
                            -Name "完整环境检查" `
                            -Value "全部通过；报告：$($LatestEnvironmentReport.Name)" `
                            -Status "Success"
                    }
                }
            }
        }
    }
    else {
        Add-Status `
            -Name "完整环境检查" `
            -Value "缺少 environment_check.ps1" `
            -Status "Failure" `
            -Action "从 GitHub 恢复 tools/environment_check.ps1"
    }


    # ======================================
    # 恢复摘要
    # ======================================

    Write-Section "恢复摘要"

    Write-Host "通过：$script:PassCount"
    Write-Host "警告：$script:WarningCount"
    Write-Host "失败：$script:FailCount"

    Add-Report "通过：$script:PassCount"
    Add-Report "警告：$script:WarningCount"
    Add-Report "失败：$script:FailCount"


    # --------------------------------------
    # 必须完成项
    # --------------------------------------

    Write-Host ""
    Write-Host "必须完成项" -ForegroundColor Red
    Write-Host "----------------------------------------------"

    Add-Report ""
    Add-Report "必须完成项"
    Add-Report "----------------------------------------------"

    if ($script:RequiredActions.Count -eq 0) {
        Write-Host "无。核心工作区已具备。" -ForegroundColor Green
        Add-Report "无。核心工作区已具备。"
    }
    else {
        $RequiredNumber = 1

        foreach ($RequiredAction in $script:RequiredActions) {
            Write-Host "$RequiredNumber. $RequiredAction" -ForegroundColor Red
            Add-Report "$RequiredNumber. $RequiredAction"

            $RequiredNumber++
        }
    }


    # --------------------------------------
    # 建议完成项
    # --------------------------------------

    Write-Host ""
    Write-Host "建议完成项" -ForegroundColor Yellow
    Write-Host "----------------------------------------------"

    Add-Report ""
    Add-Report "建议完成项"
    Add-Report "----------------------------------------------"

    if ($script:SuggestedActions.Count -eq 0) {
        Write-Host "无。当前没有额外建议项。" -ForegroundColor Green
        Add-Report "无。当前没有额外建议项。"
    }
    else {
        $SuggestedNumber = 1

        foreach ($SuggestedAction in $script:SuggestedActions) {
            Write-Host "$SuggestedNumber. $SuggestedAction" -ForegroundColor Yellow
            Add-Report "$SuggestedNumber. $SuggestedAction"

            $SuggestedNumber++
        }
    }


    # --------------------------------------
    # 保存报告
    # Windows PowerShell 5.1 的 UTF8 会写入 BOM
    # --------------------------------------

    Add-Report ""
    Add-Report "完成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Report "安全说明：报告不记录 Token、API Key、密码或代理凭据。"

    $script:Report |
        Set-Content `
            -LiteralPath $script:LogFile `
            -Encoding UTF8

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " 工作区恢复检查完成" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "恢复报告：$script:LogFile"
}
catch {
    $FatalMessage = $_.Exception.Message

    Write-Host ""
    Write-Host "工作区恢复工具发生错误：$FatalMessage" -ForegroundColor Red

    if ($null -ne $script:Report) {
        Add-Report ""
        Add-Report "致命错误：$FatalMessage"

        if (
            -not [string]::IsNullOrWhiteSpace(
                $script:LogFile
            )
        ) {
            try {
                $script:Report |
                    Set-Content `
                        -LiteralPath $script:LogFile `
                        -Encoding UTF8

                Write-Host "错误报告：$script:LogFile"
            }
            catch {
                Write-Host "无法保存错误报告。" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
[void](
    Read-Host "按 Enter 键关闭窗口"
)
