# Codex Design Git状态检查脚本


Write-Host "================================="
Write-Host " Codex Design Git Status"
Write-Host "================================="


# 自动进入项目根目录
Set-Location (Join-Path $PSScriptRoot "..")


Write-Host ""

Write-Host "当前项目："

pwd


Write-Host ""

Write-Host "Git状态："

git status


Write-Host ""

pause