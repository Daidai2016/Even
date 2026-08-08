# Validate promoted Codex Design creative artifacts.

param(
    [Parameter(Mandatory = $true)]
    [string]$ExperimentPath,

    [string]$PromptPath = "",

    [string]$WorkflowPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectPath = @(& git.exe rev-parse --show-toplevel 2>$null) |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace([string]$ProjectPath)) {
    throw "无法解析 Codex Design 仓库根目录。"
}

$ProjectPath = ([string]$ProjectPath).Trim()
$Required = @(
    [PSCustomObject]@{
        Label = "实验记录"
        Path = $ExperimentPath
        Prefix = "experiments/"
        Headings = @("目标", "输入", "输出", "评价", "失败")
    }
)

if (
    [string]::IsNullOrWhiteSpace($PromptPath) -and
    [string]::IsNullOrWhiteSpace($WorkflowPath)
) {
    throw "至少提供一个待晋级的提示词或工作流文件。"
}

if (-not [string]::IsNullOrWhiteSpace($PromptPath)) {
    $Required += [PSCustomObject]@{
        Label = "提示词规范"
        Path = $PromptPath
        Prefix = "prompts/"
        Headings = @("用途", "输入", "提示词", "边界", "验证")
    }
}

if (-not [string]::IsNullOrWhiteSpace($WorkflowPath)) {
    $Required += [PSCustomObject]@{
        Label = "正式工作流"
        Path = $WorkflowPath
        Prefix = "workflows/"
        Headings = @("目标", "输入", "步骤", "验收", "失败处理")
    }
}

foreach ($Item in $Required) {
    $FullPath = [System.IO.Path]::GetFullPath(
        (Join-Path $ProjectPath $Item.Path)
    )
    $Relative = $FullPath.Substring($ProjectPath.Length + 1).Replace("\", "/")

    if (-not $Relative.StartsWith(
        $Item.Prefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "$($Item.Label)必须位于 $($Item.Prefix) 下。"
    }

    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
        throw "$($Item.Label)不存在。"
    }

    $Text = Get-Content -LiteralPath $FullPath -Raw -Encoding UTF8

    foreach ($Heading in $Item.Headings) {
        if ($Text -notmatch ("(?m)^#{1,4}\s+.*" + [regex]::Escape($Heading))) {
            throw "$($Item.Label)缺少标题：${Heading}"
        }
    }
}

Write-Host "创意能力晋级结构验证通过。" -ForegroundColor Green
