# =============================================
# Even Codex Design Desktop Workspace Generator
#
# Version: 2.2.1
#
# 功能：
# 1. 自动识别当前项目根目录
# 2. 读取 tools/config/shortcut_config.json
# 3. 根据 JSON 配置创建桌面快捷方式
# 4. 自动检测 Photoshop Beta 与 Illustrator Beta
# 5. 自动匹配仓库中的 ICO 图标
# 6. 创建 Even Codex Design 桌面工作台
# 7. 生成详细安装日志
# 8. 为工作台和分类目录设置自定义文件夹图标
# 9. 创建动态指向当前仓库根目录的本地项目快捷方式
# 10. 优先使用 Windows Terminal 打开 PowerShell 项目终端
#
# 兼容环境：
# Windows 10
# Windows PowerShell 5.1
#
# 文件编码：
# UTF-8 with BOM
# =============================================

param(
    [string]$OutputRoot = "",
    [switch]$ValidationMode
)


$ErrorActionPreference = "Stop"

$ToolVersion = "2.2.1"


# =============================================
# 一、项目基础路径
# =============================================


# 当前脚本位于 tools 目录
# tools 的上一级为项目根目录

$ProjectPath = Join-Path $PSScriptRoot ".."

$ProjectPath = (Resolve-Path $ProjectPath).Path


$ToolsPath = Join-Path $ProjectPath "tools"

$ConfigPath = Join-Path $ToolsPath "config"

$ToolsDocsPath = Join-Path $ToolsPath "docs"

$IconPath = Join-Path $ProjectPath "assets\icons\ico"

$LogsPath = Join-Path $ProjectPath "logs"

$ScriptsPath = Join-Path $ProjectPath "scripts"


# =============================================
# 二、项目文件路径
# =============================================


$AgentsFile = Join-Path $ProjectPath "AGENTS.md"

$CodingRulesFile = Join-Path $ProjectPath "CODING_RULES.md"

$EnvironmentFile = Join-Path $ToolsDocsPath "ENVIRONMENT.md"

$ShortcutConfigFile = Join-Path `
    $ConfigPath `
    "shortcut_config.json"


# =============================================
# 三、工具脚本路径
# =============================================


$GitStatusScript = Join-Path `
    $ToolsPath `
    "git_status.ps1"


$GitSyncScript = Join-Path `
    $ToolsPath `
    "git_sync.ps1"


$GitPublishScript = Join-Path `
    $ToolsPath `
    "git_publish.ps1"


$EnvironmentCheckScript = Join-Path `
    $ToolsPath `
    "environment_check.ps1"


$BackupScript = Join-Path `
    $ToolsPath `
    "backup_project.ps1"


# =============================================
# 四、项目脚本目录
# =============================================


$PhotoshopJsxPath = Join-Path `
    $ProjectPath `
    "scripts\photoshop\jsx"


$IllustratorJsxPath = Join-Path `
    $ProjectPath `
    "scripts\illustrator\jsx"


# =============================================
# 五、Windows 系统程序
# =============================================


$PowerShellExe = Join-Path `
    $env:SystemRoot `
    "System32\WindowsPowerShell\v1.0\powershell.exe"


$ExplorerExe = Join-Path `
    $env:SystemRoot `
    "explorer.exe"


$NotepadExe = Join-Path `
    $env:SystemRoot `
    "System32\notepad.exe"


# =============================================
# 六、桌面路径
# =============================================


if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
}
else {
    $DesktopPath = [IO.Path]::GetFullPath($OutputRoot)
}


# =============================================
# 七、创建日志目录
# =============================================


if (-not (Test-Path -LiteralPath $LogsPath -PathType Container)) {

    New-Item `
        -ItemType Directory `
        -Path $LogsPath `
        -Force |
        Out-Null
}


$LogFile = Join-Path `
    $LogsPath `
    "shortcut_install.log"


# =============================================
# 八、运行统计
# =============================================


$script:ShortcutSuccessCount = 0

$script:ShortcutFailureCount = 0

$script:WarningCount = 0

$script:FolderIconSuccessCount = 0

$script:FolderIconFailureCount = 0


# =============================================
# 九、日志函数
# =============================================


function Write-SetupLog {

    param(

        [string]$Message,

        [ValidateSet(
            "INFO",
            "SUCCESS",
            "WARNING",
            "ERROR"
        )]
        [string]$Level = "INFO"
    )


    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $LogLine = "[$Time] [$Level] $Message"


    Add-Content `
        -LiteralPath $LogFile `
        -Value $LogLine `
        -Encoding UTF8


    switch ($Level) {

        "SUCCESS" {

            Write-Host `
                $Message `
                -ForegroundColor Green
        }

        "WARNING" {

            Write-Host `
                $Message `
                -ForegroundColor Yellow

            $script:WarningCount++
        }

        "ERROR" {

            Write-Host `
                $Message `
                -ForegroundColor Red
        }

        default {

            Write-Host $Message
        }
    }
}


# =============================================
# 十、暂停退出函数
# =============================================


function Wait-BeforeExit {

    if ($ValidationMode) {
        return
    }

    Write-Host ""

    [void](Read-Host "按 Enter 键关闭窗口")
}


# =============================================
# 十一、参数加引号函数
# =============================================


function Quote-Argument {

    param(
        [string]$Value
    )


    return '"' + $Value + '"'
}


# =============================================
# 十二、写入本次运行日志头
# =============================================


Add-Content `
    -LiteralPath $LogFile `
    -Value "" `
    -Encoding UTF8


Add-Content `
    -LiteralPath $LogFile `
    -Value "==================================================" `
    -Encoding UTF8


Add-Content `
    -LiteralPath $LogFile `
    -Value "Even Codex Design Desktop Setup V$ToolVersion" `
    -Encoding UTF8


Add-Content `
    -LiteralPath $LogFile `
    -Value "运行时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" `
    -Encoding UTF8


# =============================================
# 十三、启动界面
# =============================================


Write-Host ""

Write-Host "============================================="

Write-Host " Even Codex Design Desktop Setup"

Write-Host " Version $ToolVersion"

Write-Host "============================================="

Write-Host ""


Write-SetupLog "项目路径：$ProjectPath"

Write-SetupLog "桌面路径：$DesktopPath"


# =============================================
# 十四、验证项目结构
# =============================================


$MissingProjectItems = @()


if (-not (
    Test-Path `
        -LiteralPath $AgentsFile `
        -PathType Leaf
)) {

    $MissingProjectItems += "AGENTS.md"
}


if (-not (
    Test-Path `
        -LiteralPath $CodingRulesFile `
        -PathType Leaf
)) {

    $MissingProjectItems += "CODING_RULES.md"
}


if (-not (
    Test-Path `
        -LiteralPath $ToolsPath `
        -PathType Container
)) {

    $MissingProjectItems += "tools"
}


if (-not (
    Test-Path `
        -LiteralPath $ScriptsPath `
        -PathType Container
)) {

    $MissingProjectItems += "scripts"
}


if ($MissingProjectItems.Count -gt 0) {

    Write-SetupLog `
        "当前目录不是完整的 Even Codex Design 项目。" `
        "ERROR"


    Write-Host ""

    Write-Host "缺少以下项目内容：" -ForegroundColor Red


    foreach ($MissingItem in $MissingProjectItems) {

        Write-Host `
            "  - $MissingItem" `
            -ForegroundColor Red


        Write-SetupLog `
            "缺少项目内容：$MissingItem" `
            "ERROR"
    }


    Wait-BeforeExit

    exit 1
}


Write-SetupLog `
    "项目结构验证通过。" `
    "SUCCESS"


# =============================================
# 十五、检查环境说明文件
# =============================================


if (
    Test-Path `
        -LiteralPath $EnvironmentFile `
        -PathType Leaf
) {

    Write-SetupLog `
        "已找到环境说明：tools\docs\ENVIRONMENT.md" `
        "SUCCESS"
}
else {

    Write-SetupLog `
        "未找到 tools\docs\ENVIRONMENT.md。" `
        "WARNING"
}


# =============================================
# 十六、读取快捷方式配置
# =============================================


if (-not (
    Test-Path `
        -LiteralPath $ShortcutConfigFile `
        -PathType Leaf
)) {

    Write-SetupLog `
        "缺少快捷方式配置文件：tools\config\shortcut_config.json" `
        "ERROR"


    Wait-BeforeExit

    exit 1
}


try {

    $ShortcutConfigText = Get-Content `
        -LiteralPath $ShortcutConfigFile `
        -Raw `
        -Encoding UTF8


    $ShortcutConfig = $ShortcutConfigText |
        ConvertFrom-Json


    Write-SetupLog `
        "shortcut_config.json 读取成功。" `
        "SUCCESS"
}
catch {

    Write-SetupLog `
        "shortcut_config.json 解析失败：$($_.Exception.Message)" `
        "ERROR"


    Wait-BeforeExit

    exit 1
}


# =============================================
# 十七、验证快捷方式配置
# =============================================


$WorkspaceName = [string]$ShortcutConfig.workspace.name

$WorkspaceIcon = [string]$ShortcutConfig.workspace.icon


if ([string]::IsNullOrWhiteSpace($WorkspaceName)) {

    $WorkspaceName = "Even Codex Design"

    Write-SetupLog `
        "配置中未设置工作台名称，使用默认名称：$WorkspaceName" `
        "WARNING"
}


$ShortcutGroups = @($ShortcutConfig.groups)

$ShortcutItems = @($ShortcutConfig.shortcuts)


if ($ShortcutGroups.Count -eq 0) {

    Write-SetupLog `
        "shortcut_config.json 中没有 groups 配置。" `
        "ERROR"


    Wait-BeforeExit

    exit 1
}


if ($ShortcutItems.Count -eq 0) {

    Write-SetupLog `
        "shortcut_config.json 中没有 shortcuts 配置。" `
        "ERROR"


    Wait-BeforeExit

    exit 1
}


Write-SetupLog `
    "配置版本：$($ShortcutConfig.version)"


Write-SetupLog `
    "工作台名称：$WorkspaceName"


Write-SetupLog `
    "快捷方式配置数量：$($ShortcutItems.Count)"


# =============================================
# 十八、工作台路径
# =============================================


$WorkspacePath = Join-Path `
    $DesktopPath `
    $WorkspaceName


Write-SetupLog `
    "工作台路径：$WorkspacePath"


# =============================================
# 十九、创建工作台根目录
# =============================================


if (-not (
    Test-Path `
        -LiteralPath $WorkspacePath `
        -PathType Container
)) {

    New-Item `
        -ItemType Directory `
        -Path $WorkspacePath `
        -Force |
        Out-Null


    Write-SetupLog `
        "创建工作台目录：$WorkspacePath" `
        "SUCCESS"
}
else {

    Write-SetupLog `
        "工作台目录已经存在：$WorkspacePath"
}


# =============================================
# 二十、创建工作台分类目录
# =============================================


foreach ($GroupConfigItem in $ShortcutGroups) {

    $GroupName = [string]$GroupConfigItem.name


    if ([string]::IsNullOrWhiteSpace($GroupName)) {

        Write-SetupLog `
            "发现没有名称的工作台分类，已经跳过。" `
            "WARNING"

        continue
    }


    $GroupPath = Join-Path `
        $WorkspacePath `
        $GroupName


    if (-not (
        Test-Path `
            -LiteralPath $GroupPath `
            -PathType Container
    )) {

        New-Item `
            -ItemType Directory `
            -Path $GroupPath `
            -Force |
            Out-Null


        Write-SetupLog `
            "创建工作台分类：$GroupName" `
            "SUCCESS"
    }
    else {

        Write-SetupLog `
            "工作台分类已经存在：$GroupName"
    }
}


# =============================================
# 二十一、查找桌面应用
# =============================================


# ---------------------------------------------
# VS Code
# ---------------------------------------------


function Find-VSCode {

    $VSCodeCandidates = @()


    if ($env:LOCALAPPDATA) {

        $VSCodeCandidates += Join-Path `
            $env:LOCALAPPDATA `
            "Programs\Microsoft VS Code\Code.exe"
    }


    if ($env:ProgramFiles) {

        $VSCodeCandidates += Join-Path `
            $env:ProgramFiles `
            "Microsoft VS Code\Code.exe"
    }


    $ProgramFilesX86 = [Environment]::GetEnvironmentVariable(
        "ProgramFiles(x86)"
    )


    if ($ProgramFilesX86) {

        $VSCodeCandidates += Join-Path `
            $ProgramFilesX86 `
            "Microsoft VS Code\Code.exe"
    }


    foreach ($VSCodeCandidate in $VSCodeCandidates) {

        if (
            Test-Path `
                -LiteralPath $VSCodeCandidate `
                -PathType Leaf
        ) {

            return $VSCodeCandidate
        }
    }


    $VSCodeCommand = Get-Command `
        "code.exe" `
        -ErrorAction SilentlyContinue


    if ($VSCodeCommand -and $VSCodeCommand.Source) {

        return $VSCodeCommand.Source
    }


    return $null
}


$VSCodeExe = Find-VSCode


if ($VSCodeExe) {

    Write-SetupLog `
        "已找到 VS Code：$VSCodeExe" `
        "SUCCESS"
}
else {

    Write-SetupLog `
        "未找到 VS Code。相关快捷方式将被跳过或使用记事本。" `
        "WARNING"
}


# ---------------------------------------------
# Windows Terminal
# ---------------------------------------------


function Find-WindowsTerminal {

    $WindowsTerminalCommand = Get-Command `
        "wt.exe" `
        -ErrorAction SilentlyContinue


    if (
        $WindowsTerminalCommand -and
        $WindowsTerminalCommand.Source -and
        (
            Test-Path `
                -LiteralPath $WindowsTerminalCommand.Source `
                -PathType Leaf
        )
    ) {

        return $WindowsTerminalCommand.Source
    }


    if ($env:LOCALAPPDATA) {

        $WindowsTerminalAlias = Join-Path `
            $env:LOCALAPPDATA `
            "Microsoft\WindowsApps\wt.exe"


        if (
            Test-Path `
                -LiteralPath $WindowsTerminalAlias `
                -PathType Leaf
        ) {

            return $WindowsTerminalAlias
        }
    }


    return $null
}


$WindowsTerminalExe = Find-WindowsTerminal


if ($WindowsTerminalExe) {

    Write-SetupLog `
        "已找到 Windows Terminal：$WindowsTerminalExe" `
        "SUCCESS"
}
else {

    Write-SetupLog `
        "未找到 Windows Terminal；项目终端将使用 Windows PowerShell 直接打开。" `
        "WARNING"
}


# =============================================
# 二十二、Adobe Beta 环境检测
# =============================================


$AdobeRoot = Join-Path `
    $env:ProgramFiles `
    "Adobe"


# ---------------------------------------------
# Photoshop Beta
# ---------------------------------------------


$PhotoshopBetaRoot = Join-Path `
    $AdobeRoot `
    "Adobe Photoshop (Beta)"


$PhotoshopScriptCandidates = @(

    (Join-Path `
        $PhotoshopBetaRoot `
        "Presets\Scripts"),

    (Join-Path `
        $PhotoshopBetaRoot `
        "Presets\zh_CN\Scripts"),

    (Join-Path `
        $PhotoshopBetaRoot `
        "Presets\zh_CN\脚本")
)


$PhotoshopBetaScriptPath = $null


foreach ($PhotoshopCandidate in $PhotoshopScriptCandidates) {

    if (
        Test-Path `
            -LiteralPath $PhotoshopCandidate `
            -PathType Container
    ) {

        $PhotoshopBetaScriptPath = $PhotoshopCandidate

        break
    }
}


if ($PhotoshopBetaScriptPath) {

    Write-SetupLog `
        "Photoshop Beta脚本目录：$PhotoshopBetaScriptPath" `
        "SUCCESS"
}
elseif (
    Test-Path `
        -LiteralPath $PhotoshopBetaRoot `
        -PathType Container
) {

    $PhotoshopBetaScriptPath = $PhotoshopBetaRoot


    Write-SetupLog `
        "找到 Photoshop Beta，但未找到 Presets\Scripts；将打开安装目录。" `
        "WARNING"
}
elseif (
    Test-Path `
        -LiteralPath $AdobeRoot `
        -PathType Container
) {

    $PhotoshopBetaScriptPath = $AdobeRoot


    Write-SetupLog `
        "未找到 Photoshop Beta；将打开 Adobe 安装目录。" `
        "WARNING"
}
else {

    $PhotoshopBetaScriptPath = $env:ProgramFiles


    Write-SetupLog `
        "未找到 Adobe 安装目录；将打开 Program Files。" `
        "WARNING"
}


# ---------------------------------------------
# Illustrator Beta
# ---------------------------------------------


$IllustratorBetaRoot = Join-Path `
    $AdobeRoot `
    "Adobe Illustrator (Beta)"


$IllustratorScriptCandidates = @(

    (Join-Path `
        $IllustratorBetaRoot `
        "Presets\zh_CN\脚本"),

    (Join-Path `
        $IllustratorBetaRoot `
        "Presets\zh_CN\Scripts"),

    (Join-Path `
        $IllustratorBetaRoot `
        "Presets\en_US\Scripts"),

    (Join-Path `
        $IllustratorBetaRoot `
        "Presets\Scripts")
)


$IllustratorBetaScriptPath = $null


foreach ($IllustratorCandidate in $IllustratorScriptCandidates) {

    if (
        Test-Path `
            -LiteralPath $IllustratorCandidate `
            -PathType Container
    ) {

        $IllustratorBetaScriptPath = $IllustratorCandidate

        break
    }
}


if ($IllustratorBetaScriptPath) {

    Write-SetupLog `
        "Illustrator Beta脚本目录：$IllustratorBetaScriptPath" `
        "SUCCESS"
}
elseif (
    Test-Path `
        -LiteralPath $IllustratorBetaRoot `
        -PathType Container
) {

    $IllustratorBetaScriptPath = $IllustratorBetaRoot


    Write-SetupLog `
        "找到 Illustrator Beta，但未找到语言脚本目录；将打开安装目录。" `
        "WARNING"
}
elseif (
    Test-Path `
        -LiteralPath $AdobeRoot `
        -PathType Container
) {

    $IllustratorBetaScriptPath = $AdobeRoot


    Write-SetupLog `
        "未找到 Illustrator Beta；将打开 Adobe 安装目录。" `
        "WARNING"
}
else {

    $IllustratorBetaScriptPath = $env:ProgramFiles


    Write-SetupLog `
        "未找到 Adobe 安装目录；将打开 Program Files。" `
        "WARNING"
}


# =============================================
# 二十三、图标检测函数
# =============================================


function Get-IconLocation {

    param(
        [string]$IconFileName
    )


    if ([string]::IsNullOrWhiteSpace($IconFileName)) {

        return $null
    }


    $IconFile = Join-Path `
        $IconPath `
        $IconFileName


    if (
        Test-Path `
            -LiteralPath $IconFile `
            -PathType Leaf
    ) {

        return "$IconFile,0"
    }


    Write-SetupLog `
        "缺少图标：$IconFileName，将使用系统默认图标。" `
        "WARNING"


    return $null
}


if (
    Test-Path `
        -LiteralPath $IconPath `
        -PathType Container
) {

    Write-SetupLog `
        "图标目录检测通过：$IconPath" `
        "SUCCESS"
}
else {

    Write-SetupLog `
        "未找到 assets\icons\ico，快捷方式将使用系统默认图标。" `
        "WARNING"
}


# =============================================
# 二十四、设置工作台文件夹图标
# =============================================


function Set-EvenFolderIcon {

    param(

        [Parameter(Mandatory = $true)]
        [string]$FolderPath,

        [Parameter(Mandatory = $true)]
        [string]$IconFileName
    )


    try {

        if (-not (
            Test-Path `
                -LiteralPath $FolderPath `
                -PathType Container
        )) {

            throw "目标文件夹不存在：$FolderPath"
        }


        if ([string]::IsNullOrWhiteSpace($IconFileName)) {

            throw "文件夹图标名称为空：$FolderPath"
        }


        $FolderIconFile = Join-Path `
            $IconPath `
            $IconFileName


        if (-not (
            Test-Path `
                -LiteralPath $FolderIconFile `
                -PathType Leaf
        )) {

            throw "缺少文件夹图标：$IconFileName"
        }


        $DesktopIniFile = Join-Path `
            $FolderPath `
            "desktop.ini"


        if (
            Test-Path `
                -LiteralPath $DesktopIniFile `
                -PathType Leaf
        ) {

            $ExistingDesktopIniItem = Get-Item `
                -LiteralPath $DesktopIniFile `
                -Force


            $ExistingDesktopIniItem.Attributes = `
                $ExistingDesktopIniItem.Attributes -band `
                (-bnot [IO.FileAttributes]::ReadOnly)
        }


        $DesktopIniContent = @(
            "[.ShellClassInfo]",
            "IconResource=`"$FolderIconFile`",0",
            "ConfirmFileOp=0"
        )


        # desktop.ini 使用 UTF-16 LE，确保 Windows 资源管理器稳定读取路径。

        [IO.File]::WriteAllLines(
            $DesktopIniFile,
            $DesktopIniContent,
            [Text.Encoding]::Unicode
        )


        $DesktopIniItem = Get-Item `
            -LiteralPath $DesktopIniFile `
            -Force


        $DesktopIniItem.Attributes = `
            $DesktopIniItem.Attributes -bor `
            [IO.FileAttributes]::Hidden -bor `
            [IO.FileAttributes]::System


        $FolderItem = Get-Item `
            -LiteralPath $FolderPath `
            -Force


        # Windows 需要文件夹带有只读属性，才会应用 desktop.ini 自定义设置。

        $FolderItem.Attributes = `
            $FolderItem.Attributes -bor `
            [IO.FileAttributes]::ReadOnly


        $script:FolderIconSuccessCount++


        Write-SetupLog `
            "文件夹图标设置成功：$FolderPath -> $IconFileName" `
            "SUCCESS"
    }
    catch {

        $script:FolderIconFailureCount++


        Write-SetupLog `
            "文件夹图标设置失败：$FolderPath；原因：$($_.Exception.Message)" `
            "WARNING"
    }
}


Set-EvenFolderIcon `
    -FolderPath $WorkspacePath `
    -IconFileName $WorkspaceIcon


foreach ($GroupConfigItem in $ShortcutGroups) {

    $GroupName = [string]$GroupConfigItem.name

    $GroupIcon = [string]$GroupConfigItem.icon


    if ([string]::IsNullOrWhiteSpace($GroupName)) {

        continue
    }


    $GroupPath = Join-Path `
        $WorkspacePath `
        $GroupName


    Set-EvenFolderIcon `
        -FolderPath $GroupPath `
        -IconFileName $GroupIcon
}


$IconRefreshExe = Join-Path `
    $env:SystemRoot `
    "System32\ie4uinit.exe"


if (
    (-not $ValidationMode) -and
    (
        Test-Path `
            -LiteralPath $IconRefreshExe `
            -PathType Leaf
    )
) {

    try {

        Start-Process `
            -FilePath $IconRefreshExe `
            -ArgumentList "-show" `
            -WindowStyle Hidden `
            -Wait


        Write-SetupLog `
            "已请求 Windows 资源管理器刷新图标缓存。" `
            "SUCCESS"
    }
    catch {

        Write-SetupLog `
            "无法自动刷新图标缓存：$($_.Exception.Message)" `
            "WARNING"
    }
}


# =============================================
# 二十五、创建快捷方式函数
# =============================================


$WScriptShell = New-Object `
    -ComObject WScript.Shell


function New-EvenShortcut {

    param(

        [Parameter(Mandatory = $true)]
        [string]$ShortcutFolder,

        [Parameter(Mandatory = $true)]
        [string]$ShortcutName,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [string]$Arguments = "",

        [string]$WorkingDirectory = "",

        [string]$IconFileName = "",

        [string]$Description = ""
    )


    try {

        if ([string]::IsNullOrWhiteSpace($ShortcutName)) {

            throw "快捷方式名称为空。"
        }


        if ([string]::IsNullOrWhiteSpace($TargetPath)) {

            throw "快捷方式目标路径为空。"
        }


        if (-not (
            Test-Path `
                -LiteralPath $TargetPath `
                -PathType Leaf
        )) {

            throw "目标程序不存在：$TargetPath"
        }


        if (-not (
            Test-Path `
                -LiteralPath $ShortcutFolder `
                -PathType Container
        )) {

            New-Item `
                -ItemType Directory `
                -Path $ShortcutFolder `
                -Force |
                Out-Null
        }


        $ShortcutFile = Join-Path `
            $ShortcutFolder `
            "$ShortcutName.lnk"


        # 使用 $LinkObject，避免与 JSON 循环变量重名

        $LinkObject = $WScriptShell.CreateShortcut(
            $ShortcutFile
        )


        $LinkObject.TargetPath = $TargetPath


        if (-not [string]::IsNullOrWhiteSpace($Arguments)) {

            $LinkObject.Arguments = $Arguments
        }


        if (
            -not [string]::IsNullOrWhiteSpace(
                $WorkingDirectory
            ) -and
            (
                Test-Path `
                    -LiteralPath $WorkingDirectory `
                    -PathType Container
            )
        ) {

            $LinkObject.WorkingDirectory = $WorkingDirectory
        }
        else {

            $LinkObject.WorkingDirectory = $ProjectPath
        }


        if (-not [string]::IsNullOrWhiteSpace($Description)) {

            $LinkObject.Description = $Description
        }


        $IconLocation = Get-IconLocation `
            $IconFileName


        if ($IconLocation) {

            $LinkObject.IconLocation = $IconLocation
        }


        $LinkObject.WindowStyle = 1

        $LinkObject.Save()


        $script:ShortcutSuccessCount++


        Write-SetupLog `
            "快捷方式创建成功：$ShortcutName" `
            "SUCCESS"
    }
    catch {

        $script:ShortcutFailureCount++


        $ErrorMessage = $_.Exception.Message


        Write-SetupLog `
            "快捷方式创建失败：$ShortcutName；原因：$ErrorMessage" `
            "ERROR"
    }
}


# =============================================
# 二十六、创建 PowerShell 脚本快捷方式函数
# =============================================


function New-PowerShellScriptShortcut {

    param(

        [string]$ShortcutFolder,

        [string]$ShortcutName,

        [string]$ScriptFile,

        [string]$IconFileName,

        [string]$Description
    )


    if (-not (
        Test-Path `
            -LiteralPath $ScriptFile `
            -PathType Leaf
    )) {

        Write-SetupLog `
            "未找到脚本：$ScriptFile，跳过快捷方式：$ShortcutName" `
            "WARNING"

        return
    }


    $PowerShellArguments = `
        '-NoProfile -ExecutionPolicy Bypass -File "' +
        $ScriptFile +
        '"'


    New-EvenShortcut `
        -ShortcutFolder $ShortcutFolder `
        -ShortcutName $ShortcutName `
        -TargetPath $PowerShellExe `
        -Arguments $PowerShellArguments `
        -WorkingDirectory $ProjectPath `
        -IconFileName $IconFileName `
        -Description $Description
}


# =============================================
# 二十七、根据 JSON 配置创建快捷方式
# =============================================


$EscapedProjectPath = $ProjectPath.Replace(
    "'",
    "''"
)


foreach ($ShortcutConfigItem in $ShortcutItems) {

    $ShortcutName = [string]$ShortcutConfigItem.name

    $ShortcutGroup = [string]$ShortcutConfigItem.group

    $ShortcutType = [string]$ShortcutConfigItem.type

    $ShortcutIcon = [string]$ShortcutConfigItem.icon

    $ShortcutDescription = [string]$ShortcutConfigItem.description


    Write-SetupLog `
        "处理快捷方式：$ShortcutName"


    if ([string]::IsNullOrWhiteSpace($ShortcutName)) {

        Write-SetupLog `
            "发现没有名称的快捷方式配置，已经跳过。" `
            "WARNING"

        continue
    }


    if ([string]::IsNullOrWhiteSpace($ShortcutGroup)) {

        Write-SetupLog `
            "快捷方式缺少 group：$ShortcutName" `
            "WARNING"

        continue
    }


    if ([string]::IsNullOrWhiteSpace($ShortcutType)) {

        Write-SetupLog `
            "快捷方式缺少 type：$ShortcutName" `
            "WARNING"

        continue
    }


    $ShortcutFolder = Join-Path `
        $WorkspacePath `
        $ShortcutGroup


    if (-not (
        Test-Path `
            -LiteralPath $ShortcutFolder `
            -PathType Container
    )) {

        New-Item `
            -ItemType Directory `
            -Path $ShortcutFolder `
            -Force |
            Out-Null


        Write-SetupLog `
            "配置中的分类不存在，已经自动创建：$ShortcutGroup" `
            "WARNING"
    }


    switch ($ShortcutType.ToLower()) {

        "vscode" {

            if (-not $VSCodeExe) {

                Write-SetupLog `
                    "未找到 VS Code，跳过快捷方式：$ShortcutName" `
                    "WARNING"

                break
            }


            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $VSCodeExe `
                -Arguments (Quote-Argument $ProjectPath) `
                -WorkingDirectory $ProjectPath `
                -IconFileName $ShortcutIcon `
                -Description "使用 VS Code 打开 Even Codex Design 项目"


            break
        }


        "git_status" {

            New-PowerShellScriptShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -ScriptFile $GitStatusScript `
                -IconFileName $ShortcutIcon `
                -Description "查看 Even Codex Design Git 状态"


            break
        }


        "git_sync" {

            New-PowerShellScriptShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -ScriptFile $GitSyncScript `
                -IconFileName $ShortcutIcon `
                -Description "安全同步 Even Codex Design 的 origin/main"


            break
        }


        "git_publish" {

            New-PowerShellScriptShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -ScriptFile $GitPublishScript `
                -IconFileName $ShortcutIcon `
                -Description "提交并同步 Even Codex Design 到 GitHub"


            break
        }


        "terminal" {

            if ($WindowsTerminalExe) {

                $TerminalTarget = $WindowsTerminalExe

                $TerminalArguments = `
                    'new-tab -d ' +
                    (Quote-Argument $ProjectPath) +
                    ' ' +
                    (Quote-Argument $PowerShellExe) +
                    ' -NoExit -NoProfile'

                $TerminalDescription = `
                    "使用 Windows Terminal 和 Windows PowerShell 打开 Even Codex Design 项目终端"
            }
            else {

                $TerminalTarget = $PowerShellExe

                $TerminalArguments = `
                    '-NoExit -NoProfile -Command ' +
                    '"Set-Location -LiteralPath ''' +
                    $EscapedProjectPath +
                    '''"'

                $TerminalDescription = `
                    "在 Even Codex Design 项目目录打开 Windows PowerShell"
            }


            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $TerminalTarget `
                -Arguments $TerminalArguments `
                -WorkingDirectory $ProjectPath `
                -IconFileName $ShortcutIcon `
                -Description $TerminalDescription


            break
        }


        "environment_check" {

            New-PowerShellScriptShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -ScriptFile $EnvironmentCheckScript `
                -IconFileName $ShortcutIcon `
                -Description "检查 Even Codex Design 本机开发与 Adobe 环境"


            break
        }


        "folder" {

            $RelativeTarget = [string]$ShortcutConfigItem.target


            if ([string]::IsNullOrWhiteSpace($RelativeTarget)) {

                Write-SetupLog `
                    "folder 类型缺少 target：$ShortcutName" `
                    "WARNING"

                break
            }


            $RelativeTarget = $RelativeTarget.Replace(
                "/",
                "\"
            )


            $FolderTarget = Join-Path `
                $ProjectPath `
                $RelativeTarget


            if (-not (
                Test-Path `
                    -LiteralPath $FolderTarget `
                    -PathType Container
            )) {

                Write-SetupLog `
                    "目标文件夹不存在：$FolderTarget；快捷方式仍将创建。" `
                    "WARNING"
            }


            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $ExplorerExe `
                -Arguments (Quote-Argument $FolderTarget) `
                -WorkingDirectory $ProjectPath `
                -IconFileName $ShortcutIcon `
                -Description "打开 Even Codex Design 项目目录"


            break
        }


        "repository" {

            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $ExplorerExe `
                -Arguments (Quote-Argument $ProjectPath) `
                -WorkingDirectory $ProjectPath `
                -IconFileName $ShortcutIcon `
                -Description "在资源管理器中打开当前 Codex Design 仓库"


            break
        }


        "photoshop_beta" {

            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $ExplorerExe `
                -Arguments (
                    Quote-Argument $PhotoshopBetaScriptPath
                ) `
                -WorkingDirectory $PhotoshopBetaScriptPath `
                -IconFileName $ShortcutIcon `
                -Description "打开 Photoshop Beta 安装脚本目录"


            break
        }


        "illustrator_beta" {

            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $ExplorerExe `
                -Arguments (
                    Quote-Argument $IllustratorBetaScriptPath
                ) `
                -WorkingDirectory $IllustratorBetaScriptPath `
                -IconFileName $ShortcutIcon `
                -Description "打开 Illustrator Beta 安装脚本目录"


            break
        }


        "docs" {

            if (-not (
                Test-Path `
                    -LiteralPath $ToolsDocsPath `
                    -PathType Container
            )) {

                New-Item `
                    -ItemType Directory `
                    -Path $ToolsDocsPath `
                    -Force |
                    Out-Null
            }


            New-EvenShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -TargetPath $ExplorerExe `
                -Arguments (Quote-Argument $ToolsDocsPath) `
                -WorkingDirectory $ToolsDocsPath `
                -IconFileName $ShortcutIcon `
                -Description "打开 Even Codex Design 项目文档"


            break
        }


        "rules" {

            if ($VSCodeExe) {

                New-EvenShortcut `
                    -ShortcutFolder $ShortcutFolder `
                    -ShortcutName $ShortcutName `
                    -TargetPath $VSCodeExe `
                    -Arguments (Quote-Argument $AgentsFile) `
                    -WorkingDirectory $ProjectPath `
                    -IconFileName $ShortcutIcon `
                    -Description "使用 VS Code 打开 AGENTS.md"
            }
            else {

                New-EvenShortcut `
                    -ShortcutFolder $ShortcutFolder `
                    -ShortcutName $ShortcutName `
                    -TargetPath $NotepadExe `
                    -Arguments (Quote-Argument $AgentsFile) `
                    -WorkingDirectory $ProjectPath `
                    -IconFileName $ShortcutIcon `
                    -Description "打开 AGENTS.md"
            }


            break
        }


        "backup" {

            New-PowerShellScriptShortcut `
                -ShortcutFolder $ShortcutFolder `
                -ShortcutName $ShortcutName `
                -ScriptFile $BackupScript `
                -IconFileName $ShortcutIcon `
                -Description "备份 Even Codex Design 项目"


            break
        }


        default {

            Write-SetupLog `
                "未知快捷方式类型：$ShortcutType；快捷方式：$ShortcutName" `
                "WARNING"
        }
    }
}


# =============================================
# 二十八、完成统计
# =============================================


Write-Host ""

Write-Host "============================================="

Write-Host " Even Codex Design 工作台创建完成"

Write-Host "============================================="

Write-Host ""


Write-Host "工作台位置："

Write-Host $WorkspacePath

Write-Host ""


Write-Host "成功创建：$ShortcutSuccessCount 个"

Write-Host "创建失败：$ShortcutFailureCount 个"

Write-Host "警告数量：$WarningCount 个"

Write-Host "文件夹图标成功：$FolderIconSuccessCount 个"

Write-Host "文件夹图标失败：$FolderIconFailureCount 个"

Write-Host ""


Write-Host "日志文件："

Write-Host $LogFile

Write-Host ""


Write-SetupLog `
    "快捷方式成功数量：$ShortcutSuccessCount"


Write-SetupLog `
    "快捷方式失败数量：$ShortcutFailureCount"


Write-SetupLog `
    "警告数量：$WarningCount"


Write-SetupLog `
    "文件夹图标成功数量：$FolderIconSuccessCount"


Write-SetupLog `
    "文件夹图标失败数量：$FolderIconFailureCount"


if (
    ($ShortcutFailureCount -eq 0) -and
    ($FolderIconFailureCount -eq 0)
) {

    Write-SetupLog `
        "桌面工作台生成完成。" `
        "SUCCESS"
}
else {

    Write-SetupLog `
        "桌面工作台生成结束，但存在创建失败的快捷方式。" `
        "WARNING"
}


# =============================================
# 二十九、打开生成后的工作台
# =============================================


if (-not $ValidationMode) {

try {

    Start-Process `
        -FilePath $ExplorerExe `
        -ArgumentList (
            Quote-Argument $WorkspacePath
        )
}
catch {

    Write-SetupLog `
        "无法自动打开桌面工作台：$($_.Exception.Message)" `
        "WARNING"
}

}


# =============================================
# 三十、结束
# =============================================


Wait-BeforeExit
