# ==================================================
# Codex Design First Workstation Setup V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==================================================

param(
    [switch]$CheckOnly,
    [switch]$SkipDesktopShortcuts,
    [switch]$SkipEnvironmentCheck,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$CompletedSteps = New-Object "System.Collections.Generic.List[string]"


function Stop-Setup {
    param([string]$Message)

    throw $Message
}


function Get-WindowsPowerShell {
    $Candidate = Join-Path `
        $env:SystemRoot `
        "System32\WindowsPowerShell\v1.0\powershell.exe"

    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        return $Candidate
    }

    $Command = Get-Command "powershell.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $Command) {
        Stop-Setup -Message "未检测到 Windows PowerShell。"
    }

    return $Command.Source
}


function Invoke-SetupStep {
    param(
        [string]$Name,
        [string]$RelativeScriptPath,
        [string[]]$Arguments = @()
    )

    $ScriptPath = Join-Path $ProjectPath $RelativeScriptPath

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        Stop-Setup -Message "缺少部署工具：$RelativeScriptPath"
    }

    Write-Host ""
    Write-Host "[$($CompletedSteps.Count + 1)] $Name" -ForegroundColor Cyan
    Write-Host "----------------------------------------------"

    $ChildArguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $ScriptPath
    ) + $Arguments

    & $script:PowerShellExe @ChildArguments
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        Stop-Setup -Message "$Name 失败，退出码：$ExitCode"
    }

    [void]$CompletedSteps.Add($Name)
}


try {
    $script:PowerShellExe = Get-WindowsPowerShell

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Design 首次部署本机" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "项目目录：$ProjectPath"
    Write-Host "模式：$(if ($CheckOnly) { '只读检查' } else { '首次部署' })"
    Write-Host ""
    Write-Host "本工具不会安装系统软件、访问 GitHub、提交或推送。" `
        -ForegroundColor DarkGray

    Invoke-SetupStep `
        -Name "验证仓库结构" `
        -RelativeScriptPath "tools\validate_repository.ps1" `
        -Arguments @("-NoPause")

    if ($CheckOnly) {
        foreach ($PluginName in @(
            "codex-design-workflows",
            "codex-design-visuals"
        )) {
            Invoke-SetupStep `
                -Name "检查插件：$PluginName" `
                -RelativeScriptPath "tools\install_codex_design_plugin.ps1" `
                -Arguments @(
                    "-PluginName",
                    $PluginName,
                    "-CheckOnly",
                    "-NoPause"
                )
        }

        Invoke-SetupStep `
            -Name "检查 Skill 中文界面" `
            -RelativeScriptPath "tools\localize_codex_skills.ps1" `
            -Arguments @("-CheckOnly", "-NoPause")

        Write-Host ""
        Write-Host "部署状态检查通过。" -ForegroundColor Green
        exit 0
    }

    Invoke-SetupStep `
        -Name "配置当前仓库 Git 规范" `
        -RelativeScriptPath "tools\configure_repository_git.ps1" `
        -Arguments @("-NoPause")

    foreach ($PluginName in @(
        "codex-design-workflows",
        "codex-design-visuals"
    )) {
        Invoke-SetupStep `
            -Name "安装插件：$PluginName" `
            -RelativeScriptPath "tools\install_codex_design_plugin.ps1" `
            -Arguments @(
                "-PluginName",
                $PluginName,
                "-NoPause"
            )
    }

    Invoke-SetupStep `
        -Name "应用 Skill 中文界面" `
        -RelativeScriptPath "tools\localize_codex_skills.ps1" `
        -Arguments @("-NoPause")

    if (-not $SkipDesktopShortcuts) {
        Invoke-SetupStep `
            -Name "创建桌面工作台" `
            -RelativeScriptPath "tools\create_desktop_shortcuts.ps1" `
            -Arguments @("-ValidationMode")
    }

    foreach ($PluginName in @(
        "codex-design-workflows",
        "codex-design-visuals"
    )) {
        Invoke-SetupStep `
            -Name "验证插件：$PluginName" `
            -RelativeScriptPath "tools\install_codex_design_plugin.ps1" `
            -Arguments @(
                "-PluginName",
                $PluginName,
                "-CheckOnly",
                "-NoPause"
            )
    }

    Invoke-SetupStep `
        -Name "验证 Skill 中文界面" `
        -RelativeScriptPath "tools\localize_codex_skills.ps1" `
        -Arguments @("-CheckOnly", "-NoPause")

    Invoke-SetupStep `
        -Name "最终仓库验证" `
        -RelativeScriptPath "tools\validate_repository.ps1" `
        -Arguments @("-NoPause")

    if (-not $SkipEnvironmentCheck) {
        Invoke-SetupStep `
            -Name "本机环境检查（不访问 GitHub）" `
            -RelativeScriptPath "tools\environment_check.ps1" `
            -Arguments @(
                "-SkipRemoteCheck",
                "-NoPause"
            )
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " Codex Design 本机首次部署完成" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "完成步骤：$($CompletedSteps.Count)"
    Write-Host "重新打开 Codex 或新建任务后，即可使用插件和中文 Skill 名称。"
    Write-Host "Codex 全局配置加固仍作为独立任务保留，不在首次部署中自动执行。" `
        -ForegroundColor DarkGray
}
catch {
    Write-Host ""
    Write-Host "首次部署失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "已完成步骤：$($CompletedSteps.Count)"
    exit 1
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
