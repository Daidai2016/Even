# ==================================================
# Codex Skills and Plugins Reconciler V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==================================================

param(
    [switch]$CheckOnly,
    [switch]$SkillsOnly,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ManifestPath = Join-Path $ProjectPath "tools\config\codex_capabilities.json"
$ProxyGuardPath = Join-Path $ProjectPath "tools\lib\github_proxy_guard.ps1"
$PluginInstallerPath = Join-Path $ProjectPath "tools\install_codex_design_plugin.ps1"
$LocalizationPath = Join-Path $ProjectPath "tools\localize_codex_skills.ps1"
$CodexEnvironmentPath = Join-Path $ProjectPath "tools\create_codex_env.ps1"
$script:TemporaryRoot = $null


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
        throw "未检测到 Windows PowerShell。"
    }

    return $Command.Source
}


function Invoke-ChildScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "缺少同步组件：$ScriptPath"
    }

    $ChildArguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $ScriptPath
    ) + $Arguments

    & $script:PowerShellExe @ChildArguments

    if ($LASTEXITCODE -ne 0) {
        throw "同步组件执行失败：$(Split-Path -Leaf $ScriptPath)"
    }
}


function Invoke-Git {
    param([string[]]$Arguments)

    & $script:GitExe @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Git 命令执行失败。"
    }
}


function Invoke-Codex {
    param([string[]]$Arguments)

    $PreviousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $Output = @(& $script:CodexExe @Arguments 2>$null)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($ExitCode -ne 0) {
        throw "Codex 命令执行失败：$($Arguments -join ' ')"
    }

    return @($Output)
}


function Get-SkillBasePath {
    param([string]$Scope)

    $UserProfile = [Environment]::GetFolderPath("UserProfile")

    switch ($Scope) {
        "codex" {
            return (Join-Path $UserProfile ".codex\skills")
        }
        "agents" {
            return (Join-Path $UserProfile ".agents\skills")
        }
        default {
            throw "不支持的 Skill scope：$Scope"
        }
    }
}


function Test-SkillInstalled {
    param([object]$Skill)

    $BasePath = Get-SkillBasePath -Scope ([string]$Skill.scope)
    $SkillPath = Join-Path $BasePath ([string]$Skill.name)
    $SkillManifest = Join-Path $SkillPath "SKILL.md"

    return (Test-Path -LiteralPath $SkillManifest -PathType Leaf)
}


function Test-SafeSkillSource {
    param([string]$SourcePath)

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Skill 来源目录不存在：$SourcePath"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $SourcePath "SKILL.md") -PathType Leaf)) {
        throw "Skill 来源缺少 SKILL.md：$SourcePath"
    }

    $UnsafeItems = @(
        Get-ChildItem -LiteralPath $SourcePath -Force -Recurse |
            Where-Object {
                ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            }
    )

    if ($UnsafeItems.Count -gt 0) {
        throw "Skill 来源包含链接或重解析点：$SourcePath"
    }
}


function Resolve-GitHubSkillSource {
    param(
        [string]$ClonePath,
        [object]$Skill
    )

    $ConfiguredPath = [string]$Skill.sourcePath

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) {
        $Candidate = Join-Path $ClonePath ($ConfiguredPath -replace "/", "\")

        if (Test-Path -LiteralPath (Join-Path $Candidate "SKILL.md") -PathType Leaf) {
            return $Candidate
        }

        throw "上游路径缺少 SKILL.md：$($Skill.repository)/$ConfiguredPath"
    }

    $ExpectedName = [regex]::Escape([string]$Skill.name)
    $Matches = New-Object "System.Collections.Generic.List[string]"
    $SkillFiles = Get-ChildItem `
        -LiteralPath $ClonePath `
        -Filter "SKILL.md" `
        -File `
        -Recurse

    foreach ($SkillFile in $SkillFiles) {
        if ($SkillFile.FullName -like "*\.git\*") {
            continue
        }

        $Header = Get-Content `
            -LiteralPath $SkillFile.FullName `
            -Encoding UTF8 `
            -TotalCount 30 |
            Out-String

        if ($Header -match "(?m)^name:\s*[`"']?$ExpectedName[`"']?\s*$") {
            [void]$Matches.Add($SkillFile.Directory.FullName)
        }
    }

    if ($Matches.Count -ne 1) {
        throw (
            "无法在 $($Skill.repository) 中唯一定位 Skill：" +
            "$($Skill.name)（匹配数：$($Matches.Count)）"
        )
    }

    return $Matches[0]
}


function Install-StagedSkill {
    param(
        [object]$Skill,
        [string]$SourcePath
    )

    Test-SafeSkillSource -SourcePath $SourcePath

    $BasePath = Get-SkillBasePath -Scope ([string]$Skill.scope)
    $DestinationPath = Join-Path $BasePath ([string]$Skill.name)

    if (Test-SkillInstalled -Skill $Skill) {
        Write-Host "  已存在，保留：$($Skill.name)" -ForegroundColor DarkGray
        return
    }

    if (Test-Path -LiteralPath $DestinationPath) {
        throw "目标目录已存在但缺少 SKILL.md：$DestinationPath"
    }

    if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $BasePath -Force)
    }

    $StagePath = Join-Path `
        $script:TemporaryRoot `
        ("stage-" + [string]$Skill.name + "-" + [guid]::NewGuid().ToString("N"))

    Copy-Item -LiteralPath $SourcePath -Destination $StagePath -Recurse
    Test-SafeSkillSource -SourcePath $StagePath
    Move-Item -LiteralPath $StagePath -Destination $DestinationPath

    Write-Host "  已安装：$($Skill.name)" -ForegroundColor Green
}


function Install-MissingSkills {
    param([object[]]$MissingSkills)

    if ($MissingSkills.Count -eq 0) {
        return
    }

    $SnapshotSkills = @($MissingSkills | Where-Object { $_.type -eq "snapshot" })

    foreach ($Skill in $SnapshotSkills) {
        $SourcePath = Join-Path `
            $ProjectPath `
            (([string]$Skill.sourcePath) -replace "/", "\")
        Install-StagedSkill -Skill $Skill -SourcePath $SourcePath
    }

    $GitHubSkills = @($MissingSkills | Where-Object { $_.type -eq "github" })

    if ($GitHubSkills.Count -eq 0) {
        return
    }

    if (-not (Test-Path -LiteralPath $ProxyGuardPath -PathType Leaf)) {
        throw "缺少 GitHub 代理保护组件。"
    }

    . $ProxyGuardPath
    $Guard = Test-GitHubProxyGuard -RepositoryRoot $ProjectPath

    if (-not $Guard.Success) {
        throw $Guard.Message
    }

    $GitCommand = Get-Command "git.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        throw "未检测到 git.exe。"
    }

    $script:GitExe = $GitCommand.Source
    Write-Host "GitHub 代理检查通过；所有 Skill 下载将使用当前代理。" `
        -ForegroundColor DarkGray

    $Groups = @($GitHubSkills | Group-Object -Property repository)

    foreach ($Group in $Groups) {
        $Repository = [string]$Group.Name
        $ClonePath = Join-Path `
            $script:TemporaryRoot `
            ("repo-" + [guid]::NewGuid().ToString("N"))
        $CloneUrl = "https://github.com/$Repository.git"
        $ExplicitPaths = @(
            $Group.Group |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_.sourcePath)
                } |
                ForEach-Object { [string]$_.sourcePath } |
                Sort-Object -Unique
        )
        $NeedsDiscovery = @(
            $Group.Group |
                Where-Object {
                    [string]::IsNullOrWhiteSpace([string]$_.sourcePath)
                }
        ).Count -gt 0

        Write-Host "  获取来源：$Repository"
        Invoke-Git -Arguments @(
            "clone",
            "--depth", "1",
            "--filter=blob:none",
            "--no-checkout",
            $CloneUrl,
            $ClonePath
        )

        if (-not $NeedsDiscovery -and $ExplicitPaths.Count -gt 0) {
            Invoke-Git -Arguments @(
                "-C", $ClonePath,
                "sparse-checkout", "init", "--cone"
            )
            Invoke-Git -Arguments (@(
                "-C", $ClonePath,
                "sparse-checkout", "set"
            ) + $ExplicitPaths)
        }

        Invoke-Git -Arguments @(
            "-C", $ClonePath,
            "checkout", "--force"
        )

        foreach ($Skill in $Group.Group) {
            $SourcePath = Resolve-GitHubSkillSource `
                -ClonePath $ClonePath `
                -Skill $Skill
            Install-StagedSkill -Skill $Skill -SourcePath $SourcePath
        }
    }
}


function Get-InstalledPluginIds {
    $JsonText = Invoke-Codex -Arguments @("plugin", "list", "--json") |
        Out-String
    $PluginData = $JsonText | ConvertFrom-Json
    $Ids = New-Object "System.Collections.Generic.List[string]"

    foreach ($Plugin in @($PluginData.installed)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$Plugin.pluginId)) {
            [void]$Ids.Add([string]$Plugin.pluginId)
        }
    }

    return @($Ids)
}


function Sync-Plugins {
    param([object]$Manifest)

    $CodexCommand = Get-Command "codex.cmd" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $CodexCommand) {
        throw "未检测到 codex.cmd。"
    }

    $script:CodexExe = $CodexCommand.Source

    foreach ($PluginName in @($Manifest.repositoryPlugins)) {
        $Arguments = @("-PluginName", [string]$PluginName, "-NoPause")

        if ($CheckOnly) {
            $Arguments += "-CheckOnly"
        }

        Invoke-ChildScript `
            -ScriptPath $PluginInstallerPath `
            -Arguments $Arguments
    }

    $InstalledIds = @(Get-InstalledPluginIds)

    foreach ($PluginId in @($Manifest.managedPlugins)) {
        if ($InstalledIds -contains [string]$PluginId) {
            Write-Host "  插件已安装：$PluginId" -ForegroundColor DarkGray
            continue
        }

        if ($CheckOnly) {
            throw "缺少插件：$PluginId"
        }

        [void](Invoke-Codex -Arguments @(
            "plugin", "add", [string]$PluginId, "--json"
        ))
        Write-Host "  已安装插件：$PluginId" -ForegroundColor Green
    }
}


function Show-OptionalCommandStatus {
    param([object]$Manifest)

    foreach ($CommandName in @($Manifest.optionalCommands)) {
        $Command = Get-Command `
            ([string]$CommandName) `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -eq $Command) {
            Write-Host (
                "  可选命令未安装：$CommandName；对应 Skill 需要时再配置。"
            ) -ForegroundColor Yellow
        }
        else {
            Write-Host "  可选命令可用：$CommandName" -ForegroundColor DarkGray
        }
    }
}


function Remove-TemporaryRoot {
    if ([string]::IsNullOrWhiteSpace([string]$script:TemporaryRoot)) {
        return
    }

    $ResolvedTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $ResolvedTarget = [IO.Path]::GetFullPath($script:TemporaryRoot)
    $TargetName = Split-Path -Leaf $ResolvedTarget

    if (
        -not $ResolvedTarget.StartsWith(
            $ResolvedTempBase,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not $TargetName.StartsWith("codex-capability-sync-")
    ) {
        throw "拒绝清理未经验证的临时目录：$ResolvedTarget"
    }

    if (Test-Path -LiteralPath $ResolvedTarget) {
        Remove-Item -LiteralPath $ResolvedTarget -Recurse -Force
    }
}


try {
    $script:PowerShellExe = Get-WindowsPowerShell

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "缺少能力清单：tools\config\codex_capabilities.json"
    }

    $Manifest = Get-Content `
        -LiteralPath $ManifestPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ([int]$Manifest.schemaVersion -ne 1) {
        throw "不支持的能力清单版本。"
    }

    $script:TemporaryRoot = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ("codex-capability-sync-" + [guid]::NewGuid().ToString("N"))
    [void](New-Item -ItemType Directory -Path $script:TemporaryRoot)

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host " Codex Skills 与插件同步" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "模式：$(if ($CheckOnly) { '只读检查' } else { '补齐缺失能力' })"
    Write-Host "策略：保留已有 Skill，不删除未知项目，不复制登录状态。" `
        -ForegroundColor DarkGray

    $MissingSkills = New-Object "System.Collections.Generic.List[object]"

    foreach ($Skill in @($Manifest.skills)) {
        if (Test-SkillInstalled -Skill $Skill) {
            Write-Host "  Skill 已存在：$($Skill.name)" -ForegroundColor DarkGray
        }
        else {
            [void]$MissingSkills.Add($Skill)
            Write-Host "  缺少 Skill：$($Skill.name)" -ForegroundColor Yellow
        }
    }

    if ($CheckOnly -and $MissingSkills.Count -gt 0) {
        throw "缺少 $($MissingSkills.Count) 个受管 Skill。"
    }

    if (-not $CheckOnly) {
        Install-MissingSkills -MissingSkills ($MissingSkills.ToArray())
    }

    if ($SkillsOnly) {
        Write-Host "Skill 同步完成。" -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "同步插件" -ForegroundColor Cyan
    Sync-Plugins -Manifest $Manifest

    if ($CheckOnly) {
        Invoke-ChildScript `
            -ScriptPath $LocalizationPath `
            -Arguments @("-CheckOnly", "-NoPause")
    }
    else {
        Invoke-ChildScript `
            -ScriptPath $LocalizationPath `
            -Arguments @("-NoPause")
        Invoke-ChildScript `
            -ScriptPath $CodexEnvironmentPath `
            -Arguments @("-Force", "-NoPause")
    }

    Write-Host ""
    Write-Host "检查可选命令" -ForegroundColor Cyan
    Show-OptionalCommandStatus -Manifest $Manifest

    Write-Host ""
    Write-Host "Codex Skills 与插件同步完成。" -ForegroundColor Green
    Write-Host "重新打开 Codex 后加载新安装的能力。" -ForegroundColor DarkGray
}
catch {
    Write-Host ""
    Write-Host "同步失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    try {
        Remove-TemporaryRoot
    }
    catch {
        Write-Host "临时目录清理失败：$($_.Exception.Message)" `
            -ForegroundColor Yellow
    }

    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
