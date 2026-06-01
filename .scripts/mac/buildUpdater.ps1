param([string]$Architecture)

. "$PSScriptRoot/scriptHelper.ps1"; Set-Location $repoRoot
$buildTargets = Select-BuildTargets $Architecture
foreach ($target in $buildTargets) {
    Write-Host "Building updater for $($target.RuntimeIdentifier)... ($($target.BinFolder))"
    & dotnet publish $updaterCsproj -c Release -r $target.RuntimeIdentifier --no-self-contained -o $target.BinFolder
    if ($LASTEXITCODE) { throw "dotnet publish failed for updater ($($target.RuntimeIdentifier) exit $LASTEXITCODE)" }
    Set-MacHostExecutable (Join-Path $target.BinFolder 'updater')
}
