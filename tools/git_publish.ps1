# Codex Design Git自动发布脚本

Write-Host "================================="
Write-Host " Codex Design Git Publish"
Write-Host "================================="


# 进入项目目录
Set-Location "E:\AI_Workspace\Codex_Design"


Write-Host ""
Write-Host "【1】检查Git状态"

git status


Write-Host ""

$confirm = Read-Host "是否继续提交并同步GitHub？(Y/N)"


if ($confirm -ne "Y") {

    Write-Host "取消操作"

    exit

}


Write-Host ""

Write-Host "【2】添加修改文件"

git add .


Write-Host ""

Write-Host "【3】输入提交说明"

$message = Read-Host "Commit Message"


if ($message -eq "") {

    $message = "Update Codex Design files"

}


git commit -m "$message"


Write-Host ""

Write-Host "【4】推送GitHub"

git push origin main


Write-Host ""

Write-Host "================================="
Write-Host " 发布完成"
Write-Host "================================="


pause