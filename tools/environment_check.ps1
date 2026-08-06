# ==========================================
# Codex Design 环境检查工具 V2.2.0
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# Illustrator MCP 三层健康检查：
# 1. 配置状态
# 2. 令牌变量
# 3. 实时端口
#
# 安全说明：
# - 不显示或记录令牌真实值
# - 不向 MCP 发送业务请求
# - 不读取或修改 Illustrator 文档
# - 只检查本机 TCP 端口是否正在监听
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
            "python.exe" `
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

            $PythonExitCode = $LASTEXITCODE

            $PythonText = (
                (
                    $PythonOutput |
                        ForEach-Object {
                            [string]$_
                        }
                ) -join " "
            ).Trim()

            if (
                $PythonExitCode -eq 0 -and
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

    # 检查 Windows Python Launcher。

    $PythonLauncher = Get-Command `
        "py.exe" `
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
            # Python 属于可选工具，不终止整个检查。
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
                Resolve-Path `
                    -LiteralPath $Candidate
            ).Path
        }
    }

    return "未找到"
}


# ==========================================
# 检查环境变量是否存在
#
# 只返回存在状态，不读取到报告，
# 不显示或记录变量真实值。
# ==========================================

function Test-EnvironmentVariableExists {
    param(
        [string]$VariableName
    )

    $ProcessValue = $null
    $UserValue = $null
    $MachineValue = $null

    try {
        $ProcessValue = [Environment]::GetEnvironmentVariable(
            $VariableName,
            [System.EnvironmentVariableTarget]::Process
        )
    }
    catch {
        $ProcessValue = $null
    }

    try {
        $UserValue = [Environment]::GetEnvironmentVariable(
            $VariableName,
            [System.EnvironmentVariableTarget]::User
        )
    }
    catch {
        $UserValue = $null
    }

    try {
        $MachineValue = [Environment]::GetEnvironmentVariable(
            $VariableName,
            [System.EnvironmentVariableTarget]::Machine
        )
    }
    catch {
        $MachineValue = $null
    }

    $Exists = $false

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$ProcessValue
        )
    ) {
        $Exists = $true
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$UserValue
        )
    ) {
        $Exists = $true
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$MachineValue
        )
    ) {
        $Exists = $true
    }

    # 主动清除局部变量引用。

    $ProcessValue = $null
    $UserValue = $null
    $MachineValue = $null

    return $Exists
}


# ==========================================
# 检查 TCP 端口
#
# 仅建立本机 TCP 连接测试。
# 不发送 HTTP、MCP 或 Illustrator 指令。
# ==========================================

function Test-TcpPort {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMilliseconds = 800
    )

    $TcpClient = New-Object `
        System.Net.Sockets.TcpClient

    $AsyncResult = $null

    try {
        $AsyncResult = $TcpClient.BeginConnect(
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

        $TcpClient.EndConnect($AsyncResult)

        return $TcpClient.Connected
    }
    catch {
        return $false
    }
    finally {
        if (
            $null -ne $AsyncResult -and
            $null -ne $AsyncResult.AsyncWaitHandle
        ) {
            $AsyncResult.AsyncWaitHandle.Close()
        }

        $TcpClient.Close()
    }
}


# ==========================================
# 添加普通报告行
# ==========================================

function Add-Report {
    param(
        [string]$Text
    )

    [void]$script:Report.Add($Text)
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

    Add-Report "Codex Design 环境检查 V2.2.0"
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
    # Adobe 脚本目录
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
    # Illustrator MCP 三层健康检查
    # ======================================

    Add-Report "Illustrator MCP"
    Add-Report "----------------------------------------"

    $McpName = "adobe_illustrator"
    $McpTokenVariableName = "ADOBE_ILLUSTRATOR_MCP_BEARER_TOKEN"
    $McpHost = "127.0.0.1"
    $McpPort = 18412


    # --------------------------------------
    # 第一层：配置状态
    # --------------------------------------

    $CodexCommand = Get-Command `
        "codex" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $CodexCommand) {
        Add-Status `
            -Name "配置状态" `
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
                    -Name "配置状态" `
                    -Value "codex mcp list 检查失败" `
                    -Status "Failure"
            }
            elseif (
                $McpText -match [regex]::Escape($McpName) -and
                $McpText -match "(?i)\benabled\b"
            ) {
                Add-Status `
                    -Name "配置状态" `
                    -Value "$McpName 已配置并启用" `
                    -Status "Success"
            }
            elseif (
                $McpText -match [regex]::Escape($McpName)
            ) {
                Add-Status `
                    -Name "配置状态" `
                    -Value "$McpName 已配置，但未确认启用状态" `
                    -Status "Warning"
            }
            else {
                Add-Status `
                    -Name "配置状态" `
                    -Value "未发现 $McpName 配置" `
                    -Status "Failure"
            }
        }
        catch {
            Add-Status `
                -Name "配置状态" `
                -Value "检查失败" `
                -Status "Failure"
        }
    }


    # --------------------------------------
    # 第二层：令牌变量
    #
    # 只检查变量是否存在。
    # 不显示、不记录、不验证真实值。
    # --------------------------------------

    $McpTokenExists = Test-EnvironmentVariableExists `
        -VariableName $McpTokenVariableName

    if ($McpTokenExists) {
        Add-Status `
            -Name "令牌变量" `
            -Value "$McpTokenVariableName 已存在（值不显示）" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "令牌变量" `
            -Value "$McpTokenVariableName 未配置" `
            -Status "Warning"
    }


    # --------------------------------------
    # 第三层：实时端口
    #
    # 只检测本机 18412 TCP 端口。
    # 不发送 MCP 请求，不读取 Illustrator 文档。
    # --------------------------------------

    $McpPortOpen = Test-TcpPort `
        -ComputerName $McpHost `
        -Port $McpPort `
        -TimeoutMilliseconds 800

    if ($McpPortOpen) {
        Add-Status `
            -Name "实时端口" `
            -Value "$McpHost`:$McpPort 正在监听（Illustrator MCP 服务可访问）" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "实时端口" `
            -Value "$McpPort 当前未监听（Illustrator 可能未启动或 MCP 尚未开启）" `
            -Status "Warning"
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

        if (
            $RepositoryExitCode -ne 0 -or
            $RepositoryCheck.Count -eq 0 -or
            ([string]$RepositoryCheck[0]).Trim() -ne "true"
        ) {
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

            $PreviousGitPrompt = $env:GIT_TERMINAL_PROMPT
            $env:GIT_TERMINAL_PROMPT = "0"

            try {
                $GitHubOutput = @(
                    & $GitCommand.Source `
                        ls-remote `
                        origin `
                        2>&1
                )

                $GitHubExitCode = $LASTEXITCODE
            }
            finally {
                $env:GIT_TERMINAL_PROMPT = $PreviousGitPrompt
            }

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
    Add-Report "3. Illustrator MCP 使用配置、令牌变量和实时端口三层检查。"
    Add-Report "4. Illustrator 未启动或端口未监听时只记录为警告。"
    Add-Report "5. 端口检查只建立本机 TCP 测试，不发送 MCP 请求。"
    Add-Report "6. 本脚本不会读取或修改 Illustrator 文档。"
    Add-Report "7. 本报告不记录密码、Token、API Key 或代理凭据。"


    # ======================================
    # 保存报告
    #
    # Windows PowerShell 5.1 的 UTF8
    # 会写入 UTF-8 BOM。
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