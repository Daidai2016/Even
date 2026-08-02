# =================================
# Codex Design Git 发布工具
# =================================


Write-Host ""
Write-Host "================================="
Write-Host " Codex Design Git Publish"
Write-Host "================================="


# ---------------------------------
# 自动定位项目根目录
# ---------------------------------

$ProjectPath = Join-Path $PSScriptRoot ".."

Set-Location $ProjectPath


Write-Host ""

Write-Host "当前项目："

Write-Host $ProjectPath


Write-Host ""


# ---------------------------------
# 检查 Git 状态
# ---------------------------------

Write-Host "【1】检查 Git 状态"

Write-Host ""

git status


Write-Host ""


# ---------------------------------
# 用户确认
# ---------------------------------

$confirm = Read-Host "是否继续提交并同步 GitHub？(Y/N)"


if ($confirm -ne "Y" -and $confirm -ne "y") {

    Write-Host ""

    Write-Host "取消操作"

    pause

    exit

}


Write-Host ""


# ---------------------------------
# 添加修改文件
# ---------------------------------

Write-Host "【2】添加修改文件"

git add .


Write-Host ""


# ---------------------------------
# 输入提交信息
# ---------------------------------

Write-Host "【3】填写 Git 提交说明"

$message = Read-Host "Commit Message"


if ([string]::IsNullOrWhiteSpace($message)) {

    $message = "Update Codex Design files"

}


Write-Host ""


# ---------------------------------
# 提交
# ---------------------------------

git commit -m "$message"


Write-Host ""


# ---------------------------------
# 推送 GitHub
# ---------------------------------

Write-Host "【4】同步 GitHub"

git push origin main


Write-Host ""


# ---------------------------------
# 完成
# ---------------------------------

Write-Host "================================="
Write-Host " Git 发布完成"
Write-Host "================================="


Write-Host ""

pause