#requires -Version 7.0
param(
    [switch]$mac,
    [switch]$win
)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Join-RepoPath -ErrorAction SilentlyContinue)) {
    function Join-RepoPath {
        param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Segments)
        if (-not $Segments.Count) { throw 'Join-RepoPath requires at least one segment.' }
        $path = $Segments[0]
        for ($i = 1; $i -lt $Segments.Count; $i++) {
            $segment = $Segments[$i].TrimStart('/')
            $path = if ($path.EndsWith('/')) { "$path$segment" } else { "$path/$segment" }
        }
        return $path
    }
}

if (-not (Get-Command Normalize-PathSlashes -ErrorAction SilentlyContinue)) {
    function Normalize-PathSlashes {
        param([Parameter(Mandatory)][string]$Path)
        return $Path.Replace('\', '/')
    }
}

if (-not $repoRoot) {
    $repoRoot = (Split-Path $PSScriptRoot -Parent) -replace '\\', '/'
}

$copyRepoWinPath = '/Volumes/[C] Windows 11/Users/foster/Documents/GitHub/skeleton'
$copyRepoWinVolume = '/Volumes/[C] Windows 11'

$copyRepoMacPath = ''
$copyRepoMacPathWin = 'Z:\Users\foster\Documents\GitHub\skeleton'
$copyRepoMacVolumeWin = 'Z:\'

$foreignOsProfiles = @{
    Mac     = @{ ObjBinRegex = '/(Users|home)/'; PublishSubdirs = 'osx-arm64', 'osx-x64'; RepoFileMarkers = '.DS_Store'; PublishRootGlobs = @(); PublishLabel = 'macOS' }
    Windows = @{ ObjBinRegex = 'win-x64|win-arm64|win-x86|\\Users\\|C:\\'; PublishSubdirs = 'x86', 'x64', 'arm64'; RepoFileMarkers = @(); PublishRootGlobs = @(); PublishLabel = 'Windows' }
}

function Remove-TreeForce {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Attributes = 'Normal' }
    Remove-Item -LiteralPath $Path -Recurse -Force
}

function Clear-RepoObjBin {
    param([Parameter(Mandatory)][string]$Root)

    foreach ($dirName in @('obj', 'bin')) {
        foreach ($dir in @(Get-ChildItem -LiteralPath $Root -Directory -Filter $dirName -Recurse -Force -ErrorAction SilentlyContinue)) {
            Remove-TreeForce $dir.FullName
        }
    }
}

function Test-RepoWritable {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) { return $true }
    $probe = Join-Path $Root ".copy-probe-$PID"
    try {
        [IO.File]::WriteAllText($probe, '')
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch {
        return $false
    }
}

function Clear-PathReadOnlyAt {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) { return }

    $fixed = 0
    foreach ($item in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue)) {
        if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) {
            $item.Attributes = $item.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)
            $fixed++
        }
    }

    if ($fixed) { Write-Host "Cleared read-only on $fixed item(s) under $Root." }
}

function Ensure-RepoWritable {
    param([Parameter(Mandatory)][string]$Root)

    if (Test-RepoWritable $Root) { return }

    Clear-PathReadOnlyAt $Root
    if (Test-RepoWritable $Root) { return }

    $onWinVolume = $IsMacOS -and $Root.StartsWith($copyRepoWinVolume, [StringComparison]::Ordinal)
    if ($onWinVolume) {
        throw "Cannot write to $Root on the mounted Windows volume. Fix folder permissions in Windows, or delete that folder and run copyToOS.ps1 -win again."
    }

    $onMacVolume = -not $IsMacOS -and $Root.StartsWith($copyRepoMacVolumeWin, [StringComparison]::OrdinalIgnoreCase)
    if ($onMacVolume) {
        throw "Cannot write to $Root on the mounted Mac volume. Fix folder permissions on Mac, or delete that folder and run copyToOS.ps1 -mac again."
    }

    if ($IsMacOS) {
        throw "Cannot write to $Root. Run once: sudo chown -R $(whoami):staff `"$Root`""
    }

    throw "Cannot write to $Root. Check folder permissions and retry."
}

function Resolve-CopyDestination {
    param(
        [switch]$mac,
        [switch]$win
    )

    if ($win -and -not $IsMacOS) {
        throw 'Copy-ToOS -win is for macOS hosts (sync to the mounted Windows volume). On Windows, use -mac to sync to Mac.'
    }

    $dest = if ($mac) {
        if ($IsMacOS) { $copyRepoMacPath } else { $copyRepoMacPathWin }
    } else {
        $copyRepoWinPath
    }

    if ($mac -and $IsMacOS -and [string]::IsNullOrWhiteSpace($copyRepoMacPath)) {
        throw 'Set $copyRepoMacPath in copyToOS.ps1 for Copy-ToOS -mac on macOS.'
    }

    $destNorm = (Normalize-PathSlashes $dest).TrimEnd('/')
    $rootNorm = (Normalize-PathSlashes $repoRoot).TrimEnd('/')
    if ($destNorm -eq $rootNorm) { throw 'Copy-ToOS destination must differ from $repoRoot.' }

    return $dest
}

function Test-CopyDestinationReady {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [switch]$mac,
        [switch]$win
    )

    if ($win -and $IsMacOS -and -not (Test-Path -LiteralPath $copyRepoWinVolume)) {
        throw "Windows volume not mounted. Expected: $copyRepoWinVolume"
    }

    if ($mac -and -not $IsMacOS -and -not (Test-Path -LiteralPath $copyRepoMacVolumeWin)) {
        throw "Mac volume not available. Expected: $copyRepoMacVolumeWin"
    }

    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        $hint = if ($win -and $IsMacOS) { 'is the Windows volume mounted?' }
                elseif ($mac -and -not $IsMacOS) { 'is the Mac volume mounted?' }
                else { 'does the parent folder exist?' }
        throw "Copy destination parent not found ($hint): $parent"
    }
}

function Sync-CopyRepo {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [switch]$StripMacMetadata
    )

    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        throw "Copy destination parent not found: $parent"
    }

    Ensure-RepoWritable $parent
    if (Test-Path -LiteralPath $Destination) { Ensure-RepoWritable $Destination }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Write-Host 'Syncing files...'
    if ($IsMacOS) {
        $excludes = @('--exclude=obj/', '--exclude=bin/')
        if ($StripMacMetadata) {
            $excludes += '--exclude=._*', '--exclude=.DS_Store'
        }

        $copyfileWas = $env:COPYFILE_DISABLE
        if ($StripMacMetadata) { $env:COPYFILE_DISABLE = '1' }

        try {
            & rsync -a --delete --progress --stats @excludes "$Source/" "$Destination/"
            if ($LASTEXITCODE) { throw "rsync failed (exit $LASTEXITCODE)" }
        }
        finally {
            if ($StripMacMetadata) {
                if ($null -eq $copyfileWas) { Remove-Item Env:COPYFILE_DISABLE -ErrorAction SilentlyContinue }
                else { $env:COPYFILE_DISABLE = $copyfileWas }
            }
        }
    }
    else {
        $robocopyArgs = @(
            $Source, $Destination,
            '/MIR', '/XD', 'obj', 'bin',
            '/R:2', '/W:2', '/NP'
        )
        if ($StripMacMetadata) {
            $robocopyArgs += '/XF', '.DS_Store'
        }

        & robocopy @robocopyArgs
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed (exit $LASTEXITCODE)" }
    }
}

function Clear-MacMetadataAt {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) { return }

    $removed = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Filter '._*' -Recurse -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $file.FullName -Force
        $removed++
    }

    if ($removed) { Write-Host "Removed $removed macOS AppleDouble file(s)." }
}

function Test-ObjBinForeignArtifacts {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][hashtable]$Profile
    )

    foreach ($dirName in @('obj', 'bin')) {
        foreach ($dir in @(Get-ChildItem -LiteralPath $Root -Directory -Filter $dirName -Recurse -Force -ErrorAction SilentlyContinue)) {
            foreach ($file in @(Get-ChildItem -LiteralPath $dir.FullName -Include '*.nuget.g.props', 'project.assets.json' -File -Recurse -Force -ErrorAction SilentlyContinue)) {
                if ([IO.File]::ReadAllText($file.FullName) -match $Profile.ObjBinRegex) { return $true }
            }
        }
    }

    return $false
}

function Test-CopiedFromForeignOs {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][hashtable]$Profile
    )

    if (Test-ObjBinForeignArtifacts $Root $Profile) { return $true }

    $publish = Join-RepoPath $Root 'publish'
    foreach ($name in $Profile.PublishSubdirs) {
        if (Test-Path -LiteralPath (Join-RepoPath $publish $name)) { return $true }
    }

    foreach ($marker in $Profile.RepoFileMarkers) {
        if (@(Get-ChildItem -LiteralPath $Root -Filter $marker -Recurse -Force -ErrorAction SilentlyContinue).Count -gt 0) { return $true }
    }

    if (-not $Profile.PublishRootGlobs.Count -or -not (Test-Path -LiteralPath $publish)) { return $false }

    foreach ($glob in $Profile.PublishRootGlobs) {
        if (@(Get-ChildItem -LiteralPath $publish -Filter $glob -File -ErrorAction SilentlyContinue).Count -gt 0) { return $true }
    }

    return $false
}

function Test-MacObjBinArtifacts { if ($IsMacOS) { return $false }; Test-ObjBinForeignArtifacts $repoRoot $foreignOsProfiles.Mac }
function Test-CopiedFromMac { if ($IsMacOS) { return $false }; Test-CopiedFromForeignOs $repoRoot $foreignOsProfiles.Mac }

function Clear-CopiedRepoReadOnly {
    if ($IsMacOS) { return }
    Clear-PathReadOnlyAt $repoRoot
}

function Clear-ForeignPublishArtifactsAt {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][hashtable]$Profile
    )

    foreach ($marker in $Profile.RepoFileMarkers) {
        foreach ($file in @(Get-ChildItem -LiteralPath $Root -Filter $marker -Recurse -Force -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $file.FullName -Force
        }
    }

    $publish = Join-RepoPath $Root 'publish'
    foreach ($name in $Profile.PublishSubdirs) {
        $path = Join-RepoPath $publish $name
        if (Test-Path -LiteralPath $path) {
            Remove-TreeForce $path
            Write-Host "Removed $($Profile.PublishLabel) publish output: $path"
        }
    }

    if (-not $Profile.PublishRootGlobs.Count -or -not (Test-Path -LiteralPath $publish)) { return }

    foreach ($glob in $Profile.PublishRootGlobs) {
        foreach ($file in @(Get-ChildItem -LiteralPath $publish -Filter $glob -File -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $file.FullName -Force
            Write-Host "Removed $($Profile.PublishLabel) publish artifact: $($file.Name)"
        }
    }
}

function Clear-ForeignBuildArtifacts {
    param([Parameter(Mandatory)][hashtable]$Profile)

    Clear-ForeignPublishArtifactsAt $repoRoot $Profile

    if (-not (Test-ObjBinForeignArtifacts $repoRoot $Profile)) { return }

    Write-Host "Removing $($Profile.PublishLabel) build artifacts (obj/bin)..."
    Clear-RepoObjBin $repoRoot
}

function Clear-MacBuildArtifactsAt {
    param([Parameter(Mandatory)][string]$Root)
    Clear-ForeignPublishArtifactsAt $Root $foreignOsProfiles.Mac
    Clear-MacMetadataAt $Root
}
function Clear-MacBuildArtifacts { if ($IsMacOS) { return }; if (Test-CopiedFromMac) { Clear-CopiedRepoReadOnly }; Clear-ForeignBuildArtifacts $foreignOsProfiles.Mac }
function Test-WindowsObjBinArtifacts { param([string]$Root = $repoRoot); if (-not $IsMacOS) { return $false }; Test-ObjBinForeignArtifacts $Root $foreignOsProfiles.Windows }
function Test-CopiedFromWindows { param([string]$Root = $repoRoot); if (-not $IsMacOS) { return $false }; Test-CopiedFromForeignOs $Root $foreignOsProfiles.Windows }
function Clear-WindowsBuildArtifactsAt { param([Parameter(Mandatory)][string]$Root); Clear-ForeignPublishArtifactsAt $Root $foreignOsProfiles.Windows }
function Clear-WindowsBuildArtifacts { if (-not $IsMacOS) { return }; Clear-ForeignBuildArtifacts $foreignOsProfiles.Windows }

function Initialize-CopiedRepo {
    Set-Location -LiteralPath $repoRoot
    Write-Host "Preparing folder copy for $(if ($IsMacOS) { 'macOS' } else { 'Windows' })..."
    if ($IsMacOS) {
        Ensure-RepoWritable $repoRoot
        Clear-WindowsBuildArtifacts
        Clear-RepoObjBin $repoRoot
    }
    else {
        Clear-CopiedRepoReadOnly
        Clear-MacBuildArtifacts
    }
    Write-Host 'Ready.'
}

function Copy-ToOS {
    param(
        [switch]$mac,
        [switch]$win
    )

    if ($mac -and $win) { throw 'Use exactly one of -mac or -win.' }
    if (-not $mac -and -not $win) { throw 'Specify -mac or -win as the copy destination.' }

    if ($win -and -not $IsMacOS) {
        Write-Host 'On Windows, -win targets this machine (already your repo). Syncing to Mac (-mac) instead.'
        $mac = $true
        $win = $false
    }
    elseif ($mac -and $IsMacOS) {
        Write-Host 'On macOS, -mac targets this machine (already your repo). Syncing to Windows (-win) instead.'
        $win = $true
        $mac = $false
    }

    $dest = Resolve-CopyDestination -mac:$mac -win:$win
    Test-CopyDestinationReady -Destination $dest -mac:$mac -win:$win

    Write-Host "Syncing $repoRoot -> $dest"
    Sync-CopyRepo -Source $repoRoot -Destination $dest -StripMacMetadata:($win.IsPresent)
    Clear-RepoObjBin $dest

    if ($mac) { Clear-WindowsBuildArtifactsAt $dest }
    else { Clear-MacBuildArtifactsAt $dest }

    Write-Host 'Copy complete.'
}

if ($MyInvocation.InvocationName -ne '.') {
    Copy-ToOS -mac:$mac -win:$win
}
