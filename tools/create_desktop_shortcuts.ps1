# =============================================
# Even Codex Design 桌面工作台生成器
# Version: 2.0
#
# 功能：
# 1. 自动识别当前 Git 项目路径
# 2. 创建 Even Codex Design 桌面工作台
# 3. 分类创建 11 个快捷方式
# 4. 自动调用仓库中的 ICO 图标
# 5. 自动检测 Photoshop Beta 和 Illustrator Beta
# 6. 生成快捷方式安装日志
#
# 兼容：
# Windows 10
# Windows PowerShell 5.1
# =============================================


$ErrorActionPreference = "Stop"

$ToolVersion = "2.0"


# =============================================
# 一、获取基础路径
# =============================================


# tools 文件夹的上一级为项目根目录
$ProjectPath = Join-Path $PSScriptRoot ".."

$ProjectPath = (Resolve-Path $ProjectPath).Path


# Windows 桌面路径
$DesktopPath = [Environment]::GetFolderPath("Desktop")


# 桌面工作台根目录
$WorkspacePath = Join-Path $DesktopPath "Even Codex Design"


# 工作台分类目录
$DevelopmentFolder = Join-Path $WorkspacePath "01_开发工具"

$AdobeFolder = Join-Path $WorkspacePath "02_Adobe脚本"

$ManagementFolder = Join-Path $WorkspacePath "03_项目管理"


# 项目资源目录
$IconDirectory = Join-Path $ProjectPath "assets\icons\ico"

$LogsDirectory = Join-Path $ProjectPath "logs"

$ToolsDirectory = Join-Path $ProjectPath "tools"

$ToolsDocsDirectory = Join-Path $ProjectPath "tools\docs"


# 项目文件
$AgentsFile = Join-Path $ProjectPath "AGENTS.md"

$CodingRulesFile = Join-Path $ProjectPath "CODING_RULES.md"

$EnvironmentFile = Join-Path $ToolsDocsDirectory "ENVIRONMENT.md"


# 工具脚本
$GitStatusScript = Join-Path $ToolsDirectory "git_status.ps1"

$GitPublishScript = Join-Path $ToolsDirectory "git_publish.ps1"

$BackupScript = Join-Path $ToolsDirectory "backup_project.ps1"


# 项目脚本目录
$PhotoshopJsxDirectory = Join-Path $ProjectPath "scripts\photoshop\jsx"

$IllustratorJsxDirectory = Join-Path $ProjectPath "scripts\illustrator\jsx"


# Windows 程序
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

$ExplorerExe = Join-Path $env:SystemRoot "explorer.exe"

$NotepadExe = Join-Path $env:SystemRoot "System32\notepad.exe"


# =============================================
# 二、创建日志目录
# =============================================


if (-not (Test-Path -LiteralPath $LogsDirectory -PathType Container)) {

    New-Item `
        -ItemType Directory `
        -Path $LogsDirectory `
        -Force | Out-Null
}


$LogFile = Join-Path $LogsDirectory "shortcut_install.log"


# 记录每次运行的分隔信息
Add-Content `
    -LiteralPath $LogFile `
    -Encoding UTF8 `
    -Value ""


Add-Content `
    -LiteralPath $LogFile `
    -Encoding UTF8 `
    -Value "=================================================="


Add-Content `
    -LiteralPath $LogFile `
    -Encoding UTF8 `
    -Value "Even Codex Design Desktop Setup V$ToolVersion"


Add-Content `
    -LiteralPath $LogFile `
    -Encoding UTF8 `
    -Value "运行时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"


# =============================================
# 三、运行状态统计
# =============================================


$script:ShortcutSuccessCount = 0

$script:ShortcutFailureCount = 0

$script:WarningCount = 0


# =============================================
# 四、日志输出函数
# =============================================


function Write-SetupLog {

    param(
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )


    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $LogLine = "[$Time] [$Level] $Message"


    switch ($Level) {

        "SUCCESS" {

            Write-Host $Message -ForegroundColor Green
        }

        "WARNING" {

            Write-Host $Message -ForegroundColor Yellow

            $script:WarningCount++
        }

        "ERROR" {

            Write-Host $Message -ForegroundColor Red
        }

        default {

            Write-Host $Message
        }
    }


    Add-Content `
        -LiteralPath $LogFile `
        -Encoding UTF8 `
        -Value $LogLine
}


# =============================================
# 五、退出前暂停函数
# =============================================


function Wait-BeforeExit {

    Write-Host ""

    [void](Read-Host "按 Enter 键关闭窗口")
}


# =============================================
# 六、项目环境验证
# =============================================


Write-Host ""
Write-Host "============================================="
Write-Host " Even Codex Design Desktop Setup V$ToolVersion"
Write-Host "============================================="
Write-Host ""


Write-SetupLog "项目目录：$ProjectPath"

Write-SetupLog "桌面目录：$DesktopPath"

Write-SetupLog "工作台目录：$WorkspacePath"


$MissingProjectItems = @()


if (-not (Test-Path -LiteralPath $AgentsFile -PathType Leaf)) {

    $MissingProjectItems += "AGENTS.md"
}


if (-not (Test-Path -LiteralPath $CodingRulesFile -PathType Leaf)) {

    $MissingProjectItems += "CODING_RULES.md"
}


if (-not (Test-Path -LiteralPath $ToolsDirectory -PathType Container)) {

    $MissingProjectItems += "tools"
}


if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath "scripts") -PathType Container)) {

    $MissingProjectItems += "scripts"
}


if ($MissingProjectItems.Count -gt 0) {

    Write-SetupLog "当前目录不是完整的 Even Codex Design 项目。" "ERROR"

    Write-Host ""
    Write-Host "缺少以下项目内容：" -ForegroundColor Red


    foreach ($Item in $MissingProjectItems) {

        Write-Host "  - $Item" -ForegroundColor Red

        Add-Content `
            -LiteralPath $LogFile `
            -Encoding UTF8 `
            -Value "缺少项目内容：$Item"
    }


    Wait-BeforeExit

    exit 1
}


Write-SetupLog "项目结构验证通过。" "SUCCESS"


# 检查环境说明文件
if (Test-Path -LiteralPath $EnvironmentFile -PathType Leaf) {

    Write-SetupLog "已找到环境说明：tools\docs\ENVIRONMENT.md" "SUCCESS"
}
else {

    Write-SetupLog "未找到 tools\docs\ENVIRONMENT.md，文档快捷方式仍会打开 tools\docs。" "WARNING"
}


# =============================================
# 七、创建工作台分类目录
# =============================================


$WorkspaceFolders = @(

    $WorkspacePath,

    $DevelopmentFolder,

    $AdobeFolder,

    $ManagementFolder
)


foreach ($Folder in $WorkspaceFolders) {

    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {

        New-Item `
            -ItemType Directory `
            -Path $Folder `
            -Force | Out-Null

        Write-SetupLog "创建目录：$Folder" "SUCCESS"
    }
    else {

        Write-SetupLog "目录已经存在：$Folder"
    }
}


# =============================================
# 八、查找 VS Code
# =============================================


function Find-VSCode {

    $Candidates = @()


    if ($env:LOCALAPPDATA) {

        $Candidates += Join-Path `
            $env:LOCALAPPDATA `
            "Programs\Microsoft VS Code\Code.exe"
    }


    if ($env:ProgramFiles) {

        $Candidates += Join-Path `
            $env:ProgramFiles `
            "Microsoft VS Code\Code.exe"
    }


    $ProgramFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")


    if ($ProgramFilesX86) {

        $Candidates += Join-Path `
            $ProgramFilesX86 `
            "Microsoft VS Code\Code.exe"
    }


    foreach ($Candidate in $Candidates) {

        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {

            return $Candidate
        }
    }


    return $null
}


$VSCodeExe = Find-VSCode


if ($VSCodeExe) {

    Write-SetupLog "已找到 VS Code：$VSCodeExe" "SUCCESS"
}
else {

    Write-SetupLog "未找到 VS Code，VS Code快捷方式将无法创建。" "WARNING"
}


# =============================================
# 九、图标检测函数
# =============================================


function Get-ShortcutIcon {

    param(
        [string]$IconFileName
    )


    $IconFile = Join-Path $IconDirectory $IconFileName


    if (Test-Path -LiteralPath $IconFile -PathType Leaf) {

        return "$IconFile,0"
    }


    Write-SetupLog "缺少图标：$IconFileName，将使用系统默认图标。" "WARNING"

    return $null
}


if (Test-Path -LiteralPath $IconDirectory -PathType Container) {

    Write-SetupLog "图标目录检测通过：$IconDirectory" "SUCCESS"
}
else {

    Write-SetupLog "未找到图标目录：assets\icons\ico，所有快捷方式将使用默认图标。" "WARNING"
}


# =============================================
# 十、检测 Adobe Beta 路径
# =============================================


$AdobeRoot = Join-Path $env:ProgramFiles "Adobe"


# Photoshop Beta
$PhotoshopBetaRoot = Join-Path `
    $AdobeRoot `
    "Adobe Photoshop (Beta)"


$PhotoshopScriptCandidates = @(

    (Join-Path $PhotoshopBetaRoot "Presets\Scripts"),

    (Join-Path $PhotoshopBetaRoot "Presets\zh_CN\Scripts"),

    (Join-Path $PhotoshopBetaRoot "Presets\zh_CN\脚本")
)


$PhotoshopBetaScriptPath = $null


foreach ($Candidate in $PhotoshopScriptCandidates) {

    if (Test-Path -LiteralPath $Candidate -PathType Container) {

        $PhotoshopBetaScriptPath = $Candidate

        break
    }
}


if ($PhotoshopBetaScriptPath) {

    Write-SetupLog "已找到 Photoshop Beta 脚本目录：$PhotoshopBetaScriptPath" "SUCCESS"
}
elseif (Test-Path -LiteralPath $PhotoshopBetaRoot -PathType Container) {

    $PhotoshopBetaScriptPath = $PhotoshopBetaRoot

    Write-SetupLog "已找到 Photoshop Beta，但未找到 Presets\Scripts；快捷方式将打开 Photoshop Beta 安装目录。" "WARNING"
}
elseif (Test-Path -LiteralPath $AdobeRoot -PathType Container) {

    $PhotoshopBetaScriptPath = $AdobeRoot

    Write-SetupLog "未找到 Photoshop Beta；快捷方式将打开 Adobe 安装目录。" "WARNING"
}
else {

    $PhotoshopBetaScriptPath = $env:ProgramFiles

    Write-SetupLog "未找到 Adobe 安装目录；Photoshop快捷方式将打开 Program Files。" "WARNING"
}


# Illustrator Beta
$IllustratorBetaRoot = Join-Path `
    $AdobeRoot `
    "Adobe Illustrator (Beta)"


$IllustratorScriptCandidates = @(

    (Join-Path $IllustratorBetaRoot "Presets\zh_CN\脚本"),

    (Join-Path $IllustratorBetaRoot "Presets\zh_CN\Scripts"),

    (Join-Path $IllustratorBetaRoot "Presets\en_US\Scripts"),

    (Join-Path $IllustratorBetaRoot "Presets\Scripts")
)


$IllustratorBetaScriptPath = $null


foreach ($Candidate in $IllustratorScriptCandidates) {

    if (Test-Path -LiteralPath $Candidate -PathType Container) {

        $IllustratorBetaScriptPath = $Candidate

        break
    }
}


if ($IllustratorBetaScriptPath) {

    Write-SetupLog "已找到 Illustrator Beta 脚本目录：$IllustratorBetaScriptPath" "SUCCESS"
}
elseif (Test-Path -LiteralPath $IllustratorBetaRoot -PathType Container) {

    $IllustratorBetaScriptPath = $IllustratorBetaRoot

    Write-SetupLog "已找到 Illustrator Beta，但未找到语言脚本目录；快捷方式将打开 Illustrator Beta 安装目录。" "WARNING"
}
elseif (Test-Path -LiteralPath $AdobeRoot -PathType Container) {

    $IllustratorBetaScriptPath = $AdobeRoot

    Write-SetupLog "未找到 Illustrator Beta；快捷方式将打开 Adobe 安装目录。" "WARNING"
}
else {

    $IllustratorBetaScriptPath = $env:ProgramFiles

    Write-SetupLog "未找到 Adobe 安装目录；Illustrator快捷方式将打开 Program Files。" "WARNING"
}


# =============================================
# 十一、创建快捷方式函数
# =============================================


$WScriptShell = New-Object -ComObject WScript.Shell


function New-EvenShortcut {

    param(
        [string]$ShortcutFolder,

        [string]$ShortcutName,

        [string]$TargetPath,

        [string]$Arguments = "",

        [string]$WorkingDirectory = "",

        [string]$IconFileName = "",

        [string]$Description = ""
    )


    try {

        if (-not (Test-Path -LiteralPath $ShortcutFolder -PathType Container)) {

            New-Item `
                -ItemType Directory `
                -Path $ShortcutFolder `
                -Force | Out-Null
        }


        $ShortcutFile = Join-Path `
            $ShortcutFolder `
            "$ShortcutName.lnk"


        $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)


        $Shortcut.TargetPath = $TargetPath


        if ($Arguments) {

            $Shortcut.Arguments = $Arguments
        }


        if ($WorkingDirectory) {

            $Shortcut.WorkingDirectory = $WorkingDirectory
        }
        else {

            $Shortcut.WorkingDirectory = $ProjectPath
        }


        if ($Description) {

            $Shortcut.Description = $Description
        }


        if ($IconFileName) {

            $IconLocation = Get-ShortcutIcon $IconFileName


            if ($IconLocation) {

                $Shortcut.IconLocation = $IconLocation
            }
        }


        $Shortcut.WindowStyle = 1

        $Shortcut.Save()


        $script:ShortcutSuccessCount++


        Write-SetupLog "快捷方式创建成功：$ShortcutName" "SUCCESS"
    }
    catch {

        $script:ShortcutFailureCount++


        Write-SetupLog `
            "快捷方式创建失败：$ShortcutName；原因：$($_.Exception.Message)" `
            "ERROR"
    }
}


# =============================================
# 十二、准备快捷方式参数
# =============================================


$QuotedProjectPath = '"' + $ProjectPath + '"'

$QuotedPhotoshopJsx = '"' + $PhotoshopJsxDirectory + '"'

$QuotedIllustratorJsx = '"' + $IllustratorJsxDirectory + '"'

$QuotedPhotoshopBetaScripts = '"' + $PhotoshopBetaScriptPath + '"'

$QuotedIllustratorBetaScripts = '"' + $IllustratorBetaScriptPath + '"'

$QuotedToolsDocs = '"' + $ToolsDocsDirectory + '"'

$QuotedAgentsFile = '"' + $AgentsFile + '"'


$GitStatusArguments = `
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $GitStatusScript +
    '"'


$GitPublishArguments = `
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $GitPublishScript +
    '"'


$BackupArguments = `
    '-NoProfile -ExecutionPolicy Bypass -File "' +
    $BackupScript +
    '"'


$EscapedProjectPath = $ProjectPath.Replace("'", "''")


$TerminalArguments = `
    '-NoExit -NoProfile -Command "Set-Location -LiteralPath ''' +
    $EscapedProjectPath +
    '''"'


# =============================================
# 十三、创建 01_开发工具
# =============================================


if ($VSCodeExe) {

    New-EvenShortcut `
        -ShortcutFolder $DevelopmentFolder `
        -ShortcutName "Codex Design VS Code" `
        -TargetPath $VSCodeExe `
        -Arguments $QuotedProjectPath `
        -WorkingDirectory $ProjectPath `
        -IconFileName "codex_workspace.ico" `
        -Description "使用 VS Code 打开 Even Codex Design 项目"
}


if (Test-Path -LiteralPath $GitStatusScript -PathType Leaf) {

    New-EvenShortcut `
        -ShortcutFolder $DevelopmentFolder `
        -ShortcutName "Codex Design 状态检查" `
        -TargetPath $PowerShellExe `
        -Arguments $GitStatusArguments `
        -WorkingDirectory $ProjectPath `
        -IconFileName "git_status.ico" `
        -Description "查看 Even Codex Design Git 状态"
}
else {

    Write-SetupLog "未找到 tools\git_status.ps1，跳过状态检查快捷方式。" "WARNING"
}


if (Test-Path -LiteralPath $GitPublishScript -PathType Leaf) {

    New-EvenShortcut `
        -ShortcutFolder $DevelopmentFolder `
        -ShortcutName "Codex Design 发布GitHub" `
        -TargetPath $PowerShellExe `
        -Arguments $GitPublishArguments `
        -WorkingDirectory $ProjectPath `
        -IconFileName "git_publish.ico" `
        -Description "提交并同步 Even Codex Design 到 GitHub"
}
else {

    Write-SetupLog "未找到 tools\git_publish.ps1，跳过 GitHub 发布快捷方式。" "WARNING"
}


New-EvenShortcut `
    -ShortcutFolder $DevelopmentFolder `
    -ShortcutName "Codex Design 终端" `
    -TargetPath $PowerShellExe `
    -Arguments $TerminalArguments `
    -WorkingDirectory $ProjectPath `
    -IconFileName "codex_terminal.ico" `
    -Description "在 Even Codex Design 项目目录打开 PowerShell"


# =============================================
# 十四、创建 02_Adobe脚本
# =============================================


New-EvenShortcut `
    -ShortcutFolder $AdobeFolder `
    -ShortcutName "Photoshop JSX脚本" `
    -TargetPath $ExplorerExe `
    -Arguments $QuotedPhotoshopJsx `
    -WorkingDirectory $PhotoshopJsxDirectory `
    -IconFileName "photoshop_jsx.ico" `
    -Description "打开仓库中的 Photoshop JSX 正式脚本目录"


New-EvenShortcut `
    -ShortcutFolder $AdobeFolder `
    -ShortcutName "Illustrator JSX脚本" `
    -TargetPath $ExplorerExe `
    -Arguments $QuotedIllustratorJsx `
    -WorkingDirectory $IllustratorJsxDirectory `
    -IconFileName "illustrator_jsx.ico" `
    -Description "打开仓库中的 Illustrator JSX 正式脚本目录"


New-EvenShortcut `
    -ShortcutFolder $AdobeFolder `
    -ShortcutName "Photoshop Beta安装脚本目录" `
    -TargetPath $ExplorerExe `
    -Arguments $QuotedPhotoshopBetaScripts `
    -WorkingDirectory $PhotoshopBetaScriptPath `
    -IconFileName "photoshop_beta_scripts.ico" `
    -Description "打开 Photoshop Beta 安装脚本目录"


New-EvenShortcut `
    -ShortcutFolder $AdobeFolder `
    -ShortcutName "Illustrator Beta安装脚本目录" `
    -TargetPath $ExplorerExe `
    -Arguments $QuotedIllustratorBetaScripts `
    -WorkingDirectory $IllustratorBetaScriptPath `
    -IconFileName "illustrator_beta_scripts.ico" `
    -Description "打开 Illustrator Beta 安装脚本目录"


# =============================================
# 十五、创建 03_项目管理
# =============================================


New-EvenShortcut `
    -ShortcutFolder $ManagementFolder `
    -ShortcutName "Codex Design 文档" `
    -TargetPath $ExplorerExe `
    -Arguments $QuotedToolsDocs `
    -WorkingDirectory $ToolsDocsDirectory `
    -IconFileName "codex_docs.ico" `
    -Description "打开 Even Codex Design 工具和环境文档目录"


if ($VSCodeExe) {

    New-EvenShortcut `
        -ShortcutFolder $ManagementFolder `
        -ShortcutName "Codex Design 规则" `
        -TargetPath $VSCodeExe `
        -Arguments $QuotedAgentsFile `
        -WorkingDirectory $ProjectPath `
        -IconFileName "codex_rules.ico" `
        -Description "使用 VS Code 打开 AGENTS.md"
}
else {

    New-EvenShortcut `
        -ShortcutFolder $ManagementFolder `
        -ShortcutName "Codex Design 规则" `
        -TargetPath $NotepadExe `
        -Arguments $QuotedAgentsFile `
        -WorkingDirectory $ProjectPath `
        -IconFileName "codex_rules.ico" `
        -Description "打开 AGENTS.md"
}


if (Test-Path -LiteralPath $BackupScript -PathType Leaf) {

    New-EvenShortcut `
        -ShortcutFolder $ManagementFolder `
        -ShortcutName "Codex Design 项目备份" `
        -TargetPath $PowerShellExe `
        -Arguments $BackupArguments `
        -WorkingDirectory $ProjectPath `
        -IconFileName "project_backup.ico" `
        -Description "备份 Even Codex Design 项目"
}
else {

    Write-SetupLog "未找到 tools\backup_project.ps1，跳过项目备份快捷方式。" "WARNING"
}


# =============================================
# 十六、完成信息
# =============================================


Write-Host ""
Write-Host "============================================="
Write-Host " 桌面工作台创建完成"
Write-Host "============================================="
Write-Host ""


Write-Host "工作台位置："
Write-Host $WorkspacePath
Write-Host ""


Write-Host "成功创建：$ShortcutSuccessCount 个快捷方式"

Write-Host "创建失败：$ShortcutFailureCount 个快捷方式"

Write-Host "警告数量：$WarningCount"

Write-Host ""


Write-Host "日志文件："
Write-Host $LogFile
Write-Host ""


Write-SetupLog "快捷方式成功数量：$ShortcutSuccessCount"

Write-SetupLog "快捷方式失败数量：$ShortcutFailureCount"

Write-SetupLog "警告数量：$WarningCount"

Write-SetupLog "桌面工作台生成完成。" "SUCCESS"


# 打开生成后的桌面工作台
try {

    Start-Process `
        -FilePath $ExplorerExe `
        -ArgumentList ('"' + $WorkspacePath + '"')
}
catch {

    Write-SetupLog "无法自动打开桌面工作台：$($_.Exception.Message)" "WARNING"
}


Wait-BeforeExit