#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'copyToOS.ps1')

$repoRoot = Resolve-CanonicalRepoRoot (Split-Path $PSScriptRoot -Parent)
$projectName = 'skeleton'
$csproj = Join-RepoPath $repoRoot $projectName "$projectName.csproj"
$dotnetFramework = 'net10.0'
$versionFolder = Join-RepoPath $repoRoot '.version'
$version = Join-RepoPath $versionFolder 'version'; $versionContents = ([IO.File]::ReadAllText($version)).Trim()
$versionBuild = Join-RepoPath $versionFolder 'versionBuild'
$versionTag = Join-RepoPath $versionFolder 'versionTag'
$versionTagContents = if (Test-Path -LiteralPath $versionTag) { ([IO.File]::ReadAllText($versionTag)).Trim() } else { '' }
$readme = Join-RepoPath $repoRoot 'README.md'
$readmeContents = Get-Content -LiteralPath $readme -Raw
$installerFolder = Join-RepoPath $repoRoot '.installer'
$installerOutput = Join-RepoPath $installerFolder 'Output'
$ISCC = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
$appPublisher = 'fosterbarnes'
$appURL = "https://github.com/$appPublisher/$projectName"
$appCopyright = "Copyright © $(Get-Date -Format yyyy) Foster Barnes"
$tag = if ([string]::IsNullOrWhiteSpace($versionTagContents)) { "v$versionContents" } else { $versionTagContents }
$ghRepo = "$appPublisher/$projectName"
$appIcon = Join-RepoPath $repoRoot '.resources' 'icon' "$projectName.ico"
$installerWizardSmallImage = Join-RepoPath $repoRoot '.resources' 'icon' 'installer-wizard-small.png'
$installerWizardLargeImage = Join-RepoPath $repoRoot '.resources' 'icon' 'installer-wizard-large.png'
$macInfoPlist = Join-RepoPath $repoRoot '.resources' 'mac' 'Info.plist'
$macEntitlements = Join-RepoPath $repoRoot '.resources' 'mac' 'Entitlements.plist'
$macAppIcon = Join-RepoPath $repoRoot '.resources' 'icon' "$projectName.icns"
$linuxDebResources = Join-RepoPath $repoRoot '.resources' 'linux' 'debian'
$linuxAppIcon = Join-RepoPath $repoRoot '.resources' 'icon' 'skeleton256.png'
$buildNotes = Join-RepoPath $repoRoot '.md' 'buildNotes.txt'
$publishFolder = Join-RepoPath $repoRoot 'publish'
$updater = Join-RepoPath $repoRoot '.updater'
$updaterCsproj = Join-RepoPath $updater 'updater.csproj'

$platformTargetDefs = @{
    Windows = @(
        @{ Architecture = 'x64';   RuntimeIdentifier = 'win-x64';   PublishDir = 'x64';   IssSuffix = 'x64' }
        @{ Architecture = 'x86';   RuntimeIdentifier = 'win-x86';   PublishDir = 'x86';   IssSuffix = 'x86' }
        @{ Architecture = 'arm64'; RuntimeIdentifier = 'win-arm64'; PublishDir = 'arm64'; IssSuffix = 'arm64' }
    )
    Mac = @(
        @{ Architecture = 'arm64'; RuntimeIdentifier = 'osx-arm64'; PublishDir = 'osx-arm64'; AssetTag = 'macOS-arm' }
        @{ Architecture = 'x64';   RuntimeIdentifier = 'osx-x64';   PublishDir = 'osx-x64';   AssetTag = 'macOS-intel' }
    )
    Linux = @(
        @{ Architecture = 'arm64'; RuntimeIdentifier = 'linux-arm64'; PublishDir = 'linux-arm64'; DebTag = 'arm64' }
        @{ Architecture = 'x64';   RuntimeIdentifier = 'linux-x64';   PublishDir = 'linux-x64';   DebTag = 'amd64' }
    )
}

function Expand-PlatformTarget {
    param([Parameter(Mandatory)][hashtable]$Def)

    $bin = Join-RepoPath $publishFolder $Def.PublishDir
    $t = @{
        Architecture      = $Def.Architecture
        RuntimeIdentifier = $Def.RuntimeIdentifier
        BinFolder         = $bin
    }
    if ($Def.AssetTag) {
        $t.AssetTag = $Def.AssetTag
        $t.HostPath = Join-RepoPath $bin $projectName
        $t.AppBundlePath = Join-RepoPath $bin "$projectName.app"
    }
    if ($Def.DebTag) {
        $t.DebTag = $Def.DebTag
        $t.HostPath = Join-RepoPath $bin $projectName
        $t.DebArchitecture = $Def.DebTag
    }
    if ($Def.IssSuffix) {
        $t.ExePath = Join-RepoPath $bin "$projectName.exe"
        $t.InstallerName = "$projectName-$($Def.Architecture)-installer.exe"
        $t.InstallerScript = Join-RepoPath $installerFolder "$projectName.$($Def.IssSuffix).installer.iss"
    }
    return $t
}

$expanded = @{
    Windows = @($platformTargetDefs.Windows | ForEach-Object { Expand-PlatformTarget $_ })
    Mac     = @($platformTargetDefs.Mac | ForEach-Object { Expand-PlatformTarget $_ })
    Linux   = @($platformTargetDefs.Linux | ForEach-Object { Expand-PlatformTarget $_ })
}
$hostPlatformKey = if ($IsMacOS) { 'Mac' } elseif ($IsLinux) { 'Linux' } else { 'Windows' }
$buildTargets = $expanded[$hostPlatformKey]
$winReleaseTargets = @($expanded.Windows | ForEach-Object { @{ Architecture = $_.Architecture; BinFolder = $_.BinFolder; InstallerName = $_.InstallerName } })
$macReleaseTargets = @($expanded.Mac | ForEach-Object { @{ Architecture = $_.Architecture; AssetTag = $_.AssetTag; AppBundlePath = $_.AppBundlePath } })
$linuxReleaseTargets = @($expanded.Linux | ForEach-Object { @{ Architecture = $_.Architecture; DebTag = $_.DebTag; BinFolder = $_.BinFolder } })

$publishStripCommon = @(
    'Avalonia.DesignerSupport.dll', 'Avalonia.Remote.Protocol.dll',
    "$projectName.ico", "${projectName}256.png", 'VersionBuild'
)
$publishStripFiles = $publishStripCommon + $(if ($IsMacOS) {
    @('Avalonia.Win32.Automation.dll', 'Avalonia.Win32.dll')
} elseif ($IsLinux) {
    @('Avalonia.Win32.Automation.dll', 'Avalonia.Win32.dll', 'Avalonia.Native.dll')
} else {
    @('Avalonia.Native.dll', 'Avalonia.FreeDesktop.dll', 'Avalonia.FreeDesktop.AtSpi.dll', 'Avalonia.X11.dll', 'Tmds.DBus.Protocol.dll')
})

function Get-IssDefinePattern([string]$Name) { "#define\s+$([regex]::Escape($Name))\s+`"([^`"]*)`"" }

function Test-IssDefine {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ExpectedValue
    )
    if ($Content -notmatch (Get-IssDefinePattern $Name)) { return $false }
    return (Normalize-PathSlashes $Matches[1]) -eq (Normalize-PathSlashes $ExpectedValue)
}

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
    } else {
        switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
            'Arm64' { 'arm64' }
            'X86'   { if (-not $IsMacOS) { 'x86' } else { 'arm64' } }
            default { 'x64' }
        }
    }

    Set-VersionBuildPlatform $platform
}

function Resolve-BuildArchitecture {
    param([string[]]$FlagArgs)

    $hasArm = $false; $has64Flag = $false; $resolved = @()

    foreach ($a in @($FlagArgs)) {
        if ([string]::IsNullOrWhiteSpace($a)) { continue }
        switch -Regex ($a.Trim()) {
            '(?i)^(--arm64|-arm64)$' { $resolved += 'arm64'; break }
            '(?i)^(--x64|-x64)$' { $resolved += 'x64'; break }
            '(?i)^(--x86|-x86)$' { if (-not $IsMacOS -and -not $IsLinux) { $resolved += 'x86' }; break }
            '(?i)^(--86|-86)$' { if (-not $IsMacOS -and -not $IsLinux) { $resolved += 'x86' }; break }
            '(?i)^(--arm|-arm)$' { $hasArm = $true; break }
            '(?i)^(--64|-64)$' { $has64Flag = $true; break }
            default {
                $flags = if ($IsMacOS -or $IsLinux) { '-arm64, -x64 (or -arm, -arm -64, -64)' } else { '-arm64, -x64, -x86 (or -arm, -arm -64, -64, -86)' }
                throw "Unknown build flag: $a. Use $flags."
            }
        }
    }

    if ($hasArm -and $has64Flag) { $resolved += 'arm64' }
    elseif ($has64Flag) { $resolved += 'x64' }
    elseif ($hasArm) { $resolved += 'arm64' }

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
    if ($filtered.Count -eq 1) { return ,$filtered[0] }
    return $filtered
}

function Get-InstallerIssDefines {
    [ordered]@{
        AppVersion    = $versionContents
        AppCopyright  = $appCopyright
        AppPublisher  = $appPublisher
        AppURL        = $appURL
        SetupIconFile       = @('..', '.resources', 'icon', "$projectName.ico") -join '\'
        WizardSmallImageFile = @('..', '.resources', 'icon', 'installer-wizard-small.png') -join '\'
        WizardImageFile     = @('..', '.resources', 'icon', 'installer-wizard-large.png') -join '\'
    }
}

function Sync-InstallerDefines {
    if ($IsMacOS) { return }
    if (-not (Test-Path -LiteralPath $ISCC)) { throw "Inno Setup compiler not found: $ISCC" }
    if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }

    $defines = Get-InstallerIssDefines
    foreach ($target in $buildTargets) {
        $path = $target.InstallerScript
        $content = [IO.File]::ReadAllText($path)
        $original = $content
        foreach ($key in 'AppVersion', 'AppCopyright') {
            $pattern = Get-IssDefinePattern $key
            if ($content -notmatch $pattern) { throw "$path`: missing $key define" }
            $content = [regex]::Replace($content, $pattern, "#define $key `"$($defines[$key])`"", 1)
        }
        if ($content -ne $original) {
            [IO.File]::WriteAllText($path, $content)
            Write-Host "Updated $($target.Architecture) installer defines (AppVersion=$versionContents)"
        }
    }
}

function Get-UpdaterRuntimeIdentifier {
    param([string]$MsBuildPlatform)

    if (-not $IsMacOS) { return $null }
    switch ($MsBuildPlatform) {
        'ARM64' { return 'osx-arm64' }
        'x64' { return 'osx-x64' }
    }
    return $null
}

function Remove-PublishArtifacts {
    param([Parameter(Mandatory)][string]$BinFolder)

    foreach ($pdb in Get-ChildItem -LiteralPath $BinFolder -Filter '*.pdb' -File -ErrorAction SilentlyContinue) {
        Remove-Item -LiteralPath $pdb.FullName -Force
    }

    foreach ($name in $publishStripFiles) {
        $path = Join-Path $BinFolder $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

function Set-UnixHostExecutable {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    & chmod +x $Path
    if ($LASTEXITCODE) { throw "chmod failed for $Path (exit $LASTEXITCODE)" }
}

function Get-ZipEntryUnixMode {
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$EntryPath
    )

    $output = & zipinfo -v $ZipPath $EntryPath 2>&1
    if ($LASTEXITCODE) { return $null }
    $match = [regex]::Match(($output -join "`n"), 'Unix file attributes \((\d+) octal\):')
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value
}

function Assert-MacPortableZipExecutableEntries {
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$AppBundleName
    )

    foreach ($name in $projectName, 'updater') {
        $entry = "$AppBundleName/Contents/MacOS/$name"
        $mode = Get-ZipEntryUnixMode -ZipPath $ZipPath -EntryPath $entry
        if ($mode -ne '100755') {
            throw "macOS portable zip entry must be 100755: $entry (got $mode) in $ZipPath"
        }
    }
}

function New-MacPortableZip {
    param(
        [Parameter(Mandatory)][string]$AppBundle,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) { Remove-Item -LiteralPath $DestinationPath -Force }
    & ditto -c -k --sequesterRsrc --keepParent $AppBundle $DestinationPath
    if ($LASTEXITCODE) { throw "ditto failed for $AppBundle (exit $LASTEXITCODE)" }

    $bundleName = [IO.Path]::GetFileName($AppBundle)
    Assert-MacPortableZipExecutableEntries -ZipPath $DestinationPath -AppBundleName $bundleName
}

function Confirm-MacAppBundleSigned {
    param([Parameter(Mandatory)][string]$AppBundle)

    & codesign --verify --deep --strict $AppBundle
    if ($LASTEXITCODE) { throw "codesign verify failed for $AppBundle (exit $LASTEXITCODE)" }

    $details = (& codesign -dv $AppBundle 2>&1 | ForEach-Object { "$_" }) -join "`n"
    if ($details -notmatch 'Info\.plist entries=') {
        throw "macOS app bundle signature is not sealed (Info.plist not bound): $AppBundle"
    }
}

function New-MacAppBundle {
    param([Parameter(Mandatory)][hashtable]$Target)

    $binFolder = $Target.BinFolder
    $appBundle = $Target.AppBundlePath
    $hostFile = Join-Path $binFolder $projectName
    if (-not (Test-Path -LiteralPath $hostFile)) { throw "Missing app host (run build.ps1 first): $hostFile" }

    Set-UnixHostExecutable $hostFile
    if (Test-Path -LiteralPath $appBundle) { Remove-Item -LiteralPath $appBundle -Recurse -Force }

    $macOsDir = Join-Path $appBundle 'Contents/MacOS'
    $resourcesDir = Join-Path $appBundle 'Contents/Resources'
    New-Item -ItemType Directory -Path $macOsDir, $resourcesDir -Force | Out-Null

    if (-not (Test-Path -LiteralPath $macAppIcon)) { throw "Missing macOS app icon: $macAppIcon" }
    Copy-Item -LiteralPath $macAppIcon -Destination (Join-Path $resourcesDir "$projectName.icns") -Force

    Get-ChildItem -LiteralPath $binFolder -Force | ForEach-Object {
        if ($_.Name -eq "$projectName.app") { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $macOsDir $_.Name) -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $macInfoPlist)) { throw "Missing macOS Info.plist template: $macInfoPlist" }
    [IO.File]::WriteAllText((Join-Path $appBundle 'Contents/Info.plist'), ([IO.File]::ReadAllText($macInfoPlist)).Replace('__VERSION__', $versionContents))

    foreach ($p in (Join-Path $macOsDir $projectName), (Join-Path $macOsDir 'updater')) { Set-UnixHostExecutable $p }
    Write-Host "Created $appBundle"
}

function Invoke-MacAppBundleCodesign {
    param([Parameter(Mandatory)][array]$Targets)

    $identity = $env:SKELETON_MAC_SIGN_IDENTITY
    foreach ($t in $Targets) {
        $app = $t.AppBundlePath
        if (-not (Test-Path -LiteralPath $app)) { throw "Missing app bundle (run build.ps1 first): $app" }
        if ([string]::IsNullOrWhiteSpace($identity)) {
            Write-Host "Adhoc sealing $($t.Architecture) app bundle: $app"
            & codesign --force --deep --sign - $app
            if ($LASTEXITCODE) { throw "adhoc codesign failed for $app (exit $LASTEXITCODE)" }
        }
        else {
            if (-not (Test-Path -LiteralPath $macEntitlements)) { throw "Missing macOS entitlements: $macEntitlements" }
            Write-Host "Codesigning $($t.Architecture) app bundle: $app"
            & codesign --force --options runtime --entitlements $macEntitlements --sign $identity $app
            if ($LASTEXITCODE) { throw "codesign failed for $app (exit $LASTEXITCODE)" }
        }
        Confirm-MacAppBundleSigned $app
    }
}

function Get-WinReleaseAssetName {
    param(
        [Parameter(Mandatory)][ValidateSet('Installer', 'Portable')][string]$Kind,
        [Parameter(Mandatory)][string]$Architecture
    )
    $ext = if ($Kind -eq 'Installer') { 'exe' } else { 'zip' }
    '{0}{1}_v{2}_{3}.{4}' -f $projectName, $Kind, $versionContents, $Architecture, $ext
}

function Get-MacPortableReleaseAssetName {
    param([Parameter(Mandatory)][string]$AssetTag)
    '{0}_v{1}_{2}.zip' -f $projectName, $versionContents, $AssetTag
}

function Get-LinuxDebReleaseAssetName {
    param([Parameter(Mandatory)][string]$Architecture)
    $tag = if ($Architecture -eq 'x64') { 'amd64' } else { 'arm64' }
    '{0}_v{1}_debian-{2}.deb' -f $projectName, $versionContents, $tag
}

function New-LinuxDebPackage {
    param([Parameter(Mandatory)][hashtable]$Target)

    if (-not (Get-Command dpkg-deb -ErrorAction SilentlyContinue)) {
        throw 'dpkg-deb not found. Install dpkg-dev on Debian (sudo apt install dpkg-dev).'
    }

    $binFolder = $Target.BinFolder
    $hostFile = $Target.HostPath
    if (-not (Test-Path -LiteralPath $hostFile)) { throw "Missing app host (run build.ps1 first): $hostFile" }

    $launcherTemplate = Join-RepoPath $linuxDebResources $projectName
    $desktopTemplate = Join-RepoPath $linuxDebResources "$projectName.desktop"
    $controlTemplate = Join-RepoPath $linuxDebResources 'control.template'
    foreach ($path in $launcherTemplate, $desktopTemplate, $controlTemplate, $linuxAppIcon) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing Linux deb template: $path" }
    }

    $debPath = Join-Path $publishFolder (Get-LinuxDebReleaseAssetName -Architecture $Target.Architecture)
    if (Test-Path -LiteralPath $debPath) { Remove-Item -LiteralPath $debPath -Force }

    $stagingRoot = Join-Path ([IO.Path]::GetTempPath()) "$projectName-deb-$([Guid]::NewGuid().ToString('N'))"
    $libDir = Join-RepoPath $stagingRoot 'usr' 'lib' $projectName
    $binDir = Join-RepoPath $stagingRoot 'usr' 'bin'
    $applicationsDir = Join-RepoPath $stagingRoot 'usr' 'share' 'applications'
    $pixmapsDir = Join-RepoPath $stagingRoot 'usr' 'share' 'pixmaps'
    $debianDir = Join-RepoPath $stagingRoot 'DEBIAN'

    try {
        New-Item -ItemType Directory -Path $libDir, $binDir, $applicationsDir, $pixmapsDir, $debianDir -Force | Out-Null

        $publishItems = @(Get-ChildItem -LiteralPath $binFolder -Force -ErrorAction Stop)
        if (-not $publishItems.Count) { throw "Linux publish folder is empty ($($Target.Architecture)): $binFolder" }
        $publishItems | Copy-Item -Destination $libDir -Recurse -Force
        $updaterPath = Join-Path $libDir 'updater'
        if (Test-Path -LiteralPath $updaterPath) { Remove-Item -LiteralPath $updaterPath -Force }

        Set-UnixHostExecutable (Join-Path $libDir $projectName)
        & chmod -R a+rX $libDir
        if ($LASTEXITCODE) { throw "chmod failed for $libDir (exit $LASTEXITCODE)" }

        $launcherDest = Join-Path $binDir $projectName
        Copy-Item -LiteralPath $launcherTemplate -Destination $launcherDest -Force
        Set-UnixHostExecutable $launcherDest

        Copy-Item -LiteralPath $desktopTemplate -Destination (Join-Path $applicationsDir "$projectName.desktop") -Force
        Copy-Item -LiteralPath $linuxAppIcon -Destination (Join-Path $pixmapsDir "$projectName.png") -Force

        $installedSizeKb = [int]((& du -sk $stagingRoot) -split '\t')[0]
        $description = "$projectName Avalonia settings app template."
        $control = [IO.File]::ReadAllText($controlTemplate)
        $control = $control.Replace('__PACKAGE__', $projectName).Replace('__VERSION__', $versionContents).Replace('__DEB_ARCH__', $Target.DebArchitecture).Replace('__INSTALLED_SIZE_KB__', "$installedSizeKb").Replace('__MAINTAINER__', "$appPublisher <$appPublisher@users.noreply.github.com>").Replace('__HOMEPAGE__', $appURL).Replace('__DESCRIPTION__', $description).Replace('__EXTENDED_DESCRIPTION__', 'Framework-dependent; install .NET 10 runtime from Microsoft apt repo.')
        [IO.File]::WriteAllText((Join-Path $debianDir 'control'), $control)

        Write-Host "Building $($Target.Architecture) .deb (AppVersion=$versionContents)"
        & dpkg-deb --root-owner-group --build $stagingRoot $debPath
        if ($LASTEXITCODE) { throw "dpkg-deb failed for $($Target.Architecture) (exit $LASTEXITCODE)" }
        Set-UnixHostExecutable $debPath
        Write-Host "Created $debPath"
    }
    finally {
        Remove-TreeForce $stagingRoot
    }
}

function Copy-ReleaseArtifactsToPublish {
    param([string]$Architecture)

    $targets = if ($IsMacOS) {
        if ([string]::IsNullOrWhiteSpace($Architecture)) { $macReleaseTargets } else { @($macReleaseTargets | Where-Object Architecture -eq $Architecture) }
    } elseif ($IsLinux) {
        if ([string]::IsNullOrWhiteSpace($Architecture)) { $linuxReleaseTargets } else { @($linuxReleaseTargets | Where-Object Architecture -eq $Architecture) }
    } else {
        if ([string]::IsNullOrWhiteSpace($Architecture)) { $winReleaseTargets } else { @($winReleaseTargets | Where-Object Architecture -eq $Architecture) }
    }
    if (-not $targets.Count) { throw "No release targets for architecture: $Architecture" }

    foreach ($target in $targets) {
        if ($IsLinux) {
            $debPath = Join-Path $publishFolder (Get-LinuxDebReleaseAssetName -Architecture $target.Architecture)
            if (-not (Test-Path -LiteralPath $debPath)) {
                throw "Missing Linux .deb ($($target.Architecture)). Run buildInstaller.ps1 first: $debPath"
            }
            $publishDir = $target.BinFolder
            Remove-TreeForce $publishDir
            Write-Host "Removed Linux publish output: $publishDir"
            continue
        }

        if ($IsMacOS) {
            $appBundle = $target.AppBundlePath
            if (-not (Test-Path -LiteralPath $appBundle)) { throw "Missing macOS app bundle (run build.ps1 first): $appBundle" }

            $dest = Join-Path $publishFolder (Get-MacPortableReleaseAssetName -AssetTag $target.AssetTag)
            Write-Host "Staging macOS portable: $dest"
            New-MacPortableZip -AppBundle $appBundle -DestinationPath $dest
            $publishDir = Split-Path $appBundle -Parent
            Remove-TreeForce $publishDir
            Write-Host "Removed macOS publish output: $publishDir"
            continue
        }

        $arch = $target.Architecture
        $binFolder = $target.BinFolder
        if (-not (Test-Path -LiteralPath $binFolder)) { throw "Missing Windows publish ($arch). Run build.ps1 first: $binFolder" }

        $binItems = @(Get-ChildItem -LiteralPath $binFolder -Force | ForEach-Object FullName)
        if (-not $binItems.Count) { throw "Windows publish folder is empty ($arch): $binFolder" }

        $portableDest = Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Portable -Architecture $arch)
        Write-Host "Staging Windows portable: $portableDest"
        if (Test-Path -LiteralPath $portableDest) { Remove-Item -LiteralPath $portableDest -Force }
        Compress-Archive -Path $binItems -DestinationPath $portableDest -Force

        $builtInstaller = Join-Path $installerOutput $target.InstallerName
        if (-not (Test-Path -LiteralPath $builtInstaller)) { throw "Missing Windows installer ($arch). Run buildInstaller.ps1 first: $builtInstaller" }

        $installerDest = Join-Path $publishFolder (Get-WinReleaseAssetName -Kind Installer -Architecture $arch)
        Write-Host "Staging Windows installer: $installerDest"
        Copy-Item -LiteralPath $builtInstaller -Destination $installerDest -Force

        Remove-TreeForce $binFolder
        Write-Host "Removed Windows publish output: $binFolder"
        Remove-Item -LiteralPath $builtInstaller -Force
        Write-Host "Removed Windows installer output: $builtInstaller"
    }

    Write-Host "Release artifacts staged in $publishFolder"
}

if (($c = (Get-PSCallStack)[1].ScriptName) -and (Split-Path $c -Leaf) -in 'build.ps1', '.run.ps1', 'buildUpdater.ps1') {
    Invoke-HostBuildPrep
}
