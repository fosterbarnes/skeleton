param([Alias('h')][switch]$Help, [Parameter(ValueFromRemainingArguments = $true)][string[]]$BuildArgs)

$buildAllHelp = @"
.buildAll.ps1 [-arm64 | -arm | -x64 | -x86 | -arm -64 | -64 | -86]
Build app, updater, and installer. Omit flags to build all architectures.
"@

if ($Help) { Write-Host $buildAllHelp; exit }

. "$PSScriptRoot\scriptHelper.ps1"; Set-Location $repoRoot
$architecture = Resolve-BuildArchitecture (@($BuildArgs) + @($args))
$archParams = @{}
if ($architecture) { $archParams['Architecture'] = $architecture }

$steps = @(
    @{ Name = 'build';          Script = 'build.ps1';          UseArch = $true  },
    @{ Name = 'buildInstaller'; Script = 'buildInstaller.ps1'; UseArch = $true  },
    @{ Name = 'updateReadme';   Script = 'updateReadme.ps1';   UseArch = $false }
)

foreach ($step in $steps) {
    $stepScript = "$PSScriptRoot\$($step.Script)"
    if ($step.UseArch) { & $stepScript @archParams } else { & $stepScript }
    if ($LASTEXITCODE -ne 0) { throw "$($step.Name) failed (exit $LASTEXITCODE)." }
}
