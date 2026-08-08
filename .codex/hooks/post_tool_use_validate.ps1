# Codex Design PostToolUse Validator V1.0.0

$ErrorActionPreference = "Stop"

try {
    $InputText = [Console]::In.ReadToEnd()

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        exit 0
    }

    $HookInput = $InputText | ConvertFrom-Json

    if ([string]$HookInput.tool_name -notmatch '^(Bash|shell_command|ApplyPatch|apply_patch)$') {
        exit 0
    }

    $ProjectPath = @(
        & git.exe rev-parse --show-toplevel 2>$null
    ) | Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace([string]$ProjectPath)) {
        exit 0
    }

    $ValidatorPath = Join-Path `
        ([string]$ProjectPath).Trim() `
        "tools\validate_repository.ps1"

    if (-not (Test-Path -LiteralPath $ValidatorPath -PathType Leaf)) {
        exit 0
    }

    $ValidationOutput = @(
        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $ValidatorPath `
            -ChangedOnly `
            -Quiet `
            -NoPause 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        $Summary = (($ValidationOutput | Select-Object -First 8) -join " ").Trim()

        if ($Summary.Length -gt 800) {
            $Summary = $Summary.Substring(0, 800)
        }

        $Response = [ordered]@{
            decision = "block"
            reason = "仓库变更后验证失败，请先修复。"
            hookSpecificOutput = [ordered]@{
                hookEventName = "PostToolUse"
                additionalContext = $Summary
            }
        }

        $Response | ConvertTo-Json -Depth 5 -Compress
    }
}
catch {
    $Response = [ordered]@{
        decision = "block"
        reason = "仓库变更后验证器发生异常，请人工检查。"
    }

    $Response | ConvertTo-Json -Compress
}
