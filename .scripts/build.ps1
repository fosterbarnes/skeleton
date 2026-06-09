param([string]$Architecture)

#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

Ensure-VersionBuildPlatform $Architecture
& dotnet restore skeleton.sln
if ($LASTEXITCODE) { throw "dotnet restore failed (exit $LASTEXITCODE)" }

$selectedTargets = Select-BuildTargets $Architecture
foreach ($target in $selectedTargets) {
    Write-Host "Clearing $($target.RuntimeIdentifier) build..."
    if (Test-Path -LiteralPath $target.BinFolder) { Remove-Item -LiteralPath $target.BinFolder -Recurse -Force }
    Write-Host "Building $($target.RuntimeIdentifier)... ($($target.BinFolder))"
    & dotnet publish $csproj -c Release -r $target.RuntimeIdentifier --no-self-contained -p:PublishReadyToRun=true -o $target.BinFolder
    if ($LASTEXITCODE) { throw "dotnet publish failed ($($target.RuntimeIdentifier) exit $LASTEXITCODE)" }
}

& (Join-Path $PSScriptRoot 'buildUpdater.ps1') -Architecture $Architecture
if ($LASTEXITCODE) { throw "buildUpdater failed (exit $LASTEXITCODE)" }

foreach ($target in $selectedTargets) {
    if ($IsMacOS) {
        $updaterPath = Join-Path $target.BinFolder 'updater'
        if (-not (Test-Path -LiteralPath $updaterPath)) { throw "Missing updater (run buildUpdater.ps1 first): $updaterPath" }
    }
    Copy-Item -LiteralPath $version -Destination (Join-Path $target.BinFolder 'Version') -Force
    Remove-PublishArtifacts $target.BinFolder
    if ($IsMacOS) {
        Set-MacHostExecutable $target.HostPath
        New-MacAppBundle $target
    }
}
