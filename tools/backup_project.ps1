# ==========================================
# Codex Design Project Backup V2.0.0
# Windows PowerShell 5.1 / UTF-8 with BOM
# ==========================================

param(
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$BackupRoot = Join-Path $DesktopPath "Codex_Backup"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TargetPath = Join-Path $BackupRoot "Codex_Design_$Timestamp"

function Stop-Backup {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red

    if (-not $NoPause) {
        Write-Host ""
        [void](Read-Host "按 Enter 键关闭窗口")
    }

    exit 1
}

try {
    Write-Host ""
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host " Codex Design 安全备份 V2.0.0" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
        Stop-Backup -Message "无法解析 Windows 桌面目录。"
    }

    $ResolvedProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
    $ResolvedTargetPath = [System.IO.Path]::GetFullPath($TargetPath)

    if ($ResolvedTargetPath.StartsWith(
        $ResolvedProjectPath.TrimEnd("\") + "\",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Backup -Message "拒绝在项目目录内部创建备份。"
    }

    New-Item -ItemType Directory -Path $ResolvedTargetPath -Force |
        Out-Null

    $ExcludedDirectories = @(
        (Join-Path $ResolvedProjectPath ".git"),
        (Join-Path $ResolvedProjectPath "logs"),
        (Join-Path $ResolvedProjectPath "work")
    )

    $RobocopyArguments = @(
        $ResolvedProjectPath,
        $ResolvedTargetPath,
        "/E",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/R:1",
        "/W:1",
        "/XJ",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP",
        "/XD"
    ) + $ExcludedDirectories + @(
        "/XF",
        ".env",
        ".env.*",
        "*.log",
        "*.tmp",
        "*.bak",
        "Thumbs.db",
        ".DS_Store"
    )

    & robocopy.exe @RobocopyArguments | Out-Null
    $RobocopyExitCode = $LASTEXITCODE

    if ($RobocopyExitCode -gt 7) {
        Stop-Backup -Message `
            "备份复制失败，Robocopy 错误代码：$RobocopyExitCode"
    }

    $ManifestPath = Join-Path $ResolvedTargetPath "BACKUP_MANIFEST.txt"
    $Manifest = New-Object "System.Collections.Generic.List[string]"
    [void]$Manifest.Add("Codex Design Backup Manifest V2.0.0")
    [void]$Manifest.Add("Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$Manifest.Add("Excluded: .git, logs, work, .env*, *.log, *.tmp, *.bak")
    [void]$Manifest.Add("")

    $BackupFiles = @(
        Get-ChildItem -LiteralPath $ResolvedTargetPath -Recurse -File |
            Where-Object { $_.FullName -ne $ManifestPath } |
            Sort-Object FullName
    )

    foreach ($File in $BackupFiles) {
        $RelativePath = $File.FullName.Substring(
            $ResolvedTargetPath.TrimEnd("\").Length + 1
        )

        $Hash = Get-FileHash `
            -LiteralPath $File.FullName `
            -Algorithm SHA256

        [void]$Manifest.Add("$($Hash.Hash)  $RelativePath")
    }

    $Manifest |
        Set-Content -LiteralPath $ManifestPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        Stop-Backup -Message "备份清单生成失败。"
    }

    Write-Host "备份完成。" -ForegroundColor Green
    Write-Host "文件数量：$($BackupFiles.Count)"
    Write-Host "校验清单：BACKUP_MANIFEST.txt"
    Write-Host "安全排除：凭据文件、日志、工作目录和 Git 内部数据。"
}
catch {
    Stop-Backup -Message "备份工具发生异常：$($_.Exception.Message)"
}

if (-not $NoPause) {
    Write-Host ""
    [void](Read-Host "按 Enter 键关闭窗口")
}
