param([Alias('h')][switch]$Help, [Parameter(ValueFromRemainingArguments = $true)][string[]]$BuildArgs)

$buildAllHelp = @"
.buildAll.ps1 [-arm64 | -arm | -x64 | -arm -64 | -64]
Publish main app, updater, and app bundle for macOS (osx-arm64, osx-x64). Optional codesign via buildInstaller.ps1.
"@

if ($Help) { Write-Host $buildAllHelp; exit }

. "$PSScriptRoot/scriptHelper.ps1"; Set-Location $repoRoot
$architecture = Resolve-BuildArchitecture (@($BuildArgs) + @($args))
$archParams = @{}
if ($architecture) { $archParams['Architecture'] = $architecture }

& "$PSScriptRoot/build.ps1" @archParams
if ($LASTEXITCODE -ne 0) { throw "build failed (exit $LASTEXITCODE)." }

& "$PSScriptRoot/buildInstaller.ps1" @archParams
if ($LASTEXITCODE -ne 0) { throw "buildInstaller failed (exit $LASTEXITCODE)." }

& "$PSScriptRoot/updateReadme.ps1"
if ($LASTEXITCODE -ne 0) { throw "updateReadme failed (exit $LASTEXITCODE)." }
