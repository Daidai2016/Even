# ==========================================
# Codex Design GitHub Proxy Guard V1.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
#
# 只允许 GitHub 网络操作使用当前有效代理。
# 不显示、记录或持久化代理地址与凭据。
# ==========================================

function New-ProxyGuardResult {
    param(
        [bool]$Success,
        [string]$Source,
        [string]$Message
    )

    return [PSCustomObject]@{
        Success = $Success
        Source  = $Source
        Message = $Message
    }
}


function Get-EnvironmentVariableValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    foreach ($Target in @(
        [System.EnvironmentVariableTarget]::Process,
        [System.EnvironmentVariableTarget]::User,
        [System.EnvironmentVariableTarget]::Machine
    )) {
        try {
            $Value = [Environment]::GetEnvironmentVariable(
                $Name,
                $Target
            )

            if (-not [string]::IsNullOrWhiteSpace([string]$Value)) {
                return [string]$Value
            }
        }
        catch {
            # 继续检查下一层环境变量。
        }
    }

    return ""
}


function Test-GitHubNoProxyBypass {
    $NoProxy = Get-EnvironmentVariableValue -Name "NO_PROXY"

    if ([string]::IsNullOrWhiteSpace($NoProxy)) {
        $NoProxy = Get-EnvironmentVariableValue -Name "no_proxy"
    }

    if ([string]::IsNullOrWhiteSpace($NoProxy)) {
        return $false
    }

    foreach ($Item in ($NoProxy -split ",")) {
        $Entry = $Item.Trim().ToLowerInvariant()

        if (
            $Entry -eq "*" -or
            $Entry -eq "github.com" -or
            $Entry -eq ".github.com" -or
            $Entry.EndsWith(".github.com")
        ) {
            return $true
        }
    }

    return $false
}


function ConvertTo-ProxyEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProxyValue,

        [string]$DefaultScheme = "http"
    )

    $Candidate = $ProxyValue.Trim()

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    if ($Candidate -match ";") {
        $Parts = @($Candidate -split ";")
        $Selected = $Parts |
            Where-Object { $_ -match "^\s*https=" } |
            Select-Object -First 1

        if ($null -eq $Selected) {
            $Selected = $Parts |
                Where-Object { $_ -match "^\s*http=" } |
                Select-Object -First 1
        }

        if ($null -eq $Selected) {
            $Selected = $Parts |
                Where-Object { $_ -match "^\s*socks=" } |
                Select-Object -First 1
        }

        if ($null -eq $Selected) {
            return $null
        }

        if ($Selected -match "^\s*socks=") {
            $DefaultScheme = "socks5"
        }

        $Candidate = ($Selected -replace "^\s*[^=]+=", "").Trim()
    }

    if ($Candidate -notmatch "^[A-Za-z][A-Za-z0-9+.-]*://") {
        $Candidate = "$DefaultScheme`://$Candidate"
    }

    try {
        $Uri = New-Object System.Uri -ArgumentList $Candidate
    }
    catch {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Uri.Host)) {
        return $null
    }

    $Port = $Uri.Port

    if ($Port -le 0) {
        switch ($Uri.Scheme.ToLowerInvariant()) {
            "https" { $Port = 443 }
            "socks5" { $Port = 1080 }
            "socks5h" { $Port = 1080 }
            default { $Port = 80 }
        }
    }

    return [PSCustomObject]@{
        Uri  = $Candidate
        Host = $Uri.Host
        Port = [int]$Port
    }
}


function Test-ProxyEndpointReachable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [ValidateRange(100, 10000)]
        [int]$TimeoutMilliseconds = 1200
    )

    $Client = New-Object System.Net.Sockets.TcpClient
    $AsyncResult = $null

    try {
        $AsyncResult = $Client.BeginConnect(
            $HostName,
            $Port,
            $null,
            $null
        )

        if (-not $AsyncResult.AsyncWaitHandle.WaitOne(
            $TimeoutMilliseconds,
            $false
        )) {
            return $false
        }

        $Client.EndConnect($AsyncResult)
        return $Client.Connected
    }
    catch {
        return $false
    }
    finally {
        if (
            $null -ne $AsyncResult -and
            $null -ne $AsyncResult.AsyncWaitHandle
        ) {
            $AsyncResult.AsyncWaitHandle.Close()
        }

        $Client.Close()
    }
}


function Get-WindowsProxyValue {
    try {
        $ProxyInfo = Get-ItemProperty `
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" `
            -ErrorAction Stop

        if (
            $ProxyInfo.ProxyEnable -eq 1 -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$ProxyInfo.ProxyServer
            )
        ) {
            return [string]$ProxyInfo.ProxyServer
        }
    }
    catch {
        # 未启用或无法读取系统代理。
    }

    return ""
}


function Test-GitHubRemoteUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemoteUrl
    )

    return (
        $RemoteUrl -match "(?i)(^|[@/:])github\.com([/:]|$)"
    )
}


function Test-GitHubProxyGuard {
    param(
        [string]$ProjectPath = (Get-Location).Path,

        [ValidateRange(100, 10000)]
        [int]$TimeoutMilliseconds = 1200
    )

    $GitCommand = Get-Command "git.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        $GitCommand = Get-Command "git" -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    if ($null -eq $GitCommand) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source "None" `
            -Message "未检测到 Git，禁止访问 GitHub。"
    }

    $ResolvedProjectPath = ""

    try {
        $ResolvedProjectPath = (
            Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop
        ).Path
    }
    catch {
        return New-ProxyGuardResult `
            -Success $false `
            -Source "None" `
            -Message "项目目录无效，禁止访问 GitHub。"
    }

    $RemoteOutput = @(
        & $GitCommand.Source `
            -C $ResolvedProjectPath `
            remote get-url origin 2>$null
    )

    if ($LASTEXITCODE -ne 0 -or $RemoteOutput.Count -eq 0) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source "None" `
            -Message "未找到 origin，禁止访问 GitHub。"
    }

    $RemoteUrl = ([string]$RemoteOutput[0]).Trim()

    if (-not (Test-GitHubRemoteUrl -RemoteUrl $RemoteUrl)) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source "None" `
            -Message "origin 不是 GitHub 地址，GitHub 专用工具已停止。"
    }

    if (Test-GitHubNoProxyBypass) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source "None" `
            -Message "NO_PROXY 会绕过 GitHub 代理，网络操作已停止。"
    }

    $ProxyValue = ""
    $ProxySource = ""

    $GitProxyOutput = @(
        & $GitCommand.Source `
            -C $ResolvedProjectPath `
            config --get-urlmatch http.proxy https://github.com 2>$null
    )

    if ($LASTEXITCODE -eq 0 -and $GitProxyOutput.Count -gt 0) {
        $ProxyValue = ([string]$GitProxyOutput[0]).Trim()
        $ProxySource = "Git配置"
    }

    if ([string]::IsNullOrWhiteSpace($ProxyValue)) {
        foreach ($GitProxyKey in @("https.proxy", "http.proxy")) {
            $GitProxyOutput = @(
                & $GitCommand.Source `
                    -C $ResolvedProjectPath `
                    config --get $GitProxyKey 2>$null
            )

            if ($LASTEXITCODE -eq 0 -and $GitProxyOutput.Count -gt 0) {
                $ProxyValue = ([string]$GitProxyOutput[0]).Trim()
                $ProxySource = "Git配置"
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($ProxyValue)) {
        foreach ($VariableName in @(
            "HTTPS_PROXY",
            "https_proxy",
            "HTTP_PROXY",
            "http_proxy",
            "ALL_PROXY",
            "all_proxy"
        )) {
            $ProxyValue = Get-EnvironmentVariableValue `
                -Name $VariableName

            if (-not [string]::IsNullOrWhiteSpace($ProxyValue)) {
                $ProxySource = "环境变量"
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($ProxyValue)) {
        $ProxyValue = Get-WindowsProxyValue

        if (-not [string]::IsNullOrWhiteSpace($ProxyValue)) {
            $ProxySource = "Windows系统代理"
        }
    }

    if ([string]::IsNullOrWhiteSpace($ProxyValue)) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source "None" `
            -Message "未检测到 Git、环境变量或 Windows 有效代理，禁止直连 GitHub。"
    }

    $Endpoint = ConvertTo-ProxyEndpoint -ProxyValue $ProxyValue

    if ($null -eq $Endpoint) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source $ProxySource `
            -Message "代理配置格式无法安全解析，GitHub 网络操作已停止。"
    }

    if (-not (Test-ProxyEndpointReachable `
        -HostName $Endpoint.Host `
        -Port $Endpoint.Port `
        -TimeoutMilliseconds $TimeoutMilliseconds
    )) {
        return New-ProxyGuardResult `
            -Success $false `
            -Source $ProxySource `
            -Message "已检测到代理，但代理端口不可达，GitHub 网络操作已停止。"
    }

    if ($ProxySource -eq "Windows系统代理") {
        $env:HTTPS_PROXY = $Endpoint.Uri
        $env:HTTP_PROXY = $Endpoint.Uri
    }

    $ProxyValue = $null
    $Endpoint = $null

    return New-ProxyGuardResult `
        -Success $true `
        -Source $ProxySource `
        -Message "代理已配置且端口可达。"
}


function Assert-GitHubProxy {
    param(
        [string]$ProjectPath = (Get-Location).Path,
        [switch]$Quiet
    )

    $Result = Test-GitHubProxyGuard -ProjectPath $ProjectPath

    if (-not $Quiet) {
        if ($Result.Success) {
            Write-Host "GitHub代理：已通过脱敏检查（$($Result.Source)）。" `
                -ForegroundColor Green
        }
        else {
            Write-Host "GitHub代理：$($Result.Message)" `
                -ForegroundColor Red
        }
    }

    return $Result
}
