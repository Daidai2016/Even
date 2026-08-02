# =============================================
# Codex Design Desktop Shortcut Creator
# 创建 Codex Design 桌面工作台快捷方式
# =============================================


Write-Host ""
Write-Host "================================="
Write-Host " Codex Design Desktop Setup"
Write-Host "================================="
Write-Host ""


# ---------------------------------
# 获取项目根目录
# ---------------------------------

$ProjectPath = Join-Path $PSScriptRoot ".."

$ProjectPath = (Resolve-Path $ProjectPath).Path


# ---------------------------------
# 桌面路径
# ---------------------------------

$DesktopPath = [Environment]::GetFolderPath("Desktop")


# ---------------------------------
# 图标目录
# ---------------------------------

$IconPath = Join-Path $ProjectPath "assets\icons\ico"



Write-Host "项目目录："
Write-Host $ProjectPath

Write-Host ""

Write-Host "图标目录："
Write-Host $IconPath

Write-Host ""



# ---------------------------------
# 创建快捷方式函数
# ---------------------------------

function Create-Shortcut {

    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$IconFile
    )


    $ShortcutPath = Join-Path $DesktopPath "$Name.lnk"


    $WScriptShell = New-Object -ComObject WScript.Shell


    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)


    $Shortcut.TargetPath = $TargetPath


    if ($Arguments) {

        $Shortcut.Arguments = $Arguments

    }


    if ($IconFile -and (Test-Path $IconFile)) {

        $Shortcut.IconLocation = $IconFile

    }


    $Shortcut.WorkingDirectory = $ProjectPath


    $Shortcut.Save()


    Write-Host "创建完成：$Name"

}



# ---------------------------------
# 1. VS Code项目
# ---------------------------------

Create-Shortcut `
"Codex Design VS Code" `
"code.exe" `
"`"$ProjectPath`"" `
(Join-Path $IconPath "codex_workspace.ico")



# ---------------------------------
# 2. Git状态检查
# ---------------------------------

Create-Shortcut `
"Codex Design 状态检查" `
"powershell.exe" `
"-ExecutionPolicy Bypass -File `"$ProjectPath\tools\git_status.ps1`"" `
(Join-Path $IconPath "git_status.ico")



# ---------------------------------
# 3. Git发布
# ---------------------------------

Create-Shortcut `
"Codex Design 发布GitHub" `
"powershell.exe" `
"-ExecutionPolicy Bypass -File `"$ProjectPath\tools\git_publish.ps1`"" `
(Join-Path $IconPath "git_publish.ico")



# ---------------------------------
# 4. Codex终端
# ---------------------------------

Create-Shortcut `
"Codex Design 终端" `
"powershell.exe" `
"-NoExit -Command `"cd '$ProjectPath'`"" `
(Join-Path $IconPath "codex_terminal.ico")



# ---------------------------------
# 5. Photoshop JSX目录
# ---------------------------------

Create-Shortcut `
"Photoshop JSX脚本" `
"explorer.exe" `
"`"$ProjectPath\scripts\photoshop\jsx`"" `
(Join-Path $IconPath "photoshop_jsx.ico")



# ---------------------------------
# 6. Illustrator JSX目录
# ---------------------------------

Create-Shortcut `
"Illustrator JSX脚本" `
"explorer.exe" `
"`"$ProjectPath\scripts\illustrator\jsx`"" `
(Join-Path $IconPath "illustrator_jsx.ico")



# ---------------------------------
# 7. Photoshop安装脚本目录
# ---------------------------------

$PhotoshopScripts = "C:\Program Files\Adobe"


Create-Shortcut `
"Photoshop安装脚本目录" `
"explorer.exe" `
"`"$PhotoshopScripts`"" `
(Join-Path $IconPath "photoshop_scripts.ico")



# ---------------------------------
# 8. Illustrator安装脚本目录
# ---------------------------------

$IllustratorScripts = "C:\Program Files\Adobe"


Create-Shortcut `
"Illustrator安装脚本目录" `
"explorer.exe" `
"`"$IllustratorScripts`"" `
(Join-Path $IconPath "illustrator_scripts.ico")



# ---------------------------------
# 9. 项目文档
# ---------------------------------

Create-Shortcut `
"Codex Design 文档" `
"explorer.exe" `
"`"$ProjectPath\docs`"" `
(Join-Path $IconPath "codex_docs.ico")



# ---------------------------------
# 10. 项目规则
# ---------------------------------

Create-Shortcut `
"Codex Design 规则" `
"notepad.exe" `
"`"$ProjectPath\AGENTS.md`"" `
(Join-Path $IconPath "codex_rules.ico")



# ---------------------------------
# 11. 项目备份
# ---------------------------------

Create-Shortcut `
"Codex Design 项目备份" `
"powershell.exe" `
"-ExecutionPolicy Bypass -File `"$ProjectPath\tools\backup_project.ps1`"" `
(Join-Path $IconPath "project_backup.ico")



Write-Host ""

Write-Host "================================="
Write-Host " 桌面快捷方式创建完成"
Write-Host "================================="


pause