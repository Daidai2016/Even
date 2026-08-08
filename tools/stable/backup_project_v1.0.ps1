# Codex Design 项目备份工具


Write-Host "================================="
Write-Host " Codex Design Backup"
Write-Host "================================="


# 当前脚本所在目录
$ToolsPath = $PSScriptRoot


# 项目根目录
$ProjectPath = Join-Path $ToolsPath ".."


# 备份目录（桌面）
$BackupRoot = Join-Path $env:USERPROFILE "Desktop\Codex_Backup"


# 时间
$Date = Get-Date -Format "yyyyMMdd_HHmmss"


# 备份目标
$Target = Join-Path $BackupRoot "Codex_Design_$Date"



Write-Host ""

Write-Host "项目目录："

Write-Host $ProjectPath


Write-Host ""

Write-Host "备份位置："

Write-Host $Target



# 创建备份目录

New-Item `
-ItemType Directory `
-Force `
-Path $Target | Out-Null



# 执行复制

Copy-Item `
-Path $ProjectPath\* `
-Destination $Target `
-Recurse `
-Force



Write-Host ""

Write-Host "================================="
Write-Host "备份完成"
Write-Host "================================="


pause