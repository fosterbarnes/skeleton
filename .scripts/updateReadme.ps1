#requires -Version 7.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'scriptHelper.ps1')
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($versionContents)) { throw "Version is empty: $version" }
if ($readmeContents -notmatch '<!-- Quick Reference --') { throw 'Could not find Quick Reference block in README.md.' }

$releaseBase = "$appURL/releases/download/$tag"
$quickReference = [ordered]@{ version = $versionContents }

foreach ($target in $winReleaseTargets) {
    $arch = $target.Architecture
    $label = if ($arch -eq 'arm64') { 'ARM64' } else { $arch }
    $quickReference["${label}Installer"] = "$releaseBase/$(Get-WinReleaseAssetName -Kind Installer -Architecture $arch)"
    $quickReference["${label}Portable"] = "$releaseBase/$(Get-WinReleaseAssetName -Kind Portable -Architecture $arch)"
}
$quickReference['osxX64Portable'] = "$releaseBase/$(Get-MacPortableReleaseAssetName -AssetTag 'macOS-intel')"
$quickReference['osxArm64Portable'] = "$releaseBase/$(Get-MacPortableReleaseAssetName -AssetTag 'macOS-arm')"

$refLines = ($quickReference.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join "`n`n"
$readmeUpdated = [regex]::Replace($readmeContents, '(?s)<!-- Quick Reference --.*?-->', "<!-- Quick Reference --`n$refLines`n-->")

$svgSections = @(
    @{
        Pattern = '(?s)(?<section>### Windows\b.*?(?=### macOS|## Tabs))'
        Links = @{
            'download_x64.svg' = 'x64Installer'; 'download_x86.svg' = 'x86Installer'; 'download_arm.svg' = 'ARM64Installer'
            'download_portable_x64.svg' = 'x64Portable'; 'download_portable_x86.svg' = 'x86Portable'; 'download_portable_arm64.svg' = 'ARM64Portable'
        }
    }
    @{
        Pattern = '(?s)(?<section>### macOS\b.*?(?=## Tabs))'
        Links = @{ 'download_appleIntel.svg' = 'osxX64Portable'; 'download_appleArm.svg' = 'osxArm64Portable' }
    }
)

foreach ($section in $svgSections) {
    if ($readmeUpdated -notmatch $section.Pattern) { continue }
    $text = $Matches['section']
    $updated = $text
    foreach ($svg in $section.Links.Keys) {
        $url = $quickReference[$section.Links[$svg]]
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        $updated = $updated -replace "(<a href=`")[^`"]+(`"><img src=`"\./\.resources/svg/$([regex]::Escape($svg))`")", "`${1}$url`${2}"
    }
    $readmeUpdated = $readmeUpdated.Replace($text, $updated)
}

if ($readmeUpdated -eq $readmeContents) {
    Write-Host "README already up to date (v$versionContents)."
    exit 0
}
Set-Content -LiteralPath $readme -Value $readmeUpdated -NoNewline -Encoding utf8NoBOM
Write-Host "Updated README.md for v$versionContents"
exit 0
