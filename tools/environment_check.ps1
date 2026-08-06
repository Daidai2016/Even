# ==========================================
# Codex Design 环境检查工具 V2.1.1
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

$ErrorActionPreference = "Stop"


# ==========================================
# 函数
# ==========================================


function Get-CommandVersion {

    param(
        [string]$CommandName,
        [string[]]$Arguments = @("--version")
    )


    $Command = Get-Command $CommandName -ErrorAction SilentlyContinue


    if ($null -eq $Command) {

        return "未安装"

    }


    try {

        $Output = & $Command.Source @Arguments 2>&1


        if ($null -eq $Output) {

            return "已安装，但无法读取版本"

        }


        $Text = ($Output | Select-Object -First 1).ToString().Trim()


        if ([string]::IsNullOrWhiteSpace($Text)) {

            return "已安装，但无版本信息"

        }


        return $Text

    }
    catch {

        return "已安装，但检测失败"

    }

}



function Find-FirstExistingPath {

    param(
        [string[]]$Candidates
    )


    foreach($Candidate in $Candidates) {


        if ([string]::IsNullOrWhiteSpace($Candidate)) {

            continue

        }


        if (Test-Path -LiteralPath $Candidate) {

            return (
                Resolve-Path -LiteralPath $Candidate
            ).Path

        }

    }


    return "未找到"

}



function Add-Report {

    param(
        [string]$Text
    )

    $script:Report.Add($Text)

}



function Add-Status {

    param(
        [string]$Name,
        [string]$Value
    )


    if (
        $Value -match "未找到|未安装|失败|缺失"
    ) {

        $script:FailCount++

        Add-Report "❌ $Name：$Value"

    }
    elseif(
        $Value -match "存在未提交|警告"
    ) {

        $script:WarningCount++

        Add-Report "⚠ $Name：$Value"

    }
    else {

        $script:SuccessCount++

        Add-Report "✓ $Name：$Value"

    }

}



# ==========================================
# 主程序
# ==========================================


try {


    $ProjectPath = (
        Resolve-Path (
            Join-Path $PSScriptRoot ".."
        )
    ).Path


    $LogsPath =
    Join-Path $ProjectPath "logs"



    if (!(Test-Path $LogsPath)) {

        New-Item `
        -ItemType Directory `
        -Path $LogsPath `
        -Force |
        Out-Null

    }



    $Timestamp =
    Get-Date -Format "yyyyMMdd_HHmmss"



    $LogFile =
    Join-Path `
    $LogsPath `
    "environment_check_$Timestamp.txt"



    $Report =
    New-Object System.Collections.Generic.List[string]


    $SuccessCount = 0

    $WarningCount = 0

    $FailCount = 0



    # 后续检测内容见第2部分
        # ==========================================
    # 系统环境
    # ==========================================


    $OS =
    Get-CimInstance Win32_OperatingSystem



    $PowerShellVersion =
    $PSVersionTable.PSVersion.ToString()



    Add-Report ""
    Add-Report "系统"
    Add-Report "----------------------------------------"


    Add-Status `
    "Windows" `
    "$($OS.Caption) $($OS.Version)"


    Add-Status `
    "PowerShell" `
    $PowerShellVersion




    # ==========================================
    # 开发工具
    # ==========================================


    $GitVersion =
    Get-CommandVersion "git"



    $NodeVersion =
    Get-CommandVersion "node"



    $NpmVersion =
    Get-CommandVersion "npm.cmd"



    $PythonVersion =
    Get-CommandVersion "python"



    $CodexVersion =
    Get-CommandVersion "codex"



    $VSCodeVersion =
    Get-CommandVersion "code"



    Add-Report ""
    Add-Report "开发工具"
    Add-Report "----------------------------------------"


    Add-Status "Git" $GitVersion

    Add-Status "Node.js" $NodeVersion

    Add-Status "npm" $NpmVersion

    Add-Status "Python" $PythonVersion

    Add-Status "Codex" $CodexVersion

    Add-Status "VS Code" $VSCodeVersion




    # ==========================================
    # VS Code 工作区
    # ==========================================


    $VSCodeFolder =
    Join-Path $ProjectPath ".vscode"



    Add-Report ""
    Add-Report "VS Code 工作区"
    Add-Report "----------------------------------------"



    $VSCodeFiles = @(
        "extensions.json",
        "settings.json",
        "tasks.json"
    )


    foreach($File in $VSCodeFiles){


        $CheckPath =
        Join-Path $VSCodeFolder $File



        if(Test-Path $CheckPath){

            Add-Status `
            "VS Code配置" `
            "$File：存在"

        }
        else{

            Add-Status `
            "VS Code配置" `
            "$File：缺失"

        }

    }





    # ==========================================
    # Adobe Beta
    # ==========================================


    $PhotoshopBetaPath =
    Find-FirstExistingPath @(
        (
            Join-Path `
            $env:ProgramFiles `
            "Adobe\Adobe Photoshop (Beta)"
        )
    )



    $IllustratorBetaPath =
    Find-FirstExistingPath @(
        (
            Join-Path `
            $env:ProgramFiles `
            "Adobe\Adobe Illustrator (Beta)"
        )
    )



    $PhotoshopJSXPath =
    Join-Path `
    $env:ProgramFiles `
    "Adobe\Adobe Photoshop (Beta)\Presets\Scripts"



    $IllustratorJSXPath =
    Join-Path `
    $env:ProgramFiles `
    "Adobe\Adobe Illustrator (Beta)\Presets\zh_CN\脚本"



    Add-Report ""
    Add-Report "Adobe Beta"
    Add-Report "----------------------------------------"



    Add-Status `
    "Photoshop Beta" `
    $PhotoshopBetaPath



    Add-Status `
    "Illustrator Beta" `
    $IllustratorBetaPath




    if(Test-Path $PhotoshopJSXPath){

        Add-Status `
        "Photoshop JSX目录" `
        "存在"

    }
    else{

        Add-Status `
        "Photoshop JSX目录" `
        "缺失"

    }




    if(Test-Path $IllustratorJSXPath){

        Add-Status `
        "Illustrator JSX目录" `
        "存在"

    }
    else{

        Add-Status `
        "Illustrator JSX目录" `
        "缺失"

    }





    # ==========================================
    # MCP
    # ==========================================


    Add-Report ""
    Add-Report "MCP"
    Add-Report "----------------------------------------"



    try{


        $McpResult =
        codex mcp list 2>$null



        if(
            $McpResult -match "adobe_illustrator"
        ){

            Add-Status `
            "Illustrator MCP" `
            "已配置"

        }
        else{

            Add-Status `
            "Illustrator MCP" `
            "未发现"

        }


    }
    catch{


        Add-Status `
        "Illustrator MCP" `
        "检查失败"


    }





    # ==========================================
    # Git状态
    # ==========================================


    Add-Report ""
    Add-Report "Git"
    Add-Report "----------------------------------------"



    $GitStatus =
    git status --porcelain



    if(
        [string]::IsNullOrWhiteSpace($GitStatus)
    ){

        Add-Status `
        "Git状态" `
        "工作区干净"

    }
    else{


        Add-Status `
        "Git状态" `
        "存在未提交修改"

    }





    # ==========================================
    # GitHub连接
    # ==========================================


    git ls-remote origin > $null 2>&1



    if($LASTEXITCODE -eq 0){


        Add-Status `
        "GitHub连接" `
        "正常"


    }
    else{


        Add-Status `
        "GitHub连接" `
        "失败"


    }





    # ==========================================
    # Windows代理
    # ==========================================


    Add-Report ""
    Add-Report "网络"
    Add-Report "----------------------------------------"



    $Proxy =
    Get-ItemProperty `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" `
    -ErrorAction SilentlyContinue



    if(
        $Proxy.ProxyEnable -eq 1
    ){

        $ProxyStatus =
        "已启用：" + $Proxy.ProxyServer

    }
    else{

        $ProxyStatus =
        "未启用"

    }



    Add-Status `
    "Windows代理" `
    $ProxyStatus



    # 第3部分继续
        # ==========================================
    # 检查摘要
    # ==========================================


    Add-Report ""

    Add-Report "检查摘要"

    Add-Report "----------------------------------------"

    Add-Report "通过：$SuccessCount"

    Add-Report "警告：$WarningCount"

    Add-Report "失败：$FailCount"



    Add-Report ""

    Add-Report "说明："

    Add-Report "本报告不记录密码、Token、API Key。"





    # ==========================================
    # 保存日志
    # ==========================================


    $Report |
    Set-Content `
    -LiteralPath $LogFile `
    -Encoding UTF8





    # ==========================================
    # 输出报告
    # ==========================================


    foreach($Line in $Report){

        Write-Host $Line

    }



    Write-Host ""

    Write-Host "环境检查完成。" `
    -ForegroundColor Green



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