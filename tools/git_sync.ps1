# ==========================================
# Codex Design GitHub Sync Tool V2.1
# 安全同步 GitHub
# 支持 Windows 全局代理环境
# ==========================================


$ProjectPath = Split-Path $PSScriptRoot -Parent

Set-Location $ProjectPath


function Write-Title {

    Write-Host ""
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host " Codex Design GitHub 安全同步 V2.1" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""

}


function Check-Git {

    if (!(Get-Command git -ErrorAction SilentlyContinue)) {

        Write-Host "错误：未检测到 Git" -ForegroundColor Red
        pause
        exit

    }

}


function Check-Network {


    Write-Host "[2/5] 检查网络环境..." -ForegroundColor Yellow


    # Git代理

    $gitHttpProxy = git config --global --get http.proxy

    $gitHttpsProxy = git config --global --get https.proxy


    if ($gitHttpProxy -or $gitHttpsProxy) {

        Write-Host "Git代理：" -ForegroundColor Green

        if ($gitHttpProxy) {

            Write-Host $gitHttpProxy

        }

        if ($gitHttpsProxy) {

            Write-Host $gitHttpsProxy

        }

    }
    else {

        Write-Host "Git代理：未配置"

    }



    # Windows代理

    $proxyEnable = Get-ItemProperty `
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" `
        -ErrorAction SilentlyContinue


    if ($proxyEnable.ProxyEnable -eq 1) {

        Write-Host "Windows系统代理：已启用" -ForegroundColor Green

        Write-Host $proxyEnable.ProxyServer

    }
    else {

        Write-Host "Windows系统代理：未启用"

    }



    Write-Host ""

    Write-Host "测试 GitHub 连接..." -ForegroundColor Yellow


    git ls-remote origin > $null 2>&1


    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "GitHub连接失败。" -ForegroundColor Red

        Write-Host "请检查网络代理。" -ForegroundColor Yellow

        pause
        exit

    }


    Write-Host "GitHub连接成功。" -ForegroundColor Green


}



Write-Title


Write-Host "项目目录："
Write-Host $ProjectPath

Write-Host ""


Check-Git



# ==============================
# Step 1
# ==============================


Write-Host "[1/5] 检查当前状态..." -ForegroundColor Yellow


git status --short


$status = git status --porcelain


if ($status) {


    Write-Host ""
    Write-Host "检测到未提交修改。" -ForegroundColor Red

    Write-Host "同步已停止，请先提交或处理修改。" -ForegroundColor Yellow

    pause
    exit

}


Write-Host "工作区干净。" -ForegroundColor Green



# ==============================
# Step 2
# ==============================


Check-Network



# ==============================
# Step 3
# ==============================


Write-Host ""

Write-Host "[3/5] 获取远程更新..." -ForegroundColor Yellow


git fetch origin



# ==============================
# Step 4
# ==============================


Write-Host ""

Write-Host "[4/5] 同步 main 分支..." -ForegroundColor Yellow


git pull --ff-only origin main



if ($LASTEXITCODE -ne 0) {


    Write-Host ""

    Write-Host "同步失败。" -ForegroundColor Red

    Write-Host "可能存在分支差异。" -ForegroundColor Yellow

    pause

    exit

}



# ==============================
# Step 5
# ==============================


Write-Host ""

Write-Host "[5/5] 验证同步结果..." -ForegroundColor Yellow


git status



Write-Host ""

Write-Host "==================================" -ForegroundColor Green

Write-Host " GitHub同步完成" -ForegroundColor Green

Write-Host "==================================" -ForegroundColor Green


pause