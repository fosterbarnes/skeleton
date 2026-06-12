param([string]$Architecture)

#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

$targets = Select-BuildTargets $Architecture

if ($IsMacOS) {
    Invoke-MacAppBundleCodesign $targets
    Write-Host 'App bundles sealed.'
    return
}

Sync-InstallerDefines
if (-not (Test-Path -LiteralPath $appIcon)) { throw "App icon not found: $appIcon" }
if (-not (Test-Path -LiteralPath $installerWizardSmallImage)) { throw "Installer wizard image not found: $installerWizardSmallImage" }
if (-not (Test-Path -LiteralPath $installerWizardLargeImage)) { throw "Installer wizard image not found: $installerWizardLargeImage" }

$issDefines = Get-InstallerIssDefines
$isccArgs = 'AppVersion', 'AppPublisher', 'AppURL', 'SetupIconFile', 'WizardSmallImageFile', 'WizardImageFile' | ForEach-Object { "/D$_=$($issDefines[$_])" }

if (-not $Architecture) { Write-Host "Clearing old installers..."; Remove-Item $installerOutput -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $installerOutput -Force | Out-Null

foreach ($t in $targets) {
    if ($Architecture) {
        $out = Join-Path $installerOutput $t.InstallerName
        if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
    }
    $iss = Get-Content -LiteralPath $t.InstallerScript -Raw
    foreach ($name in $issDefines.Keys) {
        if (-not (Test-IssDefine -Content $iss -Name $name -ExpectedValue $issDefines[$name])) { throw "$($t.InstallerScript): $name must match scriptHelper ('$($issDefines[$name])')" }
    }
    if (-not (Test-Path -LiteralPath $t.ExePath)) { throw "Missing publish output (run build.ps1 first): $($t.ExePath)" }
    $updaterExe = Join-Path $t.BinFolder 'updater.exe'
    if (-not (Test-Path -LiteralPath $updaterExe)) { throw "Missing updater.exe (run build.ps1 first): $updaterExe" }
    Write-Host "Building $($t.Architecture) installer (AppVersion=$versionContents)"
    & $ISCC @isccArgs $t.InstallerScript; if ($LASTEXITCODE) { throw "ISCC failed ($LASTEXITCODE): $($t.InstallerScript)" }
}
Write-Host "Done. Output: $installerOutput"
