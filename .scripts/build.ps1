. "$PSScriptRoot\scriptHelper.ps1"; Set-Location $repoRoot
foreach ($target in $buildTargets) {
    Write-Host "Clearing old builds..."; Remove-Item $target.BinFolder -Recurse -Force
    Write-Host "Building $($target.RuntimeIdentifier)... ($($target.BinFolder))"
    & dotnet publish $csproj -c Release -r $target.RuntimeIdentifier --no-self-contained -o $target.BinFolder
    if ($LASTEXITCODE) { throw "dotnet publish failed ($($target.RuntimeIdentifier) exit $LASTEXITCODE)" }
}
