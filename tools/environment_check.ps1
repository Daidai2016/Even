# ==========================================
# Codex Design 环境检查工具
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

$ErrorActionPreference = "Stop"

function Get-CommandVersion {
    param(
        [string]$CommandName,
        [string[]]$Arguments = @("--version")
    )

    $Command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $Command) {
        return "未找到"
    }

    try {
        $VersionOutput = @(& $Command.Source @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0 -or $VersionOutput.Count -eq 0) {
            return "已安装，但无法读取版本（$($Command.Source)）"
        }

        return (($VersionOutput | Select-Object -First 1) -as [string]).Trim()
    }
    catch {
        return "已安装，但检查失败（$($Command.Source)）"
    }
}

function Find-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($Candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($Candidate) -and (Test-Path -LiteralPath $Candidate)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }

    return "未找到"
}

try {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $LogsPath = Join-Path $ProjectPath "logs"

    if (-not (Test-Path -LiteralPath $LogsPath -PathType Container)) {
        New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFile = Join-Path $LogsPath "environment_check_$Timestamp.txt"
    $Report = New-Object System.Collections.Generic.List[string]

    $Os = Get-CimInstance Win32_OperatingSystem
    $PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    $GitVersion = Get-CommandVersion "git"
    $NodeVersion = Get-CommandVersion "node"
    $NpmVersion = Get-CommandVersion "npm.cmd"
    $PythonVersion = Get-CommandVersion "python"
    $CodexVersion = Get-CommandVersion "codex"

    $VSCodePath = Find-FirstExistingPath @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\Code.exe"),
        (Join-Path ([Environment]::GetEnvironmentVariable("ProgramFiles(x86)")) "Microsoft VS Code\Code.exe")
    )

    $PhotoshopBetaPath = Find-FirstExistingPath @(
        (Join-Path $env:ProgramFiles "Adobe\Adobe Photoshop (Beta)")
    )
    $IllustratorBetaPath = Find-FirstExistingPath @(
        (Join-Path $env:ProgramFiles "Adobe\Adobe Illustrator (Beta)")
    )

    $CodexConfigPath = Join-Path $env:USERPROFILE ".codex\config.toml"
    $McpStatus = "未找到 Codex 配置文件"
    if (Test-Path -LiteralPath $CodexConfigPath -PathType Leaf) {
        $McpServerCount = @(
            Select-String `
                -LiteralPath $CodexConfigPath `
                -Pattern '^\s*\[mcp_servers\.' `
                -ErrorAction SilentlyContinue
        ).Count
        $McpStatus = "已找到 Codex 配置；MCP 服务器配置数：$McpServerCount"
    }

    $Report.Add("Codex Design 环境检查")
    $Report.Add("========================================")
    $Report.Add("检查时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $Report.Add("项目目录：$ProjectPath")
    $Report.Add("")
    $Report.Add("系统")
    $Report.Add("----------------------------------------")
    $Report.Add("Windows：$($Os.Caption) $($Os.Version) (Build $($Os.BuildNumber))")
    $Report.Add("PowerShell：$PowerShellVersion")
    $Report.Add("")
    $Report.Add("开发工具")
    $Report.Add("----------------------------------------")
    $Report.Add("Git：$GitVersion")
    $Report.Add("Node.js：$NodeVersion")
    $Report.Add("npm：$NpmVersion")
    $Report.Add("Python：$PythonVersion")
    $Report.Add("Codex：$CodexVersion")
    $Report.Add("VS Code：$VSCodePath")
    $Report.Add("")
    $Report.Add("Adobe Beta")
    $Report.Add("----------------------------------------")
    $Report.Add("Photoshop Beta：$PhotoshopBetaPath")
    $Report.Add("Illustrator Beta：$IllustratorBetaPath")
    $Report.Add("")
    $Report.Add("MCP")
    $Report.Add("----------------------------------------")
    $Report.Add($McpStatus)
    $Report.Add("")
    $Report.Add("说明：报告仅记录环境状态，不包含密钥、令牌或代理凭据。")

    $Report | Set-Content -LiteralPath $LogFile -Encoding UTF8
    $Report | ForEach-Object { Write-Host $_ }

    Write-Host ""
    Write-Host "环境检查完成。" -ForegroundColor Green
    Write-Host "报告文件：$LogFile"
}
catch {
    Write-Host ""
    Write-Host "环境检查失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
[void](Read-Host "按 Enter 键关闭窗口")
