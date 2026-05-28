param([string]$Architecture)

. "$PSScriptRoot\scriptHelper.ps1"; Set-Location $repoRoot
Ensure-VersionBuildPlatform $Architecture
& dotnet restore skeleton.sln
if ($LASTEXITCODE) { throw "dotnet restore failed (exit $LASTEXITCODE)" }
$buildTargets = Select-BuildTargets $Architecture
foreach ($target in $buildTargets) {
    Write-Host "Clearing $($target.RuntimeIdentifier) build..."
    if (Test-Path -LiteralPath $target.BinFolder) { Remove-Item -LiteralPath $target.BinFolder -Recurse -Force }
    Write-Host "Building $($target.RuntimeIdentifier)... ($($target.BinFolder))"
    & dotnet publish $csproj -c Release -r $target.RuntimeIdentifier --no-self-contained -p:PublishReadyToRun=true -o $target.BinFolder
    if ($LASTEXITCODE) { throw "dotnet publish failed ($($target.RuntimeIdentifier) exit $LASTEXITCODE)" }
}

& "$PSScriptRoot\buildUpdater.ps1" -Architecture $Architecture
if ($LASTEXITCODE) { throw "buildUpdater failed (exit $LASTEXITCODE)" }

foreach ($target in $buildTargets) {
    Copy-Item -LiteralPath $version -Destination "$($target.BinFolder)\Version" -Force
    Remove-PublishArtifacts $target.BinFolder
}
