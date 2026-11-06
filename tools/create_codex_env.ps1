# ==================================================
# Codex Local Proxy Environment Generator V1.1.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==================================================

param(
    [string]$OutputPath = (Join-Path `
        ([Environment]::GetFolderPath("UserProfile")) `
        ".codex\.env"),
    [string]$ProxyUri = "",
    [switch]$Force, # 兼容旧快捷方式；不再跳过预览、确认或备份。
    [switch]$Preview,
    [switch]$Apply, # 仅供已获得明确授权的自动化调用。
    [switch]$Restore,
    [string]$RestoreBackupPath = "",
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProxyGuardPath = Join-Path $PSScriptRoot "lib\github_proxy_guard.ps1"
$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path


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


function Get-ProcessProxyValues {
    $Values = New-Object "System.Collections.Generic.List[string]"

    foreach ($VariableName in @(
        "HTTPS_PROXY",
        "HTTP_PROXY",
        "https_proxy",
        "http_proxy"
    )) {
        try {
            $Value = [Environment]::GetEnvironmentVariable(
                $VariableName,
                [System.EnvironmentVariableTarget]::Process
            )

            if (-not [string]::IsNullOrWhiteSpace([string]$Value)) {
                [void]$Values.Add([string]$Value)
            }
        }
        catch {
            # 继续检查下一个进程环境变量。
        }
    }

    return @($Values)
}


function Get-GitProxyValues {
    $Values = New-Object "System.Collections.Generic.List[string]"
    $GitCommand = Get-Command "git.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $GitCommand) {
        return @($Values)
    }

    $UrlMatchOutput = @(
        & $GitCommand.Source `
            -C $RepositoryRoot `
            config --get-urlmatch http.proxy https://github.com 2>$null
    )

    if ($LASTEXITCODE -eq 0 -and $UrlMatchOutput.Count -gt 0) {
        [void]$Values.Add(([string]$UrlMatchOutput[0]).Trim())
    }

    foreach ($GitProxyKey in @("https.proxy", "http.proxy")) {
        $GitProxyOutput = @(
            & $GitCommand.Source `
                -C $RepositoryRoot `
                config --get $GitProxyKey 2>$null
        )

        if ($LASTEXITCODE -eq 0 -and $GitProxyOutput.Count -gt 0) {
            [void]$Values.Add(([string]$GitProxyOutput[0]).Trim())
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

    foreach ($Value in @(Get-ProcessProxyValues)) {
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "当前进程环境变量"
            Value  = $Value
        })
    }

    foreach ($Value in @(Get-PersistentProxyValues)) {
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "持久化环境变量"
            Value  = $Value
        })
    }

    foreach ($Value in @(Get-GitProxyValues)) {
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "当前 Git 配置（只读）"
            Value  = $Value
        })
    }

    # 只枚举已知代理程序的真实监听端口，不猜测常见端口。
    $ProxyProcesses = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match "^(clash.*|mihomo.*|v2ray.*|xray.*|sing-box|starsky.*|trojan.*|winxray)$" })
    $Listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Where-Object { $_.OwningProcess -in $ProxyProcesses.Id })
    foreach ($Listener in $Listeners) {
        if ($Listener.LocalAddress -notin @("127.0.0.1", "0.0.0.0", "::1", "::")) { continue }
        $Address = if ($Listener.LocalAddress -match ":") { "[::1]" } else { "127.0.0.1" }
        [void]$Candidates.Add([PSCustomObject]@{
            Source = "运行中的代理程序监听端口"
            Value = "http://$($Address):$($Listener.LocalPort)"
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($ProxyUri)) {
        # 显式指定的地址失败时不静默换用其他代理。
        $Candidates = @($Candidates[0])
    }
    $Seen = New-Object "System.Collections.Generic.HashSet[string]"

    foreach ($Candidate in $Candidates) {
        $Endpoint = ConvertTo-ProxyEndpoint -ProxyValue $Candidate.Value

        if ($null -eq $Endpoint) {
            continue
        }

        if (-not $Seen.Add($Endpoint.Uri)) { continue }
        $ParsedUri = New-Object System.Uri -ArgumentList $Endpoint.Uri

        if (
            $ParsedUri.Scheme -ne "http" -or
            -not $ParsedUri.IsLoopback -or
            -not [string]::IsNullOrEmpty($ParsedUri.UserInfo) -or
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

        $BoundListeners = @(Get-NetTCPConnection -State Listen -LocalPort $Endpoint.Port -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalAddress -in @("127.0.0.1", "0.0.0.0", "::1", "::") })
        if ($BoundListeners.Count -eq 0) { continue }
        $OwnerIds = @($BoundListeners | Select-Object -ExpandProperty OwningProcess -Unique)
        $Owners = @(Get-Process -Id $OwnerIds -ErrorAction SilentlyContinue |
            ForEach-Object { "$($_.ProcessName) (PID $($_.Id))" })
        Write-Host "检测来源：$($Candidate.Source)；监听端口：$($Endpoint.Port)；进程：$($Owners -join ', ')"
        if (-not (Test-HttpsProxy -Uri $Builder.Uri.AbsoluteUri.TrimEnd("/"))) {
            if ($Candidate.Source -ne "运行中的代理程序监听端口") {
                throw "当前配置代理的 HTTPS 检测失败；未改用其他代理或直连。请检查代理节点后重试。"
            }
            continue
        }

        return [PSCustomObject]@{
            Source = $Candidate.Source
            Uri    = $Builder.Uri.AbsoluteUri.TrimEnd("/")
            Host   = $Endpoint.Host
            Port   = $Endpoint.Port
        }
    }

    return $null
}


function Test-HttpsProxy {
    param([string]$Uri)
    $Curl = Get-Command "curl.exe" -ErrorAction Stop | Select-Object -First 1
    foreach ($Target in @("https://chatgpt.com/", "https://api.openai.com/v1/models")) {
        # -q 禁用用户 curl 配置；明确指定代理与绕过名单；不发送密钥、不忽略证书。
        $Result = @(& $Curl.Source -q --proxy $Uri --noproxy "localhost,127.0.0.1,::1" `
            --connect-timeout 5 --max-time 12 --silent --head --output NUL `
            --write-out "%{http_connect}|%{http_code}|%{ssl_verify_result}" --url $Target)
        $ExitCode = $LASTEXITCODE
        $Summary = ($Result -join "").Trim()
        Write-Host "HTTPS 检测：$Target；CONNECT|HTTP|TLS=$Summary；退出码=$ExitCode"
        if ($ExitCode -ne 0 -or $Summary -notmatch '^200\|([234][0-9]{2})\|0$') { return $false }
        $Status = [int]$Matches[1]
        if ($Status -ge 300 -and $Status -ne 401) {
            Write-Host "站点未返回可接受结果；403、429 等响应不算 Codex 可用。" -ForegroundColor Yellow
            return $false
        }
    }
    Write-Host "代理隧道和 TLS 检测通过；未验证登录态或长时间流式连接。" -ForegroundColor Green
    return $true
}


function Get-UpdatedEnvironmentText {
    param([string]$Original, [string]$Uri)
    $Bypass = New-Object "System.Collections.Generic.List[string]"
    foreach ($Value in @("localhost", "127.0.0.1", "::1")) { [void]$Bypass.Add($Value) }
    # 合并已有绕过名单，避免破坏本地 MCP 或用户自己的内网规则。
    foreach ($Line in ($Original -split '\r?\n')) {
        if ($Line -match '^\s*(?:export\s+)?NO_PROXY\s*=\s*(.*)$') {
            $Value = $Matches[1].Trim()
            if ($Value -match '^(["''])(.*?)\1\s*(?:#.*)?$') { $Value = $Matches[2] }
            else { $Value = ($Value -replace '\s+#.*$', '').Trim() }
            foreach ($Part in ($Value -split ',')) {
                $Part = $Part.Trim()
                if ($Part -and $Part -notin $Bypass) { [void]$Bypass.Add($Part) }
            }
        }
    }
    $Values = @{
        HTTP_PROXY = $Uri
        HTTPS_PROXY = $Uri
        NO_PROXY = ($Bypass -join ',')
    }
    $Seen = @{}
    $Lines = New-Object "System.Collections.Generic.List[string]"
    $NewLine = if ($Original.Contains("`r`n")) { "`r`n" } else { "`n" }
    $InputLines = @($Original -split '\r?\n')
    for ($Index = 0; $Index -lt $InputLines.Count; $Index++) {
        $Line = $InputLines[$Index]
        if ($Index -eq ($InputLines.Count - 1) -and $Line -eq '') { continue }
        if ($Line -match '^\s*(?:export\s+)?(HTTP_PROXY|HTTPS_PROXY|NO_PROXY)\s*=') {
            $Key = $Matches[1].ToUpperInvariant()
            if (-not $Seen.ContainsKey($Key)) { [void]$Lines.Add("$Key=$($Values[$Key])") }
            $Seen[$Key] = $true
        }
        else { [void]$Lines.Add($Line) }
    }
    foreach ($Key in @("HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY")) {
        if (-not $Seen.ContainsKey($Key)) { [void]$Lines.Add("$Key=$($Values[$Key])") }
    }
    return ($Lines -join $NewLine) + $NewLine
}


function Show-ProxyPreview {
    param([string]$Text)
    foreach ($Line in ($Text -split '\r?\n')) {
        if ($Line -match '^\s*(?:export\s+)?(HTTP_PROXY|HTTPS_PROXY|NO_PROXY|ALL_PROXY)\s*=') {
            Write-Host ($Line -replace '(?<=://)[^/@]+@', '[凭据已隐藏]@')
        }
    }
}


function Save-EnvironmentBytes {
    param([string]$Path, [byte[]]$Bytes, [bool]$Existed, [byte[]]$OriginalBytes)
    $NowExists = Test-Path -LiteralPath $Path -PathType Leaf
    if ($NowExists -ne $Existed -or ($NowExists -and
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) -cne [Convert]::ToBase64String($OriginalBytes))) {
        throw "预览后目标文件发生变化，已停止；请重新预览。"
    }
    $Directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $Directory -Force)
    }
    $TempPath = $Path + ".tmp." + [Guid]::NewGuid().ToString("N")
    [IO.File]::WriteAllBytes($TempPath, $Bytes)
    try {
        if ($Existed) {
            $Stamp = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, "China Standard Time").ToString("yyyyMMdd-HHmmss-fff")
            $Backup = $Path + ".bak." + $Stamp + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
            # 同目录原子替换，同时保留被替换文件；失败不退回直接覆盖。
            [IO.File]::Replace($TempPath, $Path, $Backup)
            Write-Host "原文件备份：$Backup"
        }
        else { [IO.File]::Move($TempPath, $Path) }
    }
    finally {
        if (Test-Path -LiteralPath $TempPath -PathType Leaf) { Remove-Item -LiteralPath $TempPath }
    }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) -cne [Convert]::ToBase64String($Bytes)) {
        throw "写入后字节校验失败，请使用已报告的备份恢复。"
    }
}


try {
    if (-not (Test-Path -LiteralPath $ProxyGuardPath -PathType Leaf)) {
        throw "缺少代理检测组件：tools\lib\github_proxy_guard.ps1"
    }

    if ($Apply -and $Preview) { throw "-Apply 与 -Preview 不能同时使用。" }
    . $ProxyGuardPath
    $ResolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $Existed = Test-Path -LiteralPath $ResolvedOutputPath -PathType Leaf
    $OriginalBytes = [byte[]]@()
    $Original = ""
    $Utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    if ($Existed) {
        $OriginalBytes = [IO.File]::ReadAllBytes($ResolvedOutputPath)
        $Original = $Utf8.GetString($OriginalBytes).TrimStart([char]0xFEFF)
    }
    if ($Restore -or $RestoreBackupPath) {
        $Directory = Split-Path -Parent $ResolvedOutputPath
        $Prefix = [IO.Path]::GetFileName($ResolvedOutputPath) + ".bak."
        $Backups = @(Get-ChildItem -LiteralPath $Directory -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase) } |
            Sort-Object Name -Descending)
        if (-not $RestoreBackupPath) {
            if ($Backups.Count -eq 0) { throw "没有找到此环境文件的备份。" }
            for ($Index = 0; $Index -lt $Backups.Count; $Index++) { Write-Host "$($Index + 1). $($Backups[$Index].Name)" }
            if ($NoPause -or $Preview) { Write-Host "仅列出备份；未恢复。自动化恢复需指定 -RestoreBackupPath。"; exit 0 }
            $Choice = Read-Host "输入要恢复的备份序号（其他输入取消）"
            $Number = 0
            if (-not [int]::TryParse($Choice, [ref]$Number) -or $Number -lt 1 -or $Number -gt $Backups.Count) {
                Write-Host "已取消，文件未修改。"; exit 0
            }
            $RestoreBackupPath = $Backups[$Number - 1].FullName
        }
        $BackupPath = [IO.Path]::GetFullPath($RestoreBackupPath)
        if ($BackupPath -notin @($Backups.FullName)) { throw "只能恢复目标文件同目录下的 .bak. 备份。" }
        $NewBytes = [IO.File]::ReadAllBytes($BackupPath)
        $NewText = $Utf8.GetString($NewBytes).TrimStart([char]0xFEFF)
        Write-Host "准备从 $BackupPath 恢复整个 .env（包括其他配置）；当前文件也会先备份。" -ForegroundColor Yellow
    }
    else {
        $ResolvedProxy = Resolve-CurrentHttpProxy
        if ($null -eq $ResolvedProxy) { throw "未检测到可用的本机 HTTP 代理；请先启动代理软件并启用 HTTP 或混合端口。" }
        $NewText = Get-UpdatedEnvironmentText -Original $Original -Uri $ResolvedProxy.Uri
        $NewBytes = $Utf8.GetBytes($NewText)
        Write-Host "仅更新 HTTP_PROXY、HTTPS_PROXY、NO_PROXY，保留其他配置。"
        if ($Original -match '(?im)^\s*(?:export\s+)?(ALL_PROXY|NO_PR0xY)\s*=') {
            Write-Host "发现 ALL_PROXY 或拼写为 NO_PR0xY 的旧变量，本工具保留原值；请单独检查其是否冲突。" -ForegroundColor Yellow
        }
    }
    Write-Host "目标文件：$ResolvedOutputPath"
    Write-Host "原代理内容："; Show-ProxyPreview -Text $Original
    Write-Host "拟写入代理内容："; Show-ProxyPreview -Text $NewText
    if ([Convert]::ToBase64String($OriginalBytes) -ceq [Convert]::ToBase64String($NewBytes)) {
        Write-Host "内容相同，无需写入或新增备份。" -ForegroundColor Green; exit 0
    }
    if ($Preview -or ($NoPause -and -not $Apply)) {
        Write-Host "仅预览，未写入。请双击「Codex 代理环境配置」确认更新；-Force 不代表授权。" -ForegroundColor Yellow
        exit 0
    }
    if (-not $Apply -and (Read-Host "输入“确认”后写入，其他输入取消") -cne "确认") {
        Write-Host "已取消，文件未修改。"; exit 0
    }
    Save-EnvironmentBytes -Path $ResolvedOutputPath -Bytes $NewBytes -Existed $Existed -OriginalBytes $OriginalBytes
    Write-Host "Codex 本地代理环境已更新，写入校验通过。" -ForegroundColor Green
    Write-Host "保存工作后完全退出并重开 VS Code / Codex，再测试连续对话。"
    Write-Host "需要回退时，双击「Codex 代理环境恢复」，选择本次备份并确认。"
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
