# ==========================================
# Codex Design Repository Validator V1.1.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

param(
    [switch]$ChangedOnly,
    [switch]$Quiet,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Errors = New-Object "System.Collections.Generic.List[string]"
$Warnings = New-Object "System.Collections.Generic.List[string]"
$Checks = 0


function Add-ValidationError {
    param([string]$Message)
    [void]$script:Errors.Add($Message)
}


function Add-ValidationWarning {
    param([string]$Message)
    [void]$script:Warnings.Add($Message)
}


function Get-RelativeProjectPath {
    param([string]$FullName)

    $Root = $script:ProjectPath.TrimEnd("\", "/") + "\"
    return $FullName.Substring($Root.Length).Replace("\", "/")
}


function Get-CandidateFiles {
    if (-not $ChangedOnly) {
        return @(
            Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Force |
                Where-Object {
                    $_.FullName -notmatch "[\\/]\.git[\\/]" -and
                    $_.FullName -notmatch "[\\/]logs[\\/]" -and
                    $_.FullName -notmatch "[\\/]work[\\/]"
                }
        )
    }

    $RelativePaths = New-Object "System.Collections.Generic.HashSet[string]" `
        ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($GitArgs in @(
        @("diff", "--name-only", "--diff-filter=ACMR"),
        @("diff", "--cached", "--name-only", "--diff-filter=ACMR"),
        @("ls-files", "--others", "--exclude-standard")
    )) {
        foreach ($Path in @(
            & git -C $ProjectPath -c core.safecrlf=false @GitArgs 2>$null
        )) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Path)) {
                [void]$RelativePaths.Add(([string]$Path).Trim())
            }
        }
    }

    $Files = @()

    foreach ($RelativePath in $RelativePaths) {
        $FullPath = Join-Path $ProjectPath $RelativePath

        if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
            $Files += Get-Item -LiteralPath $FullPath
        }
    }

    return @($Files)
}


function Test-Utf8BomPowerShellFile {
    param([System.IO.FileInfo]$File)

    $script:Checks++
    $Bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    $HasBom = (
        $Bytes.Length -ge 3 -and
        $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and
        $Bytes[2] -eq 0xBF
    )

    if (-not $HasBom) {
        Add-ValidationError `
            "PowerShell 文件不是 UTF-8 BOM：$(Get-RelativeProjectPath $File.FullName)"
    }
}


function Test-PowerShellSyntax {
    param([System.IO.FileInfo]$File)

    $script:Checks++
    $Tokens = $null
    $ParseErrors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $File.FullName,
        [ref]$Tokens,
        [ref]$ParseErrors
    )

    if (@($ParseErrors).Count -gt 0) {
        Add-ValidationError `
            "PowerShell 语法错误：$(Get-RelativeProjectPath $File.FullName)"
    }
}


function Test-Utf8JsonText {
    param([System.IO.FileInfo]$File)

    $script:Checks++
    $Bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    $HasBom = (
        $Bytes.Length -ge 3 -and
        $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and
        $Bytes[2] -eq 0xBF
    )

    try {
        $Utf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $Text = $Utf8.GetString($Bytes)
    }
    catch {
        Add-ValidationError `
            "JSON 不是严格 UTF-8：$(Get-RelativeProjectPath $File.FullName)"
        return
    }

    if ($HasBom) {
        Add-ValidationError `
            "JSON 必须使用 UTF-8 without BOM：$(Get-RelativeProjectPath $File.FullName)"
    }

    if ($Text.IndexOf([char]0xFFFD) -ge 0) {
        Add-ValidationError `
            "JSON 包含 Unicode 替换字符，疑似发生编码损坏：$(Get-RelativeProjectPath $File.FullName)"
    }

    if ($Text.Contains("`r")) {
        Add-ValidationError `
            "JSON 必须使用 LF 换行：$(Get-RelativeProjectPath $File.FullName)"
    }

    foreach ($Marker in @(
        "鐘舵",
        "妫€",
        "鐜",
        "锝滄",
        "鍙戝",
        "鍚屾",
        "瀹夎",
        "浠撳",
        "妗岄潰",
        "鎻掍欢"
    )) {
        if ($Text.Contains($Marker)) {
            Add-ValidationError `
                "JSON 疑似把 UTF-8 错按 CP936/GBK 解码：$(Get-RelativeProjectPath $File.FullName)"
            break
        }
    }
}


function Test-JsonFile {
    param([System.IO.FileInfo]$File)

    $script:Checks++

    try {
        [void](
            Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8 |
                ConvertFrom-Json
        )
    }
    catch {
        Add-ValidationError `
            "JSON 无法解析：$(Get-RelativeProjectPath $File.FullName)"
    }
}


function Test-PluginManifest {
    param([System.IO.FileInfo]$File)

    $script:Checks++

    try {
        $Manifest = Get-Content `
            -LiteralPath $File.FullName `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        $PluginRoot = Split-Path $File.DirectoryName -Parent
        $FolderName = Split-Path $PluginRoot -Leaf

        if ($Manifest.name -ne $FolderName) {
            Add-ValidationError "插件名称与目录不一致：$FolderName"
        }

        if ([string]$Manifest.version -notmatch "^\d+\.\d+\.\d+$") {
            Add-ValidationError "插件版本不是严格 semver：$FolderName"
        }

        if (
            [string]::IsNullOrWhiteSpace([string]$Manifest.description) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.author.name) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.interface.displayName) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.interface.shortDescription) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.interface.longDescription) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.interface.developerName) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.interface.category)
        ) {
            Add-ValidationError "插件 manifest 缺少必要元数据：$FolderName"
        }

        if (
            -not [string]::IsNullOrWhiteSpace([string]$Manifest.skills) -and
            -not (Test-Path -LiteralPath (
                Join-Path $PluginRoot (
                    ([string]$Manifest.skills).TrimStart(
                        [char[]]@(".", "/", "\")
                    )
                )
            ) -PathType Container)
        ) {
            Add-ValidationError "插件 skills 路径不存在：$FolderName"
        }

        if (
            (Get-Content -LiteralPath $File.FullName -Raw) -match "\[TODO:"
        ) {
            Add-ValidationError "插件 manifest 含 TODO 占位符：$FolderName"
        }
    }
    catch {
        Add-ValidationError `
            "插件 manifest 校验失败：$(Get-RelativeProjectPath $File.FullName)"
    }
}


function Test-MarketplaceManifest {
    param([System.IO.FileInfo]$File)

    $script:Checks++

    try {
        $Marketplace = Get-Content `
            -LiteralPath $File.FullName `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        if (
            [string]::IsNullOrWhiteSpace([string]$Marketplace.name) -or
            [string]::IsNullOrWhiteSpace(
                [string]$Marketplace.interface.displayName
            ) -or
            @($Marketplace.plugins).Count -eq 0
        ) {
            Add-ValidationError "本地插件市场清单缺少必要字段。"
            return
        }

        foreach ($Plugin in @($Marketplace.plugins)) {
            if (
                [string]::IsNullOrWhiteSpace([string]$Plugin.name) -or
                [string]$Plugin.source.source -ne "local" -or
                [string]::IsNullOrWhiteSpace([string]$Plugin.source.path)
            ) {
                Add-ValidationError "本地插件市场包含无效插件条目。"
                continue
            }

            $PluginRelativePath = ([string]$Plugin.source.path).TrimStart(
                [char[]]@(".", "/", "\")
            )
            $PluginPath = Join-Path $ProjectPath $PluginRelativePath

            if (-not (Test-Path -LiteralPath $PluginPath -PathType Container)) {
                Add-ValidationError "本地插件市场指向不存在的插件：$($Plugin.name)"
            }
        }
    }
    catch {
        Add-ValidationError "本地插件市场清单校验失败。"
    }
}


function Test-SkillFolder {
    param([System.IO.FileInfo]$File)

    $script:Checks++
    $SkillRoot = $File.DirectoryName
    $FolderName = Split-Path $SkillRoot -Leaf
    $Text = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8

    $NameMatch = [regex]::Match(
        $Text,
        "(?ms)^---\s*\r?\nname:\s*([^\r\n]+).*?\r?\ndescription:\s*([^\r\n]+).*?\r?\n---"
    )

    if (-not $NameMatch.Success) {
        Add-ValidationError "Skill frontmatter 无效：$FolderName"
        return
    }

    $SkillName = $NameMatch.Groups[1].Value.Trim().Trim('"', "'")
    $Description = $NameMatch.Groups[2].Value.Trim().Trim('"', "'")

    if ($SkillName -ne $FolderName) {
        Add-ValidationError "Skill 名称与目录不一致：$FolderName"
    }

    if (
        $SkillName -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$" -or
        $SkillName.Length -gt 64
    ) {
        Add-ValidationError "Skill 名称不符合规范：$FolderName"
    }

    if ([string]::IsNullOrWhiteSpace($Description)) {
        Add-ValidationError "Skill description 为空：$FolderName"
    }

    if ($Text -match "\[TODO:") {
        Add-ValidationError "Skill 含 TODO 占位符：$FolderName"
    }

    $OpenAiYaml = Join-Path $SkillRoot "agents\openai.yaml"

    if (-not (Test-Path -LiteralPath $OpenAiYaml -PathType Leaf)) {
        Add-ValidationError "Skill 缺少 agents/openai.yaml：$FolderName"
        return
    }

    $YamlText = Get-Content -LiteralPath $OpenAiYaml -Raw -Encoding UTF8

    if ($YamlText -notmatch [regex]::Escape("`$$SkillName")) {
        Add-ValidationError "Skill 默认提示未显式引用 `$$SkillName：$FolderName"
    }
}


try {
    Set-Location -LiteralPath $ProjectPath
    $CandidateFiles = @(Get-CandidateFiles)

    foreach ($File in $CandidateFiles) {
        $RelativePath = Get-RelativeProjectPath $File.FullName

        if ($File.Extension -ieq ".ps1") {
            Test-Utf8BomPowerShellFile -File $File
            Test-PowerShellSyntax -File $File
        }

        if (
            $File.Extension -ieq ".json" -or
            $File.Extension -ieq ".jsonc"
        ) {
            Test-Utf8JsonText -File $File
        }

        if (
            $File.Extension -ieq ".json" -and
            $RelativePath -ne ".vscode/settings.json"
        ) {
            Test-JsonFile -File $File
        }

        if ($RelativePath -match "/\.codex-plugin/plugin\.json$") {
            Test-PluginManifest -File $File
        }

        if ($RelativePath -eq ".agents/plugins/marketplace.json") {
            Test-MarketplaceManifest -File $File
        }

        if ($File.Name -eq "SKILL.md") {
            Test-SkillFolder -File $File
        }
    }

    $TrackedSensitive = @(
        & git -C $ProjectPath -c core.safecrlf=false `
            ls-files -- ".env" ".env.*" "auth.json" 2>$null
    )

    $Checks++

    if ($TrackedSensitive.Count -gt 0) {
        Add-ValidationError "Git 中存在敏感配置文件名，请移除后重新检查。"
    }

    $PrivateKeyMatches = @(
        & git -C $ProjectPath -c core.safecrlf=false `
            grep -n -I -E -e `
            "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}" `
            -- . 2>$null
    )

    $Checks++

    if ($PrivateKeyMatches.Count -gt 0) {
        Add-ValidationError "检测到疑似私钥或长期访问密钥格式。"
    }

    if (-not $Quiet) {
        Write-Host "Codex Design 仓库验证"
        Write-Host "检查项：$Checks"
        Write-Host "错误：$($Errors.Count)"
        Write-Host "警告：$($Warnings.Count)"

        foreach ($Warning in $Warnings) {
            Write-Host "警告：$Warning" -ForegroundColor Yellow
        }
    }

    foreach ($ValidationError in $Errors) {
        Write-Host "错误：$ValidationError" -ForegroundColor Red
    }

    if ($Errors.Count -gt 0) {
        exit 1
    }

    if (-not $Quiet) {
        Write-Host "验证通过。" -ForegroundColor Green
    }
}
catch {
    Write-Host "验证器异常：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (-not $NoPause -and -not $Quiet) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
