#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectName = "skeleton"
$source = "$repoRoot\$projectName"
$csproj = "$source\$projectName.csproj"
$coreCsproj = "$repoRoot\skeleton.Core\skeleton.Core.csproj"
$dotnetFramework = 'net10.0'
$versionFolder = "$repoRoot\.version"
$version = "$versionFolder\version"; $versionContents = ([IO.File]::ReadAllText($version)).Trim()
$versionBuild = "$versionFolder\versionBuild"
$versionTag = "$versionFolder\versionTag"
$versionTagContents = if (Test-Path -LiteralPath $versionTag) { ([IO.File]::ReadAllText($versionTag)).Trim() } else { '' }
$readme = "$repoRoot\README.md"
$readmeContents = Get-Content -LiteralPath $readme -Raw
$installerFolder = "$repoRoot\.installer"
$installerOutput = "$installerFolder\Output"
$ISCC = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'; if (-not (Test-Path -LiteralPath $ISCC)) { throw "Inno Setup compiler not found: $ISCC" }
$appPublisher = "fosterbarnes"
$appURL = "https://github.com/$appPublisher/$projectName"
$copyrightHolder = 'Foster Barnes'
$appCopyright = "Copyright © $(Get-Date -Format yyyy) $copyrightHolder"
$tag = if ([string]::IsNullOrWhiteSpace($versionTagContents)) { "v$versionContents" } else { $versionTagContents }
$ghRepo = "$appPublisher/$projectName"
$appIcon = "$repoRoot\.resources\icon\$projectName.ico"
$buildNotes = "$repoRoot\.md\.buildNotes.txt"
$publishFolder = "$repoRoot\publish"
$updater = "$repoRoot\.updater"
$updaterCsproj = "$updater\updater.csproj"
$buildTargets = @(
    @{ Architecture = 'x64';   RuntimeIdentifier = 'win-x64';   BinFolder = "$publishFolder\x64";   ExePath = "$publishFolder\x64\$projectName.exe";   InstallerName = "$projectName-x64-installer.exe";   InstallerScript = "$installerFolder\$projectName.x64.installer.iss" }
    @{ Architecture = 'x86';   RuntimeIdentifier = 'win-x86';   BinFolder = "$publishFolder\x86";   ExePath = "$publishFolder\x86\$projectName.exe";   InstallerName = "$projectName-x86-installer.exe";   InstallerScript = "$installerFolder\$projectName.x86.installer.iss" }
    @{ Architecture = 'arm64'; RuntimeIdentifier = 'win-arm64'; BinFolder = "$publishFolder\arm64"; ExePath = "$publishFolder\arm64\$projectName.exe"; InstallerName = "$projectName-arm64-installer.exe"; InstallerScript = "$installerFolder\$projectName.arm64.installer.iss" }
)

# Future cross-platform publish targets (requires build on matching OS or CI):
# @{ Architecture = 'arm64'; RuntimeIdentifier = 'osx-arm64'; BinFolder = "$publishFolder\osx-arm64"; ExePath = "$publishFolder\osx-arm64\$projectName"; ... }
# @{ Architecture = 'x64';   RuntimeIdentifier = 'linux-x64'; BinFolder = "$publishFolder\linux-x64"; ExePath = "$publishFolder\linux-x64\$projectName"; ... }

function Set-VersionBuildPlatform {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [string]$LiteralPath = $versionBuild
    )
    [IO.File]::WriteAllText($LiteralPath, $Platform)
}

function Ensure-VersionBuildPlatform {
    param([string]$Architecture)

    if (Test-Path -LiteralPath $versionBuild) { return }

    $platform = if (-not [string]::IsNullOrWhiteSpace($Architecture)) {
        $Architecture
    }
    else {
        switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
            'Arm64' { 'arm64' }
            'X86'   { 'x86' }
            default { 'x64' }
        }
    }

    Set-VersionBuildPlatform $platform
}

function Get-ReleaseAssetName {
    param(
        [Parameter(Mandatory)][ValidateSet('Installer', 'Portable')][string]$Kind,
        [Parameter(Mandatory)][string]$Architecture
    )
    $ext = if ($Kind -eq 'Installer') { 'exe' } else { 'zip' }
    '{0}{1}_v{2}_{3}.{4}' -f $projectName, $Kind, $versionContents, $Architecture, $ext
}

function Resolve-BuildArchitecture {
    param([string[]]$FlagArgs)

    $hasArm = $false
    $has64Flag = $false
    $resolved = [System.Collections.Generic.List[string]]::new()

    foreach ($a in @($FlagArgs)) {
        if ([string]::IsNullOrWhiteSpace($a)) { continue }
        switch -Regex ($a.Trim()) {
            '(?i)^(--arm64|-arm64)$' { $resolved.Add('arm64'); break }
            '(?i)^(--x64|-x64)$' { $resolved.Add('x64'); break }
            '(?i)^(--x86|-x86)$' { $resolved.Add('x86'); break }
            '(?i)^(--86|-86)$' { $resolved.Add('x86'); break }
            '(?i)^(--arm|-arm)$' { $hasArm = $true; break }
            '(?i)^(--64|-64)$' { $has64Flag = $true; break }
            default { throw "Unknown build flag: $a. Use -arm64, -x64, -x86 (or -arm, -arm -64, -64, -86)." }
        }
    }

    if ($hasArm -and $has64Flag) { $resolved.Add('arm64') }
    elseif ($has64Flag) { $resolved.Add('x64') }
    elseif ($hasArm) { $resolved.Add('arm64') }

    $unique = @($resolved | Select-Object -Unique)
    if ($unique.Count -gt 1) { throw "Conflicting architecture flags: $($unique -join ', ')" }
    if ($unique.Count -eq 1) { return $unique[0] }
    return $null
}

function Select-BuildTargets {
    param([string]$Architecture)

    if ([string]::IsNullOrWhiteSpace($Architecture)) { return $buildTargets }
    $filtered = @($buildTargets | Where-Object { $_.Architecture -eq $Architecture })
    if (-not $filtered.Count) { throw "No build target for architecture: $Architecture" }
    return $filtered
}

function Sync-InstallerDefines {
    if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }

    $defines = [ordered]@{
        AppVersion   = $versionContents
        AppCopyright = $appCopyright
    }

    foreach ($target in $buildTargets) {
        $path = $target.InstallerScript
        $content = [IO.File]::ReadAllText($path)
        $original = $content
        foreach ($entry in $defines.GetEnumerator()) {
            $pattern = "#define $($entry.Key) `"[^`"]*`""
            if ($content -notmatch $pattern) { throw "$path`: missing $($entry.Key) define" }
            $defineLine = "#define $($entry.Key) `"$($entry.Value)`""
            $content = [regex]::Replace($content, $pattern, $defineLine, 1)
        }
        if ($content -ne $original) {
            [IO.File]::WriteAllText($path, $content)
            Write-Host "Updated $($target.Architecture) installer defines (AppVersion=$versionContents)"
        }
    }
}

$publishStripFiles = @(
    'Avalonia.DesignerSupport.dll'
    'Avalonia.Remote.Protocol.dll'
    'Avalonia.FreeDesktop.dll'
    'Avalonia.FreeDesktop.AtSpi.dll'
    'Avalonia.X11.dll'
    'Avalonia.Native.dll'
    'Tmds.DBus.Protocol.dll'
)

function Remove-PublishArtifacts {
    param([Parameter(Mandatory)][string]$BinFolder)

    foreach ($pdb in Get-ChildItem -LiteralPath $BinFolder -Filter '*.pdb' -File -ErrorAction SilentlyContinue) {
        Remove-Item -LiteralPath $pdb.FullName -Force
    }

    foreach ($name in $publishStripFiles) {
        $path = "$BinFolder\$name"
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }

    foreach ($name in @("$projectName.ico", "${projectName}256.png", 'VersionBuild')) {
        $path = "$BinFolder\$name"
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}
