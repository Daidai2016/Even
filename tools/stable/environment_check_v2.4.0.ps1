# ==========================================
# Codex Design 环境检查工具 V2.4.0
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# 主要功能：
# - 检查 Windows 和 PowerShell
# - 检查 Git、Node.js、npm、Python、Codex、VS Code
# - 检查 VS Code 工作区配置
# - 检查 Adobe Beta 和 JSX 目录
# - 检查 Illustrator MCP 配置、令牌变量和实时端口
# - 检查 Git 仓库和 GitHub 连接
# - 强制检查 GitHub 当前代理及其可达性
# - 区分插件缓存、显式启用和 manifest 健康状态
# - 自动生成环境检查报告
# - 每类运行日志只保留最近 30 份
#
# Illustrator MCP 三层健康检查：
# 1. 配置状态
# 2. 令牌变量
# 3. 实时端口
#
# 安全说明：
# - 不显示或记录令牌真实值
# - 不显示或记录 API Key
# - 不显示或记录代理地址和代理凭据
# - 不向 MCP 发送业务请求
# - 不读取或修改 Illustrator 文档
# - 只检查本机 TCP 端口是否正在监听
# - 不执行 force push、reset、clean 等 Git 操作
# ==========================================

param(
    [switch]$SkipRemoteCheck,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"

$ProxyGuardScript = Join-Path `
    $PSScriptRoot `
    "lib\github_proxy_guard.ps1"

if (-not (Test-Path -LiteralPath $ProxyGuardScript -PathType Leaf)) {
    throw "缺少 GitHub 代理门禁：tools/lib/github_proxy_guard.ps1"
}

. $ProxyGuardScript


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
# 安全执行原生命令
#
# 作用：
# - 捕获标准输出和错误输出
# - 返回退出代码
# - 原生命令失败时不终止整个环境检查
# - 兼容 Windows PowerShell 5.1 和新版 PowerShell
# ==========================================

function Invoke-NativeCommandSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @()
    )

    $OldNativeErrorPreference = $null
    $HasNativeErrorPreference = $false

    $NativePreferenceVariable = Get-Variable `
        -Name "PSNativeCommandUseErrorActionPreference" `
        -ErrorAction SilentlyContinue

    if ($null -ne $NativePreferenceVariable) {
        $HasNativeErrorPreference = $true
        $OldNativeErrorPreference =
            $PSNativeCommandUseErrorActionPreference

        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $Output = @(
            & $FilePath @Arguments 2>&1
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
        if ($HasNativeErrorPreference) {
            $PSNativeCommandUseErrorActionPreference =
                $OldNativeErrorPreference
        }
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

    $CommandResult = Invoke-NativeCommandSafe `
        -FilePath $Command.Source `
        -Arguments $Arguments

    if (
        $CommandResult.ExitCode -ne 0 -or
        $CommandResult.Output.Count -eq 0
    ) {
        return New-CheckResult `
            -Value "已安装，但无法读取版本" `
            -Status "Failure"
    }

    $FirstLine = (
        [string](
            $CommandResult.Output |
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

        $PythonResult = Invoke-NativeCommandSafe `
            -FilePath $PythonPath `
            -Arguments @("--version")

        $PythonText = (
            (
                $PythonResult.Output |
                    ForEach-Object {
                        [string]$_
                    }
            ) -join " "
        ).Trim()

        if (
            $PythonResult.ExitCode -eq 0 -and
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

    # 检查 Windows Python Launcher。

    $PythonLauncher = Get-Command `
        "py.exe" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -ne $PythonLauncher) {
        $LauncherResult = Invoke-NativeCommandSafe `
            -FilePath $PythonLauncher.Source `
            -Arguments @("--version")

        $LauncherText = (
            (
                $LauncherResult.Output |
                    ForEach-Object {
                        [string]$_
                    }
            ) -join " "
        ).Trim()

        if (
            $LauncherResult.ExitCode -eq 0 -and
            $LauncherText -match "^Python\s+\d"
        ) {
            return New-CheckResult `
                -Value "$LauncherText（通过 py 启动器）" `
                -Status "Success"
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

        if (
            Test-Path `
                -LiteralPath $Candidate
        ) {
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
# 只返回存在状态。
# 不显示、不记录、不验证变量真实值。
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

        $ConnectedInTime =
            $AsyncResult.AsyncWaitHandle.WaitOne(
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
# 清理本地运行日志
#
# 每种日志分别保留最近 Keep 份。
#
# 当前管理：
# - environment_check_*.txt
# - bootstrap_workspace_*.txt
#
# 安全限制：
# - 只操作项目 logs 目录
# - 只删除符合指定命名规则的文件
# - 不删除目录
# - 不操作其他项目文件
# ==========================================

function Invoke-RuntimeLogCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogsPath,

        [ValidateRange(1, 1000)]
        [int]$Keep = 30
    )

    $Details = New-Object `
        "System.Collections.Generic.List[string]"

    $Warnings = New-Object `
        "System.Collections.Generic.List[string]"

    $TotalFound = 0
    $TotalRemoved = 0
    $TotalRemaining = 0

    if (
        -not (
            Test-Path `
                -LiteralPath $LogsPath `
                -PathType Container
        )
    ) {
        return [PSCustomObject]@{
            TotalFound     = 0
            TotalRemoved   = 0
            TotalRemaining = 0
            Details        = @(
                "日志目录不存在，无需清理。"
            )
            Warnings       = @()
        }
    }

    $CleanupRules = @(
        [PSCustomObject]@{
            Name   = "环境检查日志"
            Filter = "environment_check_*.txt"
        },
        [PSCustomObject]@{
            Name   = "工作区恢复日志"
            Filter = "bootstrap_workspace_*.txt"
        }
    )

    $LogsRoot = [System.IO.Path]::GetFullPath(
        $LogsPath
    )

    $LogsRoot = $LogsRoot.TrimEnd(
        [char[]]@(
            "\",
            "/"
        )
    ) + [System.IO.Path]::DirectorySeparatorChar

    foreach ($Rule in $CleanupRules) {
        try {
            $Files = @(
                Get-ChildItem `
                    -LiteralPath $LogsPath `
                    -Filter $Rule.Filter `
                    -File `
                    -ErrorAction SilentlyContinue |
                    Sort-Object `
                        -Property LastWriteTimeUtc, Name `
                        -Descending
            )

            $FilesToRemove = @(
                $Files |
                    Select-Object `
                        -Skip $Keep
            )

            $RemovedForRule = 0

            foreach ($File in $FilesToRemove) {
                try {
                    $FullFilePath =
                        [System.IO.Path]::GetFullPath(
                            $File.FullName
                        )

                    if (
                        -not $FullFilePath.StartsWith(
                            $LogsRoot,
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    ) {
                        [void]$Warnings.Add(
                            "拒绝删除 logs 目录之外的文件：$FullFilePath"
                        )

                        continue
                    }

                    if ($File.Name -notlike $Rule.Filter) {
                        [void]$Warnings.Add(
                            "拒绝删除不符合日志规则的文件：$($File.Name)"
                        )

                        continue
                    }

                    Remove-Item `
                        -LiteralPath $FullFilePath `
                        -Force `
                        -ErrorAction Stop

                    $RemovedForRule++
                    $TotalRemoved++
                }
                catch {
                    [void]$Warnings.Add(
                        "$($Rule.Name)清理失败：$($File.Name)"
                    )
                }
            }

            $RemainingForRule =
                $Files.Count -
                $RemovedForRule

            $TotalFound += $Files.Count
            $TotalRemaining += $RemainingForRule

            [void]$Details.Add(
                "$($Rule.Name)：找到 $($Files.Count) 份，删除 $RemovedForRule 份，保留 $RemainingForRule 份。"
            )
        }
        catch {
            [void]$Warnings.Add(
                "$($Rule.Name)统计或清理失败。"
            )
        }
    }

    return [PSCustomObject]@{
        TotalFound     = $TotalFound
        TotalRemoved   = $TotalRemoved
        TotalRemaining = $TotalRemaining
        Details        = @($Details)
        Warnings       = @($Warnings)
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

    Add-Report "Codex Design 环境检查 V2.4.0"
    Add-Report "========================================"
    Add-Report "检查时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Report "项目目录：$ProjectPath"
    Add-Report ""


    # ======================================
    # 系统环境
    # ======================================

    $OS = Get-CimInstance `
        Win32_OperatingSystem `
        -ErrorAction Stop

    $PowerShellVersion =
        $PSVersionTable.PSVersion.ToString()

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
        -CommandName "codex.cmd"

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
    # Codex 插件状态
    # ======================================

    Add-Report "Codex插件"
    Add-Report "----------------------------------------"

    $ProjectCodexConfigPath = Join-Path `
        $ProjectPath `
        ".codex\config.toml"
    $ProjectHooksManifestPath = Join-Path `
        $ProjectPath `
        ".codex\hooks.json"
    $RequiredHookFiles = @(
        (Join-Path $ProjectPath ".codex\hooks\pre_tool_use_policy.ps1"),
        (Join-Path $ProjectPath ".codex\hooks\post_tool_use_validate.ps1")
    )

    if (Test-Path -LiteralPath $ProjectCodexConfigPath -PathType Leaf) {
        Add-Status `
            -Name "项目Codex配置" `
            -Value "已部署" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "项目Codex配置" `
            -Value "缺失" `
            -Status "Failure"
    }

    $HooksHealthy = Test-Path `
        -LiteralPath $ProjectHooksManifestPath `
        -PathType Leaf

    foreach ($HookFile in $RequiredHookFiles) {
        if (-not (Test-Path -LiteralPath $HookFile -PathType Leaf)) {
            $HooksHealthy = $false
        }
    }

    if ($HooksHealthy) {
        try {
            [void](
                Get-Content `
                    -LiteralPath $ProjectHooksManifestPath `
                    -Raw `
                    -Encoding UTF8 |
                    ConvertFrom-Json
            )
        }
        catch {
            $HooksHealthy = $false
        }
    }

    Add-Status `
        -Name "安全Hooks" `
        -Value $(if ($HooksHealthy) { "已部署且清单有效" } else { "缺失或清单无效" }) `
        -Status $(if ($HooksHealthy) { "Success" } else { "Failure" })

    $UserProfilePath = [Environment]::GetFolderPath("UserProfile")

    if ([string]::IsNullOrWhiteSpace($UserProfilePath)) {
        $UserProfilePath = [string]$env:USERPROFILE
    }

    $CodexHomePath = Join-Path $UserProfilePath ".codex"
    $PluginCachePath = Join-Path $CodexHomePath "plugins\cache"
    $CachedPluginNames = New-Object `
        "System.Collections.Generic.HashSet[string]" `
        ([System.StringComparer]::OrdinalIgnoreCase)

    if (Test-Path -LiteralPath $PluginCachePath -PathType Container) {
        foreach ($ManifestFile in @(
            Get-ChildItem `
                -LiteralPath $PluginCachePath `
                -Recurse `
                -Force `
                -Filter "plugin.json" `
                -File `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.DirectoryName -match "[\\/]\.codex-plugin$"
                }
        )) {
            try {
                $ManifestData = Get-Content `
                    -LiteralPath $ManifestFile.FullName `
                    -Raw `
                    -Encoding UTF8 |
                    ConvertFrom-Json

                if (-not [string]::IsNullOrWhiteSpace(
                    [string]$ManifestData.name
                )) {
                    [void]$CachedPluginNames.Add(
                        [string]$ManifestData.name
                    )
                }
            }
            catch {
                # 单个缓存 manifest 异常不暴露路径。
            }
        }
    }

    $InstalledPlugins = @()
    $PluginQuerySucceeded = $false
    $CodexCommand = Get-Command "codex.cmd" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -ne $CodexCommand) {
        try {
            $PluginListOutput = @(
                & $CodexCommand.Source plugin list --json 2>$null
            )

            if ($LASTEXITCODE -eq 0) {
                $PluginListData = ($PluginListOutput -join `
                    [Environment]::NewLine) |
                    ConvertFrom-Json

                $InstalledPlugins = @($PluginListData.installed)
                $PluginQuerySucceeded = $true
            }
        }
        catch {
            $PluginQuerySucceeded = $false
        }
    }

    Add-Status `
        -Name "插件缓存" `
        -Value "$($CachedPluginNames.Count) 个可识别插件包" `
        -Status "Success"

    if ($PluginQuerySucceeded) {
        $EnabledPlugins = @(
            $InstalledPlugins | Where-Object { $_.enabled -eq $true }
        )

        Add-Status `
            -Name "插件安装" `
            -Value "$($InstalledPlugins.Count) 个已安装，$($EnabledPlugins.Count) 个已启用" `
            -Status "Success"

        $WorkspacePlugin = @(
            $InstalledPlugins |
                Where-Object {
                    $_.pluginId -eq `
                        "codex-design-workflows@codex-design" -and
                    $_.enabled -eq $true
                }
        )

        if ($WorkspacePlugin.Count -gt 0) {
            Add-Status `
                -Name "项目工作流插件" `
                -Value "已安装并启用" `
                -Status "Success"
        }
        else {
            Add-Status `
                -Name "项目工作流插件" `
                -Value "未安装或未启用" `
                -Status "Warning"
        }
    }
    else {
        Add-Status `
            -Name "插件安装" `
            -Value "Codex CLI 当前无法读取插件状态" `
            -Status "Warning"
    }

    Add-Report "插件授权：按连接器或 MCP 独立管理；本检查不读取凭据。"
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
        "tasks.json",
        "launch.json"
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

    $ProgramFilesX86 =
        [Environment]::GetEnvironmentVariable(
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
    $McpTokenVariableName =
        "ADOBE_ILLUSTRATOR_MCP_BEARER_TOKEN"

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
        $McpResult = Invoke-NativeCommandSafe `
            -FilePath $CodexCommand.Source `
            -Arguments @(
                "mcp",
                "list"
            )

        $McpText = (
            (
                $McpResult.Output |
                    ForEach-Object {
                        [string]$_
                    }
            ) -join "`n"
        )

        if ($McpResult.ExitCode -ne 0) {
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


    # --------------------------------------
    # 第二层：令牌变量
    #
    # 只检查变量是否存在。
    # 不显示、不记录、不验证真实值。
    # --------------------------------------

    $McpTokenExists =
        Test-EnvironmentVariableExists `
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

    $ProxyGuardResult = $null

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
        $RepositoryResult =
            Invoke-NativeCommandSafe `
                -FilePath $GitCommand.Source `
                -Arguments @(
                    "rev-parse",
                    "--is-inside-work-tree"
                )

        $RepositoryText = (
            [string](
                $RepositoryResult.Output |
                    Select-Object -First 1
            )
        ).Trim()

        if (
            $RepositoryResult.ExitCode -ne 0 -or
            $RepositoryText -ne "true"
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
            $GitStatusResult =
                Invoke-NativeCommandSafe `
                    -FilePath $GitCommand.Source `
                    -Arguments @(
                        "status",
                        "--porcelain"
                    )

            if ($GitStatusResult.ExitCode -ne 0) {
                Add-Status `
                    -Name "Git状态" `
                    -Value "检查失败" `
                    -Status "Failure"
            }
            elseif ($GitStatusResult.Output.Count -gt 0) {
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


            # ----------------------------------
            # 检查 origin 是否存在
            # ----------------------------------

            $RemoteResult =
                Invoke-NativeCommandSafe `
                    -FilePath $GitCommand.Source `
                    -Arguments @(
                        "remote",
                        "get-url",
                        "origin"
                    )

            if ($RemoteResult.ExitCode -ne 0) {
                Add-Status `
                    -Name "GitHub连接" `
                    -Value "未发现 origin 远程仓库" `
                    -Status "Failure"
            }
            else {
                $ProxyGuardResult = Test-GitHubProxyGuard `
                    -ProjectPath $ProjectPath

                if (-not $ProxyGuardResult.Success) {
                    Add-Status `
                        -Name "GitHub连接" `
                        -Value "未执行：$($ProxyGuardResult.Message)" `
                        -Status "Warning"
                }
                elseif ($SkipRemoteCheck) {
                    Add-Status `
                        -Name "GitHub连接" `
                        -Value "已跳过远程连接；代理门禁已通过" `
                        -Status "Success"
                }
                else {
                    $PreviousGitPrompt =
                        $env:GIT_TERMINAL_PROMPT

                    $env:GIT_TERMINAL_PROMPT = "0"

                    try {
                        $GitHubResult =
                            Invoke-NativeCommandSafe `
                                -FilePath $GitCommand.Source `
                                -Arguments @(
                                    "ls-remote",
                                    "origin"
                                )
                    }
                    finally {
                        $env:GIT_TERMINAL_PROMPT =
                            $PreviousGitPrompt
                    }

                    if ($GitHubResult.ExitCode -eq 0) {
                        Add-Status `
                            -Name "GitHub连接" `
                            -Value "正常（已强制通过代理）" `
                            -Status "Success"
                    }
                    else {
                        Add-Status `
                            -Name "GitHub连接" `
                            -Value "暂时无法连接（代理已验证；请检查登录或 GitHub 状态）" `
                            -Status "Warning"
                    }
                }
            }
        }
    }

    Add-Report ""


    # ======================================
    # GitHub 网络代理
    # ======================================

    Add-Report "网络"
    Add-Report "----------------------------------------"

    if ($null -eq $ProxyGuardResult) {
        Add-Status `
            -Name "GitHub代理" `
            -Value "未完成检查" `
            -Status "Warning"
    }
    elseif ($ProxyGuardResult.Success) {
        Add-Status `
            -Name "GitHub代理" `
            -Value "已通过脱敏检查（$($ProxyGuardResult.Source)）" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "GitHub代理" `
            -Value $ProxyGuardResult.Message `
            -Status "Warning"
    }

    Add-Report ""


    # ======================================
    # 日志管理
    #
    # 先创建本次日志占位文件，
    # 确保本次报告计入最近 30 份。
    # ======================================

    New-Item `
        -ItemType File `
        -Path $LogFile `
        -Force |
        Out-Null

    $LogCleanupResult =
        Invoke-RuntimeLogCleanup `
            -LogsPath $LogsPath `
            -Keep 30

    Add-Report "日志管理"
    Add-Report "----------------------------------------"

    if ($LogCleanupResult.Warnings.Count -eq 0) {
        Add-Status `
            -Name "日志保留规则" `
            -Value "每类保留最近 30 份；本次删除 $($LogCleanupResult.TotalRemoved) 份" `
            -Status "Success"
    }
    else {
        Add-Status `
            -Name "日志保留规则" `
            -Value "已执行，但存在 $($LogCleanupResult.Warnings.Count) 条清理警告" `
            -Status "Warning"
    }

    foreach ($Detail in $LogCleanupResult.Details) {
        Add-Report "  $Detail"
    }

    foreach ($CleanupWarning in $LogCleanupResult.Warnings) {
        Add-Report "  ⚠ $CleanupWarning"
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
    Add-Report "3. GitHub 网络、DNS 或代理异常只记录为警告，不会中断环境检查。"
    Add-Report "4. Illustrator MCP 使用配置、令牌变量和实时端口三层检查。"
    Add-Report "5. Illustrator 未启动或端口未监听时只记录为警告。"
    Add-Report "6. 端口检查只建立本机 TCP 测试，不发送 MCP 请求。"
    Add-Report "7. 本脚本不会读取或修改 Illustrator 文档。"
    Add-Report "8. 每种运行日志分别保留最近 30 份。"
    Add-Report "9. 本报告不记录密码、Token、API Key、代理地址或代理凭据。"


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

if (-not $NoPause) {
    Write-Host ""
    [void](
        Read-Host "按 Enter 键关闭窗口"
    )
}
