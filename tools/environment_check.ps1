# ==========================================
# Codex Design 环境检查工具 V2.1.2
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

$ErrorActionPreference = "Stop"


# ==========================================
# 创建标准检查结果
# ==========================================

function New-CheckResult {
    param(
        [string]$Value,

        [ValidateSet(
            "Success",
            "Warning",
            "Failure"
        )]
        [string]$Status
    )

    return [PSCustomObject]@{
        Value  = $Value
        Status = $Status
    }
}


# ==========================================
# 检查普通命令版本
# ==========================================

function Get-CommandVersionResult {
    param(
        [string]$CommandName,
        [string[]]$Arguments = @("--version")
    )

    $Command = Get-Command `
        $CommandName `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $Command) {
        return New-CheckResult `
            -Value "未安装" `
            -Status "Failure"
    }

    try {
        $VersionOutput = @(
            & $Command.Source @Arguments 2>&1
        )

        $ExitCode = $LASTEXITCODE

        if (
            $ExitCode -ne 0 -or
            $VersionOutput.Count -eq 0
        ) {
            return New-CheckResult `
                -Value "已安装，但无法读取版本" `
                -Status "Failure"
        }

        $FirstLine = (
            [string](
                $VersionOutput |
                Select-Object -First 1
            )
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($FirstLine)) {
            return New-CheckResult `
                -Value "已安装，但无版本信息" `
                -Status "Failure"
        }

        return New-CheckResult `
            -Value $FirstLine `
            -Status "Success"
    }
    catch {
        return New-CheckResult `
            -Value "已安装，但检测失败" `
            -Status "Failure"
    }
}


# ==========================================
# 专门检查 Python
#
# Python 在当前项目中属于可选工具。
# 未安装或只有 Microsoft Store 占位别名时，
# 只记录警告，不记录失败。
# ==========================================

function Get-PythonVersionResult {
    $PythonCommands = @(
        Get-Command `
            "python" `
            -All `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.CommandType -eq "Application"
            } |
            Sort-Object `
                -Property Source `
                -Unique
    )

    $StoreAliasDetected = $false

    foreach ($PythonCommand in $PythonCommands) {
        $PythonPath = [string]$PythonCommand.Source

        if ([string]::IsNullOrWhiteSpace($PythonPath)) {
            continue
        }

        try {
            $PythonOutput = @(
                & $PythonPath --version 2>&1
            )

            $ExitCode = $LASTEXITCODE

            $PythonText = (
                (
                    $PythonOutput |
                    ForEach-Object {
                        [string]$_
                    }
                ) -join " "
            ).Trim()

            if (
                $ExitCode -eq 0 -and
                $PythonText -match "^Python\s+\d"
            ) {
                return New-CheckResult `
                    -Value $PythonText `
                    -Status "Success"
            }

            if (
                $PythonPath -match "\\WindowsApps\\" -or
                $PythonText -match "Python was not found" -or
                $PythonText -match "Microsoft Store" -or
                $PythonText -match "App execution aliases"
            ) {
                $StoreAliasDetected = $true
            }
        }
        catch {
            if ($PythonPath -match "\\WindowsApps\\") {
                $StoreAliasDetected = $true
            }
        }
    }

    # 检查 Windows Python Launcher
    $PythonLauncher = Get-Command `
        "py" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -ne $PythonLauncher) {
        try {
            $LauncherOutput = @(
                & $PythonLauncher.Source --version 2>&1
            )

            $LauncherExitCode = $LASTEXITCODE

            $LauncherText = (
                (
                    $LauncherOutput |
                    ForEach-Object {
                        [string]$_
                    }
                ) -join " "
            ).Trim()

            if (
                $LauncherExitCode -eq 0 -and
                $LauncherText -match "^Python\s+\d"
            ) {
                return New-CheckResult `
                    -Value "$LauncherText（通过 py 启动器）" `
                    -Status "Success"
            }
        }
        catch {
            # Python 属于可选项，此处不终止整个检查。
        }
    }

    if ($StoreAliasDetected) {
        return New-CheckResult `
            -Value "未安装（仅检测到 Microsoft Store 应用执行别名）" `
            -Status "Warning"
    }

    return New-CheckResult `
        -Value "未安装（当前项目暂不依赖 Python）" `
        -Status "Warning"
}


# ==========================================
# 从候选路径中查找第一个有效路径
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
                Resolve-Path -LiteralPath $Candidate
            ).Path
        }
    }

    return "未找到"
}


# ==========================================
# 添加普通报告行
# ==========================================

function Add-Report {
    param(
        [string]$Text
    )

    $script:Report.Add($Text)
}


# ==========================================
# 添加带状态的报告行并统计
# ==========================================

function Add-Status {
    param(
        [string]$Name,
        [string]$Value,

        [ValidateSet(
            "Success",
            "Warning",
            "Failure"
        )]
        [string]$Status
    )

    switch ($Status) {
        "Success" {
            $script:SuccessCount++
            Add-Report "✓ $Name：$Value"
        }

        "Warning" {
            $script:WarningCount++
            Add-Report "⚠ $Name：$Value"
        }

        "Failure" {
            $script:FailCount++
            Add-Report "❌ $Name：$Value"
        }
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
    # 日志目录
    # --------------------------------------

    $LogsPath = Join-Path `
        $ProjectPath `
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

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $LogFile = Join-Path `
        $LogsPath `
        "environment_check_$Timestamp.txt"


    # --------------------------------------
    # 初始化报告和统计
    # --------------------------------------

    $Report = New-Object `
        "System.Collections.Generic.List[string]"

    $SuccessCount = 0
    $WarningCount = 0
    $FailCount = 0


    # --------------------------------------
    # 报告标题
    # --------------------------------------

    Add-Report "Codex Design 环境检查 V2.1.2"
    Add-Report "========================================"
    Add-Report "检查时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Report "项目目录：$ProjectPath"
    Add-Report ""


    # ======================================
    # 系统环境
    # ======================================

    $OS = Get-CimInstance Win32_OperatingSystem

    $PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    Add-Report "系统"
    Add-Report "----------------------------------------"

    Add-Status `
        -Name "Windows" `
        -Value "$($OS.Caption) $($OS.Version)" `
        -Status "Success"

    Add-Status `
        -Name "PowerShell" `
        -Value $PowerShellVersion `
        -Status "Success"

    Add-Report ""


    # ======================================
    # 开发工具
    # ======================================

    $GitVersion = Get-CommandVersionResult `
        -CommandName "git"

    $NodeVersion = Get-CommandVersionResult `
        -CommandName "node"

    $NpmVersion = Get-CommandVersionResult `
        -CommandName "npm.cmd"

    $PythonVersion = Get-PythonVersionResult

    $CodexVersion = Get-CommandVersionResult `
        -CommandName "codex"

    $VSCodeVersion = Get-CommandVersionResult `
        -CommandName "code"

    Add-Report "开发工具"
    Add-Report "----------------------------------------"

    Add-Status `
        -Name "Git" `
        -Value $GitVersion.Value `
        -Status $GitVersion.Status

    Add-Status `
        -Name "Node.js" `
        -Value $NodeVersion.Value `
        -Status $NodeVersion.Status

    Add-Status `
        -Name "npm" `
        -Value $NpmVersion.Value `
        -Status $NpmVersion.Status

    Add-Status `
        -Name "Python" `
        -Value $PythonVersion.Value `
        -Status $PythonVersion.Status

    Add-Status `
        -Name "Codex" `
        -Value $CodexVersion.Value `
        -Status $CodexVersion.Status

    Add-Status `
        -Name "VS Code" `
        -Value $VSCodeVersion.Value `
        -Status $VSCodeVersion.Status

    Add-Report ""


    # ======================================
    # VS Code 工作区
    # ======================================

    $VSCodeFolder = Join-Path `
        $ProjectPath `
        ".vscode"

    Add-Report "VS Code 工作区"
    Add-Report "----------------------------------------"

    $VSCodeFiles = @(
        "extensions.json",
        "settings.json",
        "tasks.json"
    )

    foreach ($FileName in $VSCodeFiles) {
        $ConfigPath = Join-Path `
            $VSCodeFolder `
            $FileName

        if (
            Test-Path `
                -LiteralPath $ConfigPath `
                -PathType Leaf
        ) {
            Add-Status `
                -Name "VS Code配置" `
                -Value "$FileName：存在" `
                -Status "Success"
        }
        else {
            Add-Status `
                -Name "VS Code配置" `
                -Value "$FileName：缺失" `
                -Status "Failure"
        }
    }

    Add-Report ""


    # ======================================
    # Adobe Beta
    # ======================================

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

    if (
        -not [string]::IsNullOrWhiteSpace(
            $ProgramFilesX86
        )
    ) {
        $PhotoshopCandidates += Join-Path `
            $ProgramFilesX86 `
            "Adobe\Adobe Photoshop (Beta)"
    }

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
        $IllustratorCandidates += Join-Path `
            $ProgramFilesX86 `
            "Adobe\Adobe Illustrator (Beta)"
    }

    $PhotoshopBetaPath = Find-FirstExistingPath `
        -Candidates $PhotoshopCandidates

    $IllustratorBetaPath = Find-FirstExistingPath `
        -Candidates $IllustratorCandidates

    Add-Report "Adobe Beta"
    Add-Report "----------------------------------------"

    if ($PhotoshopBetaPath -eq "未找到") {
        Add-Status `
            -Name "Photoshop Beta" `
            -Value "未找到" `
            -Status "Failure"
    }
    else {
        Add-Status `
            -Name "Photoshop Beta" `
            -Value $PhotoshopBetaPath `
            -Status "Success"
    }

    if ($IllustratorBetaPath -eq "未找到") {
        Add-Status `
            -Name "Illustrator Beta" `
            -Value "未找到" `
            -Status "Failure"
    }
    else {
        Add-Status `
            -Name "Illustrator Beta" `
            -Value $IllustratorBetaPath `
            -Status "Success"
    }


    # --------------------------------------
    # Adobe 安装脚本目录
    # --------------------------------------

    $PhotoshopJSXPath = ""

    if ($PhotoshopBetaPath -ne "未找到") {
        $PhotoshopJSXPath = Join-Path `
            $PhotoshopBetaPath `
            "Presets\Scripts"
    }

    $IllustratorJSXPath = ""

    if ($IllustratorBetaPath -ne "未找到") {
        $IllustratorJSXPath = Join-Path `
            $IllustratorBetaPath `
            "Presets\zh_CN\脚本"
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $PhotoshopJSXPath
        ) -and
        (
            Test-Path `
                -LiteralPath $PhotoshopJSXPath `
                -PathType Container
        )
    ) {
        Add-Status `
            -Name "Photoshop JSX目录" `
            -Value "存在" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "Photoshop JSX目录" `
            -Value "缺失" `
            -Status "Failure"
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $IllustratorJSXPath
        ) -and
        (
            Test-Path `
                -LiteralPath $IllustratorJSXPath `
                -PathType Container
        )
    ) {
        Add-Status `
            -Name "Illustrator JSX目录" `
            -Value "存在" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "Illustrator JSX目录" `
            -Value "缺失" `
            -Status "Failure"
    }

    Add-Report ""


    # ======================================
    # Illustrator MCP
    # ======================================

    Add-Report "MCP"
    Add-Report "----------------------------------------"

    $CodexCommand = Get-Command `
        "codex" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $CodexCommand) {
        Add-Status `
            -Name "Illustrator MCP" `
            -Value "无法检查：未安装 Codex CLI" `
            -Status "Failure"
    }
    else {
        try {
            $McpOutput = @(
                & $CodexCommand.Source mcp list 2>&1
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
                    -Name "Illustrator MCP" `
                    -Value "检查失败" `
                    -Status "Failure"
            }
            elseif (
                $McpText -match "adobe_illustrator" -and
                $McpText -match "enabled"
            ) {
                Add-Status `
                    -Name "Illustrator MCP" `
                    -Value "已配置并启用" `
                    -Status "Success"
            }
            elseif (
                $McpText -match "adobe_illustrator"
            ) {
                Add-Status `
                    -Name "Illustrator MCP" `
                    -Value "已配置，但未确认启用状态" `
                    -Status "Warning"
            }
            else {
                Add-Status `
                    -Name "Illustrator MCP" `
                    -Value "未发现 adobe_illustrator 配置" `
                    -Status "Failure"
            }
        }
        catch {
            Add-Status `
                -Name "Illustrator MCP" `
                -Value "检查失败" `
                -Status "Failure"
        }
    }

    Add-Report ""


    # ======================================
    # Git 仓库与 GitHub
    # ======================================

    Add-Report "Git"
    Add-Report "----------------------------------------"

    $GitCommand = Get-Command `
        "git" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        Add-Status `
            -Name "Git状态" `
            -Value "无法检查：未安装 Git" `
            -Status "Failure"

        Add-Status `
            -Name "GitHub连接" `
            -Value "无法检查：未安装 Git" `
            -Status "Failure"
    }
    else {
        $RepositoryCheck = @(
            & $GitCommand.Source `
                rev-parse `
                --is-inside-work-tree `
                2>&1
        )

        $RepositoryExitCode = $LASTEXITCODE

        if ($RepositoryExitCode -ne 0) {
            Add-Status `
                -Name "Git状态" `
                -Value "当前目录不是有效 Git 仓库" `
                -Status "Failure"

            Add-Status `
                -Name "GitHub连接" `
                -Value "未执行：当前目录不是有效 Git 仓库" `
                -Status "Failure"
        }
        else {
            $GitChanges = @(
                & $GitCommand.Source `
                    status `
                    --porcelain `
                    2>&1
            )

            $GitStatusExitCode = $LASTEXITCODE

            if ($GitStatusExitCode -ne 0) {
                Add-Status `
                    -Name "Git状态" `
                    -Value "检查失败" `
                    -Status "Failure"
            }
            elseif ($GitChanges.Count -gt 0) {
                Add-Status `
                    -Name "Git状态" `
                    -Value "发现本地修改（需要提交）" `
                    -Status "Warning"
            }
            else {
                Add-Status `
                    -Name "Git状态" `
                    -Value "工作区干净" `
                    -Status "Success"
            }

            $PreviousTerminalPrompt = $env:GIT_TERMINAL_PROMPT
            $env:GIT_TERMINAL_PROMPT = "0"

            try {
                $GitHubOutput = @(
                    & $GitCommand.Source `
                        ls-remote `
                        origin `
                        2>&1
                )

                $GitHubExitCode = $LASTEXITCODE

                if ($GitHubExitCode -eq 0) {
                    Add-Status `
                        -Name "GitHub连接" `
                        -Value "正常" `
                        -Status "Success"
                }
                else {
                    Add-Status `
                        -Name "GitHub连接" `
                        -Value "连接失败" `
                        -Status "Failure"
                }
            }
            finally {
                $env:GIT_TERMINAL_PROMPT = $PreviousTerminalPrompt
            }
        }
    }

    Add-Report ""


    # ======================================
    # Windows 网络代理
    # ======================================

    Add-Report "网络"
    Add-Report "----------------------------------------"

    $ProxyInfo = Get-ItemProperty `
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" `
        -ErrorAction SilentlyContinue

    if ($null -eq $ProxyInfo) {
        Add-Status `
            -Name "Windows代理" `
            -Value "无法读取系统代理状态" `
            -Status "Warning"
    }
    elseif ($ProxyInfo.ProxyEnable -eq 1) {
        $ProxyServer = [string]$ProxyInfo.ProxyServer

        if ([string]::IsNullOrWhiteSpace($ProxyServer)) {
            Add-Status `
                -Name "Windows代理" `
                -Value "已启用，但未读取到代理地址" `
                -Status "Warning"
        }
        else {
            Add-Status `
                -Name "Windows代理" `
                -Value "已启用：$ProxyServer" `
                -Status "Success"
        }
    }
    else {
        Add-Status `
            -Name "Windows代理" `
            -Value "未启用（允许使用直连或其他全局网络方式）" `
            -Status "Success"
    }

    Add-Report ""


    # ======================================
    # 检查摘要
    # ======================================

    Add-Report "检查摘要"
    Add-Report "----------------------------------------"
    Add-Report "通过：$SuccessCount"
    Add-Report "警告：$WarningCount"
    Add-Report "失败：$FailCount"
    Add-Report ""

    Add-Report "说明："
    Add-Report "1. Python 是当前项目的可选工具，未安装仅记录为警告。"
    Add-Report "2. Git 存在本地修改时仅记录为警告，不会自动提交或丢弃修改。"
    Add-Report "3. 本报告不记录密码、Token、API Key 或代理凭据。"


    # ======================================
    # 保存报告
    # Windows PowerShell 5.1 的 UTF8 会写入 BOM
    # ======================================

    $Report |
        Set-Content `
            -LiteralPath $LogFile `
            -Encoding UTF8


    # ======================================
    # 输出报告
    # ======================================

    foreach ($Line in $Report) {
        Write-Host $Line
    }

    Write-Host ""
    Write-Host "环境检查完成。" -ForegroundColor Green
    Write-Host "报告文件：$LogFile"
}
catch {
    Write-Host ""
    Write-Host `
        "环境检查失败：$($_.Exception.Message)" `
        -ForegroundColor Red

    exit 1
}

Write-Host ""
[void](
    Read-Host "按 Enter 键关闭窗口"
)