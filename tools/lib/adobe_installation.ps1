# Shared Adobe installation discovery. Windows PowerShell 5.1.
function Get-AdobeInstallation {
    param(
        [ValidateSet("Photoshop", "Illustrator")]
        [string]$Product,
        [string[]]$AdobeRoots = @()
    )

    if ($AdobeRoots.Count -eq 0) {
        $AdobeRoots = @(
            @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique |
                ForEach-Object { Join-Path $_ "Adobe" }
        )
    }

    $Result = [pscustomobject]@{ Path = ""; ScriptsPath = ""; PluginsPath = "" }
    $Candidates = @(
        foreach ($AdobeRoot in $AdobeRoots) {
            if (-not (Test-Path -LiteralPath $AdobeRoot -PathType Container)) { continue }
            Get-ChildItem -LiteralPath $AdobeRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^Adobe $Product (\d{4}|\(Beta\))$" }
        }
    )
    # Prefer the newest usable release; retain Beta as a fallback.
    $Candidates = @($Candidates | Sort-Object -Property @{
        Expression = { if ($_.Name -match "(\d{4})$") { [int]$Matches[1] } else { 0 } }
        Descending = $true
    }, FullName)

    $Executable = if ($Product -eq "Photoshop") { "Photoshop.exe" } else {
        "Support Files\Contents\Windows\Illustrator.exe"
    }
    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath (Join-Path $Candidate.FullName $Executable) -PathType Leaf) {
            $Result.Path = $Candidate.FullName
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($Result.Path)) { return $Result }

    $ScriptFolders = if ($Product -eq "Photoshop") {
        @("Presets\Scripts", "Presets\zh_CN\Scripts", "Presets\zh_CN\脚本")
    } else {
        @("Presets\zh_CN\脚本", "Presets\zh_CN\Scripts", "Presets\en_US\Scripts", "Presets\Scripts")
    }
    foreach ($Folder in $ScriptFolders) {
        $Path = Join-Path $Result.Path $Folder
        if (Test-Path -LiteralPath $Path -PathType Container) {
            $Result.ScriptsPath = $Path
            break
        }
    }
    foreach ($Folder in @("Plug-ins", "增效工具")) {
        $Path = Join-Path $Result.Path $Folder
        if (Test-Path -LiteralPath $Path -PathType Container) {
            $Result.PluginsPath = $Path
            break
        }
    }
    return $Result
}
