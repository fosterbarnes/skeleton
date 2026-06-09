param([string]$Architecture)

#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

$buildTargets = Select-BuildTargets $Architecture

if ($IsMacOS) {
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
    return
}

Sync-InstallerDefines
$appIconIss = Get-IssPath '..' '.resources' 'icon' "$projectName.ico"
if ($Architecture) {
    foreach ($target in $buildTargets) {
        $builtInstaller = Join-Path $installerOutput $target.InstallerName
        if (Test-Path -LiteralPath $builtInstaller) { Remove-Item -LiteralPath $builtInstaller -Force }
    }
}
else {
    Write-Host "Clearing old installers..."
    Remove-Item $installerOutput -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $installerOutput -Force | Out-Null
if (-not (Test-Path -LiteralPath $appIcon)) { throw "App icon not found: $appIcon" }
$issDefines = @{ AppVersion = $versionContents; AppCopyright = $appCopyright; AppPublisher = $appPublisher; AppURL = $appURL; SetupIconFile = $appIconIss }
$isccArgs = @("/DAppVersion=$versionContents", "/DAppPublisher=$appPublisher", "/DAppURL=$appURL", "/DSetupIconFile=$appIconIss")
foreach ($target in $buildTargets) {
    $iss = Get-Content -LiteralPath $target.InstallerScript -Raw
    foreach ($name in $issDefines.Keys) {
        if (-not (Test-IssDefine -Content $iss -Name $name -ExpectedValue $issDefines[$name])) {
            throw "$($target.InstallerScript): $name must match scriptHelper ('$($issDefines[$name])')"
        }
    }
    if (-not (Test-Path -LiteralPath $target.ExePath)) { throw "Missing publish output (run build.ps1 first): $($target.ExePath)" }
    $updaterExe = Join-Path $target.BinFolder 'updater.exe'
    if (-not (Test-Path -LiteralPath $updaterExe)) { throw "Missing updater.exe (run build.ps1 first): $updaterExe" }
    Write-Host "Building $($target.Architecture) installer (AppVersion=$versionContents)"
    & $ISCC @isccArgs $target.InstallerScript
    if ($LASTEXITCODE) { throw "ISCC failed ($LASTEXITCODE): $($target.InstallerScript)" }
}
Write-Host "Done. Output: $installerOutput"
