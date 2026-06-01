param([string]$Architecture)

. "$PSScriptRoot/scriptHelper.ps1"; Set-Location $repoRoot
$buildTargets = Select-BuildTargets $Architecture
$identity = $env:SKELETON_MAC_SIGN_IDENTITY

foreach ($target in $buildTargets) {
    $appBundle = $target.AppBundlePath
    if (-not (Test-Path -LiteralPath $appBundle)) {
        throw "Missing app bundle (run build.ps1 first): $appBundle"
    }

    if ([string]::IsNullOrWhiteSpace($identity)) {
        Write-Host "Skipping codesign for $($target.Architecture) (SKELETON_MAC_SIGN_IDENTITY not set): $appBundle"
        continue
    }

    Write-Host "Codesigning $($target.Architecture) app bundle: $appBundle"
    & codesign --force --deep --sign $identity --options runtime $appBundle
    if ($LASTEXITCODE) { throw "codesign failed for $appBundle (exit $LASTEXITCODE)" }

    & codesign --verify --deep --strict $appBundle
    if ($LASTEXITCODE) { throw "codesign verify failed for $appBundle (exit $LASTEXITCODE)" }
}

Write-Host "Done."
