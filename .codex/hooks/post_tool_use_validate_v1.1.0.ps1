# Codex Design PostToolUse Validator V1.1.0
# Advisory deduplication only; final validation remains required.
$ErrorActionPreference = "Stop"

function Write-ValidationNotice {
    param([string]$Message)
    [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName = "PostToolUse"
            additionalContext = $Message
        }
    } | ConvertTo-Json -Depth 4 -Compress
}

function Get-TextDigest {
    param([string]$Text)
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($Hasher.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($Text)))).Replace("-", "")
    }
    finally { $Hasher.Dispose() }
}

try {
    $InputText = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($InputText)) { exit 0 }
    $HookInput = $InputText | ConvertFrom-Json
    if ([string]$HookInput.tool_name -notmatch '^(Bash|shell_command|ApplyPatch|apply_patch)$') { exit 0 }

    $ProjectPath = [string](@(& git.exe rev-parse --show-toplevel 2>$null) | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ProjectPath)) { exit 0 }
    $ProjectPath = $ProjectPath.Trim()
    $ValidatorPath = Join-Path $ProjectPath "tools\validate_repository.ps1"
    if (-not (Test-Path -LiteralPath $ValidatorPath -PathType Leaf)) {
        throw "Missing repository validator"
    }

    $Paths = @(
        foreach ($GitArgs in @(
            @("diff", "--name-only", "--diff-filter=ACMRD"),
            @("diff", "--cached", "--name-only", "--diff-filter=ACMRD"),
            @("ls-files", "--others", "--exclude-standard")
        )) {
            & git.exe -C $ProjectPath -c core.quotepath=false @GitArgs
            if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate changed files" }
        }
    ) | Sort-Object -Unique
    $Paths = @($Paths | Where-Object {
        $_ -match '\.(ps1|psm1|psd1|json|jsonc|md|yaml|yml|py)$' -and
        $_ -notmatch '^(work|logs)/' -and
        $_ -notmatch '(^|/)(\.env[^/]*|auth\.json|\.codex-global-state\.json|\.sandbox-secrets)$'
    })
    if ($Paths.Count -eq 0) { exit 0 }

    # Hash only candidate source/config files, never tool input or session transcripts.
    $Entries = @(
        (Get-FileHash -LiteralPath $ValidatorPath -Algorithm SHA256).Hash
        foreach ($RelativePath in $Paths) {
            $FullPath = Join-Path $ProjectPath $RelativePath
            if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
                $Item = Get-Item -LiteralPath $FullPath
                if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked candidate requires manual validation" }
                "$RelativePath|$((Get-FileHash -LiteralPath $FullPath -Algorithm SHA256).Hash)"
            }
            else { "$RelativePath|deleted" }
        }
    )
    $Fingerprint = Get-TextDigest ($Entries -join "`n")
    $SessionKey = Get-TextDigest ([string]$HookInput.session_id)
    $CacheDirectory = Join-Path $ProjectPath "work\hook-validation"
    $CachePath = Join-Path $CacheDirectory "$SessionKey.txt"
    if ((Test-Path -LiteralPath $CachePath -PathType Leaf) -and
        (Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8).Trim() -eq $Fingerprint) { exit 0 }

    # First observation of a dirty worktree validates once, including after a read-only call.
    # A cache hit is not evidence that validation passed, and never replaces final checks.
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $ValidationOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidatorPath -ChangedOnly -Quiet -NoPause 2>&1)
        $ValidationExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $PreviousPreference }
    if ($null -eq $ValidationExitCode) { throw "Validator did not return an exit code" }
    [void][IO.Directory]::CreateDirectory($CacheDirectory)
    [IO.File]::WriteAllText($CachePath, $Fingerprint, (New-Object Text.UTF8Encoding($false)))

    if ($ValidationExitCode -ne 0) {
        $Summary = (($ValidationOutput | Select-Object -First 8) -join " ").Trim()
        if ($Summary.Length -gt 800) { $Summary = $Summary.Substring(0, 800) }
        Write-ValidationNotice "仓库验证发现问题（可能包含既存问题）：$Summary。请结合本次差异判断，仅修复本次引入或阻断交付的问题；无关问题报告即可。当前结果不代表验收通过。"
    }
}
catch {
    Write-ValidationNotice "变更后自动验证未完成；请在交付前使用 -ChangedOnly -NoPause 显式运行仓库验证。不要因 Hook 异常扩大修复范围。"
}
