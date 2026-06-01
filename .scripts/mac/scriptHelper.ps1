#requires -Version 7.0
$ErrorActionPreference = 'Stop'

if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
    throw 'macOS scripts must run on native macOS.'
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$projectName = "skeleton"
$source = "$repoRoot/$projectName"
$csproj = "$source/$projectName.csproj"
$dotnetFramework = 'net10.0'
$versionFolder = "$repoRoot/.version"
$version = "$versionFolder/version"; $versionContents = ([IO.File]::ReadAllText($version)).Trim()
$versionBuild = "$versionFolder/versionBuild"
$versionTag = "$versionFolder/versionTag"
$versionTagContents = if (Test-Path -LiteralPath $versionTag) { ([IO.File]::ReadAllText($versionTag)).Trim() } else { '' }
$readme = "$repoRoot/README.md"
$readmeContents = Get-Content -LiteralPath $readme -Raw
$appPublisher = "fosterbarnes"
$appURL = "https://github.com/$appPublisher/$projectName"
$tag = if ([string]::IsNullOrWhiteSpace($versionTagContents)) { "v$versionContents" } else { $versionTagContents }
$ghRepo = "$appPublisher/$projectName"
$macInfoPlist = "$repoRoot/.resources/mac/Info.plist"
$macAppIcon = "$repoRoot/.resources/icon/$projectName.icns"
$buildNotes = "$repoRoot/.md/buildNotes.txt"
$publishFolder = "$repoRoot/publish"
$updater = "$repoRoot/.updater"
$updaterCsproj = "$updater/updater.csproj"
$buildTargets = @(
    @{ Architecture = 'arm64'; RuntimeIdentifier = 'osx-arm64'; BinFolder = "$publishFolder/osx-arm64"; HostPath = "$publishFolder/osx-arm64/$projectName"; AssetTag = 'osx-arm64'; AppBundlePath = "$publishFolder/osx-arm64/$projectName.app" }
    @{ Architecture = 'x64';   RuntimeIdentifier = 'osx-x64';   BinFolder = "$publishFolder/osx-x64";   HostPath = "$publishFolder/osx-x64/$projectName";   AssetTag = 'osx-x64';   AppBundlePath = "$publishFolder/osx-x64/$projectName.app" }
)

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
            default { 'x64' }
        }
    }

    Set-VersionBuildPlatform $platform
}

function Get-ReleaseAssetName {
    param(
        [Parameter(Mandatory)][ValidateSet('Portable')][string]$Kind,
        [Parameter(Mandatory)][string]$Architecture
    )
    $target = @($buildTargets | Where-Object { $_.Architecture -eq $Architecture } | Select-Object -First 1)
    $suffix = if ($target) { $target.AssetTag } else { "osx-$Architecture" }
    '{0}{1}_v{2}_{3}.zip' -f $projectName, $Kind, $versionContents, $suffix
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
            '(?i)^(--arm|-arm)$' { $hasArm = $true; break }
            '(?i)^(--64|-64)$' { $has64Flag = $true; break }
            default { throw "Unknown build flag: $a. Use -arm64, -x64 (or -arm, -arm -64, -64)." }
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

function Get-UpdaterRuntimeIdentifier {
    param([string]$MsBuildPlatform)

    switch ($MsBuildPlatform) {
        'ARM64' { return 'osx-arm64' }
        'x64' { return 'osx-x64' }
    }
    return $null
}

$publishStripFiles = @(
    'Avalonia.DesignerSupport.dll'
    'Avalonia.Remote.Protocol.dll'
    'Avalonia.FreeDesktop.dll'
    'Avalonia.FreeDesktop.AtSpi.dll'
    'Avalonia.X11.dll'
    'Avalonia.Win32.Automation.dll'
    'Avalonia.Win32.dll'
    'Tmds.DBus.Protocol.dll'
)

function Remove-PublishArtifacts {
    param([Parameter(Mandatory)][string]$BinFolder)

    foreach ($pdb in Get-ChildItem -LiteralPath $BinFolder -Filter '*.pdb' -File -ErrorAction SilentlyContinue) {
        Remove-Item -LiteralPath $pdb.FullName -Force
    }

    foreach ($name in $publishStripFiles) {
        $path = Join-Path $BinFolder $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }

    foreach ($name in @("$projectName.ico", "${projectName}256.png", 'VersionBuild')) {
        $path = Join-Path $BinFolder $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

function Set-MacHostExecutable {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    & chmod +x $Path
    if ($LASTEXITCODE) { throw "chmod failed for $Path (exit $LASTEXITCODE)" }
}

function New-MacAppBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Target
    )

    $binFolder = $Target.BinFolder
    $appBundle = $Target.AppBundlePath
    $hostFile = Join-Path $binFolder $projectName
    if (-not (Test-Path -LiteralPath $hostFile)) { throw "Missing app host (run build.ps1 first): $hostFile" }

    Set-MacHostExecutable $hostFile

    if (Test-Path -LiteralPath $appBundle) { Remove-Item -LiteralPath $appBundle -Recurse -Force }

    $contents = Join-Path $appBundle 'Contents'
    $macOsDir = Join-Path $contents 'MacOS'
    $resourcesDir = Join-Path $contents 'Resources'
    New-Item -ItemType Directory -Path $macOsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $resourcesDir -Force | Out-Null

    if (-not (Test-Path -LiteralPath $macAppIcon)) { throw "Missing macOS app icon: $macAppIcon" }
    Copy-Item -LiteralPath $macAppIcon -Destination (Join-Path $resourcesDir "$projectName.icns") -Force

    Get-ChildItem -LiteralPath $binFolder -Force | ForEach-Object {
        if ($_.Name -eq "$projectName.app") { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $macOsDir $_.Name) -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $macInfoPlist)) { throw "Missing macOS Info.plist template: $macInfoPlist" }
    $plist = ([IO.File]::ReadAllText($macInfoPlist)).Replace('__VERSION__', $versionContents)
    [IO.File]::WriteAllText((Join-Path $contents 'Info.plist'), $plist)

    Set-MacHostExecutable (Join-Path $macOsDir $projectName)
    Set-MacHostExecutable (Join-Path $macOsDir 'updater')
    Write-Host "Created $appBundle"
}
