# Codex CLI discovery and version check.
# Windows PowerShell 5.1 / UTF-8 with BOM

function Get-CodexVersionResult {
    # Application includes both standalone .exe and npm .cmd launchers.
    # Resolve the actual launcher without relying on an npm installation path.
    $Command = Get-Command "codex" -CommandType Application `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    $Result = [pscustomobject]@{
        Success = $false
        Status = "Failure"
        Value = "未安装或未加入 PATH"
        Path = ""
    }

    if ($null -eq $Command) {
        return $Result
    }

    $Result.Path = $Command.Path
    $Result.Value = "已安装，但无法读取版本"
    $PreviousPreference = $ErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false

    try {
        # PowerShell 5.1 wraps stderr warnings in ErrorRecord objects.
        # Use the exit code and version line, not stderr presence, as evidence.
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = $null
        $Output = @(& $Result.Path --version 2>&1)
        $ExitCode = $global:LASTEXITCODE
        $Version = $Output | ForEach-Object { ([string]$_).Trim() } |
            Where-Object { $_ -match "^codex-cli\s+\d+\.\d+\.\d+(?:\S*)$" } |
            Select-Object -First 1

        if ($ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($Version)) {
            $Result.Success = $true
            $Result.Status = "Success"
            $Result.Value = $Version
        }
    }
    catch {
        # Keep an installed-but-unusable launcher distinct from a missing one.
        $Result.Value = "已安装，但无法读取版本"
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    return $Result
}
