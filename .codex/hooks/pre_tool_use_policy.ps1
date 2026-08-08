# Codex Design PreToolUse Policy V1.0.0

$ErrorActionPreference = "Stop"

function Deny-ToolCall {
    param([string]$Reason)

    $Response = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName          = "PreToolUse"
            permissionDecision     = "deny"
            permissionDecisionReason = $Reason
        }
    }

    $Response | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

try {
    $InputText = [Console]::In.ReadToEnd()

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        exit 0
    }

    $HookInput = $InputText | ConvertFrom-Json
    $ToolName = [string]$HookInput.tool_name
    $Command = [string]$HookInput.tool_input.command

    if ([string]::IsNullOrWhiteSpace($Command)) {
        $Command = [string]$HookInput.tool_input.patch
    }

    if ([string]::IsNullOrWhiteSpace($Command)) {
        $Command = [string]$HookInput.tool_input.input
    }

    if ($ToolName -match '^(Bash|shell_command)$') {
        $ForbiddenPatterns = @(
            '(?i)\bgit\s+reset\s+--hard\b',
            '(?i)\bgit\s+clean\s+-[^\s]*f',
            '(?i)\bgit\s+push\b[^\r\n]*(--force|-f(?:\s|$))',
            '(?i)\bgit\s+config\b[^\r\n]*http\.sslverify\s+false',
            '(?i)\bRemove-Item\b[^\r\n]*-Recurse[^\r\n]*(?:[A-Za-z]:\\\s*$|\$env:USERPROFILE|\$HOME|~)'
        )

        foreach ($Pattern in $ForbiddenPatterns) {
            if ($Command -match $Pattern) {
                Deny-ToolCall -Reason "命令违反 Codex Design 删除、Git 历史或 TLS 安全规则。"
            }
        }

        $UsesGitHubNetwork = (
            $Command -match '(?i)\bgit(?:\.exe)?\b[^\r\n]*(fetch|pull|push|ls-remote)\b' -or
            $Command -match '(?i)\bgh(?:\.exe)?\s+'
        )

        if ($UsesGitHubNetwork) {
            $ProjectPath = @(
                & git.exe rev-parse --show-toplevel 2>$null
            ) | Select-Object -First 1

            if ([string]::IsNullOrWhiteSpace([string]$ProjectPath)) {
                Deny-ToolCall -Reason "无法解析项目根目录，GitHub 网络操作已阻止。"
            }

            $GuardPath = Join-Path `
                ([string]$ProjectPath).Trim() `
                "tools\lib\github_proxy_guard.ps1"

            if (-not (Test-Path -LiteralPath $GuardPath -PathType Leaf)) {
                Deny-ToolCall -Reason "缺少 GitHub 代理门禁，网络操作已阻止。"
            }

            . $GuardPath
            $GuardResult = Test-GitHubProxyGuard `
                -ProjectPath ([string]$ProjectPath).Trim()

            if (-not $GuardResult.Success) {
                Deny-ToolCall -Reason $GuardResult.Message
            }
        }
    }

    if ($ToolName -match '^(ApplyPatch|apply_patch)$') {
        $SensitivePathPatterns = @(
            '(?im)^\*\*\* (?:Add|Update|Delete) File:\s*(?:.*[\\/])?\.env(?:\..*)?\s*$',
            '(?im)^\*\*\* (?:Add|Update|Delete) File:\s*.*(?:auth\.json|\.sandbox-secrets)\s*$',
            '(?im)^\*\*\* (?:Add|Update|Delete) File:\s*.*\.codex-global-state\.json\s*$'
        )

        foreach ($Pattern in $SensitivePathPatterns) {
            if ($Command -match $Pattern) {
                Deny-ToolCall -Reason "禁止通过补丁写入本地凭据或 Codex 私有状态文件。"
            }
        }
    }
}
catch {
    Deny-ToolCall -Reason "安全 hook 无法完成检查，已按失败关闭策略阻止工具调用。"
}
