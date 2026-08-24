# ==================================================
# Codex Local Proxy Environment Generator V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==================================================

param(
    [string]$OutputPath = (Join-Path `
        ([Environment]::GetFolderPath("UserProfile")) `
        ".codex\.env"),
    [string]$ProxyUri = "",
    [switch]$Force,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProxyGuardPath = Join-Path $PSScriptRoot "lib\github_proxy_guard.ps1"


function Get-PersistentProxyValues {
    $Values = New-Object "System.Collections.Generic.List[string]"

    foreach ($VariableName in @(
        "HTTPS_PROXY",
        "HTTP_PROXY",
        "https_proxy",
        "http_proxy"
    )) {
        foreach ($Target in @(
            [System.EnvironmentVariableTarget]::User,
            [System.EnvironmentVariableTarget]::Machine
        )) {
            try {
                $Value = [Environment]::GetEnvironmentVariable(
                    $VariableName,
                    $Target
                )

                if (-not [string]::IsNullOrWhiteSpace([string]$Value)) {
                    [void]$Values.Add([string]$Value)
                }
            }
            catch {
                # 继续检查下一个持久化环境变量。
            }
        }
    }

    return @($Values)
}


function Resolve-CurrentHttpProxy {
    $Candidates = New-Object "System.Collections.Generic.List[object]"

    if (-not [string]::IsNullOrWhiteSpace($ProxyUri)) {
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "命令行参数"
            Value  = $ProxyUri
        })
    }

    $WindowsProxy = Get-WindowsProxyValue

    if (-not [string]::IsNullOrWhiteSpace($WindowsProxy)) {
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "Windows 系统代理"
            Value  = $WindowsProxy
        })
    }

    foreach ($Value in @(Get-PersistentProxyValues)) {
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "持久化环境变量"
            Value  = $Value
        })
    }

    foreach ($Candidate in $Candidates) {
        $Endpoint = ConvertTo-ProxyEndpoint -ProxyValue $Candidate.Value

        if ($null -eq $Endpoint) {
            continue
        }

        $ParsedUri = New-Object System.Uri -ArgumentList $Endpoint.Uri

        if (
            $ParsedUri.Scheme -ne "http" -or
            -not (Test-ProxyEndpointReachable `
                -HostName $Endpoint.Host `
                -Port $Endpoint.Port
            )
        ) {
            continue
        }

        $Builder = New-Object System.UriBuilder -ArgumentList $ParsedUri
        $Builder.Path = ""
        $Builder.Query = ""
        $Builder.Fragment = ""

        return [PSCustomObject]@{
            Source = $Candidate.Source
            Uri    = $Builder.Uri.AbsoluteUri.TrimEnd("/")
            Host   = $Endpoint.Host
            Port   = $Endpoint.Port
        }
    }

    return $null
}


try {
    if (-not (Test-Path -LiteralPath $ProxyGuardPath -PathType Leaf)) {
        throw "缺少代理检测组件：tools\lib\github_proxy_guard.ps1"
    }

    . $ProxyGuardPath
    $ResolvedProxy = Resolve-CurrentHttpProxy

    if ($null -eq $ResolvedProxy) {
        throw (
            "未检测到端口可达的 HTTP 代理。请先启用本机代理，" +
            "或使用 -ProxyUri 指定当前电脑的 HTTP 代理。"
        )
    }

    $ResolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)

    if (
        (Test-Path -LiteralPath $ResolvedOutputPath -PathType Leaf) -and
        -not $Force
    ) {
        throw "目标文件已存在；如需更新，请添加 -Force。"
    }

    $OutputDirectory = Split-Path -Parent $ResolvedOutputPath

    if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        [void](New-Item `
            -ItemType Directory `
            -Path $OutputDirectory `
            -Force
        )
    }

    $Lines = @(
        "HTTP_PROXY=$($ResolvedProxy.Uri)",
        "HTTPS_PROXY=$($ResolvedProxy.Uri)"
    )
    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines(
        $ResolvedOutputPath,
        $Lines,
        $Utf8WithoutBom
    )

    Write-Host "Codex 本地代理环境文件已生成。" -ForegroundColor Green
    Write-Host "代理来源：$($ResolvedProxy.Source)"
    Write-Host "代理端点：$($ResolvedProxy.Host):$($ResolvedProxy.Port)"
    Write-Host "输出文件：$ResolvedOutputPath"
    Write-Host "未访问 GitHub，未修改系统或 Git 代理配置。" `
        -ForegroundColor DarkGray
    exit 0
}
catch {
    Write-Host "生成 Codex 本地代理环境文件失败：$($_.Exception.Message)" `
        -ForegroundColor Red
    exit 1
}
finally {
    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }
}
